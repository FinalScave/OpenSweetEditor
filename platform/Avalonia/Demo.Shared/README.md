# Demo.Shared

跨平台共享示例逻辑与资源库，为所有 Avalonia Demo 项目提供核心功能实现。

## 项目配置

| 属性 | 值 |
|------|-----|
| 目标框架 | net8.0 |
| 程序集名称 | SweetEditor.Avalonia.Demo.Shared |
| Avalonia 版本 | 11.3.12 |

## 目录结构

```
Demo.Shared/
├── MainView.cs                 # 主视图，核心 UI 入口
├── ViewModels/
│   ├── MainViewModel.cs        # MVVM 视图模型
│   └── DemoSettings.cs         # 用户设置持久化
├── Host/
│   ├── DemoPlatformServices.cs # 平台服务抽象接口
│   └── DeferredMainViewHost.cs # 延迟加载宿主
├── Decoration/
│   ├── DemoDecorationProvider.cs   # 语法高亮装饰提供者
│   └── DemoSweetLineRuntime.cs     # SweetLine 原生引擎封装
├── Editor/
│   ├── DemoCompletionProvider.cs       # 代码补全提供者
│   ├── DemoSelectionMenuItemProvider.cs # 选择菜单项提供者
│   ├── DemoNewLineActionProvider.cs    # 换行动作提供者
│   ├── DemoInlineSuggestionListener.cs # 内联建议监听器
│   ├── DemoIconProvider.cs             # 图标提供者
│   └── DemoMetadata.cs                 # 元数据定义
├── UI/
│   ├── LoadingIndicator.cs     # 加载指示器
│   ├── NotificationPanel.cs    # 通知面板
│   ├── KeyboardShortcutsDialog.cs # 快捷键对话框
│   ├── WelcomeOverlayView.cs   # 欢迎覆盖层
│   ├── Toolbar/
│   │   └── EditorToolbarController.cs # 工具栏控制器
│   └── Samples/
│       ├── SampleDocumentLoader.cs    # 示例文档加载器
│       ├── EmbeddedSampleRepository.cs # 嵌入式示例仓库
│       └── DemoSampleFile.cs          # 示例文件定义
├── Performance/
│   ├── ObjectPool.cs           # 对象池
│   └── PerformanceBenchmark.cs # 性能基准测试
└── Assets/
    └── Icons/                  # 图标资源
```

## 核心组件

### 1. MainView - 主视图

主视图是 Demo 应用的核心 UI 入口，负责：

- **编辑器初始化**: 创建 `SweetEditorControl` 和 `SweetEditorController`
- **事件处理**: 文档加载、文本变更、光标移动、选择变更等
- **UI 组件管理**: 工具栏、状态栏、补全弹窗、选择操作栏
- **主题切换**: 深色/浅色主题动态切换
- **缩放控制**: 预设缩放比例 (72% - 120%)

```csharp
public sealed class MainView : UserControl
{
    private readonly SweetEditorController controller = new();
    private SweetEditorControl? editor;
    // ...
}
```

### 2. DemoDecorationProvider - 语法高亮装饰

实现 `IDecorationProvider` 接口，提供多种装饰类型：

| 装饰类型 | 说明 |
|----------|------|
| SyntaxHighlight | 语法高亮 |
| InlayHint | 内联提示（类型推断、颜色预览） |
| Diagnostic | 诊断信息（TODO、FIXME、行长度警告） |
| FoldRegion | 折叠区域 |
| IndentGuide | 缩进参考线 |
| BracketGuide | 括号匹配线 |
| FlowGuide | 控制流参考线 |
| GutterIcon | 行号图标 |
| PhantomText | 幽灵文本 |

**大文档优化**:
- 超过 12,000 行或 900KB 自动启用大文档模式
- 异步预加载语法高亮缓存
- 增量更新支持

### 3. DemoCompletionProvider - 代码补全

实现 `ICompletionProvider` 接口，提供：

- **触发字符**: `.`, `:`, `#`
- **补全项类型**: 关键字、函数、类、代码片段
- **异步补全**: 120ms 延迟后返回结果

