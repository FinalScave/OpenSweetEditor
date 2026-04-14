# Avalonia Demo 项目

## 项目结构

```
platform/Avalonia/
├── SweetEditor/          # 核心控件库
├── Demo.Shared/          # 共享示例逻辑与资源
├── Demo.Desktop/         # 桌面端示例 (Windows/Linux/macOS)
├── Demo.Android/         # Android 端示例
├── Demo.iOS/             # iOS 端示例
└── Demo.Mac/             # macOS 原生示例
```

## 平台支持

| 平台 | 项目 | 目标框架 | 状态 |
|------|------|----------|------|
| Windows | Demo.Desktop | net8.0 | ✅ 支持 |
| Linux | Demo.Desktop | net8.0 | ✅ 支持 |
| macOS | Demo.Desktop | net8.0 | ✅ 支持 |
| Android | Demo.Android | net8.0-android | ✅ 支持 |
| iOS | Demo.iOS | net8.0-ios | ✅ 支持 |
| macOS (原生) | Demo.Mac | net8.0-macos | ✅ 支持 |

## 快速开始

### 桌面端

```bash
cd platform/Avalonia
dotnet run --project Demo.Desktop
```

### Android

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net8.0-android -p:RuntimeIdentifier=android-arm64
```

Termux 下建议使用 [Demo.Android/termux-dotnet-android-build.md](./Demo.Android/termux-dotnet-android-build.md) 中的完整模板，显式指定 Android SDK、`aapt2`、`zipalign` 和 `UseInterpreter=true`。

### iOS

```bash
cd platform/Avalonia
dotnet build Demo.iOS -c Release -f net8.0-ios
```

## 资源引用

Demo.Shared 通过 csproj 直接引用 `platform/_res/` 目录下的共享资源：

```xml
<EmbeddedResource Include="../../_res/files/*.*">
  <LogicalName>SweetEditor.PlatformRes.files.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
<EmbeddedResource Include="../../_res/syntaxes/*.json">
  <LogicalName>SweetEditor.PlatformRes.syntaxes.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
```

## 原生库依赖

Avalonia 控件库仍通过仓库 `prebuilt/` 中的 `sweeteditor` core native library 接入 C++ Core。Demo.Shared 的语法高亮直接依赖 `SweetLine` NuGet 包，不再维护本地 SweetLine P/Invoke wrapper。

| 组件 | 解析策略 |
|------|----------|
| `sweeteditor` core | 各平台宿主按既有项目配置引用仓库 `prebuilt/*/sweeteditor` 动态库 |
| `SweetLine` Linux/macOS | 由 `SweetLine` NuGet RID assets 提供动态库 |
| `SweetLine` Android | `Demo.Android` 将 `libsweetline.asset` staging 到应用私有目录，并设置 `SWEETLINE_LIB_PATH` |
| `SweetLine` 兜底 | 若 bundles 中没有对应动态库，可设置 `SWEETLINE_LIB_PATH` 或把动态库拷贝到当前工作目录 |

## 设计目标

- 统一走 `SweetEditorControl` / `SweetEditorController`
- 覆盖 decorations / diagnostics / CodeLens / completion / inline suggestion / snippet / selection menu / new line action / perf overlay / keymap / 大文档切换
- 平台差异仅收口到平台服务层

## 对接状态

当前完成度、验证命令与剩余 SHOULD/MAY 项见 [AVALONIA_INTEGRATION_STATUS.md](./AVALONIA_INTEGRATION_STATUS.md)。

## 性能优化

Demo 包含以下性能优化组件：

- **LruCache**: LRU 缓存实现
- **FrameRateMonitor**: 实时帧率监控
- **GlyphRunCache**: 字形缓存优化
- **RenderOptimizer**: 脏区域渲染优化
- **RenderBufferPool**: 数组池化减少 GC

详见 [PERFORMANCE_OPTIMIZATION_REPORT.md](./PERFORMANCE_OPTIMIZATION_REPORT.md)
