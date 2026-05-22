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
export const setEditorViewport: (handle: number, width: number, height: number) => ArrayBuffer | undefined;
export const setEditorDocument: (handle: number, documentHandle: number) => ArrayBuffer | undefined;

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
export const editorOnFontMetricsChanged: (handle: number) => ArrayBuffer | undefined;
export const editorSetFoldArrowMode: (handle: number, mode: number) => ArrayBuffer | undefined;
export const editorSetWrapMode: (handle: number, mode: number) => ArrayBuffer | undefined;
export const editorSetTabSize: (handle: number, tabSize: number) => ArrayBuffer | undefined;
export const editorSetInsertSpaces: (handle: number, enabled: number) => ArrayBuffer | undefined;
export const editorSetKeyMap: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetScale: (handle: number, scale: number) => ArrayBuffer | undefined;
export const editorSetLineSpacing: (handle: number, add: number, mult: number) => ArrayBuffer | undefined;
export const editorSetContentStartPadding: (handle: number, padding: number) => ArrayBuffer | undefined;
export const editorSetShowSplitLine: (handle: number, show: boolean) => ArrayBuffer | undefined;
export const editorSetCurrentLineRenderMode: (handle: number, mode: number) => ArrayBuffer | undefined;
export const editorSetGutterSticky: (handle: number, sticky: boolean) => ArrayBuffer | undefined;
export const editorSetGutterVisible: (handle: number, visible: boolean) => ArrayBuffer | undefined;

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
export const editorSetCursorPosition: (handle: number, line: number, column: number) => ArrayBuffer | undefined;
export const editorGetCursorPosition: (handle: number) => number[];
export const editorSelectAll: (handle: number) => ArrayBuffer | undefined;
export const editorSetSelection: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number) => ArrayBuffer | undefined;
export const editorGetSelection: (handle: number) => number[] | null;
export const editorGetSelectedText: (handle: number) => string;
export const editorGetWordRangeAtCursor: (handle: number) => number[];
export const editorGetWordAtCursor: (handle: number) => string;

// Cursor movement
export const editorMoveCursorLeft: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;
export const editorMoveCursorRight: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;
export const editorMoveCursorUp: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;
export const editorMoveCursorDown: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;
export const editorMoveCursorToLineStart: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;
export const editorMoveCursorToLineEnd: (handle: number, extendSelection: boolean) => ArrayBuffer | undefined;

