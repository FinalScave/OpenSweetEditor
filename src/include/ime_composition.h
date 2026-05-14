//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_IME_COMPOSITION_H
#define SWEETEDITOR_IME_COMPOSITION_H

#include "ime_types.h"

namespace NS_SWEETEDITOR {

  class EditorCore;

  class CompositionController {
  public:
    explicit CompositionController(EditorCore& editor);

    ImeActionResult updatePreedit(const U8String& text,
                                  ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitText(const U8String& text,
                               ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult finishPreedit();
    ImeActionResult cancelPreedit();
    ImeActionResult markDocumentRange(const TextRange& range,
                                       ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult replaceText(const TextRange& range,
                                const U8String& text,
                                ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitDocumentRangeReplacement(const TextRange& range,
                                                   const U8String& text,
                                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult deleteBackward(size_t before_length = 1,
                                   ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteForward(size_t after_length = 1,
                                  ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteSurrounding(size_t before_length,
                                      size_t after_length,
                                      ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult notifySelectionChanged(const TextRange& range);
    ImeActionResult notifyCursorChanged(const TextPosition& cursor);
    ImeSyncSnapshot buildSyncSnapshot() const;

    TextEditResult setComposingText(const U8String& text);
    TextEditResult commitComposingText(const U8String& committed_text,
                                       bool empty_text_keeps_composition = false);
    void cancelComposing();
    void removeComposingText();
    void resetCompositionState();

    bool hasComposingSession() const;
    bool hasVisibleComposition() const;
    TextRange currentComposingRange() const;
    const CompositionState& composition() const;

    void setKeyboardScriptClass(ImeScriptClass script_class);
    ImeScriptClass keyboardScriptClass() const;

    void clearPlainLatinInputLock();
    void clearCandidateCommitWindow();

  private:
    /// Core-owned IME session bookkeeping that is not exposed to platform layers.
    struct SessionState {
      bool preedit_text_in_document {false};
      bool preedit_replaces_document_range {false};
      TextRange preedit_replaced_range;
      U8String preedit_replaced_text;
      bool has_shadow_preedit {false};
      U8String shadow_preedit_text;
      ImeScriptClass shadow_script_class {ImeScriptClass::UNKNOWN};
      bool has_candidate_commit_window {false};
      TextRange candidate_committed_range;
      U8String candidate_committed_text;
      bool candidate_deleted_to_prefix {false};
      bool suppress_candidate_exact_range {false};
      bool plain_latin_input_lock {false};
      U8String plain_latin_preedit_text;
      U8String document_range_end_plain_preedit_text;
      U8String document_range_end_plain_inserted_text;
    };

    struct EditorState {
      TextPosition cursor;
      bool has_selection {false};
      TextRange selection;
    };

    static ImeScriptClass classifyScriptFromText(const U8String& text);
    static bool isNonLatinScript(ImeScriptClass script_class);
    static bool isInlineCandidateText(const U8String& text);
    static size_t calcUtf16Columns(const U8String& text);
    EditorState captureEditorState() const;
    void finishAction(ImeActionResult& result, const EditorState& state) const;
    static void mergeEditResult(ImeActionResult& result, const TextEditResult& edit_result);
    void observeKeyboardScriptClass(ImeScriptClass script_class);
    ImeScriptClass resolveScriptClass(const U8String& text, ImeScriptClass script_class) const;

    bool coreHasDocument() const;
    bool coreReadOnly() const;
    bool coreIsLinkedEditingActive() const;
    TextPosition coreCursor() const;
    bool coreHasSelection() const;
    TextRange coreSelection() const;
    TextRange coreClampDocumentRange(const TextRange& range) const;
    bool coreIsDocumentRangeReadable(const TextRange& range) const;
    U8String coreDocumentText(const TextRange& range) const;
    size_t coreDocumentLineCount() const;
    uint32_t coreLineColumns(size_t line) const;
    size_t coreCharIndexFromPosition(const TextPosition& position) const;
    TextPosition corePositionAfterInsert(const TextPosition& start, const U8String& text) const;
    size_t coreUtf16Columns(const U8String& text) const;
    TextEditResult coreApplyEdit(const TextRange& range, const U8String& text);
    TextEditResult coreInsertText(const U8String& text);
    void coreDeleteSelectionForComposition();
    void coreDeleteDocumentRange(const TextRange& range);
    void coreInsertDocumentText(const TextPosition& position, const U8String& text);
    TextEditResult coreBackspace();
    TextEditResult coreDeleteForward();
    TextEditResult coreDeleteCodePointBackward();
    TextEditResult coreDeleteCodePointForward();
    void coreSetCursorPosition(const TextPosition& cursor);
    void coreSetSelection(const TextRange& range);
    void coreSetCursorPositionInternal(const TextPosition& cursor);
    void coreSetSelectionInternal(const TextRange& range);
    void coreSetRawCursorPosition(const TextPosition& cursor);
    void coreInvalidateContentMetrics(size_t line);
    void coreEnsureCursorVisible();

    EditorCore& m_editor_;

    SessionState m_session_;
    CompositionState m_composition_;
    ImeScriptClass m_keyboard_script_class_ {ImeScriptClass::UNKNOWN};

    void setComposingRange(const TextRange& range);
    TextEditResult finishComposing();
    TextEditResult applyDocumentRangePlainEdit(const U8String& text);
    bool canMoveSelectionInsideComposition(const TextRange& range) const;
    void clearShadowPreedit();
    void setShadowPreedit(const U8String& text, ImeScriptClass script_class);
    void beginPlainLatinInputLock(const U8String& preedit_text);
    void trimPlainLatinInputLock(size_t before_length);
    bool shouldUsePlainLatinInputLock(const U8String& text,
                                      ImeScriptClass script_class,
                                      bool is_commit) const;
    bool shouldShadowPlainLatinLockedPreedit(const U8String& text,
                                             ImeScriptClass script_class) const;
    void openCandidateCommitWindow(const TextRange& range, const U8String& text, bool suppress_exact_range);
    void markCandidateDeletedToPrefix();
    void resetSessionPreservingCandidateWindow();

    void beginComposingTextSession();
    bool hasMidDocumentRangeComposition(const CompositionState& composition,
                                        const TextPosition& cursor) const;
    bool resolveDocumentRangePlainEdit(const CompositionState& composition,
                                       const TextPosition& cursor,
                                       const U8String& text,
                                       TextRange& range,
                                       U8String& replacement) const;
    bool hasMidDocumentRangeComposition() const;
    bool resolveDocumentRangePlainEdit(const U8String& text,
                                       TextRange& range,
                                       U8String& replacement) const;
    bool hasEndDocumentRangeComposition() const;
    bool resolveDocumentRangeInsertedText(const U8String& text,
                                          U8String& replacement) const;
    TextEditResult applyDocumentRangeEndReplacement(const TextRange& range,
                                                    const U8String& replacement,
                                                    const U8String& preedit_text,
                                                    const U8String& inserted_text,
                                                    bool is_commit);
    TextEditResult applyDocumentRangeEndPlainEdit(const U8String& text, bool is_commit);
    TextEditResult applyPlainLatinInputLockEdit(const U8String& text, bool is_commit);
    bool trySuppressCandidateCommit(const U8String& text);
    bool trySuppressCandidateMark(const TextRange& range);
    void updateCandidateWindowAfterDelete();
    void handleUpdatePreedit(ImeActionResult& result, const U8String& text, ImeScriptClass script_class);
    void handleCommitText(ImeActionResult& result, const U8String& text, ImeScriptClass script_class);
    void handleFinishPreedit(ImeActionResult& result);
    void handleCancelPreedit();
    void handleMarkDocumentRange(const TextRange& range);
    void handleDelete(ImeActionResult& result,
                      size_t before_length,
                      size_t after_length,
                      ImeTextUnit text_unit);
    void handleSelectionChanged(const TextRange& range);
    void handleCursorChanged(const TextPosition& cursor);
    bool tryDeleteFromDocumentRangeEnd(ImeActionResult& result,
                                       size_t before_length,
                                       size_t after_length,
                                       ImeTextUnit text_unit);
    void handleReplaceText(ImeActionResult& result, const TextRange& range, const U8String& text);
  };

}

#endif //SWEETEDITOR_IME_COMPOSITION_H
