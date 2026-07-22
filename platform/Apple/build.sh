#!/usr/bin/env bash
set -euo pipefail

APPLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
NATIVE_OUTPUT_DIR="${APPLE_DIR}/.build-local"
IOS_OUTPUT="${NATIVE_OUTPUT_DIR}/SweetEditorCoreIOS.xcframework"
MACOS_OUTPUT="${NATIVE_OUTPUT_DIR}/SweetEditorCoreMacOS.xcframework"
IOS_DEVICE_BUILD_DIR="${REPO_ROOT}/build/apple-ios-device"
IOS_SIM_BUILD_DIR="${REPO_ROOT}/build/apple-ios-simulator"
MACOS_BUILD_DIR="${REPO_ROOT}/build/apple-macos"
MACOS_X64_BUILD_DIR="${REPO_ROOT}/build/apple-macos-x86_64"
MACOS_UNIVERSAL_BUILD_DIR="${REPO_ROOT}/build/apple-macos-universal"
IOS_FRAMEWORK_NAME="SweetEditorCoreIOS.framework"
IOS_FRAMEWORK_TARGET="SweetEditorCoreIOS"
MACOS_FRAMEWORK_NAME="SweetEditorCoreMacOS.framework"
MACOS_FRAMEWORK_BINARY_NAME="SweetEditorCoreMacOS"
MACOS_FRAMEWORK_TARGET="SweetEditorCoreMacOS"
IOS_DEPLOYMENT_TARGET="14.0"
MACOS_DEPLOYMENT_TARGET="11.0"

function usage() {
  cat <<'EOF'
Usage: bash ./build.sh <command> [platform]

Commands:
  native [ios|macos|all]           Rebuild native XCFrameworks
  native-if-needed [ios|macos|all] Rebuild native XCFrameworks when inputs changed
  build                            Build the Swift Package
  verify                           Describe and build the Swift Package
  all                              Refresh native artifacts and verify the package
  demo-macos-build                 Build the macOS demos
  demo-macos-run                   Run the AppKit macOS demo
  demo-macos-run-swiftui           Run the SwiftUI macOS demo
  clean                            Remove Apple build outputs
EOF
}

function configure_apple_build() {
  local build_dir="$1"
  local deployment_target="$2"
  shift 2

  cmake -S "${REPO_ROOT}" -B "${build_dir}" -G Xcode \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
    -DSWEETEDITOR_BUILD_TESTS=OFF \
    -DSWEETEDITOR_BUILD_SHARED=ON \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_APPLE_FRAMEWORK=ON \
    -DSWEETEDITOR_APPLE_STATIC_FRAMEWORK=OFF \
    "$@"
}

function locate_framework_dir() {
  local build_dir="$1"
  local framework_name="$2"
  local path
  local candidates=(
    "${build_dir}/Release/${framework_name}"
    "${build_dir}/lib/Release/${framework_name}"
    "${build_dir}/Release-iphoneos/${framework_name}"
    "${build_dir}/Release-iphonesimulator/${framework_name}"
    "${build_dir}/Release-macos/${framework_name}"
    "${build_dir}/lib/Release-iphoneos/${framework_name}"
    "${build_dir}/lib/Release-iphonesimulator/${framework_name}"
    "${build_dir}/lib/Release/${framework_name}"
    "${build_dir}/lib/${framework_name}"
  )

  for path in "${candidates[@]}"; do
    if [[ -d "${path}" ]]; then
      printf '%s\n' "${path}"
      return 0
    fi
  done

  path="$(find "${build_dir}" -type d -name "${framework_name}" | head -n 1 || true)"
  if [[ -n "${path}" ]]; then
    printf '%s\n' "${path}"
    return 0
  fi

  return 1
}

