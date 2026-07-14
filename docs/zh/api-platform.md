# 接入 API 文档入口

本文档汇总当前仓库已经实现的接入 API。若签名或行为与源码不一致，以源码为准，同时应修正文档。

## README

- [Android](../../platform/Android/sweeteditor/README.md)
- [Apple](../../platform/Apple/README.md)
- [Avalonia](../../platform/Avalonia/SweetEditor/README.md)
- [Flutter](../../platform/Flutter/sweeteditor/README.md)
- [OHOS](../../platform/OHOS/sweeteditor/README.md)
- [Swing](../../platform/Swing/sweeteditor/README.md)
- [WinForms](../../platform/WinForms/SweetEditor/README.md)
- [Web](../../platform/Emscripten/README.md)

安装、环境要求、快速开始、构建命令和原生接入说明以各实现 README 为入口；下方文档提供完整的公开 API 参考。

## 文档列表

- [Android 平台 API](./api-platform-android.md)
- [Apple 平台 API](./api-platform-apple.md)
- [Avalonia API](./api-platform-avalonia.md)
- [Flutter API](./api-platform-flutter.md)
- [OHOS 平台 API](./api-platform-ohos.md)
- [Swing API](./api-platform-swing.md)
- [Web 平台 API](./api-platform-web.md)
- [WinForms API](./api-platform-winforms.md)
- [C++ 核心 / C API](./api-editor-core.md)
- [接入实现标准](./platform-implementation-standard.md)

## 建议阅读顺序

1. 先看对应实现的 README，完成安装和构建。
2. 再看控件层 API，完成产品接入。
3. 需要确认 ABI、二进制 payload 布局或枚举值时，再阅读 [C++ 核心 / C API](./api-editor-core.md)。
