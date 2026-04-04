// Document API
export const createDocumentFromString: (text: string) => number;
export const createDocumentFromFile: (path: string) => number;
export const freeDocument: (handle: number) => void;
export const getDocumentText: (handle: number) => string;
export const getDocumentLineCount: (handle: number) => number;
export const getDocumentLineText: (handle: number, line: number) => string;

// EditorCore lifecycle
export const createEditor: (measurer: TextMeasurer, optionsData?: ArrayBuffer) => number;
export const freeEditor: (handle: number) => void;
export const setEditorViewport: (handle: number, width: number, height: number) => void;
export const setEditorDocument: (handle: number, documentHandle: number) => void;

// Rendering
export const buildEditorRenderModel: (handle: number) => ArrayBuffer | undefined;
export const getLayoutMetrics: (handle: number) => ArrayBuffer | undefined;

// Gesture/keyboard
export const handleEditorGestureEvent: (handle: number, type: number, pointerCount: number, points: number[]) => ArrayBuffer | undefined;
export const handleEditorGestureEventEx: (handle: number, type: number, pointerCount: number, points: number[], modifiers: number, wheelDeltaX: number, wheelDeltaY: number, directScale: number) => ArrayBuffer | undefined;
export const editorTickEdgeScroll: (handle: number) => ArrayBuffer | undefined;
export const editorTickFling: (handle: number) => ArrayBuffer | undefined;
export const editorTickAnimations: (handle: number) => ArrayBuffer | undefined;
export const handleEditorKeyEvent: (handle: number, keyCode: number, text: string | null, modifiers: number) => ArrayBuffer | undefined;

// Font/appearance
export const editorOnFontMetricsChanged: (handle: number) => void;
export const editorSetFoldArrowMode: (handle: number, mode: number) => void;
export const editorSetWrapMode: (handle: number, mode: number) => void;
export const editorSetTabSize: (handle: number, tabSize: number) => void;
export const editorSetInsertSpaces: (handle: number, enabled: number) => void;
export const editorSetKeyMap: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetScale: (handle: number, scale: number) => void;
export const editorSetLineSpacing: (handle: number, add: number, mult: number) => void;
export const editorSetContentStartPadding: (handle: number, padding: number) => void;
export const editorSetShowSplitLine: (handle: number, show: boolean) => void;
export const editorSetCurrentLineRenderMode: (handle: number, mode: number) => void;
export const editorSetGutterSticky: (handle: number, sticky: boolean) => void;
export const editorSetGutterVisible: (handle: number, visible: boolean) => void;

// Text editing
export const editorInsertText: (handle: number, text: string) => ArrayBuffer | undefined;
export const editorReplaceText: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number, text: string) => ArrayBuffer | undefined;
export const editorDeleteText: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number) => ArrayBuffer | undefined;
export const editorBackspace: (handle: number) => ArrayBuffer | undefined;
export const editorDeleteForward: (handle: number) => ArrayBuffer | undefined;

// Line operations
export const editorMoveLineUp: (handle: number) => ArrayBuffer | undefined;
export const editorMoveLineDown: (handle: number) => ArrayBuffer | undefined;
export const editorCopyLineUp: (handle: number) => ArrayBuffer | undefined;
export const editorCopyLineDown: (handle: number) => ArrayBuffer | undefined;
export const editorDeleteLine: (handle: number) => ArrayBuffer | undefined;
export const editorInsertLineAbove: (handle: number) => ArrayBuffer | undefined;
export const editorInsertLineBelow: (handle: number) => ArrayBuffer | undefined;

// Undo/redo
export const editorUndo: (handle: number) => ArrayBuffer | undefined;
export const editorRedo: (handle: number) => ArrayBuffer | undefined;
export const editorCanUndo: (handle: number) => boolean;
export const editorCanRedo: (handle: number) => boolean;

// Cursor/selection
export const editorSetCursorPosition: (handle: number, line: number, column: number) => void;
export const editorGetCursorPosition: (handle: number) => number[];
export const editorSelectAll: (handle: number) => void;
export const editorSetSelection: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number) => void;
export const editorGetSelection: (handle: number) => number[] | null;
export const editorGetSelectedText: (handle: number) => string;
export const editorGetWordRangeAtCursor: (handle: number) => number[];
export const editorGetWordAtCursor: (handle: number) => string;

// Cursor movement
export const editorMoveCursorLeft: (handle: number, extendSelection: boolean) => void;
export const editorMoveCursorRight: (handle: number, extendSelection: boolean) => void;
export const editorMoveCursorUp: (handle: number, extendSelection: boolean) => void;
export const editorMoveCursorDown: (handle: number, extendSelection: boolean) => void;
export const editorMoveCursorToLineStart: (handle: number, extendSelection: boolean) => void;
export const editorMoveCursorToLineEnd: (handle: number, extendSelection: boolean) => void;

