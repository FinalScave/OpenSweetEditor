#!/bin/bash
# Arguments:
# -b, --build           Build directory
# -o, --output          Output directory
# -s, --src             SweetEditor project source directory
# -p, --platform        Target platform (all/android/windows/osx/ios/ohos/wasm; all means build everything)
# --android-ndk         Android NDK path
# --ohos-toolchain      OHOS toolchain CMake file path

# Parse arguments
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/prebuilt"
ANDROID_NDK="${ANDROID_NDK:-}"
OHOS_TOOLCHAIN="${OHOS_TOOLCHAIN:-}"
PLATFORM="all"
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--build)
      BUILD_DIR="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -s|--src)
      PROJECT_DIR="$2"
      shift 2
      ;;
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    --android-ndk)
      ANDROID_NDK="$2"
      shift 2
      ;;
    --ohos-toolchain)
      OHOS_TOOLCHAIN="$2"
      shift 2
      ;;
    -*|--*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}"

TARGET_NAME=sweeteditor
WASM_TARGET_NAMES=(sweeteditor_wasm_c_abi sweeteditor_wasm_embind)
APPLE_XCFRAMEWORK_IOS="SweetEditorCoreIOS.xcframework"
APPLE_XCFRAMEWORK_OSX="SweetEditorCoreOSX.xcframework"
echo "============================= Start building: $PLATFORM ============================="

function resolve_android_strip_tool() {
  local host_tags=("windows-x86_64" "linux-x86_64" "darwin-x86_64" "darwin-arm64")
  local tag
  for tag in "${host_tags[@]}"; do
    local bin_dir="$ANDROID_NDK/toolchains/llvm/prebuilt/$tag/bin"
    if [ -x "$bin_dir/llvm-strip" ]; then
      echo "$bin_dir/llvm-strip"
      return 0
    fi
    if [ -x "$bin_dir/llvm-strip.exe" ]; then
      echo "$bin_dir/llvm-strip.exe"
      return 0
    fi
  done
  return 1
}

function strip_android_outputs() {
  local target_dir="$1"
  local strip_tool="$2"
  [ -d "$target_dir" ] || return 0
  [ -n "$strip_tool" ] || return 0
  while IFS= read -r -d '' so_file; do
    "$strip_tool" --strip-unneeded "$so_file"
  done < <(find "$target_dir" -type f -name "*.so" -print0)
}

function copy_built_libraries() {
  local build_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  find "$build_dir" -type f \( -name "*.dll" -o -name "*.so" -o -name "*.dylib" -o -name "*.wasm" -o -name "*.js" \) -exec cp -f {} "$dest_dir/" \;
}

function copy_apple_dylib() {
  local build_dir="$1"
  local dest_dir="$2"
  local dylib_path=""
  local framework_binary_path=""
  local candidates=(
    "$build_dir/lib/libsweeteditor.dylib"
    "$build_dir/lib/Release/libsweeteditor.dylib"
    "$build_dir/lib/Release-iphoneos/libsweeteditor.dylib"
    "$build_dir/lib/Release-iphonesimulator/libsweeteditor.dylib"
    "$build_dir/Release/libsweeteditor.dylib"
    "$build_dir/Release-iphoneos/libsweeteditor.dylib"
    "$build_dir/Release-iphonesimulator/libsweeteditor.dylib"
  )

  mkdir -p "$dest_dir"

  for dylib_path in "${candidates[@]}"; do
    if [ -f "$dylib_path" ]; then
      cp -f "$dylib_path" "$dest_dir/"
      return 0
    fi
  done

  dylib_path="$(find "$build_dir" -type f -name "libsweeteditor.dylib" | head -n 1 || true)"
  if [ -n "$dylib_path" ]; then
    cp -f "$dylib_path" "$dest_dir/"
    return 0
  fi

  local framework_candidates=(
    "$build_dir/lib/Release/SweetEditorCore.framework/SweetEditorCore"
    "$build_dir/lib/Release/SweetEditorCore.framework/Versions/A/SweetEditorCore"
    "$build_dir/lib/SweetEditorCore.framework/SweetEditorCore"
    "$build_dir/lib/SweetEditorCore.framework/Versions/A/SweetEditorCore"
    "$build_dir/Release/SweetEditorCore.framework/SweetEditorCore"
    "$build_dir/Release/SweetEditorCore.framework/Versions/A/SweetEditorCore"
    "$build_dir/Release-iphoneos/SweetEditorCore.framework/SweetEditorCore"
    "$build_dir/Release-iphonesimulator/SweetEditorCore.framework/SweetEditorCore"
  )

  for framework_binary_path in "${framework_candidates[@]}"; do
    if [ -f "$framework_binary_path" ]; then
      cp -f "$framework_binary_path" "$dest_dir/libsweeteditor.dylib"
      return 0
    fi
  done

  framework_binary_path="$(find "$build_dir" -type f \( -path "*SweetEditorCore.framework/SweetEditorCore" -o -path "*SweetEditorCore.framework/Versions/A/SweetEditorCore" \) | head -n 1 || true)"
  if [ -n "$framework_binary_path" ]; then
    cp -f "$framework_binary_path" "$dest_dir/libsweeteditor.dylib"
    return 0
  fi

  echo "Apple dylib not found under $build_dir" >&2
  return 1
}

