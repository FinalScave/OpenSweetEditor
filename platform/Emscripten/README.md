# SweetEditor for Web

SweetEditor provides an Emscripten build of the shared native core as WebAssembly. Platform target definitions live in `cmake/platform/Emscripten.cmake`.

## Scope

SweetEditor for Web exposes the selected C ABI through `sweeteditor_c_abi.js` and `sweeteditor_c_abi.wasm`. Browser UI and rendering are implemented by the host.

## Build Outputs

- `sweeteditor_c_abi.js` and `sweeteditor_c_abi.wasm`: modular ES-module C ABI runtime
- `sweeteditor_embind.js` and `sweeteditor_embind.wasm`: reserved Embind module

Prebuilt modules are stored under prebuilt/wasm.

## Module Initialization

~~~javascript
import createSweetEditorCAbi from './sweeteditor_c_abi.js';

const sweetEditor = await createSweetEditorCAbi();
~~~

Exported C functions use Emscripten-style names such as _create_editor and _free_editor. Only symbols explicitly listed in WASM_C_ABI_EXPORTED_FUNCTIONS are available.

The module also exports selected runtime helpers for C calls, UTF-8 conversion, heap access, callback registration, and the Emscripten filesystem. Call the matching object, string, binary-buffer, or heap free function for every owned native allocation.

See the Web Platform API reference for the exact boundary, supported capability groups, memory ownership, runtime helpers, and known exclusions.

## Build

On Windows:

~~~powershell
.\scripts\build-release.ps1 -Platform wasm
~~~

On a shell with Emscripten configured:

~~~bash
./scripts/build-release.sh --platform wasm
~~~

The CMake targets are sweeteditor_wasm_c_abi and sweeteditor_wasm_embind. They can be selected independently with SWEETEDITOR_BUILD_WASM_C_ABI and SWEETEDITOR_BUILD_WASM_EMBIND.

## Links

- [Web Platform API](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-web.md)
- [Web 平台 API](https://github.com/FinalScave/SweetEditor/blob/main/docs/zh/api-platform-web.md)
- [C++ core and complete C API](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-editor-core.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../LICENSE)
