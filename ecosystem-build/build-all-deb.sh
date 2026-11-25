#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATAISO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_REPOS_ROOT="$(cd "$DATAISO_ROOT/.." && pwd)"
REPOS_ROOT="${1:-${REPOS_ROOT:-$DEFAULT_REPOS_ROOT}}"

CONF_FILE="$SCRIPT_DIR/targets.conf"
OUT_DEB_DIR="$SCRIPT_DIR/artifacts/deb"
REPORT_FILE="$SCRIPT_DIR/artifacts/build-report.txt"
WORK_BASE="/tmp/dataiso_ecosystem_build"

mkdir -p "$OUT_DEB_DIR" "$WORK_BASE"
: > "$REPORT_FILE"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "❌ Config file not found: $CONF_FILE" >&2
    exit 1
fi

if [[ ! -d "$REPOS_ROOT" ]]; then
    echo "❌ Repositories root not found: $REPOS_ROOT" >&2
    exit 1
fi

trim_edges() {
    local s="$1"
    s="${s//$'\r'/}"
    printf '%s' "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

declare -A TARGET_TYPE
declare -A TARGET_ENABLED
declare -A TARGET_BIN
declare -A TARGET_CAT
declare -A TARGET_DESC

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
        echo "❌ [$pkg_name] 'flutter' command not found in PATH." >&2
        return 1
    fi

    if ! command -v dpkg-deb >/dev/null 2>&1; then
        echo "❌ [$pkg_name] 'dpkg-deb' command not found in PATH." >&2
        return 1
    fi

    (
        cd "$repo_dir" || exit 1
        flutter pub get
        flutter build linux --release
    ) || return 1

    if [[ ! -d "$bundle_dir" ]]; then
        echo "❌ [$pkg_name] Bundle directory not found: $bundle_dir" >&2
        return 1
    fi

    if [[ ! -f "$bundle_dir/$bin_name" ]]; then
        echo "❌ [$pkg_name] Binary not found inside bundle: $bundle_dir/$bin_name" >&2
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

for repo_dir in "$REPOS_ROOT"/*/; do
    [[ -d "$repo_dir" ]] || continue
    pkg_name="$(basename "$repo_dir")"

    [[ "$pkg_name" == "dataiso" ]] && continue

    version_file="$repo_dir/VERSION"
    if [[ ! -f "$version_file" ]]; then
        ((skipped_no_version++))
        echo "NO_VERSION | $pkg_name" >> "$REPORT_FILE"
        continue
    fi

    version="$(tr -d '[:space:]' < "$version_file")"
    if [[ -z "$version" ]]; then
        ((skipped_no_version++))
        echo "EMPTY_VERSION | $pkg_name" >> "$REPORT_FILE"
        continue
    fi

    if [[ -z "${TARGET_TYPE[$pkg_name]:-}" ]]; then
        ((skipped_unconfigured++))
        echo "UNCONFIGURED | $pkg_name | v$version" >> "$REPORT_FILE"
        continue
    fi

    if [[ "${TARGET_ENABLED[$pkg_name]}" != "true" ]]; then
        ((skipped_disabled++))
        echo "DISABLED | $pkg_name | v$version" >> "$REPORT_FILE"
        continue
    fi

    ptype="${TARGET_TYPE[$pkg_name]}"
    pbin="${TARGET_BIN[$pkg_name]}"
    pcat="${TARGET_CAT[$pkg_name]}"
    pdesc="${TARGET_DESC[$pkg_name]}"

    echo "🔨 [$pkg_name] (v$version, type=$ptype) -> building..."
    set +e
    case "$ptype" in
        flutter)
            build_flutter_deb "$repo_dir" "$pkg_name" "$version" "$pbin" "$pcat" "$pdesc"
            rc=$?
            ;;
        *)
            echo "⚠️  [$pkg_name] Unknown type '$ptype'"
            rc=2
            ;;
    esac
    set -e

    if [[ $rc -eq 0 ]]; then
        echo "✅ [$pkg_name] v$version -> built in $OUT_DEB_DIR"
        echo "BUILT | $pkg_name | v$version | $ptype" >> "$REPORT_FILE"
        ((built_count++))
    else
        echo "❌ [$pkg_name] v$version -> failed!"
        echo "FAILED | $pkg_name | v$version | $ptype" >> "$REPORT_FILE"
        ((failed_count++))
    fi
done

echo ""
echo "================ ECOSYSTEM DEB BUILD SUMMARY ================"
echo "Built (.deb):          $built_count"
echo "Skipped (no VERSION):  $skipped_no_version"
echo "Skipped (unconfigured):$skipped_unconfigured"
echo "Skipped (disabled):    $skipped_disabled"
echo "Failed:                $failed_count"
echo "DEB output dir:        $OUT_DEB_DIR"
echo "Report file:           $REPORT_FILE"
echo "============================================================="