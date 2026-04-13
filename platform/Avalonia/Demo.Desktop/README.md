# Demo.Desktop

桌面端 Avalonia 示例工程，支持 Windows、Linux、macOS。

## 环境要求

- .NET 8.0 SDK
- Avalonia 11.3.12

## 项目配置

| 属性 | 值 |
|------|-----|
| 目标框架 | net8.0 |
| 输出类型 | WinExe |
| 程序集名称 | SweetEditor.Avalonia.Demo.Desktop |

## 快速开始

### 编译

```bash
cd platform/Avalonia
dotnet build Demo.Desktop
```

### 运行

```bash
dotnet run --project Demo.Desktop
```

### 发布

```bash
# Windows
dotnet publish Demo.Desktop -c Release -r win-x64 --self-contained

# Linux
dotnet publish Demo.Desktop -c Release -r linux-x64 --self-contained

# macOS
dotnet publish Demo.Desktop -c Release -r osx-arm64 --self-contained
```

## 原生库依赖

项目引用 `prebuilt/` 目录下的原生库：

| 平台 | 库文件 |
|------|--------|
| Windows x64 | `sweeteditor.dll` |
| Linux x86_64 | `libsweeteditor.so` |
| macOS x86_64 | `libsweeteditor.dylib` |
| macOS arm64 | `libsweeteditor.dylib` |

## 架构说明

- 与其他平台共用 `Demo.Shared` 示例逻辑
- 使用 Avalonia.Desktop 包实现跨平台桌面支持
- 原生库自动复制到输出目录
