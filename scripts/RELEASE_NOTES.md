# SweetEditor v{{VERSION}}

Cross-platform release assets for SweetEditor.

## Assets

- Prebuilt binaries: `{{PREBUILT_ASSET_NAME}}`
- C/C++ headers: `{{HEADERS_ASSET_NAME}}`

## Included Platforms In The Prebuilt Package

- Android: `arm64-v8a`, `x86_64`
- iOS: `arm64`, `simulator-arm64`, `SweetEditorCoreIOS.xcframework.zip`
- macOS: `arm64`, `x86_64`, `SweetEditorCoreOSX.xcframework.zip`
- Linux: `x86_64`, `aarch64`
- Windows: `x64`
- OHOS: `arm64-v8a`, `x86_64`
- Web: `sweeteditor_c_abi.js`, `sweeteditor_c_abi.wasm`, `sweeteditor_embind.js`, `sweeteditor_embind.wasm`

## Package Layout

- `{{PREBUILT_ASSET_NAME}}`
  - archive root contains platform directories directly
  - includes `README.txt` and `SHA256SUMS.txt` by default
- `{{HEADERS_ASSET_NAME}}`
  - archive root contains `include/sweeteditor/...`
  - includes `SHA256SUMS.txt` by default

## Notes

- Commit: `{{COMMIT}}`
- The prebuilt package is built from the repository `prebuilt/` artifacts.
- The headers package is built from `include/sweeteditor/` and uses the install-style layout `include/sweeteditor/`.
