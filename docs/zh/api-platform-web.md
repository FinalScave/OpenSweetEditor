# Web 平台 API（Emscripten）

本文档映射到当前 Web/Emscripten 实现：

- 绑定层：`platform/Emscripten/sweeteditor_bindings.cpp`
- 核心 API 封装：`platform/Emscripten/web/editor-core.js`
- 控件层：`platform/Emscripten/web/sweet-editor-widget.js`
- 入口文件：`platform/Emscripten/web/index.js`

## ⚠️ 重要状态说明

**Web 平台目前处于测试阶段，存在已知问题，不建议用于生产环境。**

- **暂无 CDN 或 NPM 包** - 需要从源码构建
- **存在已知问题** - 可能遇到 Bug 和 API 变更
- **不建议用于生产环境** - 仅适合测试和实验
- 欢迎通过 GitHub Issues 反馈问题和建议

## 架构说明

- Web 平台使用 Emscripten 将 C++ 核心编译为 WebAssembly。
- `sweeteditor_bindings.cpp` 使用 embind 将 C++ 类和函数暴露给 JavaScript。
- 使用 Canvas 进行编辑器内容渲染。
- `WebEditorCore` 封装底层 WASM API，提供 JavaScript 便捷方法。
- `SweetEditorWidget` 提供与其他平台类似的高层控件 API。
- 文本测量通过 JavaScript 回调实现（使用 canvas `measureText`）。

## 快速开始

### 环境要求

- 已安装并激活 Emscripten SDK (emsdk)
- 支持 WebAssembly 的现代浏览器
- 本地静态文件服务器（WASM 加载必需；`file://` 协议无法工作）

### 构建 Wasm

#### Windows (PowerShell)

```powershell
./platform/Emscripten/build-wasm.ps1
```

#### macOS/Linux

```bash
bash ./platform/Emscripten/build-wasm.sh
```

WASM 输出将生成至：
- `build/wasm/bin/sweeteditor.js`
- `build/wasm/bin/sweeteditor.wasm`

### 运行示例

示例应用位于 `platform/Emscripten/web/demo/`。

1. 构建 WASM 模块（见上文）
2. 在 `platform/Emscripten/web` 目录启动本地静态服务器：

```bash
# 使用 Python 3
cd platform/Emscripten/web
python -m http.server 8080

# 使用 Node.js (npx)
cd platform/Emscripten/web
npx serve .
```

3. 在浏览器中打开 `http://localhost:8080/demo/`

### 集成到现有 Web 项目

由于暂无 CDN 或 NPM 包，您需要：

1. 从源码构建 WASM 模块
2. 将以下文件复制到您的项目：
   - `sweeteditor.js`
   - `sweeteditor.wasm`
   - `editor-core.js`
   - `sweet-editor-widget.js`
   - `index.js`（可选，用于便捷导出）

3. 导入并使用：

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    #editor-container {
      width: 800px;
      height: 600px;
    }
  </style>
</head>
<body>
  <div id="editor-container"></div>
  <script type="module">
    import { createSweetEditor } from './index.js';

    const editor = await createSweetEditor(
      document.getElementById('editor-container'),
      {
        theme: {
          background: '#1e1e1e',
          text: '#d4d4d4',
          lineNumber: '#858585',
          cursor: '#ffffff',
          selection: 'rgba(90,140,255,0.30)',
          currentLine: 'rgba(255,255,255,0.06)',
        }
      }
    );

    editor.loadText('Hello, SweetEditor Web!', { kind: 'line-array' });
  </script>
</body>
</html>
```

### 注意事项

- 由于浏览器安全限制，WASM 模块无法从 `file://` URL 加载。
- 开发时请使用本地 HTTP 服务器。
- 可向 `createSweetEditor` 传递 `locale` 选项（`"en"` 或 `"zh"`）进行右键菜单本地化。

## 公开 API 层

### 高层 API：`createSweetEditor`

```javascript
async function createSweetEditor(container, options = {})
```

在指定容器元素中创建并初始化 SweetEditor 控件。

**参数：**
- `container` (HTMLElement)：包含编辑器的 DOM 元素
- `options` (Object，可选)：
  - `wasmModule`：预加载的 WASM 模块（如未提供，将自动加载）
  - `theme`：颜色主题对象
  - `locale`：`"en"` 或 `"zh"`，用于右键菜单本地化

**返回：** `Promise<SweetEditorWidget>`

### `SweetEditorWidget` 类

提供高层编辑器功能的主控件类。

#### 文档与外观

```javascript
loadText(text, options = {})   // options.kind: 'piece-table' | 'line-array'
getText()
getDocumentFactory()
applyTheme(theme)
getTheme()
setScale(scale)
setWrapMode(mode)          // 'NONE' | 'CHAR_BREAK' | 'WORD_BREAK'
setReadOnly(readOnly)
isReadOnly()
setAutoIndentMode(mode)    // 'NONE' | 'KEEP_INDENT'
getAutoIndentMode()
setLineSpacing(add, mult)
setContentStartPadding(padding)
getContentStartPadding()
```

#### 文本编辑 / 撤销重做

```javascript
insertText(text)
replaceText(range, newText)
deleteText(range)

undo()
redo()
canUndo()
canRedo()
```

#### 光标选区 / 导航

```javascript
selectAll()
getSelectedText()
getCursorPosition()
setCursorPosition(position)
setSelection(start, end)
getSelection()
getSelectionRange()
hasSelection()
clearSelection()
gotoPosition(line, column)     // alias: goto(line, column)
scrollToLine(line, behavior)
setScroll(scrollX, scrollY)
getScrollMetrics()
getPositionRect(line, column)
getCursorRect()
```

#### 样式 / 装饰

