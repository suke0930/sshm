#!/bin/bash
# SSHM Installation Script for Termux (Android)
#
# Termux is a non-rooted Android terminal emulator. It uses a prefix
# filesystem rooted at $PREFIX (/data/data/com.termux/files/usr) and has
# no sudo. Binaries live in $PREFIX/bin which is already on PATH.
#
# Usage:
#   bash termux.sh                       # build from source (recommended)
#   SSHM_VERSION=v1.8.1 bash termux.sh   # build a specific tag
#   SSHM_FROM_SOURCE=false bash termux.sh # try prebuilt binary first
#   FORCE_INSTALL=true bash termux.sh    # skip confirmation prompts

set -e

# ---- Defaults / env ---------------------------------------------------------
EXECUTABLE_NAME=sshm
FROM_SOURCE="${SSHM_FROM_SOURCE:-true}"   # Termux has no prebuilt releases yet, source is the safe path
FORCE_INSTALL="${FORCE_INSTALL:-false}"
SSHM_VERSION="${SSHM_VERSION:-main}"      # branch, tag or commit; "main" = latest
SSHM_REPO="${SSHM_REPO:-suke0930/sshm}"

# ---- Colors -----------------------------------------------------------------
RED='\033[0;31m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    printf "${PURPLE}SSHM Installation Script for Termux${NC}\n\n"
    printf "Usage:\n"
    printf "  Build from source (default):  ${GREEN}bash termux.sh${NC}\n"
    printf "  Build specific tag/branch:    ${GREEN}SSHM_VERSION=v1.8.1 bash termux.sh${NC}\n"
    printf "  Try prebuilt binary first:    ${GREEN}SSHM_FROM_SOURCE=false bash termux.sh${NC}\n"
    printf "  Force (no prompts):           ${GREEN}FORCE_INSTALL=true bash termux.sh${NC}\n\n"
    printf "Environment variables:\n"
    printf "  SSHM_VERSION      Tag/branch/commit to build (default: main)\n"
    printf "  SSHM_REPO         'owner/name' GitHub repo to build from (default: suke0930/sshm)\n"
    printf "  SSHM_FROM_SOURCE  Build from source instead of downloading (default: true)\n"
    printf "  SSHM_UPDATE_URL   GitHub API URL for update checks (default: empty = disabled)\n"
    printf "  FORCE_INSTALL     Skip confirmation prompts (default: false)\n"
    printf "  GOPATH            Override Go workspace (default: \$HOME/go)\n\n"
}

# ---- Termux environment detection ------------------------------------------
detectTermux() {
    if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
        # Fall back to the well-known Termux prefix
        PREFIX="/data/data/com.termux/files/usr"
    fi
    if [ ! -d "$PREFIX" ]; then
        printf "${RED}This script is intended for Termux on Android.${NC}\n"
        printf "${RED}Could not find Termux prefix at: $PREFIX${NC}\n"
        printf "${YELLOW}For regular Linux/macOS use install/unix.sh instead.${NC}\n"
        exit 1
    fi

    INSTALL_DIR="$PREFIX/bin"
    EXECUTABLE_PATH="$INSTALL_DIR/$EXECUTABLE_NAME"

    # HOME in Termux is /data/data/com.termux/files/home ; respect it if set
    if [ -z "$HOME" ]; then
        HOME="/data/data/com.termux/files/home"
        export HOME
    fi

    printf "${GREEN}Detected Termux:${NC}\n"
    printf "  PREFIX      : %s\n" "$PREFIX"
    printf "  HOME        : %s\n" "$HOME"
    printf "  Install dir : %s\n" "$INSTALL_DIR"
}

