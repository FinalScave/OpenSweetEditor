# Platform Implementation Standard

> This document defines the conventions and constraints that every SweetEditor platform implementation must follow.
> The goal is to keep cross-platform behavior consistent while allowing platform-specific rendering and input handling.
>
> This document describes the current repository code state (2026-03). If the document and source code are different, use the source code.
>
> Constraint levels:
> - **MUST** 鈥?all platforms must comply; violation is a bug.
> - **SHOULD** 鈥?recommended; deviation requires documented justification.
> - **MAY** 鈥?optional; platform decides based on its own needs.

---

## 1. Module Structure

Every platform implementation MUST include the following two logical layers and ensure all types within each category are implemented. File organization (directory structure, file granularity) MAY vary by language convention (e.g. Java uses package directories, C# uses one file per namespace, Swift uses Sources layering), but the logical categories MUST be identifiable and the types MUST be fully covered.

### 1.1 Core Layer (Pure Data / Models / Protocol)

The Core layer does not involve UI rendering. It contains only bridging, data models, and protocol encoding/decoding.

| Category | Required Types | Description |
|---|---|---|
| **Core Bridge** | `EditorCore`, `Document`, `ProtocolEncoder`, `ProtocolDecoder`, `TextMeasurer`, `EditorOptions` | Native bridge + public core API wrapper |
| **Foundation** | `TextPosition`, `TextRange`, `TextChange`, `WrapMode`, `FoldArrowMode`, `AutoIndentMode`, `CurrentLineRenderMode`, `ScrollBehavior` | Fundamental value types and enums |
| **Adornment** | `StyleSpan`, `SpanLayer`, `InlayHint`, `InlayType`, `PhantomText`, `FoldRegion`, `GutterIcon`, `Diagnostic`, `IndentGuide`, `BracketGuide`, `FlowGuide`, `SeparatorGuide`, `SeparatorStyle`, `TextStyle` | Decoration data types |
| **Visual** | `EditorRenderModel`, `VisualLine`, `VisualRun`, `VisualRunType`, `Cursor`, `CursorRect`, `SelectionRect`, `SelectionHandle`, `ScrollMetrics`, `ScrollbarModel`, `ScrollbarRect`, `GuideSegment`, `GuideType`, `GuideDirection`, `GuideStyle`, `DiagnosticDecoration`, `CompositionDecoration`, `FoldMarkerRenderItem`, `FoldState`, `GutterIconRenderItem`, `LinkedEditingRect`, `BracketHighlightRect` | Render model types (geometry semantics follow Section 2.4) |
| **Snippet** | `LinkedEditingModel`, `TabStopGroup` | Linked editing / tab stop groups |
| **Keymap** | `KeyMap`, `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, `EditorCommand` | Shortcut mapping data types and command identifiers |

### 1.2 Widget Layer (UI Controls / Rendering / Interaction)

The Widget layer handles platform-native rendering, user interaction, and extension systems.

| Category | Required Types | Description |
|---|---|---|
| **Widget** | `SweetEditor`, `SweetEditorController` *(declarative frameworks MUST; imperative frameworks MAY)*, `EditorTheme`, `EditorSettings`, `EditorIconProvider`, `EditorMetadata`, `LanguageConfiguration` | Widget entry, controller, theme, configuration |
| **Decoration** | `DecorationProvider`, `DecorationProviderManager`, `DecorationContext`, `DecorationResult`, `DecorationType`; if the Receiver callback pattern is used, `DecorationReceiver` is the recommended name | Decoration provider system |
| **Completion** | `CompletionProvider`, `CompletionProviderManager`, `CompletionContext`, `CompletionItem`, `CompletionResult`; if the Receiver callback pattern is used, `CompletionReceiver` is the recommended name | Completion provider system |
| **Event** | A type-safe event mechanism, `EditorEvent`, `TextChangedEvent`, `CursorChangedEvent`, `SelectionChangedEvent`, `ScrollChangedEvent`, `ScaleChangedEvent`, `DocumentLoadedEvent`, `FoldToggleEvent`, `GutterIconClickEvent`, `InlayHintClickEvent`, `LongPressEvent`*(mobile only)*, `DoubleTapEvent`, `ContextMenuEvent`*(desktop & cross-platform UI frameworks)*; if an explicit event-bus/listener pattern is used, `EditorEventBus` and `EditorEventListener` are the recommended names | Event system |
| **NewLine** | `NewLineActionProvider`, `NewLineActionProviderManager`, `NewLineAction`, `NewLineContext` | Newline action provider system |
| **Keymap** | `EditorKeyMap` | Widget-layer keymap extension that binds command ids to host-side handlers |
| **Copilot** *(SHOULD)* | `InlineSuggestion`, `InlineSuggestionListener` or an equivalent host-visible accept/dismiss callback mechanism; MAY: `InlineSuggestionController` | Inline suggestion data + callback; listener shape is the primary path when exposed |
| **Selection** *(MAY, mobile-only)* | `SelectionMenuController`, `SelectionMenuItem`, `SelectionMenuItemProvider`, a host-visible custom-item click callback mechanism; MAY: `SelectionMenuListener` | Selection menu (MAY omit on desktop) |
| **Perf** *(SHOULD)* | `PerfOverlay`, `MeasurePerfStats`, `PerfStepRecorder` | Performance overlay |

> `TextChangeAction` is a SHOULD-level auxiliary event enum. Platforms MAY expose it to classify a text-change cycle at a coarse level (for example: `INSERT`, `DELETE`, `UNDO`, `REDO`, `KEY`, `COMPOSITION`), but it MUST NOT replace `changes: List<TextChange>` as the primary incremental payload.

### 1.3 Recommended Internal Implementation Patterns (SHOULD)

The following types are **internal implementation details**, not part of the public API contract. Platforms SHOULD adopt these patterns to organize internal logic, but MAY choose equivalent alternatives based on platform characteristics (e.g. implementing directly within the widget class, using platform-native Popup, etc.).

| Pattern | Recommended Types | Use Case | Benefits |
|---|---|---|---|
| **Renderer** | `EditorRenderer` | Separate rendering logic from the widget entry class | Single responsibility; rendering logic can be iterated and tested independently |
| **Controller** | `CompletionPopupController`, `InlineSuggestionController`, `SelectionMenuController` | Manage popup / overlay lifecycle and interaction logic | Decouples UI popups from data logic; platforms may implement directly with Popup instead |

> If adopting the above patterns, naming SHOULD follow the canonical names in Section 2.1.
> Not adopting these patterns is not a violation, but equivalent functionality must be implemented elsewhere.

---

## 2. Naming Conventions

### 2.1 Class / Type Names (MUST)

All platforms MUST use the following canonical names for public types. Language-specific prefixes or suffixes are allowed only where mandated by the language convention (e.g. C# interface `I` prefix).

The widget entry class MUST use `SweetEditor` as prefix and MAY append the target platform's conventional UI component suffix:

| Suffix | Full Name | When to Use | Example Platforms |
|---|---|---|---|
| (none) | `SweetEditor` | Platform does not mandate a UI component suffix | Android View, Swing, OHOS ArkUI |
| `Control` | `SweetEditorControl` | Platform convention uses `Control` | WinForms, WPF |
| `Widget` | `SweetEditorWidget` | Platform convention uses `Widget` | Flutter, Qt |
| `View` | `SweetEditorView` | Platform convention uses `View` | SwiftUI, UIKit, AppKit, React Native |
| `Component` | `SweetEditorComponent` | Platform convention uses `Component` | Web Components, React, Vue |
| `Element` | `SweetEditorElement` | Platform convention uses `Element` | Lit, Angular |

> Names without the `SweetEditor` prefix (e.g. `EditorControl`, `EditorView`, `EditorWidget`) are NOT allowed.
> If the target platform's conventional suffix is not listed above, a PR SHOULD be submitted to extend this table before implementation.

Other public types:

| Canonical Name | Allowed Variants | Notes |
|---|---|---|
| `EditorCore` | OC: `SEEditorCore` | Core bridge wrapper |
| `TextMeasurer` | OC: `SETextMeasurer` | Can be struct in C# |
| `EditorTheme` | OC: `SEEditorTheme` | Theme definition |
| `EditorSettings` | OC: `SEEditorSettings` | Configuration |
| `DecorationProvider` | C#/TS/Kotlin: `IDecorationProvider`; OC: `SEDecorationProvider` | Provider interface |
| `CompletionProvider` | C#/TS/Kotlin: `ICompletionProvider`; OC: `SECompletionProvider` | Provider interface |
| `DecorationReceiver` | C#/TS/Kotlin: `IDecorationReceiver`; OC: `SEDecorationReceiver` | Callback interface; only applicable when the platform exposes an explicit Receiver type |
| `CompletionReceiver` | C#/TS/Kotlin: `ICompletionReceiver`; OC: `SECompletionReceiver` | Callback interface; only applicable when the platform exposes an explicit Receiver type |
| `NewLineActionProvider` | C#/TS/Kotlin: `INewLineActionProvider`; OC: `SENewLineActionProvider` | Provider interface |
| `KeyMap` | OC: `SEKeyMap` | Core keymap data container |
| `EditorKeyMap` | OC: `SEEditorKeyMap` | Widget-layer keymap extension |
| `EditorCommand` | OC: `SEEditorCommand` | Built-in command ids / command-handler concept type |
| `KeyBinding` | OC: `SEKeyBinding` | One- or two-chord binding entry |
| `KeyChord` | OC: `SEKeyChord` | Single key-chord value type |
| `KeyCode` | OC: `SEKeyCode` | Keyboard key code constants / enum |
| `KeyModifier` | OC: `SEKeyModifier` | Keyboard modifier flags / enum |
| `EditorMetadata` | C#/TS/Kotlin: `IEditorMetadata`; OC: `SEEditorMetadata` | Metadata concept type; only applicable when the platform exposes an explicit public type |
| `EditorEventListener` | C#/TS/Kotlin: `IEditorEventListener`; OC: `SEEditorEventListener` | Listener interface; applies only when the platform exposes an explicit listener-interface pattern |
| `InlineSuggestionListener` | C#/TS/Kotlin: `IInlineSuggestionListener`; OC: `SEInlineSuggestionListener` | Listener interface; only applicable when the platform exposes an explicit inline-suggestion listener |
| `SelectionMenuItem` | OC: `SESelectionMenuItem` | Selection menu item data type |
| `SelectionMenuItemProvider` | C#/TS/Kotlin: `ISelectionMenuItemProvider`; OC: `SESelectionMenuItemProvider` | Selection menu item provider; builds the full menu for the current editor state |
| `SelectionMenuListener` | C#/TS/Kotlin: `ISelectionMenuListener`; OC: `SESelectionMenuListener` | Listener interface; only applicable when the platform exposes an explicit selection-menu listener |
| `EditorIconProvider` | C#/TS/Kotlin: `IEditorIconProvider`; OC: `SEEditorIconProvider` | Icon provider interface |
| `SweetEditorController` | OC: `SESweetEditorController` | External control entry for declarative frameworks (see Section 3.0) |

> **Naming variant rules:**
> - Languages whose convention requires an `I` prefix on interfaces (e.g. C#, TypeScript, Kotlin) MAY use the `I`-prefixed variant
> - Languages whose convention requires a project prefix on class names (e.g. Objective-C) MAY use the `SE` prefix variant (abbreviation of SweetEditor)
> - All other languages SHOULD use the canonical name directly

> If the event system uses platform-native `event` / delegate / stream / signal APIs, the platform does not need to expose public `EditorEventBus` / `EditorEventListener` types; in that case only the semantics in Section 11 are required.

### 2.2 Field / Property Names (MUST)

Data model fields MUST use the same semantic names across platforms, adapted to each language's casing convention:

| Java / ArkTS (camelCase) | C# (PascalCase) | Swift (camelCase) | Dart (camelCase) |
|---|---|---|---|
| `line` | `Line` | `line` | `line` |
| `column` | `Column` | `column` | `column` |
| `startColumn` | `StartColumn` | `startColumn` | `startColumn` |
| `endColumn` | `EndColumn` | `endColumn` | `endColumn` |
| `styleId` | `StyleId` | `styleId` | `styleId` |
| `scrollX` | `ScrollX` | `scrollX` | `scrollX` |
| `backgroundColor` | `BackgroundColor` | `backgroundColor` | `backgroundColor` |

### 2.3 Method Names (MUST)

Public API methods MUST follow each language's casing convention. Canonical names use Java/ArkTS camelCase as the baseline; each language adapts per its own convention (e.g. C# PascalCase, Go capitalized exports). See Section 3 for the full method list and allowed variants.

### 2.4 Geometry Carrier Types (MUST)

For simple geometry carriers used in public APIs and event payloads, platforms MAY use either the canonical SweetEditor geometry names or platform-native equivalents when the semantics are identical.

- Point types: `PointF` or a platform-native point type (e.g. Android `android.graphics.PointF`, Apple `CGPoint`)
- Rect types: `RectF` or a platform-native rect type (e.g. Android `android.graphics.RectF`, Apple `CGRect`)

If a platform-native geometry type is used, coordinate basis, axis direction, and field semantics MUST remain identical to the canonical SweetEditor model.

---

## 3. Public API Contract (MUST)

The following lists all public methods that `EditorCore` and `SweetEditor` MUST expose. All platforms MUST implement every listed method.

> Lifecycle / memory management APIs (e.g. `create`, `destroy`, `freeBinaryData`) are not listed here; each platform implements them per its own conventions.

**General naming variant rules:**
- Canonical names use Java/ArkTS camelCase as the baseline
- PascalCase languages (e.g. C#, Go): all method names use PascalCase (e.g. `setDocument` 鈫?`SetDocument`); this rule applies to all methods and is not repeated per row
- Each language MAY adapt parameter naming and calling style per its own conventions (e.g. Swift argument labels, Go export rules, Dart named parameters)
- The "Allowed Variants" column below only lists variants with **substantive differences** from the canonical name (e.g. getter as property, different method name semantics); `鈥擿 means no substantive difference

### 3.0 API Carrier Rules (MUST)

Editor components inherently contain many imperative operations (e.g. `loadDocument()`, `undo()`, `gotoPosition()`) that cannot be expressed as pure declarative state. Different UI paradigms require different API exposure strategies.

#### 3.0.1 Imperative UI Frameworks

In imperative frameworks (Android View, UIKit, AppKit, Swing, WinForms, etc.), host code can directly hold a reference to the widget instance.

- The APIs in Section 3.2, plus any module-specific public APIs defined in later sections for implemented optional modules, MUST be exposed as public methods directly on the widget entry class (e.g. `SweetEditor`, `SweetEditorView`, `SweetEditorControl`)
- MAY additionally provide `SweetEditorController` to decouple control logic, but this is not required

```java
// Android View
SweetEditor editor = findViewById(R.id.editor);
editor.loadDocument(doc);
editor.applyTheme(EditorTheme.dark());
```

#### 3.0.2 Declarative UI Frameworks

In declarative frameworks (Flutter, Jetpack Compose, SwiftUI, ArkUI, etc.), Widgets/Composables are immutable description objects and host code cannot directly hold a widget instance.

- MUST provide a `SweetEditorController` class as the sole imperative entry point for external control of the editor
- `SweetEditorController` MUST expose all APIs defined in Section 3.2, plus any module-specific public APIs from later sections for implemented optional modules
- The widget entry class (e.g. `SweetEditorWidget`, `SweetEditorView`) MUST accept `SweetEditorController` as a constructor parameter
- The widget MUST internally bind itself to the Controller on mount and unbind on unmount

```dart
// Flutter
final controller = SweetEditorController();
SweetEditorWidget(controller: controller);
controller.loadDocument(doc);
controller.applyTheme(EditorTheme.dark());
```

#### 3.0.3 `SweetEditorController` Specification

| Rule | Constraint | Description |
|---|---|---|
| Lifecycle callback | **MUST** | Provide `whenReady(callback)` method that fires when the widget finishes mounting; if already ready at call time, execute immediately |
| Calls before mount | **SHOULD** | When calling Controller methods before the widget is mounted, SHOULD queue operations and execute them in order after mount; MAY choose to silently ignore (no-op) |
| Bind / Unbind | **MUST** | Provide internal `bind(editorApi)` / `unbind()` mechanism (naming MAY vary by platform); widget calls `bind` on mount and `unbind` on unmount |
| Multiple bindings | **MUST** | The same Controller instance MAY be bound to a new widget after the previous one unbinds; MUST NOT be bound to multiple widgets simultaneously |
| API consistency | **MUST** | Method signatures exposed on the Controller MUST match the Public API table in Section 3.2 and any implemented module-specific public API tables in later sections (method name, parameters, return type) |
| Getter methods | **SHOULD** | When the widget is not mounted, getter methods (e.g. `getDocument()`, `getCursorPosition()`) SHOULD return null or default values; MUST NOT throw exceptions |
| Resource disposal | **MUST** | Provide a `dispose()` method (naming MAY vary by platform, e.g. `close()`, `release()`) that releases internal resources and unbinds the widget |

#### 3.0.4 Platform Classification Reference

| UI Paradigm | Frameworks | API Carrier |
|---|---|---|
| Imperative | Android View, UIKit, AppKit, Swing, WinForms | Widget entry class exposes directly |
| Declarative | Flutter, Jetpack Compose, SwiftUI, ArkUI, React, Vue | `SweetEditorController` |
| Hybrid | React Native, Qt (QML + C++) | Determined by the primary UI layer paradigm |

> If a platform provides both imperative and declarative APIs (e.g. Apple has both UIKit and SwiftUI), the imperative API is exposed on the widget class, and the declarative wrapper MUST additionally provide a Controller.

---

### 3.1 `EditorCore` Public API

| Function | Canonical Name | Allowed Variants |
|---|---|---|
| **Configuration** | | |
| Load document | `loadDocument(doc)` | 鈥?|
| Set viewport | `setViewport(w, h)` | 鈥?|
| Font metrics changed | `onFontMetricsChanged()` | 鈥?|
| Fold arrow mode | `setFoldArrowMode(mode)` | 鈥?|
| Wrap mode | `setWrapMode(mode)` | 鈥?|
| Tab size | `setTabSize(size)` | 鈥?|
| Insert spaces | `setInsertSpaces(enabled)` | 鈥?|
| Scale | `setScale(scale)` | 鈥?|
| Line spacing | `setLineSpacing(add, mult)` | 鈥?|
| Content start padding | `setContentStartPadding(padding)` | 鈥?|
| Show split line | `setShowSplitLine(show)` | 鈥?|
| Current line render mode | `setCurrentLineRenderMode(mode)` | 鈥?|
| Gutter sticky | `setGutterSticky(sticky)` | 鈥?|
| Gutter visible | `setGutterVisible(visible)` | 鈥?|
| Handle config | `setHandleConfig(...)` | 鈥?|
| Scrollbar config | `setScrollbarConfig(...)` | 鈥?|
| **Render Model** | | |
| Build render model | `buildRenderModel()` | 鈥?|
| Get layout metrics | `getLayoutMetrics()` | property: `layoutMetrics` / `LayoutMetrics { get; }` |
| **Gesture / Keyboard** | | |
| Handle gesture event | `handleGestureEvent(...)` | 鈥?|
| Handle gesture event (extended) | `handleGestureEventEx(...)` | 鈥?|
| Edge scroll tick | `tickEdgeScroll()` | 鈥?|
| Fling tick | `tickFling()` | 鈥?|
| Animation tick | `tickAnimations()` | 鈥?|
| Handle key event | `handleKeyEvent(...)` | 鈥?|
| Set key map | `setKeyMap(keyMap)` | 鈥?|
| **Text Editing** | | |
| Insert text | `insertText(text)` | 鈥?|
| Replace text | `replaceText(range, text)` | 鈥?|
| Delete text | `deleteText(range)` | 鈥?|
| Backspace | `backspace()` | 鈥?|
| Delete forward | `deleteForward()` | 鈥?|
| Move line up | `moveLineUp()` | 鈥?|
| Move line down | `moveLineDown()` | 鈥?|
| Copy line up | `copyLineUp()` | 鈥?|
| Copy line down | `copyLineDown()` | 鈥?|
| Delete line | `deleteLine()` | 鈥?|
| Insert line above | `insertLineAbove()` | 鈥?|
| Insert line below | `insertLineBelow()` | 鈥?|
| **Undo / Redo** | | |
| Undo | `undo()` | 鈥?|
| Redo | `redo()` | 鈥?|
| Can undo | `canUndo()` | 鈥?|
| Can redo | `canRedo()` | 鈥?|
| **Cursor / Selection** | | |
| Set cursor position | `setCursorPosition(line, col)` | 鈥?|
| Get cursor position | `getCursorPosition()` | property: `cursorPosition` / `CursorPosition { get; }` |
| Select all | `selectAll()` | 鈥?|
| Set selection | `setSelection(sL, sC, eL, eC)` | 鈥?|
| Get selection | `getSelection()` | property: `selection` / `Selection { get; }` |
| Get selected text | `getSelectedText()` | property: `selectedText` / `SelectedText { get; }` |
| Word range at cursor | `getWordRangeAtCursor()` | property: `wordRangeAtCursor` / `WordRangeAtCursor { get; }` |
| Word at cursor | `getWordAtCursor()` | property: `wordAtCursor` / `WordAtCursor { get; }` |
| Move cursor left | `moveCursorLeft(extend)` | 鈥?|
| Move cursor right | `moveCursorRight(extend)` | 鈥?|
| Move cursor up | `moveCursorUp(extend)` | 鈥?|
| Move cursor down | `moveCursorDown(extend)` | 鈥?|
| Move cursor to line start | `moveCursorToLineStart(extend)` | 鈥?|
| Move cursor to line end | `moveCursorToLineEnd(extend)` | 鈥?|
| **IME** | | |
| Composition start | `compositionStart()` | 鈥?|
| Composition update | `compositionUpdate(text)` | 鈥?|
| Composition end | `compositionEnd(committed)` | 鈥?|
| Composition cancel | `compositionCancel()` | 鈥?|
| Is composing | `isComposing()` | property: `isComposing` / `IsComposing { get; }` |
| Set composition enabled | `setCompositionEnabled(enabled)` | 鈥?|
| Is composition enabled | `isCompositionEnabled()` | property: `isCompositionEnabled` / `IsCompositionEnabled { get; }` |
| **Read-only / Indent** | | |
| Set read-only | `setReadOnly(readOnly)` | 鈥?|
| Is read-only | `isReadOnly()` | property: `isReadOnly` / `IsReadOnly { get; }` |
| Set auto indent mode | `setAutoIndentMode(mode)` | 鈥?|
| Get auto indent mode | `getAutoIndentMode()` | property: `autoIndentMode` / `AutoIndentMode { get; }` |
| Set backspace unindent | `setBackspaceUnindent(enabled)` | 鈥?|
| **Navigation / Scroll** | | |
| Scroll to line | `scrollToLine(line, behavior)` | 鈥?|
| Go to position | `gotoPosition(line, col)` | 鈥?|
| Ensure cursor visible | `ensureCursorVisible()` | 鈥?|
| Set scroll | `setScroll(x, y)` | 鈥?|
| Get scroll metrics | `getScrollMetrics()` | property: `scrollMetrics` / `ScrollMetrics { get; }` |
| Get position rect | `getPositionRect(line, col)` | 鈥?|
| Get cursor rect | `getCursorRect()` | property: `cursorRect` / `CursorRect { get; }` |
| **Style / Highlight** | | |
| Register text style | `registerTextStyle(id, color, bg, fontStyle)` | 鈥?|
| Batch register styles | `registerBatchTextStyles(data)` | 鈥?|
| Set line spans | `setLineSpans(line, layer, spans)` | 鈥?|
| Batch set line spans | `setBatchLineSpans(layer, entries)` | 鈥?|
| Clear line spans | `clearLineSpans(line, layer)` | 鈥?|
| Clear highlights by layer | `clearHighlights(layer)` | 鈥?|
| Clear all highlights | `clearHighlights()` | 鈥?|
| **Inlay Hint** | | |
| Set line inlay hints | `setLineInlayHints(line, hints)` | 鈥?|
| Batch set inlay hints | `setBatchLineInlayHints(entries)` | 鈥?|
| Clear inlay hints | `clearInlayHints()` | 鈥?|
| **Phantom Text** | | |
| Set line phantom texts | `setLinePhantomTexts(line, phantoms)` | 鈥?|
| Batch set phantom texts | `setBatchLinePhantomTexts(entries)` | 鈥?|
| Clear phantom texts | `clearPhantomTexts()` | 鈥?|
| **Gutter Icon** | | |
| Set line gutter icons | `setLineGutterIcons(line, icons)` | 鈥?|
| Batch set gutter icons | `setBatchLineGutterIcons(entries)` | 鈥?|
| Set max gutter icons | `setMaxGutterIcons(count)` | 鈥?|
| Clear gutter icons | `clearGutterIcons()` | 鈥?|
| **Diagnostic** | | |
| Set line diagnostics | `setLineDiagnostics(line, items)` | 鈥?|
| Batch set diagnostics | `setBatchLineDiagnostics(entries)` | 鈥?|
| Clear diagnostics | `clearDiagnostics()` | 鈥?|
| **Guide** | | |
| Set indent guides | `setIndentGuides(guides)` | 鈥?|
| Set bracket guides | `setBracketGuides(guides)` | 鈥?|
| Set flow guides | `setFlowGuides(guides)` | 鈥?|
| Set separator guides | `setSeparatorGuides(guides)` | 鈥?|
| Clear guides | `clearGuides()` | 鈥?|
| **Bracket** | | |
| Set bracket pairs | `setBracketPairs(open, close)` | 鈥?|
| Set auto-closing pairs | `setAutoClosingPairs(open, close)` | 鈥?|
| Set matched brackets | `setMatchedBrackets(oL, oC, cL, cC)` | 鈥?|
| Clear matched brackets | `clearMatchedBrackets()` | 鈥?|
| **Folding** | | |
| Set fold regions | `setFoldRegions(regions)` | 鈥?|
| Toggle fold | `toggleFoldAt(line)` | Swift: `toggleFold(at:)` |
| Fold | `foldAt(line)` | Swift: `fold(at:)` |
| Unfold | `unfoldAt(line)` | Swift: `unfold(at:)` |
| Fold all | `foldAll()` | 鈥?|
| Unfold all | `unfoldAll()` | 鈥?|
| Is line visible | `isLineVisible(line)` | 鈥?|
| **Clear** | | |
| Clear all decorations | `clearAllDecorations()` | 鈥?|
| **Linked Editing** | | |
| Insert snippet | `insertSnippet(template)` | 鈥?|
| Start linked editing | `startLinkedEditing(model)` | 鈥?|
| Is in linked editing | `isInLinkedEditing()` | property: `isInLinkedEditing` / `IsInLinkedEditing { get; }` |
| Next tab stop | `linkedEditingNext()` | 鈥?|
| Previous tab stop | `linkedEditingPrev()` | 鈥?|
| Cancel linked editing | `cancelLinkedEditing()` | 鈥?|

> Payload-level APIs (e.g. `setLineSpans`, `setBatchLineSpans`) 鈥?all platforms MUST provide high-level typed wrappers (e.g. `setLineSpans(line, layer, spans: List<StyleSpan>)`). Platforms SHOULD additionally expose raw/binary payload APIs when the host language has a natural public binary carrier (e.g. `ByteBuffer`, `NSData`, `byte[]`, `Uint8List`). If both typed and payload APIs are exposed, their parameter semantics and final Core behavior MUST be identical. Payload encoding format remains platform-defined.

### 3.2 `SweetEditor` Public API

| Function | Canonical Name | Allowed Variants |
|---|---|---|
| **Document / Theme** | | |
| Load document | `loadDocument(doc)` | 鈥?|
| Get document | `getDocument()` | property: `document` / `Document { get; }` |
| Apply theme | `applyTheme(theme)` | 鈥?|
| Get theme | `getTheme()` | property: `theme` / `Theme { get; }` |
| **Configuration** | | |
| Get settings | `getSettings()` | property: `settings` / `Settings { get; }` |
| Get key map *(SHOULD)* | `getKeyMap()` | property: `keyMap` / `KeyMap { get; }` |
| Set key map | `setKeyMap(keyMap)` | 鈥?|
| Icon provider | `setEditorIconProvider(provider)` | 鈥?|
| **Text Editing** | | |
| Insert text | `insertText(text)` | 鈥?|
| Replace text | `replaceText(range, text)` | 鈥?|
| Delete text | `deleteText(range)` | 鈥?|
| Move line up | `moveLineUp()` | 鈥?|
| Move line down | `moveLineDown()` | 鈥?|
| Copy line up | `copyLineUp()` | 鈥?|
| Copy line down | `copyLineDown()` | 鈥?|
| Delete line | `deleteLine()` | 鈥?|
| Insert line above | `insertLineAbove()` | 鈥?|
| Insert line below | `insertLineBelow()` | 鈥?|
| **Undo / Redo** | | |
| Undo | `undo()` | 鈥?|
| Redo | `redo()` | 鈥?|
| Can undo | `canUndo()` | 鈥?|
| Can redo | `canRedo()` | 鈥?|
| **Clipboard (MAY)** | | |
| Copy | `copyToClipboard()` | 鈥?|
| Paste | `pasteFromClipboard()` | 鈥?|
| Cut | `cutToClipboard()` | 鈥?|
| **Cursor / Selection** | | |
| Select all | `selectAll()` | 鈥?|
| Get selected text | `getSelectedText()` | property: `selectedText` / `SelectedText { get; }` |
| Set selection | `setSelection(sL, sC, eL, eC)` | 鈥?|
| Get selection | `getSelection()` | property: `selection` / `Selection { get; }` |
| Set cursor | `setCursorPosition(pos)` | 鈥?|
| Get cursor | `getCursorPosition()` | property: `cursorPosition` / `CursorPosition { get; }` |
| Word range at cursor | `getWordRangeAtCursor()` | property: `wordRangeAtCursor` / `WordRangeAtCursor { get; }` |
| Word at cursor | `getWordAtCursor()` | property: `wordAtCursor` / `WordAtCursor { get; }` |
| **Navigation / Scroll** | | |
| Go to position | `gotoPosition(line, col)` | 鈥?|
| Scroll to line | `scrollToLine(line, behavior)` | 鈥?|
| Set scroll | `setScroll(x, y)` | 鈥?|
| Get scroll metrics | `getScrollMetrics()` | property: `scrollMetrics` / `ScrollMetrics { get; }` |
| Get position rect | `getPositionRect(line, col)` | 鈥?|
| Get cursor rect | `getCursorRect()` | property: `cursorRect` / `CursorRect { get; }` |
| **Folding** | | |
| Toggle fold | `toggleFoldAt(line)` | Swift: `toggleFold(at:)` |
| Fold line | `foldAt(line)` | 鈥?|
| Unfold line | `unfoldAt(line)` | 鈥?|
| Is line visible | `isLineVisible(line)` | 鈥?|
| Fold all | `foldAll()` | 鈥?|
| Unfold all | `unfoldAll()` | 鈥?|
| **Language / Metadata** | | |
| Set language config | `setLanguageConfiguration(config)` | 鈥?|
| Get language config | `getLanguageConfiguration()` | property: `languageConfiguration` / `LanguageConfiguration { get; }` |
| Set metadata | `setMetadata(metadata)` | 鈥?|
| Get metadata | `getMetadata()` | property: `metadata` / `Metadata { get; }` |
| **Provider Management** | | |
| Add decoration provider | `addDecorationProvider(provider)` | `attachDecorationProvider(provider)` |
| Remove decoration provider | `removeDecorationProvider(provider)` | `detachDecorationProvider(provider)` |
| Request decoration refresh | `requestDecorationRefresh()` | 鈥?|
| Add completion provider | `addCompletionProvider(provider)` | `attachCompletionProvider(provider)` |
| Remove completion provider | `removeCompletionProvider(provider)` | `detachCompletionProvider(provider)` |
| Add newline provider | `addNewLineActionProvider(provider)` | `attachNewLineActionProvider(provider)` |
| Remove newline provider | `removeNewLineActionProvider(provider)` | `detachNewLineActionProvider(provider)` |
| **Completion** | | |
| Trigger completion | `triggerCompletion()` | 鈥?|
| Show completion items | `showCompletionItems(items)` | 鈥?|
| Dismiss completion | `dismissCompletion()` | 鈥?|
| Configure completion item rendering | `setCompletionItemRenderer(renderer)` | `setCompletionItemViewFactory(factory)`, `setCompletionCellRenderer(renderer)`, or other platform-idiomatic rendering customization APIs |
| **Style** | | |
| Register text style | `registerTextStyle(id, ...)` | 鈥?|
| Register batch text styles | `registerBatchTextStyles(stylesById)` | 鈥?|
| **Decoration / Adornment Write** | | |
| Set line spans | `setLineSpans(line, layer, spans)` | 鈥?|
| Set batch line spans | `setBatchLineSpans(layer, spansByLine)` | 鈥?|
| Set line inlay hints | `setLineInlayHints(line, hints)` | 鈥?|
| Set batch line inlay hints | `setBatchLineInlayHints(hintsByLine)` | 鈥?|
| Set line phantom texts | `setLinePhantomTexts(line, phantoms)` | 鈥?|
| Set batch line phantom texts | `setBatchLinePhantomTexts(phantomsByLine)` | 鈥?|
| Set line gutter icons | `setLineGutterIcons(line, icons)` | 鈥?|
| Set batch line gutter icons | `setBatchLineGutterIcons(iconsByLine)` | 鈥?|
| Set line diagnostics | `setLineDiagnostics(line, items)` | 鈥?|
| Set batch line diagnostics | `setBatchLineDiagnostics(diagsByLine)` | 鈥?|
| Set indent guides | `setIndentGuides(guides)` | 鈥?|
| Set bracket guides | `setBracketGuides(guides)` | 鈥?|
| Set flow guides | `setFlowGuides(guides)` | 鈥?|
| Set separator guides | `setSeparatorGuides(guides)` | 鈥?|
| Set fold regions | `setFoldRegions(regions)` | 鈥?|
| **Decoration / Adornment Clear** | | |
| Clear highlights | `clearHighlights()` | 鈥?|
| Clear highlights by layer | `clearHighlights(layer)` | 鈥?|
| Clear inlay hints | `clearInlayHints()` | 鈥?|
| Clear phantom texts | `clearPhantomTexts()` | 鈥?|
| Clear gutter icons | `clearGutterIcons()` | 鈥?|
| Clear guides | `clearGuides()` | 鈥?|
| Clear diagnostics | `clearDiagnostics()` | 鈥?|
| Clear all decorations | `clearAllDecorations()` | 鈥?|
| **Flush** | | |
| Flush | `flush()` | 鈥?|
| **Query** | | |
| Visible line range | `getVisibleLineRange()` | property: `visibleLineRange` / `VisibleLineRange { get; }` |
| Total line count | `getTotalLineCount()` | property: `totalLineCount` / `TotalLineCount { get; }` |

> The canonical naming for provider management methods is `add` / `remove`. Each platform MAY use semantically equivalent variants per its own conventions (e.g. `attach` / `detach`, `register` / `unregister`).

> Clipboard methods (`copyToClipboard`, `pasteFromClipboard`, `cutToClipboard`) are **MAY** because clipboard access is platform-specific.

> Event exposure does not require a uniform method shape. Platforms MUST provide a type-safe event mechanism per Section 11, and may use `subscribe` / `unsubscribe`, platform-native `event` / delegates, typed `Stream` getters, signals / observers, or equivalent forms.

> Section 3.2 is the widget-entry public API index. Some module-specific interfaces, data models, and callback contracts are further specified in later sections (for example Sections 4, 5, 6, 7, and 10); Sections 4, 5, and 10 define required-module contracts, while Sections 6 and 7 define optional or conditional module contracts.

---

## 4. Provider Interfaces (MUST)

> **General rules:**
> - `provideDecorations` and `provideCompletions` MUST support both **synchronous** and **asynchronous** result delivery
> - `DecorationProvider` MUST support multi-shot result delivery so a single request may yield zero, one, or multiple successive snapshots
> - `CompletionProvider` MUST support at least single-shot result delivery, and MAY support multi-shot / incremental result updates
> - In-flight decoration / completion requests MUST have an explicit cancellation / staleness contract; once a request becomes cancelled or stale, any late result from that request MUST be ignored
> - Platforms MAY expose provider results via a Receiver callback, `Future` / `Promise` / `Task`, coroutine / `suspend` API, stream / observable, or another platform-idiomatic async form
> - The **Receiver callback pattern remains the recommended public shape** because it naturally supports sync return, async return, multi-shot updates, and cancellation checks in one contract
> - If the platform does not expose the Receiver shape, it MUST still document how its chosen API expresses immediate delivery, deferred delivery, multi-shot updates where applicable, and cancellation / staleness
> - Multiple instances of the same Provider type can be registered; the Manager is responsible for iterating and merging results
> - The provider-manager pattern (register -> iterate -> dispatch) MUST be consistent across all platforms

### 4.1 DecorationProvider

#### Recommended Receiver Signature

```
interface DecorationProvider {
    getCapabilities() -> Set<DecorationType>
    provideDecorations(context: DecorationContext, receiver: DecorationReceiver) -> void
}

interface DecorationReceiver {
    accept(result: DecorationResult) -> boolean
    isCancelled() -> boolean
}
```

> Platforms MAY expose a semantically equivalent async API instead of an explicit `DecorationReceiver`, but the contract MUST still support immediate results, deferred results, and cancellation / staleness checks. If an explicit Receiver type is exposed, `DecorationReceiver` is the recommended name.

#### DecorationContext MUST Fields

| Field | Type | Description |
|---|---|---|
| `visibleStartLine` | int | Visible area start line (0-based) |
| `visibleEndLine` | int | Visible area end line (0-based) |
| `totalLineCount` | int | Total line count of the document |
| `textChanges` | List\<TextChange\> | Text changes accumulated during this refresh cycle; empty list means non-text-change trigger |
| `languageConfiguration` | LanguageConfiguration? | Current language configuration (nullable) |
| `editorMetadata` | EditorMetadata? | Current editor metadata (nullable) |

#### ApplyMode Enum (MUST)

Each decoration data type MUST have a corresponding `ApplyMode` that controls how the Manager merges results:

| Value | Description |
|---|---|
| `MERGE` | Merge with existing data (default) |
| `REPLACE_ALL` | Replace all existing data |
| `REPLACE_RANGE` | Replace only data within the visible range |

When multiple Providers return different ApplyModes, the Manager MUST use the highest priority: `REPLACE_ALL` > `REPLACE_RANGE` > `MERGE`.

#### DecorationResult MUST Fields

`DecorationResult` contains 11 decoration data types, each with a corresponding `ApplyMode` (default `MERGE`). Data types MUST use the standard types defined in the Core layer (e.g. `StyleSpan`, `InlayHint`, `Diagnostic`, etc.).

| Data Field | Type | ApplyMode Field |
|---|---|---|
| `syntaxSpans` | Map\<int, List\<StyleSpan\>\>? | `syntaxSpansMode` |
| `semanticSpans` | Map\<int, List\<StyleSpan\>\>? | `semanticSpansMode` |
| `inlayHints` | Map\<int, List\<InlayHint\>\>? | `inlayHintsMode` |
| `diagnostics` | Map\<int, List\<Diagnostic\>\>? | `diagnosticsMode` |
| `indentGuides` | List\<IndentGuide\>? | `indentGuidesMode` |
| `bracketGuides` | List\<BracketGuide\>? | `bracketGuidesMode` |
| `flowGuides` | List\<FlowGuide\>? | `flowGuidesMode` |
| `separatorGuides` | List\<SeparatorGuide\>? | `separatorGuidesMode` |
| `foldRegions` | List\<FoldRegion\>? | `foldRegionsMode` |
| `gutterIcons` | Map\<int, List\<GutterIcon\>\>? | `gutterIconsMode` |
| `phantomTexts` | Map\<int, List\<PhantomText\>\>? | `phantomTextsMode` |

> Line-indexed data (syntaxSpans, semanticSpans, etc.) uses `Map<int, List<T>>` where the key is the line number (0-based).

#### Multi-Provider Merge Strategy

The Manager iterates all registered Providers and merges each Provider's snapshot according to ApplyMode:
- `MERGE`: append and merge same-type data from each Provider
- `REPLACE_ALL`: clear all existing data first, then write new data
- `REPLACE_RANGE`: clear only existing data within the visible range, then write new data

### 4.2 CompletionProvider

#### Recommended Receiver Signature

```
interface CompletionProvider {
    isTriggerCharacter(ch: String) -> boolean
    provideCompletions(context: CompletionContext, receiver: CompletionReceiver) -> void
}

interface CompletionReceiver {
    accept(result: CompletionResult) -> boolean
    isCancelled() -> boolean
}
```

> Platforms MAY expose a semantically equivalent async API instead of an explicit `CompletionReceiver`, but the contract MUST still support immediate results, deferred results, and cancellation / staleness checks. If an explicit Receiver type is exposed, `CompletionReceiver` is the recommended name.

#### CompletionTriggerKind Enum (MUST)

| Value | Description |
|---|---|
| `INVOKED` | User manually triggered (e.g. Ctrl+Space) |
| `CHARACTER` | Trigger character entered (e.g. `.`) |
| `RETRIGGER` | Re-trigger after content change |

#### CompletionContext MUST Fields

| Field | Type | Description |
|---|---|---|
| `triggerKind` | CompletionTriggerKind | Trigger type |
| `triggerCharacter` | String? | Trigger character (nullable, only set for CHARACTER type) |
| `cursorPosition` | TextPosition | Cursor position |
| `lineText` | String | Current line text |
| `wordRange` | TextRange | Word range at cursor |
| `languageConfiguration` | LanguageConfiguration? | Current language configuration (nullable) |
| `editorMetadata` | EditorMetadata? | Current editor metadata (nullable) |

#### CompletionResult MUST Fields

| Field | Type | Description |
|---|---|---|
| `items` | List\<CompletionItem\> | List of completion items |
| `isIncomplete` | boolean | Whether the result is incomplete (true means subsequent input should re-request) |

#### Multi-Provider Merge and Sort Strategy

The Manager iterates all Providers, merges the `CompletionItem` lists returned by each Provider, and sorts by `sortKey` (falling back to `label`).

### 4.3 NewLineActionProvider

#### Interface Signature

```
interface NewLineActionProvider {
    provideNewLineAction(context: NewLineContext) -> NewLineAction?
}
```

> `NewLineActionProvider` remains synchronous because newline handling is part of the immediate input path.

#### NewLineContext MUST Fields

| Field | Type | Description |
|---|---|---|
| `lineNumber` | int | Caret line number (0-based) |
| `column` | int | Caret column (0-based) |
| `lineText` | String | Current line text |
| `languageConfiguration` | LanguageConfiguration? | Current language configuration (nullable) |
| `editorMetadata` | EditorMetadata? | Current editor metadata (nullable) |

#### NewLineAction MUST Fields

| Field | Type | Description |
|---|---|---|
| `text` | String | Full text to insert (including newline and indentation) |

#### Multi-Provider Chain Priority Strategy

The Manager iterates all Providers in registration order and returns the first non-null `NewLineAction`. If all Providers return null, the default newline behavior is used.
## 5. `CompletionItem` Field Definitions (MUST)

`CompletionItem` is the core data type of the completion system. Application priority on commit: `textEdit` 鈫?`insertText` 鈫?`label`.

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `label` | String | **MUST** | Display label (used for list display and fallback insertion) |
| `detail` | String? | **MAY** | Detailed description (displayed to the right of or below the label) |
| `insertText` | String? | **MAY** | Insert text (takes priority over `label` for insertion) |
| `insertTextFormat` | int | **MUST** | Insert text format: `PLAIN_TEXT=1` (default), `SNIPPET=2` (VSCode Snippet format, supports `$1`, `${1:default}`, `$0` placeholders) |
| `textEdit` | CompletionTextEdit? | **MAY** | Precise replacement edit (specifies replacement range + new text), highest priority |
| `filterText` | String? | **MAY** | Filter/match text (falls back to `label` when null) |
| `sortKey` | String? | **MAY** | Sort key (falls back to `label` when null) |
| `kind` | int | **MUST** | Completion item kind (affects icon display) |

**Kind constants (MUST):**

| Constant | Value |
|---|---|
| `KIND_KEYWORD` | 0 |
| `KIND_FUNCTION` | 1 |
| `KIND_VARIABLE` | 2 |
| `KIND_CLASS` | 3 |
| `KIND_INTERFACE` | 4 |
| `KIND_MODULE` | 5 |
| `KIND_PROPERTY` | 6 |
| `KIND_SNIPPET` | 7 |
| `KIND_TEXT` | 8 |

**`CompletionTextEdit`** sub-type:

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `range` | TextRange | **MUST** | Replacement range |
| `newText` | String | **MUST** | Replacement text |

---

## 6. Copilot / InlineSuggestion Interface Definition (SHOULD)

The inline suggestion (Copilot) module is SHOULD level, but when implemented MUST follow the interface specification below.

### 6.1 `InlineSuggestion` Data Type

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `line` | int | **MUST** | Target line number (0-based) |
| `column` | int | **MUST** | Insertion column (0-based, UTF-16 offset) |
| `text` | String | **MUST** | Suggestion text content |

> `InlineSuggestion` SHOULD be an immutable object.

### 6.2 Inline Suggestion Callback Contract

Platforms MUST provide a host-visible way to observe inline suggestion acceptance and dismissal.

Platforms MAY use any of the following forms:
- An explicit listener interface
- Delegate / closure / callback setters
- Platform-native events / typed streams / signals

If a platform exposes an explicit listener interface, the recommended shape is:

```
interface InlineSuggestionListener {
    onSuggestionAccepted(suggestion: InlineSuggestion) -> void
    onSuggestionDismissed(suggestion: InlineSuggestion) -> void
}
```

The callback contract MUST satisfy all of the following:
- A visible inline suggestion MUST have two distinct host-visible events: `accepted` and `dismissed`
- `accepted` payload MUST include the accepted `InlineSuggestion` value, or an equivalent payload from which the same suggestion can be unambiguously identified
- `dismissed` payload MUST include the dismissed `InlineSuggestion` value, or an equivalent payload / identifier, unless the platform's callback form is a no-payload dismissed signal and that limitation is explicitly documented
- For a single shown suggestion instance, `accepted` MUST fire at most once and `dismissed` MUST fire at most once
- After either `accepted` or `dismissed` fires for a shown suggestion instance, no further callbacks for that same suggestion instance MAY be emitted
- If `showInlineSuggestion()` replaces an already-visible suggestion, the platform MAY either emit `dismissed` for the previous suggestion before switching, or replace it quietly without a `dismissed` callback; in either case the previous suggestion instance MUST NOT emit further callbacks after replacement
- After widget destruction, unbind, or controller disposal, no further host-visible inline-suggestion callbacks MAY be emitted

| Callback | Constraint | Trigger Condition |
|---|---|---|
| `onSuggestionAccepted` | **MUST** | When the user accepts the currently visible suggestion |
| `onSuggestionDismissed` | **MUST** | When the user dismisses the currently visible suggestion |

### 6.3 `SweetEditor` Copilot API

| Method | Constraint | Description |
|---|---|---|
| `showInlineSuggestion(suggestion)` | **MUST** | Show the inline suggestion and make it available for accept / dismiss interaction |
| `dismissInlineSuggestion()` | **MUST** | Dismiss the current inline suggestion and remove its visible presentation |
| `isInlineSuggestionShowing()` | **MUST** | Query whether an inline suggestion is currently showing |
| `setInlineSuggestionListener(listener)` | **MUST** | Register the host-visible accepted / dismissed listener; passing `null` clears it |

> Platforms MAY expose semantically equivalent APIs such as `setInlineSuggestionCallbacks(callbacks)`, delegate setters, event subscriptions, or typed streams.

### 6.4 Auto-dismiss Behavior

| Rule | Constraint | Description |
|---|---|---|
| Text change | **MUST** | MUST automatically dismiss the current inline suggestion when the user types text |
| Cursor movement | **MUST** | MUST automatically dismiss the current inline suggestion when the cursor position changes |
| Scrolling | **SHOULD** | SHOULD update the visible suggestion affordance position on scroll when applicable; SHOULD NOT auto-dismiss |

### 6.5 `InlineSuggestionController` (MAY)

`InlineSuggestionController` is the recommended internal implementation pattern (see Section 1.3), responsible for managing the complete lifecycle of inline suggestions:

- Suggestion presentation and removal
- Event listener (TextChanged / CursorChanged / ScrollChanged) subscription and unsubscription
- Accept / dismiss interaction and any associated visual affordance positioning
- Accept / dismiss key handling where applicable

Platforms MAY choose not to use the Controller pattern, but MUST implement equivalent functionality.

---

## 7. Selection / SelectionMenu Interface Definition (MAY, mobile-only)

The selection menu module is MAY overall. Desktop platforms MAY omit it entirely. If implemented, it MUST follow the contract below.

### 7.1 `SelectionMenuItem` Data Type

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `id` | String | **MUST** | Stable action identifier used by host code to distinguish menu items |
| `label` | String | **MUST** | Display text shown in the menu |
| `enabled` | boolean | **MAY** | Whether the menu item is currently actionable; defaults to enabled if omitted |
| `iconId` | int? | **MAY** | Optional icon resource ID when the platform supports icons in the selection menu |

> `SelectionMenuItem` is the shared menu-item data model. If a platform exposes standard actions, the recommended built-in `id` values are `cut`, `copy`, `paste`, and `select_all`; custom actions MAY use any stable `id`.

### 7.2 `SelectionMenuItemProvider`

If the platform allows host code to customize selection-menu items, the recommended shape is:

```
interface SelectionMenuItemProvider {
    provideMenuItems(editor: SweetEditor) -> List<SelectionMenuItem>
}
```

This capability SHOULD satisfy the following semantics:
- The provider returns the complete menu model for the current show cycle, rather than incremental appended items
- When the provider is `null`, the platform SHOULD restore the default selection menu
- When the provider returns an empty list, the platform MAY choose not to show a selection menu
- The provider SHOULD be invoked again immediately before the menu is shown so items can reflect current editor state

### 7.3 Selection Menu Callback Contract

If the platform exposes `SelectionMenuItemProvider` or any other custom-item injection mechanism, it MUST provide a host-visible way to observe custom selection-menu item activation. Platforms MAY use an explicit listener interface, delegate / closure / callback setters, or platform-native events / typed streams / signals.

If a platform exposes an explicit listener interface, the recommended shape is:

```
interface SelectionMenuListener {
    onSelectionMenuItemSelected(itemId: String) -> void
}
```

The callback contract MUST satisfy all of the following:
- Host-visible callbacks MAY cover custom menu items only; built-in cut / copy / paste / select-all actions are not required to emit a unified `item-selected` callback
- The `item-selected` payload SHOULD include the selected custom item's `itemId`, or an equivalent payload from which that menu item can be unambiguously identified
- The standard does not require a host-visible `dismissed` event for selection menus
- After widget destruction, unbind, or controller disposal, no further host-visible custom selection-menu callbacks MAY be emitted

### 7.4 `SweetEditor` Selection API

| Method | Constraint | Description |
|---|---|---|
| `setSelectionMenuItemProvider(provider)` | **MUST** | Configure custom selection-menu items; passing `null` restores the platform default menu |

> Platforms MAY expose semantically equivalent APIs such as `setSelectionMenuListener(listener)`, custom-item click event subscriptions, delegate setters, or typed streams. Platforms MAY additionally expose read-only query APIs such as `isSelectionMenuShowing()`, but the standard does not require them.

### 7.5 Positioning and Lifetime

| Rule | Constraint | Description |
|---|---|---|
| Selection anchor | **MUST** | When visible, the menu MUST be anchored to the current selection / caret geometry or an equivalent platform-native selection affordance |
| Selection invalidation | **MUST** | If the selection becomes empty, invalid, or detached from the current document state, the menu MUST dismiss |
| Scroll / viewport change | **SHOULD** | Scrolling or viewport changes SHOULD update the menu position; they SHOULD NOT require dismiss unless the platform cannot reposition safely |
| Command completion | **SHOULD** | After the user activates a selection-menu command, the menu SHOULD dismiss unless the platform intentionally keeps it open for a multi-step workflow |

### 7.6 `SelectionMenuController` (MAY)

`SelectionMenuController` is the recommended internal implementation pattern for mobile selection menus. It may manage item updates, visibility, positioning, and callback dispatch, but platforms MAY implement equivalent behavior directly in the widget layer.

---

## 8. EditorTheme (MUST)

All platforms MUST define `EditorTheme` with the following color fields. Field names follow Section 2.2 casing rules.

### 8.1 Predefined Style Constants

| Constant | Value |
|---|---|
| `STYLE_KEYWORD` | 1 |
| `STYLE_STRING` | 2 |
| `STYLE_COMMENT` | 3 |
| `STYLE_NUMBER` | 4 |
| `STYLE_BUILTIN` | 5 |
| `STYLE_TYPE` | 6 |
| `STYLE_CLASS` | 7 |
| `STYLE_FUNCTION` | 8 |
| `STYLE_VARIABLE` | 9 |
| `STYLE_PUNCTUATION` | 10 |
| `STYLE_ANNOTATION` | 11 |
| `STYLE_PREPROCESSOR` | 12 |
| `STYLE_USER_BASE` | 100 |

### 8.2 Required Color Fields

All color fields use the platform color type (ARGB). Grouped by function:

**Basic Colors**

| Field | Description |
|---|---|
| `backgroundColor` | Editor background color |
| `textColor` | Default text color, used when not overridden by syntax highlighting |
| `cursorColor` | Cursor color |
| `selectionColor` | Selection highlight fill color (recommended to include alpha) |

**Line Number & Current Line**

| Field | Description |
|---|---|
| `lineNumberColor` | Line number text color |
| `currentLineNumberColor` | Current line number text color |
| `currentLineColor` | Current line highlight background color (recommended to include alpha) |

**Guide Lines**

| Field | Description |
|---|---|
| `guideColor` | Code structure line color (indent/bracket/flow guide) |
| `separatorLineColor` | Separator line color (SeparatorGuide) |
| `splitLineColor` | Line number area split line color |

**Scrollbar**

| Field | Description |
|---|---|
| `scrollbarTrackColor` | Scrollbar track color |
| `scrollbarThumbColor` | Scrollbar thumb color |
| `scrollbarThumbActiveColor` | Scrollbar thumb active (dragging) color |

**IME**

| Field | Description |
|---|---|
| `compositionUnderlineColor` | IME composition underline color |

**InlayHint**

| Field | Description |
|---|---|
| `inlayHintBgColor` | InlayHint rounded background color |
| `inlayHintTextColor` | InlayHint text color (typically with alpha) |
| `inlayHintIconColor` | InlayHint icon tint color (typically with alpha) |

**Fold Placeholder**

| Field | Description |
|---|---|
| `foldPlaceholderBgColor` | Fold placeholder background color (typically with alpha) |
| `foldPlaceholderTextColor` | Fold placeholder text color |

**PhantomText**

| Field | Description |
|---|---|
| `phantomTextColor` | PhantomText color (typically with alpha) |

**Diagnostics**

| Field | Description |
|---|---|
| `diagnosticErrorColor` | Diagnostic ERROR level default color |
| `diagnosticWarningColor` | Diagnostic WARNING level default color |
| `diagnosticInfoColor` | Diagnostic INFO level default color |
| `diagnosticHintColor` | Diagnostic HINT level default color |

**Linked Editing**

| Field | Description |
|---|---|
| `linkedEditingActiveColor` | Linked editing active tab stop border color |
| `linkedEditingInactiveColor` | Linked editing inactive tab stop border color |

**Bracket Matching**

| Field | Description |
|---|---|
| `bracketHighlightBorderColor` | Bracket match highlight border color |
| `bracketHighlightBgColor` | Bracket match highlight background color (semi-transparent) |

**Completion Popup**

| Field | Description |
|---|---|
| `completionBgColor` | Completion popup background color |
| `completionBorderColor` | Completion popup border color |
| `completionSelectedBgColor` | Completion popup selected row highlight color |
| `completionLabelColor` | Completion popup label text color |
| `completionDetailColor` | Completion popup detail text color |

### 8.3 Factory Methods

Every platform MUST provide at least `dark()` and `light()` factory methods that return pre-configured themes.

### 8.4 TextStyle Map

Every `EditorTheme` MUST contain a `textStyles` map (`Map<int, TextStyle>`) and a `defineTextStyle(styleId, style)` method.

---

## 9. EditorSettings (MUST)

All editor appearance and behavior configuration MUST be centralized through the `EditorSettings` object. `SweetEditor` itself MUST NOT directly expose any configuration setters (e.g. `setWrapMode`, `setScale`, `setCompositionEnabled`). Instead, it exposes a `getSettings()` method that returns an `EditorSettings` instance, and callers configure the editor through that instance. This widget-layer rule does not change the `EditorCore` public API defined in Section 3.1.

All platforms MUST expose the following settings through getter/setter pairs (or properties):

| Field | Type | Default | setter | getter | Effect | Description |
|---|---|---|---|---|---|---|
| `editorTextSize` | float | Platform-dependent | `setEditorTextSize(size)` | `getEditorTextSize()` | `relayout` | Editor text size |
| `typeface` / `fontFamily` | Platform font type | `monospace` | `setTypeface(typeface)` / `setFontFamily(family)` | `getTypeface()` / `getFontFamily()` | `relayout` | Font family |
| `scale` | float | 1.0 | `setScale(scale)` | `getScale()` | `relayout` | Scale factor |
| `foldArrowMode` | FoldArrowMode | ALWAYS | `setFoldArrowMode(mode)` | `getFoldArrowMode()` | `repaint` | Fold arrow display mode |
| `wrapMode` | WrapMode | NONE | `setWrapMode(mode)` | `getWrapMode()` | `relayout` | Auto-wrap mode |
| `compositionEnabled` | boolean | Platform-dependent | `setCompositionEnabled(enabled)` | `isCompositionEnabled()` | `runtime-transition` | Whether IME composition mode is enabled |
| `lineSpacingAdd` | float | 0 | `setLineSpacing(add, mult)` | `getLineSpacingAdd()` | `relayout` | Line spacing extra (pixels) |
| `lineSpacingMult` | float | 1.0 | *(same as above)* | `getLineSpacingMult()` | `relayout` | Line spacing multiplier |
| `contentStartPadding` | float | Platform-dependent | `setContentStartPadding(padding)` | `getContentStartPadding()` | `relayout` | Extra horizontal padding between gutter split and text rendering start (pixels) |
| `showSplitLine` | boolean | true | `setShowSplitLine(show)` | `isShowSplitLine()` | `repaint` | Whether to render the gutter split line |
| `gutterSticky` | boolean | Platform-dependent | `setGutterSticky(sticky)` | `isGutterSticky()` | `repaint` | Whether gutter stays fixed during horizontal scroll (true=fixed, false=scrolls with content) |
| `gutterVisible` | boolean | true | `setGutterVisible(visible)` | `isGutterVisible()` | `relayout` | Whether gutter area is visible (false=hide line numbers, icons, fold arrows) |
| `currentLineRenderMode` | CurrentLineRenderMode | BACKGROUND | `setCurrentLineRenderMode(mode)` | `getCurrentLineRenderMode()` | `repaint` | Current line render mode |
| `autoIndentMode` | AutoIndentMode | KEEP_INDENT | `setAutoIndentMode(mode)` | `getAutoIndentMode()` | `runtime-transition` | Auto indent mode |
| `backspaceUnindent` | boolean | true | `setBackspaceUnindent(enabled)` | `isBackspaceUnindent()` | `runtime-transition` | Whether backspace key unindents at line start |
| `readOnly` | boolean | false | `setReadOnly(readOnly)` | `isReadOnly()` | `runtime-transition` | Read-only mode, blocks all edit operations |
| `maxGutterIcons` | int | 0 | `setMaxGutterIcons(count)` | `getMaxGutterIcons()` | `relayout` | Maximum gutter icon count |
| `decorationScrollRefreshMinIntervalMs` | long | 16 | `setDecorationScrollRefreshMinIntervalMs(ms)` | `getDecorationScrollRefreshMinIntervalMs()` | `provider-policy` | Decoration scroll refresh minimum interval (ms) |
| `decorationOverscanViewportMultiplier` | float | 1.5 | `setDecorationOverscanViewportMultiplier(mult)` | `getDecorationOverscanViewportMultiplier()` | `provider-policy` | Decoration overscan viewport multiplier |

> All setter calls MUST take effect immediately.
>
> Effect classification:
> - `repaint`: MUST trigger an immediate repaint or equivalent visual refresh, without requiring text relayout.
> - `relayout`: MUST trigger layout invalidation and rebuild the render model or an equivalent relayout path immediately.
> - `runtime-transition`: MUST apply immediately and safely handle active runtime state transitions required by the setting. A `runtime-transition` setting does not require repaint or relayout unless the current visible state actually changes.
> - `provider-policy`: MUST immediately affect subsequent provider scheduling / refresh behavior. It does not require repaint or relayout unless the implementation explicitly triggers a refresh as part of applying the new policy.
>
> `compositionEnabled` is the canonical example of `runtime-transition`: when switching from enabled to disabled while an IME composition is active, the platform MUST cancel or otherwise safely terminate the active composition before the new setting takes effect.
>
> `contentStartPadding` is platform-dependent by default. It MUST be `>= 0`. `0` is the neutral baseline, but platforms MAY choose a non-zero visual default.
>
> `gutterSticky` is platform-dependent by default. Desktop-style platforms SHOULD default to `true`; mobile / touch-first platforms SHOULD default to `false`.
>
> `autoIndentMode`, `backspaceUnindent`, and `readOnly` are also `runtime-transition` settings. They MUST affect subsequent editing behavior immediately, but they do not require `flush()`, repaint, or relayout if no visible state changes at the moment of the setter call.

---

## 10. Keymap / Shortcut Mapping (MUST)

### 10.1 Core Data Model

All platforms MUST provide the core-layer keymap types `KeyMap`, `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, and `EditorCommand`.

- `KeyMap` MUST be a pure data mapping from `KeyBinding` to command id
- `KeyBinding` MUST support both single-chord and two-chord bindings
- `KeyChord` MUST represent one key press as `modifiers + keyCode`
- Single-chord bindings MUST encode the second chord as an empty / none chord
- `EditorCore.setKeyMap(keyMap)` MUST sync the full binding table to the C++ core

### 10.2 Numeric Alignment

If the platform exposes `KeyCode`, `KeyModifier`, or built-in `EditorCommand` constants, their numeric values MUST align with the C++ core.

- `KeyModifier` MUST use bit flags so combined modifiers can be represented by bitwise OR
- `KeyCode.NONE`, the empty second chord, and `EditorCommand.NONE` MUST preserve the same semantics as the C++ core

### 10.3 Widget-Layer Extension

- `SweetEditor` MUST support `setKeyMap(keyMap)` and SHOULD expose `getKeyMap()`
- Platforms MUST expose `EditorKeyMap` as a widget-layer extension of `KeyMap` so host code can additionally bind command ids to host-side handlers
- `EditorKeyMap` MUST support `registerCommand(binding, handler)`
- If `binding.command == EditorCommand.NONE`, `registerCommand(binding, handler)` MUST auto-assign a custom command id and return it
- Platforms MAY additionally expose convenience APIs for custom-command registration, but `registerCommand(binding, handler)` remains the canonical contract
- Auto-assigned custom command ids MUST be greater than `BUILT_IN_MAX`
- Platforms MUST provide `defaultKeyMap()` as the default binding factory
- Platforms MUST provide `vscode()`, and `defaultKeyMap()` MUST be semantically equivalent to `vscode()`
- Platforms SHOULD provide named preset factories such as `jetbrains()` and `sublime()`
- `SweetEditor.setKeyMap()` MUST replace the current keymap and make the new bindings immediately effective
- Widget-layer handlers remain platform-side and are not serialized to the C++ core
- If a platform does not expose `getKeyMap()`, its documentation MUST clearly describe how host code constructs and replaces the active keymap

---

## 11. Event System (MUST)

### 11.1 Event Mechanism

All platforms MUST provide a **type-safe** editor event exposure mechanism so host code can observe specific event types and manage subscription lifecycle through unsubscribe / dispose / cancel-listening or an equivalent operation.

Platforms MAY use any of the following forms:
- `EditorEventBus` + `subscribe` / `unsubscribe` / `publish` / `clear`
- Platform-native event / delegate / listener mechanisms (for example C# `event`, Java listener callbacks)
- Typed stream / signal / observable getters (for example Dart `Stream<T>`)

If a platform adopts an explicit event-bus/listener pattern, the related public types SHOULD be named `EditorEventBus` / `EditorEventListener`.

### 11.2 Required Event Types

All platforms MUST support the following event types:

```
TextChangedEvent, CursorChangedEvent, SelectionChangedEvent,
ScrollChangedEvent, ScaleChangedEvent, DocumentLoadedEvent,
FoldToggleEvent, GutterIconClickEvent, InlayHintClickEvent,
LongPressEvent,       // mobile only (iOS/Android)
DoubleTapEvent,
ContextMenuEvent      // desktop (macOS/Windows/Linux) & cross-platform UI frameworks
```

> `LongPressEvent` is for mobile platforms (iOS/Android), while `ContextMenuEvent` is for desktop platforms (macOS/Windows/Linux) and cross-platform UI frameworks. Platform implementations SHOULD only register events relevant to their platform.

> The above event types MUST be distinguishable and consumable in a type-safe way through the platform's chosen event mechanism.

Platform-specific events (e.g. `SelectionMenuItemClickEvent` on mobile) MAY be added.

### 11.3 Event Payload Contract

Event payloads MUST be defined per-event. Platforms MUST NOT assume or require a shared base payload schema beyond the event type itself.

| Event | Fields | Description |
|---|---|---|
| `TextChangedEvent` | `changes: List<TextChange>`, `action: TextChangeAction?` *(SHOULD)* | Incremental text changes for the current edit cycle; `action` is an optional coarse-grained semantic hint |
| `CursorChangedEvent` | `cursorPosition: TextPosition` | Current cursor position |
| `SelectionChangedEvent` | `hasSelection: boolean`, `selection: TextRange?`, `cursorPosition: TextPosition` | Current selection state and cursor position |
| `ScrollChangedEvent` | `scrollX: float`, `scrollY: float` | Current view scroll offset |
| `ScaleChangedEvent` | `scale: float` | Current editor scale |
| `DocumentLoadedEvent` | 鈥?| No payload fields are required |
| `FoldToggleEvent` | `line: int`, `isGutter: boolean`, `screenPoint: PointF or platform-native point type` | Toggled fold line, whether the click came from gutter, and screen position |
| `GutterIconClickEvent` | `line: int`, `iconId: int`, `screenPoint: PointF or platform-native point type` | Clicked gutter icon line, icon id, and screen position |
| `InlayHintClickEvent` | `line: int`, `column: int`, `type: InlayType`, `intValue: int`, `screenPoint: PointF or platform-native point type` | Clicked inlay hint position, inlay type, type-specific value, and screen position |
| `LongPressEvent` | `cursorPosition: TextPosition`, `screenPoint: PointF or platform-native point type` | Long-press target position and screen position |
| `DoubleTapEvent` | `cursorPosition: TextPosition`, `hasSelection: boolean`, `selection: TextRange?`, `screenPoint: PointF or platform-native point type` | Double-tap target position, resulting selection state, and screen position |
| `ContextMenuEvent` | `cursorPosition: TextPosition`, `screenPoint: PointF or platform-native point type` | Context-menu target position and screen position |
| `SelectionMenuItemClickEvent` *(platform-specific)* | `item: SelectionMenuItem` | Clicked custom selection-menu item |

---

## 12. Enumeration and Constant Values (MUST)

Enum and enum-like constant values MUST match the C++ core definitions. The following groups MUST have identical members and numeric values across all platforms:

| Enum | Values |
|---|---|
| `WrapMode` | NONE=0, CHAR_BREAK=1, WORD_BREAK=2 |
| `FoldArrowMode` | AUTO=0, ALWAYS=1, HIDDEN=2 |
| `AutoIndentMode` | NONE=0, KEEP_INDENT=1 |
| `CurrentLineRenderMode` | BACKGROUND=0, BORDER=1, NONE=2 |
| `ScrollBehavior` | TOP=0, CENTER=1, BOTTOM=2 |
| `SpanLayer` | SYNTAX=0, SEMANTIC=1 |
| `InlayType` | TEXT=0, ICON=1, COLOR=2 |
| `VisualRunType` | TEXT=0, WHITESPACE=1, NEWLINE=2, INLAY_HINT=3, PHANTOM_TEXT=4, FOLD_PLACEHOLDER=5, TAB=6 |
| `FoldState` | NONE=0, EXPANDED=1, COLLAPSED=2 |
| `DecorationType` | SYNTAX_HIGHLIGHT, SEMANTIC_HIGHLIGHT, INLAY_HINT, DIAGNOSTIC, FOLD_REGION, INDENT_GUIDE, BRACKET_GUIDE, FLOW_GUIDE, SEPARATOR_GUIDE, GUTTER_ICON, PHANTOM_TEXT |
| `GuideType` | INDENT=0, BRACKET=1, FLOW=2, SEPARATOR=3 |
| `GuideDirection` | (platform-aligned with C++ core) |
| `GuideStyle` | SOLID=0, DASHED=1, DOUBLE=2 |
| `SeparatorStyle` | SINGLE=0, DOUBLE=1 |
| `KeyCode` | NONE=0, BACKSPACE=8, TAB=9, ENTER=13, ESCAPE=27, DELETE_KEY=46, LEFT=37, UP=38, RIGHT=39, DOWN=40, HOME=36, END=35, PAGE_UP=33, PAGE_DOWN=34, A=65, C=67, D=68, V=86, X=88, Y=89, Z=90, K=75, SPACE=32 |
| `KeyModifier` | NONE=0, SHIFT=1, CTRL=2, ALT=4, META=8 |
| `EditorCommand` | NONE=0, CURSOR_LEFT=1, CURSOR_RIGHT=2, CURSOR_UP=3, CURSOR_DOWN=4, CURSOR_LINE_START=5, CURSOR_LINE_END=6, CURSOR_PAGE_UP=7, CURSOR_PAGE_DOWN=8, SELECT_LEFT=9, SELECT_RIGHT=10, SELECT_UP=11, SELECT_DOWN=12, SELECT_LINE_START=13, SELECT_LINE_END=14, SELECT_PAGE_UP=15, SELECT_PAGE_DOWN=16, SELECT_ALL=17, BACKSPACE=18, DELETE_FORWARD=19, INSERT_TAB=20, INSERT_NEWLINE=21, INSERT_LINE_ABOVE=22, INSERT_LINE_BELOW=23, UNDO=24, REDO=25, MOVE_LINE_UP=26, MOVE_LINE_DOWN=27, COPY_LINE_UP=28, COPY_LINE_DOWN=29, DELETE_LINE=30, COPY=31, PASTE=32, CUT=33, TRIGGER_COMPLETION=34 |

---

## 13. Platform-Specific Allowances

### 13.1 Bridge Layer (MAY differ)

Each platform uses its own native bridge technology. This is expected and not constrained:

| Platform | Bridge Technology |
|---|---|
| Android | JNI (`jeditor.hpp`) |
| Swing | Java FFM (`EditorNative.java`) |
| WinForms | P/Invoke (`NativeMethods`) |
| Apple | Swift C bridge (`CBridge.swift`) |
| OHOS | NAPI (`napi_editor.hpp`) |
| Flutter | FFI (Dart) |

### 13.2 Input Method Handling (MAY differ)

IME integration is inherently platform-specific:

| Platform | IME API |
|---|---|
| Android | `InputConnection` |
| iOS | `UITextInput` |
| macOS | `NSTextInputClient` |
| Swing | `InputMethodRequests` |
| WinForms | `ImmAssociateContext` / TSF |
| OHOS | IME Kit |

### 13.3 Optional Modules

| Module | Mobile | Desktop |
|---|---|---|
| `copilot/` (InlineSuggestion) | SHOULD | SHOULD |
| `selection/` (SelectionMenu) | SHOULD | MAY omit |
| `perf/` (PerfOverlay) | SHOULD | SHOULD |

### 13.4 Rendering Details (MAY differ)

Minor visual differences are acceptable:
- Line number background rendering mode
- Scrollbar visual style and animation
- Cursor blink timing
- Selection handle shape
- Platform-native font rendering differences

---

## 14. Threading and Concurrency Model (MUST)

State-mutating editor operations and host-visible callbacks are UI-thread-affine by default. Platforms MAY expose additional thread-safe query surfaces, but MUST choose a concrete threading model and document it explicitly.

| Rule | Constraint | Description |
|---|---|---|
| State-mutating API thread | **MUST** | Public methods that mutate editor state or trigger visible UI updates MUST be called on the UI thread unless the platform explicitly documents an equivalent serialized threading model |
| API thread contract documentation | **MUST** | Platform documentation MUST explicitly identify which public APIs are UI-thread-only and which pure query / snapshot APIs, if any, are safe to call from background threads |
| Pure query API thread | **SHOULD** | Pure query / snapshot APIs SHOULD either remain UI-thread-only or be explicitly documented as background-safe; platforms MAY allow background reads only when implemented safely |
| Event callback thread | **MUST** | All event callbacks / delegate invocations / stream emissions that are visible to host code MUST execute on the UI thread |
| Provider call thread | **MUST** | Platforms MUST choose a stable invocation model for `provideDecorations()` and `provideCompletions()` (UI thread, worker thread, or another documented serialized executor) and MUST document that model for host code |
| Provider async callback thread | **MUST** | Provider result delivery may happen from any thread, but the Manager MUST switch back to the UI thread when applying results to Core or mutating host-visible editor state |
| `buildRenderModel()` | **MUST** | `buildRenderModel()` MUST observe a stable editor snapshot. Platforms MAY require UI-thread calls or provide a stronger thread-safe snapshot contract, but the returned `EditorRenderModel` SHOULD be treated as immutable and MAY be safely read on the render thread |
| `NewLineActionProvider` | **MUST** | `provideNewLineAction()` MUST complete synchronously on the input path so Enter handling does not depend on a later async callback |
| Thread safety annotations | **SHOULD** | Platforms SHOULD annotate thread constraints in public API documentation (e.g. Java `@MainThread`, Swift `@MainActor`) |
## 15. Error Handling (MUST)

Public APIs adopt defensive handling for invalid inputs without throwing exceptions; exceptions in Provider callbacks are isolated by the Manager.

### 15.1 Public API Parameter Validation

| Scenario | Constraint | Behavior |
|---|---|---|
| Line / column out of bounds | **MUST** | Automatically clamp to valid range `[0, max)`; MUST NOT throw exceptions |
| null / empty parameters | **MUST** | For MUST-non-null parameters receiving null, MUST silently ignore (no-op); MUST NOT throw exceptions or crash. Platforms MAY log a warning, especially in debug builds |
| Invalid enum values | **MUST** | Use default value (e.g. `WrapMode.NONE`); MUST NOT throw exceptions |
| Calls when widget not mounted | **SHOULD** | Getters return null or default values; imperative methods SHOULD queue or silently ignore (consistent with Section 3.0.3) |

### 15.2 Provider Exception Handling

| Rule | Constraint | Description |
|---|---|---|
| Exception capture | **SHOULD** | Platforms SHOULD isolate Provider exceptions where practical so a single Provider does not affect other Providers or crash the editor; for Providers on the synchronous input hot path (such as `NewLineActionProvider`), platforms MAY skip a uniform try-catch wrapper and use a lighter or platform-native strategy instead |
| Exception logging | **MAY** | Platforms MAY log caught exceptions; the standard does not require any specific log format or fields such as Provider class name |
| Post-exception behavior | **SHOULD** | The failing Provider's result for this cycle SHOULD be discarded; subsequent refresh cycles SHOULD continue calling the Provider (no automatic disabling) |

### 15.3 C++ Core Error Propagation

| Rule | Constraint | Description |
|---|---|---|
| Bridge layer error conversion | **MUST** | Error codes returned by C++ Core MUST be converted to platform-idiomatic error representations in the bridge layer (e.g. Java logging + no-op, Swift `Result` type); MUST NOT propagate C++ exceptions directly to upper layers |
| Memory allocation failure | **MUST** | When C++ Core memory allocation fails, the bridge layer MUST handle it safely (e.g. return an empty model); MUST NOT cause undefined behavior |

---

## 16. Lifecycle Management (MUST)

Resource creation and destruction follow explicit ordering constraints to prevent dangling references and memory leaks.

### 16.1 `EditorCore` Lifecycle

| Phase | Constraint | Rule |
|---|---|---|
| Creation | **MUST** | `EditorCore` instance MUST be created during widget initialization (imperative frameworks: constructor or init; declarative frameworks: on first widget mount) |
| Release path | **MUST** | The platform MUST ensure that `EditorCore` and its native / C++ resources are eventually released; the mechanism MAY be an explicit `dispose()` / `close()`, a host-managed lifecycle, GC / finalizer / ARC-backed automatic reclamation, an equivalent platform cleanup hook, or another platform-idiomatic mechanism. View detachment, widget unmount, or temporary removal from the view tree is NOT by itself required to be the release moment |
| Post-release calls | **MUST** | If the platform exposes an explicit release API, or otherwise keeps the object reachable after internal release, post-release calls MUST NOT access freed native / C++ resources and MUST NOT trigger further editor side effects or callbacks. Mutating calls MUST be a no-op or throw an explicit "already destroyed" exception. Getter calls MAY return `null`, default values, or last-known managed snapshots, as long as they do not require released native state or trigger lazy recomputation against destroyed resources |
| Repeated release | **MUST** | If the platform exposes explicit release logic, multiple invocations MUST be idempotent (no-op); MUST NOT cause double-free |

> The standard requires eventual native-resource release, but does **not** require every managed-language `Document` / bridge wrapper to expose an additional explicit release API beyond the platform's own lifecycle model. If a platform chooses to keep returning last-known managed snapshots after release, it SHOULD document that those values are stale snapshots rather than live editor state.

### 16.2 Provider Lifecycle

| Rule | Constraint | Description |
|---|---|---|
| Registration timing | **SHOULD** | Providers SHOULD be registered after `loadDocument()` to ensure valid document data in the Context |
| Cleanup during release | **MUST** | If the platform defines an explicit editor release / dispose / close / teardown phase, it MUST automatically unregister all registered Providers and cancel or mark stale all in-flight async requests so late results are ignored; platforms that rely solely on automatic reclamation SHOULD still ensure late async results cannot mutate freed native resources or host-visible editor state |
| Provider references | **SHOULD** | Platform implementations SHOULD avoid Providers holding strong references to the widget instance to prevent circular references causing memory leaks (Java/Kotlin: WeakReference; Swift: weak/unowned; Dart: no special handling needed) |

### 16.3 `SweetEditorController` Lifecycle (Declarative Frameworks)

| Phase | Constraint | Rule |
|---|---|---|
| Creation | **MUST** | Controller MUST be created by host code; lifecycle is managed by the host |
| Binding | **MUST** | MUST call `bind()` on widget mount and `unbind()` on widget unmount (consistent with Section 3.0.3) |
| `dispose()` ordering | **MUST** | `dispose()` MUST first unbind the widget (if still bound), then release internal resources; any method call after `dispose()` MUST be a no-op |
| Widget rebuild | **SHOULD** | In declarative frameworks, widgets may be rebuilt due to state changes; the Controller SHOULD seamlessly `bind()` to the new widget after the old one calls `unbind()`, without losing queued operations |

> This section applies only to platforms that expose an independent controller object. It MUST NOT be interpreted as requiring every imperative `View` / `Control` / `Widget` / `Document` type to add a library-defined `dispose()` / `close()` method.

### 16.4 Resource Release Order

When the platform performs editor release / dispose / close / final teardown, it MUST satisfy the following safety constraints:

- All in-flight async Provider requests MUST be cancelled or marked stale before their results can reach invalid native state
- Provider registrations MUST be cleared before they can emit further callbacks into a destroyed editor
- Host-visible event subscriptions / listeners / observers MUST be cleared before post-destruction callbacks can occur
- `EditorCore` / native resources MUST be released exactly once and only after no further platform callbacks can legally use them
- Platform-specific resources (textures, canvases, timers, etc.) MAY be released in platform-idiomatic order, as long as the constraints above are preserved

> The standard defines dependency / safety ordering here, not a single mandatory cross-platform step sequence.

---

## 17. Data Model Field Definitions (MUST)

The Core layer defines numerous decoration data types. All platforms MUST implement identical fields. This section specifies the MUST fields, construction constraints, and immutability requirements for each data type.

### 17.1 General Constraints

| Rule | Constraint | Description |
|---|---|---|
| Immutability | **SHOULD** | All Adornment data types (`StyleSpan`, `InlayHint`, etc.) SHOULD be immutable objects (Java: `final` fields, C#: `sealed record` or read-only properties, Swift: `struct` / `let`, Dart: `final` fields) |
| Construction | **MUST** | Each data type MUST provide a constructor (or equivalent factory method) that includes all MUST fields; MAY additionally provide a Builder pattern |
| Field names | **MUST** | Field names MUST follow the cross-platform naming rules in Section 2.2 |
| Coordinate basis | **MUST** | All line numbers (`line`) and column numbers (`column`) MUST be 0-based; columns are measured in UTF-16 character offsets |

### 17.2 Shared Data Types

**`TextChange`** 鈥?Incremental text change

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `range` | TextRange | **MUST** | Changed range in document coordinates |
| `text` | String | **MUST** | Replacement text; empty string means pure deletion |

### 17.3 Adornment Data Types

**`StyleSpan`** 鈥?Inline highlight range

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `column` | int | **MUST** | Start column (0-based, UTF-16 offset) |
| `length` | int | **MUST** | Character length |
| `styleId` | int | **MUST** | Style ID registered via `registerTextStyle()` |

**`TextStyle`** 鈥?Text style definition

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `color` | int | **MUST** | Foreground color (ARGB) |
| `backgroundColor` | int | **MUST** | Background color (ARGB), 0 means transparent |
| `fontStyle` | int | **MUST** | Font style bit flags: `BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4` |

**`InlayHint`** 鈥?Inline embedded hint

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `type` | InlayType | **MUST** | Type: TEXT=0, ICON=1, COLOR=2 |
| `column` | int | **MUST** | Insertion column (0-based, UTF-16 offset) |
| `text` | String? | **MUST** | Text content (MUST be non-null for TEXT type; MAY be null for other types) |
| `intValue` | int | **MUST** | Integer value (iconId for ICON type; ARGB color for COLOR type; 0 for TEXT type) |

> Platforms SHOULD provide convenience factory methods: `TextHint(column, text)`, `IconHint(column, iconId)`, `ColorHint(column, color)`.

**`PhantomText`** 鈥?Ghost text

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `column` | int | **MUST** | Insertion column (0-based, UTF-16 offset) |
| `text` | String | **MUST** | Phantom text content |

**`GutterIcon`** 鈥?Gutter area icon

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `iconId` | int | **MUST** | Icon resource ID (resolved and rendered by the platform's `EditorIconProvider`) |

**`Diagnostic`** 鈥?Diagnostic information

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `column` | int | **MUST** | Start column (0-based, UTF-16 offset) |
| `length` | int | **MUST** | Character length |
| `severity` | int | **MUST** | Severity level: ERROR=0, WARNING=1, INFO=2, HINT=3 |
| `color` | int | **MUST** | Custom color (ARGB), 0 means use severity default color |

> `Diagnostic` in this standard is a minimal diagnostic decoration model. It is intended for diagnostic rendering and lightweight interactions, not as a full IDE diagnostic object.

**`FoldRegion`** 鈥?Foldable region

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `startLine` | int | **MUST** | Fold region start line (0-based, this line remains visible) |
| `endLine` | int | **MUST** | Fold region end line (0-based, inclusive) |

**`IndentGuide`** 鈥?Indentation guide line

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `start` | TextPosition | **MUST** | Start position |
| `end` | TextPosition | **MUST** | End position |

**`BracketGuide`** 鈥?Bracket pair guide line

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `parent` | TextPosition | **MUST** | Parent bracket position |
| `end` | TextPosition | **MUST** | End bracket position |
| `children` | List\<TextPosition\> | **MUST** | Child node position list |

**`FlowGuide`** 鈥?Control flow guide line

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `start` | TextPosition | **MUST** | Start position |
| `end` | TextPosition | **MUST** | End position |

**`SeparatorGuide`** 鈥?Separator line

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `line` | int | **MUST** | Line number (0-based) |
| `style` | int | **MUST** | Style: SINGLE=0, DOUBLE=1 |
| `count` | int | **MUST** | Repeat count |
| `textEndColumn` | int | **MUST** | Text end column (used to determine separator drawing start position) |

---

## 18. Document Specification (MUST)

`Document` is the core data type of the editor, wrapping the C++ side document handle.

### 18.1 Construction Methods

All platforms MUST support at least the following two construction methods:

| Method | Constraint | Description |
|---|---|---|
| From string | **MUST** | `Document(text: String)` - create from in-memory text content |
| From file path | **SHOULD** | `Document(file: File)` / `Document(path: String)` - create from a local file; large-file loading strategy is platform-specific |

> Constructor parameter naming and types MAY vary by platform (e.g. Java `File`, C# `string path`, Swift `URL`), but semantics MUST be consistent.

### 18.2 Public Methods

| Method | Constraint | Description |
|---|---|---|
| `getLineCount()` | **MUST** | Returns the total number of lines in the document |
| `getLineText(line)` | **MUST** | Returns the text content of the specified line (excluding line ending) |
| `getText()` | **SHOULD** | Returns the complete document text |

### 18.3 Internal Implementation

| Rule | Constraint | Description |
|---|---|---|
| Native document reference | **MUST** | `Document` MUST internally retain a bridge-layer reference to a C++ side document instance; whether this is represented as an opaque handle, pointer wrapper, object wrapper, or another mechanism is an implementation detail |
| Resource release | **MUST** | When `Document` reaches its terminal platform lifecycle state, the bridge layer MUST eventually release the C++ side document memory; the exact cleanup mechanism is platform-specific, and an explicit `dispose()` / `close()` API is optional |
| Encoding model | **MUST** | Platform layers MUST NOT assume or expose a specific internal storage / layout encoding beyond the semantics guaranteed by the public APIs |
| Line endings | **MUST** | C++ Core supports LF, CR, and CRLF line endings; text returned by `getLineText()` MUST NOT include line endings |

### 18.4 Relationship with `loadDocument()`

| Rule | Constraint | Description |
|---|---|---|
| Loading timing | **MUST** | After creation, `Document` MUST be loaded into the editor via `loadDocument(doc)`; an unloaded `Document` will not trigger any rendering or events |
| Document replacement | **MUST** | Calling `loadDocument()` again replaces the current document; the old document reference is managed by host code |
| Document ownership | **SHOULD** | The same `Document` instance SHOULD NOT be loaded into multiple editor instances simultaneously |
## 19. `EditorMetadata` and `LanguageConfiguration` Field Definitions (MUST)

### 19.1 `EditorMetadata`

`EditorMetadata` is a **semantic concept type** representing host-defined metadata attached to an editor instance. The platform layer is responsible only for storing and returning it, not interpreting its internal structure.

| Rule | Constraint | Description |
|---|---|---|
| Representation form | **MUST** | Platforms MUST provide some representation capable of carrying arbitrary host-defined metadata; they MAY use a marker interface / protocol / abstract class / base class / `Object` / `any` / `unknown` / generic payload, etc. |
| Explicit type naming | **SHOULD** | If the platform chooses to expose an explicit public type, it SHOULD be named `EditorMetadata`; language-conventional variants such as `IEditorMetadata` or `SEEditorMetadata` are also allowed |
| Purpose | **MUST** | Host code stores and retrieves custom metadata (e.g. file path, language ID) via `setMetadata()` / `getMetadata()`; the platform layer MUST treat it as an opaque value and MUST NOT impose its own schema |
| Retrieval semantics | **MUST** | `getMetadata()` MUST return the same metadata value previously set, or `null` if none exists; if the platform exposes a wider carrier type (such as `Object?`), host code is responsible for its own casts / type assertions |

### 19.2 `LanguageConfiguration`

`LanguageConfiguration` describes metadata for a specific programming language.

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `languageId` | String | **MUST** | Language identifier (e.g. `"java"`, `"cpp"`, `"swift"`) |
| `brackets` | List\<BracketPair\>? | **MAY** | Bracket pair list (null = not configured; platform MUST NOT sync to Core when null) |
| `autoClosingPairs` | List\<BracketPair\>? | **MAY** | Auto-closing bracket pair list (null = not configured; platform MUST NOT sync to Core when null) |
| `tabSize` | int / int? | **MAY** | Tab stop width |
| `insertSpaces` | bool / bool? | **MAY** | Whether pressing Tab inserts spaces instead of a hard tab character |

**`BracketPair`** sub-type:

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `open` | String | **MUST** | Opening bracket (e.g. `"("`, `"{"`, `"["`) |
| `close` | String | **MUST** | Closing bracket (e.g. `")"`, `"}"`, `"]"`) |

| Rule | Constraint | Description |
|---|---|---|
| Construction | **SHOULD** | SHOULD provide Builder pattern construction (Java/Kotlin); MAY use direct constructors or named-parameter constructors (Swift/C#/Dart/ArkTS) |
| Immutability | **SHOULD** | SHOULD be immutable after construction |
| Optionality and defaults | **MUST** | Platforms MAY expose `tabSize` / `insertSpaces` as nullable or non-null fields. If nullable, `null` MAY mean "use editor default". If non-null, their default values MUST match the editor defaults |
| Runtime effect | **MUST** | When `setLanguageConfiguration()` is called, bracket matching, auto-closing behavior, and Tab insertion behavior visible to the editor MUST be updated consistently with the new configuration |
| `tabSize` semantics | **MUST** | `tabSize` and `insertSpaces` MUST be treated as independent dimensions: `tabSize` controls tab-stop width, while `insertSpaces` controls whether the Tab key inserts spaces or a hard tab character |
| `insertSpaces=true` behavior | **MUST** | If `insertSpaces` is `true`, the Tab key / `INSERT_TAB` command MUST insert the number of spaces required to reach the next tab stop, rather than always inserting a fixed `tabSize` count |
## 20. Performance Guidance & Reference Targets (SHOULD)

Based on the `perf/` module (`PerfOverlay`, `PerfStepRecorder`, `MeasurePerfStats`) and the C++ Core `PERF_TIMER` macros, this section defines cross-platform performance guidance and reference targets rather than hard conformance gates.

### 20.1 Runtime Performance Invariants

| Rule | Constraint Level | Description |
|---|---|---|
| Viewport-scoped rendering | **MUST** | Layout and painting on the platform side MUST be scoped to the visible region (plus small lookahead buffers when needed); platforms MUST NOT require full-document relayout or redraw for ordinary scrolling |
| Provider non-blocking | **MUST** | Slow decoration / completion providers MUST NOT block typing, scrolling, or painting on the host-visible interaction path |
| Stale async results | **MUST** | Outdated async provider results MUST be cancellable or discarded before they mutate visible editor state |
| Core/layout duplication | **MUST** | Platform hot paths MUST NOT redundantly recompute geometry or layout information that is already produced by Core and can be consumed directly |
| Performance diagnostics | **SHOULD** | Platforms SHOULD preserve enough timing hooks to support PerfOverlay or equivalent debug-only performance diagnostics |

### 20.2 Reference Targets

The following numbers are reference targets for release builds on representative hardware. They are optimization goals, not conformance gates.

| Metric | Constraint Level | Target | Description |
|---|---|---|---|
| Scroll frame rate | **SHOULD** | >= 60fps on reference hardware | Scrolling SHOULD maintain near-60fps for documents under 10K lines |
| `buildRenderModel()` latency | **SHOULD** | <= 8ms | Exceeding 8ms is marked as SLOW (consistent with `WARN_BUILD_MS` across platforms) |
| Single-frame draw latency | **SHOULD** | <= 8ms | Exceeding 8ms is marked as SLOW (consistent with `WARN_PAINT_MS` across platforms) |
| Single-frame total latency | **SHOULD** | <= 16.6ms | Exceeding 16.6ms is marked as SLOW FRAME |
| Single render step | **SHOULD** | <= 2ms | Exceeding 2ms is marked with `!` in PerfOverlay (consistent with `WARN_PAINT_STEP_MS`) |
| Input path latency | **SHOULD** | <= 3ms | Time from gesture/keyboard event to Core processing completion (consistent with `WARN_INPUT_MS`) |

### 20.3 Large Document Performance Guidance

| Scenario | Constraint Level | Guidance |
|---|---|---|
| 100K-line document loading | **SHOULD** | Use memory mapping, streaming load, or equivalent large-file strategies to avoid allocating all memory at once; load time target is <= 500ms on reference hardware |
| 100K-line document scrolling | **SHOULD** | Rely on viewport rendering (only layout and draw visible lines); scroll frame rate target is >= 30fps on reference hardware |
| Memory usage | **SHOULD** | Platform-layer memory usage target for a 100K-line document is <= 50MB (excluding C++ Core document storage) |

### 20.4 Provider Timeout Guidance

| Rule | Constraint Level | Description |
|---|---|---|
| `DecorationProvider` timeout | **SHOULD** | If no decoration result is delivered within 5 seconds, the Manager SHOULD cancel or mark the request stale |
| `CompletionProvider` timeout | **SHOULD** | If no completion result is delivered within 3 seconds, the Manager SHOULD cancel or mark the request stale |
| `NewLineActionProvider` latency | **MUST/SHOULD** | `provideNewLineAction()` MUST stay synchronous on the input path and SHOULD complete within a sub-millisecond to 1ms budget on reference hardware; it MUST NOT introduce user-perceptible Enter-key latency |

### 20.5 `PerfOverlay` Debug Panel (SHOULD)

| Rule | Constraint Level | Description |
|---|---|---|
| API | **SHOULD** | Each platform SHOULD provide `setPerfOverlayEnabled(bool)` / `isPerfOverlayEnabled()` APIs |
| Default state | **MUST** | PerfOverlay MUST be disabled by default; for debug use only |
| Display position | **SHOULD** | When enabled, SHOULD display a semi-transparent performance panel at the top-left of the editor area |
| Display content | **SHOULD** | SHOULD include at minimum: FPS, per-frame total/build/draw latency, text measurement statistics |
| Stability | **MUST** | PerfOverlay field names, thresholds, and step names are for debug display and MUST NOT be treated as a stable API contract |
## 21. Testing Standards (SHOULD)

### 21.1 C++ Core Tests

| Rule | Constraint Level | Description |
|---|---|---|
| Test framework | **MUST** | C++ Core uses the Catch2 framework (`tests/` directory) |
| Regression tests | **MUST** | Each core module (Document, Layout, Decoration, EditorCore) MUST have corresponding regression tests |
| Performance baselines | **SHOULD** | SHOULD use Catch2 `BENCHMARK` macros to establish performance baseline tests (e.g., `performance_baseline.cpp`) |
| Coverage scope | **SHOULD** | SHOULD cover: text editing operations, cursor/selection, undo/redo, IME composition input, decoration offset adjustment, layout mapping, scroll metrics |

### 21.2 Platform-Layer Tests

| Rule | Constraint Level | Description |
|---|---|---|
| Unit tests | **SHOULD** | Each platform SHOULD provide unit tests for Core-layer data types (e.g., `EditorSettings` default value validation, `EditorTheme` factory method validation) |
| Integration tests | **MAY** | MAY provide widget-level integration tests (e.g., create widget 鈫?load document 鈫?verify line count) |
| Test framework | **SHOULD** | Use the platform's idiomatic test framework (Android: JUnit/Espresso, Apple: XCTest, C#: xUnit/NUnit, OHOS: Hypium) |

### 21.3 Cross-Platform Consistency Verification

| Rule | Constraint Level | Description |
|---|---|---|
| API contract tests | **SHOULD** | Each platform SHOULD verify that Public API behavior is consistent with this standard document (e.g., `getWrapMode()` returns the same value after `setWrapMode()`) |
| Render model consistency | **MAY** | MAY compare `buildRenderModel()` output structure (line count, VisualRun count, etc.) across platforms for identical input |
| Event consistency | **SHOULD** | SHOULD verify that identical operations trigger the same event sequences across platforms |

---

## 22. Accessibility Standards (MAY)

Accessibility support is at the MAY level, but implementations SHOULD follow the guidance below.

### 22.1 Basic Accessibility Properties

| Rule | Constraint Level | Description |
|---|---|---|
| Role annotation | **SHOULD** | The editor widget SHOULD be annotated as a "text editor" role (Android: `AccessibilityNodeInfo.setClassName("android.widget.EditText")`, iOS: `accessibilityTraits = .updatesFrequently`, macOS: `NSAccessibilityRole.textArea`) |
| Text content | **SHOULD** | SHOULD expose currently visible text content to accessibility services |
| Cursor position | **SHOULD** | SHOULD expose current cursor position and selection range to accessibility services |
| Line information | **MAY** | MAY expose current line number and total line count to accessibility services |

### 22.2 Keyboard Navigation

| Rule | Constraint Level | Description |
|---|---|---|
| Focus management | **SHOULD** | The editor widget SHOULD be focusable and defocusable via the Tab key |
| Keyboard shortcuts | **SHOULD** | Desktop platforms SHOULD support standard keyboard shortcuts (Ctrl/Cmd+C/V/X/Z/A, etc.) |
| Screen reader compatibility | **MAY** | MAY support screen reader text narration (VoiceOver, TalkBack, Narrator) |

### 22.3 Visual Aids

| Rule | Constraint Level | Description |
|---|---|---|
| High contrast | **MAY** | MAY provide a high-contrast theme or respond to system high-contrast settings |
| Font scaling | **SHOULD** | SHOULD respond to system font scaling settings (via `setScale()` or `setEditorTextSize()`) |
| Cursor visibility | **SHOULD** | The cursor SHOULD have sufficient visual contrast, and blink frequency SHOULD be between 0.5鈥?Hz |

---

## 23. Versioning

This standard applies to SweetEditor platform implementations as of 2026-03. When the C++ core adds new enums, events, or API methods, all platforms MUST be updated to match within the same release cycle.

### 23.1 Platform Package Version Numbering

Platform package version numbers MUST maintain alignment with the C++ Core version. The version format is `a.b.c` (major.minor.patch).

| Segment | Constraint | Rule | Example (Core `1.0.0`) |
|---|---|---|---|
| `a` (major) | **MUST** | Platform package major version MUST match the Core major version and MUST NOT exceed it | Package `1.x.x` 鉁? `2.0.0` 鉂?|
| `b` (minor) | **SHOULD** | Platform package minor version SHOULD NOT exceed Core minor version `+9`; exceeding requires documented justification | Core `1.0.0` 鈫?package `1.9.x` is the recommended ceiling |
| `c` (patch) | **MAY** | Platform package patch version may increment freely for platform-specific bugfixes | `1.0.15` 鉁?|

- When Core releases a new major version (e.g. `2.0.0`), all platform packages MUST upgrade their major version within the same release cycle.
- Platform packages MAY independently release patch versions (`c` increment) while the Core version remains unchanged, for platform-specific fixes.
- The recommended ceiling on the minor version (`b`) is to prevent platform package versions from diverging too far from the Core version, which would cause version mapping confusion.

