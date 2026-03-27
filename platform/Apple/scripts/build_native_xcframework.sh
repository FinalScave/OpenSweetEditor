#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
MACOS_BUILD_DIR="${REPO_ROOT}/build/apple-macos"
IOS_DEVICE_BUILD_DIR="${REPO_ROOT}/build/apple-ios-device"
IOS_SIM_BUILD_DIR="${REPO_ROOT}/build/apple-ios-simulator"
OUTPUT_DIR="${APPLE_DIR}/binaries"
OUTPUT_XCFRAMEWORK="${OUTPUT_DIR}/SweetNativeCore.xcframework"
MACOS_LIB_PATH="${MACOS_BUILD_DIR}/lib/libsweeteditor_static.a"
IOS_DEVICE_LIB_PATH="${IOS_DEVICE_BUILD_DIR}/lib/Release/libsweeteditor_static.a"
IOS_SIM_LIB_PATH="${IOS_SIM_BUILD_DIR}/lib/Release/libsweeteditor_static.a"

mkdir -p "${OUTPUT_DIR}"

cmake -S "${REPO_ROOT}" -B "${MACOS_BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_TESTING=OFF \
  -DBUILD_SHARED_LIB=OFF \
  -DBUILD_STATIC_LIB=ON

cmake --build "${MACOS_BUILD_DIR}" --config Release

cmake -S "${REPO_ROOT}" -B "${IOS_DEVICE_BUILD_DIR}" \
  -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_TESTING=OFF \
  -DBUILD_SHARED_LIB=OFF \
  -DBUILD_STATIC_LIB=ON

cmake --build "${IOS_DEVICE_BUILD_DIR}" --config Release

cmake -S "${REPO_ROOT}" -B "${IOS_SIM_BUILD_DIR}" \
  -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_TESTING=OFF \
  -DBUILD_SHARED_LIB=OFF \
  -DBUILD_STATIC_LIB=ON

cmake --build "${IOS_SIM_BUILD_DIR}" --config Release

if [[ ! -f "${MACOS_LIB_PATH}" ]]; then
  echo "Native macOS static library not found at ${MACOS_LIB_PATH}" >&2
  exit 1
fi

if [[ ! -f "${IOS_DEVICE_LIB_PATH}" ]]; then
  echo "Native iOS device static library not found at ${IOS_DEVICE_LIB_PATH}" >&2
  exit 1
fi

if [[ ! -f "${IOS_SIM_LIB_PATH}" ]]; then
  echo "Native iOS simulator static library not found at ${IOS_SIM_LIB_PATH}" >&2
  exit 1
fi

rm -rf "${OUTPUT_XCFRAMEWORK}"
xcodebuild -create-xcframework \
  -library "${MACOS_LIB_PATH}" \
  -headers "${REPO_ROOT}/src/include" \
  -library "${IOS_DEVICE_LIB_PATH}" \
  -headers "${REPO_ROOT}/src/include" \
  -library "${IOS_SIM_LIB_PATH}" \
  -headers "${REPO_ROOT}/src/include" \
  -output "${OUTPUT_XCFRAMEWORK}"

echo "Generated ${OUTPUT_XCFRAMEWORK}"
