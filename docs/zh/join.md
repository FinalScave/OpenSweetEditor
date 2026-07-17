# 参与共建

本文档是基于当前仓库结构给出的实际开发入口。文档若与代码冲突，以代码为准。

## 建议阅读顺序

1. `docs/zh/architecture.md`
2. `docs/zh/api-editor-core.md`
3. `docs/zh/platform-implementation-standard.md`
4. `include/sweeteditor/*.h`
5. `src/*.cpp`
6. 最后再看 `platform/*`
7. `docs/zh/guide-adding-decoration-type.md` — 添加新装饰类型的逐层指南

## 仓库地图

```text
├── 3dparty
│   ├── simdutf / json / utfcpp      第三方依赖
├── docs
│   ├── zh/architecture.md           架构总览（中文）
│   ├── zh/api-editor-core.md        C API / 核心契约（中文）
│   ├── zh/api-platform*.md          各接入 API 文档（中文）
│   ├── en/architecture.md           架构总览（英文）
│   ├── en/api-editor-core.md        C API / 核心契约（英文）
│   └── en/api-platform*.md          各接入 API 文档（英文）
├── include/sweeteditor              核心头文件与 c_api.h
├── src                              Document / Layout / Decoration / EditorCore / c_api 实现
├── tests                            核心回归测试
├── platform
│   ├── Android                      Android SDK + JNI 直连
│   ├── Swing                        Java FFM + C API
│   ├── WinForms                     C# P/Invoke + C API
│   ├── Apple                        Swift Package + 手工 C bridge
│   ├── OHOS                         OHOS SDK + NAPI 直连
│   ├── Flutter                      Dart FFI + Flutter Widget
│   ├── Avalonia                     C# P/Invoke + Avalonia Control
│   └── Emscripten                   通过显式 C ABI 子集提供 Web ES Module 内核绑定
└── prebuilt                         预构建动态库
```

## 平台目录职责

### 核心层

- `include/sweeteditor/document.h` / `src/document.cpp`
  - 文本存储、位置映射、Piece Table / LineArray 实现
- `include/sweeteditor/layout.h` / `src/layout.cpp`
  - 文本布局、自动换行、命中测试、测量缓存、可见区裁剪
- `include/sweeteditor/decoration.h` / `src/decoration.cpp`
  - 高亮、Inlay Hint、Ghost Text、结构线、折叠、诊断等装饰
- `include/sweeteditor/editor_core.h` / `src/editor_core.cpp`
  - 编辑语义总协调器：输入、选区、IME、撤销重做、渲染模型组装
- `include/sweeteditor/c_api.h` / `src/c_api.cpp`
  - 非 Android 接入实现的稳定桥接边界

### Android

- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
  - 控件层，对业务暴露语义化 API
- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
  - JNI 桥接与二进制结果解码
- `platform/Android/sweeteditor/src/main/cpp/jni_entry.cpp`
- `platform/Android/sweeteditor/src/main/cpp/jeditor.hpp`
  - JNI 直连 C++ 的主路径

### Swing

- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
  - Swing 控件层
- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
  - Java 侧语义包装
- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorNative.java`
  - FFM downcall / upcall

### WinForms

- `platform/WinForms/SweetEditor/SweetEditorControl.cs`
  - WinForms 控件层、输入与绘制
- `platform/WinForms/SweetEditor/EditorCore.cs`
  - P/Invoke 封装与协议对接
- `platform/WinForms/SweetEditor/CoreProtocol.cs`
  - binary payload 解码
- `platform/WinForms/SweetEditor/EditorCompletion.cs`
  - Completion Provider 与补全弹层协作
- `platform/WinForms/SweetEditor/EditorDecoration.cs`
  - Decoration Provider 与刷新调度
- `platform/WinForms/SweetEditor/EditorNewLine.cs`
  - NewLine Action Provider 扩展接入
- `platform/WinForms/SweetEditor/Perf.cs`
  - 性能记录与 overlay 绘制

### Apple

- `include/sweeteditor/c_api.h`
  - 原生 Framework 直接导入的标准 C API
- `platform/Apple/SweetEditor-Shared/api/SweetEditorCore.swift`
  - Swift 侧核心封装与二进制协议解码
- `platform/Apple/SweetEditor-Shared/core/CoreProtocol.swift`
  - 与其他接入实现 `CoreProtocol` 对齐的二进制载荷编解码
- `platform/Apple/SweetEditor-Shared/core/CoreVisual.swift`
  - Apple 共用渲染模型 DTO
- `platform/Apple/SweetEditor-Shared/EditorRenderer.swift`
  - 消费渲染模型的 Apple 共用渲染器
- `platform/Apple/SweetEditor-iOS`
- `platform/Apple/SweetEditor-macOS`
  - iOS / macOS 平台视图

### Flutter

- `platform/Flutter/sweeteditor/lib/core/editor_core.dart`
  - Dart FFI 核心 API
- `platform/Flutter/sweeteditor/lib/core/core_protocol.dart`
  - Dart 侧二进制协议编解码
- `platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart`
  - Flutter Widget 与文本输入接入

### Avalonia

- `platform/Avalonia/SweetEditor/SweetEditorControl.cs`
  - Avalonia 控件层、输入与绘制
- `platform/Avalonia/SweetEditor/EditorCore.cs`
  - C# P/Invoke bridge
- `platform/Avalonia/SweetEditor/CoreProtocol.cs`
  - C# 侧二进制协议编解码
- `platform/Avalonia/SweetEditor/EditorRenderer.cs`
  - Avalonia DrawingContext 渲染

## 接入实现标准

如果你正在新增或维护接入实现，请参阅 [接入实现标准](platform-implementation-standard.md)，其中定义了所有接入实现必须遵循的类型清单、模块结构、API 契约与合规规则。

## 修改什么，就从哪里进

- 改文本编辑语义、撤销重做、选区、IME：
  - 先看 `editor_core.*`、`document.*`、`gesture.*`
- 改自动换行、命中测试、折叠占位符、inlay / ghost text 布局：
  - 先看 `layout.*`、`visual.h`
- 改装饰偏移、诊断、结构线、折叠：
  - 先看 `decoration.*`
- 改公共 ABI、二进制协议、枚举值：
  - 先改 `c_api.h` / `c_api.cpp`
  - 再同步 Swing / WinForms / Apple / Flutter / Avalonia
  - Android 若有同构能力，也要同步 JNI 路径
- 改接入层输入行为：
  - 先确认核心是否已有语义支持，再改接入层转发，不要把编辑规则写死在接入层

## 跨实现同步检查点

只要触发以下任一项，就不要只改一层：

- `c_api.h` 新增或修改函数
- 二进制 payload 字段顺序、类型或枚举值变更
- `EditorActionResult` / `ScrollMetrics` / `LayoutMetrics` 等 bridge 返回 payload 变更
- 渲染模型字段变更
- 和输入法、手势、折叠、装饰相关的核心行为变更

通常需要同步检查：

- Android：`jeditor.hpp`、`jni_entry.cpp`、Java `CoreProtocol`
- Swing：`EditorNative.java`、`CoreProtocol.java`
- WinForms：`EditorCore.cs`、`CoreProtocol.cs`
- Apple：`c_api.h`、`SweetEditorCore.swift`、`CoreProtocol.swift`
- Flutter：`editor_core.dart`、`core_protocol.dart`、`sweeteditor_bindings_generated.dart`
- Avalonia：`EditorCore.cs`、`CoreProtocol.cs`

## 构建入口

- 核心 / 测试：仓库根目录 `cmake` + `tests/CMakeLists.txt`
- Android：`platform/Android`
- Swing：`platform/Swing`
- WinForms：`platform/WinForms/WinForms.sln`
- Apple：`platform/Apple/Package.swift`
- Flutter：`platform/Flutter/sweeteditor`
- Avalonia：`platform/Avalonia/Avalonia.sln`

## 文档与编码约定

- 文档更新优先反映“当前代码已经实现的能力”，不要把路线图写成现状。
- Windows 仓库里遇到中文文件先确认编码；本仓库 `README.md` 和大多数 `docs/zh/*.md` 当前为 UTF-8。
- 接入协议改动后，`README.md`、`docs/zh/architecture.md`、`docs/en/architecture.md`，以及对应的 `docs/zh/api-platform*.md` / `docs/en/api-platform*.md` 至少同步一处说明。

## 命名风格（当前代码习惯）

- C++ 文件名小写，头文件用 `.h`，实现文件用 `.cpp`
- C++ 类型名使用 PascalCase
- C++ 函数名使用 lowerCamelCase
- C++ 成员变量通常使用 `m_` 前缀
- 接入层公开 API 优先语义化，桥接层保持贴近底层协议
