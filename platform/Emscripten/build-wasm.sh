#!/usr/bin/env bash
set -euo pipefail

BUILD_TYPE="${1:-Release}"
BUILD_DIR="${2:-build/wasm}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if command -v emcmake >/dev/null 2>&1; then
  EMCMAKE="emcmake"
else
  echo "emcmake not found. Please activate emsdk first." >&2
  exit 1
fi

cmake -E make_directory "$REPO_ROOT/$BUILD_DIR"
$EMCMAKE cmake -S "$REPO_ROOT" -B "$REPO_ROOT/$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$REPO_ROOT/$BUILD_DIR"

echo "Wasm build done: $REPO_ROOT/$BUILD_DIR/bin/sweeteditor.js"
