#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub repository
REPO="missuo/ask"
INSTALL_DIR="/usr/bin"
BINARY_NAME="ask"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Function to detect OS
detect_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case $os in
        linux)
            echo "linux"
            ;;
        darwin)
            echo "darwin"
            ;;
        freebsd)
            echo "freebsd"
            ;;
        *)
            print_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
}

# Function to get latest release tag
get_latest_tag() {
    # Try using GitHub API first
    if command -v curl >/dev/null 2>&1; then
        local tag=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -n "$tag" && "$tag" != "null" ]]; then
            echo "$tag"
            return 0
        fi
    fi
    
    # Fallback to git if API fails
    if command -v git >/dev/null 2>&1; then
        local tag=$(git ls-remote --tags --refs --sort="version:refname" "https://github.com/$REPO.git" | tail -n1 | sed 's/.*\///')
        if [[ -n "$tag" ]]; then
            echo "$tag"
            return 0
        fi
    fi
    
    return 1
}

# Function to download binary
download_binary() {
    local tag=$1
    local os=$2
    local arch=$3
    local binary_name="ask-$os-$arch"
    local download_url="https://github.com/$REPO/releases/download/$tag/$binary_name"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$download_url" -o "$binary_name" >/dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget "$download_url" -O "$binary_name" >/dev/null 2>&1
    else
        return 1
    fi
    
    if [[ ! -f "$binary_name" ]]; then
        return 1
    fi
    
    echo "$binary_name"
}

# Function to install binary
install_binary() {
    local binary_file=$1
    
    print_info "Installing $binary_file to $INSTALL_DIR/$BINARY_NAME..."
    
    # Check if we have write permission to install directory
    if [[ ! -w "$INSTALL_DIR" ]]; then
        print_warn "No write permission to $INSTALL_DIR. Trying with sudo..."
        sudo mv "$binary_file" "$INSTALL_DIR/$BINARY_NAME"
        sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
    else
        mv "$binary_file" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
    fi
    
    print_info "Installation completed successfully!"
}

# Function to verify installation
verify_installation() {
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local version=$("$BINARY_NAME" --version 2>/dev/null | head -1)
        print_info "$BINARY_NAME installed successfully!"
        print_info "Version: $version"
        print_info "Location: $(which $BINARY_NAME)"
        print_info "Test installation with: $BINARY_NAME <github-username>"
    else
        print_error "Installation verification failed. $BINARY_NAME not found in PATH."
        exit 1
    fi
}

# Function to cleanup
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -f ask-*-*
}

# Function to uninstall binary
uninstall() {
    print_info "Starting uninstallation of $BINARY_NAME..."
    
    if [[ ! -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        print_warn "$BINARY_NAME is not installed in $INSTALL_DIR"
        exit 0
    fi
    
    print_info "Removing $BINARY_NAME from $INSTALL_DIR..."
    
    if [[ ! -w "$INSTALL_DIR" ]]; then
        print_warn "No write permission to $INSTALL_DIR. Trying with sudo..."
        sudo rm -f "$INSTALL_DIR/$BINARY_NAME"
    else
        rm -f "$INSTALL_DIR/$BINARY_NAME"
    fi
    
    if [[ ! -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        print_info "$BINARY_NAME uninstalled successfully!"
    else
        print_error "Failed to uninstall $BINARY_NAME"
        exit 1
    fi
}

# Function to upgrade binary
upgrade() {
    print_info "Starting upgrade of $BINARY_NAME..."
    
    if [[ ! -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        print_warn "$BINARY_NAME is not installed. Running installation instead..."
        install_main
        return
    fi
    
    # Get current version
    local current_version=$("$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null | head -1)
    print_info "Current version: $current_version"
    
    # Check if running on Linux
    if [[ "$(detect_os)" != "linux" ]]; then
        print_error "This installer is designed for Linux only."
        exit 1
    fi
    
    # Detect system architecture
    local arch=$(detect_arch)
    local os=$(detect_os)
    
    # Get latest release tag
    print_info "Fetching latest release information..."
    local latest_tag=$(get_latest_tag)
    if [[ $? -ne 0 || -z "$latest_tag" ]]; then
        print_error "Failed to fetch latest release tag"
        exit 1
    fi
    print_info "Latest release: $latest_tag"
    
    # Check if already up to date
    if [[ "$current_version" == *"$latest_tag"* ]]; then
        print_info "$BINARY_NAME is already up to date ($latest_tag)"
        return
    fi
    
    # Download and install new version
    local binary_name="ask-$os-$arch"
    local download_url="https://github.com/$REPO/releases/download/$latest_tag/$binary_name"
    print_info "Downloading $binary_name from $download_url..."
    
    local binary_file=$(download_binary "$latest_tag" "$os" "$arch")
    if [[ $? -ne 0 || -z "$binary_file" ]]; then
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Install binary
    install_binary "$binary_file"
    
    # Verify installation
    verify_installation
    
    print_info "Upgrade complete!"
}

# Main installation function
install_main() {
    print_info "Starting installation of $BINARY_NAME..."
    
    # Check if running on Linux
    if [[ "$(detect_os)" != "linux" ]]; then
        print_error "This installer is designed for Linux only."
        exit 1
    fi
    
    # Detect system architecture
    local arch=$(detect_arch)
    local os=$(detect_os)
    
    print_info "Detected system: $os/$arch"
    
    # Get latest release tag
    print_info "Fetching latest release information..."
    local latest_tag=$(get_latest_tag)
    if [[ $? -ne 0 || -z "$latest_tag" ]]; then
        print_error "Failed to fetch latest release tag"
        exit 1
    fi
    print_info "Latest release: $latest_tag"
    
    # Download binary
    local binary_name="ask-$os-$arch"
    local download_url="https://github.com/$REPO/releases/download/$latest_tag/$binary_name"
    print_info "Downloading $binary_name from $download_url..."
    
    local binary_file=$(download_binary "$latest_tag" "$os" "$arch")
    if [[ $? -ne 0 || -z "$binary_file" ]]; then
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Install binary
    install_binary "$binary_file"
    
    # Verify installation
    verify_installation
    
    print_info "Installation complete! You can now use '$BINARY_NAME' command."
    print_info "Usage: $BINARY_NAME <github-username>"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [install|upgrade|uninstall]"
    echo ""
    echo "Commands:"
    echo "  install    Install $BINARY_NAME (default)"
    echo "  upgrade    Upgrade $BINARY_NAME to latest version"
    echo "  uninstall  Remove $BINARY_NAME from system"
    echo ""
    echo "Examples:"
    echo "  bash <(curl -Ls https://raw.githubusercontent.com/$REPO/main/install.sh)"
    echo "  bash <(curl -Ls https://raw.githubusercontent.com/$REPO/main/install.sh) upgrade"
    echo "  bash <(curl -Ls https://raw.githubusercontent.com/$REPO/main/install.sh) uninstall"
}

# Main function
main() {
    local command="${1:-install}"
    
    case "$command" in
        install)
            install_main
            ;;
        upgrade)
            upgrade
            ;;
        uninstall)
            uninstall
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"