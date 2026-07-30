# @qiplat/sweeteditor

SweetEditor 是一个面向 HarmonyOS 的代码编辑器组件，提供 ArkTS API 和 ArkUI Canvas 渲染。

源码仓库：<https://github.com/FinalScave/SweetEditor>

## 功能特性

- 基于原生 C++ 核心的高性能代码编辑能力
- 支持通过可扩展文本样式实现语法和语义高亮
- 支持 decoration、diagnostic、gutter icon、缩进线、括号线、流程线和分隔线
- 支持 inlay hint、phantom text、ghost text 和 inline suggestion
- 支持代码折叠、折叠占位、括号高亮和 linked editing
- 支持 CompletionProvider、补全面板、键盘导航和 snippet 插入
- 在手机上支持选择手柄和选择菜单，在 PC/2in1 上提供桌面鼠标交互
- 支持剪贴板操作和 IME 组合输入
- 支持自动换行模式、行间距、缩放、只读模式和 gutter 行为配置
- 同时支持等宽字体和非等宽字体
- 提供 completion、decoration、newline action 和自定义菜单项等扩展点

## 架构说明

SweetEditor for OHOS 采用分层架构：

- 共享的 C++ 核心负责文档存储、编辑命令、文本布局、命中测试、滚动、折叠、linked editing 以及渲染模型生成。
- OHOS 层通过 NAPI 调用共享核心，并负责 ArkTS 组件组合、Canvas 渲染、IME 集成、剪贴板访问、手势转发、补全面板 UI、inline suggestion UI 和选择菜单 UI。

这种设计可以在不同平台之间保持一致的编辑行为，同时又允许 OHOS 侧使用原生方式组织界面和交互。

## 安装

```bash
ohpm install @qiplat/sweeteditor@1.0.0-rc1
```

该包依赖随包分发的原生库 `libsweeteditor.so`，依赖关系已经在 `oh-package.json5` 中声明。

## 环境要求

- HarmonyOS 5.1.1（API 19）Stage 模型工程与兼容的 DevEco Studio 工具链
- `phone` 或 `2in1` 设备类型
- `arm64-v8a` 或 `x86_64` 原生运行环境
- 可用的 `ohpm` 与 Hvigor 环境

## 快速开始

```ts
import {
  Document,
  EditorTheme,
  SweetEditor,
  SweetEditorController
} from '@qiplat/sweeteditor';

@Entry
@Component
struct ExamplePage {
  private readonly controller: SweetEditorController = new SweetEditorController();

  aboutToAppear(): void {
    this.controller.whenReady(() => {
      this.controller.applyTheme(EditorTheme.dark());
      this.controller.loadDocument(Document.fromString(
        '#include <iostream>\n\n' +
        'int main() {\n' +
        '    std::cout << "Hello, SweetEditor" << std::endl;\n' +
        '    return 0;\n' +
        '}\n'
      ));
    });
  }

  build() {
    Column() {
      SweetEditor({ controller: this.controller })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
```

## 常用配置

```ts
import {
  CurrentLineRenderMode,
  FoldArrowMode,
  WhitespaceRenderMode,
  WrapMode
} from '@qiplat/sweeteditor';

this.controller.whenReady(() => {
  const settings = this.controller.getSettings();
  if (!settings) {
    return;
  }

  settings.setFontFamily('monospace');
  settings.setEditorTextSize(28);
  settings.setWrapMode(WrapMode.NONE);
  settings.setRenderWhitespace(WhitespaceRenderMode.BOUNDARY);
  settings.setRenderLineBreaks(true);
  settings.setFoldArrowMode(FoldArrowMode.AUTO);
  settings.setCurrentLineRenderMode(CurrentLineRenderMode.BORDER);
  settings.setReadOnly(false);
});
```

## 扩展能力

HAR 入口已经导出集成编辑器所需的主要公共类型：

- `SweetEditor` 和 `SweetEditorController`
- `EditorTheme`、`LanguageConfiguration` 和 `EditorSettings`
- completion 相关类型和 provider 接口
- decoration 相关类型和 provider 接口
- inline suggestion 相关类型
- 选择菜单相关类型
- 编辑器事件类型
- foundation、adornment、linked editing 和 visual 模型类型

典型扩展场景包括：

- 实现自定义 `CompletionProvider`
- 通过 `DecorationProvider` 推送装饰结果
- 监听光标、选区、文本、滚动和折叠等编辑器事件
- 从外部逻辑显示或关闭 inline suggestion
- 自定义选择菜单项

## Demo

仓库中包含可直接运行的 OHOS demo：

- 仓库地址：<https://github.com/FinalScave/SweetEditor>
- Demo 目录：<https://github.com/FinalScave/SweetEditor/tree/main/platform/OHOS/demo>

当前 demo 展示了：

- 主题切换
- 文件切换
- decoration provider
- completion provider
- inline suggestion
- 选择菜单
- 折叠与换行选项

## 生命周期与原生资源

`SweetEditor` 组件负责创建和释放编辑器会话。宿主通过 `SweetEditorController.whenReady(...)` 等待核心初始化完成，再加载文档、应用主题或注册 Provider。传入 Controller 的 `Document` 只会被借用，调用方必须保证它在编辑器使用期间存活，并在不再使用后自行调用 `destroy()`。

HAR 包通过 NAPI 和 `libsweeteditor.so` 访问共享 C++ 核心。不要绕过组件和 Controller 直接复用已经释放的原生句柄。

## 构建与运行

在 DevEco Studio 中打开 `platform/OHOS`，同步依赖后运行 `demo` 模块。命令行环境可在该目录使用 Hvigor 构建 HAR 和 demo HAP。

HAR 构建通过 `sweeteditor/build-profile.json5` 的 `externalNativeOptions` 直接使用仓库根目录 `CMakeLists.txt` 编译共享核心，不读取 `prebuilt/ohos`。

如果还需要刷新仓库级 OHOS 预构建产物，请在仓库根目录提供 OHOS CMake toolchain 后执行：

```bash
OHOS_TOOLCHAIN=/absolute/path/to/ohos.toolchain.cmake \
  ./scripts/build-release.sh --platform ohos
```

该命令仅输出 `prebuilt/ohos/arm64-v8a` 与 `prebuilt/ohos/x86_64` 下的独立原生库，不会替代 Hvigor 的 HAR 构建，也不会自动把预构建产物同步进 HAR。

## 约束与限制

- 当前原生预构建支持 `arm64-v8a` 和 `x86_64`。
- 编辑器布局、状态和渲染模型由共享 C++ 核心维护，ArkTS 层负责 Canvas、输入法和平台 UI。
- Provider 回调和 Controller 操作应在组件生命周期内执行。

## 相关链接

- [OHOS 平台 API](https://github.com/FinalScave/SweetEditor/blob/main/docs/zh/api-platform-ohos.md)
- [更新日志](CHANGELOG.md)
- [源码仓库](https://github.com/FinalScave/SweetEditor)

## 许可证

该模块基于 MIT License 发布，完整条款见 `LICENSE`。
