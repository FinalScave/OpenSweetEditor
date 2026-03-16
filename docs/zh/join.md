# 参与共建

本文档是基于当前仓库结构给出的实际开发入口。文档若与代码冲突，以代码为准。

## 建议阅读顺序

1. `docs/zh/architecture.md`
2. `docs/zh/api-editor-core.md`
3. `src/include/*.h`
4. `src/core/*.cpp`
5. 最后再看 `platform/*`

## 仓库地图

```text
├── 3dparty
│   ├── simdutf / json / utfcpp      第三方依赖
├── docs
│   ├── zh/architecture.md           架构总览（中文）
│   ├── zh/api-editor-core.md        C API / 核心契约（中文）
│   ├── zh/api-platform*.md          各平台 API 文档（中文）
│   ├── en/architecture.md           架构总览（英文）
│   ├── en/api-editor-core.md        C API / 核心契约（英文）
│   └── en/api-platform*.md          各平台 API 文档（英文）
├── src
│   ├── include                      核心头文件与 c_api.h
│   └── core                         Document / Layout / Decoration / EditorCore / c_api
├── tests                            核心回归测试
└── platform
    ├── Android                      Android SDK + JNI 直连
    ├── Swing                        Java FFM + C API
    ├── WinForms                     C# P/Invoke + C API
    ├── Apple                        Swift Package + 手工 C bridge
    ├── Emscripten                   Web 预留目录（bindings 为空）
    └── OHOS                         预留目录
```

## 平台目录职责

### 核心层

- `src/include/document.h` / `src/core/document.cpp`
  - 文本存储、位置映射、Piece Table / LineArray 实现
- `src/include/layout.h` / `src/core/layout.cpp`
  - 文本布局、自动换行、命中测试、测量缓存、可见区裁剪
- `src/include/decoration.h` / `src/core/decoration.cpp`
  - 高亮、Inlay Hint、Ghost Text、结构线、折叠、诊断等装饰
- `src/include/editor_core.h` / `src/core/editor_core.cpp`
  - 编辑语义总协调器：输入、选区、IME、撤销重做、渲染模型组装
- `src/include/c_api.h` / `src/core/c_api.cpp`
  - 非 Android 平台的稳定桥接边界

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

- `platform/WinForms/SweetEditor/EditorControl.cs`
  - WinForms 控件层、输入与绘制
- `platform/WinForms/SweetEditor/EditorCore.cs`
  - P/Invoke 封装与协议对接
- `platform/WinForms/SweetEditor/EditorProtocol.cs`
  - binary payload 解码
- `platform/WinForms/SweetEditor/EditorExtension.cs`
  - Completion / Decoration provider 等扩展能力
- `platform/WinForms/SweetEditor/Perf.cs`
  - 性能记录与 overlay 绘制

### Apple

- `platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
  - 手工 C bridge 头
- `platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
  - Swift 侧核心封装与二进制协议解码
- `platform/Apple/Sources/SweetEditoriOS`
- `platform/Apple/Sources/SweetEditorMacOS`
  - iOS / macOS 平台视图

## 修改什么，就从哪里进

- 改文本编辑语义、撤销重做、选区、IME：
  - 先看 `editor_core.*`、`document.*`、`gesture.*`
- 改自动换行、命中测试、折叠占位符、inlay / ghost text 布局：
  - 先看 `layout.*`、`visual.h`
- 改装饰偏移、诊断、结构线、折叠：
  - 先看 `decoration.*`
- 改公共 ABI、二进制协议、枚举值：
  - 先改 `c_api.h` / `c_api.cpp`
  - 再同步 Swing / WinForms / Apple
  - Android 若有同构能力，也要同步 JNI 路径
- 改平台输入行为：
  - 先确认核心是否已有语义支持，再改平台转发，不要把编辑规则写死在平台层

## 平台同步检查点

只要触发以下任一项，就不要只改一层：

- `c_api.h` 新增或修改函数
- 二进制 payload 字段顺序、类型或枚举值变更
- `TextEditResult` / `GestureResult` / `KeyEventResult` / `ScrollMetrics` / `LayoutMetrics` 变更
- 渲染模型字段变更
- 和输入法、手势、折叠、装饰相关的核心行为变更

通常需要同步检查：

- Android：`jeditor.hpp`、`jni_entry.cpp`、Java `ProtocolDecoder`
- Swing：`EditorNative.java`、`ProtocolDecoder.java`
- WinForms：`EditorCore.cs`、`EditorProtocol.cs`
- Apple：`SweetEditorBridge.h`、`SweetEditorCore.swift`

## 构建入口

- 核心 / 测试：仓库根目录 `cmake` + `tests/CMakeLists.txt`
- Android：`platform/Android`
- Swing：`platform/Swing`
- WinForms：`platform/WinForms/WinForms.sln`
- Apple：`platform/Apple/Package.swift`

## 文档与编码约定

- 文档更新优先反映“当前代码已经实现的能力”，不要把路线图写成现状。
- Windows 仓库里遇到中文文件先确认编码；本仓库 `README.md` 和大多数 `docs/zh/*.md` 当前为 UTF-8。
- 平台协议改动后，`README.md`、`docs/zh/architecture.md`、`docs/en/architecture.md`，以及对应的 `docs/zh/api-platform*.md` / `docs/en/api-platform*.md` 至少同步一处说明。

## 命名风格（当前代码习惯）

- C++ 文件名小写，头文件用 `.h`，实现文件用 `.cpp`
- C++ 类型名使用 PascalCase
- C++ 函数名使用 lowerCamelCase
- C++ 成员变量通常使用 `m_` 前缀
- 平台层公开 API 优先语义化，桥接层保持贴近底层协议
