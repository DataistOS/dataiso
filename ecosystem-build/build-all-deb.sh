#!/usr/bin/env bash
#
# Builds .deb packages for configured Dataist ecosystem repositories.
#
# Scans repository directories under REPOS_ROOT, validates VERSION metadata and
# target entries in targets.conf, compiles supported targets (such as Flutter
# Linux release bundles), packages them into Debian archives, and writes a
# machine-readable summary report.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATAISO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_REPOS_ROOT="$(cd "$DATAISO_ROOT/.." && pwd)"
REPOS_ROOT="${1:-${REPOS_ROOT:-$DEFAULT_REPOS_ROOT}}"

CONF_FILE="$SCRIPT_DIR/targets.conf"
OUT_DEB_DIR="$SCRIPT_DIR/artifacts/deb"
REPORT_FILE="$SCRIPT_DIR/artifacts/build-report.txt"
WORK_BASE="/tmp/dataiso_ecosystem_build"
ONLY_TARGETS="${ONLY_TARGETS:-}"

# Enable ANSI color sequences only when stdout is connected to a terminal.
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
fi

# Preserve the invoking user's home, pub cache, and tool paths under sudo/su.
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6 || echo "/home/$SUDO_USER")"
    export HOME="${HOME:-$USER_HOME}"
    export PUB_CACHE="${PUB_CACHE:-$USER_HOME/.pub-cache}"
    for candidate_bin in "$USER_HOME/flutter/bin" "$USER_HOME/.local/bin" "/opt/flutter/bin" "/usr/local/flutter/bin"; do
        if [[ -d "$candidate_bin" && ":$PATH:" != *":$candidate_bin:"* ]]; then
            export PATH="$candidate_bin:$PATH"
        fi
    done
fi

mkdir -p "$OUT_DEB_DIR" "$WORK_BASE"
: > "$REPORT_FILE"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "${C_RED}${C_BOLD}❌ Config file not found:${C_RESET} $CONF_FILE" >&2
    exit 1
fi

if [[ ! -d "$REPOS_ROOT" ]]; then
    echo "${C_RED}${C_BOLD}❌ Repositories root not found:${C_RESET} $REPOS_ROOT" >&2
    exit 1
fi

