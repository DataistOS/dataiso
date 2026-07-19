# Use the official Arch Linux base image
FROM archlinux:latest

# Update system and install required tools for build
# 'archiso' is the core requirement
# 'git' and 'base-devel' are added for better compatibility with build tools
RUN pacman -Syu --noconfirm archiso git base-devel

# Set the working directory to the project root
WORKDIR /dataist

# Copy project files into the container
# This allows building the image once and then running the build script
COPY . .

# Set the entry point to execute the build script
CMD ["./build.sh"]