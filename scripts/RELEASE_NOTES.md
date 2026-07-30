# SweetEditor v{{VERSION}}

Cross-platform native SDK for SweetEditor.

## Assets

- Native SDK: `{{NATIVE_ASSET_NAME}}`

## Included Platforms

- Android: `arm64-v8a`, `x86_64`
- iOS: `arm64/libsweeteditor.dylib`, `simulator-arm64/libsweeteditor.dylib`, `SweetEditorCoreIOS.xcframework.zip`
- macOS: `arm64/libsweeteditor.dylib`, `x86_64/libsweeteditor.dylib`, `SweetEditorCoreMacOS.xcframework.zip`
- Linux: `x86_64`, `aarch64`
- Windows: `x64`
- OHOS: `arm64-v8a`, `x86_64`
- Web: `sweeteditor_c_abi.js`, `sweeteditor_c_abi.wasm`, `sweeteditor_embind.js`, `sweeteditor_embind.wasm`

## Package Layout

- `include/sweeteditor/`: C/C++ headers
- `prebuilt/`: native binaries grouped by platform
- `README.txt`: package metadata and included platforms
- `SHA256SUMS.txt`: checksums for all packaged files

## Notes

- Commit: `{{COMMIT}}`
- The SDK is built from the repository `prebuilt/` and `include/` directories.