function copy_apple_static_lib() {
  local build_dir="$1"
  local dest_dir="$2"
  local static_lib_path=""
  local candidates=(
    "$build_dir/lib/libsweeteditor_static.a"
    "$build_dir/lib/Release/libsweeteditor_static.a"
    "$build_dir/lib/Release-iphoneos/libsweeteditor_static.a"
    "$build_dir/lib/Release-iphonesimulator/libsweeteditor_static.a"
    "$build_dir/Release/libsweeteditor_static.a"
    "$build_dir/Release-iphoneos/libsweeteditor_static.a"
    "$build_dir/Release-iphonesimulator/libsweeteditor_static.a"
  )

  mkdir -p "$dest_dir"

  for static_lib_path in "${candidates[@]}"; do
    if [ -f "$static_lib_path" ]; then
      cp -f "$static_lib_path" "$dest_dir/"
      return 0
    fi
  done

  static_lib_path="$(find "$build_dir" -type f -name "libsweeteditor_static.a" | head -n 1 || true)"
  if [ -n "$static_lib_path" ]; then
    cp -f "$static_lib_path" "$dest_dir/"
    return 0
  fi

  echo "Apple static library not found under $build_dir" >&2
  return 1
}

function copy_xcframework() {
  local platform="$1"
  local apple_binaries_dir="$2"
  local output_dir="$3"
  local xcframework_name
  local xcframework_dir
  local xcframework_zip

  case "$platform" in
    ios)
      xcframework_name="$APPLE_XCFRAMEWORK_IOS"
      ;;
    osx)
      xcframework_name="$APPLE_XCFRAMEWORK_OSX"
      ;;
    *)
      echo "Unknown platform: $platform" >&2
      return 1
      ;;
  esac

  xcframework_dir="${apple_binaries_dir}/${xcframework_name}"
  xcframework_zip="${output_dir}/${xcframework_name}.zip"

  if [ ! -d "$xcframework_dir" ]; then
    echo "XCFramework not found at $xcframework_dir" >&2
    return 1
  fi

  mkdir -p "$output_dir"
  rm -f "$xcframework_zip"
  (
    cd "$apple_binaries_dir"
    ditto -c -k --sequesterRsrc --keepParent "$xcframework_name" "$xcframework_zip"
  )
}

function build_windows_msvc() {
  echo "============================= Windows X64 ============================="
  WINDOWS_BUILD_DIR="$BUILD_DIR/windows"
  WINDOWS_PREBUILT_DIR="$OUTPUT_DIR/windows/x64"
  cmake $PROJECT_DIR \
    -B $WINDOWS_BUILD_DIR \
    -G "Visual Studio 17 2022" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_FLAGS="/std:c++17 /EHsc /utf-8" \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_TESTS=OFF
  cmake --build $WINDOWS_BUILD_DIR --target $TARGET_NAME -j 24 --config Release
  copy_built_libraries "$WINDOWS_BUILD_DIR/bin" "$WINDOWS_PREBUILT_DIR"
}

