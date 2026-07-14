# 更新日志

该文件记录 `@qiplat/sweeteditor` 的重要变更。

## 1.0.0-rc1

### 编辑器与公共 API

- 提供 ArkUI `SweetEditor` 组件、`SweetEditorController` 外部控制入口，以及低层 `EditorCore` 和字符串或文件文档 API。
- 支持文本插入、指定位置插入、范围替换与删除、批量文本编辑、行移动、行复制、行删除、上下插行和撤销重做。
- 支持光标与选区控制、单词查询、全选、剪贴板操作、位置跳转、坐标查询、滚动控制、可见行范围和滚动度量。
- 支持区分大小写、全词、正则表达式、循环查找、匹配数量限制、上一项、下一项、替换当前项、全部替换、清除和搜索状态查询。
- 支持代码折叠与折叠占位、行可见性查询、snippet、tab stop 和 linked editing。
- 提供深色与浅色主题、自定义文本样式与颜色、语言配置、括号对、自动闭合对、Tab 宽度、空格缩进、Metadata、图标 Provider，以及 VS Code、JetBrains、Sublime 预设和自定义快捷键。
- 提供字体、字号、缩放、换行、空白字符与换行符渲染、行间距、内容边距、分隔线、gutter 显示与固定、折叠箭头、当前行渲染、自动缩进、退格反缩进、只读模式、gutter icon 数量和 decoration 刷新策略等运行时配置。

### 渲染与装饰能力

- 使用 ArkUI Canvas 完成视口渲染，支持等宽与非等宽字体、自动换行、光标、选区、折叠、结构线、gutter、scrollbar 和可配置的范围效果。
- 支持文本样式注册，以及语法、语义和 overlay span，并支持 inlay hint、phantom text、diagnostic、文档高亮、gutter icon、CodeLens、链接和括号匹配。
- 支持缩进线、括号线、流程线和分隔线，以及单行或批量 decoration 更新、分层清理和全部清理。

### 语言能力与扩展点

- 提供异步 `DecorationProvider`，支持取消、可见范围上下文、增量刷新，以及合并、全量替换和范围替换 decoration。
- 提供可取消的异步 `CompletionProvider` 请求和同步 `NewLineActionProvider` 调用链。
- 支持自动补全触发字符、重新触发、snippet、主文本编辑、附加文本编辑、键盘导航、自定义补全项视图和外部补全项展示。
- 提供 inline suggestion ghost text 与操作条、自定义选择菜单项、编辑器图标、快捷键命令、语言 Metadata，以及接受和关闭 inline suggestion 的回调。
- 提供文本、光标、选区、滚动、缩放、文档加载、折叠、gutter icon、inlay hint、CodeLens、链接、长按、双击、右键菜单手势和自定义选择菜单项等类型化事件。

### OHOS 平台集成与打包

- 集成 HarmonyOS 输入法组合输入、preview text、上下文同步、光标与选区更新、软键盘生命周期和硬件键盘事件。
- 集成系统 pasteboard、触摸与鼠标事件、拖动选区、选择手柄、滚动、缩放、补全面板、移动端选择菜单和可选的调试性能浮层。
- 使用 ArkTS 与 NAPI 直连共享 C++ 编辑器核心，并通过统一的 `Index.ets` 导出 foundation、adornment、visual、search、IME、linked editing、completion、decoration、selection 和 event 等公共类型。
- 以 `@qiplat/sweeteditor` HAR 包组织，声明 `libsweeteditor.so` 原生依赖，支持 HarmonyOS API 19、Stage 模型、phone 设备以及 `arm64-v8a` 和 `x86_64` 原生架构。
- 由 `SweetEditor` 组件管理原生编辑器会话、渲染资源和释放生命周期。