```javascript
registerTextStyle(styleId, color, backgroundColor, fontStyle)
setLineSpans(line, layer, spans)
setBatchLineSpans(layer, spansByLine)

setLineInlayHints(line, hints)
setBatchLineInlayHints(hintsByLine)
setLinePhantomTexts(line, phantoms)
setBatchLinePhantomTexts(phantomsByLine)

setLineDiagnostics(line, items)
setBatchLineDiagnostics(diagsByLine)
clearDiagnostics()

setLineGutterIcons(line, icons)
setBatchLineGutterIcons(iconsByLine)
setMaxGutterIcons(count)
clearGutterIcons()

setIndentGuides(guides)
setBracketGuides(guides)
setFlowGuides(guides)
setSeparatorGuides(guides)
clearGuides()

clearHighlights(layer?)
clearInlayHints()
clearPhantomTexts()
clearAllDecorations()
```

#### 折叠 / Snippet / 联动编辑

```javascript
setFoldRegions(regions)
toggleFold(line)
foldAt(line)
unfoldAt(line)
foldAll()
unfoldAll()
isLineVisible(line)

insertSnippet(snippetTemplate)
startLinkedEditing(model)
isInLinkedEditing()
linkedEditingNext()
linkedEditingPrev()
cancelLinkedEditing()
```

#### 事件

```javascript
subscribe(eventType, listener)
unsubscribe(eventType, listener)
```

**事件类型：**
- `TextChanged`
- `CursorChanged`
- `SelectionChanged`
- `ScrollChanged`
- `ScaleChanged`
- `LongPress`
- `DoubleTap`
- `ContextMenu`
- `InlayHintClick`
- `GutterIconClick`
- `FoldToggle`
- `DocumentLoaded`

#### 扩展提供者

```javascript
addDecorationProvider(provider)
removeDecorationProvider(provider)
requestDecorationRefresh()
addSweetLineDecorationProvider(options)

addCompletionProvider(provider)
removeCompletionProvider(provider)
triggerCompletion()
showCompletionItems(items)
dismissCompletion()

addNewLineActionProvider(provider)
removeNewLineActionProvider(provider)
```

### 核心 API：`WebEditorCore`

WASM `EditorCore` 类的底层封装。为编辑、选区、光标、滚动、折叠、snippet、联动编辑和装饰操作提供类型化转发。

### 文档抽象

```javascript
// 工厂方法
const factory = editor.getDocumentFactory();
factory.fromText(text, { kind: 'piece-table' }) // default
factory.fromText(text, { kind: 'line-array' })
factory.fromPieceTable(text)
factory.fromLineArray(text)

// 文档实例方法
document.getText()
document.getLineCount()
document.getLineText(line)
document.getPositionFromCharIndex(index)
document.getCharIndexFromPosition(position)
document.dispose()
```

优先使用 `editor.loadText(...)` 进行高层加载。
仅在低层流程中使用 `editor.getCore().loadDocument(document)`。

## 关键类型

### 枚举

| 枚举 | 值 |
|------|------|
| `WrapMode` | `NONE`, `CHAR_BREAK`, `WORD_BREAK` |
| `FoldArrowMode` | `AUTO`, `ALWAYS`, `HIDDEN` |
| `AutoIndentMode` | `NONE`, `KEEP_INDENT` |
| `SpanLayer` | `SYNTAX`, `SEMANTIC` |
| `ScrollBehavior` | `GOTO_TOP`, `GOTO_CENTER`, `GOTO_BOTTOM` |
| `InlayType` | `TEXT`, `ICON`, `COLOR` |
| `DiagnosticSeverity` | `DIAG_ERROR`, `DIAG_WARNING`, `DIAG_INFO`, `DIAG_HINT` |
| `EventType` | 触摸/鼠标事件类型 |
| `GestureType` | `TAP`, `DOUBLE_TAP`, `LONG_PRESS`, `SCALE`, `SCROLL` 等 |
| `KeyCode` | `BACKSPACE`, `TAB`, `ENTER`, `ESCAPE` 等 |
| `Modifier` | `NONE`, `SHIFT`, `CTRL`, `ALT`, `META` |

### 数据类型

| 类型 | 字段 |
|------|------|
| `TextPosition` | `line`, `column` |
| `TextRange` | `start`, `end`（均为 `TextPosition`） |
| `StyleSpan` | `column`, `length`, `styleId` |
| `InlayHint` | `type`, `column`, `text`, `iconId?`, `color?` |
| `PhantomText` | `column`, `text` |
| `GutterIcon` | `iconId` |
| `DiagnosticSpan` | `column`, `length`, `severity`, `color` |
| `FoldRegion` | `startLine`, `endLine`, `collapsed` |
| `IndentGuide` | `start`, `end` |
| `BracketGuide` | `parent`, `end`, `children` |
| `FlowGuide` | `start`, `end` |
| `SeparatorGuide` | `line`, `style`, `count`, `textEndColumn` |

## 冒烟测试

- API + 渲染冒烟测试脚本：`platform/Emscripten/web/tests/web-api-smoke.js`
- 浏览器入口页：`platform/Emscripten/web/tests/smoke.html`
- 请通过本地静态服务器打开（避免 `file://` 加载 WASM 受限）

## Android 专属功能（Web 暂不支持）

以下功能为 Android 专属，Web v1 未包含：

- InlineSuggestion
- PerfOverlay
- Android 专属输入法集成

这些功能可能会根据需求在后续版本中添加。

## 已知问题

此为测试版本，已知问题包括：

- 大文件性能可能不够理想
- 文本输入处理存在部分边界情况
- 移动端浏览器测试有限
- 主题自定义文档尚不完善

请在 [GitHub 仓库](https://github.com/FinalScave/OpenSweetEditor/issues) 报告问题。
