//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_IME_COMPOSITION_H
#define SWEETEDITOR_IME_COMPOSITION_H

#include <optional>
#include <sweeteditor/ime_types.h>

namespace NS_SWEETEDITOR {

  class EditorCore;
  class RenderComposer;

  class CompositionController {
  public:
    explicit CompositionController(EditorCore& editor);

    TextEditResult finishPreedit();
    TextEditResult cancelPreedit();

  private:
    friend class EditorCore;
    friend class RenderComposer;

    ImeActionResult applyCommandBatch(const Vector<ImeCommand>& commands);
    ImeActionResult applyTextUpdatePlan(
        const Vector<DocumentReplacement>& replacements, const std::optional<TextRange>& composition_after,
        const std::optional<TextRange>& rollover_baseline, const U8String& composition_text,
        const CaretState& caret_after, bool finish_after);

    enum class EndpointBias {
      BEFORE,
      AFTER,
    };

    struct EditTransaction {
      Vector<DocumentReplacement> physical_replacements;
      Vector<TextChange> committed_changes;
      CaretState caret_before;
      CaretState caret_after;
      std::optional<size_t> composition_replacement_index;
      std::optional<U8String> composition_text;
      std::optional<TextRange> composition_baseline_range;
      bool update_composition {false};
      std::optional<CompositionState> composition_after;
      bool cancel_linked_editing {false};
      bool break_history_merge {false};
    };

    EditorCore& m_editor_;

    std::optional<CompositionState>& compositionState();
    const std::optional<CompositionState>& compositionState() const;

    static U8String logicalizeLineEndings(const U8String& text);
    static TextChangeKind replacementChangeKind(const TextRange& range, const U8String& text);
    bool coreHasDocument() const;
    bool coreReadOnly() const;
    U8String coreDocumentText(const TextRange& range) const;
    std::optional<TextRange> projectCommittedRange(const TextRange& range) const;
    std::optional<TextPosition> projectCommittedAnchor(const TextPosition& position, EndpointBias bias) const;
    Vector<size_t> committedSourceLinesForEditingLine(size_t editing_line) const;
    TextPosition corePositionAfterInsert(const TextPosition& start, const U8String& text) const;
    static TextPosition transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                          const TextPosition& position, EndpointBias bias);
    static bool ownsCompositionText(const CompositionState& state);
    bool hasNonIdentityProjection(const CompositionState& state) const;
    TextRange baselineRange(const CompositionState& state) const;
    CaretState transformCaretForChanges(const CaretState& caret, const Vector<TextChange>& changes) const;
    bool isDocumentRangeValid(const TextRange& range) const;
    bool validateTransaction(const EditTransaction& transaction) const;
    void appendLinkedCompositionEdits(const CompositionState& state, const TextRange& baseline_range,
                                      const U8String& final_text_raw, EditTransaction& transaction);
    bool linkedRangesAffectedByChanges(const Vector<TextChange>& changes) const;
    void beginComposition(const TextRange& range, EditTransaction& transaction);
    void replaceCompositionText(const U8String& text, EditTransaction& transaction);
    void settleComposition(const U8String& final_text_raw, EditTransaction& transaction,
                           bool replace_current_text);
    void cancelComposition(EditTransaction& transaction);
    TextEditResult commitTransaction(EditTransaction& transaction);
    Vector<TextRange> deletionRangesForCaret(const CaretState& caret, size_t before_length,
                                             size_t after_length, ImeTextUnit text_unit) const;
  };

}

#endif //SWEETEDITOR_IME_COMPOSITION_H
