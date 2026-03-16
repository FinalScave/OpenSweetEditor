#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build/apple-macos"
OUTPUT_DIR="${APPLE_DIR}/binaries"
OUTPUT_XCFRAMEWORK="${OUTPUT_DIR}/SweetNativeCore.xcframework"
LIB_PATH="${BUILD_DIR}/lib/libsweeteditor_static.a"

mkdir -p "${OUTPUT_DIR}"

cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_TESTING=OFF \
  -DBUILD_SHARED_LIB=OFF \
  -DBUILD_STATIC_LIB=ON

cmake --build "${BUILD_DIR}" --config Release

if [[ ! -f "${LIB_PATH}" ]]; then
  echo "Native static library not found at ${LIB_PATH}" >&2
  exit 1
fi

rm -rf "${OUTPUT_XCFRAMEWORK}"
xcodebuild -create-xcframework \
  -library "${LIB_PATH}" \
  -headers "${REPO_ROOT}/src/include" \
  -output "${OUTPUT_XCFRAMEWORK}"

echo "Generated ${OUTPUT_XCFRAMEWORK}"
