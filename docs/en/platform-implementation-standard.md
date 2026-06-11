# Platform Implementation Standard

> This document defines the conventions and constraints that every SweetEditor platform implementation must follow.
> The goal is to keep cross-platform behavior consistent while allowing platform-specific rendering and input handling.
>
> This document describes the current repository code state (2026-06). If the document and source code are different, use the source code.
>
> Constraint levels:
> - **MUST** — all platforms must comply; violation is a bug.
> - **SHOULD** — recommended; deviation requires documented justification.
> - **MAY** — optional; platform decides based on its own needs.

---

## 1. Module Structure

Every platform implementation MUST include the following two logical layers and ensure all types within each category are implemented. File organization (directory structure, file granularity) MAY vary by language convention (e.g. Java uses package directories, C# uses one file per namespace, Swift uses Sources layering), but the logical categories MUST be identifiable and the types MUST be fully covered.

### 1.1 Core Layer (Pure Data / Models / Protocol)

The Core layer does not involve UI rendering. It contains only bridging, data models, and protocol encoding/decoding.

| Category | Required Types | Description |
|---|---|---|
| **Core Bridge** | `EditorCore`, `Document`, `CoreProtocol`, `TextMeasurer` | Native bridge + public core API wrapper |
| **Action** | `EditorActionResult`, `EditorActionSource`, `TextChangeKind`, `ScrollBehavior` | Core action result and action-related enums; `EditorActionResult` is the unified result carrier for core state-changing APIs |
| **Config** | `EditorOptions`, `HandleConfig`, `HandleHitArea`, `ScrollbarConfig`, `WrapMode`, `FoldArrowMode`, `AutoIndentMode`, `CurrentLineRenderMode`, `ScrollbarMode`, `ScrollbarTrackTapMode`, `EditorRenderColors`, `EditorRangeEffectStyles`, `RangeEffectStyle`, `RangeEffectUnderlineStyle` | Runtime, construction, and editor render styling protocol types |
| **Foundation** | `TextPosition`, `TextRange`, `TextEdit`, `IntRange`, `TextChange`, `PointF`, `Size`, `Rect` | Fundamental value types and geometry carriers |
| **Interaction** | `GestureEvent`, `GestureType`, `EventType`, `HitTarget`, `HitTargetType` | Input and hit-test protocol types |
| **IME** | `ImeSyncSnapshot`, `ImeInputContext`, `ImeOffsetRange`, `ImeScriptClass`, `ImePreeditStorage`, `ImeContextPolicy`, `ImeInputContextKind`, `ImeTextUnit`, `ImeTextModelMode`, `ImeTextReplacement`, `ImeDocumentTextReplacement`, `ImeInputContextTextReplacement`, `ImeInputStateTextReplacement`, `ImeTextModelState`, `ImeTextModelDelta` | IME synchronization snapshots, text-context protocol types, and replacement payload models; platform synchronization decisions are carried by `EditorActionResult` |
| **Adornment** | `StyleSpan`, `SpanLayer`, `InlayHint`, `InlayType`, `PhantomText`, `CodeLensItem`, `LinkSpan`, `FoldRegion`, `GutterIcon`, `Diagnostic`, `DiagnosticSeverity`, `DocumentHighlight`, `DocumentHighlightKind`, `IndentGuide`, `BracketGuide`, `FlowGuide`, `SeparatorGuide`, `SeparatorStyle`, `TextStyle` | Decoration data types |
| **Visual** | `EditorRenderModel`, `LayoutMetrics`, `VisualLine`, `VisualLineKind`, `VisualRun`, `VisualRunType`, `PointerCursorType`, `Cursor`, `CursorRect`, `SelectionHandle`, `ScrollMetrics`, `ScrollbarModel`, `GuideSegment`, `GuideType`, `GuideDirection`, `GuideStyle`, `RangeEffectKind`, `RangeEffectRenderItem`, `FoldMarkerRenderItem`, `FoldState`, `GutterIconRenderItem` | Render model types (geometry semantics follow Sections 2.5 and 2.6) |
| **Snippet** | `LinkedEditingModel`, `TabStopGroup` | Linked editing / tab stop groups |
| **Keymap** | `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, `EditorBuiltinCommand` | Shortcut binding data types and built-in command identifiers |

Core protocol types and `CoreProtocol` codecs MUST be generated from the C++ `SE_PROTOCOL_*` annotations through `tools/se_protocol_gen`. Platform code MAY add generated-code augmentation or thin host-language helpers, but MUST NOT maintain independent `ProtocolEncoder` / `ProtocolDecoder` implementations or a platform-defined binary schema. Augmentation MUST NOT change encoded field order, scalar width, nullability, list/map layout, enum values, or payload names.

### 1.2 Widget Layer (UI Controls / Rendering / Interaction)

The Widget layer handles platform-native rendering, user interaction, and extension systems.

| Category | Required Types | Description |
|---|---|---|
| **Widget** | `SweetEditor`, `SweetEditorController` *(declarative frameworks MUST; imperative frameworks MAY)*, `EditorTheme`, `EditorSettings`, `EditorIconProvider`, `EditorMetadata`, `LanguageConfiguration` | Widget entry, controller, theme, configuration |
| **Decoration** | `DecorationProvider`, `DecorationProviderManager`, `DecorationContext`, `DecorationResult`, `DecorationType`; if the Receiver callback pattern is used, `DecorationReceiver` is the recommended name | Decoration provider system |
| **Completion** | `CompletionProvider`, `CompletionProviderManager`, `CompletionContext`, `CompletionItem`, `CompletionResult`; if the Receiver callback pattern is used, `CompletionReceiver` is the recommended name | Completion provider system |
| **Event** | A type-safe event mechanism, `EditorEvent`, `TextChangedEvent`, `CursorChangedEvent`, `SelectionChangedEvent`, `ScrollChangedEvent`, `ScaleChangedEvent`, `DocumentLoadedEvent`, `FoldToggleEvent`, `GutterIconClickEvent`, `InlayHintClickEvent`, `CodeLensClickEvent`, `LinkClickEvent`, `LongPressEvent`*(mobile / touch platforms)*, `DoubleTapEvent`, `ContextMenuEvent`*(platforms with an explicit context-menu gesture entry point)*; if an explicit event-bus/listener pattern is used, `EditorEventBus` and `EditorEventListener` are the recommended names | Event system |
| **NewLine** | `NewLineActionProvider`, `NewLineActionProviderManager`, `NewLineAction`, `NewLineContext` | Newline action provider system |
| **Keymap** | `EditorKeyMap` | Widget-layer keymap extension that binds command ids to host-side handlers |
| **Copilot** *(SHOULD)* | `InlineSuggestion`, `InlineSuggestionListener` or an equivalent host-visible accept/dismiss callback mechanism | Inline suggestion data + callback; listener shape is the primary path when exposed |
| **Selection** *(SHOULD on mobile; desktop MAY omit)* | `SelectionMenuItem`, `SelectionMenuItemProvider`, a host-visible custom-item click callback mechanism; MAY: `SelectionMenuListener` | Selection menu (mobile SHOULD; desktop MAY omit) |
| **ContextMenu** *(SHOULD on desktop / mouse / right-click platforms; MAY on touch-only platforms)* | `ContextMenuRequest`, `ContextMenuSection`, `ContextMenuItem`, `ContextMenuItemProvider`, `ContextMenuTriggerKind`, a host-visible custom-item click callback mechanism; MAY: `ContextMenuPopup` | Platform-side context menu / action menu |
| **Perf** *(MAY)* | Debug performance overlay controls, such as `setPerfOverlayEnabled` / `isPerfOverlayEnabled` or platform-equivalent APIs | Debug performance overlay |

> `TextChangedEvent` MUST expose `changes: List<TextChange>`, `kind: TextChangeKind`, and `source: EditorActionSource`. Platforms MUST NOT define a separate text-change action enum that mirrors `TextChangeKind`.

### 1.3 Internal Implementation Freedom (SHOULD)

Internal renderers, popup controllers, overlay controllers, and similar objects are implementation details, not public API contract. Platforms MAY organize these objects according to their UI framework conventions; as long as sections 1.1, 1.2, and the later public contracts are satisfied, not using a specific internal controller / renderer name is not a violation.

---

## 2. Naming Conventions

### 2.1 Class / Type Names (MUST)

All platforms MUST use the following canonical names for the principal public types listed below. Additional host-facing public types introduced in later sections MUST follow the same naming rules and use the canonical names defined where those types are introduced. Language-specific prefixes or suffixes are allowed only where mandated by the language convention (e.g. C# interface `I` prefix).

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
| `TextMeasurer` | OC: `SETextMeasurer` | May appear in any platform-idiomatic form, including a top-level public type, nested type, internal bridge type, typealias, adapter, or C# struct, as long as the concept remains semantically aligned with the standard |
| `EditorTheme` | OC: `SEEditorTheme` | Theme definition |
| `EditorSettings` | OC: `SEEditorSettings` | Configuration |
| `DecorationProvider` | C#/TS/Kotlin: `IDecorationProvider`; OC: `SEDecorationProvider` | Provider interface |
| `CompletionProvider` | C#/TS/Kotlin: `ICompletionProvider`; OC: `SECompletionProvider` | Provider interface |
| `DecorationReceiver` | C#/TS/Kotlin: `IDecorationReceiver`; OC: `SEDecorationReceiver` | Callback interface; only applicable when the platform exposes an explicit Receiver type |
| `CompletionReceiver` | C#/TS/Kotlin: `ICompletionReceiver`; OC: `SECompletionReceiver` | Callback interface; only applicable when the platform exposes an explicit Receiver type |
| `NewLineActionProvider` | C#/TS/Kotlin: `INewLineActionProvider`; OC: `SENewLineActionProvider` | Provider interface |
| `EditorKeyMap` | OC: `SEEditorKeyMap` | Widget-layer keymap extension |
| `EditorBuiltinCommand` | OC: `SEEditorBuiltinCommand` | Built-in command ids |
| `KeyBinding` | OC: `SEKeyBinding` | One- or two-chord binding entry |
| `KeyChord` | OC: `SEKeyChord` | Single key-chord value type |
| `KeyCode` | OC: `SEKeyCode` | Keyboard key code constants / enum |
| `KeyModifier` | OC: `SEKeyModifier` | Keyboard modifier flags / enum |
| `EditorMetadata` | C#/TS/Kotlin: `IEditorMetadata`; OC: `SEEditorMetadata` | Metadata concept type; only applicable when the platform exposes an explicit public type |
| `EditorEventListener` | C#/TS/Kotlin: `IEditorEventListener`; OC: `SEEditorEventListener` | Listener interface; applies only when the platform exposes an explicit listener-interface pattern |
| `InlineSuggestionListener` | C#/TS/Kotlin: `IInlineSuggestionListener`; OC: `SEInlineSuggestionListener` | Listener interface; only applicable when the platform exposes an explicit inline-suggestion listener |
| `SelectionMenuItem` | OC: `SESelectionMenuItem` | Selection menu item data type |
| `SelectionMenuItemProvider` | C#/TS/Kotlin: `ISelectionMenuItemProvider`; OC: `SESelectionMenuItemProvider` | Selection menu item provider; builds the full menu from the current editor state |
| `SelectionMenuListener` | C#/TS/Kotlin: `ISelectionMenuListener`; OC: `SESelectionMenuListener` | Listener interface; only applicable when the platform exposes an explicit selection-menu listener |
| `ContextMenuItem` | OC: `SEContextMenuItem` | Context menu item data type |
| `ContextMenuSection` | OC: `SEContextMenuSection` | One visual section inside the context menu |
| `ContextMenuRequest` | OC: `SEContextMenuRequest` | Immutable request snapshot used to build a context menu |
| `ContextMenuItemProvider` | C#/TS/Kotlin: `IContextMenuItemProvider`; OC: `SEContextMenuItemProvider` | Context menu item provider; builds the full menu from the current context-menu request |
| `ContextMenuTriggerKind` | OC: `SEContextMenuTriggerKind` | Trigger kind for opening the context menu |
| `EditorIconProvider` | C#/TS/Kotlin: `IEditorIconProvider`; OC: `SEEditorIconProvider` | Icon provider interface |
| `SweetEditorController` | OC: `SESweetEditorController` | External control entry for declarative frameworks (see Section 3.0) |
| `IntRange` | OC: `SEIntRange` | Inclusive integer range value type |

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

### 2.4 Host-Facing Public API Enum Types (MUST)

For host-facing public APIs (such as `SweetEditor`, `SweetEditorController`, `EditorSettings`, event payloads, and provider / context / result types consumed directly by host code), platforms MUST use enums or equivalent strong types for discrete value sets when the target language supports them.

- Host-facing public APIs MUST NOT prefer raw `int` values when the language already supports enums / strong typed constants
- If platform or framework constraints force a host-facing public API to expose integer constants, that layer MUST handle invalid values explicitly (see Section 15)
- Bitmask / flags fields MAY remain `int`-encoded in the public model when that representation is itself the intended cross-platform contract (for example `TextStyle.fontStyle`)
- Compact numeric semantic fields MAY remain `int`-encoded in the public model when this standard explicitly defines that numeric encoding as part of the contract (for example `Diagnostic.severity`)
- `EditorCore`, bridge layers, FFI layers, and other internal numeric transport layers are not considered host-facing public APIs for this rule

### 2.5 Geometry Carrier Types (MUST)

For simple geometry carriers used in public APIs and event payloads, platforms MAY use either the canonical SweetEditor geometry names or platform-native equivalents when the semantics are identical.

- Point types: `PointF` or a platform-native point type (e.g. Android `android.graphics.PointF`, Apple `CGPoint`)
- Rect types: `Rect` or a platform-native rect type (e.g. Android `android.graphics.RectF`, Apple `CGRect`)

If a platform-native geometry type is used, coordinate basis, axis direction, and field semantics MUST remain identical to the canonical SweetEditor model.

### 2.6 Range Effect Rendering Semantics (MUST)

`RangeEffectRenderItem` is the platform-rendered channel for visible range presentations such as selection, search, document highlights, IME composition, diagnostics, linked editing, and bracket matches.

- Platforms MUST treat `RangeEffectRenderItem.rect` as final screen-space geometry. Core has already split effects for wrapping, viewport visibility, folded-tail projection, and layout-specific cases.
- Platforms MUST NOT recompute range effect geometry from document text ranges.
- Platforms MUST draw `RangeEffectStyle.backgroundColor` before text runs.
- Platforms MUST draw `RangeEffectStyle.borderColor` and `RangeEffectStyle.underlineColor` after text runs and guide segments, and before the cursor.
- Platforms MUST NOT draw `RangeEffectStyle.foregroundColor` from `RangeEffectRenderItem`. Foreground effects are applied by core through `VisualRun.style` after run splitting.
- Platforms MAY use `RangeEffectKind` for small visual differences, such as a thicker active linked-editing border. Platforms MUST NOT infer editor state, event behavior, or provider behavior from `RangeEffectKind`.
- Platforms SHOULD keep underline presentation close to core renderer conventions: underline baseline near `rect.bottom - 1`, solid and dashed strokes around 2 px, wavy strokes around 3 px, dashed pattern around 3 px on / 2 px off, and wavy half-period / amplitude around 7 px / 3.5 px.

---

## 3. Public API Contract (MUST)

The following defines two distinct public API layers:
- Section 3.1 defines the `EditorCore` bridge/runtime API
- Section 3.2 defines the host-facing editor API

Platforms MUST implement every listed method on the appropriate API carrier unless a later section assigns a weaker requirement level to that method. Section 3.1 methods belong to `EditorCore`; they are not implicitly part of the host-facing editor surface. In imperative frameworks the Section 3.2 carrier is the widget entry class itself (for example `SweetEditor`), while in declarative frameworks the Section 3.2 carrier is `SweetEditorController`. On declarative platforms, `SweetEditor` remains the runtime/session owner even though the host-facing API is exposed through the controller.

> Lifecycle / memory management APIs (e.g. `create`, `destroy`, platform wrapper names for `free_binary_data`) are not listed here; each platform implements them per its own conventions. Native binary payloads currently use the C ABI shape `const uint8_t* + out_size`; every platform wrapper MUST release owned native result buffers after decoding.

**General naming variant rules:**
- Canonical names use Java/ArkTS camelCase as the baseline
- PascalCase languages (e.g. C#, Go): all method names use PascalCase (e.g. `setDocument` → `SetDocument`); this rule applies to all methods and is not repeated per row
- Each language MAY adapt parameter naming and calling style per its own conventions (e.g. Swift argument labels, Go export rules, Dart named parameters)
- The "Allowed Variants" column below only lists variants with **substantive differences** from the canonical name (e.g. getter as property, different method name semantics); `—` means no substantive difference

### 3.0 API Carrier Rules (MUST)

Editor components contain many imperative operations. Different UI paradigms use different API carriers, but runtime ownership must remain consistent.

| Rule | Constraint | Description |
|---|---|---|
| Imperative frameworks | **MUST** | The APIs in Section 3.2, plus host APIs from implemented optional modules, MUST be exposed directly on the widget entry class (for example `SweetEditor`, `SweetEditorView`, `SweetEditorControl`). Platforms MAY additionally provide `SweetEditorController` |
| Declarative frameworks | **MUST** | MUST provide `SweetEditorController` as the sole host-held imperative entry point; the widget entry class MUST accept `controller` as a constructor parameter. `SweetEditor` remains the runtime/session owner; the controller only forwards calls and MUST NOT own the view, runtime, `EditorCore`, provider registrations, or session-scoped state |
| Controller binding | **MUST** | The controller-to-editor association MUST be established when the editor instance is constructed and remain fixed. The same Controller MUST NOT be bound to multiple widgets simultaneously, and MUST NOT be rebound to another widget/session/editor instance after initial association. Internal `bind` / `unbind` only mean initial attach and terminal detach; ordinary declarative rebuilds preserving the same mounted runtime are not rebinding |
| Public API coverage | **MUST** | Declarative Controller MUST expose all required host APIs in Section 3.2 and all host APIs for implemented optional modules. Section 3.1 `EditorCore` methods are bridge/runtime APIs and are not Controller requirements by default |
| Ready gate | **MUST** | Controller MUST provide `whenReady(callback)` or an equivalent ready mechanism. Before initial attach, mutating calls MUST be ignored or rejected rather than queued; getters SHOULD return `null` or defaults and MUST NOT throw; platforms MUST NOT create hidden runtime or hidden staging layers for pre-ready calls |
| Declarative initialization inputs | **MAY / MUST** | Declarative platforms MAY expose `document`, `text`, `theme`, `settings`, `keyMap`, and similar initialization inputs. If exposed, they MUST be construction/configuration inputs rather than pre-ready controller calls. `document` wins over `text`; text-only initialization MUST materialize an equivalent `Document`, and `getDocument()` MUST return it after ready |
| Explicit teardown | **MAY / MUST** | Platforms MAY provide terminal controller teardown such as `dispose()`, `close()`, or `release()`. If provided, it MUST release only controller-owned readiness callbacks, pending callbacks, and reference chains; it MUST NOT assume ownership of session provider registrations or runtime objects. After teardown, later calls MUST be no-ops or return default empty values |

---

### 3.1 `EditorCore` Public API

Section 3.1 defines the bridge/runtime API carried by `EditorCore`. It includes low-level render snapshot, gesture loop, keyboard dispatch, and animation tick methods. These methods are not part of the default host-facing editor surface unless a platform explicitly chooses to expose `EditorCore` itself.

All state-changing `EditorCore` APIs, including configuration writes, gestures, keyboard input, text edits, IME writes, cursor/selection writes, scrolling/navigation, decoration, folding, linked editing, and animation ticks, MUST return `EditorActionResult` or a platform-language equivalent. Query APIs keep their own semantic return values; `buildRenderModel()` is a render snapshot query and does not return `EditorActionResult`. Platform layers MUST pass every non-null `EditorActionResult` to one unified result dispatcher, and MUST NOT infer whether to emit text events, synchronize IME state, run animation, flush, or repaint from the invoked method name, setter category, or local side-effect assumptions.

During construction or first-frame bootstrap before the editor runtime / dispatcher exists, platforms MAY coalesce setup `EditorActionResult` values and perform equivalent state dispatch, IME synchronization, and refresh after the dispatcher is ready. This exception only applies to the initialization window where no dispatcher exists; every non-null `EditorActionResult` produced after runtime readiness MUST be processed through the unified dispatcher.

| Capability | Required `EditorCore` APIs |
|---|---|
| Configuration | `loadDocument(doc)`, `setViewport(w, h)`, `onFontMetricsChanged()`, `setFoldArrowMode(mode)`, `setWrapMode(mode)`, `setRenderWhitespace(mode)`, `setRenderLineBreaks(enabled)`, `setTabSize(size)`, `setInsertSpaces(enabled)`, `setScale(scale)`, `setLineSpacing(add, mult)`, `setContentStartPadding(padding)`, `setShowSplitLine(show)`, `setCurrentLineRenderMode(mode)`, `setGutterSticky(sticky)`, `setGutterVisible(visible)`, `setHandleConfig(...)`, `setScrollbarConfig(...)` |
| Render model | `buildRenderModel()`, `getLayoutMetrics()` |
| Gesture / keyboard | `handleGestureEvent(...)`, `tickAnimations()`, `handleKeyEvent(...)`, `setKeyMap(bindings)` |
| Text editing | `insertText(text)`, `replaceText(range, text)`, `deleteText(range)`, `applyTextEdits(edits)`, `backspace()`, `deleteForward()`, `moveLineUp()`, `moveLineDown()`, `copyLineUp()`, `copyLineDown()`, `deleteLine()`, `insertLineAbove()`, `insertLineBelow()` |
| Undo / redo | `undo()`, `redo()`, `canUndo()`, `canRedo()` |
| Cursor / selection | `setCursorPosition(line, col)`, `getCursorPosition()`, `selectAll()`, `setSelection(sL, sC, eL, eC)`, `getSelection()`, `getSelectedText()`, `getWordRangeAtCursor()`, `getWordAtCursor()`, `moveCursorLeft(extend)`, `moveCursorRight(extend)`, `moveCursorUp(extend)`, `moveCursorDown(extend)`, `moveCursorToLineStart(extend)`, `moveCursorToLineEnd(extend)` |
| IME | `getImeSyncSnapshot()`, `getImeInputContext(...)`, `getImeTextModelInputContext(...)`, `setImeKeyboardScriptClass(script)`, `getImeKeyboardScriptClass()`, `updateImePreedit(...)`, `setImeComposingText(...)`, `setImeComposingTextSelection(...)`, `commitImeText(...)`, `commitImeTextWithCursor(...)`, `replaceImeText(replacement)`, `replaceImeDocumentText(replacement)`, `replaceImeInputContextText(replacement)`, `finishImePreedit()`, `cancelImePreedit()`, `markImeDocumentRange(...)`, `markImeDocumentRangeByOffset(...)`, `markImeInputContextRange(...)`, `notifyImeDocumentSelectionChanged(...)`, `notifyImeInputContextSelectionChanged(...)`, `updateImeTextModelState(state)`, `updateImeTextModelDelta(delta)`, `updateImeInputStateSelection(...)`, `replaceImeInputStateText(replacement)`, `deleteImeBackward(length, unit)`, `deleteImeForward(length, unit)`, `deleteImeSurrounding(before, after, unit)`, `notifyImeSelectionChanged(range)`, `notifyImeCursorChanged(cursor)`, `getComposingRange()`, `getComposingSessionRange()`, `isComposing()` |
| Read-only / indent | `setReadOnly(readOnly)`, `isReadOnly()`, `setAutoIndentMode(mode)`, `getAutoIndentMode()`, `setBackspaceUnindent(enabled)` |
| Navigation / scroll | `scrollToLine(line, behavior)`, `gotoPosition(line, col)`, `ensureCursorVisible()`, `setScroll(x, y)`, `getScrollMetrics()`, `getPositionRect(line, col)`, `getCursorRect()` |
| Style / highlight | `registerTextStyle(id, color, bg, fontStyle)`, `registerBatchTextStyles(data)`, `setLineSpans(line, layer, spans)`, `setBatchLineSpans(layer, entries)`, `clearLineSpans(line, layer)`, `clearHighlights(layer)`, `clearHighlights()`, `setEditorRenderColors(colors)`, `setEditorRangeEffectStyles(styles)` |
| Inlay Hint | `setLineInlayHints(line, hints)`, `setBatchLineInlayHints(entries)`, `clearInlayHints()` |
| Phantom Text | `setLinePhantomTexts(line, phantoms)`, `setBatchLinePhantomTexts(entries)`, `clearPhantomTexts()` |
| Gutter Icon | `setLineGutterIcons(line, icons)`, `setBatchLineGutterIcons(entries)`, `setMaxGutterIcons(count)`, `clearGutterIcons()` |
| CodeLens | `setLineCodeLens(line, items)`, `setBatchLineCodeLens(entries)`, `clearCodeLens()` |
| Link | `setLineLinks(line, links)`, `setBatchLineLinks(entries)`, `clearLinks()` |
| Diagnostic | `setLineDiagnostics(line, items)`, `setBatchLineDiagnostics(entries)`, `clearDiagnostics()` |
| Document Highlight | `setLineDocumentHighlights(line, items)`, `setBatchLineDocumentHighlights(entries)`, `clearDocumentHighlights()` |
| Guide | `setIndentGuides(guides)`, `setBracketGuides(guides)`, `setFlowGuides(guides)`, `setSeparatorGuides(guides)`, `clearGuides()` |
| Bracket | `setBracketPairs(open, close)`, `setAutoClosingPairs(open, close)`, `setMatchedBrackets(oL, oC, cL, cC)`, `clearMatchedBrackets()` |
| Folding | `setFoldRegions(regions)`, `toggleFoldAt(line)`, `foldAt(line)`, `unfoldAt(line)`, `foldAll()`, `unfoldAll()`, `isLineVisible(line)` |
| Search | `search(request)`, `findNextSearchMatch()`, `findPreviousSearchMatch()`, `replaceCurrentSearchMatch(replacement)`, `replaceAllSearchMatches(replacement)`, `clearSearch()`, `getSearchState()` |
| Clear | `clearAllDecorations()` |
| Linked Editing | `insertSnippet(template)`, `startLinkedEditing(model)`, `isInLinkedEditing()`, `linkedEditingNext()`, `linkedEditingPrev()`, `cancelLinkedEditing()` |

IME APIs are the request entrypoints through which platform input events enter core. The platform standard constrains semantic capability families, not the complete bridge function list that each platform must call. Platform layers MUST NOT create editor composition just because the system IME requests surrounding text, candidate context, or cursor rectangles. Composition is created only when the system IME explicitly declares composing / marked / preedit text or range; commits, replacements, deletion, and selection synchronization are still adjudicated by core according to `docs/zh/ime-composition-standard.md`.

When a platform marks a composition range in core, it MUST be an explicit composing / marked range reported by the platform IME. Android `InputConnection.setComposingRegion`, Apple marked ranges, and Windows TSF composition ranges MUST NOT be treated as whole-word replacement commands by the platform layer. Neither platform code nor core may automatically start whole-word composition when the cursor enters a Latin word.

Platform layers MUST synchronize cursor changes, selection changes, composition updates, candidate commits, deletion, finish/cancel, and equivalent text-model state changes into core. When a Chinese keyboard does not declare composition, that only means SweetEditor has no visible composition; it MUST NOT be implemented by disabling the system IME, blocking Chinese candidate commits, or blocking Chinese predictive candidates.

IME offsets MUST state their coordinate space explicitly: document line/column APIs use `TextRange`; document-offset APIs use full document offsets; input-context / text-model APIs use context offsets relative to `documentStartOffset`. Platform implementations MUST NOT implicitly mix these coordinate spaces.

> Payload-level APIs (e.g. `setLineSpans`, `setBatchLineSpans`) — all platforms MUST provide high-level typed wrappers (e.g. `setLineSpans(line, layer, spans: List<StyleSpan>)`). Platforms SHOULD additionally expose raw/binary payload APIs when the host language has a natural public binary carrier (e.g. `ByteBuffer`, `MemorySegment`, `NSData`, `byte[]`, `Uint8List`, `ArrayBuffer`). Typed wrappers and raw/binary payload APIs MUST use the generated `CoreProtocol` encoding and produce identical Core behavior.

#### 3.1.1 IME API Requirement Levels

`EditorCore` IME APIs are bridge/runtime APIs. They standardize platform input adaptation and testability; they are not required to be exposed on the host-facing `SweetEditor` / controller API, and a platform is not required to call the complete function set. Conditional MUST means a platform is not required to synthesize a native IME capability it does not receive, but if that capability exists it MUST map to the corresponding core semantic capability family.

| API / Type | Requirement | Notes |
|---|---|---|
| IME protocol types | MUST | Include the generated `CoreProtocol` IME model set: `ImeSyncSnapshot`, `ImeInputContext`, `ImeOffsetRange`, `ImeScriptClass`, `ImePreeditStorage`, `ImeContextPolicy`, `ImeInputContextKind`, `ImeTextUnit`, `ImeTextModelMode`, `ImeTextReplacement`, `ImeDocumentTextReplacement`, `ImeInputContextTextReplacement`, `ImeInputStateTextReplacement`, `ImeTextModelState`, and `ImeTextModelDelta` |
| `ImeTextUnit` | MUST | Stable values are `GRAPHEME = 0` and `CODE_POINT = 1`; platform APIs MAY expose unit-aware deletion overloads according to native adapter needs |
| Synchronization snapshot capability | MUST | Platform input adapters MUST process `EditorActionResult.needsImeSync` and `EditorActionResult.imeSync`; use `getImeSyncSnapshot()` or an equivalent bridge entrypoint when an explicit query is needed |
| Keyboard script hint capability | SHOULD / conditional MUST | SHOULD track keyboard script hints; MUST map platform-provided script hints when they are available |
| Preedit / composing capability | SHOULD / conditional MUST | Native preedit, composing text, or marked text MUST map to core's preedit / composing semantic family |
| Commit / replacement capability | MUST / conditional MUST | Native commits MUST map to core; explicit replacement ranges MUST map to the corresponding document, input-context, or text-model replacement semantic family |
| Document range / offset capability | conditional MUST | Native document ranges or document offsets MUST use document coordinate semantics and MUST NOT be mixed with input-context offsets |
| Input-context capability | conditional MUST | Platforms that operate on surrounding text / extracted text windows MUST use context offsets relative to `documentStartOffset` |
| Text-model state / delta capability | conditional MUST | Platforms whose native API exposes a complete text model snapshot or delta SHOULD use the text-model semantic family rather than forcing the flow into legacy preedit / commit actions |
| Deletion capability | SHOULD / conditional MUST | Native backward, forward, or surrounding deletion requests MUST map to core deletion semantics |
| Selection / cursor synchronization capability | SHOULD / conditional MUST | IME-driven selection, cursor, or text-model selection synchronization MUST map to core |
| `isComposing()` | MUST | Reports whether editor-visible composition is active |
| `getComposingRange()` | SHOULD | Useful for platform synchronization and diagnostics; returns no range when inactive |
| `getComposingSessionRange()` | SHOULD | Useful for platform synchronization and diagnostics; returns no range when inactive |

`ImeSyncSnapshot` semantics MUST cover: document cursor, document selection, whether a composition session exists, visible composition range, platform marked range, `ImePreeditStorage`, `ImeContextPolicy`, and whether the platform should clear preedit. `ImeInputContext` semantics MUST cover: `id`, `revision`, `documentStartOffset`, `text`, `selection`, `hasComposition`, `composition`, and `kind`; `text`, `documentStartOffset`, `selection`, and `composition` carry the platform text window and its selection / composing offset semantics. `ImeActionResult` is not a platform protocol type; if the core implementation keeps this structure internally, its contents MUST be folded into `EditorActionResult` when crossing the bridge and exposed through `needsImeSync` / `imeSync`.

The complete core bridge function list is defined by `include/sweeteditor/editor_core.h` and `include/sweeteditor/c_api.h`. This standard constrains IME semantics and protocol fields, not whether every core bridge function is exposed as a host-facing API.

#### 3.1.2 `EditorOptions` Standard Fields

`EditorOptions` is a bridge-layer configuration payload. Platforms MAY expose it as a public type or keep it internal, but if it crosses the bridge boundary or is serialized into a binary payload, the following field semantics and ordering MUST remain aligned with Core:

| Field | Type | Default | Description |
|---|---|---|---|
| `touchSlop` | float | `10` | Gesture move threshold below which the interaction is still treated as a tap |
| `doubleTapTimeout` | int64 | `300` | Double-tap recognition timeout in milliseconds |
| `longPressMs` | int64 | `500` | Long-press recognition timeout in milliseconds |
| `flingFriction` | float | platform-defined | Fling friction coefficient; platforms MAY tune this to match native interaction feel |
| `flingMinVelocity` | float | platform-defined | Minimum fling velocity in px/s; platforms MAY tune this to match native interaction feel |
| `flingMaxVelocity` | float | platform-defined | Maximum fling velocity in px/s; platforms MAY tune this to match native interaction feel |
| `maxUndoStackSize` | uint64 / size_t-aligned integer | `512` | Maximum undo stack depth; `0` means unlimited |
| `keyChordTimeoutMs` | int64 | `2000` | Timeout for completing a pending multi-chord key binding |
| `revealSelectionEndOnSelectAll` | boolean | `false` | When true, `selectAll()` SHOULD reveal the selection end after updating the selection |

> If a platform serializes `EditorOptions` into a binary bridge payload, field order MUST stay aligned with Core: `touch_slop`, `double_tap_timeout`, `long_press_ms`, `fling_friction`, `fling_min_velocity`, `fling_max_velocity`, `max_undo_stack_size`, `key_chord_timeout_ms`, `reveal_selection_end_on_select_all`.

### 3.2 Host-Facing Editor Public API

Section 3.2 defines the host-facing editor API. It intentionally excludes low-level `EditorCore` gesture-loop, animation-tick, and render-model production methods. Host-facing state-changing APIs may return `void`, `EditorActionResult`, or a platform-equivalent result according to platform conventions; whenever the underlying call produces a non-null `EditorActionResult`, the platform runtime MUST process it through the unified result dispatcher. `flush()` is no longer a required standard host-facing API. Platforms MAY keep it as a force-refresh, diagnostic, or compatibility API, but normal refresh/redraw decisions MUST come from `EditorActionResult.needsRedraw`. API carriers follow Section 3.0.

Except for items marked SHOULD / MAY, every host API listed below is MUST. Languages MAY use properties, delegate setters, typed streams, or platform-idiomatic equivalent entrypoints when the mapping remains clear and unambiguous.

| Capability | Host-facing API |
|---|---|
| Document / theme | `loadDocument(doc)`, `getDocument()`, `applyTheme(theme)`, `getTheme()` |
| Configuration | `getSettings()`, `getKeyMap()` *(SHOULD)*, `setKeyMap(keyMap)`, `setEditorIconProvider(provider)` |
| Text editing | `insertText(text)`, `insertTextAt(position, text)`, `replaceText(range, text)`, `deleteText(range)`, `applyTextEdits(edits)`, `moveLineUp()`, `moveLineDown()`, `copyLineUp()`, `copyLineDown()`, `deleteLine()`, `insertLineAbove()`, `insertLineBelow()` |
| Undo / redo | `undo()`, `redo()`, `canUndo()`, `canRedo()` |
| Clipboard *(MAY)* | `copyToClipboard()`, `pasteFromClipboard()`, `cutToClipboard()` |
| Cursor / selection | `selectAll()`, `getSelectedText()`, `setSelection(sL, sC, eL, eC)`, `getSelection()`, `setCursorPosition(pos)`, `getCursorPosition()`, `getWordRangeAtCursor()`, `getWordAtCursor()` |
| Navigation / scroll | `gotoPosition(line, col)`, `scrollToLine(line, behavior)`, `setScroll(x, y)`, `getScrollMetrics()`, `getPositionRect(line, col)`, `getCursorRect()` |
| Folding | `toggleFold(line)`, `foldAt(line)`, `unfoldAt(line)`, `isLineVisible(line)`, `foldAll()`, `unfoldAll()` |
| Search | `search(request)`, `findNextSearchMatch()`, `findPreviousSearchMatch()`, `replaceCurrentSearchMatch(replacement)`, `replaceAllSearchMatches(replacement)`, `clearSearch()`, `getSearchState()` |
| Language / metadata | `setLanguageConfiguration(config)`, `getLanguageConfiguration()`, `setMetadata(metadata)`, `getMetadata()` |
| Provider management | `addDecorationProvider(provider)`, `removeDecorationProvider(provider)`, `requestDecorationRefresh()`, `addCompletionProvider(provider)`, `removeCompletionProvider(provider)`, `addNewLineActionProvider(provider)`, `removeNewLineActionProvider(provider)` |
| Completion | `triggerCompletion()`, `showCompletionItems(items)`, `dismissCompletion()`, `setCompletionItemRenderer(renderer)` or a platform-equivalent completion item rendering customization API |
| Style | `registerTextStyle(id, ...)`, `registerBatchTextStyles(stylesById)` |
| Decoration / adornment write | `setLineSpans(line, layer, spans)`, `setBatchLineSpans(layer, spansByLine)`, `setLineInlayHints(line, hints)`, `setBatchLineInlayHints(hintsByLine)`, `setLinePhantomTexts(line, phantoms)`, `setBatchLinePhantomTexts(phantomsByLine)`, `setLineGutterIcons(line, icons)`, `setBatchLineGutterIcons(iconsByLine)`, `setLineCodeLens(line, items)`, `setBatchLineCodeLens(itemsByLine)`, `setLineLinks(line, links)`, `setBatchLineLinks(linksByLine)`, `setLineDiagnostics(line, items)`, `setBatchLineDiagnostics(diagsByLine)`, `setLineDocumentHighlights(line, items)`, `setBatchLineDocumentHighlights(itemsByLine)`, `setIndentGuides(guides)`, `setBracketGuides(guides)`, `setFlowGuides(guides)`, `setSeparatorGuides(guides)`, `setFoldRegions(regions)` |
| Decoration / adornment clear | `clearHighlights()`, `clearHighlights(layer)`, `clearInlayHints()`, `clearPhantomTexts()`, `clearGutterIcons()`, `clearCodeLens()`, `clearLinks()`, `clearGuides()`, `clearDiagnostics()`, `clearDocumentHighlights()`, `clearAllDecorations()` |
| Query | `getVisibleLineRange()`, `getTotalLineCount()`, `getLinkTargetAt(line, column)`; link misses return an empty string or equivalent non-null empty value |

> The canonical naming for provider management methods is `add` / `remove`. Each platform MAY use semantically equivalent variants per its own conventions (e.g. `attach` / `detach`, `register` / `unregister`).

> Clipboard methods (`copyToClipboard`, `pasteFromClipboard`, `cutToClipboard`) are **MAY** because clipboard access is platform-specific.

> Event exposure does not require a uniform method shape. Platforms MUST provide a type-safe event mechanism per Section 11, and may use `subscribe` / `unsubscribe`, platform-native `event` / delegates, typed `Stream` getters, signals / observers, or equivalent forms.

> Section 3.2 is the host-facing editor public API index. Some module-specific interfaces, data models, and callback contracts are further specified in later sections (for example Sections 4, 5, 6, 7, and 10); Sections 4, 5, and 10 define required-module contracts, while Sections 6 and 7 define optional or conditional module contracts.

---

## 4. Provider Interfaces (MUST)

The provider-manager pattern (register -> iterate -> dispatch) MUST be consistent across all platforms. Multiple instances of the same Provider type MAY be registered; the Manager is responsible for iteration, merging, and stale-result rejection. `provideDecorations` and `provideCompletions` MUST support synchronous and asynchronous result delivery. `DecorationProvider` MUST support zero, one, or multiple snapshots for the same request. `CompletionProvider` MUST support at least single-shot delivery and MAY support incremental results. In-flight decoration / completion requests MUST have cancellation or staleness contracts; late results after cancellation or staleness MUST be ignored.

Platforms MAY use Receiver callbacks, `Future` / `Promise` / `Task`, coroutines, streams / observables, or other platform-idiomatic forms. If the Receiver shape is not exposed, the platform MUST still document immediate delivery, deferred delivery, multi-shot applicability, and cancellation / staleness semantics.

### 4.1 DecorationProvider

`DecorationProvider` MUST provide `getCapabilities() -> Set<DecorationType>` and `provideDecorations(context, receiver/equivalent)`. If an explicit Receiver is exposed, `DecorationReceiver` is the recommended name and it should provide `accept(result) -> boolean` and `isCancelled() -> boolean`.

| Object | Required fields / values |
|---|---|
| `DecorationContext` | `visibleLineRange`, `totalLineCount`, `textChanges`, `languageConfiguration`, `editorMetadata` |
| `ApplyMode` | `MERGE`, `REPLACE_ALL`, `REPLACE_RANGE`; merge priority is `REPLACE_ALL` > `REPLACE_RANGE` > `MERGE` |
| `DecorationResult` | `syntaxSpans`, `semanticSpans`, `overlaySpans`, `inlayHints`, `diagnostics`, `documentHighlights`, `indentGuides`, `bracketGuides`, `flowGuides`, `separatorGuides`, `foldRegions`, `gutterIcons`, `phantomTexts`, `codeLensItems`, `links`; every data family MUST have a corresponding `ApplyMode` field |
| `DecorationType` | MUST include every decoration family above, including `DOCUMENT_HIGHLIGHT`, `CODELENS`, and `LINK` |

Line-indexed data uses `Map<int, List<T>>` with 0-based line numbers. The Manager MUST merge snapshots according to `ApplyMode`: `MERGE` appends same-type data, `REPLACE_ALL` clears all existing data before writing, and `REPLACE_RANGE` replaces only data within `visibleLineRange`.

### 4.2 CompletionProvider

`CompletionProvider` MUST provide `isTriggerCharacter(ch)` and `provideCompletions(context, receiver/equivalent)`. If an explicit Receiver is exposed, `CompletionReceiver` is the recommended name and it should provide `accept(result) -> boolean` and `isCancelled() -> boolean`.

| Object | Required fields / values |
|---|---|
| `CompletionTriggerKind` | `INVOKED`, `CHARACTER`, `RETRIGGER` |
| `CompletionContext` | `triggerKind`, `triggerCharacter`, `cursorPosition`, `lineText`, `wordRange`, `languageConfiguration`, `editorMetadata` |
| `CompletionResult` | `items`, `isIncomplete` |

The Manager MUST iterate all Providers, merge returned `CompletionItem` values, and sort by `sortKey`, falling back to `label` when `sortKey` is empty.

### 4.3 NewLineActionProvider

`NewLineActionProvider` MUST provide synchronous `provideNewLineAction(context) -> NewLineAction?` because newline handling is part of the immediate input path. `NewLineContext` MUST include `lineNumber`, `column`, `lineText`, `languageConfiguration`, and `editorMetadata`. `NewLineAction` MUST include `text`. The Manager MUST iterate Providers in registration order and return the first non-null `NewLineAction`; if all return null, the default newline behavior is used.

---

## 5. `CompletionItem` Field Definitions (MUST)

`CompletionItem` is the core data type of the completion system. Application priority on commit: `textEdit` → `insertText` → `label`. `textEdit` is the only implicit replacement range source; when it is absent, platforms MUST insert `insertText` / `label` at the current cursor rather than deriving a replacement range from `wordRange`. When `additionalTextEdits` is present without `textEdit`, platforms MUST use a collapsed cursor edit as `edits[0]`, then append `additionalTextEdits`.

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `label` | String | **MUST** | Display label (used for list display and fallback insertion) |
| `detail` | String? | **MAY** | Detailed description (displayed to the right of or below the label) |
| `insertText` | String? | **MAY** | Insert text (takes priority over `label` for insertion) |
| `insertTextFormat` | int | **MUST** | Insert text format: `PLAIN_TEXT=1` (default), `SNIPPET=2` (VSCode Snippet format, supports `$1`, `${1:default}`, `$0` placeholders) |
| `textEdit` | TextEdit? | **MAY** | Precise replacement edit (specifies replacement range + new text), highest priority |
| `additionalTextEdits` | List<TextEdit> | **MAY** | Extra edits applied together with the primary edit; ranges use the original document coordinates and MUST NOT overlap |
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

**`TextEdit`** shared foundation type:

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `range` | TextRange | **MUST** | Replacement range |
| `newText` / `new_text` | String | **MUST** | Replacement text; platforms MAY expose idiomatic field casing while keeping the generated protocol field order unchanged |

---

## 6. Copilot / InlineSuggestion Interface Definition (SHOULD)

The inline suggestion (Copilot) module is SHOULD level, but when implemented MUST follow the interface specification below.

### 6.1 Data, Callbacks, and API

| Object / API | Constraint | Requirement |
|---|---|---|
| `InlineSuggestion` | **MUST** | Fields include `line`, `column`, `text`; `line` is 0-based and `column` is a 0-based UTF-16 offset |
| `InlineSuggestionListener` or equivalent event mechanism | **MUST** | Must observe `accepted` and `dismissed`; explicit listeners should provide `onSuggestionAccepted(suggestion)` and `onSuggestionDismissed(suggestion)` |
| `showInlineSuggestion(suggestion)` | **MUST** | Show the inline suggestion and make it available for accept / dismiss interaction |
| `dismissInlineSuggestion()` | **MUST** | Dismiss the current inline suggestion and remove its visible presentation |
| `isInlineSuggestionShowing()` | **MUST** | Query whether an inline suggestion is currently showing |
| `setInlineSuggestionListener(listener)` | **MUST** | Register the host-visible accepted / dismissed listener; passing `null` clears it. Platforms MAY use callbacks, delegates, event subscriptions, or typed streams for the same semantics |

For the same shown suggestion instance, `accepted` and `dismissed` MUST each fire at most once. After either event fires, no further callbacks may be emitted for that instance. If `showInlineSuggestion()` replaces the current suggestion, the platform MAY emit `dismissed` for the previous suggestion or replace it quietly, but the previous suggestion MUST NOT emit callbacks after replacement. After terminal editor teardown, internal detach, or controller disposal, no host-visible inline-suggestion callbacks may be emitted.

### 6.2 Auto-dismiss Behavior

| Rule | Constraint | Description |
|---|---|---|
| Text change | **MUST** | MUST automatically dismiss the current inline suggestion when the user types text |
| Cursor movement | **MUST** | MUST automatically dismiss the current inline suggestion when the cursor position changes |
| Scrolling | **SHOULD** | SHOULD update the visible suggestion affordance position on scroll when applicable; SHOULD NOT auto-dismiss |

---

## 7. Selection / SelectionMenu Interface Definition (SHOULD on mobile, desktop MAY omit)

On mobile platforms, the selection menu module is SHOULD level. Desktop platforms MAY omit it entirely. If implemented, it MUST follow the contract below.

### 7.1 Data, Provider, and Callback

| Object / API | Constraint | Requirement |
|---|---|---|
| `SelectionMenuItem` | **MUST** | Fields include `id`, `label`; MAY include `enabled`, `iconId`. Built-in actions should use `cut`, `copy`, `delete`, `paste`, `select_all`; custom actions MAY use any stable `id` |
| `SelectionMenuItemProvider` | **MUST** | Provides `provideMenuItems(editor/equivalent) -> List<SelectionMenuItem>` or an equivalent API; returns the complete menu model for the current show cycle, not an incremental patch |
| custom item callback | **MUST** | Platform MUST provide a listener, delegate, event, typed stream, or equivalent mechanism to observe custom item activation; explicit listeners should provide `onSelectionMenuItemSelected(itemId)` |
| `setSelectionMenuItemProvider(provider)` | **MUST** | Configure custom selection-menu items; passing `null` SHOULD restore the platform default menu |

When the provider returns an empty list, the platform MAY choose not to show a selection menu. The provider SHOULD be invoked immediately before the menu is shown so items can reflect the current editor state. Built-in cut / copy / paste / select-all actions are not required to emit the custom item callback. After terminal editor teardown, internal detach, or controller disposal, no host-visible custom selection-menu callbacks may be emitted.

### 7.2 Positioning and Lifetime

| Rule | Constraint | Description |
|---|---|---|
| Selection anchor | **MUST** | When visible, the menu MUST be anchored to the current selection / caret geometry or an equivalent platform-native selection affordance |
| Selection invalidation | **MUST** | If the selection becomes empty, invalid, or detached from the current document state, the menu MUST dismiss |
| Scroll / viewport change | **SHOULD** | Scrolling or viewport changes SHOULD update the menu position; they SHOULD NOT require dismiss unless the platform cannot reposition safely |
| Command completion | **SHOULD** | After the user activates a selection-menu command, the menu SHOULD dismiss unless the platform intentionally keeps it open for a multi-step workflow |

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

All color fields use the platform color type (ARGB). Platforms MUST provide the following fields:

| Group | Fields |
|---|---|
| Basic colors | `backgroundColor`, `textColor`, `cursorColor`, `selectionColor`, `selectionTextColor` |
| Line number and current line | `lineNumberColor`, `currentLineNumberColor`, `currentLineColor` |
| Guides | `guideColor`, `separatorLineColor`, `splitLineColor` |
| Scrollbar | `scrollbarTrackColor`, `scrollbarThumbColor`, `scrollbarThumbActiveColor` |
| Search | `searchMatchBgColor`, `searchCurrentBgColor`, `searchCurrentBorderColor` |
| Document highlight | `documentHighlightTextBgColor`, `documentHighlightReadBgColor`, `documentHighlightWriteBgColor` |
| IME | `compositionUnderlineColor` |
| InlayHint | `inlayHintBgColor`, `inlayHintTextColor`, `inlayHintIconColor` |
| Fold placeholder | `foldPlaceholderBgColor`, `foldPlaceholderTextColor` |
| PhantomText | `phantomTextColor` |
| CodeLens | `codeLensColor`, `codeLensActiveColor` |
| Link | `linkColor`, `linkActiveColor` |
| Invisible characters | `invisibleCharacterColor` |
| Diagnostics | `diagnosticErrorColor`, `diagnosticWarningColor`, `diagnosticInfoColor`, `diagnosticHintColor` |
| Linked editing | `linkedEditingActiveColor`, `linkedEditingInactiveColor` |
| Bracket matching | `bracketHighlightBorderColor`, `bracketHighlightBgColor` |
| Completion popup | `completionBgColor`, `completionBorderColor`, `completionSelectedBgColor`, `completionLabelColor`, `completionDetailColor` |

### 8.3 Factory Methods

Every platform MUST provide at least `dark()` and `light()` factory methods that return pre-configured themes. Built-in themes MUST assign explicit values for all required color fields, including selection text, search, document highlight, CodeLens, and link colors.

### 8.4 TextStyle Map

Every `EditorTheme` MUST contain a `textStyles` map (`Map<int, TextStyle>`) and a `defineTextStyle(styleId, style)` method.

---

## 9. EditorSettings (MUST)

Editor options and behavior/layout configuration MUST be centralized through the `EditorSettings` object. This includes settings-like editor options such as wrap mode, scale, spacing, padding, and similar editor-option fields. `EditorTheme` and `EditorKeyMap` remain separate host-facing configuration objects and are not folded into `EditorSettings` by this rule. The host-facing API carrier MUST NOT directly expose settings-like configuration setters (e.g. `setWrapMode`, `setScale`). Instead, it exposes a `getSettings()` method, and callers configure those settings through that object once it is available. On imperative platforms the host-facing carrier is `SweetEditor`; on declarative platforms it is `SweetEditorController`. On declarative platforms, `getSettings()` becomes valid only after `whenReady()` or an equivalent ready signal. Before that point it SHOULD return `null` or a default unavailable value, MUST NOT create a hidden runtime or hidden staging object, and MUST NOT be treated as a pre-ready configuration channel. Initial settings required before first attachment MUST be supplied through declarative construction parameters or an equivalent platform-native initialization path. This host-facing rule does not change the `EditorCore` public API defined in Section 3.1.

All platforms MUST expose the following settings through getter/setter pairs (or properties):

| Field | Type | Default | setter | getter | Typical Impact | Description |
|---|---|---|---|---|---|---|
| `editorTextSize` | float | Platform-dependent | `setEditorTextSize(size)` | `getEditorTextSize()` | `relayout` | Editor text size |
| `typeface` / `fontFamily` | Platform font type | `monospace` | `setTypeface(typeface)` / `setFontFamily(family)` | `getTypeface()` / `getFontFamily()` | `relayout` | Font family |
| `scale` | float | 1.0 | `setScale(scale)` | `getScale()` | `relayout` | Scale factor |
| `foldArrowMode` | FoldArrowMode | ALWAYS | `setFoldArrowMode(mode)` | `getFoldArrowMode()` | `repaint` | Fold arrow display mode |
| `wrapMode` | WrapMode | NONE | `setWrapMode(mode)` | `getWrapMode()` | `relayout` | Auto-wrap mode |
| `lineSpacingAdd` | float | 0 | `setLineSpacing(add, mult)` | `getLineSpacingAdd()` | `relayout` | Line spacing extra (pixels) |
| `lineSpacingMult` | float | 1.0 | *(same as above)* | `getLineSpacingMult()` | `relayout` | Line spacing multiplier |
| `contentStartPadding` | float | Platform-dependent | `setContentStartPadding(padding)` | `getContentStartPadding()` | `relayout` | Extra horizontal padding between gutter split and text rendering start (pixels) |
| `showSplitLine` | boolean | true | `setShowSplitLine(show)` | `isShowSplitLine()` | `repaint` | Whether to render the gutter split line |
| `gutterSticky` | boolean | Platform-dependent | `setGutterSticky(sticky)` | `isGutterSticky()` | `repaint` | Whether gutter stays fixed during horizontal scroll (true=fixed, false=scrolls with content) |
| `gutterVisible` | boolean | true | `setGutterVisible(visible)` | `isGutterVisible()` | `relayout` | Whether gutter area is visible (false=hide line numbers, icons, fold arrows) |
| `currentLineRenderMode` | CurrentLineRenderMode | BACKGROUND | `setCurrentLineRenderMode(mode)` | `getCurrentLineRenderMode()` | `repaint` | Current line render mode |
| `renderWhitespace` | WhitespaceRenderMode | NONE | `setRenderWhitespace(mode)` | `getRenderWhitespace()` | `repaint` | Whitespace marker rendering mode |
| `renderLineBreaks` | boolean | false | `setRenderLineBreaks(enabled)` | `isRenderLineBreaks()` | `repaint` | Whether to render line-break markers |
| `autoIndentMode` | AutoIndentMode | KEEP_INDENT | `setAutoIndentMode(mode)` | `getAutoIndentMode()` | `runtime-transition` | Auto indent mode |
| `backspaceUnindent` | boolean | true | `setBackspaceUnindent(enabled)` | `isBackspaceUnindent()` | `runtime-transition` | Whether backspace key unindents at line start |
| `readOnly` | boolean | false | `setReadOnly(readOnly)` | `isReadOnly()` | `runtime-transition` | Read-only mode, blocks all edit operations |
| `maxGutterIcons` | int | 0 | `setMaxGutterIcons(count)` | `getMaxGutterIcons()` | `relayout` | Maximum gutter icon count |
| `decorationScrollRefreshMinIntervalMs` | long | 16 | `setDecorationScrollRefreshMinIntervalMs(ms)` | `getDecorationScrollRefreshMinIntervalMs()` | `provider-policy` | Decoration scroll refresh minimum interval (ms) |
| `decorationOverscanViewportMultiplier` | float | 1.5 | `setDecorationOverscanViewportMultiplier(mult)` | `getDecorationOverscanViewportMultiplier()` | `provider-policy` | Decoration overscan viewport multiplier |

> All setter calls MUST take effect immediately and pass the core-returned `EditorActionResult` to the unified result dispatcher.
>
> Typical impact describes host-visible semantics only. It is not the basis for platform flush, repaint, or relayout decisions. Whether to rebuild the render model, synchronize IME state, continue animation, or repaint MUST be driven by `EditorActionResult` fields such as `needsRedraw`, `needsImeSync`, and `needsAnimation`.
>
> Typical impact categories:
> - `repaint`: usually affects visual refresh without requiring text relayout.
> - `relayout`: usually affects layout or render-model production.
> - `runtime-transition`: immediately affects subsequent editing behavior and safely handles the active runtime transition required by the setting.
> - `provider-policy`: immediately affects subsequent provider scheduling / refresh behavior.
>
> `readOnly` is a `runtime-transition` setting: when switching to read-only while an IME composition is active, the platform MUST finish or cancel the active platform composition before blocking subsequent edit requests.
>
> `contentStartPadding` is platform-dependent by default. It MUST be `>= 0`. `0` is the neutral baseline, but platforms MAY choose a non-zero visual default.
>
> `gutterSticky` is platform-dependent by default. Desktop-style platforms SHOULD default to `true`; mobile / touch-first platforms SHOULD default to `false`.
>
> `autoIndentMode`, `backspaceUnindent`, and `readOnly` are also `runtime-transition` settings. They MUST affect subsequent editing behavior immediately; if there is no visible state change at the moment of the setter call, the core-returned `EditorActionResult` should not ask the platform to refresh visible state.

---

## 10. Keymap / Shortcut Mapping (MUST)

### 10.1 Core Data Model

All platforms MUST provide the core-layer keymap protocol types `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, and `EditorBuiltinCommand`. Platform core APIs SHOULD accept the binding list directly and are not required to expose a separate core-layer `KeyMap` class. The C++ core may keep an internal `KeyMap` resolver; that internal type is not a platform public API contract.

- `KeyBinding` MUST support both single-chord and two-chord bindings
- `KeyChord` MUST represent one key press as `modifiers + keyCode`
- Single-chord bindings MUST encode the second chord as an empty / none chord
- `CoreProtocol` MUST provide `encodeSetKeyMapPayload(bindings)` or the language-equivalent casing for the `SetKeyMapPayload` binary payload
- `EditorCore.setKeyMap(bindings)` MUST sync the full binding table to the C++ core

### 10.2 Numeric Alignment

If the platform exposes `KeyCode`, `KeyModifier`, or `EditorBuiltinCommand` constants, their numeric values MUST align with the C++ core.

- `KeyModifier` MUST use bit flags so combined modifiers can be represented by bitwise OR
- `KeyCode.NONE`, the empty second chord, and `EditorBuiltinCommand.NONE` MUST preserve the same semantics as the C++ core
- `EditorCore`, bridge layers, or FFI layers MAY continue using raw integer enum values aligned with the C++ core as internal transport representations
- For such bridge-layer integer enums, platforms are not required to repeat host-facing business-level enum validation, but MUST ensure invalid input cannot cause native / C++ crashes or undefined behavior

### 10.3 Widget-Layer Extension

- `SweetEditor` MUST support `setKeyMap(keyMap)` and SHOULD expose `getKeyMap()`
- Platforms MUST expose `EditorKeyMap` as a widget-layer shortcut container so host code can bind command ids to host-side handlers
- `EditorKeyMap` MUST support `registerCommand(binding, handler)`
- If `binding.command == EditorBuiltinCommand.NONE`, `registerCommand(binding, handler)` MUST auto-assign a custom command id and return it
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
- `EditorEventBus` + `subscribe` / `unsubscribe` / `clear`
- Platform-native event / delegate / listener mechanisms (for example C# `event`, Java listener callbacks)
- Typed stream / signal / observable getters (for example Dart `Stream<T>`)

If a platform adopts an explicit event-bus/listener pattern, the related public types SHOULD be named `EditorEventBus` / `EditorEventListener`.

The host-visible event surface is an observer surface. Platforms MAY keep `publish` / `emit` or equivalent methods internally, but state events such as text, cursor, selection, scroll, and scale MUST be published by the unified `EditorActionResult` dispatcher. Host-facing APIs SHOULD NOT expose an entry point that can publish arbitrary editor state events.

### 11.2 Required Event Types

All platforms MUST support the following event types:

```
TextChangedEvent, CursorChangedEvent, SelectionChangedEvent,
ScrollChangedEvent, ScaleChangedEvent, DocumentLoadedEvent,
FoldToggleEvent, GutterIconClickEvent, InlayHintClickEvent, CodeLensClickEvent, LinkClickEvent,
LongPressEvent,       // mobile / touch platforms, including iOS, Android, and OHOS
DoubleTapEvent,
ContextMenuEvent      // platforms with an explicit context-menu gesture entry point
```

> `LongPressEvent` is for mobile / touch platforms, including iOS, Android, and OHOS, and represents the raw long-press gesture itself. `ContextMenuEvent` is for platforms that expose an explicit context-menu gesture entry point (for example desktop right click or a framework-native context-menu gesture). Platform implementations SHOULD only register events relevant to their platform.

> The above event types MUST be distinguishable and consumable in a type-safe way through the platform's chosen event mechanism.

Platform-specific events (e.g. `SelectionMenuItemClickEvent` on mobile) MAY be added.

`DocumentLoadedEvent` is a document lifecycle event and does not have to be derived directly from an `EditorActionResult` field. Platforms MAY publish it from the `loadDocument(...)` lifecycle path. However, any non-null `EditorActionResult` returned by `loadDocument(...)` MUST still be passed to the unified dispatcher; `DocumentLoadedEvent` must not replace result dispatch.

### 11.3 Event Payload Contract

Event payloads MUST be defined per-event. Platforms MUST NOT assume or require a shared base payload schema beyond the event type itself.

| Event | Fields | Description |
|---|---|---|
| `TextChangedEvent` | `changes: List<TextChange>`, `kind: TextChangeKind`, `source: EditorActionSource` | Incremental text changes for the current edit cycle, the semantic kind of the change, and the source action that produced it |
| `CursorChangedEvent` | `cursorPosition: TextPosition` | Current cursor position |
| `SelectionChangedEvent` | `hasSelection: boolean`, `selection: TextRange?`, `cursorPosition: TextPosition` | Current selection state and cursor position |
| `ScrollChangedEvent` | `scrollX: float`, `scrollY: float` | Current view scroll offset |
| `ScaleChangedEvent` | `scale: float` | Current editor scale |
| `DocumentLoadedEvent` | — | No payload fields are required |
| `FoldToggleEvent` | `line: int`, `isGutter: boolean`, `locationInEditor: PointF or platform-native point type` | Toggled fold line, whether the click came from gutter, and pointer location relative to the editor's local coordinate space |
| `GutterIconClickEvent` | `line: int`, `iconId: int`, `locationInEditor: PointF or platform-native point type` | Clicked gutter icon line, icon id, and pointer location relative to the editor's local coordinate space |
| `InlayHintClickEvent` | `line: int`, `column: int`, `type: InlayType`, `intValue: int`, `locationInEditor: PointF or platform-native point type` | Clicked inlay hint position, inlay type, type-specific value, and pointer location relative to the editor's local coordinate space |
| `CodeLensClickEvent` | `line: int`, `column: int`, `commandId: int`, `locationInEditor: PointF or platform-native point type` | Clicked CodeLens line/column anchor, unique command id, and pointer location relative to the editor's local coordinate space |
| `LinkClickEvent` | `line: int`, `column: int`, `target: String`, `locationInEditor: PointF or platform-native point type` | Clicked link line/column anchor, resolved link target, and pointer location relative to the editor's local coordinate space |
| `LongPressEvent` | `cursorPosition: TextPosition`, `locationInEditor: PointF or platform-native point type` | Raw long-press target position and pointer location relative to the editor's local coordinate space |
| `DoubleTapEvent` | `cursorPosition: TextPosition`, `hasSelection: boolean`, `selection: TextRange?`, `locationInEditor: PointF or platform-native point type` | Double-tap target position, resulting selection state, and pointer location relative to the editor's local coordinate space |
| `ContextMenuEvent` | `cursorPosition: TextPosition`, `locationInEditor: PointF or platform-native point type` | Explicit context-menu gesture target position and pointer location relative to the editor's local coordinate space |
| `ContextMenuItemClickEvent` *(platform-specific)* | `item: ContextMenuItem`, `request: ContextMenuRequest` | Clicked custom context-menu item and the immutable request snapshot used to build that menu |
| `SelectionMenuItemClickEvent` *(platform-specific)* | `item: SelectionMenuItem` | Clicked custom selection-menu item |

### 11.4 `EditorActionResult` Gesture Field Contract

Platforms MAY expose the return value of `handleGestureEvent(...)` directly, or consume it internally only; however, the gesture return value MUST be `EditorActionResult` or a platform-equivalent type. The following gesture-related fields MUST keep semantics consistent with Core and be consumed by the unified result dispatcher:

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `gestureType` | `GestureType` | **MUST** | Gesture semantics recognized by core; `UNDEFINED` means the action was not produced by gesture handling |
| `gestureEventType` | `EventType` | **MUST** | Original event type that produced this gesture semantics |
| `tapPoint` | `PointF` | **MUST** | Gesture hit point in editor-local coordinates |
| `hitTarget` | `HitTargetType` + platform-aligned payload | **MUST** | Hit-test result for the current gesture location |
| `pointerCursorAfter` / `pointerCursorChanged` | `PointerCursorType` / boolean | **MUST** on desktop or platforms with mouse / hover input, **MAY** on touch-only platforms | Pointer cursor hint for the current mouse location, plus whether the platform cursor should update |
| `needsEdgeScroll` / `needsFling` / `needsAnimation` | boolean | **MUST** | Edge-scroll and fling state plus the unified animation scheduling flag; platforms schedule ticks from `needsAnimation` |
| `isHandleDrag` | boolean | Mobile **SHOULD** | Whether the current gesture is a selection-handle drag |

> These fields MUST be consumed according to their own semantics and must not depend on `needsRedraw` as a side effect. Desktop platforms, and platforms with mouse / hover input, SHOULD apply `pointerCursorAfter` immediately when `pointerCursorChanged` is true even if the result does not require redraw; platforms MUST also start or stop animation ticks from `needsAnimation` rather than waiting for the next render model rebuild. Touch-only platforms with no pointer cursor concept MAY ignore cursor-shape changes entirely.

### 11.5 ContextMenu Standard Contract

`ContextMenu` is a widget-layer, platform-side UI capability. It MUST NOT be modeled as a C++ Core render-model concept or serialized as a Core decoration type. If a platform implements context menus, it MUST follow the following standard data model and semantics.

#### Recommended Types

```
enum ContextMenuTriggerKind {
    LONG_PRESS,
    RIGHT_CLICK
}

interface ContextMenuItemProvider {
    provideMenuItems(request: ContextMenuRequest) -> List<ContextMenuSection>
}
```

#### `ContextMenuRequest` MUST Fields

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `triggerKind` | `ContextMenuTriggerKind` | **MUST** | Trigger kind for the current menu show cycle |
| `cursorPosition` | `TextPosition` | **MUST** | Caret position after the triggering gesture resolves |
| `locationInEditor` | `PointF or platform-native point type` | **MUST** | Pointer location relative to the editor's local coordinate space |
| `hasSelection` | boolean | **MUST** | Whether the editor has a non-empty selection |
| `selection` | `TextRange?` | **MAY** | Current selection snapshot; `null` when `hasSelection == false` |
| `hitTarget` | platform-aligned `HitTarget` payload | **MUST** | Hit-test result at the trigger location |
| `linkTarget` | String | **MAY** | Resolved link target when `hitTarget` is `LINK`; empty string when not applicable |

#### `ContextMenuItem` MUST Fields

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `id` | String | **MUST** | Stable action identifier |
| `label` | String | **MUST** | Primary display text |
| `secondaryLabel` | String? | **MAY** | Optional secondary text shown on the same row |
| `enabled` | boolean | **MAY** | Whether the item is currently actionable; defaults to enabled if omitted |
| `icon` | platform-native leading icon object or equivalent | **MAY** | Optional leading icon. This SHOULD be a platform-native image object, not a cross-platform numeric icon id |

#### `ContextMenuSection` MUST Fields

| Field | Type | MUST/MAY | Description |
|---|---|---|---|
| `items` | `List<ContextMenuItem>` | **MUST** | Full list of menu items in that section |

Context-menu semantics:
- `LongPressEvent` and/or `ContextMenuEvent` MAY be the trigger signal; `ContextMenuRequest` is the immutable snapshot used to build the actual menu model
- The provider returns the complete menu model for the current show cycle, rather than incremental appended items
- Passing `null` as the provider SHOULD restore the platform default context menu
- Returning an empty list MAY suppress the menu for that show cycle
- `locationInEditor` MUST remain editor-local; platforms convert it to screen / window coordinates only when presenting a popup or native menu
- A platform MAY open a context menu from `LongPressEvent` without publishing `ContextMenuEvent`; in that case `ContextMenuRequest.triggerKind` MUST still be `LONG_PRESS`
- If `hitTarget == LINK` and `linkTarget` is non-empty, the default menu SHOULD include built-in actions `open_link` and `copy_link`
- If `hasSelection == true`, the default menu SHOULD include built-in actions `cut` and `copy`
- The general/default section SHOULD include built-in actions `paste` and `select_all`
- `ContextMenuItem.icon` MAY be null; if a given menu contains any icon-bearing rows, platforms SHOULD reserve a consistent leading icon slot for visual alignment
- The platform MUST provide a host-visible way to observe custom item activation via `ContextMenuItemClickEvent` or an equivalent callback payload
- After command execution, text change, or another gesture that invalidates the current target, the menu SHOULD dismiss unless the platform intentionally supports a persistent multi-step workflow

Platforms that implement `ContextMenu` MUST expose a host-facing API equivalent to `setContextMenuItemProvider(provider)`.

---

## 12. Enumeration and Constant Values (MUST)

Enum and enum-like constant values MUST match the C++ core definitions. The following groups MUST remain aligned with the C++ core across all platforms. When explicit numeric values are listed below, platforms MUST use those same values. When a row lists only member names or says it is aligned with the C++ core, platforms MUST still match the corresponding core definition.

| Enum | Values |
|---|---|
| `WrapMode` | NONE=0, CHAR_BREAK=1, WORD_BREAK=2 |
| `FoldArrowMode` | AUTO=0, ALWAYS=1, HIDDEN=2 |
| `AutoIndentMode` | NONE=0, KEEP_INDENT=1 |
| `CurrentLineRenderMode` | BACKGROUND=0, BORDER=1, NONE=2 |
| `WhitespaceRenderMode` | NONE=0, BOUNDARY=1, SELECTION=2, TRAILING=3, ALL=4 |
| `ScrollbarMode` | ALWAYS=0, TRANSIENT=1, NEVER=2 |
| `ScrollbarTrackTapMode` | JUMP=0, DISABLED=1 |
| `ScrollBehavior` | TOP=0, CENTER=1, BOTTOM=2 |
| `SpanLayer` | SYNTAX=0, SEMANTIC=1, OVERLAY=2 |
| `InlayType` | TEXT=0, ICON=1, COLOR=2 |
| `DiagnosticSeverity` | ERROR=0, WARNING=1, INFO=2, HINT=3 |
| `DocumentHighlightKind` | TEXT=0, READ=1, WRITE=2 |
| `RangeEffectUnderlineStyle` | NONE=0, SOLID=1, DASHED=2, WAVY=3 |
| `VisualRunType` | TEXT=0, WHITESPACE=1, NEWLINE=2, INLAY_HINT=3, PHANTOM_TEXT=4, FOLD_PLACEHOLDER=5, TAB=6, CODELENS=7, LINK=8 |
| `VisualLineKind` | CONTENT=0, PHANTOM=1, CODELENS=2 |
| `PointerCursorType` | DEFAULT=0, TEXT=1, HAND=2 |
| `FoldState` | NONE=0, EXPANDED=1, COLLAPSED=2 |
| `DecorationType` | SYNTAX_HIGHLIGHT, SEMANTIC_HIGHLIGHT, OVERLAY_HIGHLIGHT, INLAY_HINT, DIAGNOSTIC, DOCUMENT_HIGHLIGHT, FOLD_REGION, INDENT_GUIDE, BRACKET_GUIDE, FLOW_GUIDE, SEPARATOR_GUIDE, GUTTER_ICON, PHANTOM_TEXT, CODELENS, LINK |
| `HitTargetType` | NONE=0, INLAY_HINT_TEXT=1, INLAY_HINT_ICON=2, GUTTER_ICON=3, FOLD_PLACEHOLDER=4, FOLD_GUTTER=5, INLAY_HINT_COLOR=6, CODELENS=7, LINK=8 |
| `GuideType` | INDENT=0, BRACKET=1, FLOW=2, SEPARATOR=3 |
| `GuideDirection` | (platform-aligned with C++ core) |
| `GuideStyle` | SOLID=0, DASHED=1, DOUBLE=2 |
| `SeparatorStyle` | SINGLE=0, DOUBLE=1 |
| `SearchStatus` | INACTIVE=0, SEARCHING=1, READY=2, STALE=3, FAILED=4 |
| `RangeEffectKind` | SELECTION=0, SEARCH_MATCH=1, SEARCH_CURRENT=2, DOCUMENT_HIGHLIGHT_TEXT=3, DOCUMENT_HIGHLIGHT_READ=4, DOCUMENT_HIGHLIGHT_WRITE=5, LINKED_EDITING_ACTIVE=6, LINKED_EDITING_INACTIVE=7, IME_COMPOSITION=8, BRACKET_MATCH=9, DIAGNOSTIC_ERROR=10, DIAGNOSTIC_WARNING=11, DIAGNOSTIC_INFO=12, DIAGNOSTIC_HINT=13 |
| `KeyCode` | NONE=0, BACKSPACE=8, TAB=9, ENTER=13, ESCAPE=27, DELETE_KEY=46, LEFT=37, UP=38, RIGHT=39, DOWN=40, HOME=36, END=35, PAGE_UP=33, PAGE_DOWN=34, A=65, C=67, D=68, V=86, X=88, Y=89, Z=90, K=75, SPACE=32 |
| `KeyModifier` | NONE=0, SHIFT=1, CTRL=2, ALT=4, META=8 |
| `EditorBuiltinCommand` | NONE=0, CURSOR_LEFT=1, CURSOR_RIGHT=2, CURSOR_UP=3, CURSOR_DOWN=4, CURSOR_LINE_START=5, CURSOR_LINE_END=6, CURSOR_PAGE_UP=7, CURSOR_PAGE_DOWN=8, SELECT_LEFT=9, SELECT_RIGHT=10, SELECT_UP=11, SELECT_DOWN=12, SELECT_LINE_START=13, SELECT_LINE_END=14, SELECT_PAGE_UP=15, SELECT_PAGE_DOWN=16, SELECT_ALL=17, BACKSPACE=18, DELETE_FORWARD=19, INSERT_TAB=20, INSERT_NEWLINE=21, INSERT_LINE_ABOVE=22, INSERT_LINE_BELOW=23, UNDO=24, REDO=25, MOVE_LINE_UP=26, MOVE_LINE_DOWN=27, COPY_LINE_UP=28, COPY_LINE_DOWN=29, DELETE_LINE=30, COPY=31, PASTE=32, CUT=33, TRIGGER_COMPLETION=34 |

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

IME integration is inherently platform-specific, but SweetEditor composition semantics MUST remain consistent across platforms. Platform implementations MAY use different system APIs, but MUST normalize native IME events to core IME semantic capability families. Only explicit platform composing / marked / preedit declarations create editor composition. Candidate context, surrounding text, cursor rectangles, keyboard language, or moving the cursor into a Latin word MUST NOT create editor composition.

| Platform | IME API | Recommended mapping |
|---|---|---|
| Android | `InputConnection` | Choose preedit, document-range, input-context, or deletion semantics based on `setComposingText` / `setComposingRegion` / `commitText` / delete / extracted-text capabilities |
| iOS | `UITextInput` | Map marked text / `markedTextRange` to marked/preedit semantics; choose document or input-context semantics based on the coordinate capability exposed by the platform text range |
| macOS | `NSTextInputClient` | Map `setMarkedText` / marked ranges to marked/preedit semantics; selected ranges and replacement ranges must preserve coordinate-space consistency |
| Swing | `InputMethodEvent` / `InputMethodRequests` | Map composed text segments from `InputMethodEvent` to preedit/commit; use `InputMethodRequests` for candidate context and cursor rectangles |
| WinForms | TSF / IMM | Map TSF composition ranges or IMM composition strings to preedit, document-range, or input-context semantics according to the available native data |
| OHOS | IME Kit | Map platform composing / preedit callbacks or ranges to preedit, document-range, input-context, or text-model semantics according to their coordinate space |
| Flutter | `TextInputClient` | Prefer text-model state / delta semantics from `TextEditingValue`; a valid `composing` range means the platform declared composition |

Every platform MUST map native composition sources to core's preedit / composing / marked-range semantic family, native commits to the commit semantic family, explicit replacements to the replacement semantic family, and native finish/cancel events to the finish/cancel semantic family. A platform MAY choose document line/column, document offset, input-context offset, or text-model state/delta paths based on its native API, but the coordinate space MUST be explicit and consistent.

Document ranges passed to core MUST use document coordinates. Input-context / text-model offsets MUST be relative to the corresponding `documentStartOffset`. Temporary offsets from a platform-specific surrounding-text window MUST NOT be treated as document offsets. Editable editors always support platform IME composition; read-only mode blocks text changes and MUST NOT be implemented as a composition enable / disable switch.

### 13.3 Optional Modules

| Module | Mobile | Desktop |
|---|---|---|
| `copilot/` (InlineSuggestion) | SHOULD | SHOULD |
| `contextmenu/` (ContextMenu) | MAY | SHOULD |
| `selection/` (SelectionMenu) | SHOULD | MAY omit |
| `perf/` (PerfOverlay) | MAY | MAY |

### 13.4 Rendering Details (MAY differ)

Minor visual differences are acceptable:
- Line number background rendering mode
- Scrollbar visual style and animation
- Cursor blink timing
- Selection handle shape
- Platform-native font rendering differences

---

## 14. Threading and Concurrency Model (MUST)

State-mutating editor operations and host-visible callbacks are UI-thread-affine by default. Platforms MAY expose additional thread-safe query surfaces, but MUST choose a concrete threading model; platforms SHOULD explain that model through code comments, type annotations, or a README.

| Rule | Constraint | Description |
|---|---|---|
| State-mutating API thread | **MUST** | Public methods that mutate editor state or trigger visible UI updates MUST be called on the UI thread unless the platform explicitly documents an equivalent serialized threading model |
| API thread contract documentation | **SHOULD** | Platforms SHOULD use code comments, type annotations, or a README to identify which public APIs are UI-thread-only and which pure query / snapshot APIs, if any, are safe to call from background threads |
| Pure query API thread | **SHOULD** | Pure query / snapshot APIs SHOULD either remain UI-thread-only or be explicitly documented as background-safe; platforms MAY allow background reads only when implemented safely |
| Event callback thread | **MUST** | All event callbacks / delegate invocations / stream emissions that are visible to host code MUST execute on the UI thread |
| Provider call thread | **MUST** | Platforms MUST choose a stable invocation model for `provideDecorations()` and `provideCompletions()` (UI thread, worker thread, or another serialized executor); platforms SHOULD explain that model to host code through code comments, type annotations, or a README |
| Provider async callback thread | **MUST** | Provider result delivery may happen from any thread, but the Manager MUST switch back to the UI thread when applying results to Core or mutating host-visible editor state |
| `buildRenderModel()` | **MUST** | `buildRenderModel()` MUST observe a stable editor snapshot. Platforms MAY require UI-thread calls or provide a stronger thread-safe snapshot contract, but the returned `EditorRenderModel` SHOULD be treated as immutable and MAY be safely read on the render thread |
| `NewLineActionProvider` | **MUST** | `provideNewLineAction()` MUST complete synchronously on the input path so Enter handling does not depend on a later async callback |
| Thread safety annotations | **SHOULD** | Platforms SHOULD annotate thread constraints in public API documentation (e.g. Java `@MainThread`, Swift `@MainActor`) |
## 15. Error Handling (MUST)

Public APIs use defensive handling for invalid inputs; managed-language host-facing public APIs MAY fail fast using language-idiomatic errors, but bridge / FFI boundaries MUST ensure invalid input cannot cause native / C++ crashes or undefined behavior; exceptions in Provider callbacks are isolated by the Manager.

### 15.1 Public API Parameter Validation

| Scenario | Constraint | Behavior |
|---|---|---|
| Line / column out of bounds | **MUST** | Automatically clamp to valid range `[0, max)`; MUST NOT throw exceptions |
| null / empty parameters | **MUST** | Platforms MUST honor the nullable semantics of parameters that are defined as nullable. For MUST-non-null parameters, managed-language public APIs SHOULD fail fast using platform-idiomatic errors (for example Java `NullPointerException` / `IllegalArgumentException`, C# `ArgumentNullException`) and MUST NOT cause native / C++ crashes or undefined behavior; bridge / FFI boundaries MUST handle invalid input safely |
| Invalid enum values | **MUST** | For host-facing public APIs that are forced to expose integer enum values, platforms MUST handle invalid values explicitly; managed-language public APIs SHOULD fail fast using platform-idiomatic errors (for example `IllegalArgumentException`), and MAY instead fall back to a default value. For raw integer enum values used by `EditorCore`, bridge layers, or FFI layers, platforms are not required to repeat host-level business validation, but MUST NOT allow invalid input to cause native / C++ crashes or undefined behavior |
| Calls outside ready / active lifecycle | **SHOULD** | Platforms SHOULD follow the lifecycle rules in Sections 3.0.3 and 16.3. Before a declarative editor instance is ready, or after terminal teardown, getters SHOULD return `null` or default values. Mutating imperative calls MUST be ignored or rejected and MUST NOT be queued. After terminal teardown, runtime-affecting calls MUST be no-ops or return default values. This rule primarily applies to declarative controllers, explicit teardown APIs, or platforms with a defined terminal session lifecycle boundary |

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

For all platforms, the conformance target is terminal release-path safety plus eventual native-resource release. The standard does not require every platform to expose an explicit `dispose()` / `close()` / `release()` API, and it does not require a single cross-platform deterministic destruction moment. Platforms MAY satisfy the release-path requirement through an explicit teardown API, a host-managed lifecycle, widget or controller destruction, destructor / RAII / `Drop`, ARC / `deinit`, GC / finalizer-backed reclamation, or another platform-idiomatic cleanup mechanism. For GC-managed imperative widget platforms, the standard does not require inventing a synthetic terminal session-teardown hook solely for conformance; the primary requirement is eventual native-resource release plus safety after teardown or release.

### 16.1 `EditorCore` Lifecycle

| Phase | Constraint | Rule |
|---|---|---|
| Creation | **MUST** | `EditorCore` instance MUST be created during widget initialization (imperative frameworks: constructor or init; declarative frameworks: on first widget mount) |
| Release path | **MUST** | The platform MUST ensure that `EditorCore` and its native / C++ resources are eventually released. An explicit `dispose()` / `close()` / `release()` API is optional. Platforms MAY instead rely on a host-managed editor lifecycle, widget/session destruction, destructor / RAII / `Drop`, ARC / `deinit`, GC / finalizer-backed automatic reclamation, an equivalent platform cleanup hook, or another platform-idiomatic strategy. For GC-managed imperative widget platforms, eventual reclamation through GC, finalizer, Cleaner, or an equivalent runtime-backed cleanup mechanism is sufficient even when the platform does not expose a distinct terminal session callback. Controller destruction only counts when it is part of the associated editor instance's terminal cleanup path. View detachment, widget unmount, or temporary removal from the view tree is NOT by itself required to be the final reclamation moment |
| Post-teardown calls | **MUST** | If the platform exposes an explicit terminal teardown API, or otherwise keeps the object reachable and callable after logical teardown or internal release, subsequent calls MUST NOT access invalid native / C++ resources and MUST NOT trigger further editor side effects or callbacks. Mutating calls MUST be no-ops or return default values. Getter calls MAY return `null`, default values, or last-known managed snapshots, as long as they do not require live native state or trigger lazy recomputation against released resources |
| Repeated release | **MUST** | If the platform exposes explicit release logic, multiple invocations MUST be idempotent (no-op); MUST NOT cause double-free |

> The standard requires eventual native-resource release, but does **not** require every platform, or every `Document` / bridge wrapper, to expose an additional explicit release API beyond its own lifecycle model. Platforms SHOULD prioritize logical teardown safety: stop timers, detach listeners, cancel or stale-mark async receivers, and break reference chains that would otherwise keep the editor object graph alive. If a platform exposes explicit teardown logic or another known terminal cleanup callback, it MUST perform the corresponding logical teardown cleanup. On GC-managed imperative widget platforms that do not expose such a terminal cleanup hook, proactive cleanup remains a SHOULD rather than a MUST. If a platform chooses to keep returning last-known managed snapshots after teardown, it SHOULD document that those values are stale snapshots rather than live editor state.

### 16.2 Provider Lifecycle

| Rule | Constraint | Description |
|---|---|---|
| Registration timing | **MUST** | Providers MUST be registerable at any time after the associated editor instance is ready. The standard MUST NOT require registration to occur after `loadDocument(...)` or after document availability |
| Pre-attachment calls | **MUST** | On declarative platforms, provider registration calls are only valid after the associated editor instance completes its initial attachment. Host code SHOULD register providers from `whenReady()` or an equivalent ready signal. Calls before that point MAY be ignored or rejected, but MUST NOT be queued by `SweetEditorController` and MUST NOT create a hidden runtime |
| Invocation prerequisites | **MUST** | Providers MAY be invoked only when the current session has the context/data required by that provider type. If prerequisite document/context data is unavailable, the platform MAY delay invocation, skip invocation, or follow the module-specific empty/default-context contract when such a contract exists |
| Registration ownership | **MUST** | Provider registrations exposed to host code MUST belong to the currently associated `SweetEditor` session/runtime. They are session-scoped registrations, not controller-owned state |
| Session cleanup | **MUST** | If the platform defines an explicit session teardown phase, internal detach hook, or another platform-native destruction callback that semantically represents terminal session cleanup, it MUST cancel or stale-mark all in-flight provider work associated with that session, stop related timers/listeners/receivers, ignore late results from the old session, and MUST clear or terminally deactivate session-owned provider registrations as part of that session teardown. If a GC-managed imperative platform does not expose such a terminal cleanup hook, proactive session cleanup is SHOULD rather than MUST; eventual reclamation by the managed runtime is acceptable, provided late results cannot access invalid native state after release |
| Controller forwarding boundary | **MUST** | `SweetEditorController` MAY forward provider registration calls to the bound `SweetEditor`, but the standard MUST NOT require the controller to retain provider registrations across editor lifetimes or after terminal session teardown |
| Cleanup during terminal teardown | **MUST** | If the platform defines an explicit controller `dispose()` / `close()` / `release()` phase, or another equivalent final logical teardown hook, it MUST clear controller-owned readiness callbacks and internal pending callbacks, and cancel or stale-mark any controller-owned async work so late results are ignored. It MUST NOT imply controller-side ownership of session provider registrations. On GC-managed platforms, when such an explicit or platform-native terminal cleanup hook exists, the equivalent logical teardown MUST still detach listeners, stop timers, and cancel or stale-mark async receivers so late results cannot keep the editor object graph alive or mutate freed native resources / host-visible editor state. If no such terminal cleanup hook exists on a GC-managed imperative platform, proactive cleanup remains SHOULD rather than MUST |
| Provider references | **SHOULD** | Platform implementations SHOULD avoid Providers holding strong references to the widget instance to prevent circular references causing memory leaks (Java/Kotlin: WeakReference; Swift: weak/unowned; Dart: no special handling needed) |

### 16.3 `SweetEditorController` Lifecycle (Declarative Frameworks)

`SweetEditorController` is associated with a single declarative editor instance. It is created by host code, passed to `SweetEditor` at construction time, and acts only as the host-facing forwarding entry for that editor instance. An explicit `close()` / `dispose()` / `release()` API is optional and, when present, represents terminal controller teardown rather than normal widget removal.

| Phase | Constraint | Rule |
|---|---|---|
| Creation | **MUST** | Controller MUST be created by host code and provided to `SweetEditor` when that editor instance is constructed; lifecycle is managed by the host |
| Association | **MUST** | The association between a `SweetEditorController` and a `SweetEditor` instance MUST be established during construction of that editor instance and MUST remain fixed for that editor lifetime |
| Internal attachment | **MUST** | The widget/session MUST internally attach during initialization or mount, and internally detach during terminal cleanup of that editor instance |
| Post-teardown state | **MUST** | After the associated editor instance reaches terminal teardown, the Controller MUST become inactive. Subsequent runtime-affecting operations MUST be no-ops or return default values |
| Ownership boundary | **MUST** | The Controller MUST NOT own the bound widget/session runtime. `EditorCore`, render/runtime objects, overlay runtime, focus/gesture pipelines, and current binding timers/listeners belong to the currently bound widget/session |
| Explicit teardown (if provided) | **MAY** | Platforms MAY provide an explicit terminal controller teardown method such as `dispose()`, `close()`, or `release()`. This is optional for both GC-managed and non-GC platforms when terminal teardown is already guaranteed by the host lifecycle or by platform-native destruction semantics |
| Rebinding | **MUST NOT** | A `SweetEditorController` MUST NOT be rebound to another widget/session/editor instance after its initial association is established |
| Teardown ordering and boundary | **MUST** | If the platform provides an explicit controller teardown method, it MUST first detach from the associated widget/session if still attached, then release controller-owned internal state, clear readiness callbacks and internal pending callbacks, cancel timers/listeners/receivers/in-flight async work, and break reference chains. Any method call after teardown MUST be a no-op or return a default empty value. The Controller MUST NOT assume ownership of the bound widget and MUST NOT directly destroy the `View` / `Control` / `Widget` itself |
| Declarative rebuild | **SHOULD** | Ordinary declarative rebuilds that preserve the same mounted editor runtime SHOULD continue to use the same controller association and MUST NOT be treated as rebinding |

> This section applies only to platforms that expose an independent controller object. It MUST NOT be interpreted as requiring every imperative `View` / `Control` / `Widget` / `Document` type to add a library-defined `dispose()` / `close()` method. Internal detach means the controller is no longer connected to its associated editor session. Controller teardown means terminal deactivation of the controller itself; it does not transfer ownership of, or destroy, the bound widget.

### 16.4 Resource Release Order

When the platform performs editor release / dispose / close / final teardown, it MUST satisfy the following safety constraints. For GC-managed platforms, these constraints primarily apply to logical teardown and reference-chain cleanup; final native reclamation MAY happen later, as long as the torn-down object graph can no longer produce user-visible effects or touch invalid native state.

- All in-flight async Provider requests MUST be cancelled or marked stale before their results can reach invalid native state
- Provider registrations MUST be cleared or terminally deactivated before they can emit further callbacks into a destroyed editor
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

| Type | MUST fields | Special semantics |
|---|---|---|
| `IntRange` | `start`, `end` | Inclusive range; `end < start` means empty |
| `TextChange` | `range`, `newText` | `range` is in document coordinates; empty `newText` means pure deletion |

### 17.3 Adornment Data Types

| Type | MUST fields | Special semantics |
|---|---|---|
| `StyleSpan` | `column`, `length`, `styleId` | `styleId` comes from `registerTextStyle()` |
| `TextStyle` | `color`, `backgroundColor`, `fontStyle` | Colors are ARGB; `fontStyle` flags are `BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4` |
| `InlayHint` | `type`, `column`, `text`, `intValue` | `type` is `TEXT=0`, `ICON=1`, `COLOR=2`; `text` MUST be non-null for TEXT and MAY be null for other types |
| `PhantomText` | `column`, `text` | Ghost text content |
| `CodeLensItem` | `column`, `text`, `commandId` | Multiple CodeLens items on the same logical line MUST be ordered by `column`; `commandId` is passed back in `CodeLensClickEvent` |
| `LinkSpan` | `column`, `length`, `target` | `target` is returned by `getLinkTargetAt()` and `LinkClickEvent` |
| `GutterIcon` | `iconId` | Icon resources are resolved and rendered by the platform's `EditorIconProvider` |
| `Diagnostic` | `column`, `length`, `severity` | `severity` is `ERROR=0`, `WARNING=1`, `INFO=2`, `HINT=3`; this is a minimal diagnostic decoration model, not a full IDE diagnostic object |
| `DocumentHighlight` | `column`, `length`, `kind` | `kind` is `TEXT=0`, `READ=1`, `WRITE=2` |
| `FoldRegion` | `startLine`, `endLine` | `startLine` remains visible and `endLine` is inclusive |
| `IndentGuide` | `start`, `end` | Indentation guide endpoints |
| `BracketGuide` | `parent`, `end`, `children` | Bracket pair guide structure |
| `FlowGuide` | `start`, `end` | Control-flow guide endpoints |
| `SeparatorGuide` | `line`, `style`, `count`, `textEndColumn` | `textEndColumn` determines the separator drawing start position |

### 17.4 Search Data Types

| Type | MUST fields | Special semantics |
|---|---|---|
| `SearchOptions` | `caseSensitive`, `wholeWord`, `useRegex`, `wrapAround`, `maxMatches` | Defaults are case-insensitive, not whole-word, literal search, wrap-around enabled, and bounded match collection |
| `SearchRequest` | `pattern`, `options` | Empty patterns clear search state or return an inactive state according to the core result |
| `SearchState` | `status`, `pattern`, `options`, `generation`, `matchCount`, `currentIndex`, `hasCurrentMatch`, `currentRange`, `errorMessage` | `currentIndex` is `-1` when there is no current match; ranges use document coordinates |

### 17.5 Visual Render Types

| Type | MUST fields | Special semantics |
|---|---|---|
| `EditorRenderModel` | `pointerCursorType` | MUST on desktop or platforms with mouse / hover input, MAY on touch-only platforms; should stay semantically consistent with `EditorActionResult.pointerCursorAfter` |
| `VisualRun` | `type`, `iconId`, `active` | `iconId` means icon resource id for `INLAY_HINT(ICON)` and unique `commandId` for `CODELENS`; `active` drives hover / pressed rendering for clickable runs |
| `VisualLine` | `kind`, `ownsGutterSemantics` | `CODELENS` is a virtual visual line; the first real content line for the same logical line MUST be identified through `ownsGutterSemantics`, not inferred from `wrapIndex` |

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
| Resource release | **MUST** | When `Document` reaches its terminal platform lifecycle state, the bridge layer MUST eventually release the C++ side document memory. The exact cleanup mechanism is platform-specific, and an explicit `dispose()` / `close()` API is optional on both GC-managed and non-GC platforms |
| Encoding model | **MUST** | Platform layers MUST NOT assume or expose a specific internal storage / layout encoding beyond the semantics guaranteed by the public APIs |
| Line endings | **MUST** | C++ Core supports LF, CR, and CRLF line endings; text returned by `getLineText()` MUST NOT include line endings |

### 18.4 Relationship with `loadDocument()`

| Rule | Constraint | Description |
|---|---|---|
| Loading timing | **MUST** | After creation, `Document` MUST become the editor's current document either via `loadDocument(doc)` or, on declarative platforms, via declarative initialization inputs for the first attached editor session. If declarative initialization uses `text` instead of `document`, the platform MUST first materialize an equivalent `Document` from that text and treat the materialized `Document` as the current document. A `Document` that has not become the current document for any editor session will not trigger rendering or editor events |
| Document replacement | **MUST** | Calling `loadDocument()` again replaces the current document. On declarative platforms, changing the declarative current-document input for the same mounted editor runtime has the equivalent effect. If the declarative update uses `text`, the replacement document is the newly materialized `Document` created from that text. The old document reference is managed by host code |
| Document ownership | **SHOULD** | The same `Document` instance SHOULD NOT be loaded into multiple editor instances simultaneously |
## 19. `EditorMetadata` and `LanguageConfiguration` Field Definitions (MUST)

### 19.1 `EditorMetadata`

`EditorMetadata` is a **semantic concept type** representing host-defined metadata attached to an editor instance. The platform layer is responsible only for storing and returning it, not interpreting its internal structure.

| Rule | Constraint | Description |
|---|---|---|
| Representation form | **MUST** | Platforms MUST provide some representation capable of carrying arbitrary host-defined metadata; they MAY use a marker interface / protocol / abstract class / base class / `Object` / `any` / `unknown` / generic payload, etc. |
| Explicit type naming | **SHOULD** | If the platform chooses to expose an explicit public type, it SHOULD be named `EditorMetadata`; language-conventional variants such as `IEditorMetadata` or `SEEditorMetadata` are also allowed |
| Purpose | **MUST** | Host code stores and retrieves custom metadata (e.g. file path, language ID) via `setMetadata()` / `getMetadata()` or language-idiomatic typed variants such as `setMetadata<T>()` / `getMetadata<T>()`; the platform layer MUST treat it as an opaque value and MUST NOT impose its own schema |
| Retrieval semantics | **MUST** | `getMetadata()` or its typed variant MUST return the same metadata value previously set when the requested type matches, or `null` if none exists; if the platform exposes a wider carrier type (such as `Object?`), host code is responsible for its own casts / type assertions |

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

---

## 20. Performance Guidance & Reference Targets (SHOULD)

This section defines the performance invariants that platform implementations must preserve. Numeric targets are optimization goals, not conformance gates.

| Rule | Constraint Level | Description |
|---|---|---|
| Viewport-scoped rendering | **MUST** | Layout and painting on the platform side MUST be scoped to the visible region (plus small lookahead buffers when needed); platforms MUST NOT require full-document relayout or redraw for ordinary scrolling |
| Provider non-blocking | **MUST** | Slow decoration / completion providers MUST NOT block typing, scrolling, or painting on the host-visible interaction path |
| Stale async results | **MUST** | Outdated async provider results MUST be cancellable or discarded before they mutate visible editor state |
| Core/layout duplication | **MUST** | Platform hot paths MUST NOT redundantly recompute geometry or layout information that is already produced by Core and can be consumed directly |
| Performance diagnostics | **SHOULD** | Platforms SHOULD preserve enough timing hooks to support debug-only performance diagnostics |
| Large-document strategy | **SHOULD** | Large-document loading SHOULD use memory mapping, streaming load, or equivalent strategies; scrolling MUST rely on viewport rendering |
| Provider timeout | **SHOULD** | If decoration requests exceed 5 seconds or completion requests exceed 3 seconds without delivery, the Manager SHOULD cancel or mark them stale |
| NewLine latency | **MUST / SHOULD** | `provideNewLineAction()` MUST remain synchronous and MUST NOT introduce user-perceptible Enter-key latency |
| Debug performance overlay | **MAY / MUST** | If a debug performance overlay is provided, it MUST be disabled by default and used only for debugging; its field names, thresholds, and step names MUST NOT be treated as stable API contract |

---

## 21. Testing Standards (SHOULD)

| Rule | Constraint Level | Description |
|---|---|---|
| Regression tests | **MUST** | Each core module (Document, Layout, Decoration, EditorCore) MUST have corresponding regression tests |
| Platform API tests | **SHOULD** | Each platform SHOULD verify host APIs, settings/theme defaults, provider registration/release, and event subscription/release |
| Result dispatch tests | **SHOULD** | Each platform SHOULD cover `EditorActionResult` dispatch, IME synchronization, text / cursor / selection / scroll events, animation ticks, and pointer cursor updates |
| Async stale tests | **SHOULD** | Stale decoration / completion async results SHOULD be cancelled or discarded |
| Lifecycle tests | **SHOULD** | After teardown, platforms should not touch invalid native state or emit host-visible callbacks |

---

## 22. Accessibility Standards (MAY)

Accessibility support is MAY level; implementations SHOULD follow this minimum guidance.

| Rule | Constraint Level | Description |
|---|---|---|
| Role annotation | **SHOULD** | The editor widget SHOULD be annotated as a text editor or platform-equivalent role |
| Text content | **SHOULD** | SHOULD expose currently visible text content to accessibility services |
| Cursor position | **SHOULD** | SHOULD expose current cursor position and selection range to accessibility services |
| Line information | **MAY** | MAY expose current line number and total line count to accessibility services |
| Focus management | **SHOULD** | The editor widget SHOULD be focusable and defocusable via the Tab key |
| Keyboard shortcuts | **SHOULD** | Desktop platforms SHOULD support standard keyboard shortcuts (Ctrl/Cmd+C/V/X/Z/A, etc.) |
| High contrast | **MAY** | MAY provide a high-contrast theme or respond to system high-contrast settings |
| Font scaling | **SHOULD** | SHOULD respond to system font scaling settings (via `setScale()` or `setEditorTextSize()`) |
| Cursor visibility | **SHOULD** | The cursor SHOULD have sufficient visual contrast |

---

## 23. Versioning

This standard applies to SweetEditor platform implementations as of 2026-06. When the C++ core adds new enums, events, or API methods, all platforms MUST be updated to match within the same release cycle.

### 23.1 Platform Package Version Numbering

Platform package version numbers MUST maintain alignment with the C++ Core version. The version format is `a.b.c` (major.minor.patch).

| Segment | Constraint | Rule |
|---|---|---|
| `a` (major) | **MUST** | Platform package major version MUST match the Core major version and MUST NOT exceed it |
| `b` (minor) | **SHOULD** | Platform package minor version SHOULD NOT exceed Core minor version `+9`; exceeding requires documented justification |
| `c` (patch) | **MAY** | Platform package patch version may increment freely for platform-specific bugfixes |

- When Core releases a new major version (e.g. `2.0.0`), all platform packages MUST upgrade their major version within the same release cycle.
- Platform packages MAY independently release patch versions (`c` increment) while the Core version remains unchanged, for platform-specific fixes.
- The recommended ceiling on the minor version (`b`) is to prevent platform package versions from diverging too far from the Core version, which would cause version mapping confusion.
