#!/usr/bin/env bash

set -euo pipefail

VERSION=""
PREBUILT_SOURCE_DIR=""
HEADERS_SOURCE_DIR=""
OUTPUT_DIR=""
PREBUILT_NAME_PREFIX="sweeteditor-prebuilt"
HEADERS_NAME_PREFIX="sweeteditor-headers"
COMMIT=""
RELEASE_NOTES_TEMPLATE=""
SKIP_PREBUILT=0
SKIP_HEADERS=0
SKIP_RELEASE_NOTES=0
NO_PREBUILT_README=0
NO_CHECKSUMS=0
FORCE=0
PLATFORMS=()
TEMP_DIRS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

function usage() {
  cat <<'EOF'
Usage:
  bash scripts/package-artifacts.sh --version <version> [options]

Options:
  -v, --version <version>                 Release version.
      --prebuilt-source-dir <path>        Source directory for prebuilt binaries. Defaults to prebuilt.
      --headers-source-dir <path>         Source directory for public headers. Defaults to include/sweeteditor.
  -o, --output-dir <path>                 Output directory. Defaults to build/artifacts.
      --prebuilt-name-prefix <name>       Prebuilt archive prefix. Defaults to sweeteditor-prebuilt.
      --headers-name-prefix <name>        Headers archive prefix. Defaults to sweeteditor-headers.
  -p, --platform <list>                   Platform filter, comma-separated or repeated.
      --commit <commit>                   Commit text used in package metadata.
      --release-notes-template <path>     Release notes template path. Defaults to scripts/RELEASE_NOTES.md.
      --skip-prebuilt                     Do not create the prebuilt archive.
      --skip-headers                      Do not create the headers archive.
      --skip-release-notes                Do not create release notes.
      --no-prebuilt-readme                Do not include README.txt in the prebuilt archive.
      --no-checksums                      Do not include SHA256SUMS.txt.
  -f, --force                             Overwrite existing output files.
  -h, --help                              Show this help.
EOF
}

function die() {
  echo "Error: $*" >&2
  exit 1
}

function require_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    die "Missing value for $option"
  fi
}

function cleanup_temp_dirs() {
  local dir
  for dir in "${TEMP_DIRS[@]}"; do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
      rm -rf "$dir"
    fi
  done
}

trap cleanup_temp_dirs EXIT

function make_temp_dir() {
  local prefix="$1"
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXXXX")"
  TEMP_DIRS+=("$dir")
  printf '%s\n' "$dir"
}

function absolute_path() {
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

function trim_text() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

function validate_platform() {
  case "$1" in
    android|ios|linux|macos|ohos|wasm|windows)
      return 0
      ;;
    *)
      die "Unsupported platform: $1"
      ;;
  esac
}

function add_platforms() {
  local raw="$1"
  local old_ifs="$IFS"
  local item
  IFS=','
  for item in $raw; do
    item="$(trim_text "$item")"
    if [ -n "$item" ]; then
      validate_platform "$item"
      PLATFORMS+=("$item")
    fi
  done
  IFS="$old_ifs"
}