```csharp
public bool IsTriggerCharacter(string ch) =>
    TriggerChars.Contains(ch);
```

### 4. SweetLine - 原生语法高亮引擎

Demo.Shared 直接通过 NuGet 包 `SweetLine` 依赖高性能原生语法高亮引擎，不再维护本地 P/Invoke 封装源码：

**核心类**:
- `HighlightEngine`: 高亮引擎，编译语法规则
- `Document`: 托管文档，支持增量更新
- `DocumentAnalyzer`: 文档分析器
- `TextAnalyzer`: 纯文本分析器

**功能特性**:
- JSON 语法定义编译
- 增量分析（仅重分析变更部分）
- 可见区域切片提取
- 缩进参考线分析

```csharp
using var engine = new HighlightEngine();
engine.CompileSyntaxFromJson(syntaxJson);
var analyzer = engine.CreateAnalyzerByName("java");
var highlight = analyzer.AnalyzeText(sourceCode);
```

### 5. DemoPlatformServices - 平台服务抽象

平台差异抽象接口，各平台实现：

```csharp
public interface IDemoPlatformServices : IDisposable
{
    bool IsAndroid { get; }
    bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost,
        out double imeTopInHostDip);
}
```

**Android 特殊处理**:
- IME 可视区域适配
- 大文档手势锚点优化
- 延迟 UI 刷新策略

## 资源引用

### 嵌入式资源

```xml
<EmbeddedResource Include="../../_res/files/*.*">
  <LogicalName>SweetEditor.PlatformRes.files.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
<EmbeddedResource Include="../../_res/syntaxes/*.json">
  <LogicalName>SweetEditor.PlatformRes.syntaxes.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
```

### SweetLine 原生库

Demo.Shared 直接引用 `SweetLine` NuGet 包，不再手动复制桌面端原生库，也不再维护本地 P/Invoke wrapper。

- Linux/macOS 动态库由 NuGet 包随 RID assets 提供。
- 如果运行时未在包内 bundles 中找到对应动态库，可通过环境变量 `SWEETLINE_LIB_PATH` 指向动态库路径，或把动态库拷贝到当前工作目录。
- Android Demo 由平台层把 `libsweetline.asset` staging 到应用私有目录，并设置 `SWEETLINE_LIB_PATH`，共享层不包含 Android 平台专用装载逻辑。

## MVVM 架构

`MainViewModel` 实现 `INotifyPropertyChanged`，提供：

- **状态管理**: 加载状态、文档状态、撤销/重做能力
- **设置持久化**: 主题、缩放、换行模式自动保存
- **数据绑定**: 示例列表、光标位置、缩放比例

```csharp
public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    public bool DarkTheme { get; set; }
    public WrapMode WrapMode { get; set; }
    public float CurrentScale { get; set; }
    // ...
}
```

## 性能优化

### 对象池 (ObjectPool)

减少 GC 压力的对象复用池：

```csharp
public class ObjectPool<T> where T : class, new()
{
    public T Rent();
    public void Return(T obj);
}
```

### 延迟刷新策略

UI 更新通过 `DeferredChromeWork` 标志位合并：

```csharp
[Flags]
private enum DeferredChromeWork
{
    None = 0,
    Summary = 1 << 0,
    CompletionPopup = 1 << 1,
    SelectionActionBar = 1 << 2,
    CursorVisibility = 1 << 3,
    SamplePickerPopup = 1 << 4,
}
```

## 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| F1 | 触发代码补全 |
| F2 | 显示内联建议 |
| F3 | 插入代码片段 |
| Ctrl+K, Ctrl+D | 触发补全（自定义映射） |
| Escape | 关闭弹窗 |

## 扩展点

### 自定义装饰提供者

实现 `IDecorationProvider` 接口：

```csharp
public interface IDecorationProvider
{
    DecorationType Capabilities { get; }
    void PrimeDocument(string fileName, string content);
    void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver);
}
```

### 自定义补全提供者

实现 `ICompletionProvider` 接口：

```csharp
public interface ICompletionProvider
{
    bool IsTriggerCharacter(string ch);
    void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver);
}
```