// IME composition
export const editorIsComposing: (handle: number) => boolean;
export const editorGetComposingRange: (handle: number) => number[];
export const editorGetComposingSessionRange: (handle: number) => number[];
export const editorImeUpdatePreedit: (handle: number, text: string | null, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeSetComposingText: (handle: number, text: string | null, cursorOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeSetComposingTextSelection: (handle: number, text: string | null, selectionStartOffset: number, selectionEndOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeCommitText: (handle: number, text: string | null, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeFinishPreedit: (handle: number) => ArrayBuffer | undefined;
export const editorImeCancelPreedit: (handle: number) => ArrayBuffer | undefined;
export const editorImeMarkDocumentRange: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeMarkDocumentRangeByOffset: (handle: number, startOffset: number, endOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeReplaceText: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number, text: string | null, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeReplaceDocumentText: (handle: number, startOffset: number, endOffset: number, text: string | null, cursorOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeReplaceInputContextText: (handle: number, startOffset: number, endOffset: number, text: string | null, cursorOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeMarkInputContextRange: (handle: number, startOffset: number, endOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeNotifyDocumentSelectionChanged: (handle: number, startOffset: number, endOffset: number) => ArrayBuffer | undefined;
export const editorImeNotifyInputContextSelectionChanged: (handle: number, startOffset: number, endOffset: number) => ArrayBuffer | undefined;
export const editorImeUpdateInputStateText: (handle: number, contextId: number, documentStartOffset: number, text: string | null, selectionStartOffset: number, selectionEndOffset: number, composingStartOffset: number, composingEndOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeUpdateInputStateSelection: (handle: number, contextId: number, documentStartOffset: number, selectionStartOffset: number, selectionEndOffset: number) => ArrayBuffer | undefined;
export const editorImeReplaceInputStateText: (handle: number, contextId: number, documentStartOffset: number, startOffset: number, endOffset: number, text: string | null, cursorOffset: number, scriptHint: number) => ArrayBuffer | undefined;
export const editorImeDeleteBackward: (handle: number, beforeLength: number, textUnit: number) => ArrayBuffer | undefined;
export const editorImeDeleteForward: (handle: number, afterLength: number, textUnit: number) => ArrayBuffer | undefined;
export const editorImeDeleteSurrounding: (handle: number, beforeLength: number, afterLength: number, textUnit: number) => ArrayBuffer | undefined;
export const editorImeNotifySelectionChanged: (handle: number, startLine: number, startColumn: number, endLine: number, endColumn: number) => ArrayBuffer | undefined;
export const editorImeNotifyCursorChanged: (handle: number, cursorLine: number, cursorColumn: number) => ArrayBuffer | undefined;
export const editorImeSetKeyboardScriptClass: (handle: number, scriptClass: number) => ArrayBuffer | undefined;
export const editorImeGetKeyboardScriptClass: (handle: number) => number;
export const editorGetImeSyncSnapshot: (handle: number) => ArrayBuffer | undefined;
export const editorGetImeInputContext: (handle: number, beforeLength: number, afterLength: number) => ArrayBuffer | undefined;

// Read-only
export const editorSetReadOnly: (handle: number, readOnly: boolean) => ArrayBuffer | undefined;
export const editorIsReadOnly: (handle: number) => boolean;

// Auto indent
export const editorSetAutoIndentMode: (handle: number, mode: number) => ArrayBuffer | undefined;
export const editorGetAutoIndentMode: (handle: number) => number;
export const editorSetBackspaceUnindent: (handle: number, enabled: number) => ArrayBuffer | undefined;

// Handle/scrollbar config
export const editorSetHandleConfig: (handle: number, startLeft: number, startTop: number, startRight: number, startBottom: number, endLeft: number, endTop: number, endRight: number, endBottom: number) => ArrayBuffer | undefined;
export const editorSetScrollbarConfig: (handle: number, thickness: number, minThumb: number, thumbHitPadding: number, mode: number, thumbDraggable: boolean, trackTapMode: number, fadeDelayMs: number, fadeDurationMs: number) => ArrayBuffer | undefined;

// Position query
export const editorGetPositionRect: (handle: number, line: number, column: number) => number[];
export const editorGetCursorRect: (handle: number) => number[];

// Scrolling/navigation
export const editorScrollToLine: (handle: number, line: number, behavior: number) => ArrayBuffer | undefined;
export const editorGotoPosition: (handle: number, line: number, column: number) => ArrayBuffer | undefined;
export const editorEnsureCursorVisible: (handle: number) => ArrayBuffer | undefined;
export const editorSetScroll: (handle: number, scrollX: number, scrollY: number) => ArrayBuffer | undefined;
export const editorGetScrollMetrics: (handle: number) => ArrayBuffer | undefined;

// Style/highlight
export const editorRegisterTextStyle: (handle: number, styleId: number, color: number, backgroundColor: number, fontStyle: number) => ArrayBuffer | undefined;
export const editorRegisterBatchTextStyles: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetLineSpans: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineSpans: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearLineSpans: (handle: number, line: number, layer: number) => ArrayBuffer | undefined;
export const editorClearHighlights: (handle: number) => ArrayBuffer | undefined;
export const editorClearHighlightsLayer: (handle: number, layer: number) => ArrayBuffer | undefined;

// InlayHint/PhantomText
export const editorSetLineInlayHints: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineInlayHints: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetLinePhantomTexts: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLinePhantomTexts: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearInlayHints: (handle: number) => ArrayBuffer | undefined;
export const editorClearPhantomTexts: (handle: number) => ArrayBuffer | undefined;

// Gutter icons
export const editorSetLineGutterIcons: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineGutterIcons: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetMaxGutterIcons: (handle: number, count: number) => ArrayBuffer | undefined;
export const editorClearGutterIcons: (handle: number) => ArrayBuffer | undefined;

// CodeLens
export const editorSetLineCodeLens: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineCodeLens: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearCodeLens: (handle: number) => ArrayBuffer | undefined;

// Links
export const editorSetLineLinks: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineLinks: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearLinks: (handle: number) => ArrayBuffer | undefined;
export const editorGetLinkTargetAt: (handle: number, line: number, column: number) => string;

// Diagnostics
export const editorSetLineDiagnostics: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBatchLineDiagnostics: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearDiagnostics: (handle: number) => ArrayBuffer | undefined;

// Guides
export const editorSetIndentGuides: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetBracketGuides: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetFlowGuides: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorSetSeparatorGuides: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorClearGuides: (handle: number) => ArrayBuffer | undefined;

// Bracket pairs
export const editorSetBracketPairs: (handle: number, openChars: number[], closeChars: number[]) => ArrayBuffer | undefined;
export const editorSetAutoClosingPairs: (handle: number, openChars: number[], closeChars: number[]) => ArrayBuffer | undefined;
export const editorSetMatchedBrackets: (handle: number, openLine: number, openCol: number, closeLine: number, closeCol: number) => ArrayBuffer | undefined;
export const editorClearMatchedBrackets: (handle: number) => ArrayBuffer | undefined;

// Code folding
export const editorSetFoldRegions: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorToggleFold: (handle: number, line: number) => ArrayBuffer | undefined;
export const editorFoldAt: (handle: number, line: number) => ArrayBuffer | undefined;
export const editorUnfoldAt: (handle: number, line: number) => ArrayBuffer | undefined;
export const editorFoldAll: (handle: number) => ArrayBuffer | undefined;
export const editorUnfoldAll: (handle: number) => ArrayBuffer | undefined;
export const editorIsLineVisible: (handle: number, line: number) => boolean;
export const editorGetVisibleLineRange: (handle: number) => number[];

// Clear all
export const editorClearAllDecorations: (handle: number) => ArrayBuffer | undefined;

// Linked editing
export const editorInsertSnippet: (handle: number, snippetTemplate: string) => ArrayBuffer | undefined;
export const editorStartLinkedEditing: (handle: number, data: ArrayBuffer, size: number) => ArrayBuffer | undefined;
export const editorIsInLinkedEditing: (handle: number) => boolean;
export const editorLinkedEditingNext: (handle: number) => ArrayBuffer | undefined;
export const editorLinkedEditingPrev: (handle: number) => ArrayBuffer | undefined;
export const editorCancelLinkedEditing: (handle: number) => ArrayBuffer | undefined;

// TextMeasurer interface (passed to createEditor)
export interface TextMeasurer {
  measureWidth(text: string, fontStyle: number): number;
  measureInlayHintWidth(text: string): number;
  measureIconWidth(iconId: number): number;
  getFontAscent(): number;
  getFontDescent(): number;
}
