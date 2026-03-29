# SweetEditor Web Platform (Emscripten)

> **Status: Testing Phase** - This platform is currently in testing with known bugs. Not recommended for production use.

Cross-platform code editor for the web, powered by WebAssembly.

## ⚠️ Important Notices

- **No CDN or NPM package available yet** - You must build from source
- **Known bugs exist** - Expect issues and API changes
- **Not production-ready** - Suitable for testing and experimentation only
- Feedback welcome via [GitHub Issues](https://github.com/FinalScave/OpenSweetEditor/issues)

## Features

- **Full C++ Core**: Access to the complete SweetEditor C++17 core via WebAssembly
- **Canvas Rendering**: High-performance rendering using HTML5 Canvas
- **Rich Editing**: Syntax highlighting, code folding, snippets, linked editing
- **Decorations**: Inlay hints, phantom text, diagnostics, gutter icons
- **IME Support**: Full input method composition support
- **Touch & Mouse**: Complete gesture handling for desktop and mobile

## Quick Start

### Prerequisites

- [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) installed and activated
- Modern browser with WebAssembly support
- Local HTTP server (required for WASM loading)

### Build

#### Windows (PowerShell)

```powershell
# From repository root
./platform/Emscripten/build-wasm.ps1
```

#### macOS / Linux

```bash
# From repository root
bash ./platform/Emscripten/build-wasm.sh
```

Output files:
- `build/wasm/bin/sweeteditor.js` - JavaScript glue code
- `build/wasm/bin/sweeteditor.wasm` - WebAssembly binary

### Run Demo

1. Build the WASM module (see above)
2. Start a local server:

```bash
cd platform/Emscripten/web
python -m http.server 8080
# or: npx serve .
```

3. Open http://localhost:8080/demo/ in your browser

## Integration

Since there's no NPM package yet, copy these files to your project:

```
sweeteditor.js      # JS glue code (from build output)
sweeteditor.wasm    # WASM binary (from build output)
editor-core.js      # Core API wrapper
sweet-editor-widget.js  # High-level widget
index.js            # Entry point (optional)
```

### Basic Usage

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    #editor { width: 800px; height: 600px; }
  </style>
</head>
<body>
  <div id="editor"></div>
  <script type="module">
    import { createSweetEditor, DocumentFactory } from './index.js';

    const editor = await createSweetEditor(
      document.getElementById('editor'),
      {
        theme: {
          background: '#1e1e1e',
          text: '#d4d4d4',
          lineNumber: '#858585',
          cursor: '#ffffff',
          selection: 'rgba(90,140,255,0.30)',
        },
        locale: 'en', // or 'zh-CN'
        // Performance overlay is disabled by default for better runtime performance.
        performanceOverlay: {
          enabled: true,
          visible: true,
          updateIntervalMs: 250,
          stutterThresholdMs: 50,
          chart: {
            enabled: true,
            // Optional CDN override:
            // cdnUrl: 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js',
          },
        },
      }
    );

    const doc = DocumentFactory.createLineArrayDocument('Hello, World!');
    editor.loadDocument(doc);
  </script>
</body>
</html>
```

### Performance Overlay Behavior

- `performanceOverlay` is **disabled by default** in the widget to avoid extra runtime overhead.
- The demo app enables it explicitly.
- Runtime controls:
  - `editor.setPerformanceOverlayEnabled(enabled)`
  - `editor.isPerformanceOverlayEnabled()`
  - `editor.setPerformanceOverlayVisible(visible)`
  - `editor.isPerformanceOverlayVisible()`
  - `editor.getPerformanceStats()`

## API Overview

### High-Level API

```javascript
// Create editor
const editor = await createSweetEditor(container, options);

// Document
editor.loadDocument(doc);
editor.getDocument();

// Editing
editor.insertText(text);
editor.replaceText(range, newText);
editor.deleteText(range);
editor.undo();
editor.redo();

// Navigation
editor.gotoPosition(line, column);
editor.scrollToLine(line);
editor.setScroll(x, y);

// Selection
editor.setSelection(start, end);
editor.getSelection();
editor.getSelectedText();
editor.selectAll();

// Folding
editor.setFoldRegions(regions);
editor.toggleFold(line);
editor.foldAll();
editor.unfoldAll();

// Decorations
editor.setLineSpans(line, layer, spans);
editor.setLineInlayHints(line, hints);
editor.setLineDiagnostics(line, items);
editor.setLineGutterIcons(line, icons);

// Events
editor.subscribe('TextChanged', listener);
editor.unsubscribe('TextChanged', listener);
```

### Core API (Low-Level)

Direct access to WASM-bound C++ classes:

- `EditorCore` - Core editor engine
- `LineArrayDocument` - Simple document implementation
- `PieceTableDocument` - Efficient large file editing

```javascript
import { WebEditorCore, DocumentFactory } from './editor-core.js';

const core = new WebEditorCore(callbacks, options);
const doc = DocumentFactory.createPieceTableDocument(text);
core.loadDocument(doc);
```

## Project Structure

```
platform/Emscripten/
├── README.md                    # This file
├── build-wasm.ps1              # Windows build script
├── build-wasm.sh               # Unix build script
├── sweeteditor_bindings.cpp    # Embind C++ bindings
└── web/
    ├── index.js                # Entry point
    ├── editor-core.js          # Core API wrapper
    ├── sweet-editor-widget.js  # High-level widget
    ├── demo/                   # Demo application
    │   ├── index.html
    │   ├── app.js
    │   └── syntaxes/           # Syntax definitions
    └── tests/                  # Test files
        ├── smoke.html
        └── web-api-smoke.js
```

## Event Types

| Event | Description |
|-------|-------------|
| `TextChanged` | Document content changed |
| `CursorChanged` | Cursor position changed |
| `SelectionChanged` | Selection changed |
| `ScrollChanged` | Viewport scrolled |
| `ScaleChanged` | Zoom scale changed |
| `ContextMenu` | Right-click menu requested |
| `InlayHintClick` | Inlay hint clicked |
| `GutterIconClick` | Gutter icon clicked |
| `FoldToggle` | Fold region toggled |

## Known Issues

- Performance may degrade with very large files (>100k lines)
- Some edge cases in IME composition handling
- Limited mobile browser testing
- Theme customization API not fully documented

## Platform-Specific Notes

### Browser Compatibility

Tested on:
- Chrome 90+
- Firefox 90+
- Safari 15+
- Edge 90+

### Mobile Support

Basic touch support is implemented, but mobile browser testing is limited. Bug reports for mobile issues are especially welcome.

## Related Documentation

- [Web Platform API Reference](../../docs/en/api-platform-web.md)
- [Core C++ API](../../docs/en/api-editor-core.md)
- [Architecture Overview](../../docs/en/architecture.md)

## License

LGPL-2.1-or-later with Static Linking Exception. See [LICENSE](../../LICENSE) for details.
