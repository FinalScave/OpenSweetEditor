# Demo.Mac

macOS 原生 Avalonia 示例工程。

## 环境要求

- .NET 8.0 SDK
- .NET macOS workload
- macOS 10.15+

## 项目配置

| 属性 | 值 |
|------|-----|
| 目标框架 | net8.0-macos |
| 最低 macOS 版本 | 10.15 |
| 应用 ID | com.qiplat.sweeteditor.avalonia.demo.mac |
| 运行时标识 | osx-arm64 |

## 快速开始

### 安装 workload

```bash
dotnet workload install macos
```

### 编译

```bash
cd platform/Avalonia
dotnet build Demo.Mac -c Debug -f net8.0-macos
```

### 运行

```bash
dotnet run --project Demo.Mac -f net8.0-macos
```

### 发布

```bash
# arm64 (Apple Silicon)
dotnet publish Demo.Mac -c Release -r osx-arm64 --self-contained

# x86_64 (Intel)
dotnet publish Demo.Mac -c Release -r osx-x64 --self-contained
```

## 原生库依赖

项目引用 `prebuilt/osx/` 目录下的原生库：

| 架构 | 库文件 |
|------|--------|
| arm64 | `libsweeteditor.dylib`, `libsweetline.dylib` |
| x86_64 | `libsweeteditor.dylib`, `libsweetline.dylib` |

## 架构说明

- 与其他平台共用 `Demo.Shared` 示例逻辑
- 使用 Avalonia.Desktop 包实现 macOS 支持
- 原生库自动复制到输出目录

## 注意事项

- 项目配置为 SelfContained 模式
- 支持 Apple Silicon (arm64) 和 Intel (x86_64) 双架构
