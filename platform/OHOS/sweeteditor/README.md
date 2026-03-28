# @qiplat/sweeteditor

SweetEditor 是一个面向 HarmonyOS 的代码编辑器组件，构建在共享的 SweetEditor C++ 核心之上。它将 Android 版本已经验证过的编辑模型和渲染管线带到 OHOS，同时让 OHOS 层专注于 ArkTS UI、Canvas 渲染、输入法、剪贴板、手势转发、补全面板、选择菜单和其他平台集成能力。

源码仓库：<https://github.com/FinalScave/OpenSweetEditor>

## 功能特性

- 基于原生 C++ 核心的高性能代码编辑能力
- 支持通过可扩展文本样式实现语法和语义高亮
- 支持 decoration、diagnostic、gutter icon、缩进线、括号线、流程线和分隔线
- 支持 inlay hint、phantom text、ghost text 和 inline suggestion
- 支持代码折叠、折叠占位、括号高亮和 linked editing
- 支持 CompletionProvider、补全面板、键盘导航和 snippet 插入
- 支持选择手柄、选择菜单、剪贴板操作和 IME 组合输入
- 支持自动换行模式、行间距、缩放、只读模式和 gutter 行为配置
- 同时支持等宽字体和非等宽字体
- 提供 completion、decoration、newline action 和自定义菜单项等扩展点

## 架构说明

SweetEditor for OHOS 采用分层架构：

- 共享的 C++ 核心负责文档存储、编辑命令、文本布局、命中测试、滚动、折叠、linked editing 以及渲染模型生成。
- OHOS 层负责 ArkTS 组件组合、Canvas 渲染、IME 集成、剪贴板访问、手势转发、补全面板 UI、inline suggestion UI 和选择菜单 UI。

这种设计可以在不同平台之间保持一致的编辑行为，同时又允许 OHOS 侧使用原生方式组织界面和交互。

## 安装

使用 ohpm 安装：

```bash
ohpm install @qiplat/sweeteditor
```

该包依赖随包分发的原生库 `libsweeteditor.so`，依赖关系已经在 `oh-package.json5` 中声明。

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

- 仓库地址：<https://github.com/FinalScave/OpenSweetEditor>
- Demo 目录：<https://github.com/FinalScave/OpenSweetEditor/tree/main/platform/OHOS/demo>

当前 demo 展示了：

- 主题切换
- 文件切换
- decoration provider
- completion provider
- inline suggestion
- 选择菜单
- 折叠与换行选项

## 许可证

该模块基于 GNU Lesser General Public License v2.1 发布，完整条款见 `LICENSE`。
上游 SweetEditor 仓库还额外提供了一个 `EXCEPTION` 文件，特意注明了 SweetEditor 允许静态链接。