# ---- Dependency check -------------------------------------------------------
checkDependencies() {
    local missing=()

    # pkg is Termux's package manager (wraps apt)
    if ! command -v pkg >/dev/null 2>&1; then
        printf "${RED}'pkg' package manager not found. Are you really in Termux?${NC}\n"
        exit 1
    fi

    # Ensure we have everything needed to build Go from source
    local need=()
    command -v go    >/dev/null 2>&1 || need+=("golang")
    command -v git   >/dev/null 2>&1 || need+=("git")
    command -v curl  >/dev/null 2>&1 || need+=("curl")
    command -v tar   >/dev/null 2>&1 || need+=("tar")
    # gcc is helpful (not strictly required for CGO_ENABLED=0 builds) but keep it
    command -v gcc   >/dev/null 2>&1 || need+=("clang")

    if [ ${#need[@]} -gt 0 ]; then
        printf "${YELLOW}Installing required packages via pkg: %s${NC}\n" "${need[*]}"
        pkg update -y
        pkg install -y "${need[@]}"
    fi

    # Re-check after install
    if ! command -v go >/dev/null 2>&1; then
        printf "${RED}Go could not be installed. Install it manually with: pkg install golang${NC}\n"
        exit 1
    fi
}

# ---- Existing install handling ---------------------------------------------
checkExisting() {
    if [ ! -f "$EXECUTABLE_PATH" ]; then
        return
    fi

    CURRENT_VERSION=$("$EXECUTABLE_PATH" --version 2>/dev/null | grep -o 'version.*' | cut -d' ' -f2 || echo "unknown")
    printf "${YELLOW}SSHM is already installed (version: $CURRENT_VERSION)${NC}\n"

    if [ "$FORCE_INSTALL" = "true" ]; then
        printf "${GREEN}Force install enabled, proceeding...${NC}\n"
        return
    fi

    if [ ! -t 0 ]; then
        printf "${YELLOW}Running via pipe - automatically proceeding...${NC}\n"
        return
    fi

    printf "${YELLOW}Do you want to overwrite it? [y/N]: ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "${GREEN}Proceeding with installation...${NC}\n"
            ;;
        *)
            printf "${GREEN}Installation cancelled.${NC}\n"
            exit 0
            ;;
    esac
}

# ---- Build from source ------------------------------------------------------
buildFromSource() {
    printf "${YELLOW}Building SSHM from source (repo: %s, ref: %s)...${NC}\n" "$SSHM_REPO" "$SSHM_VERSION"

    GOPATH="${GOPATH:-$HOME/go}"
    WORKDIR="$HOME/.sshm-build"
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"

    CLONE_URL="https://github.com/${SSHM_REPO}.git"

    # Shallow clone of the requested ref
    if [ "$SSHM_VERSION" = "main" ]; then
        git clone --depth 1 "$CLONE_URL" "$WORKDIR/sshm"
    else
        # Try a shallow clone of the specific ref
        git clone --depth 1 --branch "$SSHM_VERSION" "$CLONE_URL" "$WORKDIR/sshm" 2>/dev/null || {
            printf "${YELLOW}Specific ref clone failed, falling back to full clone...${NC}\n"
            git clone "$CLONE_URL" "$WORKDIR/sshm"
            git -C "$WORKDIR/sshm" checkout "$SSHM_VERSION"
        }
    fi

    cd "$WORKDIR/sshm"

    # Tidy and build. CGO is disabled so the binary is pure-Go and portable
    # across Termux environments without a C toolchain at runtime.
    export GO111MODULE=on
    export GOFLAGS="-mod=mod"
    go mod tidy 2>/dev/null || true

    # Resolve a version string for the binary
    if [ "$SSHM_VERSION" = "main" ]; then
        BUILD_VERSION="$(git -C "$WORKDIR/sshm" describe --tags --always --dirty 2>/dev/null || echo "dev")"
    else
        BUILD_VERSION="$SSHM_VERSION"
    fi

    printf "${YELLOW}Compiling (version=%s, target=%s)...${NC}\n" "$BUILD_VERSION" "$EXECUTABLE_PATH"
    # Disable the update checker (empty UpdateCheckURL) so a source-built
    # fork binary does not notify about upstream releases. Override with
    # SSHM_UPDATE_URL to point at your own fork's releases instead.
    UPDATE_URL="${SSHM_UPDATE_URL:-}"
    go build -trimpath -ldflags="-s -w -X github.com/Gu1llaum-3/sshm/cmd.AppVersion=${BUILD_VERSION} -X github.com/Gu1llaum-3/sshm/internal/version.UpdateCheckURL=${UPDATE_URL}" \
        -o "$EXECUTABLE_PATH" .

    chmod +x "$EXECUTABLE_PATH"

    # Clean up build tree
    rm -rf "$WORKDIR"

    printf "${GREEN}Build complete.${NC}\n"
}

# ---- Prebuilt binary download (optional) -----------------------------------
downloadBinary() {
    # Termux runs on Linux/arm64 (most devices) or linux/arm (older 32-bit).
    # We reuse the regular linux-arm64 / linux-arm releases when available.
    local ARCH
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armv7*) ARCH="armv7" ;;
        armv6l|armv6*) ARCH="armv6" ;;
        *) printf "${RED}Unsupported architecture: $ARCH${NC}\n"; return 1 ;;
    esac

    local GORELEASER_ARCH="$ARCH"
    case $ARCH in
        arm64) GORELEASER_ARCH="arm64" ;;
        armv7) GORELEASER_ARCH="armv7" ;;
        armv6) GORELEASER_ARCH="armv6" ;;
    esac

    local VERSION
    if [ "$SSHM_VERSION" = "main" ]; then
        printf "${YELLOW}Fetching latest stable version...${NC}\n"
        VERSION=$(curl -s "https://api.github.com/repos/${SSHM_REPO}/releases/latest" \
            | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$VERSION" ]; then
            printf "${RED}Failed to fetch latest version${NC}\n"
            return 1
        fi
    else
        VERSION="$SSHM_VERSION"
    fi

    local GITHUB_FILE="sshm_Linux_${GORELEASER_ARCH}.tar.gz"
    local GITHUB_URL="https://github.com/${SSHM_REPO}/releases/download/${VERSION}/${GITHUB_FILE}"

    printf "${YELLOW}Downloading %s...${NC}\n" "$GITHUB_FILE"
    local TMP="$HOME/.sshm-tmp"
    mkdir -p "$TMP"
    if ! curl -L "$GITHUB_URL" --progress-bar --output "$TMP/sshm.tar.gz"; then
        printf "${RED}Download failed${NC}\n"
        rm -rf "$TMP"
        return 1
    fi

    tar -xzf "$TMP/sshm.tar.gz" -C "$TMP"
    if [ ! -f "$TMP/sshm" ]; then
        printf "${RED}Extracted binary not found${NC}\n"
        rm -rf "$TMP"
        return 1
    fi

    chmod +x "$TMP/sshm"
    mv "$TMP/sshm" "$EXECUTABLE_PATH"
    rm -rf "$TMP"
    printf "${GREEN}Installed prebuilt binary (version: %s).${NC}\n" "$VERSION"
}

