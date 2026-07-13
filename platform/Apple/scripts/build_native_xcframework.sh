#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
MACOS_BUILD_DIR="${REPO_ROOT}/build/apple-macos"
MACOS_X64_BUILD_DIR="${REPO_ROOT}/build/apple-macos-x86_64"
MACOS_UNIVERSAL_BUILD_DIR="${REPO_ROOT}/build/apple-macos-universal"
IOS_DEVICE_BUILD_DIR="${REPO_ROOT}/build/apple-ios-device"
IOS_SIM_BUILD_DIR="${REPO_ROOT}/build/apple-ios-simulator"
OUTPUT_DIR="${APPLE_DIR}/binaries"
OUTPUT_XCFRAMEWORK_IOS="${OUTPUT_DIR}/SweetEditorCoreIOS.xcframework"
OUTPUT_XCFRAMEWORK_OSX="${OUTPUT_DIR}/SweetEditorCoreOSX.xcframework"
FRAMEWORK_NAME="SweetEditorCore.framework"
FRAMEWORK_BINARY_NAME="SweetEditorCore"
FRAMEWORK_TARGET="SweetEditorCore"

# Parse argument: "ios", "osx", or empty (build both)
BUILD_TARGET="${1:-all}"

mkdir -p "${OUTPUT_DIR}"

function configure_apple_build() {
  local build_dir="$1"
  shift

  cmake -S "${REPO_ROOT}" -B "${build_dir}" -G Xcode \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DSWEETEDITOR_BUILD_TESTS=OFF \
    -DSWEETEDITOR_BUILD_SHARED=ON \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_APPLE_FRAMEWORK=ON \
    -DSWEETEDITOR_APPLE_STATIC_FRAMEWORK=OFF \
    "$@"
}

function locate_framework_dir() {
  local build_dir="$1"
  local path
  local candidates=(
    "${build_dir}/Release/${FRAMEWORK_NAME}"
    "${build_dir}/lib/Release/${FRAMEWORK_NAME}"
    "${build_dir}/Release-iphoneos/${FRAMEWORK_NAME}"
    "${build_dir}/Release-iphonesimulator/${FRAMEWORK_NAME}"
    "${build_dir}/Release-macos/${FRAMEWORK_NAME}"
    "${build_dir}/lib/Release-iphoneos/${FRAMEWORK_NAME}"
    "${build_dir}/lib/Release-iphonesimulator/${FRAMEWORK_NAME}"
    "${build_dir}/lib/Release/${FRAMEWORK_NAME}"
    "${build_dir}/lib/${FRAMEWORK_NAME}"
  )

  for path in "${candidates[@]}"; do
    if [[ -d "${path}" ]]; then
      printf '%s\n' "${path}"
      return 0
    fi
  done

  path="$(find "${build_dir}" -type d -name "${FRAMEWORK_NAME}" | head -n 1 || true)"
  if [[ -n "${path}" ]]; then
    printf '%s\n' "${path}"
    return 0
  fi

  return 1
}

function locate_framework_binary() {
  local framework_dir="$1"
  local direct_binary="${framework_dir}/${FRAMEWORK_BINARY_NAME}"
  local versioned_binary="${framework_dir}/Versions/A/${FRAMEWORK_BINARY_NAME}"

  if [[ -f "${direct_binary}" ]]; then
    printf '%s\n' "${direct_binary}"
    return 0
  fi

  if [[ -f "${versioned_binary}" ]]; then
    printf '%s\n' "${versioned_binary}"
    return 0
  fi

  return 1
}

function make_universal_macos_framework() {
  local arm_framework_dir="$1"
  local x64_framework_dir="$2"
  local universal_framework_dir="$3"
  local arm_binary
  local x64_binary
  local universal_binary

  rm -rf "${universal_framework_dir}"
  mkdir -p "$(dirname "${universal_framework_dir}")"
  cp -R "${arm_framework_dir}" "${universal_framework_dir}"

  arm_binary="$(locate_framework_binary "${arm_framework_dir}")"
  x64_binary="$(locate_framework_binary "${x64_framework_dir}")"
  universal_binary="$(locate_framework_binary "${universal_framework_dir}")"

  lipo -create "${arm_binary}" "${x64_binary}" -output "${universal_binary}"
}

