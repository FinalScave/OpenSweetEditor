#include "napi/native_api.h"
#include "napi_editor.hpp"

#define NAPI_METHOD(name, func) { name, nullptr, func, nullptr, nullptr, nullptr, napi_default, nullptr }

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        // Document API
        NAPI_METHOD("createDocumentFromString", DocumentNapi::createFromString),
        NAPI_METHOD("createDocumentFromFile", DocumentNapi::createFromFile),
        NAPI_METHOD("freeDocument", DocumentNapi::destroy),
        NAPI_METHOD("getDocumentText", DocumentNapi::getText),
        NAPI_METHOD("getDocumentLineCount", DocumentNapi::getLineCount),
        NAPI_METHOD("getDocumentLineText", DocumentNapi::getLineText),

        // EditorCore lifecycle
        NAPI_METHOD("createEditor", EditorCoreNapi::create),
        NAPI_METHOD("freeEditor", EditorCoreNapi::destroy),
        NAPI_METHOD("setEditorViewport", EditorCoreNapi::setViewport),
        NAPI_METHOD("setEditorDocument", EditorCoreNapi::loadDocument),

        // Rendering
        NAPI_METHOD("buildEditorRenderModel", EditorCoreNapi::buildRenderModel),
        NAPI_METHOD("getLayoutMetrics", EditorCoreNapi::getLayoutMetrics),

        // Gesture/keyboard
        NAPI_METHOD("handleEditorGestureEvent", EditorCoreNapi::handleGestureEvent),
        NAPI_METHOD("handleEditorGestureEventEx", EditorCoreNapi::handleGestureEventEx),
        NAPI_METHOD("editorTickEdgeScroll", EditorCoreNapi::tickEdgeScroll),
        NAPI_METHOD("editorTickFling", EditorCoreNapi::tickFling),
        NAPI_METHOD("editorTickAnimations", EditorCoreNapi::tickAnimations),
        NAPI_METHOD("handleEditorKeyEvent", EditorCoreNapi::handleKeyEvent),

        // Font/appearance
        NAPI_METHOD("editorOnFontMetricsChanged", EditorCoreNapi::onFontMetricsChanged),
        NAPI_METHOD("editorSetFoldArrowMode", EditorCoreNapi::setFoldArrowMode),
        NAPI_METHOD("editorSetWrapMode", EditorCoreNapi::setWrapMode),
        NAPI_METHOD("editorSetTabSize", EditorCoreNapi::setTabSize),
        NAPI_METHOD("editorSetScale", EditorCoreNapi::setScale),
        NAPI_METHOD("editorSetLineSpacing", EditorCoreNapi::setLineSpacing),
        NAPI_METHOD("editorSetContentStartPadding", EditorCoreNapi::setContentStartPadding),
        NAPI_METHOD("editorSetShowSplitLine", EditorCoreNapi::setShowSplitLine),
        NAPI_METHOD("editorSetCurrentLineRenderMode", EditorCoreNapi::setCurrentLineRenderMode),
        NAPI_METHOD("editorSetGutterSticky", EditorCoreNapi::setGutterSticky),
        NAPI_METHOD("editorSetGutterVisible", EditorCoreNapi::setGutterVisible),

        // Text editing
        NAPI_METHOD("editorInsertText", EditorCoreNapi::insertText),
        NAPI_METHOD("editorReplaceText", EditorCoreNapi::replaceText),
        NAPI_METHOD("editorDeleteText", EditorCoreNapi::deleteText),
        NAPI_METHOD("editorBackspace", EditorCoreNapi::backspace),
        NAPI_METHOD("editorDeleteForward", EditorCoreNapi::deleteForward),

        // Line operations
        NAPI_METHOD("editorMoveLineUp", EditorCoreNapi::moveLineUp),
        NAPI_METHOD("editorMoveLineDown", EditorCoreNapi::moveLineDown),
        NAPI_METHOD("editorCopyLineUp", EditorCoreNapi::copyLineUp),
        NAPI_METHOD("editorCopyLineDown", EditorCoreNapi::copyLineDown),
        NAPI_METHOD("editorDeleteLine", EditorCoreNapi::deleteLine),
        NAPI_METHOD("editorInsertLineAbove", EditorCoreNapi::insertLineAbove),
        NAPI_METHOD("editorInsertLineBelow", EditorCoreNapi::insertLineBelow),

        // Undo/redo
        NAPI_METHOD("editorUndo", EditorCoreNapi::undo),
        NAPI_METHOD("editorRedo", EditorCoreNapi::redo),
        NAPI_METHOD("editorCanUndo", EditorCoreNapi::canUndo),
        NAPI_METHOD("editorCanRedo", EditorCoreNapi::canRedo),

        // Cursor/selection
        NAPI_METHOD("editorSetCursorPosition", EditorCoreNapi::setCursorPosition),
        NAPI_METHOD("editorGetCursorPosition", EditorCoreNapi::getCursorPosition),
        NAPI_METHOD("editorSelectAll", EditorCoreNapi::selectAll),
        NAPI_METHOD("editorSetSelection", EditorCoreNapi::setSelection),
        NAPI_METHOD("editorGetSelection", EditorCoreNapi::getSelection),
        NAPI_METHOD("editorGetSelectedText", EditorCoreNapi::getSelectedText),
        NAPI_METHOD("editorGetWordRangeAtCursor", EditorCoreNapi::getWordRangeAtCursor),
        NAPI_METHOD("editorGetWordAtCursor", EditorCoreNapi::getWordAtCursor),

        // Cursor movement
        NAPI_METHOD("editorMoveCursorLeft", EditorCoreNapi::moveCursorLeft),
        NAPI_METHOD("editorMoveCursorRight", EditorCoreNapi::moveCursorRight),
        NAPI_METHOD("editorMoveCursorUp", EditorCoreNapi::moveCursorUp),
        NAPI_METHOD("editorMoveCursorDown", EditorCoreNapi::moveCursorDown),
        NAPI_METHOD("editorMoveCursorToLineStart", EditorCoreNapi::moveCursorToLineStart),
        NAPI_METHOD("editorMoveCursorToLineEnd", EditorCoreNapi::moveCursorToLineEnd),

        // IME composition
        NAPI_METHOD("editorCompositionStart", EditorCoreNapi::compositionStart),
        NAPI_METHOD("editorCompositionUpdate", EditorCoreNapi::compositionUpdate),
        NAPI_METHOD("editorCompositionEnd", EditorCoreNapi::compositionEnd),
        NAPI_METHOD("editorCompositionCancel", EditorCoreNapi::compositionCancel),
        NAPI_METHOD("editorIsComposing", EditorCoreNapi::isComposing),
        NAPI_METHOD("editorSetCompositionEnabled", EditorCoreNapi::setCompositionEnabled),
        NAPI_METHOD("editorIsCompositionEnabled", EditorCoreNapi::isCompositionEnabled),

        // Read-only
        NAPI_METHOD("editorSetReadOnly", EditorCoreNapi::setReadOnly),
        NAPI_METHOD("editorIsReadOnly", EditorCoreNapi::isReadOnly),

        // Auto indent
        NAPI_METHOD("editorSetAutoIndentMode", EditorCoreNapi::setAutoIndentMode),
        NAPI_METHOD("editorGetAutoIndentMode", EditorCoreNapi::getAutoIndentMode),
        NAPI_METHOD("editorSetBackspaceUnindent", EditorCoreNapi::setBackspaceUnindent),
        NAPI_METHOD("editorSetInsertSpaces", EditorCoreNapi::setInsertSpaces),
        NAPI_METHOD("editorSetKeyMap", EditorCoreNapi::setKeyMap),

        // Handle/scrollbar config
        NAPI_METHOD("editorSetHandleConfig", EditorCoreNapi::setHandleConfig),
        NAPI_METHOD("editorSetScrollbarConfig", EditorCoreNapi::setScrollbarConfig),

        // Position query
        NAPI_METHOD("editorGetPositionRect", EditorCoreNapi::getPositionRect),
        NAPI_METHOD("editorGetCursorRect", EditorCoreNapi::getCursorRect),

        // Scrolling/navigation
        NAPI_METHOD("editorScrollToLine", EditorCoreNapi::scrollToLine),
        NAPI_METHOD("editorGotoPosition", EditorCoreNapi::gotoPosition),
        NAPI_METHOD("editorEnsureCursorVisible", EditorCoreNapi::ensureCursorVisible),
        NAPI_METHOD("editorSetScroll", EditorCoreNapi::setScroll),
        NAPI_METHOD("editorGetScrollMetrics", EditorCoreNapi::getScrollMetrics),

        // Style/highlight
        NAPI_METHOD("editorRegisterTextStyle", EditorCoreNapi::registerTextStyle),
        NAPI_METHOD("editorRegisterBatchTextStyles", EditorCoreNapi::registerBatchTextStyles),
        NAPI_METHOD("editorSetLineSpans", EditorCoreNapi::setLineSpans),
        NAPI_METHOD("editorSetBatchLineSpans", EditorCoreNapi::setBatchLineSpans),
        NAPI_METHOD("editorClearLineSpans", EditorCoreNapi::clearLineSpans),
        NAPI_METHOD("editorClearHighlights", EditorCoreNapi::clearHighlights),
        NAPI_METHOD("editorClearHighlightsLayer", EditorCoreNapi::clearHighlightsLayer),

        // InlayHint/PhantomText
        NAPI_METHOD("editorSetLineInlayHints", EditorCoreNapi::setLineInlayHints),
        NAPI_METHOD("editorSetBatchLineInlayHints", EditorCoreNapi::setBatchLineInlayHints),
        NAPI_METHOD("editorSetLinePhantomTexts", EditorCoreNapi::setLinePhantomTexts),
        NAPI_METHOD("editorSetBatchLinePhantomTexts", EditorCoreNapi::setBatchLinePhantomTexts),
        NAPI_METHOD("editorClearInlayHints", EditorCoreNapi::clearInlayHints),
        NAPI_METHOD("editorClearPhantomTexts", EditorCoreNapi::clearPhantomTexts),

        // Gutter icons
        NAPI_METHOD("editorSetLineGutterIcons", EditorCoreNapi::setLineGutterIcons),
        NAPI_METHOD("editorSetBatchLineGutterIcons", EditorCoreNapi::setBatchLineGutterIcons),
        NAPI_METHOD("editorSetMaxGutterIcons", EditorCoreNapi::setMaxGutterIcons),
        NAPI_METHOD("editorClearGutterIcons", EditorCoreNapi::clearGutterIcons),

        // Diagnostics
        NAPI_METHOD("editorSetLineDiagnostics", EditorCoreNapi::setLineDiagnostics),
        NAPI_METHOD("editorSetBatchLineDiagnostics", EditorCoreNapi::setBatchLineDiagnostics),
        NAPI_METHOD("editorClearDiagnostics", EditorCoreNapi::clearDiagnostics),

        // Guides
        NAPI_METHOD("editorSetIndentGuides", EditorCoreNapi::setIndentGuides),
        NAPI_METHOD("editorSetBracketGuides", EditorCoreNapi::setBracketGuides),
        NAPI_METHOD("editorSetFlowGuides", EditorCoreNapi::setFlowGuides),
        NAPI_METHOD("editorSetSeparatorGuides", EditorCoreNapi::setSeparatorGuides),
        NAPI_METHOD("editorClearGuides", EditorCoreNapi::clearGuides),

        // Bracket pairs
        NAPI_METHOD("editorSetBracketPairs", EditorCoreNapi::setBracketPairs),
        NAPI_METHOD("editorSetAutoClosingPairs", EditorCoreNapi::setAutoClosingPairs),
        NAPI_METHOD("editorSetMatchedBrackets", EditorCoreNapi::setMatchedBrackets),
        NAPI_METHOD("editorClearMatchedBrackets", EditorCoreNapi::clearMatchedBrackets),

        // Code folding
        NAPI_METHOD("editorSetFoldRegions", EditorCoreNapi::setFoldRegions),
        NAPI_METHOD("editorToggleFold", EditorCoreNapi::toggleFold),
        NAPI_METHOD("editorFoldAt", EditorCoreNapi::foldAt),
        NAPI_METHOD("editorUnfoldAt", EditorCoreNapi::unfoldAt),
        NAPI_METHOD("editorFoldAll", EditorCoreNapi::foldAll),
        NAPI_METHOD("editorUnfoldAll", EditorCoreNapi::unfoldAll),
        NAPI_METHOD("editorIsLineVisible", EditorCoreNapi::isLineVisible),

        // Clear all
        NAPI_METHOD("editorClearAllDecorations", EditorCoreNapi::clearAllDecorations),

        // Linked editing
        NAPI_METHOD("editorInsertSnippet", EditorCoreNapi::insertSnippet),
        NAPI_METHOD("editorStartLinkedEditing", EditorCoreNapi::startLinkedEditing),
        NAPI_METHOD("editorIsInLinkedEditing", EditorCoreNapi::isInLinkedEditing),
        NAPI_METHOD("editorLinkedEditingNext", EditorCoreNapi::linkedEditingNext),
        NAPI_METHOD("editorLinkedEditingPrev", EditorCoreNapi::linkedEditingPrev),
        NAPI_METHOD("editorCancelLinkedEditing", EditorCoreNapi::cancelLinkedEditing),
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module sweetEditorModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "sweeteditor",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterSweeteditorModule(void)
{
    napi_module_register(&sweetEditorModule);
}
