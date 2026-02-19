#!/bin/sh
# Auto-dispatch to the correct architecture-specific binary.
# Place alongside blackdot-linux-amd64 and blackdot-linux-arm64.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64)  ARCH=amd64 ;;
    arm64|aarch64)  ARCH=arm64 ;;
    *)  echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

BINARY="${SCRIPT_DIR}/blackdot-${OS}-${ARCH}"

if [ ! -x "$BINARY" ]; then
    echo "blackdot: binary not found for ${OS}/${ARCH}" >&2
    echo "expected: $BINARY" >&2
    echo "run 'make build-linux' (or build-all) to compile both architectures" >&2
    exit 1
fi

exec "$BINARY" "$@"
