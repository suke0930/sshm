.PHONY: build build-local build-termux test clean release snapshot

# Version can be overridden via environment variable or command line
VERSION ?= dev

# GitHub API URL used by the built-in update checker. Override this when
# building a fork so update notifications point at your own repository, or
# set it to the empty string (UPDATE_CHECK_URL=) to disable update checks.
UPDATE_CHECK_URL ?= https://api.github.com/repos/Gu1llaum-3/sshm/releases/latest

# Go build flags
LDFLAGS := -s -w -X github.com/Gu1llaum-3/sshm/cmd.AppVersion=$(VERSION) -X github.com/Gu1llaum-3/sshm/internal/version.UpdateCheckURL=$(UPDATE_CHECK_URL)

# Build with specific version
build:
	@mkdir -p dist
	go build -ldflags="$(LDFLAGS)" -o dist/sshm .

# Build with git version
build-local: VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
build-local: build

# Build a pure-Go (CGO disabled) binary suitable for Termux / Android.
# This targets the local GOOS/GOARCH (typically linux/arm64 on modern
# Android devices) and disables the update checker by default, since
# Termux users typically build from source and do not want notifications
# pointing at the upstream GitHub release. Override UPDATE_CHECK_URL to
# keep update checks enabled for your own fork.
build-termux: CGO_ENABLED := 0
build-termux: GOOS := linux
build-termux: GOARCH := arm64
build-termux: UPDATE_CHECK_URL ?=
build-termux:
	@mkdir -p dist
	CGO_ENABLED=$(CGO_ENABLED) GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build -trimpath -ldflags="$(LDFLAGS)" -o dist/sshm .
	@echo "Built dist/sshm for $(GOOS)/$(GOARCH) (CGO disabled, Termux-ready)"
	@echo "Copy dist/sshm to $$PREFIX/bin/ on your Termux device."

# Build for Termux on the local device, cross-compiling for an explicit
# architecture given via GOARCH (e.g. make build-termux-arm GOARCH=arm).
build-termux-arm: GOARCH := arm
build-termux-arm: GOARM := 7
build-termux-arm: build-termux

# Run tests
test:
	go test ./...

# Clean build artifacts
clean:
	rm -rf dist

# Release with GoReleaser (requires tag)
release:
	@if [ -z "$(shell git tag --points-at HEAD)" ]; then \
		echo "Error: No git tag found at current commit. Create a tag first with: git tag vX.Y.Z"; \
		exit 1; \
	fi
	goreleaser release --clean

# Build snapshot (without tag)
snapshot:
	goreleaser release --snapshot --clean

# Check GoReleaser config
release-check:
	goreleaser check

# Run GoReleaser in dry-run mode
release-dry-run:
	goreleaser release --snapshot --skip=publish --clean
