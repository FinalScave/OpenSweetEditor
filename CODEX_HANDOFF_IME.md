# SweetEditor IME 交接

## 当前用户要求

用户准备开新会话，需要新会话能继续接上当前 IME 修复。回复用户时使用中文；提交信息若需要 commit，使用英文 conventional commit 格式。仓库指令要求执行编辑前先和用户讨论，本文件是用户明确要求写入的交接文件。

## 背景问题

用户反馈：

- Flutter Windows 输入已基本正常。
- Flutter Android 曾出现首次输入无效、候选点击无法替换、下划线残留和高亮错乱。
- 之前把 Flutter Android 修好后，又把原生 Android 改坏：Android 点击单词出现候选后，再点输入法输入会直接替换单词，而不是插入。
- 用户不希望平台侧维护复杂状态机，希望各平台基本封装成 core 结构后直接调用。

当前判断：

- 原方向中平台侧维护过多状态不是最合适。
- core 旧模型把“真实预编辑 composition”和“平台候选/纠错 marked range”混在一个 `composition` 字段里，导致 Android `setComposingRegion` 这类候选标记被 `BaseInputConnection` 当成可替换 composing span。
- 正确方向是 core 协议显式区分 range 的语义，平台侧只做薄映射。

## 当前设计

新增：

- `ImeMarkedRangeKind`
  - `NONE`
  - `COMPOSITION`
  - `PLATFORM_MARKED`
- `ImeInputContext`
  - `has_composition` / `composition`：真实可编辑预编辑范围。
  - `has_platform_marked_range` / `platform_marked_range`：候选、纠错、平台标记范围。
- `ImeTextModelState` / `ImeTextModelDelta`
  - 新增 `marked_range_kind`，默认值为 `COMPOSITION`。

语义约定：

- `COMPOSITION` 表示传入的 `composition` 是真实预编辑，core 可以创建/更新 visible composition。
- `PLATFORM_MARKED` 表示传入的 `composition` 是平台候选或纠错标记，core 只记住平台 marked range，不创建真实 composition。
- `NONE` 表示没有 marked range。
- Flutter 因为 framework 只有一个 `TextEditingValue.composing` 通道，所以把 core 的 `platformMarkedRange` 映射回 Flutter composing 展示；上报 core 时显式使用 `PLATFORM_MARKED`。
- Android 原生的 `setComposingRegion` 映射为 `PLATFORM_MARKED`，并且不再写入 `Editable` 的 composing span；`setComposingText` / `commitText` 仍按真实 `COMPOSITION` 流转。

## 已改文件和重点

core:

- `include/sweeteditor/ime_types.h`
  - 新增 `ImeMarkedRangeKind`。
  - `ImeInputContext` 新增 platform marked 字段。
  - `ImeTextModelState/Delta` 新增 `marked_range_kind`，默认 `COMPOSITION`。
- `include/sweeteditor/editor_core.h`
  - 多个 IME 内部函数增加 `ImeMarkedRangeKind` 参数。
- `src/editor_core_ime.cpp`
  - 删除了基于脚本类型猜测 hidden/platform-only composition 的逻辑。
  - 改成完全根据 `marked_range_kind` 判断。
  - `buildImeInputContext` 同时输出真实 composition 和 platform marked range。
  - `rememberImeInputState` 同步保存两类 range。
  - 修了一个重要路径：已有 platform marked range 后，如果下一次上报是真实 `COMPOSITION`，不能把旧 platform mark 当成候选替换提前消费；应进入真实 preedit 分支。
- `src/editor_core.cpp`
  - 之前已有 IME sync 相关小改动，当前工作区仍包含。
- `include/sweeteditor/c_api.h`
  - 补了 text model payload 注释里的 `ImeMarkedRangeKind marked_range_kind`。

Android:

- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditorInputConnection.java`
  - 引入 `ImeMarkedRangeKind`。
  - `setComposingRegion` 不再调用 `super.setComposingRegion`，改为 `removeComposingSpans` 后上报 `PLATFORM_MARKED`。
  - `setComposingText` / `commitText` 通过默认路径上报 `COMPOSITION`。
  - `syncEditableFromContext` 保存 core 返回的 `platformMarkedRange`，但只对真实 `hasComposition` 调用 `super.setComposingRegion`。
  - `updateSelection` 优先把 platform marked range 报给 IME。
  - 修过一个机械错误：`pushEditableTextState(perfName)` 不能硬编码 `"ime-update"`。
- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
  - 工作区有此前 restart input/context 相关改动，保留不动。

Flutter:

- `platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart`
  - `_updateImeTextModelState` / `_updateImeTextModelDelta` 上报 `markedRangeKind`。
  - `_buildEditingValueFromEditor` 优先使用 `inputContext.platformMarkedRange`，再 fallback 到 `composition`。
  - 保留此前 `_textInputContextReady`、document loaded 清理 context、delta dispatch 不清 context 等修复。

协议生成文件：

- 已运行：
  - `python tools\se_protocol_gen\src\se_protocol_gen.py generate --write-targets --update-snapshot`
- 生成层涉及 Android/Swing Java、Flutter Dart、Apple Swift、OHOS ETS、Avalonia/WinForms C#、`include/sweeteditor/protocol_codec.h`。
- 新增未跟踪文件：
  - `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeMarkedRangeKind.java`
  - `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeMarkedRangeKind.java`

测试：

- `tests/core/editor/editor_composition.cpp`
  - 测试辅助函数新增可选 `ImeMarkedRangeKind` 参数，默认 `COMPOSITION`。
  - 平台标记测试显式传 `PLATFORM_MARKED`，不再依赖 `LATIN/CJK` 推断。
  - 新增回归测试：`EditorCore IME text model platform marked range does not replace later insertion`，覆盖 Android 点击候选标记后继续输入应插入而不是替换。

## 已验证

已执行并通过：

```powershell
cmake --build build --target unit_tests --config Debug
build\bin\Debug\unit_tests.exe
flutter analyze
```

core 单测结果：

- `All tests passed (3898 assertions in 199 test cases)`

Flutter analyze 结果：

- `No issues found`

注意：`flutter analyze` 是在同一轮改动中通过的；之后又重新跑过一次协议生成器以去掉 `dart format` 对 generated Dart 的大面积重排，只保留生成器输出。建议新会话接手后再跑一次 `flutter analyze` 做最终确认。

## 当前工作区状态

截至交接前，`git status --short` 显示这些文件有改动：

```text
 M include/sweeteditor/c_api.h
 M include/sweeteditor/editor_core.h
 M include/sweeteditor/ime_types.h
 M include/sweeteditor/protocol_codec.h
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditorInputConnection.java
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/CoreProtocol.java
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeInputContext.java
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeTextModelDelta.java
 M platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeTextModelState.java
 M platform/Apple/Sources/SweetEditorCoreInternal/core/CoreIme.swift
 M platform/Apple/Sources/SweetEditorCoreInternal/core/CoreProtocol.swift
 M platform/Avalonia/SweetEditor/CoreIme.cs
 M platform/Avalonia/SweetEditor/CoreProtocol.cs
 M platform/Flutter/sweeteditor/lib/core/core_ime.dart
 M platform/Flutter/sweeteditor/lib/core/core_protocol.dart
 M platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart
 M platform/OHOS/sweeteditor/src/main/ets/core/CoreIme.ets
 M platform/OHOS/sweeteditor/src/main/ets/core/CoreProtocol.ets
 M platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/CoreProtocol.java
 M platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeInputContext.java
 M platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeTextModelDelta.java
 M platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeTextModelState.java
 M platform/WinForms/SweetEditor/CoreIme.cs
 M platform/WinForms/SweetEditor/CoreProtocol.cs
 M prebuilt/android/arm64-v8a/libsweeteditor.so
 M prebuilt/android/x86_64/libsweeteditor.so
 M prebuilt/windows/x64/sweeteditor.dll
 M src/editor_core.cpp
 M src/editor_core_ime.cpp
 M tests/core/editor/editor_composition.cpp
?? platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeMarkedRangeKind.java
?? platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/ime/ImeMarkedRangeKind.java
```

`git diff --check` 只有 line ending warning，没有 whitespace error：

- 多个文件提示 `LF will be replaced by CRLF the next time Git touches it`。

## 待办建议

新会话建议按这个顺序继续：

- 先读本文件和当前 diff，特别是 `src/editor_core_ime.cpp`、`SweetEditorInputConnection.java`、`sweet_editor_widget.dart`。
- 再跑一次：
  - `cmake --build build --target unit_tests --config Debug`
  - `build\bin\Debug\unit_tests.exe`
  - `flutter analyze`，工作目录 `platform\Flutter\sweeteditor`
- 尝试 Android Gradle 编译：
  - 工作目录 `platform\Android`
  - 可先看可用 task，再跑 library/demo 编译。
- 重新生成 prebuilt 二进制。当前 `prebuilt/android/*.so` 和 `prebuilt/windows/x64/sweeteditor.dll` 已是 modified，但它们可能是本轮最终 core 改动之前的旧产物。建议重新跑 release build 和 Flutter native sync 后再提交。
- 复核 generated protocol 文件不要被额外格式化工具大面积重排。
- 如果用户要求 commit，commit message 建议：
  - `fix(ime): separate platform marked ranges from composition`

## 新会话提示词

可以直接把下面这段发给新会话：

```text
你在 D:\Projects\CrossPlatform\SweetEditor 继续 SweetEditor IME 修复。请先完整阅读 CODEX_HANDOFF_IME.md 和 AGENTS.md。回答中文；编辑前先和我讨论；不要回滚用户或前序会话已有改动。

当前目标：继续收敛 IME 模型修复。核心方向是把真实 composition 和平台候选/纠错 platform marked range 在 core 协议中显式分离，避免 Android setComposingRegion 造成后续输入替换单词，同时保持 Flutter Android 的候选点击/下划线/高亮行为正常。

已做但需复核：
- include/sweeteditor/ime_types.h 新增 ImeMarkedRangeKind，并在 ImeInputContext、ImeTextModelState、ImeTextModelDelta 中加入 platform marked / markedRangeKind 字段。
- src/editor_core_ime.cpp 已改成用 marked_range_kind 决定 COMPOSITION vs PLATFORM_MARKED，不再靠脚本类型猜测。
- Android SweetEditorInputConnection.java 中 setComposingRegion 上报 PLATFORM_MARKED，不写 BaseInputConnection composing span；setComposingText/commitText 仍是 COMPOSITION。
- Flutter sweet_editor_widget.dart 中 TextEditingValue.composing 上报 PLATFORM_MARKED，并从 core 的 platformMarkedRange 回填 composing。
- 协议生成器已跑过，新增 Android/Swing 的 ImeMarkedRangeKind.java。
- core 单测和 flutter analyze 曾通过，但最后交接前建议你重新跑。

请重点做：
1. 复核当前 diff 是否收敛，特别是 core IME 分支、Android InputConnection、Flutter text input model。
2. 重新跑 core 单测、flutter analyze、Android Gradle 编译。
3. 重新生成 prebuilt android/windows 二进制并同步 Flutter native binaries。
4. 最后给我中文总结；如果我让你 commit，用英文 conventional commit，例如 fix(ime): separate platform marked ranges from composition。
```
