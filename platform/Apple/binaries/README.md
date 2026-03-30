# Binaries

`SweetNativeCore.xcframework` is generated locally by:

```bash
make native
```

This directory only stores the final Apple binary artifact consumed by `Package.swift`.

- `SweetNativeCore.xcframework` contains dynamic `SweetNativeCore.framework` slices.
- Intermediate framework and dynamic-library build outputs stay under the repository `build/` directory and are not treated as stable packaged artifacts.