function ensure_directory() {
  local path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

function resolve_commit() {
  local override="$1"
  if [ -n "$override" ]; then
    printf '%s\n' "$override"
    return
  fi

  git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true
}

function hash_file() {
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

function write_checksums_file() {
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

function zip_directory_contents() {
  local source_dir="$1"
  local zip_path="$2"
  local file_list

  command -v zip >/dev/null 2>&1 || die "Required command not found: zip"

  file_list="$(make_temp_dir "sweeteditor-zip-list")/files.txt"
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

function copy_directory_contents() {
  local source_dir="$1"
  local destination_dir="$2"
  local item

  ensure_directory "$destination_dir"
  while IFS= read -r item; do
    if [ "$(basename "$item")" = ".gitkeep" ]; then
      continue
    fi
    cp -R "$item" "$destination_dir/"
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 | LC_ALL=C sort)
}

function get_platform_directories() {
  local root_dir="$1"
  local platform

  if [ "${#PLATFORMS[@]}" -eq 0 ]; then
    find "$root_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort
    return
  fi

  for platform in "${PLATFORMS[@]}"; do
    if [ ! -d "$root_dir/$platform" ]; then
      die "Requested platform directory is missing under $root_dir: $platform"
    fi
    printf '%s\n' "$platform"
  done
}

function write_prebuilt_readme_file() {
  local path="$1"
  local version_text="$2"
  local commit_text="$3"
  shift 3
  local platforms=("$@")
  local platform

  {
    printf '%s\n' "SweetEditor Prebuilt Package"
    printf '%s\n' "================================"
    printf '\n'
    printf 'Version: %s\n' "$version_text"
    if [ -n "$commit_text" ]; then
      printf 'Commit: %s\n' "$commit_text"
    fi
    printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '\n'
    printf '%s\n' "Included platform directories:"
    for platform in "${platforms[@]}"; do
      printf -- '- %s\n' "$platform"
    done
    printf '\n'
    printf '%s\n' "The zip keeps each platform directory at the archive root."
    printf '%s\n' "For example:"
    printf '%s\n' "- windows/x64/sweeteditor.dll"
    printf '%s\n' "- wasm/sweeteditor_c_abi.js"
    printf '%s\n' "- wasm/sweeteditor_embind.js"
    printf '%s\n' "- android/arm64-v8a/libsweeteditor.so"
    printf '%s\n' "- ios/SweetEditorCoreIOS.xcframework.zip"
    printf '%s\n' "- macos/SweetEditorCoreMacOS.xcframework.zip"
  } > "$path"
}

function package_prebuilt_artifacts() {
  local source_dir="$1"
  local output_dir="$2"
  local version_text="$3"
  local archive_prefix="$4"
  local commit_text="$5"
  shift 5
  local platforms=("$@")
  local archive_name="$archive_prefix-v$version_text.zip"
  local archive_path="$output_dir/$archive_name"
  local temp_root
  local stage_dir
  local platform

  [ -d "$source_dir" ] || die "Prebuilt source directory does not exist: $source_dir"
  if [ -e "$archive_path" ] && [ "$FORCE" -eq 0 ]; then
    die "Archive already exists: $archive_path. Use --force to overwrite it."
  fi

  temp_root="$(make_temp_dir "sweeteditor-prebuilt")"
  stage_dir="$temp_root/stage"
  ensure_directory "$stage_dir"

  for platform in "${platforms[@]}"; do
    copy_directory_contents "$source_dir/$platform" "$stage_dir/$platform"
  done

  if [ "$NO_PREBUILT_README" -eq 0 ]; then
    write_prebuilt_readme_file "$stage_dir/README.txt" "$version_text" "$commit_text" "${platforms[@]}"
  fi

  if [ "$NO_CHECKSUMS" -eq 0 ]; then
    write_checksums_file "$stage_dir"
  fi

  zip_directory_contents "$stage_dir" "$archive_path"
  echo "Created prebuilt archive: $archive_path"
}

function package_headers_artifacts() {
  local source_dir="$1"
  local output_dir="$2"
  local version_text="$3"
  local archive_prefix="$4"
  local archive_name="$archive_prefix-v$version_text.zip"
  local archive_path="$output_dir/$archive_name"
  local temp_root
  local stage_dir
  local stage_include_dir
  local header_list
  local file

  [ -d "$source_dir" ] || die "Headers source directory does not exist: $source_dir"
  if [ -e "$archive_path" ] && [ "$FORCE" -eq 0 ]; then
    die "Archive already exists: $archive_path. Use --force to overwrite it."
  fi

  temp_root="$(make_temp_dir "sweeteditor-headers")"
  stage_dir="$temp_root/stage"
  stage_include_dir="$stage_dir/include/sweeteditor"
  header_list="$temp_root/headers.txt"
  ensure_directory "$stage_include_dir"

  find "$source_dir" -type f \( -name "*.h" -o -name "*.hpp" \) | LC_ALL=C sort > "$header_list"
  if [ ! -s "$header_list" ]; then
    die "No header files were found under $source_dir"
  fi

  while IFS= read -r file; do
    local relative_path="${file#$source_dir/}"
    local destination_path="$stage_include_dir/$relative_path"
    ensure_directory "$(dirname "$destination_path")"
    cp "$file" "$destination_path"
  done < "$header_list"

  if [ "$NO_CHECKSUMS" -eq 0 ]; then
    write_checksums_file "$stage_dir"
  fi

  zip_directory_contents "$stage_dir" "$archive_path"
  echo "Created headers archive: $archive_path"
}

function escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

function write_release_notes_file() {
  local template_path="$1"
  local output_dir="$2"
  local version_text="$3"
  local prebuilt_asset_name="$4"
  local headers_asset_name="$5"
  local commit_text="$6"
  local output_path="$output_dir/release-notes-v$version_text.md"
  local escaped_version
  local escaped_commit
  local escaped_prebuilt
  local escaped_headers

  [ -f "$template_path" ] || die "Release notes template does not exist: $template_path"

  escaped_version="$(escape_sed_replacement "$version_text")"
  escaped_commit="$(escape_sed_replacement "$commit_text")"
  escaped_prebuilt="$(escape_sed_replacement "$prebuilt_asset_name")"
  escaped_headers="$(escape_sed_replacement "$headers_asset_name")"

  sed \
    -e "s/{{VERSION}}/$escaped_version/g" \
    -e "s/{{COMMIT}}/$escaped_commit/g" \
    -e "s/{{PREBUILT_ASSET_NAME}}/$escaped_prebuilt/g" \
    -e "s/{{HEADERS_ASSET_NAME}}/$escaped_headers/g" \
    "$template_path" > "$output_path"

  echo "Created release notes: $output_path"
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
    --prebuilt-name-prefix)
      require_value "$1" "${2:-}"
      PREBUILT_NAME_PREFIX="$2"
      shift 2
      ;;
    --headers-name-prefix)
      require_value "$1" "${2:-}"
      HEADERS_NAME_PREFIX="$2"
      shift 2
      ;;
    -p|--platform)
      require_value "$1" "${2:-}"
      add_platforms "$2"
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
    --skip-prebuilt)
      SKIP_PREBUILT=1
      shift
      ;;
    --skip-headers)
      SKIP_HEADERS=1
      shift
      ;;
    --skip-release-notes)
      SKIP_RELEASE_NOTES=1
      shift
      ;;
    --no-prebuilt-readme)
      NO_PREBUILT_README=1
      shift
      ;;
    --no-checksums)
      NO_CHECKSUMS=1
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