function locate_framework_binary() {
  local framework_dir="$1"
  local framework_binary_name="$2"
  local direct_binary="${framework_dir}/${framework_binary_name}"
  local versioned_binary="${framework_dir}/Versions/A/${framework_binary_name}"

  if [[ -f "${versioned_binary}" ]]; then
    printf '%s\n' "${versioned_binary}"
    return 0
  fi

  if [[ -f "${direct_binary}" ]]; then
    printf '%s\n' "${direct_binary}"
    return 0
  fi

  return 1
}

function make_universal_macos_framework() {
  local arm_framework_dir="$1"
  local x64_framework_dir="$2"
  local universal_framework_dir="$3"
  local framework_binary_name="$4"
  local arm_binary
  local x64_binary
  local universal_binary

  rm -rf "${universal_framework_dir}"
  mkdir -p "$(dirname "${universal_framework_dir}")"
  cp -R "${arm_framework_dir}" "${universal_framework_dir}"

  arm_binary="$(locate_framework_binary "${arm_framework_dir}" "${framework_binary_name}")"
  x64_binary="$(locate_framework_binary "${x64_framework_dir}" "${framework_binary_name}")"
  universal_binary="$(locate_framework_binary "${universal_framework_dir}" "${framework_binary_name}")"

  lipo -create "${arm_binary}" "${x64_binary}" -output "${universal_binary}"
  codesign --force --sign - "${universal_framework_dir}"
}

function build_native_ios() {
  local device_framework
  local simulator_framework

  mkdir -p "$(dirname "${IOS_OUTPUT}")"

  configure_apple_build "${IOS_DEVICE_BUILD_DIR}" "${IOS_DEPLOYMENT_TARGET}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64
  cmake --build "${IOS_DEVICE_BUILD_DIR}" --target "${IOS_FRAMEWORK_TARGET}" --config Release

  configure_apple_build "${IOS_SIM_BUILD_DIR}" "${IOS_DEPLOYMENT_TARGET}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64
  cmake --build "${IOS_SIM_BUILD_DIR}" --target "${IOS_FRAMEWORK_TARGET}" --config Release

  device_framework="$(locate_framework_dir "${IOS_DEVICE_BUILD_DIR}" "${IOS_FRAMEWORK_NAME}")"
  simulator_framework="$(locate_framework_dir "${IOS_SIM_BUILD_DIR}" "${IOS_FRAMEWORK_NAME}")"

  rm -rf "${IOS_OUTPUT}"
  xcodebuild -create-xcframework \
    -framework "${device_framework}" \
    -framework "${simulator_framework}" \
    -output "${IOS_OUTPUT}"

  echo "Generated ${IOS_OUTPUT}"
}

function build_native_macos() {
  local arm_framework
  local x64_framework
  local universal_framework="${MACOS_UNIVERSAL_BUILD_DIR}/${MACOS_FRAMEWORK_NAME}"

  mkdir -p "$(dirname "${MACOS_OUTPUT}")"

  configure_apple_build "${MACOS_BUILD_DIR}" "${MACOS_DEPLOYMENT_TARGET}" -DCMAKE_OSX_ARCHITECTURES=arm64
  cmake --build "${MACOS_BUILD_DIR}" --target "${MACOS_FRAMEWORK_TARGET}" --config Release

  configure_apple_build "${MACOS_X64_BUILD_DIR}" "${MACOS_DEPLOYMENT_TARGET}" -DCMAKE_OSX_ARCHITECTURES=x86_64
  cmake --build "${MACOS_X64_BUILD_DIR}" --target "${MACOS_FRAMEWORK_TARGET}" --config Release

  arm_framework="$(locate_framework_dir "${MACOS_BUILD_DIR}" "${MACOS_FRAMEWORK_NAME}")"
  x64_framework="$(locate_framework_dir "${MACOS_X64_BUILD_DIR}" "${MACOS_FRAMEWORK_NAME}")"
  make_universal_macos_framework \
    "${arm_framework}" \
    "${x64_framework}" \
    "${universal_framework}" \
    "${MACOS_FRAMEWORK_BINARY_NAME}"

  rm -rf "${MACOS_OUTPUT}"
  xcodebuild -create-xcframework \
    -framework "${universal_framework}" \
    -output "${MACOS_OUTPUT}"

  echo "Generated ${MACOS_OUTPUT}"
}