function build_osx() {
  OSX_ARCH=$1
  echo "============================= MacOSX $OSX_ARCH ============================="
  OSX_BUILD_DIR="$BUILD_DIR/osx/$OSX_ARCH"
  OSX_PREBUILT_DIR="$OUTPUT_DIR/osx/$OSX_ARCH"
  build_apple "$OSX_BUILD_DIR" "$OSX_PREBUILT_DIR" "macosx" "$OSX_ARCH" "$TARGET_NAME" "Xcode" "" ON OFF dylib
}

function build_apple() {
  local apple_build_dir="$1"
  local apple_prebuilt_dir="$2"
  local apple_sysroot="$3"
  local apple_arch="$4"
  local apple_target_name="$5"
  local apple_generator="$6"
  local apple_system_name="$7"
  local build_shared_lib="$8"
  local build_static_lib="$9"
  local copy_mode="${10}"
  shift 10

  local cmake_args=(
    "$PROJECT_DIR"
    -B "$apple_build_dir"
    -G "$apple_generator"
    -DCMAKE_CXX_FLAGS=-std=c++17
    -DCMAKE_BUILD_TYPE=Release
    -DSWEETEDITOR_BUILD_SHARED="$build_shared_lib"
    -DSWEETEDITOR_BUILD_STATIC="$build_static_lib"
    -DSWEETEDITOR_BUILD_TESTS=OFF
    -DCMAKE_OSX_SYSROOT="$apple_sysroot"
    -DCMAKE_OSX_ARCHITECTURES="$apple_arch"
  )

  if [ -n "$apple_system_name" ]; then
    cmake_args+=( -DCMAKE_SYSTEM_NAME="$apple_system_name" )
  fi

  if [ $# -gt 0 ]; then
    cmake_args+=( "$@" )
  fi

  cmake "${cmake_args[@]}"

  cmake --build "$apple_build_dir" --target "$apple_target_name" -j 12

  case "$copy_mode" in
    dylib)
      copy_apple_dylib "$apple_build_dir" "$apple_prebuilt_dir"
      ;;
    static)
      copy_apple_static_lib "$apple_build_dir" "$apple_prebuilt_dir"
      ;;
    *)
      echo "Unknown Apple copy mode: $copy_mode" >&2
      return 1
      ;;
  esac
}

function build_ios() {
  IOS_TARGET=$1
  if [[ "$IOS_TARGET" == simulator-* ]]; then
    IOS_VARIANT="simulator"
    IOS_ARCH="${IOS_TARGET#simulator-}"
    IOS_SDK="iphonesimulator"
    IOS_PREBUILT_DIR="$OUTPUT_DIR/ios/$IOS_TARGET"
  else
    IOS_VARIANT="ios"
    IOS_ARCH="$IOS_TARGET"
    IOS_SDK="iphoneos"
    IOS_PREBUILT_DIR="$OUTPUT_DIR/ios/$IOS_ARCH"
    rm -rf "$OUTPUT_DIR/ios/device-$IOS_ARCH"
  fi
  echo "============================= iOS $IOS_VARIANT $IOS_ARCH ============================="
  IOS_BUILD_DIR="$BUILD_DIR/ios-xcode/$IOS_TARGET"
  build_apple "$IOS_BUILD_DIR" "$IOS_PREBUILT_DIR" "$IOS_SDK" "$IOS_ARCH" "$TARGET_NAME" "Xcode" "iOS" \
    ON \
    OFF \
    dylib \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY= \
    -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=
}

function build_ios_static() {
  IOS_TARGET=$1
  if [[ "$IOS_TARGET" == simulator-* ]]; then
    IOS_VARIANT="simulator"
    IOS_ARCH="${IOS_TARGET#simulator-}"
    IOS_SDK="iphonesimulator"
    IOS_PREBUILT_DIR="$OUTPUT_DIR/ios/$IOS_TARGET"
  else
    IOS_VARIANT="ios"
    IOS_ARCH="$IOS_TARGET"
    IOS_SDK="iphoneos"
    IOS_PREBUILT_DIR="$OUTPUT_DIR/ios/$IOS_ARCH"
  fi
  echo "============================= iOS $IOS_VARIANT $IOS_ARCH static ============================="
  IOS_BUILD_DIR="$BUILD_DIR/ios-xcode-static/$IOS_TARGET"
  build_apple "$IOS_BUILD_DIR" "$IOS_PREBUILT_DIR" "$IOS_SDK" "$IOS_ARCH" "${TARGET_NAME}_static" "Xcode" "iOS" \
    OFF \
    ON \
    static \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY= \
    -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=
}