function build_ios() {
  configure_apple_build "${IOS_DEVICE_BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64

  cmake --build "${IOS_DEVICE_BUILD_DIR}" --target "${FRAMEWORK_TARGET}" --config Release

  configure_apple_build "${IOS_SIM_BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64

  cmake --build "${IOS_SIM_BUILD_DIR}" --target "${FRAMEWORK_TARGET}" --config Release

  IOS_DEVICE_FRAMEWORK_PATH="$(locate_framework_dir "${IOS_DEVICE_BUILD_DIR}")"
  IOS_SIM_FRAMEWORK_PATH="$(locate_framework_dir "${IOS_SIM_BUILD_DIR}")"

  if [[ ! -d "${IOS_DEVICE_FRAMEWORK_PATH}" ]]; then
    echo "Native iOS device framework not found under ${IOS_DEVICE_BUILD_DIR}" >&2
    exit 1
  fi

  if [[ ! -d "${IOS_SIM_FRAMEWORK_PATH}" ]]; then
    echo "Native iOS simulator framework not found under ${IOS_SIM_BUILD_DIR}" >&2
    exit 1
  fi

  rm -rf "${OUTPUT_XCFRAMEWORK_IOS}"

  # Create iOS XCFramework (Device + Simulator)
  xcodebuild -create-xcframework \
    -framework "${IOS_DEVICE_FRAMEWORK_PATH}" \
    -framework "${IOS_SIM_FRAMEWORK_PATH}" \
    -output "${OUTPUT_XCFRAMEWORK_IOS}"

  echo "Generated ${OUTPUT_XCFRAMEWORK_IOS}"
}

function build_osx() {
  configure_apple_build "${MACOS_BUILD_DIR}" \
    -DCMAKE_OSX_ARCHITECTURES=arm64

  cmake --build "${MACOS_BUILD_DIR}" --target "${FRAMEWORK_TARGET}" --config Release

  configure_apple_build "${MACOS_X64_BUILD_DIR}" \
    -DCMAKE_OSX_ARCHITECTURES=x86_64

  cmake --build "${MACOS_X64_BUILD_DIR}" --target "${FRAMEWORK_TARGET}" --config Release

  MACOS_FRAMEWORK_PATH="$(locate_framework_dir "${MACOS_BUILD_DIR}")"
  MACOS_X64_FRAMEWORK_PATH="$(locate_framework_dir "${MACOS_X64_BUILD_DIR}")"

  if [[ ! -d "${MACOS_FRAMEWORK_PATH}" ]]; then
    echo "Native macOS framework not found under ${MACOS_BUILD_DIR}" >&2
    exit 1
  fi

  if [[ ! -d "${MACOS_X64_FRAMEWORK_PATH}" ]]; then
    echo "Native macOS x86_64 framework not found under ${MACOS_X64_BUILD_DIR}" >&2
    exit 1
  fi

  MACOS_UNIVERSAL_FRAMEWORK_PATH="${MACOS_UNIVERSAL_BUILD_DIR}/${FRAMEWORK_NAME}"
  make_universal_macos_framework \
    "${MACOS_FRAMEWORK_PATH}" \
    "${MACOS_X64_FRAMEWORK_PATH}" \
    "${MACOS_UNIVERSAL_FRAMEWORK_PATH}"

  rm -rf "${OUTPUT_XCFRAMEWORK_OSX}"

  # Create macOS XCFramework (Universal)
  xcodebuild -create-xcframework \
    -framework "${MACOS_UNIVERSAL_FRAMEWORK_PATH}" \
    -output "${OUTPUT_XCFRAMEWORK_OSX}"

  echo "Generated ${OUTPUT_XCFRAMEWORK_OSX}"
}

# Main execution
case "${BUILD_TARGET}" in
  ios)
    build_ios
    ;;
  osx)
    build_osx
    ;;
  all|"")
    build_ios
    build_osx
    ;;
  *)
    echo "Unknown target: ${BUILD_TARGET}" >&2
    echo "Usage: $0 [ios|osx|all]" >&2
    exit 1
    ;;
esac