#######################################
# Strip CR characters and leading/trailing whitespace from a string.
# Arguments:
#   $1: Input string.
# Outputs:
#   Writes the trimmed string to stdout.
#######################################
trim_edges() {
    local s="$1"
    s="${s//$'\r'/}"
    printf '%s' "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

#######################################
# Check whether a package matches ONLY_TARGETS when filtering is active.
# Globals:
#   ONLY_TARGETS
# Arguments:
#   $1: Package name.
# Returns:
#   0 if allowed or unfiltered, 1 if excluded by ONLY_TARGETS.
#######################################
is_target_filtered() {
    local pkg="$1"
    [[ -z "$ONLY_TARGETS" ]] && return 0
    local IFS=','
    for item in $ONLY_TARGETS; do
        item="$(trim_edges "$item")"
        [[ "$item" == "$pkg" ]] && return 0
    done
    return 1
}

declare -A TARGET_TYPE
declare -A TARGET_ENABLED
declare -A TARGET_BIN
declare -A TARGET_CAT
declare -A TARGET_DESC

# Parse pipe-delimited target definitions while ignoring comments and blanks.
while IFS='|' read -r raw_name raw_type raw_enabled raw_bin raw_cat raw_desc || [[ -n "${raw_name:-}" ]]; do
    name="$(trim_edges "${raw_name:-}")"
    [[ -z "$name" || "${name:0:1}" == "#" ]] && continue

    ptype="$(trim_edges "${raw_type:-}")"
    penabled="$(trim_edges "${raw_enabled:-false}")"
    pbin="$(trim_edges "${raw_bin:-$name}")"
    pcat="$(trim_edges "${raw_cat:-Utility;}")"
    pdesc="$(trim_edges "${raw_desc:-$name - Dataist Ecosystem Application}")"

    [[ -z "$pbin" ]] && pbin="$name"
    [[ -z "$pcat" ]] && pcat="Utility;"
    [[ -z "$pdesc" ]] && pdesc="$name - Dataist Ecosystem Application"

    TARGET_TYPE["$name"]="$ptype"
    TARGET_ENABLED["$name"]="$penabled"
    TARGET_BIN["$name"]="$pbin"
    TARGET_CAT["$name"]="$pcat"
    TARGET_DESC["$name"]="$pdesc"
done < "$CONF_FILE"

#######################################
# Resolve Flutter dependencies using proxychains when available.
# Arguments:
#   None.
# Returns:
#   Exit status of the underlying dependency resolution command.
#######################################
run_flutter_pub_get() {
    if command -v proxychains4 >/dev/null 2>&1; then
        proxychains4 sh -c 'flutter pub get'
    elif command -v proxychains >/dev/null 2>&1; then
        # Filter noisy ld.so preload warnings emitted by proxychains3.
        proxychains sh -c 'flutter pub get' 2> >(grep -v "ERROR: ld.so: object 'libproxychains.so.3'" >&2 || true)
    else
        flutter pub get
    fi
}

#######################################
# Build a Flutter Linux release bundle and package it as an amd64 .deb archive.
# Globals:
#   OUT_DEB_DIR
#   WORK_BASE
# Arguments:
#   $1: Repository directory path.
#   $2: Package name.
#   $3: Package version.
#   $4: Executable binary name inside the release bundle.
#   $5: Desktop entry Categories value.
#   $6: Package description.
# Returns:
#   0 on success, 1 on missing tools, build failure, or missing artifacts.
#######################################
build_flutter_deb() {
    local repo_dir="$1"
    local pkg_name="$2"
    local version="$3"
    local bin_name="$4"
    local categories="$5"
    local description="$6"

    local arch="amd64"
    local bundle_dir="$repo_dir/build/linux/x64/release/bundle"
    local pkg_root="$WORK_BASE/pkg_${pkg_name}_${version}_${arch}"
    local out_deb="$OUT_DEB_DIR/${pkg_name}_${version}_${arch}.deb"

    if ! command -v flutter >/dev/null 2>&1; then
        echo "${C_RED}❌ [$pkg_name] 'flutter' command not found in PATH.${C_RESET}" >&2
        return 1
    fi

    if ! command -v dpkg-deb >/dev/null 2>&1; then
        echo "${C_RED}❌ [$pkg_name] 'dpkg-deb' command not found in PATH.${C_RESET}" >&2
        return 1
    fi

    (
        cd "$repo_dir" || exit 1
        run_flutter_pub_get
        flutter build linux --release
    ) || return 1

    if [[ ! -d "$bundle_dir" ]]; then
        echo "${C_RED}❌ [$pkg_name] Bundle directory not found: $bundle_dir${C_RESET}" >&2
        return 1
    fi

    if [[ ! -f "$bundle_dir/$bin_name" ]]; then
        echo "${C_RED}❌ [$pkg_name] Binary not found inside bundle: $bundle_dir/$bin_name${C_RESET}" >&2
        return 1
    fi

    rm -rf "$pkg_root"
    mkdir -p \
        "$pkg_root/DEBIAN" \
        "$pkg_root/opt/$pkg_name" \
        "$pkg_root/usr/local/bin" \
        "$pkg_root/usr/share/applications"

    cp -r "$bundle_dir/"* "$pkg_root/opt/$pkg_name/"

    cat <<EOF > "$pkg_root/DEBIAN/control"
Package: $pkg_name
Version: $version
Section: utils
Priority: optional
Architecture: $arch
Maintainer: DataistOS <support@dataist.ir>
Description: $description
 Built by Dataiso ecosystem build pipeline ($pkg_name).
EOF

    cat <<EOF > "$pkg_root/usr/local/bin/$pkg_name"
#!/usr/bin/env bash
exec /opt/$pkg_name/$bin_name "\$@"
EOF
    chmod +x "$pkg_root/usr/local/bin/$pkg_name"

    cat <<EOF > "$pkg_root/usr/share/applications/$pkg_name.desktop"
[Desktop Entry]
Name=${pkg_name^}
Comment=$description
Exec=/usr/local/bin/$pkg_name
Terminal=false
Type=Application
Categories=$categories
EOF

    dpkg-deb --build "$pkg_root" "$out_deb" >/dev/null
}

built_count=0
skipped_no_version=0
skipped_unconfigured=0
skipped_disabled=0
failed_count=0

echo "${C_CYAN}${C_BOLD}▶ Scanning repositories in:${C_RESET} ${C_DIM}$REPOS_ROOT${C_RESET}"
echo "${C_DIM}------------------------------------------------------------${C_RESET}"

# Iterate over sibling repositories and build enabled, versioned targets.
for repo_dir in "$REPOS_ROOT"/*/; do
    [[ -d "$repo_dir" ]] || continue
    pkg_name="$(basename "$repo_dir")"

    [[ "$pkg_name" == "dataiso" ]] && continue
    is_target_filtered "$pkg_name" || continue

    version_file="$repo_dir/VERSION"
    if [[ ! -f "$version_file" ]]; then
        ((skipped_no_version++)) || true
        echo "NO_VERSION | $pkg_name" >> "$REPORT_FILE"
        continue
    fi

    version="$(tr -d '[:space:]' < "$version_file")"
    if [[ -z "$version" ]]; then
        ((skipped_no_version++)) || true
        echo "EMPTY_VERSION | $pkg_name" >> "$REPORT_FILE"
        continue
    fi

    if [[ -z "${TARGET_TYPE[$pkg_name]:-}" ]]; then
        ((skipped_unconfigured++)) || true
        echo "UNCONFIGURED | $pkg_name | v$version" >> "$REPORT_FILE"
        continue
    fi

    if [[ "${TARGET_ENABLED[$pkg_name]}" != "true" ]]; then
        ((skipped_disabled++)) || true
        echo "DISABLED | $pkg_name | v$version" >> "$REPORT_FILE"
        continue
    fi

    ptype="${TARGET_TYPE[$pkg_name]}"
    pbin="${TARGET_BIN[$pkg_name]}"
    pcat="${TARGET_CAT[$pkg_name]}"
    pdesc="${TARGET_DESC[$pkg_name]}"

    echo ""
    echo "${C_BLUE}${C_BOLD}🔨 [$pkg_name]${C_RESET} ${C_CYAN}(v$version, type=$ptype)${C_RESET} ${C_DIM}-> building...${C_RESET}"
    rc=0
    case "$ptype" in
        flutter)
            build_flutter_deb "$repo_dir" "$pkg_name" "$version" "$pbin" "$pcat" "$pdesc"
            rc=$?
            ;;
        *)
            echo "${C_YELLOW}⚠️  [$pkg_name] Unknown type '$ptype'${C_RESET}"
            rc=2
            ;;
    esac

    if [[ $rc -eq 0 ]]; then
        echo "${C_GREEN}${C_BOLD}✅ [$pkg_name] v$version${C_RESET} ${C_GREEN}-> built in $OUT_DEB_DIR${C_RESET}"
        echo "BUILT | $pkg_name | v$version | $ptype" >> "$REPORT_FILE"
        ((built_count++)) || true
    else
        echo "${C_RED}${C_BOLD}❌ [$pkg_name] v$version -> failed!${C_RESET}"
        echo "FAILED | $pkg_name | v$version | $ptype" >> "$REPORT_FILE"
        ((failed_count++)) || true
    fi
done

echo ""
echo "${C_CYAN}${C_BOLD}================ ECOSYSTEM DEB BUILD SUMMARY ================${C_RESET}"
printf "  ${C_GREEN}%-22s${C_RESET} %s\n" "Built (.deb):" "$built_count"
printf "  ${C_DIM}%-22s${C_RESET} %s\n" "Skipped (no VERSION):" "$skipped_no_version"
printf "  ${C_DIM}%-22s${C_RESET} %s\n" "Skipped (unconfigured):" "$skipped_unconfigured"
printf "  ${C_YELLOW}%-22s${C_RESET} %s\n" "Skipped (disabled):" "$skipped_disabled"
if [[ "$failed_count" -gt 0 ]]; then
    printf "  ${C_RED}${C_BOLD}%-22s${C_RESET} %s\n" "Failed:" "$failed_count"
else
    printf "  ${C_GREEN}%-22s${C_RESET} %s\n" "Failed:" "$failed_count"
fi
echo "${C_DIM}-------------------------------------------------------------${C_RESET}"
printf "  ${C_BOLD}%-22s${C_RESET} %s\n" "DEB output dir:" "$OUT_DEB_DIR"
printf "  ${C_BOLD}%-22s${C_RESET} %s\n" "Report file:" "$REPORT_FILE"
echo "${C_CYAN}${C_BOLD}=============================================================${C_RESET}"