function build_ios_xcframework() {
  local ios_output_dir="$OUTPUT_DIR/ios"

  echo "============================= iOS XCFramework ============================="
  mkdir -p "$ios_output_dir"
  bash "$PROJECT_DIR/platform/Apple/scripts/build_native_xcframework.sh" ios
  copy_xcframework ios "$PROJECT_DIR/platform/Apple/binaries" "$ios_output_dir"
}

function build_osx_xcframework() {
  local osx_output_dir="$OUTPUT_DIR/osx"

  echo "============================= macOS XCFramework ============================="
  mkdir -p "$osx_output_dir"
  bash "$PROJECT_DIR/platform/Apple/scripts/build_native_xcframework.sh" osx
  copy_xcframework osx "$PROJECT_DIR/platform/Apple/binaries" "$osx_output_dir"
}

function build_linux() {
    local linux_arch="$1"
    local linux_build_dir="$BUILD_DIR/linux/$linux_arch"
    local linux_prebuilt_dir=""
    local linux_toolchain_args=()

    if [ "$linux_arch" = "aarch64" ]; then
      linux_prebuilt_dir="$OUTPUT_DIR/linux/aarch64"
      command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || {
        echo "Missing aarch64-linux-gnu-gcc. Install gcc-aarch64-linux-gnu."
        return 1
      }
      command -v aarch64-linux-gnu-g++ >/dev/null 2>&1 || {
        echo "Missing aarch64-linux-gnu-g++. Install g++-aarch64-linux-gnu."
        return 1
      }
      linux_toolchain_args+=("-DCMAKE_TOOLCHAIN_FILE=$PROJECT_DIR/cmake/linux-aarch64-toolchain.cmake")
    elif [ "$linux_arch" = "x86_64" ]; then
      linux_prebuilt_dir="$OUTPUT_DIR/linux/x86_64"
    else
      echo "Unsupported arch: $linux_arch"
      return 1
    fi

    cmake "$PROJECT_DIR" \
      -B "$linux_build_dir" \
      -G "Ninja" \
      -DCMAKE_CXX_FLAGS="-std=c++17 -fPIC" \
      -DCMAKE_BUILD_TYPE=Release \
      -DSWEETEDITOR_BUILD_STATIC=OFF \
      -DSWEETEDITOR_BUILD_TESTS=OFF \
      "${linux_toolchain_args[@]}"
    cmake --build "$linux_build_dir" --target "$TARGET_NAME" -j 12
    copy_built_libraries "$linux_build_dir/lib" "$linux_prebuilt_dir"
}

function build_emscripten() {
  echo "============================= WebAssembly ============================="
  WASM_BUILD_DIR="$BUILD_DIR/emscripten"
  WASM_PREBUILT_DIR="$OUTPUT_DIR/wasm"
  local emcmake_cmd=""
  if command -v emcmake >/dev/null 2>&1; then
    emcmake_cmd="emcmake"
  elif command -v emcmake.bat >/dev/null 2>&1; then
    emcmake_cmd="emcmake.bat"
  else
    echo "emcmake not found. Please activate Emscripten SDK environment first."
    return 1
  fi
  $emcmake_cmd cmake $PROJECT_DIR\
    -B $WASM_BUILD_DIR \
    -G "Ninja" \
    -DCMAKE_CXX_FLAGS="-std=c++17" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_TESTS=OFF || return 1
  cmake --build $WASM_BUILD_DIR --target "${WASM_TARGET_NAMES[@]}" -j 24 || return 1
  copy_built_libraries "$WASM_BUILD_DIR/bin" "$WASM_PREBUILT_DIR"
}

