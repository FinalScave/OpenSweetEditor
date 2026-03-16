<div align="center">

**简体中文** | [English](README.md)

# SweetEditor

### 跨平台代码编辑器内核（C++17）

**一套 C++ 内核，面向多平台原生渲染，提供可长期演进的编辑基础设施。**

[![C++17](https://img.shields.io/badge/C++-17-blue.svg?logo=cplusplus)](https://isocpp.org/)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Swing%20%7C%20Web*%20%7C%20OHOS*-brightgreen.svg)](#平台接入状态当前代码)
[![License](https://img.shields.io/badge/License-LGPL--2.1%2B-yellow.svg)](LICENSE)

**Android · iOS · macOS · Windows · Swing · Web* · OHOS***

---

**核心与渲染彻底分离 · 单内核统一编辑语义 · 多平台原生接入**

**Ghost Text · Inlay Hints · 代码折叠 · 四类代码结构线 · Linked Editing**

**SIMD Unicode 加速 · Piece Table · 增量布局 · 视口渲染**

</div>

---

## 平台 Demo 截图

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Android</b><br/><img src="docs/snapshot/android.png" alt="Android 截图" width="170"/></td>
      <td align="center"><b>macOS</b><br/><img src="docs/snapshot/mac.png" alt="macOS 截图" width="360"/></td>
    </tr>
    <tr>
      <td align="center"><b>Windows (WinForms)</b><br/><img src="docs/snapshot/winforms.png" alt="WinForms 截图" width="360"/></td>
      <td align="center"><b>Swing</b><br/><img src="docs/snapshot/swing.png" alt="Swing 截图" width="360"/></td>
    </tr>
  </table>
</div>

> Android 原始截图分辨率较小，因此这里刻意采用较小展示宽度。

## 项目定位

SweetEditor 是一套跨平台代码编辑基础设施引擎，面向需要在 Android、iOS、macOS、Windows、Swing 上保持一致编辑行为的产品（Web/OHOS 正在接入中）。

它采用“**统一 C++17 内核 + 平台原生渲染**”架构：内核统一处理编辑语义与布局，平台层聚焦输入转发与绘制。

- 统一复用高亮、折叠、Inlay Hints、Ghost Text、结构线等高级能力
- 通过 Piece Table、增量布局、视口渲染、SIMD、mmap 保持可预测性能
- 核心逻辑集中在单一代码库，降低多平台回归和维护成本

## 整体架构

```
┌────────────────────────────────────────────────────────────────────┐
│                      平台层 (Input + Render)                      │
│                                                                    │
│ Android        iOS/macOS         Swing/WinForms        Web/OHOS    │
│ Canvas        CoreText/CG          Java2D / GDI+       (预留目录)   │
└───────────────┬───────────────────────────────┬────────────────────┘
                │                               │
                │ JNI 直连 C++                  │ C ABI / Binary Payload
                ▼                               ▼
      ┌─────────────────────┐         ┌──────────────────────────┐
      │ Android Bridge      │         │ C API Bridge             │
      │ (jni_entry+jeditor) │         │ extern "C" + intptr_t   │
      └───────────┬─────────┘         └────────────┬─────────────┘
                  └──────────────────────┬──────────┘
                                         ▼
      ┌──────────────────────────────────────────────────────────┐
      │                    SweetEditor Core (C++17)             │
      │  Document · TextLayout · DecorationManager · EditorCore │
      │  GestureHandler · UndoManager · LinkedEditing           │
      └──────────────────────────────────────────────────────────┘
```

整个引擎的核心设计原则：**核心与渲染彻底分离**。C++ 内核承担全部编辑逻辑，平台层只是一个轻量的渲染壳——每个平台通常只要几百行代码即可完成接入。

> 完整架构文档请参阅 [架构设计文档（中文）](docs/zh/architecture.md) / [Architecture (English)](docs/en/architecture.md)

## 平台接入状态（当前代码）


| 平台 | 对接层 | 渲染技术 | 状态 |
| --- | --- | --- | --- |
| **Android** | `SweetEditor` + JNI 直连 | Canvas + Paint | ✅ 已实现 |
| **iOS** | `SweetEditorViewiOS` | CoreText + CoreGraphics | ✅ 已实现 |
| **macOS** | `SweetEditorViewMacOS` | CoreText + CoreGraphics | ✅ 已实现 |
| **Windows** | `EditorControl` | GDI+ | ✅ 已实现 |
| **Swing** | `SweetEditor` | Java2D | ✅ 已实现 |
| **Web** | `platform/Emscripten` | - | 🚧 目录已建，绑定未接入 |
| **OHOS** | `platform/OHOS` | - | 🚧 目录占位 |

核心接入要求是实现测量回调、输入事件转发、二进制协议解码与平台绘制；编辑语义、布局与渲染模型由 C++ 内核统一生成。

## 当前功能全量清单（2026-03）

下面是按当前代码能力整理的完整特性清单。它不是路线图，而是“现在就支持”的功能面。

### 1) 文档与文本模型

- `LineArrayDocument` 与 `PieceTableDocument` 双文档实现，统一 UTF-8 存储。
- 支持从内存文本创建文档、从文件创建文档（核心 API）。
- 行文本查询、行数查询、全文查询（核心 API；C API 行文本读取路径返回 UTF-16；平台控件层支持可能存在差异）。
- 大文件加载路径支持 `mmap`。

### 2) 原子编辑能力

- 插入：`insertText`
- 精确替换：`replaceText`
- 精确删除：`deleteText`
- 退格删除：`backspace`
- 向前删除：`deleteForward`
- 行操作：`moveLineUp/down`、`copyLineUp/down`、`deleteLine`、`insertLineAbove/below`
- 撤销/重做：`undo` / `redo` / `canUndo` / `canRedo`
- 只读模式开关：`setReadOnly` / `isReadOnly`

### 3) 光标、选区与导航

- 光标定位：`setCursorPosition` / `getCursorPosition`
- 选区控制：`setSelection` / `getSelection` / `selectAll` / `getSelectedText`
- 单词查询：`getWordRangeAtCursor` / `getWordAtCursor`
- 光标移动：左/右/上/下、行首/行尾、可选扩展选区
- 导航：`scrollToLine`（Top/Center/Bottom）与 `gotoLine`
- 位置查询：`getPositionRect` / `getCursorRect`（用于浮层锚定）

### 4) 输入系统（触摸/鼠标/键盘/IME）

- 手势类型：单击、双击、长按、滚动、快速滚动、缩放、拖拽选择、上下文菜单。
- 鼠标事件：左键、右键、拖拽、滚轮。
- 键盘事件：方向键、Home/End/PageUp/PageDown、常用编辑快捷键（含修饰键位标志）。
- IME 组合输入全链路：`compositionStart/update/end/cancel`、`isComposing`。
- IME 组合输入可开关：`setCompositionEnabled` / `isCompositionEnabled`（是否对外暴露取决于平台控件层）。

### 5) 布局与渲染

- 自动换行模式：`NONE` / `CHAR_BREAK` / `WORD_BREAK`
- 自动缩进模式：`NONE` / `KEEP_INDENT`
- 折叠箭头模式：`AUTO` / `ALWAYS` / `HIDDEN`
- 行距参数：`lineHeight = fontHeight * mult + add`
- 渲染模型输出：`buildRenderModel`（native-endian 二进制 payload，文本字段当前按 UTF-8 编码）
- 布局参数输出：`getLayoutMetrics`（native-endian 二进制 payload）
- 视口裁剪与增量布局（仅输出可见区域模型）

### 6) 样式与装饰系统

- 样式注册：前景色、背景色、字体位标志（粗体/斜体/删除线）
- 高亮层：`SYNTAX` / `SEMANTIC`
- 行级 Span 设置与清理：`setLineSpans` / `clearLineSpans` / `clearHighlightsLayer`
- Inlay Hints 三形态：文本、图标、颜色块
- Phantom Text（Ghost Text）渲染
- 诊断装饰：按行设置区间（`severity + color`）
- Gutter 图标：增删清理 + 最大图标数控制
- 结构线（Guide）四类：缩进线、括号分支线、控制流回退箭头、分隔线
- 括号高亮：`setBracketPairs`、`setMatchedBrackets`、`clearMatchedBrackets`
- 一键清理：高亮 / Inlay / Phantom / 全部装饰

### 7) 代码折叠

- 折叠区域批量设置（start/end/collapsed）
- 单行折叠切换：`toggleFold`（例如 Android 控件层方法名为 `toggleFoldAt`）
- 强制折叠/展开：`foldAt` / `unfoldAt`
- 全量折叠/展开：`foldAll` / `unfoldAll`
- 行可见性查询：`isLineVisible`

### 8) Snippet 与 Linked Editing

- Snippet 插入：`insertSnippet`
- LinkedEditingModel 构建：分组、默认文本、多范围映射
- 会话控制：`startLinkedEditing` / `isInLinkedEditing`
- 跳转：`linkedEditingNext` / `linkedEditingPrev`
- 取消：`cancelLinkedEditing`

### 9) 平台侧可扩展机制

- DecorationProvider：异步装饰提供、合并与增量刷新
- CompletionProvider：触发字符判断、异步候选返回、重触发机制
- 补全 UI：候选面板、上下导航、回车确认、自定义渲染

### 10) 工程与性能基础

- [simdutf](https://github.com/simdutf/simdutf) SIMD Unicode 转码链路
- 文本宽度测量缓存与字体指标缓存
- 视口级重建与绘制，避免全量重排
- Android / WinForms 内置可开关的性能 overlay（调试用途）
- 核心逻辑集中在单一 C++ 内核，平台层聚焦输入转发与原生绘制

一句话总结：SweetEditor 已经不是“能编辑文本”的控件，而是一套可承载 IDE、AI 编程工具、云开发工作台的跨平台编辑器内核能力面。

## 快速开始

### 构建

```bash
git clone https://github.com/aspect-aspect/SweetEditor.git
cd SweetEditor

# macOS / Linux
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Android（需要 NDK）
cmake .. -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
         -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21

# WebAssembly（需要 Emscripten，当前仅核心构建，平台绑定未接入）
emcmake cmake .. -DCMAKE_BUILD_TYPE=Release
emmake make
```

### 集成示例

**Android**

```java
SweetEditor editor = new SweetEditor(context);
editor.applyTheme(EditorTheme.dark());
editor.loadDocument(new Document("Hello, SweetEditor!"));

editor.registerStyle(1, 0xFF569CD6, FontStyle.BOLD);
editor.setLineSpans(
    0,
    SpanLayer.SYNTAX,
    java.util.List.of(new StyleSpan(0, 5, 1))
);
editor.setLinePhantomTexts(
    0,
    java.util.List.of(new PhantomText(19, "\n  // AI 生成的建议"))
);
```

**iOS / macOS**

```swift
// iOS UIKit
let iosEditor = SweetEditorViewiOS(frame: .zero)
iosEditor.applyTheme(isDark: isDark)
iosEditor.loadDocument(text: "Hello, SweetEditor!")

// macOS AppKit
let macEditor = SweetEditorViewMacOS(frame: .zero)
macEditor.applyTheme(isDark: isDark)
macEditor.loadDocument(text: "Hello, SweetEditor!")

// SwiftUI
// WIP：SwiftUI 封装暂未完善，当前不可用。
// SweetEditorSwiftUIViewiOS(isDarkTheme: isDark)
// SweetEditorSwiftUIMacOS(isDarkTheme: isDark)
```

**Windows**

```csharp
var editor = new EditorControl();
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
```

## 第三方依赖

SweetEditor 坚持最小依赖原则：核心引擎运行时仅依赖 3 个轻量库，测试再额外使用 Catch2。


| 库                                                | 用途                        | 包体影响   |
| ------------------------------------------------- | --------------------------- | ---------- |
| [simdutf](https://github.com/simdutf/simdutf)     | SIMD 加速 Unicode 编解码    | ~200KB     |
| [nlohmann/json](https://github.com/nlohmann/json) | JSON 调试导出与内部辅助结构（非平台主协议） | 纯头文件   |
| [utfcpp](https://github.com/nemtrif/utfcpp)       | UTF-8 迭代与校验            | 纯头文件   |
| [Catch2](https://github.com/catchorg/Catch2)      | 单元测试框架（仅测试用）    | 不打进产物 |

## 文档


| 文档                                      | 说明                                            |
| ----------------------------------------- | ----------------------------------------------- |
| [架构设计（中文）](docs/zh/architecture.md) / [Architecture (EN)](docs/en/architecture.md) | 核心架构、模块设计、数据流、渲染流水线 |
| [EditorCore API（中文）](docs/zh/api-editor-core.md) / [EditorCore API (EN)](docs/en/api-editor-core.md) | C++ 核心层和 C API 完整参考 |
| [平台 API 索引（中文）](docs/zh/api-platform.md) / [Platform API Index (EN)](docs/en/api-platform.md) | 各平台 API 文档入口（Android / Swing / Apple / WinForms） |
| [参与共建（中文）](docs/zh/join.md) / [Contributing (EN)](docs/en/join.md) | 仓库结构、阅读入口、平台同步检查点 |

## 参与共建

SweetEditor 正在构建一个开放的跨平台编辑器基础设施生态，欢迎参与共建。

详见 [参与共建指南（中文）](docs/zh/join.md) / [Contributing Guide (EN)](docs/en/join.md)。

## License

SweetEditor 采用 [GNU Lesser General Public License v2.1 or later](LICENSE)（LGPL-2.1+）授权，
并附加 [Static Linking Exception](EXCEPTION) 作为补充说明。
