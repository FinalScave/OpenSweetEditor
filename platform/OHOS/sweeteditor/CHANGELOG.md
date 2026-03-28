# 更新日志

该文件记录 `@qiplat/sweeteditor` 的重要变更。

## [1.0.0] - 2026-03-28

`@qiplat/sweeteditor` 的首个 OHPM 发布版本。

### 新增

- 基于共享 SweetEditor C++ 核心的 HarmonyOS `SweetEditor` ArkTS 组件
- 通过 `SweetEditorController` 提供的外部文档与编辑器控制模型
- 文档加载、编辑、选区、剪贴板、滚动和 IME 支持
- 主题配置、语言配置和运行时编辑器设置能力
- spans、diagnostics、inlay hints、phantom text、gutter icons、guides 和 folding 的 decoration 管线
- CompletionProvider、补全面板、键盘导航和 snippet 插入能力
- 带 ghost text 和操作条的 inline suggestion 支持
- 选择手柄和选择菜单支持
- 覆盖主题、文件、decoration、completion 和 inline suggestion 的 OHOS demo

### 架构

- 将 OHOS 公共 API 按 foundation、adornments、visual、linked editing、completion、selection 和 event 模块拆分整理
- 使 OHOS 编辑器的主要行为和弹层交互尽量与 Android 实现保持一致
- 将 OHOS 文本测量收敛到 renderer 路径，并统一字体度量在布局与渲染中的使用方式

### 打包

- 以 `@qiplat/sweeteditor` 名称发布
- 随包分发原生依赖 `libsweeteditor.so`
- 使用 LGPL v2.1 许可证
