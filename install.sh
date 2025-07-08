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
    
    print_info "Downloading $binary_name from $download_url..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$download_url" -o "$binary_name"
    elif command -v wget >/dev/null 2>&1; then
        wget "$download_url" -O "$binary_name"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [[ ! -f "$binary_name" ]]; then
        print_error "Failed to download binary"
        exit 1
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
        local version=$("$BINARY_NAME" --version 2>/dev/null || echo "unknown")
        print_info "$BINARY_NAME installed successfully!"
        print_info "Version: $version"
        print_info "Location: $(which $BINARY_NAME)"
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

# Main installation function
main() {
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
    local binary_file=$(download_binary "$latest_tag" "$os" "$arch")
    
    # Install binary
    install_binary "$binary_file"
    
    # Verify installation
    verify_installation
    
    # Cleanup
    cleanup
    
    print_info "Installation complete! You can now use '$BINARY_NAME' command."
    print_info "Usage: $BINARY_NAME <github-username>"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"