# ---- Main -------------------------------------------------------------------
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        usage
        exit 0
    fi

    printf "${PURPLE}Installing SSHM - SSH Manager for Termux${NC}\n\n"

    detectTermux
    checkDependencies
    checkExisting

    if [ "$FROM_SOURCE" = "true" ]; then
        buildFromSource
    else
        # Try prebuilt first, fall back to source if it fails
        if ! downloadBinary; then
            printf "${YELLOW}Prebuilt download unavailable, falling back to source build...${NC}\n"
            buildFromSource
        fi
    fi

    printf "\n${GREEN}SSHM was installed successfully to: ${NC}$EXECUTABLE_PATH\n"
    printf "${GREEN}You can now use 'sshm' to manage your SSH connections!${NC}\n\n"

    printf "${YELLOW}Verifying installation...${NC}\n"
    if command -v sshm >/dev/null 2>&1; then
        "$EXECUTABLE_PATH" --version 2>/dev/null || echo "Version check failed, but installation completed"
    else
        printf "${RED}Warning: 'sshm' not found in PATH. Ensure %s is on your PATH.${NC}\n" "$INSTALL_DIR"
    fi

    printf "\n${CYAN}Termux tips:${NC}\n"
    printf "  - SSH config lives at: %s/.ssh/config\n" "$HOME"
    printf "  - SSHM app config:      %s/.config/sshm/config.json\n" "$HOME"
    printf "  - Make sure openssh is installed: ${GREEN}pkg install openssh${NC}\n"
    printf "  - Generate a key with: ${GREEN}ssh-keygen -t ed25519${NC}\n"
}

main "$@"