function build_native() {
  case "$1" in
    ios)
      build_native_ios
      ;;
    macos)
      build_native_macos
      ;;
    all)
      build_native_ios
      build_native_macos
      ;;
    *)
      echo "Unknown platform: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

function native_inputs_changed() {
  local marker="$1"

  if [[ ! -f "${marker}" ]]; then
    return 0
  fi

  if [[ "${REPO_ROOT}/CMakeLists.txt" -nt "${marker}" || "${APPLE_DIR}/build.sh" -nt "${marker}" ]]; then
    return 0
  fi

  if find "${REPO_ROOT}/src" "${REPO_ROOT}/include" "${REPO_ROOT}/cmake" "${REPO_ROOT}/3dparty/simdutf" \
    -type f -newer "${marker}" -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

function build_native_if_needed() {
  local platform="$1"
  local output

  if [[ "${platform}" == "all" ]]; then
    build_native_if_needed ios
    build_native_if_needed macos
    return
  fi

  case "${platform}" in
    ios)
      output="${IOS_OUTPUT}"
      ;;
    macos)
      output="${MACOS_OUTPUT}"
      ;;
    *)
      echo "Unknown platform: ${platform}" >&2
      usage >&2
      exit 1
      ;;
  esac

  if [[ "${SWEETEDITOR_FORCE_NATIVE:-0}" == "1" ]] || native_inputs_changed "${output}/Info.plist"; then
    build_native "${platform}"
  else
    echo "${output} is up-to-date"
  fi
}

function build_package() {
  build_native_if_needed all
  (cd "${APPLE_DIR}" && swift build)
}

function verify_package() {
  build_native_if_needed all
  (cd "${APPLE_DIR}" && swift package describe >/dev/null && swift build)
}

function run_macos_demo() {
  local action="$1"
  local module_cache="${APPLE_DIR}/Demo-macOS/.build/module-cache"
  local command=(swift)

  build_native_if_needed all
  mkdir -p "${module_cache}"

  case "${action}" in
    build)
      command+=(build --disable-sandbox)
      ;;
    appkit)
      command+=(run --disable-sandbox SweetEditorMacDemo)
      ;;
    swiftui)
      command+=(run --disable-sandbox SweetEditorMacDemoSwiftUI)
      ;;
  esac

  (
    cd "${APPLE_DIR}/Demo-macOS"
    SWIFT_MODULECACHE_PATH="${module_cache}" \
      CLANG_MODULE_CACHE_PATH="${module_cache}" \
      "${command[@]}"
  )
}

function clean_outputs() {
  rm -rf \
    "${APPLE_DIR}/.build" \
    "${APPLE_DIR}/.build-local" \
    "${APPLE_DIR}/Demo-macOS/.build" \
    "${IOS_DEVICE_BUILD_DIR}" \
    "${IOS_SIM_BUILD_DIR}" \
    "${MACOS_BUILD_DIR}" \
    "${MACOS_X64_BUILD_DIR}" \
    "${MACOS_UNIVERSAL_BUILD_DIR}"
}

COMMAND="${1:-}"
PLATFORM="${2:-all}"

case "${COMMAND}" in
  native)
    build_native "${PLATFORM}"
    ;;
  native-if-needed)
    build_native_if_needed "${PLATFORM}"
    ;;
  build)
    build_package
    ;;
  verify)
    verify_package
    ;;
  all)
    verify_package
    ;;
  demo-macos-build)
    run_macos_demo build
    ;;
  demo-macos-run)
    run_macos_demo appkit
    ;;
  demo-macos-run-swiftui)
    run_macos_demo swiftui
    ;;
  clean)
    clean_outputs
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
