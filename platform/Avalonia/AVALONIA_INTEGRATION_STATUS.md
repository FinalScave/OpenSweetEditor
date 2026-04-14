# Avalonia Integration Status

This document tracks the current Avalonia platform alignment with the project implementation standard. Chinese is the source wording for current development notes; English summaries are included where helpful.

## 当前完成项

- 核心桥接：`EditorCore` 已覆盖文档加载、编辑命令、撤销重做、光标/选区、滚动、折叠、IME、linked editing、snippet、装饰、guide、matched bracket、render model 拉取等标准 API。
- 生命周期：`EditorCore.Dispose()` 会释放 C++ `free_editor` native handle，重复释放幂等；显式释放后直接访问 `EditorCore` 会抛出 `ObjectDisposedException`，不会继续触达已释放 native 资源。
- 控件与控制器：`SweetEditorControl` 与 `SweetEditorController` 已对齐公开命令面和事件集合，Controller 支持未绑定调用排队、绑定后 replay、teardown 后 no-op。
- 渲染协议：Avalonia 已消费新版 render model 字段，包括 `VisualLineKind`、`OwnsGutterSemantics`、composition decoration、guide segments、diagnostic decorations、linked editing rects、bracket highlight rects。
- CodeLens：已实现 `CodeLensItem`、`SetLineCodeLens`、`SetBatchLineCodeLens`、`ClearCodeLens`、`CodeLensClick` 事件、命中回传与 active underline 渲染；同一行 CodeLens 会按 `column` 升序打包。
- Diagnostics：标准模型为 `Diagnostic`，旧 `DiagnosticItem` 保留为兼容别名；Decoration provider 和 Demo 均已切到 `Diagnostic` 通路。
- Provider：Decoration / Completion / NewLine / InlineSuggestion / SelectionMenu 均以 Avalonia manager/provider 形式接入，异步结果通过 generation/stale receiver 丢弃过期结果。
- SweetLine：Demo.Shared 直接依赖 `SweetLine` NuGet 包，不再维护本地 SweetLine P/Invoke wrapper；Linux/macOS 走 NuGet RID assets，Android 由平台层 staging `libsweetline.asset` 并设置 `SWEETLINE_LIB_PATH`。
- Android Demo：IME 可视区域、safe area、生命周期诊断、SweetLine native staging 和大文档 SweetLine slice/session 逻辑已收口在 Android 平台层或 Demo.Shared 对应模块。
- 文档：`docs/zh/api-platform-avalonia.md`、`docs/en/api-platform-avalonia.md`、Demo README、Android README 和 Termux 构建文档已同步当前实现。

## 验证记录

以下命令已在当前 Termux/Android 环境验证：

```bash
dotnet build Demo.Shared/Demo.Shared.csproj -c Release
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net8.0-android -m:1 -p:RuntimeIdentifier=android-arm64 -p:AndroidSdkDirectory=/data/data/com.termux/files/home/android-sdk -p:Aapt2ToolPath=/data/data/com.termux/files/usr/bin -p:Aapt2ToolExe=aapt2 -p:AndroidBinUtilsDirectory=/data/data/com.termux/files/usr/bin -p:ZipAlignToolPath=/data/data/com.termux/files/usr/bin -p:ZipalignToolExe=zipalign -p:RunAOTCompilation=false -p:PublishAot=false -p:AndroidEnableProfiledAot=false -p:AndroidEnableLLVM=false -p:UseInterpreter=true
adb install -r Demo.Android/bin/Debug/net8.0-android/android-arm64/com.qiplat.sweeteditor.avalonia.demo.android-Signed.apk
adb shell am start -W -n com.qiplat.sweeteditor.avalonia.demo.android/crc6458426131d5b6d3ae.MainActivity
```

最近一次结果：

- `Demo.Shared` Release 构建通过，0 warning / 0 error。
- `Demo.Android` Debug arm64 构建通过，0 warning / 0 error。
- APK 安装成功，冷启动 `Status: ok`。
- 启动后进程保持存活，筛选 `AndroidRuntime` / `DEBUG` / `libc` / `mono-rt` / `SweetEditorDemo` crash 日志为空。

## 剩余未完善项

这些项目前不阻塞核心 Avalonia 对接，但属于标准文档中的 SHOULD/MAY 或需要目标平台实机验证的部分：

- 平台层测试：尚未新增 Avalonia 单元测试/契约测试工程，例如 `EditorSettings` 默认值、API 行为、事件序列和 render model 兼容性测试。
- Provider 超时：当前通过 generation/stale receiver 丢弃过期结果，尚未实现 decoration 5s / completion 3s 的显式 timeout 标记策略。
- 无障碍：尚未系统化暴露文本编辑器角色、可见文本、光标/选区给屏幕阅读器；这是 SHOULD/MAY 级后续项。
- Desktop/Mac/iOS 运行态：代码已共享同一 Demo.Shared 和平台服务抽象，但当前环境只完成 Android APK 构建/安装/启动验证；Desktop/Mac/iOS 仍需要对应平台环境 smoke test。
- 平台特性：各平台原生能力仍应继续只放在对应 host 的 `Platform/*DemoPlatformServices` 或入口类中，共享层不得加入平台专用装载或 UI 行为分支。

## English Summary

- Avalonia now covers the project-standard host API surface, including CodeLens, diagnostics, guides, matched brackets, linked editing, providers, selection menu, inline suggestions, and perf overlay.
- Demo.Shared uses the `SweetLine` NuGet package directly. Android stages a platform native library and sets `SWEETLINE_LIB_PATH`; the shared layer remains platform-neutral.
- Verified in the current environment: Demo.Shared Release build, Demo.Android Debug arm64 build, APK install, cold start, and crash-log smoke check.
- Remaining work: platform tests, explicit provider timeout policy, accessibility, and smoke tests on non-Android hosts.
