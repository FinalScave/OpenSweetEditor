# Demo.iOS

iOS 端 Avalonia 示例工程。

## 环境要求

- .NET 8.0 SDK
- .NET iOS workload
- Xcode 15+ (macOS)
- Apple Developer Account (真机调试)

## 项目配置

| 属性 | 值 |
|------|-----|
| 目标框架 | net8.0-ios |
| 最低 iOS 版本 | 13.0 |
| 应用 ID | com.qiplat.sweeteditor.avalonia.demo.ios |
| 运行时标识 | ios-arm64 |

## 快速开始

### 安装 workload

```bash
dotnet workload install ios
```

### 编译

```bash
cd platform/Avalonia
dotnet build Demo.iOS -c Debug -f net8.0-ios
```

### 模拟器运行

```bash
dotnet run --project Demo.iOS -f net8.0-ios -p:RuntimeIdentifier=iossimulator-arm64
```

### 真机部署

```bash
dotnet build Demo.iOS -c Release -f net8.0-ios -p:RuntimeIdentifier=ios-arm64
```

## 原生库依赖

项目引用 `prebuilt/ios/` 目录下的原生库：

| 架构 | 库文件 |
|------|--------|
| arm64 (真机) | `libsweeteditor.dylib`, `libsweetline.dylib` |
| simulator-arm64 | `libsweeteditor.dylib`, `libsweetline.dylib` |

## 架构说明

- 与其他平台共用 `Demo.Shared` 示例逻辑
- 使用 Avalonia.iOS 包实现 iOS 支持
- 通过 NativeReference 引入原生库

## 注意事项

- 真机部署需要有效的开发者证书
- 模拟器使用 `iossimulator-arm64` 运行时标识
- Debug 配置禁用链接器 (MtouchLink=None)
