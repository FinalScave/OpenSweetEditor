# 平台 API 文档入口

本文档描述的是当前仓库代码状态（2026-03）。若文档与源码不一致，以源码为准。

## 文档列表

- [Android 平台 API](./api-platform-android.md)
- [Swing 平台 API](./api-platform-swing.md)
- [Apple 平台 API](./api-platform-apple.md)
- [WinForms 平台 API](./api-platform-winforms.md)
- [OHOS 平台 API](./api-platform-ohos.md)
- [Web 平台 API](./api-platform-web.md)
- [C++ 核心 / C API](./api-editor-core.md)

## 当前平台状态

| 平台 | 桥接方式 | 状态 | 说明 |
|---|---|---|---|
| Android | JNI 直连 C++ (`jni_entry.cpp` + `jeditor.hpp`) | ✅ 活跃 | 不经过 `c_api.h` 主路径，但复杂返回仍解码 binary payload |
| Swing | Java FFM -> C API | ✅ 活跃 | 消费二进制 payload |
| WinForms | P/Invoke -> C API | ✅ 活跃 | 消费二进制 payload |
| Apple | Swift Package + 手工 C bridge | ✅ 活跃 | 主要消费二进制 payload；bridge header 与 `c_api.h` 需显式校对 |
| OHOS | ArkTS NAPI 直连共享 C++ (`libsweeteditor.so`) | ✅ 活跃 | `EditorCore.ets` + `EditorProtocol.ets` 在 ArkTS 侧解码 binary payload |
| Web (Emscripten) | Emscripten embind | 🚧 测试中 | 存在已知问题，暂无 CDN/NPM 包。详见 [Web 平台 API](./api-platform-web.md) |

## 当前平台层约定

- 控件层公开 API 优先使用语义化枚举（`WrapMode`、`FoldArrowMode`、`SpanLayer` 等）。
- 桥接层保留原生数值协议（`int`/`byte`）对接 JNI/FFM/PInvoke/C bridge。
- `FontStyle` 这类位标志保持常量风格，不改成互斥枚举。

## 建议阅读顺序

1. 先看对应平台控件层 API（对业务最直接）。
2. 再看平台桥接层（JNI/FFM/PInvoke/Swift/NAPI bridge）。
3. 需要确认 ABI、二进制 payload 布局或枚举值时，再回到 [C++ 核心 / C API](./api-editor-core.md)。
