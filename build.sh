#!/usr/bin/env bash

set -e

# Hysteria build script for Linux
# Environment variable options:
#   - HY_APP_VERSION: App version
#   - HY_APP_COMMIT: App commit hash
#   - HY_APP_PLATFORMS: Platforms to build for (e.g. "windows/amd64,linux/amd64,darwin/amd64")

if ! [ -x "$(command -v go)" ]; then
    echo 'Error: go is not installed.' >&2
    exit 1
fi

if ! [ -x "$(command -v git)" ]; then
    echo 'Error: git is not installed.' >&2
    exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo 'Error: not in a git repository.' >&2
    exit 1
fi

ldflags="-s -w -X 'main.appDate=$(date -u '+%F %T')'"
if [ -n "$HY_APP_VERSION" ]; then
    ldflags="$ldflags -X 'main.appVersion=$HY_APP_VERSION'"
else
    ldflags="$ldflags -X 'main.appVersion=$(git describe --tags --always)'"
fi
if [ -n "$HY_APP_COMMIT" ]; then
    ldflags="$ldflags -X 'main.appCommit=$HY_APP_COMMIT'"
else
    ldflags="$ldflags -X 'main.appCommit=$(git rev-parse HEAD)'"
fi

if [ -z "$HY_APP_PLATFORMS" ]; then
    HY_APP_PLATFORMS="$(go env GOOS)/$(go env GOARCH)"
fi
platforms=(${HY_APP_PLATFORMS//,/ })

mkdir -p build
rm -rf build/*

echo "Starting build..."

for platform in "${platforms[@]}"; do
    platform=(${platform//// })
    GOOS=${platform[0]}
    GOARCH=${platform[1]}
    if [ $GOARCH = "amd64" ]; then
        GOAMD64=${platform[2]}
        echo "Building $GOOS/$GOARCH/$GOAMD64"
        output="build/hysteria-$GOOS-$GOARCH-$GOAMD64"
    else
        echo "Building $GOOS/$GOARCH"
        output="build/hysteria-$GOOS-$GOARCH"
    fi
    if [ $GOOS = "windows" ]; then
        output="$output.exe"
    fi
    if [ $GOARCH = "amd64" ]; then
        env GOOS=$GOOS GOARCH=$GOARCH GOAMD64=$GOAMD64 CGO_ENABLED=0 go build -o $output -tags=gpl -ldflags "$ldflags" -trimpath ./app/cmd/
    else
        env GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 go build -o $output -tags=gpl -ldflags "$ldflags" -trimpath ./app/cmd/
    fi
    if [ $? -ne 0 ]; then
        if [ $GOARCH = "amd64" ]; then
            echo "Error: failed to build $GOOS/$GOARCH/$GOAMD64"
        else
            echo "Error: failed to build $GOOS/$GOARCH"
        fi
        exit 1
    fi
done

echo "Build complete."

ls -lh build/ | awk '{print $9, $5}'