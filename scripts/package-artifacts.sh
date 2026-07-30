#!/usr/bin/env bash

set -euo pipefail

VERSION=""
PREBUILT_SOURCE_DIR=""
HEADERS_SOURCE_DIR=""
OUTPUT_DIR=""
COMMIT=""
RELEASE_NOTES_TEMPLATE=""
SKIP_RELEASE_NOTES=0
FORCE=0
TEMP_ROOT=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIRED_PLATFORMS=(android ios linux macos ohos wasm windows)
REQUIRED_PREBUILT_FILES=(
  "android/arm64-v8a/libsweeteditor.so"
  "android/x86_64/libsweeteditor.so"
  "ios/arm64/libsweeteditor.dylib"
  "ios/simulator-arm64/libsweeteditor.dylib"
  "ios/SweetEditorCoreIOS.xcframework.zip"
  "linux/aarch64/libsweeteditor.so"
  "linux/x86_64/libsweeteditor.so"
  "macos/arm64/libsweeteditor.dylib"
  "macos/x86_64/libsweeteditor.dylib"
  "macos/SweetEditorCoreMacOS.xcframework.zip"
  "ohos/arm64-v8a/libsweeteditor.so"
  "ohos/x86_64/libsweeteditor.so"
  "wasm/sweeteditor_c_abi.js"
  "wasm/sweeteditor_c_abi.wasm"
  "wasm/sweeteditor_embind.js"
  "wasm/sweeteditor_embind.wasm"
  "windows/x64/sweeteditor.dll"
)

usage() {
  cat <<'EOF'
Usage:
  bash scripts/package-artifacts.sh --version <version> [options]

Options:
  -v, --version <version>                 Release version.
      --prebuilt-source-dir <path>        Source directory for prebuilt binaries. Defaults to prebuilt.
      --headers-source-dir <path>         Source directory for public headers. Defaults to include.
  -o, --output-dir <path>                 Output directory. Defaults to build/artifacts.
      --commit <commit>                   Commit text used in package metadata.
      --release-notes-template <path>     Release notes template path. Defaults to scripts/RELEASE_NOTES.md.
      --skip-release-notes                Do not create release notes.
  -f, --force                             Overwrite existing output files.
  -h, --help                              Show this help.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    die "Missing value for $option"
  fi
}

cleanup() {
  if [ -n "$TEMP_ROOT" ] && [ -d "$TEMP_ROOT" ]; then
    rm -rf "$TEMP_ROOT"
  fi
}

trap cleanup EXIT

