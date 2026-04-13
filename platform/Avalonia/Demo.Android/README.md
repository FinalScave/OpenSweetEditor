# Demo.Android

Android 端 Avalonia 示例工程。

## 环境要求

- .NET 8.0 SDK
- .NET Android workload
- Android SDK (API 21+)
- Java 11+

## 项目配置

| 属性 | 值 |
|------|-----|
| 目标框架 | net8.0-android |
| 最低 Android 版本 | API 21 |
| 应用 ID | com.qiplat.sweeteditor.avalonia.demo.android |

## 快速开始

### 安装 workload

```bash
dotnet workload install android
```

### 编译

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net8.0-android -p:RuntimeIdentifier=android-arm64
```

### 运行

```bash
adb install -r Demo.Android/bin/Debug/net8.0-android/android-arm64/com.qiplat.sweeteditor.avalonia.demo.android-Signed.apk
adb shell am start -W -n com.qiplat.sweeteditor.avalonia.demo.android/crc6458426131d5b6d3ae.MainActivity
```

## 原生库依赖

项目引用仓库 `prebuilt/android/` 中的 `libsweeteditor.so`。SweetLine 由 `SweetLine` NuGet 提供托管 API，Android 平台层负责提供 Android 可加载的 native library：

| 架构 | SweetEditor Core | SweetLine staging asset |
|------|------------------|-------------------------|
| arm64-v8a | `libsweeteditor.so` | `native/sweetline/arm64-v8a/libsweetline.asset` |
| x86_64 | `libsweeteditor.so` | `native/sweetline/x86_64/libsweetline.asset` |

启动时 `MainActivity` 会在 Avalonia 初始化前把 `libsweetline.asset` 拷贝到应用私有目录并设置 `SWEETLINE_LIB_PATH`。如果后续 NuGet bundles 覆盖到 Android，可删除 staging asset，只保留共享层 NuGet 调用。

## 架构说明

- 与桌面端共用 `Demo.Shared` 示例逻辑
- 通过 `DemoPlatformServices` 注入 Android IME 可视区域适配
- SweetLine 装载、IME 可视区和 Android 生命周期日志保留在平台层；其它 Demo 逻辑保留在 `Demo.Shared`
- 平台差异仅收口到平台服务层

## Termux 编译

如需在 Termux 环境下编译，请参考 [termux-dotnet-android-build.md](./termux-dotnet-android-build.md)。
