//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_IME_H
#define SWEETEDITOR_IME_H

#include "ime_types.h"

namespace NS_SWEETEDITOR {

  class CompositionController {
  public:
    class Host {
    public:
      virtual ~Host() = default;

      virtual bool imeHasDocument() const = 0;
      virtual bool imeReadOnly() const = 0;
      virtual bool imeIsLinkedEditingActive() const = 0;
      virtual TextPosition imeCursor() const = 0;
      virtual bool imeHasSelection() const = 0;
      virtual TextRange imeSelection() const = 0;
      virtual TextRange imeClampDocumentRange(const TextRange& range) const = 0;
      virtual bool imeIsDocumentRangeReadable(const TextRange& range) const = 0;
      virtual U8String imeDocumentText(const TextRange& range) const = 0;
      virtual size_t imeDocumentLineCount() const = 0;
      virtual uint32_t imeLineColumns(size_t line) const = 0;
      virtual size_t imeCharIndexFromPosition(const TextPosition& position) const = 0;
      virtual TextPosition imePositionAfterInsert(const TextPosition& start, const U8String& text) const = 0;
      virtual size_t imeUtf16Columns(const U8String& text) const = 0;
      virtual TextEditResult imeApplyEdit(const TextRange& range, const U8String& text) = 0;
      virtual TextEditResult imeInsertText(const U8String& text) = 0;
      virtual void imeDeleteSelectionForComposition() = 0;
      virtual void imeDeleteDocumentRange(const TextRange& range) = 0;
      virtual void imeInsertDocumentText(const TextPosition& position, const U8String& text) = 0;
      virtual TextEditResult imeBackspace() = 0;
      virtual TextEditResult imeDeleteForward() = 0;
      virtual TextEditResult imeDeleteCodePointBackward() = 0;
      virtual TextEditResult imeDeleteCodePointForward() = 0;
      virtual void imeSetCursorPosition(const TextPosition& cursor) = 0;
      virtual void imeSetSelection(const TextRange& range) = 0;
      virtual void imeSetCursorPositionInternal(const TextPosition& cursor) = 0;
      virtual void imeSetSelectionInternal(const TextRange& range) = 0;
      virtual void imeSetRawCursorPosition(const TextPosition& cursor) = 0;
      virtual void imeInvalidateContentMetrics(size_t line) = 0;
      virtual void imeEnsureCursorVisible() = 0;
    };

    ImeActionResult updatePreedit(Host& host,
                                  const U8String& text,
                                  ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitText(Host& host,
                               const U8String& text,
                               ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult finishPreedit(Host& host);
    ImeActionResult cancelPreedit(Host& host);
    ImeActionResult markDocumentRange(Host& host,
                                       const TextRange& range,
                                       ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult replaceText(Host& host,
                                const TextRange& range,
                                const U8String& text,
                                ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitDocumentRangeReplacement(Host& host,
                                                   const TextRange& range,
                                                   const U8String& text,
                                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult deleteBackward(Host& host,
                                   size_t before_length = 1,
                                   ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteForward(Host& host,
                                  size_t after_length = 1,
                                  ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteSurrounding(Host& host,
                                      size_t before_length,
                                      size_t after_length,
                                      ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult notifySelectionChanged(Host& host, const TextRange& range);
    ImeActionResult notifyCursorChanged(Host& host, const TextPosition& cursor);
    ImeSyncSnapshot buildSyncSnapshot(const Host& host) const;

    TextEditResult setComposingText(Host& host, const U8String& text);
    TextEditResult commitComposingText(Host& host,
                                       const U8String& committed_text,
                                       bool empty_text_keeps_composition = false);
    void cancelComposing(Host& host);
    void removeComposingText(Host& host);
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

    struct HostState {
      TextPosition cursor;
      bool has_selection {false};
      TextRange selection;
    };

    static ImeScriptClass classifyScriptFromText(const U8String& text);
    static bool isNonLatinScript(ImeScriptClass script_class);
    static bool isInlineCandidateText(const U8String& text);
    static size_t calcUtf16Columns(const U8String& text);
    static HostState captureHostState(const Host& host);
    void finishAction(Host& host, ImeActionResult& result, const HostState& state) const;
    static void mergeEditResult(ImeActionResult& result, const TextEditResult& edit_result);
    void observeKeyboardScriptClass(ImeScriptClass script_class);
    ImeScriptClass resolveScriptClass(const U8String& text, ImeScriptClass script_class) const;

    SessionState m_session_;
    CompositionState m_composition_;
    ImeScriptClass m_keyboard_script_class_ {ImeScriptClass::UNKNOWN};

    void setComposingRange(Host& host, const TextRange& range);
    TextEditResult finishComposing(Host& host);
    TextEditResult applyDocumentRangePlainEdit(Host& host, const U8String& text);
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

    void beginComposingTextSession(Host& host);
    bool hasMidDocumentRangeComposition(const CompositionState& composition,
                                        const TextPosition& cursor) const;
    bool resolveDocumentRangePlainEdit(const CompositionState& composition,
                                       const TextPosition& cursor,
                                       const U8String& text,
                                       TextRange& range,
                                       U8String& replacement) const;
    bool hasMidDocumentRangeComposition(const Host& host) const;
    bool resolveDocumentRangePlainEdit(const Host& host,
                                       const U8String& text,
                                       TextRange& range,
                                       U8String& replacement) const;
    bool hasEndDocumentRangeComposition(const Host& host) const;
    bool resolveDocumentRangeInsertedText(const Host& host,
                                          const U8String& text,
                                          U8String& replacement) const;
    TextEditResult applyDocumentRangeEndReplacement(Host& host,
                                                    const TextRange& range,
                                                    const U8String& replacement,
                                                    const U8String& preedit_text,
                                                    const U8String& inserted_text,
                                                    bool is_commit);
    TextEditResult applyDocumentRangeEndPlainEdit(Host& host, const U8String& text, bool is_commit);
    TextEditResult applyPlainLatinInputLockEdit(Host& host, const U8String& text, bool is_commit);
    bool trySuppressCandidateCommit(Host& host, const U8String& text);
    bool trySuppressCandidateMark(Host& host, const TextRange& range);
    void updateCandidateWindowAfterDelete(Host& host);
    void handleUpdatePreedit(Host& host, ImeActionResult& result, const U8String& text, ImeScriptClass script_class);
    void handleCommitText(Host& host, ImeActionResult& result, const U8String& text, ImeScriptClass script_class);
    void handleFinishPreedit(Host& host, ImeActionResult& result);
    void handleCancelPreedit(Host& host);
    void handleMarkDocumentRange(Host& host, const TextRange& range);
    void handleDelete(Host& host,
                      ImeActionResult& result,
                      size_t before_length,
                      size_t after_length,
                      ImeTextUnit text_unit);
    void handleSelectionChanged(Host& host, const TextRange& range);
    void handleCursorChanged(Host& host, const TextPosition& cursor);
    bool tryDeleteFromDocumentRangeEnd(Host& host,
                                       ImeActionResult& result,
                                       size_t before_length,
                                       size_t after_length,
                                       ImeTextUnit text_unit);
    void handleReplaceText(Host& host, ImeActionResult& result, const TextRange& range, const U8String& text);
  };

}

#endif //SWEETEDITOR_IME_H