[ -n "$VERSION" ] || die "Missing required option: --version"
if [ "$SKIP_PREBUILT" -eq 1 ] && [ "$SKIP_HEADERS" -eq 1 ]; then
  die "Nothing to package. Remove --skip-prebuilt or --skip-headers."
fi

RESOLVED_PREBUILT_SOURCE_DIR="$(absolute_path "${PREBUILT_SOURCE_DIR:-$PROJECT_DIR/prebuilt}")"
RESOLVED_HEADERS_SOURCE_DIR="$(absolute_path "${HEADERS_SOURCE_DIR:-$PROJECT_DIR/include/sweeteditor}")"
RESOLVED_OUTPUT_DIR="$(absolute_path "${OUTPUT_DIR:-$PROJECT_DIR/build/artifacts}")"
RESOLVED_RELEASE_NOTES_TEMPLATE="$(absolute_path "${RELEASE_NOTES_TEMPLATE:-$SCRIPT_DIR/RELEASE_NOTES.md}")"
RESOLVED_COMMIT="$(resolve_commit "$COMMIT")"
PREBUILT_ARCHIVE_NAME="$PREBUILT_NAME_PREFIX-v$VERSION.zip"
HEADERS_ARCHIVE_NAME="$HEADERS_NAME_PREFIX-v$VERSION.zip"

ensure_directory "$RESOLVED_OUTPUT_DIR"

if [ "$SKIP_PREBUILT" -eq 0 ]; then
  SELECTED_PLATFORMS=()
  while IFS= read -r platform; do
    if [ -n "$platform" ]; then
      SELECTED_PLATFORMS+=("$platform")
    fi
  done < <(get_platform_directories "$RESOLVED_PREBUILT_SOURCE_DIR")

  if [ "${#SELECTED_PLATFORMS[@]}" -eq 0 ]; then
    die "No platform directories were found under $RESOLVED_PREBUILT_SOURCE_DIR"
  fi

  package_prebuilt_artifacts \
    "$RESOLVED_PREBUILT_SOURCE_DIR" \
    "$RESOLVED_OUTPUT_DIR" \
    "$VERSION" \
    "$PREBUILT_NAME_PREFIX" \
    "$RESOLVED_COMMIT" \
    "${SELECTED_PLATFORMS[@]}"
fi

if [ "$SKIP_HEADERS" -eq 0 ]; then
  package_headers_artifacts \
    "$RESOLVED_HEADERS_SOURCE_DIR" \
    "$RESOLVED_OUTPUT_DIR" \
    "$VERSION" \
    "$HEADERS_NAME_PREFIX"
fi

if [ "$SKIP_RELEASE_NOTES" -eq 0 ]; then
  write_release_notes_file \
    "$RESOLVED_RELEASE_NOTES_TEMPLATE" \
    "$RESOLVED_OUTPUT_DIR" \
    "$VERSION" \
    "$PREBUILT_ARCHIVE_NAME" \
    "$HEADERS_ARCHIVE_NAME" \
    "$RESOLVED_COMMIT"
fi