absolute_path() {
  local path="$1"
  local raw_path
  local existing_path
  local suffix
  if [[ "$path" = /* ]]; then
    raw_path="$path"
  else
    raw_path="$PWD/$path"
  fi

  existing_path="$(dirname "$raw_path")"
  suffix="$(basename "$raw_path")"
  while [ ! -d "$existing_path" ] && [ "$existing_path" != "/" ]; do
    suffix="$(basename "$existing_path")/$suffix"
    existing_path="$(dirname "$existing_path")"
  done

  if [ ! -d "$existing_path" ]; then
    die "Cannot resolve path: $path"
  fi

  printf '%s/%s\n' "$(cd "$existing_path" && pwd)" "$suffix"
}

ensure_directory() {
  local path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

resolve_commit() {
  local override="$1"
  if [ -n "$override" ]; then
    printf '%s\n' "$override"
    return
  fi

  git -C "$PROJECT_DIR" rev-parse HEAD
}

hash_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print tolower($1)}'
    return
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print tolower($1)}'
    return
  fi

  die "Required checksum command not found: shasum or sha256sum"
}

write_checksums_file() {
  local stage_dir="$1"
  local checksum_path="$stage_dir/SHA256SUMS.txt"

  (
    cd "$stage_dir"
    find . -type f ! -name "SHA256SUMS.txt" |
      sed 's#^\./##' |
      LC_ALL=C sort |
      while IFS= read -r file; do
        local hash
        hash="$(hash_file "$file")"
        printf '%s  %s\n' "$hash" "$file"
      done > "$checksum_path"
  )
}

zip_directory_contents() {
  local source_dir="$1"
  local zip_path="$2"
  local file_list="$TEMP_ROOT/files.txt"

  command -v zip >/dev/null 2>&1 || die "Required command not found: zip"

  (
    cd "$source_dir"
    find . -type f |
      sed 's#^\./##' |
      LC_ALL=C sort > "$file_list"
  )

  if [ ! -s "$file_list" ]; then
    die "No files found to package under $source_dir"
  fi

  if [ -e "$zip_path" ]; then
    rm -f "$zip_path"
  fi

  (
    cd "$source_dir"
    zip -q -@ "$zip_path" < "$file_list"
  )
}

copy_directory_contents() {
  local source_dir="$1"
  local destination_dir="$2"

  ensure_directory "$destination_dir"
  cp -R "$source_dir"/. "$destination_dir/"
  find "$destination_dir" -name ".gitkeep" -type f -delete
}

write_native_readme_file() {
  local path="$1"
  local version_text="$2"
  local commit_text="$3"
  local platform

  {
    printf '%s\n' "SweetEditor Native SDK"
    printf '%s\n' "======================"
    printf '\n'
    printf 'Version: %s\n' "$version_text"
    if [ -n "$commit_text" ]; then
      printf 'Commit: %s\n' "$commit_text"
    fi
    printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '\n'
    printf '%s\n' "Package layout:"
    printf '%s\n' "- include/sweeteditor/: C/C++ headers"
    printf '%s\n' "- prebuilt/: native binaries grouped by platform"
    printf '\n'
    printf '%s\n' "Included prebuilt platform directories:"
    for platform in "${REQUIRED_PLATFORMS[@]}"; do
      printf -- '- %s\n' "$platform"
    done
    printf '\n'
    printf '%s\n' "Examples:"
    printf '%s\n' "- prebuilt/windows/x64/sweeteditor.dll"
    printf '%s\n' "- prebuilt/wasm/sweeteditor_c_abi.js"
    printf '%s\n' "- prebuilt/android/arm64-v8a/libsweeteditor.so"
  } > "$path"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

write_release_notes_file() {
  local template_path="$1"
  local output_dir="$2"
  local version_text="$3"
  local native_asset_name="$4"
  local commit_text="$5"
  local output_path="$output_dir/release-notes-v$version_text.md"
  local escaped_version
  local escaped_commit
  local escaped_native

  [ -f "$template_path" ] || die "Release notes template does not exist: $template_path"

  escaped_version="$(escape_sed_replacement "$version_text")"
  escaped_commit="$(escape_sed_replacement "$commit_text")"
  escaped_native="$(escape_sed_replacement "$native_asset_name")"

  sed \
    -e "s|{{VERSION}}|$escaped_version|g" \
    -e "s|{{COMMIT}}|$escaped_commit|g" \
    -e "s|{{NATIVE_ASSET_NAME}}|$escaped_native|g" \
    "$template_path" > "$output_path"

  echo "Created release notes: $output_path"
}

package_native_artifacts() {
  local prebuilt_source_dir="$1"
  local headers_source_dir="$2"
  local output_dir="$3"
  local version_text="$4"
  local commit_text="$5"
  local archive_name="sweeteditor-native-v$version_text.zip"
  local archive_path="$output_dir/$archive_name"
  local stage_dir="$TEMP_ROOT/stage"
  local platform
  local required_file
  local header_count

  [ -d "$prebuilt_source_dir" ] || die "Prebuilt source directory does not exist: $prebuilt_source_dir"
  [ -d "$headers_source_dir" ] || die "Headers source directory does not exist: $headers_source_dir"

  for required_file in "${REQUIRED_PREBUILT_FILES[@]}"; do
    if [ ! -f "$prebuilt_source_dir/$required_file" ]; then
      die "Required prebuilt file is missing: $required_file"
    fi
  done

  header_count="$(find "$headers_source_dir" -type f \( -name "*.h" -o -name "*.hpp" \) | wc -l | tr -d '[:space:]')"
  if [ "$header_count" -eq 0 ]; then
    die "No header files were found under $headers_source_dir"
  fi

  if [ -e "$archive_path" ] && [ "$FORCE" -eq 0 ]; then
    die "Archive already exists: $archive_path. Use --force to overwrite it."
  fi

  ensure_directory "$stage_dir/prebuilt"
  ensure_directory "$stage_dir/include"

  for platform in "${REQUIRED_PLATFORMS[@]}"; do
    copy_directory_contents "$prebuilt_source_dir/$platform" "$stage_dir/prebuilt/$platform"
  done
  copy_directory_contents "$headers_source_dir" "$stage_dir/include"

  write_native_readme_file "$stage_dir/README.txt" "$version_text" "$commit_text"
  write_checksums_file "$stage_dir"
  zip_directory_contents "$stage_dir" "$archive_path"
  echo "Created native SDK archive: $archive_path"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--version)
      require_value "$1" "${2:-}"
      VERSION="$2"
      shift 2
      ;;
    --prebuilt-source-dir)
      require_value "$1" "${2:-}"
      PREBUILT_SOURCE_DIR="$2"
      shift 2
      ;;
    --headers-source-dir)
      require_value "$1" "${2:-}"
      HEADERS_SOURCE_DIR="$2"
      shift 2
      ;;
    -o|--output-dir)
      require_value "$1" "${2:-}"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --commit)
      require_value "$1" "${2:-}"
      COMMIT="$2"
      shift 2
      ;;
    --release-notes-template)
      require_value "$1" "${2:-}"
      RELEASE_NOTES_TEMPLATE="$2"
      shift 2
      ;;
    --skip-release-notes)
      SKIP_RELEASE_NOTES=1
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  usage >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  die "Invalid version: $VERSION"
fi

PREBUILT_SOURCE_DIR="$(absolute_path "${PREBUILT_SOURCE_DIR:-$PROJECT_DIR/prebuilt}")"
HEADERS_SOURCE_DIR="$(absolute_path "${HEADERS_SOURCE_DIR:-$PROJECT_DIR/include}")"
OUTPUT_DIR="$(absolute_path "${OUTPUT_DIR:-$PROJECT_DIR/build/artifacts}")"
RELEASE_NOTES_TEMPLATE="$(absolute_path "${RELEASE_NOTES_TEMPLATE:-$SCRIPT_DIR/RELEASE_NOTES.md}")"
COMMIT="$(resolve_commit "$COMMIT")"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sweeteditor-native.XXXXXXXX")"

ensure_directory "$OUTPUT_DIR"
package_native_artifacts "$PREBUILT_SOURCE_DIR" "$HEADERS_SOURCE_DIR" "$OUTPUT_DIR" "$VERSION" "$COMMIT"

if [ "$SKIP_RELEASE_NOTES" -eq 0 ]; then
  write_release_notes_file \
    "$RELEASE_NOTES_TEMPLATE" \
    "$OUTPUT_DIR" \
    "$VERSION" \
    "sweeteditor-native-v$VERSION.zip" \
    "$COMMIT"
fi
