# Installation Scripts

This directory contains installation scripts for SSHM.

## Unix/Linux/macOS Installation

### Quick Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/unix.sh | bash
```

**Note:** When using the pipe method, the installer will automatically proceed with installation if SSHM is already installed.

## Windows Installation

### Quick Install (Recommended)

```powershell
irm https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/windows.ps1 | iex
```

### Install Options

**Force install without prompts:**
```powershell
iex "& { $(irm https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/windows.ps1) } -Force"
```

**Custom installation directory:**
```powershell
iex "& { $(irm https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/windows.ps1) } -InstallDir 'C:\tools'"
```

## Unix/Linux/macOS Advanced Options

**Force install without prompts:**
```bash
FORCE_INSTALL=true bash -c "$(curl -sSL https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/unix.sh)"
```

**Disable auto-install when using pipe:**
```bash
FORCE_INSTALL=false bash -c "$(curl -sSL https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/unix.sh)"
```

### Manual Install

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/Gu1llaum-3/sshm/main/install/unix.sh
```

2. Make it executable:
```bash
chmod +x unix.sh
```

3. Run the installer:
```bash
./unix.sh
```

## What the installer does

1. **Detects your system** - Automatically detects your OS (Linux/macOS) and architecture (AMD64/ARM64)
2. **Fetches latest version** - Gets the latest release from GitHub
3. **Downloads binary** - Downloads the appropriate binary for your system
4. **Installs to /usr/local/bin** - Installs the binary with proper permissions
5. **Verifies installation** - Checks that the installation was successful

## Supported Platforms

- **Linux**: AMD64, ARM64
- **macOS**: AMD64 (Intel), ARM64 (Apple Silicon)
- **Android (Termux)**: ARM64, ARMv7 (builds from source)

## Requirements

- `curl` - for downloading
- `tar` - for extracting archives
- `sudo` access - for installing to `/usr/local/bin` *(not required on Termux)*

## Android (Termux) Installation

Termux is an Android terminal emulator with its own prefix filesystem
(`$PREFIX`, typically `/data/data/com.termux/files/usr`). It has **no
sudo/root** and installs packages via the `pkg` manager. SSHM provides a
dedicated installer for this environment.

### Quick Install (Recommended)

From inside Termux:

```bash
curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/termux.sh | bash
```

The generic Unix installer also works — it auto-detects Termux and
delegates to `termux.sh`:

```bash
curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/unix.sh | bash
```

### What the Termux installer does

1. **Detects Termux** via `$PREFIX` and refuses to run elsewhere
2. **Installs dependencies** with `pkg`: `golang`, `git`, `curl`, `tar`, `clang`
3. **Builds from source** (default) — clones the repo and runs
   `go build` with `CGO_ENABLED=0` for a pure-Go, portable binary
4. **Installs to `$PREFIX/bin`** (no sudo needed) so `sshm` is on `PATH`
5. **Verifies installation** by running `sshm --version`

### Install Options

**Specific version / tag:**
```bash
SSHM_VERSION=v1.8.1 bash -c "$(curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/termux.sh)"
```

**Force install without prompts:**
```bash
FORCE_INSTALL=true bash -c "$(curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/termux.sh)"
```

**Try a prebuilt binary first, fall back to source:**
```bash
SSHM_FROM_SOURCE=false bash -c "$(curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/termux.sh)"
```

**Build from a fork:**
```bash
SSHM_REPO=yourname/sshm bash -c "$(curl -sSL https://raw.githubusercontent.com/suke0930/sshm/main/install/termux.sh)"
```

### Manual Termux Install

```bash
pkg install golang git openssh
git clone https://github.com/suke0930/sshm.git ~/sshm
cd ~/sshm
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o $PREFIX/bin/sshm .
sshm --version
```

### Termux Requirements

- Termux from [F-Droid](https://f-droid.org/packages/com.termux/) (recommended) or GitHub releases
- `pkg install openssh` — required for the actual SSH connection (SSHM calls the `ssh` binary)

## Uninstall

To uninstall SSHM:

```bash
# Linux / macOS
sudo rm /usr/local/bin/sshm

# Termux (Android)
rm $PREFIX/bin/sshm
```
