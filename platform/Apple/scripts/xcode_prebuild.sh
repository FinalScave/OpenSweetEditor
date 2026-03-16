#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
OUTPUT_XCFRAMEWORK="${APPLE_DIR}/binaries/SweetNativeCore.xcframework"
OUTPUT_MARKER="${OUTPUT_XCFRAMEWORK}/Info.plist"

if [[ "${SWEETEDITOR_FORCE_NATIVE:-0}" == "1" ]]; then
  echo "SWEETEDITOR_FORCE_NATIVE=1, rebuilding native framework"
  "${SCRIPT_DIR}/build_native_xcframework.sh"
  exit 0
fi

if [[ ! -f "${OUTPUT_MARKER}" ]]; then
  echo "Native framework missing, building ${OUTPUT_XCFRAMEWORK}"
  "${SCRIPT_DIR}/build_native_xcframework.sh"
  exit 0
fi

latest_input_ts=0
while IFS= read -r -d '' file; do
  file_ts="$(stat -f "%m" "${file}")"
  if [[ "${file_ts}" -gt "${latest_input_ts}" ]]; then
    latest_input_ts="${file_ts}"
  fi
done < <(find "${REPO_ROOT}/src/core" "${REPO_ROOT}/src/include" -type f -print0)

cmake_ts="$(stat -f "%m" "${REPO_ROOT}/CMakeLists.txt")"
if [[ "${cmake_ts}" -gt "${latest_input_ts}" ]]; then
  latest_input_ts="${cmake_ts}"
fi

output_ts="$(stat -f "%m" "${OUTPUT_MARKER}")"

if [[ "${latest_input_ts}" -gt "${output_ts}" ]]; then
  echo "Native inputs changed, rebuilding ${OUTPUT_XCFRAMEWORK}"
  "${SCRIPT_DIR}/build_native_xcframework.sh"
else
  echo "Native framework is up-to-date"
fi