function build_android() {
  ANDROID_ARCH=$1
  if [ -z "$ANDROID_NDK" ]; then
    echo "ANDROID_NDK is not set. Use --android-ndk or export ANDROID_NDK."
    exit 1
  fi
  echo "============================= Android $ANDROID_ARCH ============================="
  echo "============================= NDK: $ANDROID_NDK ============================="
  ANDROID_BUILD_DIR="$BUILD_DIR/android/$ANDROID_ARCH"
  ANDROID_PREBUILT_DIR="$OUTPUT_DIR/android/$ANDROID_ARCH"
  cmake $PROJECT_DIR \
    -B $ANDROID_BUILD_DIR \
    -G "Ninja" \
    -DANDROID_ABI=$ANDROID_ARCH \
    -DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ARCH \
    -DANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_ANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_CXX_FLAGS="-std=c++17" \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_TESTS=OFF
  cmake --build $ANDROID_BUILD_DIR --target $TARGET_NAME -j 24

  local strip_tool
  strip_tool=$(resolve_android_strip_tool)
  if [ -n "$strip_tool" ]; then
    echo "============================= Stripping Android .so ($ANDROID_ARCH) ============================="
    echo "============================= Strip Tool: $strip_tool ============================="
    strip_android_outputs "$ANDROID_BUILD_DIR" "$strip_tool"
    copy_built_libraries "$ANDROID_BUILD_DIR" "$ANDROID_PREBUILT_DIR"
  else
    echo "Error: llvm-strip not found under ANDROID_NDK=$ANDROID_NDK, cannot stripping."
    return 1
  fi
}

function build_ohos() {
  OHOS_ARCH=$1
  if [ -z "$OHOS_TOOLCHAIN" ]; then
    echo "OHOS_TOOLCHAIN is not set. Use --ohos-toolchain or export OHOS_TOOLCHAIN."
    exit 1
  fi
  echo "============================= OHOS $OHOS_ARCH ============================="
  echo "============================= Toolchain: $OHOS_TOOLCHAIN ============================="
  OHOS_BUILD_DIR="$BUILD_DIR/ohos/$OHOS_ARCH"
  OHOS_PREBUILT_DIR="$OUTPUT_DIR/ohos/$OHOS_ARCH"
  cmake $PROJECT_DIR \
    -B $OHOS_BUILD_DIR \
    -G "Ninja" \
    -DOHOS_PLATFORM=OHOS \
    -DOHOS_ARCH=$OHOS_ARCH \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$OHOS_TOOLCHAIN" \
    -DCMAKE_CXX_FLAGS="-std=c++17" \
    -DSWEETEDITOR_BUILD_STATIC=OFF \
    -DSWEETEDITOR_BUILD_TESTS=OFF
  cmake --build $OHOS_BUILD_DIR --target $TARGET_NAME -j 24
  copy_built_libraries "$OHOS_BUILD_DIR/lib" "$OHOS_PREBUILT_DIR"
}

if [ $PLATFORM = "all" ]; then
  build_windows_msvc
  build_osx arm64
  build_osx x86_64
  build_ios arm64
  build_ios_static arm64
  build_ios simulator-arm64
  build_ios_static simulator-arm64
  build_ios_xcframework
  build_osx_xcframework
  build_linux x86_64
  build_linux aarch64
  build_emscripten
  build_android arm64-v8a
  build_android x86_64
  build_ohos arm64-v8a
  build_ohos x86_64
elif [ $PLATFORM = "wasm" ]; then
  build_emscripten
elif [ $PLATFORM = "windows" ]; then
  build_windows_msvc
elif [ $PLATFORM = "osx" ]; then
  build_osx arm64
  build_osx x86_64
  build_osx_xcframework
elif [ $PLATFORM = "ios" ]; then
  build_ios arm64
  build_ios_static arm64
  build_ios simulator-arm64
  build_ios_static simulator-arm64
  build_ios_xcframework
elif [ $PLATFORM = "osx" ]; then
  build_osx arm64
  build_osx x86_64
  build_osx_xcframework
elif [ $PLATFORM = "linux" ]; then
  build_linux x86_64
  build_linux aarch64
elif [ $PLATFORM = "android" ]; then
  build_android arm64-v8a
  build_android x86_64
elif [ $PLATFORM = "ohos" ]; then
  build_ohos arm64-v8a
  build_ohos x86_64
fi
