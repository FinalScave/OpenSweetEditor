<div align="center">

**简体中文** | [English](README.md)

# SweetEditor

### 跨平台代码编辑器内核（C++17）

**C++17 内核 + 平台原生渲染，面向 IDE、AI 编程工具、云开发工作台等长期演进的编辑基础设施场景。**

[![C++17](https://img.shields.io/badge/C++-17-blue.svg?logo=cplusplus)](https://isocpp.org/)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Swing%20%7C%20OHOS%20%7C%20Web*-brightgreen.svg)](#平台支持状态)
[![License](https://img.shields.io/badge/License-LGPL--2.1%2B-yellow.svg)](LICENSE)

**Android · iOS · macOS · Windows · Swing · OHOS · Web\***

</div>

---

## 项目定位

SweetEditor 是一套跨平台代码编辑器内核，面向需要在 Android、iOS、macOS、Windows、Swing 和 OHOS 上保持一致编辑行为的产品。

它采用“**C++17 内核 + 平台原生渲染**”架构：C++ 内核负责文档编辑语义、文本布局与装饰模型，各平台层负责输入转发与绘制。

适合用于 IDE、AI 编程工具、云开发工作台等需要长期演进的编辑基础设施场景。

## 核心特性

- **统一内核，多平台复用**：高亮、折叠、Inlay Hints、Ghost Text、结构线等能力由单一 C++ 内核统一生成
- **核心与渲染分离**：平台层聚焦输入桥接与原生绘制，降低多平台回归和维护成本
- **高级编辑能力完整**：支持代码折叠、Snippet、Linked Editing、诊断装饰、补全扩展等能力
- **性能路径明确**：基于 Piece Table、增量布局、视口渲染、SIMD Unicode 加速与 mmap 大文件加载
- **原生接入友好**：已适配 Android、Apple 平台、Windows、Swing 和 OHOS，Web 当前为测试状态，由非官方 fork 仓库维护

## 平台支持状态

| 平台 | 状态 | 渲染技术                    | UI 框架 | 实现来源                                                                                                                      |
| --- | --- |-------------------------| --- |---------------------------------------------------------------------------------------------------------------------------|
| Android | 已实现 | Canvas + Paint          | Android View | [./platform/Android](./platform/Android)                                                                               |
| iOS | 已实现 | CoreText + CoreGraphics | UIKit / SwiftUI（正在完善） | [./platform/Apple](./platform/Apple)                                                                                   |
| macOS | 已实现 | CoreText + CoreGraphics | AppKit / SwiftUI（正在完善） | [./platform/Apple](./platform/Apple)                                                                                   |
| Windows | 已实现 | GDI+                    | WinForms | [./platform/WinForms](./platform/WinForms)                                                                             |
| Swing | 已实现 | Java2D                  | Swing | [./platform/Swing](./platform/Swing)                                                                                   |
| OHOS | 已实现 | ArkUI Canvas            | ArkUI | [./platform/OHOS](./platform/OHOS)                                                                                     |
| Flutter | 已实现 | TextPainter             | Flutter | [./platform/Flutter](./platform/Flutter)                                                                               |
| Avalonia | 已实现 | Direct2D / Skia         | Avalonia UI | [./platform/Avalonia](./platform/Avalonia)                                                                             |
| Compose Multiplatform | 进行中 | Compose Canvas          | Compose | [lumkit/SweetEditor-Compose](https://github.com/lumkit/SweetEditor-Compose)                                              |
| Web | 测试中（非官方） | -                       | - | [LangLang03/OpenSweetEditor-Web](https://github.com/LangLang03/OpenSweetEditor-Web/tree/main/platform/Emscripten) |
| Qt | 待实现 | -                       | Qt | -                                                                                                                         |
| C# WinUI | 待实现 | -                       | - | -                                                                                                                         |

## 整体架构

```text
+-----------------------------------------------------------------------------------+
|                          平台层（Input + Render）                                 |
|                                                                                   |
| Android        Apple         Swing / WinForms      OHOS            Web*           |
| Canvas         CoreText/CG   Java2D / GDI+         ArkUI Canvas    测试中         |
+----------------+-------------+----------------------+---------------+--------------+
         |               |                 |                    |
         | JNI 直连      | 手工 C bridge   | C API / payload    | NAPI 直连
         v               v                 v                    v
+----------------+ +----------------+ +------------------+ +-------------------+
| JNI Bridge     | | Apple Bridge   | | C API Bridge     | | OHOS NAPI Bridge |
| jni_entry      | | Swift + C      | | extern "C"       | | ArkTS + NAPI     |
+----------------+ +----------------+ +------------------+ +-------------------+
          \               |                 |                    /
           \              |                 |                   /
            +-------------+-----------------+------------------+
                                  |
                                  v
               +--------------------------------------------------+
               |             SweetEditor Core (C++17)             |
               | Document / TextLayout / DecorationManager /      |
               | EditorCore / GestureHandler / UndoManager /      |
               | LinkedEditing                                    |
               +--------------------------------------------------+
```

> 完整架构文档请参阅 [架构设计文档](docs/zh/architecture.md)

## 核心能力

C++ 内核涵盖文档编辑（Piece Table、撤销重做、大文件加载）、文本布局（自动换行、增量布局、视口裁剪）、样式与装饰（语法/语义高亮、Inlay Hints、Ghost Text、诊断、结构线）、高级编辑（代码折叠、Snippet、Linked Editing）以及平台扩展机制（DecorationProvider、CompletionProvider）。性能基于 SIMD Unicode 转码、测量缓存与视口级渲染构建。

完整能力清单见：[EditorCore API（中文）](docs/zh/api-editor-core.md)。

## 快速开始

### 构建

```bash
git clone https://github.com/FinalScave/OpenSweetEditor.git
cd OpenSweetEditor
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j
```

各平台快速接入指南及 WebAssembly 测试构建说明，请参阅 [平台 API 索引](docs/zh/api-platform.md)。

### 最小集成示例

```java
SweetEditor editor = new SweetEditor(context);
editor.applyTheme(EditorTheme.dark());
editor.loadDocument(new Document("Hello, SweetEditor!"));
```

更多示例请参阅平台 API 文档。

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

> Android 原始截图分辨率较小，因此这里采用较小展示宽度。

## 依赖

SweetEditor 坚持最小依赖原则，核心运行时仅依赖少量轻量库：

- [simdutf](https://github.com/simdutf/simdutf)：SIMD 加速 Unicode 编解码
- [nlohmann/json](https://github.com/nlohmann/json)：JSON 调试导出与内部辅助结构
- [utfcpp](https://github.com/nemtrif/utfcpp)：UTF-8 迭代与校验

测试使用 [Catch2](https://github.com/catchorg/Catch2)。

## 文档

| 文档 | 说明 |
| --- | --- |
| [架构设计](docs/zh/architecture.md) | 核心架构、模块设计、数据流、渲染流水线 |
| [EditorCore API（中文）](docs/zh/api-editor-core.md) | C++ 核心层和 C API 参考 |
| [平台 API 索引（中文）](docs/zh/api-platform.md) | Android、Swing、Apple、WinForms、OHOS 平台 API 文档入口 |
| [平台实现标准](docs/zh/platform-implementation-standard.md) | 所有平台实现必须遵循的类型清单、模块结构、API 契约与合规规则 |
| [参与共建](docs/zh/join.md) | 仓库结构、阅读入口、平台同步检查点 |

## 参与共建

SweetEditor 正在构建开放的跨平台编辑器基础设施生态，欢迎参与共建。

详见 [参与共建指南](docs/zh/join.md)。

## Community

<table width="100%">
  <tr>
    <td width="33%" valign="top" align="center">
      <strong>QQ</strong><br><br>
      <img src="docs/imgs/qrcode_qq_group.jpg" alt="QQ群二维码" width="150"/>
      <p>QQ群号：1090609035</p>
    </td>
    <td width="33%" valign="top" align="center">
      <strong>微信</strong><br><br>
      <img src="docs/imgs/qrcode_wechat.png" alt="微信群二维码" width="200"/>
    </td>
    <td width="33%" valign="top" align="center">
      <strong>Discord</strong><br><br>
      <a href="https://discord.gg/q5u4tGMgKQ" target="_blank">加入 Discord</a>
    </td>
  </tr>
</table>

## License

SweetEditor 采用 [GNU Lesser General Public License v2.1 or later](LICENSE)（LGPL-2.1+）授权，并附加 [Static Linking Exception](EXCEPTION) 作为补充说明。

## Star History

<a href="https://www.star-history.com/#FinalScave/OpenSweetEditor&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=FinalScave/OpenSweetEditor&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=FinalScave/OpenSweetEditor&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=FinalScave/OpenSweetEditor&type=date&legend=top-left" />
 </picture>
</a>
