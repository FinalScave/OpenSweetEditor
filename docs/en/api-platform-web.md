# Web Platform API (Emscripten)

This document maps to the current Web/Emscripten implementation:

- Bindings layer: `platform/Emscripten/sweeteditor_bindings.cpp`
- Core API wrapper: `platform/Emscripten/web/editor-core.js`
- Widget layer: `platform/Emscripten/web/sweet-editor-widget.js`
- Entry file: `platform/Emscripten/web/index.js`

## ⚠️ Important Status Notice

**The Web platform is currently in the testing phase with known bugs and is not production-ready.**

- **No CDN or NPM package is available yet** - you must build from source
- **Known issues exist** - expect bugs and API changes
- **Not recommended for production use** - suitable for testing and experimentation only
- Feedback and bug reports are welcome via GitHub Issues

## Architecture Notes

- The Web platform uses Emscripten to compile the C++ core to WebAssembly.
- `sweeteditor_bindings.cpp` uses embind to expose C++ classes and functions to JavaScript.
- Canvas rendering is used for drawing the editor content.
- `WebEditorCore` wraps the low-level WASM API with JavaScript convenience methods.
- `SweetEditorWidget` provides a high-level widget API similar to other platforms.
- Text measurement is performed via JavaScript callbacks (canvas `measureText`).

## Quick Start

### Environment Requirements

- Emscripten SDK (emsdk) installed and activated
- Modern browser with WebAssembly support
- A local static file server (required for WASM loading; `file://` protocol will not work)

### Build Wasm

#### Windows (PowerShell)

```powershell
./platform/Emscripten/build-wasm.ps1
```

#### macOS/Linux

```bash
bash ./platform/Emscripten/build-wasm.sh
```

The WASM output will be generated at:
- `build/wasm/bin/sweeteditor.js`
- `build/wasm/bin/sweeteditor.wasm`

The build scripts also sync those artifacts to:
- `platform/Emscripten/web/sweeteditor.js`
- `platform/Emscripten/web/sweeteditor.wasm`

This makes `platform/Emscripten/web` self-contained for demo distribution.

### Run the Demo

The demo application is located at `platform/Emscripten/web/demo/`.

1. Build the WASM module (see above)
2. Optional: copy only `platform/Emscripten/web` to another machine/location for distribution
3. Start a local static server in the `platform/Emscripten/web` directory:

```bash
# Using Python 3
cd platform/Emscripten/web
python -m http.server 8080

# Using Node.js (npx)
cd platform/Emscripten/web
npx serve .
```

4. Open `http://localhost:8080/demo/` in your browser

### Integrate into an Existing Web Project

Since there is no CDN or NPM package yet, you need to:

1. Build the WASM module from source
2. Copy files from `platform/Emscripten/web/` to your project:
   - `sweeteditor.js`
   - `sweeteditor.wasm`
   - `editor-core.js`
   - `sweet-editor-widget.js`
   - `index.js` (optional, for convenience exports)

3. Import and use:

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

### Notes

- WASM modules cannot be loaded from `file://` URLs due to browser security restrictions.
- Use a local HTTP server during development.
- The `locale` option (`"en"` or `"zh"`) can be passed to `createSweetEditor` for context menu localization.

## Public API Layer

### High-Level API: `createSweetEditor`

```javascript
async function createSweetEditor(container, options = {})
```

Creates and initializes a SweetEditor widget in the given container element.

**Parameters:**
- `container` (HTMLElement): The DOM element to contain the editor
- `options` (Object, optional):
  - `wasmModule`: Pre-loaded WASM module (if not provided, will load automatically)
  - `theme`: Theme object with colors
  - `locale`: `"en"` or `"zh"` for context menu localization

**Returns:** `Promise<SweetEditorWidget>`

### `SweetEditorWidget` Class

The main widget class providing high-level editor functionality.

#### Document and Appearance

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

#### Text Edit / Undo Redo

```javascript
insertText(text)                 // alias: insert(text)
replaceText(range, newText)      // alias: replace(range, newText)
deleteText(range)                // alias: delete(range)

undo()
redo()
canUndo()
canRedo()
```

#### Cursor Selection / Navigation

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

#### Styles / Decorations

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

#### Folding / Snippet / Linked Editing

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

#### Events

```javascript
subscribe(eventType, listener)
unsubscribe(eventType, listener)
```

**Event Types:**
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

#### Extension Providers

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

### Core API: `WebEditorCore`

Low-level wrapper around the WASM `EditorCore` class. Provides typed forwarding for editing, selection, cursor, scroll, folding, snippet, linked-editing, and decoration operations.

### Document Abstraction

```javascript
// Obtain factory from widget
const factory = editor.getDocumentFactory();

// Factory methods
factory.fromText(text, { kind: 'piece-table' }) // default
factory.fromText(text, { kind: 'line-array' })
factory.fromPieceTable(text)
factory.fromLineArray(text)

// Document instance methods
document.getText()
document.getLineCount()
document.getLineText(line)
document.getPositionFromCharIndex(index)
document.getCharIndexFromPosition(position)
document.dispose()
```

For high-level widget usage, prefer `editor.loadText(...)`.
Use `editor.getCore().loadDocument(document)` only in low-level workflows.

## Key Types

### Enums

| Enum | Values |
|------|--------|
| `WrapMode` | `NONE`, `CHAR_BREAK`, `WORD_BREAK` |
| `FoldArrowMode` | `AUTO`, `ALWAYS`, `HIDDEN` |
| `AutoIndentMode` | `NONE`, `KEEP_INDENT` |
| `SpanLayer` | `SYNTAX`, `SEMANTIC` |
| `ScrollBehavior` | `GOTO_TOP`, `GOTO_CENTER`, `GOTO_BOTTOM` |
| `InlayType` | `TEXT`, `ICON`, `COLOR` |
| `DiagnosticSeverity` | `DIAG_ERROR`, `DIAG_WARNING`, `DIAG_INFO`, `DIAG_HINT` |
| `EventType` | Touch/Mouse event types |
| `GestureType` | `TAP`, `DOUBLE_TAP`, `LONG_PRESS`, `SCALE`, `SCROLL`, etc. |
| `KeyCode` | `BACKSPACE`, `TAB`, `ENTER`, `ESCAPE`, etc. |
| `Modifier` | `NONE`, `SHIFT`, `CTRL`, `ALT`, `META` |

### Data Types

| Type | Fields |
|------|--------|
| `TextPosition` | `line`, `column` |
| `TextRange` | `start`, `end` (both `TextPosition`) |
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

## Smoke Tests

- API + rendering smoke test script: `platform/Emscripten/web/tests/web-api-smoke.js`
- Browser entry page: `platform/Emscripten/web/tests/smoke.html`
- Open via a local static server (avoid `file://` for WASM loading)

## Android-Only Features (Not Available on Web)

The following features are Android-specific and not included in Web v1:

- InlineSuggestion
- PerfOverlay
- Android-specific input method integrations

These may be added in future versions based on demand.

## Known Issues

This is a testing release. Known issues include:

- Performance may not be optimal for very large files
- Some edge cases in text input handling
- Limited mobile browser testing
- Theme customization is not fully documented

Please report issues on the [GitHub repository](https://github.com/FinalScave/OpenSweetEditor/issues).
