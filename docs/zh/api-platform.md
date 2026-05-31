# 平台 API 文档入口

本文档描述的是当前仓库代码状态（2026-05）。若文档与源码不一致，以源码为准。

## 文档列表

- [Android 平台 API](./api-platform-android.md)
- [Swing 平台 API](./api-platform-swing.md)
- [Apple 平台 API](./api-platform-apple.md)
- [WinForms 平台 API](./api-platform-winforms.md)
- [OHOS 平台 API](./api-platform-ohos.md)
- [C++ 核心 / C API](./api-editor-core.md)
- [平台实现标准](./platform-implementation-standard.md)

## 当前平台状态

| 平台 | 桥接方式 | 状态 | 说明 |
|---|---|---|---|
| Android | JNI 直连 C++（`jni_entry.cpp` + `jeditor.hpp`） | ✅ 已接入 | 主路径不经过 `c_api.h`，但复杂返回值仍走 binary payload 解码 |
| Swing | Java FFM -> C API | ✅ 已接入 | 消费 binary payload |
| WinForms | P/Invoke -> C API | ✅ 已接入 | 消费 binary payload |
| Apple | Swift Package + 手工 C bridge | ✅ 已接入 | 主要消费 binary payload；bridge header 与 `c_api.h` 仍需显式对照 |
| OHOS | ArkTS NAPI 直连共享 C++（`libsweeteditor.so`） | ✅ 已接入 | `EditorCore.ets` + `CoreProtocol.ets` 在 ArkTS 侧解码 binary payload |
| Web (Emscripten) | 非官方 fork（`LangLang03/OpenSweetEditor-Web`） | 🧪 测试中 | Web 平台为实验性开发，维护于 fork 仓库：<https://github.com/LangLang03/OpenSweetEditor-Web/tree/main/platform/Emscripten> |

## 当前平台层约定

- 控件层公开 API 优先使用语义化枚举（`WrapMode`、`FoldArrowMode`、`SpanLayer` 等）。
- 桥接层保留原生数值协议（`int`/`byte`）对接 JNI/FFM/PInvoke/C bridge。
- 变更类 core 调用统一通过 `EditorActionResult` 表达文本事件、IME 同步、动画、刷新与重绘需求，平台层不再按方法名或局部经验自行推断副作用。
- `FontStyle` 这类位标志保持常量风格，不改成互斥枚举。

## 建议阅读顺序

1. 先看对应平台控件层 API（对业务最直接）。
2. 再看平台桥接层（JNI/FFM/PInvoke/Swift/NAPI bridge）。
3. 需要确认 ABI、二进制 payload 布局或枚举值时，再回到 [C++ 核心 / C API](./api-editor-core.md)。
