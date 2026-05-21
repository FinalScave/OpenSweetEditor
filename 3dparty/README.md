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

Examples:

```text
lib/macos/arm64/release/
lib/windows/x64/debug/
lib/linux/x86_64/release/
```

Project code should depend on `SweetEditor3p::*` targets instead of referencing
`3dparty` paths directly.
