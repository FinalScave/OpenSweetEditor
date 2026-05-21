# SweetEditor Third-Party Dependencies

All vendored third-party dependencies live under `3dparty`.

Each dependency should provide:

- `METADATA` with the upstream version, source, license name, and retrieved files.
- `LICENSE` with the upstream license text or license selection note.
- `sweeteditor_3p.cmake` defining stable `SweetEditor3p::*` targets.

Source dependencies should keep upstream files under `include` and `src`.

Binary dependencies should separate artifacts by platform, architecture, and build
configuration:

```text
lib/<platform>/<arch>/<config>/
bin/<platform>/<arch>/<config>/
```

When a platform has only one architecture in this project, the architecture
directory can be omitted:

```text
lib/<platform>/<config>/
bin/<platform>/<config>/
```

Examples:

```text
lib/android/arm64-v8a/release/
lib/emscripten/release/
lib/ios/arm64/release/
lib/ios/simulator-arm64/release/
lib/macos/arm64/release/
lib/linux/x86_64/release/
lib/ohos/x86_64/release/
lib/windows/x64/debug/
lib/windows/x64/release/
```

For iOS, keep device and simulator artifacts under the same `ios` platform
directory. Use `arm64` for device builds and `simulator-arm64` for Apple Silicon
simulator builds.

Simdutf currently uses these prebuilt library paths:

```text
lib/android/arm64-v8a/release/libsimdutf.a
lib/android/x86_64/release/libsimdutf.a
lib/emscripten/release/libsimdutf.a
lib/ios/arm64/release/libsimdutf.a
lib/ios/simulator-arm64/release/libsimdutf.a
lib/linux/aarch64/release/libsimdutf.a
lib/linux/x86_64/release/libsimdutf.a
lib/macos/arm64/release/libsimdutf.a
lib/macos/x86_64/release/libsimdutf.a
lib/ohos/arm64-v8a/release/libsimdutf.a
lib/ohos/x86_64/release/libsimdutf.a
lib/windows/x64/debug/simdutf.lib
lib/windows/x64/release/libsimdutf.a
lib/windows/x64/release/simdutf.lib
```

Project code should depend on `SweetEditor3p::*` targets instead of referencing
`3dparty` paths directly.