// IME composition
export const editorCompositionStart: (handle: number) => void;
export const editorCompositionUpdate: (handle: number, text: string | null) => void;
export const editorCompositionEnd: (handle: number, committedText?: string | null) => ArrayBuffer | undefined;
export const editorCompositionCancel: (handle: number) => void;
export const editorIsComposing: (handle: number) => boolean;
export const editorSetCompositionEnabled: (handle: number, enabled: boolean) => void;
export const editorIsCompositionEnabled: (handle: number) => boolean;

// Read-only
export const editorSetReadOnly: (handle: number, readOnly: boolean) => void;
export const editorIsReadOnly: (handle: number) => boolean;

// Auto indent
export const editorSetAutoIndentMode: (handle: number, mode: number) => void;
export const editorGetAutoIndentMode: (handle: number) => number;
export const editorSetBackspaceUnindent: (handle: number, enabled: number) => void;

// Handle/scrollbar config
export const editorSetHandleConfig: (handle: number, startLeft: number, startTop: number, startRight: number, startBottom: number, endLeft: number, endTop: number, endRight: number, endBottom: number) => void;
export const editorSetScrollbarConfig: (handle: number, thickness: number, minThumb: number, thumbHitPadding: number, mode: number, thumbDraggable: boolean, trackTapMode: number, fadeDelayMs: number, fadeDurationMs: number) => void;

// Position query
export const editorGetPositionRect: (handle: number, line: number, column: number) => number[];
export const editorGetCursorRect: (handle: number) => number[];

// Scrolling/navigation
export const editorScrollToLine: (handle: number, line: number, behavior: number) => void;
export const editorGotoPosition: (handle: number, line: number, column: number) => void;
export const editorEnsureCursorVisible: (handle: number) => void;
export const editorSetScroll: (handle: number, scrollX: number, scrollY: number) => void;
export const editorGetScrollMetrics: (handle: number) => ArrayBuffer | undefined;

// Style/highlight
export const editorRegisterTextStyle: (handle: number, styleId: number, color: number, backgroundColor: number, fontStyle: number) => void;
export const editorRegisterBatchTextStyles: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetLineSpans: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBatchLineSpans: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorClearLineSpans: (handle: number, line: number, layer: number) => void;
export const editorClearHighlights: (handle: number) => void;
export const editorClearHighlightsLayer: (handle: number, layer: number) => void;

// InlayHint/PhantomText
export const editorSetLineInlayHints: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBatchLineInlayHints: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetLinePhantomTexts: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBatchLinePhantomTexts: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorClearInlayHints: (handle: number) => void;
export const editorClearPhantomTexts: (handle: number) => void;

// Gutter icons
export const editorSetLineGutterIcons: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBatchLineGutterIcons: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetMaxGutterIcons: (handle: number, count: number) => void;
export const editorClearGutterIcons: (handle: number) => void;

// Diagnostics
export const editorSetLineDiagnostics: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBatchLineDiagnostics: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorClearDiagnostics: (handle: number) => void;

// Guides
export const editorSetIndentGuides: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetBracketGuides: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetFlowGuides: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorSetSeparatorGuides: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorClearGuides: (handle: number) => void;

// Bracket pairs
export const editorSetBracketPairs: (handle: number, openChars: number[], closeChars: number[]) => void;
export const editorSetAutoClosingPairs: (handle: number, openChars: number[], closeChars: number[]) => void;
export const editorSetMatchedBrackets: (handle: number, openLine: number, openCol: number, closeLine: number, closeCol: number) => void;
export const editorClearMatchedBrackets: (handle: number) => void;

// Code folding
export const editorSetFoldRegions: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorToggleFold: (handle: number, line: number) => boolean;
export const editorFoldAt: (handle: number, line: number) => boolean;
export const editorUnfoldAt: (handle: number, line: number) => boolean;
export const editorFoldAll: (handle: number) => void;
export const editorUnfoldAll: (handle: number) => void;
export const editorIsLineVisible: (handle: number, line: number) => boolean;

// Clear all
export const editorClearAllDecorations: (handle: number) => void;

// Linked editing
export const editorInsertSnippet: (handle: number, snippetTemplate: string) => ArrayBuffer | undefined;
export const editorStartLinkedEditing: (handle: number, data: ArrayBuffer, size: number) => void;
export const editorIsInLinkedEditing: (handle: number) => boolean;
export const editorLinkedEditingNext: (handle: number) => boolean;
export const editorLinkedEditingPrev: (handle: number) => boolean;
export const editorCancelLinkedEditing: (handle: number) => void;

// TextMeasurer interface (passed to createEditor)
export interface TextMeasurer {
  measureWidth(text: string, fontStyle: number): number;
  measureInlayHintWidth(text: string): number;
  measureIconWidth(iconId: number): number;
  getFontAscent(): number;
  getFontDescent(): number;
}
