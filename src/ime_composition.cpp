//
// Created by Scave on 2025/12/1.
//
#include <algorithm>
#include <utility>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {

  CompositionController::CompositionController(EditorCore& editor): m_editor_(editor) {
  }

  std::optional<CompositionState>& CompositionController::compositionState() {
    return m_editor_.m_ime_session_->composition;
  }

  const std::optional<CompositionState>& CompositionController::compositionState() const {
    static const std::optional<CompositionState> empty;
    return m_editor_.m_ime_session_.has_value()
        ? m_editor_.m_ime_session_->composition
        : empty;
  }

  U8String CompositionController::logicalizeLineEndings(const U8String& text) {
    U8String logical;
    logical.reserve(text.size());
    for (size_t index = 0; index < text.size(); ++index) {
      if (text[index] == '\r') {
        if (index + 1 < text.size() && text[index + 1] == '\n') {
          ++index;
        }
        logical.push_back('\n');
      } else {
        logical.push_back(text[index]);
      }
    }
    return logical;
  }

  TextChangeKind CompositionController::replacementChangeKind(const TextRange& range, const U8String& text) {
    if (range.isCollapsed()) {
      return text.empty() ? TextChangeKind::NONE : TextChangeKind::INSERTION;
    }
    return text.empty() ? TextChangeKind::DELETION : TextChangeKind::REPLACEMENT;
  }

  bool CompositionController::coreHasDocument() const {
    return m_editor_.m_document_ != nullptr;
  }

  bool CompositionController::coreReadOnly() const {
    return m_editor_.m_settings_.read_only;
  }

  U8String CompositionController::coreDocumentText(const TextRange& range) const {
    return coreHasDocument() ? m_editor_.m_document_->getU8Text(range) : U8String {};
  }

  TextPosition CompositionController::corePositionAfterInsert(const TextPosition& start, const U8String& text) const {
    return m_editor_.calcPositionAfterInsert(start, text);
  }

  TextPosition CompositionController::transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                                        const TextPosition& position, EndpointBias bias) {
    const TextRange range = old_range.normalized();
    if (position < range.start) {
      return position;
    }
    if (position <= range.end) {
      return bias == EndpointBias::BEFORE ? range.start : new_end;
    }
    return range.transformPositionAfterEdit(position, new_end);
  }

  bool CompositionController::ownsCompositionText(const CompositionState& state) {
    return state.baseline_text_raw.has_value();
  }

  bool CompositionController::hasNonIdentityProjection(const CompositionState& state) const {
    return ownsCompositionText(state)
        && logicalizeLineEndings(coreDocumentText(state.current_range))
            != logicalizeLineEndings(*state.baseline_text_raw);
  }

  TextRange CompositionController::baselineRange(const CompositionState& state) const {
    if (!ownsCompositionText(state)) {
      return state.current_range;
    }
    const TextPosition end = corePositionAfterInsert(
        state.current_range.start,
        logicalizeLineEndings(*state.baseline_text_raw));
    return {state.current_range.start, end};
  }

  CaretState CompositionController::transformCaretForChanges(const CaretState& caret,
                                                             const Vector<TextChange>& changes) const {
    CaretState transformed = caret;
    for (auto it = changes.rbegin(); it != changes.rend(); ++it) {
      const TextPosition new_end = corePositionAfterInsert(it->range.start, it->new_text);
      const bool active_collapsed = it->range.start <= transformed.active
          && transformed.active <= it->range.end;
      transformed.anchor = transformPosition(
          it->range, new_end, transformed.anchor, EndpointBias::BEFORE);
      transformed.active = transformPosition(
          it->range, new_end, transformed.active, EndpointBias::AFTER);
      if (active_collapsed) {
        transformed.active_affinity = CaretAffinity::DOWNSTREAM;
      }
    }
    return transformed;
  }

  bool CompositionController::isDocumentRangeValid(const TextRange& range) const {
    if (!coreHasDocument() || range.end < range.start) {
      return false;
    }
    if (range.start.line >= m_editor_.m_document_->getLineCount()
        || range.end.line >= m_editor_.m_document_->getLineCount()) {
      return false;
    }
    const U16String& start_line = m_editor_.m_document_->getLineU16TextRef(range.start.line);
    const U16String& end_line = range.start.line == range.end.line
        ? start_line
        : m_editor_.m_document_->getLineU16TextRef(range.end.line);
    return range.start.column <= start_line.size()
        && range.end.column <= end_line.size()
        && UnicodeUtil::isCodePointBoundary(start_line, range.start.column)
        && UnicodeUtil::isCodePointBoundary(end_line, range.end.column);
  }

  bool CompositionController::validateTransaction(
      const EditTransaction& transaction) const {
    Vector<const DocumentReplacement*> replacements;
    replacements.reserve(transaction.physical_replacements.size());
    for (const DocumentReplacement& replacement : transaction.physical_replacements) {
      if (replacement.range.isCollapsed() && replacement.text.empty()) {
        continue;
      }
      if (!isDocumentRangeValid(replacement.range)) {
        return false;
      }
      replacements.push_back(&replacement);
    }
    std::sort(replacements.begin(), replacements.end(),
              [](const DocumentReplacement* lhs, const DocumentReplacement* rhs) {
                if (lhs->range.start != rhs->range.start) {
                  return lhs->range.start < rhs->range.start;
                }
                return lhs->range.end < rhs->range.end;
              });
    for (size_t index = 1; index < replacements.size(); ++index) {
      if (replacements[index - 1]->range.overlaps(replacements[index]->range)) {
        return false;
      }
    }
    return true;
  }

  void CompositionController::beginComposition(const TextRange& range, EditTransaction& transaction) {
    const TextRange safe_range = m_editor_.clampDocumentRange(
        range.normalized(), true, false);
    CompositionState state;
    state.current_range = safe_range;
    state.baseline_caret = transaction.caret_after;
    transaction.update_composition = true;
    transaction.composition_after = std::move(state);
  }

  void CompositionController::replaceCompositionText(const U8String& text, EditTransaction& transaction) {
    std::optional<CompositionState> state = transaction.update_composition
        ? transaction.composition_after
        : compositionState();
    if (!state.has_value()) {
      const TextRange range = m_editor_.m_caret_.hasSelection()
          ? m_editor_.m_caret_.normalizedSelection()
          : TextRange {m_editor_.m_caret_.active, m_editor_.m_caret_.active};
      beginComposition(range, transaction);
      state = transaction.composition_after;
    }

    const TextRange current_range = state->current_range;
    if (!ownsCompositionText(*state)) {
      state->baseline_text_raw = coreDocumentText(current_range);
      transaction.composition_baseline_range = current_range;
      transaction.break_history_merge = true;
    }
    if (transaction.composition_replacement_index.has_value()) {
      transaction.physical_replacements[*transaction.composition_replacement_index].text = text;
    } else if (coreDocumentText(current_range) != text) {
      transaction.composition_replacement_index = transaction.physical_replacements.size();
      transaction.physical_replacements.push_back({current_range, text});
    }
    const TextPosition new_end = corePositionAfterInsert(current_range.start, text);
    state->current_range = {current_range.start, new_end};
    transaction.update_composition = true;
    transaction.composition_after = std::move(state);
    transaction.composition_text = text;
    transaction.caret_after.setSelection({new_end, new_end});
  }

  bool CompositionController::stageLinkedEdit(
      const TextRange& range, const U8String& text, EditTransaction& transaction) {
    if (!m_editor_.isInLinkedEditing()) return false;
    const std::optional<Vector<DocumentReplacement>> plan = m_editor_.planLinkedEdit(range, text);
    if (!plan.has_value()) {
      transaction.cancel_linked_editing = true;
      return false;
    }
    for (const DocumentReplacement& replacement : *plan) {
      const U8String old_text = coreDocumentText(replacement.range);
      transaction.physical_replacements.push_back(replacement);
      transaction.committed_changes.push_back({replacement.range, old_text, replacement.text});
    }
    return true;
  }

  void CompositionController::appendLinkedCompositionEdits(
      const CompositionState& state, const TextRange& baseline_range,
      const U8String& final_text_raw, EditTransaction& transaction) {
    LinkedEditingSession* session = m_editor_.m_linked_editing_session_.get();
    if (session == nullptr) {
      return;
    }
    const TabStopGroup* group = session->currentGroup();
    if (!m_editor_.hasValidLinkedEditingGroup() || group == nullptr) {
      transaction.cancel_linked_editing = true;
      return;
    }
    if (group->ranges.size() < 2) {
      return;
    }

    size_t owner_count = 0;
    size_t owner_index = group->ranges.size();
    for (size_t index = 0; index < group->ranges.size(); ++index) {
      const TextRange& range = group->ranges[index];
      const bool owns_baseline = baseline_range.isCollapsed()
          ? range.start <= baseline_range.start && baseline_range.start <= range.end
          : range.start <= baseline_range.start && baseline_range.end <= range.end;
      if (owns_baseline) {
        ++owner_count;
        owner_index = index;
      }
    }
    if (owner_count != 1 || owner_index != 0) {
      transaction.cancel_linked_editing = true;
      return;
    }

    const TextRange& primary = group->ranges[0];
    TextRange editing_primary;
    if (primary == baseline_range) {
      editing_primary = state.current_range;
    } else {
      editing_primary.start = primary.start == baseline_range.start
          ? state.current_range.start
          : primary.start;
        editing_primary.end = primary.end == baseline_range.end
          ? state.current_range.end
          : transformPosition(baseline_range, state.current_range.end, primary.end, EndpointBias::AFTER);
    }
    if (!isDocumentRangeValid(editing_primary)
        || state.current_range.start < editing_primary.start
        || editing_primary.end < state.current_range.end) {
      transaction.cancel_linked_editing = true;
      return;
    }

    const U8String prefix = coreDocumentText({editing_primary.start, state.current_range.start});
    const U8String suffix = coreDocumentText({state.current_range.end, editing_primary.end});
    const U8String linked_text = prefix + final_text_raw + suffix;
    const Vector<std::pair<TextRange, U8String>> edits = session->computeLinkedEdits(linked_text);
    for (const auto& [committed_range, edit_text] : edits) {
      if (committed_range == group->ranges[0]) continue;
      const std::optional<TextRange> projected = projectCommittedRange(committed_range);
      if (!projected.has_value() || !isDocumentRangeValid(*projected)) {
        transaction.cancel_linked_editing = true;
        return;
      }
      const TextRange& editing_secondary = *projected;
      const U8String secondary_text = coreDocumentText(editing_secondary);
      if (secondary_text == edit_text) continue;
      transaction.physical_replacements.push_back({editing_secondary, edit_text});
      transaction.committed_changes.push_back({committed_range, secondary_text, edit_text});
    }
  }

  bool CompositionController::linkedRangesAffectedByChanges(const Vector<TextChange>& changes) const {
    if (m_editor_.m_linked_editing_session_ == nullptr
        || !m_editor_.m_linked_editing_session_->isActive()) {
      return false;
    }
    const Vector<LinkedEditingHighlight> highlights =
        m_editor_.m_linked_editing_session_->getAllHighlights();
    for (const TextChange& change : changes) {
      for (const LinkedEditingHighlight& highlight : highlights) {
        const bool affected = change.range.isCollapsed()
            ? highlight.range.start <= change.range.start
                && change.range.start <= highlight.range.end
            : change.range.overlaps(highlight.range)
                || (highlight.range.isCollapsed()
                    && change.range.start <= highlight.range.start
                    && highlight.range.start <= change.range.end);
        if (affected) {
          return true;
        }
      }
    }
    return false;
  }

  void CompositionController::settleComposition(const U8String& final_text_raw, EditTransaction& transaction,
                                                bool replace_current_text) {
    const std::optional<CompositionState>& staged_composition = transaction.update_composition
        ? transaction.composition_after
        : compositionState();
    if (!staged_composition.has_value()) {
      return;
    }

    const CompositionState state = *staged_composition;
    if (!ownsCompositionText(state)) {
      if (replace_current_text) {
        const U8String old_text = coreDocumentText(state.current_range);
        if (old_text != final_text_raw) {
          transaction.composition_replacement_index =
              transaction.physical_replacements.size();
          transaction.physical_replacements.push_back({state.current_range, final_text_raw});
          transaction.composition_text = final_text_raw;
          transaction.committed_changes.push_back({state.current_range, old_text, final_text_raw});
        }
        const TextPosition caret = corePositionAfterInsert(state.current_range.start, final_text_raw);
        transaction.caret_after.setSelection({caret, caret});
        transaction.break_history_merge = true;
      }
      transaction.update_composition = true;
      transaction.composition_after.reset();
      return;
    }
    const TextRange baseline_range = transaction.composition_baseline_range.value_or(baselineRange(state));
    const bool has_net_change = logicalizeLineEndings(final_text_raw)
        != logicalizeLineEndings(*state.baseline_text_raw);

    transaction.caret_before = state.baseline_caret;
    transaction.break_history_merge = true;
    if (!has_net_change) {
      const U8String current_text = replace_current_text
          ? final_text_raw
          : transaction.composition_replacement_index.has_value()
              ? *transaction.composition_text
              : coreDocumentText(state.current_range);
      if (current_text != *state.baseline_text_raw) {
        if (transaction.composition_replacement_index.has_value()) {
          DocumentReplacement& replacement = transaction.physical_replacements[
              *transaction.composition_replacement_index];
          replacement.text = *state.baseline_text_raw;
        } else {
          transaction.physical_replacements.push_back({state.current_range, *state.baseline_text_raw});
        }
      }
    } else {
      if (replace_current_text) {
        if (transaction.composition_replacement_index.has_value()) {
          transaction.physical_replacements[*transaction.composition_replacement_index].text = final_text_raw;
        } else {
          transaction.physical_replacements.push_back({state.current_range, final_text_raw});
        }
      }
      transaction.committed_changes.push_back({baseline_range, *state.baseline_text_raw, final_text_raw});

      appendLinkedCompositionEdits(state, baseline_range, final_text_raw, transaction);
    }

    if (replace_current_text) {
      const U8String& caret_text = has_net_change
          ? final_text_raw
          : *state.baseline_text_raw;
      const TextPosition caret = corePositionAfterInsert(state.current_range.start, caret_text);
      transaction.caret_after.setSelection({caret, caret});
    }
    transaction.update_composition = true;
    transaction.composition_after.reset();
  }

  void CompositionController::cancelComposition(EditTransaction& transaction) {
    const std::optional<CompositionState>& staged_composition = transaction.update_composition
        ? transaction.composition_after
        : compositionState();
    if (!staged_composition.has_value()) {
      return;
    }
    const CompositionState& composition = *staged_composition;
    if (!ownsCompositionText(composition)) {
      transaction.update_composition = true;
      transaction.composition_after.reset();
      return;
    }
    if (transaction.composition_replacement_index.has_value()) {
      DocumentReplacement& replacement = transaction.physical_replacements[
          *transaction.composition_replacement_index];
      replacement.text = *composition.baseline_text_raw;
    } else if (coreDocumentText(composition.current_range)
        != *composition.baseline_text_raw) {
      transaction.physical_replacements.push_back({composition.current_range, *composition.baseline_text_raw});
    }
    transaction.caret_before = m_editor_.m_caret_;
    transaction.caret_after = composition.baseline_caret;
    transaction.break_history_merge = true;
    transaction.update_composition = true;
    transaction.composition_after.reset();
  }

  TextEditResult CompositionController::commitTransaction(EditTransaction& transaction) {
    TextEditResult result;
    if (!coreHasDocument()) {
      return result;
    }

    std::sort(transaction.committed_changes.begin(),
              transaction.committed_changes.end(),
              [](const TextChange& lhs, const TextChange& rhs) {
                if (lhs.range.start != rhs.range.start) {
                  return lhs.range.start < rhs.range.start;
                }
                return lhs.range.end < rhs.range.end;
              });
    Vector<TextChange> normalized_changes;
    normalized_changes.reserve(transaction.committed_changes.size());
    for (TextChange& change : transaction.committed_changes) {
      if (!normalized_changes.empty()
          && normalized_changes.back().new_text.empty()
          && change.new_text.empty()
          && normalized_changes.back().range.end == change.range.start) {
        normalized_changes.back().range.end = change.range.end;
        normalized_changes.back().old_text += change.old_text;
      } else {
        normalized_changes.push_back(std::move(change));
      }
    }
    transaction.committed_changes = std::move(normalized_changes);

    if (!validateTransaction(transaction)) {
      return result;
    }

    if (!transaction.physical_replacements.empty()) {
      m_editor_.m_document_->replaceU8TextBatch(transaction.physical_replacements);
      result.editing_content_changed = true;
    }

    if (transaction.update_composition) {
      compositionState() = transaction.composition_after;
    }
    if (transaction.cancel_linked_editing
        && m_editor_.m_linked_editing_session_ != nullptr) {
      m_editor_.m_linked_editing_session_->cancel();
      m_editor_.m_linked_editing_session_.reset();
    }

    if (!transaction.committed_changes.empty()) {
      for (auto it = transaction.committed_changes.rbegin();
           it != transaction.committed_changes.rend();
           ++it) {
        const TextPosition new_end = corePositionAfterInsert(it->range.start, it->new_text);
        m_editor_.autoUnfoldForEdit(it->range);
        m_editor_.m_decorations_->adjustForEdit(it->range, new_end);
        if (m_editor_.m_linked_editing_session_ != nullptr) {
          m_editor_.m_linked_editing_session_->adjustRangesForEdit(it->range, new_end);
        }
        result.markHandled(replacementChangeKind(it->range, it->new_text));
      }
      m_editor_.noteDocumentContentChanged();
      result.changes = transaction.committed_changes;
      result.cursor_before = transaction.caret_before.active;
    }

    m_editor_.restoreCaretState(transaction.caret_after);
    result.cursor_after = m_editor_.m_caret_.active;

    if (!transaction.committed_changes.empty()) {
      m_editor_.recordHistory(transaction.committed_changes, transaction.caret_before, transaction.caret_after);
      m_editor_.syncFoldState();
    } else if (!transaction.physical_replacements.empty()
               || transaction.update_composition) {
      m_editor_.syncFoldState();
    }
    if (!transaction.physical_replacements.empty()
        || transaction.update_composition) {
      m_editor_.markAllLinesDirty(true);
    }

    if (transaction.break_history_merge) {
      m_editor_.m_undo_manager_->breakMergeChain();
    }
    if (!transaction.physical_replacements.empty()
        || !transaction.committed_changes.empty()
        || transaction.break_history_merge) {
      m_editor_.ensureCursorVisible();
    }
    return result;
  }

  ImeActionResult CompositionController::applyTextUpdatePlan(
      const Vector<DocumentReplacement>& replacements, const std::optional<TextRange>& composition_after,
      const std::optional<TextRange>& rollover_baseline, const U8String& composition_text,
      const CaretState& caret_after, bool finish_after) {
    ImeActionResult result;
    result.handled = coreHasDocument() && !coreReadOnly();
    if (!result.handled) {
      return result;
    }

    EditTransaction transaction;
    transaction.caret_before = m_editor_.m_caret_;
    transaction.caret_after = caret_after;
    transaction.physical_replacements = replacements;
    transaction.break_history_merge = !replacements.empty();
    const std::optional<CompositionState>& initial_composition = compositionState();
    const bool initial_owns_text = initial_composition.has_value()
        && ownsCompositionText(*initial_composition);
    if (initial_owns_text) {
      transaction.composition_baseline_range = baselineRange(*initial_composition);
    }
    if (!initial_owns_text) {
      if (!composition_after.has_value()) {
        bool linked_edit_staged = false;
        if (!initial_composition.has_value() && replacements.size() == 1
            && m_editor_.isInLinkedEditing()) {
          transaction.physical_replacements.clear();
          linked_edit_staged = stageLinkedEdit(
              replacements.front().range, replacements.front().text, transaction);
          if (!linked_edit_staged) {
            transaction.physical_replacements = replacements;
          }
        }
        if (!linked_edit_staged) {
          transaction.committed_changes.reserve(replacements.size());
          for (const DocumentReplacement& replacement : replacements) {
            const U8String old_text = coreDocumentText(replacement.range);
            if (old_text != replacement.text) {
              transaction.committed_changes.push_back({replacement.range, old_text, replacement.text});
            }
          }
          if (linkedRangesAffectedByChanges(transaction.committed_changes)) {
            transaction.cancel_linked_editing = true;
          }
        }
        if (initial_composition.has_value()) {
          transaction.update_composition = true;
          transaction.composition_after.reset();
        }
      } else {
        if (replacements.size() > 1) {
          result.handled = false;
          return result;
        }
        CompositionState state = initial_composition.value_or(CompositionState {});
        state.current_range = *composition_after;
        if (replacements.empty()) {
          state.baseline_text_raw.reset();
        } else {
          const TextRange baseline = replacements.front().range;
          state.baseline_text_raw = coreDocumentText(baseline);
          transaction.composition_baseline_range = baseline;
          transaction.composition_text = composition_text;
        }
        if (!initial_composition.has_value()) {
          state.baseline_caret = transaction.caret_before;
        }
        transaction.update_composition = true;
        transaction.composition_after = std::move(state);
      }
    } else {
      const TextRange current_range = initial_composition->current_range;
      const CaretState rollover_caret = m_editor_.m_caret_;
      U8String rollover_baseline_text;
      if (rollover_baseline.has_value()) {
        rollover_baseline_text = coreDocumentText(*rollover_baseline);
        settleComposition(coreDocumentText(current_range), transaction, false);
        transaction.composition_baseline_range = *rollover_baseline;
      }
      for (const DocumentReplacement& replacement : replacements) {
        if (rollover_baseline.has_value()
            && replacement.range == *rollover_baseline) {
          continue;
        }
        bool inside = current_range.start <= replacement.range.start
            && replacement.range.end <= current_range.end;
        if (inside && replacement.range.isCollapsed()
            && (replacement.range.start == current_range.start
                || replacement.range.start == current_range.end)
            && composition_after.has_value()) {
          const TextPosition inserted_end = corePositionAfterInsert(replacement.range.start, replacement.text);
          inside = composition_after->start <= replacement.range.start
              && inserted_end <= composition_after->end;
        }
        if (inside) {
          continue;
        }
        if (replacement.range.overlaps(current_range)) {
          if (!replacement.text.empty()) {
            result.handled = false;
            return result;
          }
          const TextRange baseline = baselineRange(*initial_composition);
          const TextPosition left_end = std::min(replacement.range.end, current_range.start);
          if (replacement.range.start < left_end) {
            const TextRange editing_left {replacement.range.start, left_end};
            transaction.committed_changes.push_back({
                {
                    transformPosition(current_range, baseline.end, editing_left.start, EndpointBias::AFTER),
                    transformPosition(current_range, baseline.end, editing_left.end, EndpointBias::BEFORE)
                },
                coreDocumentText(editing_left), ""
            });
          }
          const TextPosition right_start = std::max(replacement.range.start, current_range.end);
          if (right_start < replacement.range.end) {
            const TextRange editing_right {right_start, replacement.range.end};
            transaction.committed_changes.push_back({
                {
                    transformPosition(current_range, baseline.end, editing_right.start, EndpointBias::AFTER),
                    transformPosition(current_range, baseline.end, editing_right.end, EndpointBias::BEFORE)
                },
                coreDocumentText(editing_right), ""
            });
          }
          continue;
        }
        const TextRange baseline = baselineRange(*initial_composition);
        TextRange committed_range;
        if (replacement.range.isCollapsed()
            && replacement.range.start == current_range.start) {
          committed_range = {baseline.start, baseline.start};
        } else if (replacement.range.isCollapsed()
                   && replacement.range.start == current_range.end) {
          committed_range = {baseline.end, baseline.end};
        } else {
          committed_range = {
              transformPosition(current_range, baseline.end, replacement.range.start, EndpointBias::AFTER),
              transformPosition(current_range, baseline.end, replacement.range.end, EndpointBias::BEFORE)
          };
        }
        const U8String old_text = coreDocumentText(replacement.range);
        if (old_text != replacement.text) {
          transaction.committed_changes.push_back({committed_range, old_text, replacement.text});
        }
      }

      if (rollover_baseline.has_value()) {
        CompositionState state;
        state.current_range = *composition_after;
        state.baseline_text_raw = std::move(rollover_baseline_text);
        state.baseline_caret = rollover_caret;
        transaction.update_composition = true;
        transaction.composition_after = std::move(state);
        transaction.composition_text = composition_text;
      } else if (composition_after.has_value()) {
        CompositionState state = *initial_composition;
        state.current_range = *composition_after;
        state.baseline_caret = transformCaretForChanges(state.baseline_caret, transaction.committed_changes);
        transaction.update_composition = true;
        transaction.composition_after = std::move(state);
        transaction.composition_text = composition_text;
      } else {
        settleComposition(composition_text, transaction, false);
      }
    }

    if (finish_after && transaction.composition_after.has_value()) {
      settleComposition(composition_text, transaction, false);
      transaction.caret_after = caret_after;
    }

    if (!validateTransaction(transaction)) {
      result.handled = false;
      return result;
    }
    result.edit_result = commitTransaction(transaction);
    return result;
  }

  ImeActionResult CompositionController::applyCommandBatch(const Vector<ImeCommand>& commands) {
    ImeActionResult result;
    result.handled = coreHasDocument() && !coreReadOnly() && !commands.empty();
    if (!result.handled) {
      return result;
    }

    EditTransaction transaction;
    transaction.caret_before = m_editor_.m_caret_;
    transaction.caret_after = m_editor_.m_caret_;
    const std::optional<CompositionState>& initial_composition = compositionState();
    if (initial_composition.has_value()
        && ownsCompositionText(*initial_composition)) {
      transaction.composition_baseline_range = baselineRange(*initial_composition);
    }
    const size_t initial_document_length = m_editor_.documentUtf16Length();

    auto stagedComposition = [&]() -> const std::optional<CompositionState>& {
      return transaction.update_composition
          ? transaction.composition_after
          : initial_composition;
    };
    auto stagedCompositionOffsets = [&]() -> std::pair<size_t, size_t> {
      const std::optional<CompositionState>& state = stagedComposition();
      if (!state.has_value()) {
        return {0, 0};
      }
      const size_t start = transaction.composition_replacement_index.has_value()
          ? m_editor_.m_document_->getCharIndexFromPosition(
              transaction.physical_replacements[*transaction.composition_replacement_index].range.start)
          : m_editor_.m_document_->getCharIndexFromPosition(state->current_range.start);
      const size_t end = start + (transaction.composition_replacement_index.has_value()
          ? StrUtil::utf16Length(*transaction.composition_text)
          : m_editor_.m_document_->getCharIndexFromPosition(state->current_range.end)
              - m_editor_.m_document_->getCharIndexFromPosition(state->current_range.start));
      return {start, end};
    };
    auto stagedPosition = [&](size_t offset) -> std::optional<TextPosition> {
      Vector<const DocumentReplacement*> replacements;
      replacements.reserve(transaction.physical_replacements.size());
      for (const DocumentReplacement& replacement : transaction.physical_replacements) {
        if (!replacement.range.isCollapsed() || !replacement.text.empty()) {
          replacements.push_back(&replacement);
        }
      }
      std::stable_sort(
          replacements.begin(), replacements.end(),
          [](const DocumentReplacement* lhs, const DocumentReplacement* rhs) {
            if (lhs->range.start != rhs->range.start) {
              return lhs->range.start < rhs->range.start;
            }
            return lhs->range.end < rhs->range.end;
          });

      size_t source_offset = 0;
      size_t staged_offset = 0;
      TextPosition staged_position;
      const auto advanceSource = [&](size_t target_offset) {
        const TextPosition source_start =
            m_editor_.m_document_->getPositionFromCharIndex(source_offset);
        const TextPosition source_end =
            m_editor_.m_document_->getPositionFromCharIndex(target_offset);
        if (source_start.line == source_end.line) {
          staged_position.column += source_end.column - source_start.column;
        } else {
          staged_position.line += source_end.line - source_start.line;
          staged_position.column = source_end.column;
        }
        source_offset = target_offset;
      };

      for (const DocumentReplacement* replacement : replacements) {
        const size_t old_start = m_editor_.m_document_->getCharIndexFromPosition(
            replacement->range.start);
        const size_t old_end = m_editor_.m_document_->getCharIndexFromPosition(
            replacement->range.end);
        if (old_start < source_offset || old_end < old_start
            || old_end > initial_document_length) {
          return std::nullopt;
        }
        const size_t unchanged_length = old_start - source_offset;
        if (offset <= staged_offset + unchanged_length) {
          advanceSource(source_offset + offset - staged_offset);
          return staged_position;
        }
        advanceSource(old_start);
        staged_offset += unchanged_length;

        U16String replacement_text;
        StrUtil::convertUTF8ToUTF16(replacement->text, replacement_text);
        if (offset <= staged_offset + replacement_text.size()) {
          const size_t prefix_length = offset - staged_offset;
          if (!UnicodeUtil::isCodePointBoundary(replacement_text, prefix_length)) {
            return std::nullopt;
          }
          U8String prefix;
          StrUtil::convertUTF16ToUTF8(
              replacement_text.substr(0, prefix_length), prefix);
          return corePositionAfterInsert(staged_position, prefix);
        }
        staged_position = corePositionAfterInsert(staged_position, replacement->text);
        staged_offset += replacement_text.size();
        source_offset = old_end;
      }

      const size_t remaining = offset - staged_offset;
      if (remaining > initial_document_length - source_offset) {
        return std::nullopt;
      }
      advanceSource(source_offset + remaining);
      return staged_position;
    };
    auto resolveRange = [&](const ImeOffsetRange& range) -> std::optional<TextRange> {
      size_t start = static_cast<size_t>(range.start_utf16);
      size_t end = static_cast<size_t>(range.end_utf16);
      if (range.coordinate_space == ImeCoordinateSpace::COMPOSITION) {
        const std::optional<CompositionState>& state = stagedComposition();
        if (!state.has_value()) {
          return std::nullopt;
        }
        const auto offsets = stagedCompositionOffsets();
        if (end > offsets.second - offsets.first) {
          return std::nullopt;
        }
        start += offsets.first;
        end += offsets.first;
      } else if (range.coordinate_space != ImeCoordinateSpace::DOCUMENT) {
        return std::nullopt;
      }
      const std::optional<TextPosition> start_position = stagedPosition(start);
      const std::optional<TextPosition> end_position = stagedPosition(end);
      if (!start_position.has_value() || !end_position.has_value()) {
        return std::nullopt;
      }
      return TextRange {*start_position, *end_position};
    };
    auto resolveSelection = [&](const ImeSelection& selection) -> std::optional<CaretState> {
      ImeOffsetRange range {
          selection.coordinate_space,
          std::min(selection.anchor_utf16, selection.active_utf16),
          std::max(selection.anchor_utf16, selection.active_utf16)
      };
      const std::optional<TextRange> resolved = resolveRange(range);
      if (!resolved.has_value()) {
        return std::nullopt;
      }
      CaretState caret;
      caret.anchor = selection.anchor_utf16 <= selection.active_utf16
          ? resolved->start
          : resolved->end;
      caret.active = selection.anchor_utf16 <= selection.active_utf16
          ? resolved->end
          : resolved->start;
      caret.active_affinity = selection.affinity;
      return caret;
    };

    for (const ImeCommand& command : commands) {
      const bool has_target = command.target_range.start_utf16 >= 0;
      const bool has_selection = command.selection_after.anchor_utf16 >= 0;
      switch (command.kind) {
        case ImeCommandKind::SET_SELECTION: {
          const std::optional<CaretState> caret = resolveSelection(command.selection_after);
          if (!caret.has_value()) {
            result.handled = false;
            return result;
          }
          transaction.caret_after = *caret;
          break;
        }
        case ImeCommandKind::BEGIN_COMPOSITION: {
          if (stagedComposition().has_value()) {
            result.handled = false;
            return result;
          }
          const std::optional<TextRange> range = resolveRange(command.target_range);
          if (!range.has_value()) {
            result.handled = false;
            return result;
          }
          beginComposition(*range, transaction);
          break;
        }
        case ImeCommandKind::UPDATE_COMPOSITION: {
          const bool was_active = stagedComposition().has_value();
          if (!was_active) {
            std::optional<TextRange> target;
            if (has_target) {
              if (command.target_range.coordinate_space != ImeCoordinateSpace::DOCUMENT) {
                result.handled = false;
                return result;
              }
              target = resolveRange(command.target_range);
              if (!target.has_value()) {
                result.handled = false;
                return result;
              }
            }
            const TextRange range = target.value_or(
                transaction.caret_after.hasSelection()
                    ? transaction.caret_after.normalizedSelection()
                    : TextRange {transaction.caret_after.active, transaction.caret_after.active});
            beginComposition(range, transaction);
          }
          U8String composition_text = transaction.composition_text.has_value()
              ? *transaction.composition_text
              : coreDocumentText(stagedComposition()->current_range);
          if (has_target && was_active) {
            if (command.target_range.coordinate_space != ImeCoordinateSpace::COMPOSITION) {
              result.handled = false;
              return result;
            }
            U16String utf16;
            StrUtil::convertUTF8ToUTF16(composition_text, utf16);
            const size_t start = static_cast<size_t>(command.target_range.start_utf16);
            const size_t end = static_cast<size_t>(command.target_range.end_utf16);
            if (end > utf16.size()
                || !UnicodeUtil::isCodePointBoundary(utf16, start)
                || !UnicodeUtil::isCodePointBoundary(utf16, end)) {
              result.handled = false;
              return result;
            }
            U16String replacement;
            StrUtil::convertUTF8ToUTF16(command.text, replacement);
            utf16.replace(start, end - start, replacement);
            StrUtil::convertUTF16ToUTF8(utf16, composition_text);
          } else {
            composition_text = command.text;
          }
          replaceCompositionText(composition_text, transaction);
          break;
        }
        case ImeCommandKind::COMMIT_TEXT: {
          if (stagedComposition().has_value()) {
            if (has_target) {
              result.handled = false;
              return result;
            }
            if (ownsCompositionText(*stagedComposition())) {
              replaceCompositionText(command.text, transaction);
              settleComposition(command.text, transaction, false);
            } else {
              settleComposition(command.text, transaction, true);
            }
          } else {
            std::optional<TextRange> resolved_range;
            if (has_target) {
              resolved_range = resolveRange(command.target_range);
              if (!resolved_range.has_value()) {
                result.handled = false;
                return result;
              }
            }
            const TextRange staged_range = resolved_range.value_or(
                transaction.caret_after.hasSelection()
                    ? transaction.caret_after.normalizedSelection()
                    : TextRange {transaction.caret_after.active, transaction.caret_after.active});
            TextRange physical_range = staged_range;
            if (transaction.composition_replacement_index.has_value()) {
              const DocumentReplacement& composition_replacement = transaction.physical_replacements[
                  *transaction.composition_replacement_index];
              const size_t staged_start = m_editor_.m_document_->getCharIndexFromPosition(
                  composition_replacement.range.start);
              const size_t staged_end = staged_start + StrUtil::utf16Length(composition_replacement.text);
              const size_t target_start = staged_range.start == composition_replacement.range.start
                  ? staged_start
                  : m_editor_.m_document_->getCharIndexFromPosition(staged_range.start);
              const size_t target_end = m_editor_.m_document_->getCharIndexFromPosition(staged_range.end);
              if (target_start < staged_end && staged_start < target_end) {
                result.handled = false;
                return result;
              }
            }
            TextRange committed_range = physical_range;
            if (initial_composition.has_value()
                && ownsCompositionText(*initial_composition)) {
              const TextRange initial_baseline = baselineRange(*initial_composition);
              if (physical_range.overlaps(initial_composition->current_range)) {
                result.handled = false;
                return result;
              }
              committed_range = {
                  transformPosition(initial_composition->current_range, initial_baseline.end,
                                    physical_range.start, EndpointBias::AFTER),
                  transformPosition(initial_composition->current_range, initial_baseline.end,
                                    physical_range.end, EndpointBias::BEFORE)
              };
            }
            bool linked_edit_staged = false;
            if (!initial_composition.has_value()
                && transaction.physical_replacements.empty()
                && m_editor_.isInLinkedEditing()) {
              linked_edit_staged = stageLinkedEdit(physical_range, command.text, transaction);
            }
            if (!linked_edit_staged) {
              const U8String old_text = coreDocumentText(physical_range);
              if (old_text != command.text) {
                transaction.physical_replacements.push_back({physical_range, command.text});
                transaction.committed_changes.push_back({committed_range, old_text, command.text});
              }
            }
            transaction.caret_after.setSelection({
                corePositionAfterInsert(physical_range.start, command.text),
                corePositionAfterInsert(physical_range.start, command.text)
            });
            transaction.break_history_merge = true;
          }
          break;
        }
        case ImeCommandKind::FINISH_COMPOSITION:
          if (stagedComposition().has_value()) {
            const U8String final_text = transaction.composition_text.has_value()
                ? *transaction.composition_text
                : coreDocumentText(stagedComposition()->current_range);
            settleComposition(final_text, transaction, false);
          }
          break;
        case ImeCommandKind::CANCEL_COMPOSITION:
          cancelComposition(transaction);
          break;
        case ImeCommandKind::DELETE_SURROUNDING: {
          if (!transaction.physical_replacements.empty()
              || transaction.composition_replacement_index.has_value()) {
            result.handled = false;
            return result;
          }
          const Vector<TextRange> ranges = deletionRangesForCaret(
              transaction.caret_after, static_cast<size_t>(command.delete_before),
              static_cast<size_t>(command.delete_after), command.text_unit);
          if (ranges.empty()) {
            break;
          }

          const std::optional<CompositionState>& state = stagedComposition();
          const bool owns_text = state.has_value() && ownsCompositionText(*state);
          bool linked_edit_staged = false;
          if (!state.has_value() && ranges.size() == 1 && m_editor_.isInLinkedEditing()) {
            linked_edit_staged = stageLinkedEdit(ranges.front(), "", transaction);
          }
          Vector<TextChange> editing_changes;
          if (!linked_edit_staged) {
            for (const TextRange& range : ranges) {
              transaction.physical_replacements.push_back({range, ""});
              editing_changes.push_back({range, coreDocumentText(range), ""});
              if (!owns_text) {
                transaction.committed_changes.push_back({range, coreDocumentText(range), ""});
                continue;
              }

              const TextRange baseline = baselineRange(*state);
              const TextPosition left_end = std::min(range.end, state->current_range.start);
              if (range.start < left_end) {
                const TextRange editing_left {range.start, left_end};
                transaction.committed_changes.push_back({
                    {
                        transformPosition(state->current_range, baseline.end,
                                          editing_left.start, EndpointBias::AFTER),
                        transformPosition(state->current_range, baseline.end,
                                          editing_left.end, EndpointBias::BEFORE)
                    },
                    coreDocumentText(editing_left), ""
                });
              }
              const TextPosition right_start = std::max(range.start, state->current_range.end);
              if (right_start < range.end) {
                const TextRange editing_right {right_start, range.end};
                transaction.committed_changes.push_back({
                    {
                        transformPosition(state->current_range, baseline.end,
                                          editing_right.start, EndpointBias::AFTER),
                        transformPosition(state->current_range, baseline.end,
                                          editing_right.end, EndpointBias::BEFORE)
                    },
                    coreDocumentText(editing_right), ""
                });
              }
            }
          }
          if (owns_text) {
            U16String composition_text;
            StrUtil::convertUTF8ToUTF16(
                transaction.composition_text.has_value()
                    ? *transaction.composition_text
                    : coreDocumentText(state->current_range), composition_text);
            const size_t composition_start = m_editor_.m_document_->getCharIndexFromPosition(
                state->current_range.start);
            Vector<std::pair<size_t, size_t>> composition_deletions;
            for (const TextRange& range : ranges) {
              const TextPosition overlap_start = std::max(range.start, state->current_range.start);
              const TextPosition overlap_end = std::min(range.end, state->current_range.end);
              if (overlap_start < overlap_end) {
                composition_deletions.push_back({
                    m_editor_.m_document_->getCharIndexFromPosition(overlap_start)
                        - composition_start,
                    m_editor_.m_document_->getCharIndexFromPosition(overlap_end)
                        - composition_start
                });
              }
            }
            for (auto it = composition_deletions.rbegin(); it != composition_deletions.rend(); ++it) {
              composition_text.erase(it->first, it->second - it->first);
            }
            U8String updated_composition_text;
            StrUtil::convertUTF16ToUTF8(composition_text, updated_composition_text);
            transaction.composition_text = std::move(updated_composition_text);
            CompositionState next_state = *state;
            for (auto it = ranges.rbegin(); it != ranges.rend(); ++it) {
              next_state.current_range = {
                  transformPosition(*it, it->start, next_state.current_range.start, EndpointBias::BEFORE),
                  transformPosition(*it, it->start, next_state.current_range.end, EndpointBias::AFTER)
              };
            }
            next_state.baseline_caret = transformCaretForChanges(state->baseline_caret,
                                                                 transaction.committed_changes);
            transaction.update_composition = true;
            transaction.composition_after = next_state;
            transaction.caret_after = transformCaretForChanges(transaction.caret_after, editing_changes);
          } else if (linked_edit_staged) {
            Vector<TextChange> ordered_changes = transaction.committed_changes;
            std::sort(ordered_changes.begin(), ordered_changes.end(),
                      [](const TextChange& lhs, const TextChange& rhs) {
                        return lhs.range.start < rhs.range.start;
                      });
            transaction.caret_after = transformCaretForChanges(
                transaction.caret_after, ordered_changes);
          } else {
            transaction.caret_after = transformCaretForChanges(transaction.caret_after,
                                                               transaction.committed_changes);
            if (state.has_value()) {
              CompositionState next_state = *state;
              for (auto it = ranges.rbegin(); it != ranges.rend(); ++it) {
                next_state.current_range = {
                    transformPosition(*it, it->start, next_state.current_range.start, EndpointBias::BEFORE),
                    transformPosition(*it, it->start, next_state.current_range.end, EndpointBias::AFTER)
                };
              }
              next_state.baseline_caret = transformCaretForChanges(next_state.baseline_caret,
                                                                   transaction.committed_changes);
              transaction.update_composition = true;
              transaction.composition_after = std::move(next_state);
            }
          }
          if (!linked_edit_staged
              && linkedRangesAffectedByChanges(transaction.committed_changes)) {
            transaction.cancel_linked_editing = true;
          }
          transaction.break_history_merge = true;
          break;
        }
      }
      if (has_selection && command.kind != ImeCommandKind::SET_SELECTION) {
        const std::optional<CaretState> caret = resolveSelection(command.selection_after);
        if (!caret.has_value()) {
          result.handled = false;
          return result;
        }
        transaction.caret_after = *caret;
      }
    }

    if (!validateTransaction(transaction)) {
      result.handled = false;
      return result;
    }
    result.edit_result = commitTransaction(transaction);
    return result;
  }

  TextEditResult CompositionController::finishPreedit() {
    TextEditResult result;
    const std::optional<CompositionState>& composition = compositionState();
    if (composition.has_value() && coreHasDocument() && !coreReadOnly()) {
      EditTransaction transaction;
      transaction.caret_before = composition->baseline_caret;
      transaction.caret_after = m_editor_.m_caret_;
      const U8String final_text = coreDocumentText(composition->current_range);
      settleComposition(final_text, transaction, false);
      result = commitTransaction(transaction);
    }
    return result;
  }

  TextEditResult CompositionController::cancelPreedit() {
    TextEditResult result;
    if (compositionState().has_value() && coreHasDocument()) {
      EditTransaction transaction;
      transaction.caret_before = m_editor_.m_caret_;
      transaction.caret_after = m_editor_.m_caret_;
      cancelComposition(transaction);
      result = commitTransaction(transaction);
    }
    return result;
  }

  Vector<TextRange> CompositionController::deletionRangesForCaret(const CaretState& caret, size_t before_length,
                                                                 size_t after_length, ImeTextUnit text_unit) const {
    if (!coreHasDocument()) {
      return {};
    }

    const bool has_selection = caret.hasSelection();
    const TextRange selection = has_selection
        ? caret.normalizedSelection()
        : TextRange {caret.active, caret.active};
    TextPosition start = selection.start;
    TextPosition end = selection.end;
    for (size_t index = 0; index < before_length; ++index) {
      if (start.column > 0) {
        const U16String& line = m_editor_.m_document_->getLineU16TextRef(start.line);
        start.column = text_unit == ImeTextUnit::UNICODE_CODE_POINT
            ? UnicodeUtil::prevCodePointColumn(line, start.column)
            : start.column - 1;
      } else if (start.line > 0) {
        --start.line;
        start.column = m_editor_.m_document_->getLineColumns(start.line);
      }
    }
    for (size_t index = 0; index < after_length; ++index) {
      const U16String& line = m_editor_.m_document_->getLineU16TextRef(end.line);
      if (end.column < line.size()) {
        end.column = text_unit == ImeTextUnit::UNICODE_CODE_POINT
            ? UnicodeUtil::nextCodePointColumn(line, end.column)
            : end.column + 1;
      } else if (end.line + 1 < m_editor_.m_document_->getLineCount()) {
        ++end.line;
        end.column = 0;
      }
    }
    Vector<TextRange> ranges;
    if (has_selection) {
      if (start < selection.start) {
        ranges.push_back({start, selection.start});
      }
      if (selection.end < end) {
        ranges.push_back({selection.end, end});
      }
    } else if (start < end) {
      ranges.push_back({start, end});
    }
    return ranges;
  }

  std::optional<TextRange> CompositionController::projectCommittedRange(const TextRange& range) const {
    const std::optional<CompositionState>& composition = compositionState();
    if (!composition.has_value() || !hasNonIdentityProjection(*composition)) {
      return range;
    }

    const TextRange baseline = baselineRange(*composition);
    const TextRange normalized = range.normalized();
    const bool affected = baseline.isCollapsed()
        ? normalized.start < baseline.start && baseline.start < normalized.end
        : normalized.overlaps(baseline);
    if (affected) {
      return std::nullopt;
    }

    TextRange projected {
        transformPosition(baseline, composition->current_range.end, normalized.start, EndpointBias::AFTER),
        transformPosition(baseline, composition->current_range.end, normalized.end, EndpointBias::BEFORE)
    };
    if (projected.end < projected.start) {
      projected.end = projected.start;
    }
    return projected;
  }

  std::optional<TextPosition> CompositionController::projectCommittedAnchor(const TextPosition& position,
                                                                            EndpointBias bias) const {
    const std::optional<CompositionState>& composition = compositionState();
    if (!composition.has_value() || !hasNonIdentityProjection(*composition)) {
      return position;
    }
    const TextRange baseline = baselineRange(*composition);
    if (!baseline.isCollapsed()
        && baseline.start <= position
        && position < baseline.end) {
      return std::nullopt;
    }
    return transformPosition(baseline, composition->current_range.end, position, bias);
  }

  Vector<size_t> CompositionController::committedSourceLinesForEditingLine(
      size_t editing_line) const {
    const std::optional<CompositionState>& composition = compositionState();
    if (!composition.has_value() || !hasNonIdentityProjection(*composition)) {
      return {editing_line};
    }
    const TextRange baseline = baselineRange(*composition);
    const TextRange current = composition->current_range;
    Vector<size_t> lines;
    const auto append_unique = [&lines](size_t line) {
      if (std::find(lines.begin(), lines.end(), line) == lines.end()) {
        lines.push_back(line);
      }
    };

    if (editing_line < current.start.line) {
      append_unique(editing_line);
    } else if (editing_line > current.end.line) {
      const int64_t line_delta = static_cast<int64_t>(current.end.line)
          - static_cast<int64_t>(baseline.end.line);
      append_unique(TextPosition {editing_line, 0}.withLineDelta(-line_delta).line);
    } else {
      if (editing_line == current.start.line) {
        append_unique(baseline.start.line);
      }
      if (editing_line == current.end.line) {
        append_unique(baseline.end.line);
      }
    }
    return lines;
  }

}
