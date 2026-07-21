//
// Created by Scave on 2025/12/1.
//
#include <algorithm>
#include <cstddef>
#include <functional>
#include <limits>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {

  constexpr uint64_t MAX_IME_WIRE_INTEGER = (uint64_t {1} << 53u) - 1;
  constexpr size_t IME_BUFFER_SURROUNDING_LENGTH = 1024;
  constexpr size_t IME_BUFFER_GUARD_LENGTH = 256;
  constexpr size_t IME_BUFFER_HARD_CAP = 65536;

  struct StagedImeCodeUnit {
    char16_t value {0};
    std::optional<size_t> original_offset;
  };

  struct StagedImeReplacement {
    size_t start {0};
    size_t end {0};
    U8String text;
  };

  static bool isKnownMutationModel(ImeMutationModel model) {
    return model == ImeMutationModel::COMMAND || model == ImeMutationModel::TEXT_UPDATE;
  }

  static bool isKnownTextSource(ImeTextSource source) {
    return source == ImeTextSource::EDITING
        || source == ImeTextSource::COMMITTED
        || source == ImeTextSource::EDITING_BUFFER;
  }

  static bool isKnownCoordinateSpace(ImeCoordinateSpace space) {
    return space == ImeCoordinateSpace::DOCUMENT
        || space == ImeCoordinateSpace::EDITING_BUFFER
        || space == ImeCoordinateSpace::CONTEXT_SLICE
        || space == ImeCoordinateSpace::COMPOSITION;
  }

  static bool isKnownTextUnit(ImeTextUnit unit) {
    return unit == ImeTextUnit::UTF16_CODE_UNIT
        || unit == ImeTextUnit::UNICODE_CODE_POINT;
  }

  static bool isKnownCommandKind(ImeCommandKind kind) {
    return kind == ImeCommandKind::SET_SELECTION
        || kind == ImeCommandKind::BEGIN_COMPOSITION
        || kind == ImeCommandKind::UPDATE_COMPOSITION
        || kind == ImeCommandKind::COMMIT_TEXT
        || kind == ImeCommandKind::FINISH_COMPOSITION
        || kind == ImeCommandKind::CANCEL_COMPOSITION
        || kind == ImeCommandKind::DELETE_SURROUNDING;
  }

  static bool isKnownAffinity(CaretAffinity affinity) {
    return affinity == CaretAffinity::DOWNSTREAM || affinity == CaretAffinity::UPSTREAM;
  }

  static bool isNoneRange(const ImeOffsetRange& range) {
    return range.coordinate_space == ImeCoordinateSpace::DOCUMENT
        && range.start_utf16 == -1
        && range.end_utf16 == -1;
  }

  static bool isNoneSelection(const ImeSelection& selection) {
    return selection.coordinate_space == ImeCoordinateSpace::DOCUMENT
        && selection.anchor_utf16 == -1
        && selection.active_utf16 == -1
        && selection.affinity == CaretAffinity::DOWNSTREAM;
  }

  static bool isValidRangeShape(const ImeOffsetRange& range) {
    return isKnownCoordinateSpace(range.coordinate_space)
        && range.start_utf16 >= 0
        && static_cast<uint64_t>(range.start_utf16) <= MAX_IME_WIRE_INTEGER
        && static_cast<uint64_t>(range.end_utf16) <= MAX_IME_WIRE_INTEGER
        && range.end_utf16 >= range.start_utf16;
  }

  static bool isValidSelectionShape(const ImeSelection& selection) {
    return isKnownCoordinateSpace(selection.coordinate_space)
        && isKnownAffinity(selection.affinity)
        && selection.anchor_utf16 >= 0
        && selection.active_utf16 >= 0
        && static_cast<uint64_t>(selection.anchor_utf16) <= MAX_IME_WIRE_INTEGER
        && static_cast<uint64_t>(selection.active_utf16) <= MAX_IME_WIRE_INTEGER;
  }

  static U8String logicalizeLineEndings(const U8String& text) {
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

  static U8String utf16Slice(const U8String& text, size_t start, size_t end) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);
    start = std::min(start, utf16.size());
    end = std::min(std::max(start, end), utf16.size());
    U8String result;
    StrUtil::convertUTF16ToUTF8(utf16.substr(start, end - start), result);
    return result;
  }

  static bool isUtf16Boundary(const U8String& text, size_t offset) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);
    return offset <= utf16.size() && UnicodeUtil::isCodePointBoundary(utf16, offset);
  }

  static Vector<StagedImeCodeUnit> makeStagedImeText(const U8String& text) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);
    Vector<StagedImeCodeUnit> staged;
    staged.reserve(utf16.size());
    for (size_t index = 0; index < utf16.size(); ++index) {
      staged.push_back({utf16[index], index});
    }
    return staged;
  }

  static void replaceStagedImeText(Vector<StagedImeCodeUnit>& staged, size_t start, size_t end,
                                   const U8String& replacement_text) {
    U16String replacement;
    StrUtil::convertUTF8ToUTF16(replacement_text, replacement);
    Vector<StagedImeCodeUnit> replacement_units;
    replacement_units.reserve(replacement.size());
    for (char16_t value : replacement) {
      replacement_units.push_back({value, std::nullopt});
    }
    staged.erase(staged.begin() + static_cast<ptrdiff_t>(start),
                 staged.begin() + static_cast<ptrdiff_t>(end));
    staged.insert(staged.begin() + static_cast<ptrdiff_t>(start), replacement_units.begin(),
                  replacement_units.end());
  }

  static Vector<StagedImeReplacement> buildStagedImeReplacements(const Vector<StagedImeCodeUnit>& staged,
                                                                 size_t original_length) {
    Vector<StagedImeReplacement> replacements;
    size_t original_offset = 0;
    U16String replacement_text;
    auto flush = [&](size_t end) {
      if (original_offset == end && replacement_text.empty()) {
        return;
      }
      U8String utf8;
      StrUtil::convertUTF16ToUTF8(replacement_text, utf8);
      replacements.push_back({original_offset, end, std::move(utf8)});
      replacement_text.clear();
      original_offset = end;
    };
    for (const StagedImeCodeUnit& unit : staged) {
      if (!unit.original_offset.has_value()) {
        replacement_text.push_back(unit.value);
        continue;
      }
      flush(*unit.original_offset);
      original_offset = *unit.original_offset + 1;
    }
    flush(original_length);
    return replacements;
  }

  static size_t transformImeOffset(size_t offset, size_t start, size_t end,
                                   size_t replacement_length, bool after) {
    if (offset < start || (offset == start && !after)) {
      return offset;
    }
    if (offset > end || (offset == end && after)) {
      return offset - (end - start) + replacement_length;
    }
    return after ? start + replacement_length : start;
  }

  static void appendImeEditResult(TextEditResult& target, const TextEditResult& source) {
    target.editing_content_changed = target.editing_content_changed
        || source.editing_content_changed;
    if (!source.contentChanged()) {
      return;
    }
    if (!target.contentChanged()) {
      target = source;
      return;
    }
    target.markHandled(source.change_kind);
    target.changes.insert(target.changes.end(), source.changes.begin(), source.changes.end());
    target.cursor_after = source.cursor_after;
  }

  ImeState EditorCore::emptyImeState(ImeResultCode result_code) const {
    ImeState state;
    state.result_code = result_code;
    return state;
  }

  ImeState EditorCore::buildImeState() const {
    if (!m_ime_session_.has_value() || m_document_ == nullptr) {
      return emptyImeState(ImeResultCode::OK);
    }

    ImeState state;
    state.result_code = ImeResultCode::OK;
    state.session_id = m_ime_session_->session_id;
    state.state_revision = m_ime_session_->editing_buffer.has_value()
        ? m_ime_session_->editing_buffer->state_revision
        : 0;
    state.selection = {
        ImeCoordinateSpace::DOCUMENT,
        static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.anchor)),
        static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.active)),
        m_caret_.active_affinity
    };
    if (getCompositionState().has_value()) {
      const TextRange range = getCompositionState()->current_range;
      state.composition_range = {
          ImeCoordinateSpace::DOCUMENT,
          static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.start)),
          static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.end))
      };
    }
    return state;
  }

  bool EditorCore::hasMatchingImeSession(uint64_t session_id) const {
    return session_id != 0
        && m_ime_session_.has_value()
        && m_ime_session_->session_id == session_id;
  }

  bool EditorCore::isImeCommandSession() const {
    return m_ime_session_.has_value() && !m_ime_session_->editing_buffer.has_value();
  }

  bool EditorCore::isImeTextUpdateSession() const {
    return m_ime_session_.has_value() && m_ime_session_->editing_buffer.has_value();
  }

  void EditorCore::closeImeSession() {
    m_ime_session_.reset();
  }

  ImeState EditorCore::beginImeSession(ImeMutationModel mutation_model) {
    if (m_settings_.read_only) {
      return emptyImeState(ImeResultCode::READ_ONLY);
    }
    if (m_document_ == nullptr
        || m_ime_session_.has_value()
        || !isKnownMutationModel(mutation_model)
        || m_next_ime_session_id_ == 0
        || m_next_ime_session_id_ > MAX_IME_WIRE_INTEGER) {
      return emptyImeState(ImeResultCode::REJECTED);
    }

    ImeSessionState session;
    if (mutation_model == ImeMutationModel::TEXT_UPDATE) {
      const size_t document_length = documentUtf16Length();
      const size_t anchor = m_document_->getCharIndexFromPosition(m_caret_.anchor);
      const size_t active = m_document_->getCharIndexFromPosition(m_caret_.active);
      const size_t selection_start = std::min(anchor, active);
      const size_t selection_end = std::max(anchor, active);
      const size_t required_guard = std::min(IME_BUFFER_GUARD_LENGTH, selection_start)
          + std::min(IME_BUFFER_GUARD_LENGTH, document_length - selection_end);
      if (selection_end - selection_start + required_guard > IME_BUFFER_HARD_CAP) {
        return emptyImeState(ImeResultCode::REJECTED);
      }
      const size_t margin = IME_BUFFER_SURROUNDING_LENGTH + IME_BUFFER_GUARD_LENGTH;
      size_t left_length = std::min(margin, selection_start);
      size_t right_length = std::min(margin, document_length - selection_end);
      size_t total_buffer_length = selection_end - selection_start
          + left_length + right_length;
      if (total_buffer_length > IME_BUFFER_HARD_CAP) {
        size_t overflow = total_buffer_length - IME_BUFFER_HARD_CAP;
        const size_t right_guard = std::min(IME_BUFFER_GUARD_LENGTH,
                                            document_length - selection_end);
        const size_t trim_right = std::min(overflow, right_length - right_guard);
        right_length -= trim_right;
        overflow -= trim_right;
        const size_t left_guard = std::min(IME_BUFFER_GUARD_LENGTH, selection_start);
        left_length -= std::min(overflow, left_length - left_guard);
      }
      size_t start = selection_start - left_length;
      size_t end = selection_end + right_length;
      TextPosition start_position = m_document_->getPositionFromCharIndex(start);
      TextPosition end_position = m_document_->getPositionFromCharIndex(end);
      const U16String& start_line = m_document_->getLineU16TextRef(start_position.line);
      const U16String& end_line = m_document_->getLineU16TextRef(end_position.line);
      start_position.column = UnicodeUtil::clampColumnToCodePointBoundaryLeft(
          start_line, start_position.column);
      end_position.column = UnicodeUtil::clampColumnToCodePointBoundaryRight(
          end_line, end_position.column);
      start = m_document_->getCharIndexFromPosition(start_position);
      end = m_document_->getCharIndexFromPosition(end_position);
      EditingBufferState buffer;
      buffer.document_range = {start_position, end_position};
      buffer.text = logicalizeLineEndings(m_document_->getU8Text(buffer.document_range));
      buffer.safe_start_utf16 = static_cast<int64_t>(std::min(IME_BUFFER_GUARD_LENGTH,
                                                              selection_start - start));
      buffer.safe_end_utf16 = static_cast<int64_t>(end - start
          - std::min(IME_BUFFER_GUARD_LENGTH, document_length - selection_end));
      session.editing_buffer = std::move(buffer);
    }
    session.session_id = m_next_ime_session_id_++;
    m_ime_session_ = std::move(session);
    return buildImeState();
  }

  ImeState EditorCore::getImeState(uint64_t session_id) const {
    return hasMatchingImeSession(session_id)
        ? buildImeState()
        : emptyImeState(ImeResultCode::SESSION_MISMATCH);
  }

  const std::optional<CompositionState>& EditorCore::getCompositionState() const {
    return m_composition_controller_.compositionState();
  }

  bool EditorCore::hasPreedit() const {
    return getCompositionState().has_value();
  }

  bool EditorCore::validateImeCommand(const ImeCommand& command) const {
    if (!isKnownCommandKind(command.kind) || !isKnownTextUnit(command.text_unit)) {
      return false;
    }
    const bool has_target = !isNoneRange(command.target_range);
    const bool has_selection = !isNoneSelection(command.selection_after);
    if ((has_target && !isValidRangeShape(command.target_range))
        || (has_selection && !isValidSelectionShape(command.selection_after))) {
      return false;
    }
    switch (command.kind) {
      case ImeCommandKind::SET_SELECTION:
        return !has_target && has_selection && command.text.empty()
            && command.delete_before == 0 && command.delete_after == 0
            && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
      case ImeCommandKind::BEGIN_COMPOSITION:
        return has_target && command.text.empty()
            && command.delete_before == 0 && command.delete_after == 0
            && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
      case ImeCommandKind::UPDATE_COMPOSITION:
      case ImeCommandKind::COMMIT_TEXT:
        return command.delete_before == 0 && command.delete_after == 0
            && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
      case ImeCommandKind::FINISH_COMPOSITION:
      case ImeCommandKind::CANCEL_COMPOSITION:
        return !has_target && !has_selection && command.text.empty()
            && command.delete_before == 0 && command.delete_after == 0
            && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
      case ImeCommandKind::DELETE_SURROUNDING:
        if (has_target || has_selection || !command.text.empty()
            || command.delete_before < 0 || command.delete_after < 0
            || static_cast<uint64_t>(command.delete_before) > MAX_IME_WIRE_INTEGER
            || static_cast<uint64_t>(command.delete_after) > MAX_IME_WIRE_INTEGER
            || static_cast<uint64_t>(command.delete_before) > std::numeric_limits<size_t>::max()
            || static_cast<uint64_t>(command.delete_after) > std::numeric_limits<size_t>::max()) {
          return false;
        }
        return true;
    }
    return false;
  }

  ImeActionResult EditorCore::rejectImeMutation() {
    ImeActionResult result;
    result.handled = true;
    result.state = emptyImeState(ImeResultCode::REJECTED);
    if (hasPreedit()) {
      result.edit_result = m_composition_controller_.finishPreedit();
    }
    closeImeSession();
    result.host_action = m_settings_.read_only
        ? ImeHostAction::CLOSE_SESSION
        : ImeHostAction::RESTART_SESSION;
    return result;
  }

  EditorActionResult EditorCore::applyImeCommands(const ImeCommandBatch& batch) {
    const ActionSnapshot before = captureActionSnapshot();
    if (!hasMatchingImeSession(batch.session_id)) {
      ImeActionResult mismatch;
      mismatch.handled = true;
      mismatch.state = emptyImeState(ImeResultCode::SESSION_MISMATCH);
      return finishImeAction(before, mismatch);
    }
    if (!isImeCommandSession() || batch.commands.empty()) {
      return finishImeAction(before, rejectImeMutation());
    }
    for (const ImeCommand& command : batch.commands) {
      if (!validateImeCommand(command)) {
        return finishImeAction(before, rejectImeMutation());
      }
    }

    ImeActionResult result = m_composition_controller_.applyCommandBatch(batch.commands);
    if (!result.handled) {
      return finishImeAction(before, rejectImeMutation());
    }
    result.state = buildImeState();
    return finishImeAction(before, result);
  }

  bool EditorCore::validateImeTextUpdateStep(const ImeTextUpdateStep& step) const {
    const bool has_patch = !isNoneRange(step.patch_range);
    const bool has_composition = !isNoneRange(step.composition_after);
    if (!isValidSelectionShape(step.selection_after)
        || step.selection_after.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER
        || (has_patch && (!isValidRangeShape(step.patch_range)
            || step.patch_range.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER))
        || (!has_patch && !step.replacement_text.empty())
        || (has_composition && (!isValidRangeShape(step.composition_after)
            || step.composition_after.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER))) {
      return false;
    }
    return true;
  }

  EditorActionResult EditorCore::applyImeTextUpdates(const ImeTextUpdateBatch& batch) {
    const ActionSnapshot before = captureActionSnapshot();
    if (!hasMatchingImeSession(batch.session_id)) {
      ImeActionResult mismatch;
      mismatch.handled = true;
      mismatch.state = emptyImeState(ImeResultCode::SESSION_MISMATCH);
      return finishImeAction(before, mismatch);
    }
    if (!isImeTextUpdateSession() || batch.steps.empty()) {
      return finishImeAction(before, rejectImeMutation());
    }

    EditingBufferState& buffer = *m_ime_session_->editing_buffer;
    if (batch.expected_state_revision != buffer.state_revision) {
      return finishImeAction(before, rejectImeMutation());
    }
    for (const ImeTextUpdateStep& step : batch.steps) {
      if (!validateImeTextUpdateStep(step)) {
        return finishImeAction(before, rejectImeMutation());
      }
    }
    const size_t buffer_start = m_document_->getCharIndexFromPosition(buffer.document_range.start);
    const size_t document_length_before = documentUtf16Length();
    const size_t buffer_end_before = m_document_->getCharIndexFromPosition(buffer.document_range.end);
    const bool hidden_left = buffer_start > 0;
    const bool hidden_right = buffer_end_before < document_length_before;
    size_t safe_start = static_cast<size_t>(buffer.safe_start_utf16);
    size_t safe_end = static_cast<size_t>(buffer.safe_end_utf16);
    bool needs_restart = false;
    const size_t selection_anchor_before =
        m_document_->getCharIndexFromPosition(m_caret_.anchor) - buffer_start;
    const size_t selection_active_before =
        m_document_->getCharIndexFromPosition(m_caret_.active) - buffer_start;
    std::optional<std::pair<size_t, size_t>> composition_before;
    if (hasPreedit()) {
      const TextRange range = getCompositionState()->current_range;
      composition_before = {
          m_document_->getCharIndexFromPosition(range.start) - buffer_start,
          m_document_->getCharIndexFromPosition(range.end) - buffer_start
      };
    }
    U8String staged_text = buffer.text;
    Vector<StagedImeCodeUnit> staged_units = makeStagedImeText(buffer.text);
    std::optional<std::pair<size_t, size_t>> staged_composition = composition_before;
    size_t composition_ownership_transitions = 0;
    for (const ImeTextUpdateStep& step : batch.steps) {
      const size_t text_length = StrUtil::utf16Length(staged_text);
      if (step.old_text != staged_text
          || (!isNoneRange(step.patch_range)
              && static_cast<uint64_t>(step.patch_range.end_utf16) > text_length)) {
        return finishImeAction(before, rejectImeMutation());
      }
      if (!isNoneRange(step.patch_range)) {
        const size_t start = static_cast<size_t>(step.patch_range.start_utf16);
        const size_t end = static_cast<size_t>(step.patch_range.end_utf16);
        if (!isUtf16Boundary(staged_text, start) || !isUtf16Boundary(staged_text, end)) {
          return finishImeAction(before, rejectImeMutation());
        }
        staged_text = utf16Slice(staged_text, 0, start)
            + step.replacement_text
            + utf16Slice(staged_text, end, StrUtil::utf16Length(staged_text));
        replaceStagedImeText(staged_units, start, end, step.replacement_text);
        const size_t replacement_length = StrUtil::utf16Length(step.replacement_text);
        if ((hidden_left && start <= safe_start)
            || (hidden_right && end >= safe_end)) {
          needs_restart = true;
        }
        safe_start = transformImeOffset(safe_start, start, end, replacement_length, true);
        safe_end = transformImeOffset(safe_end, start, end, replacement_length, false);
      }
      const size_t after_length = StrUtil::utf16Length(staged_text);
      if (static_cast<uint64_t>(step.selection_after.anchor_utf16) > after_length
          || static_cast<uint64_t>(step.selection_after.active_utf16) > after_length
          || (!isNoneRange(step.composition_after)
              && static_cast<uint64_t>(step.composition_after.end_utf16) > after_length)) {
        return finishImeAction(before, rejectImeMutation());
      }
      const size_t selection_start = static_cast<size_t>(std::min(
          step.selection_after.anchor_utf16, step.selection_after.active_utf16));
      const size_t selection_end = static_cast<size_t>(std::max(
          step.selection_after.anchor_utf16, step.selection_after.active_utf16));
      if ((hidden_left && selection_start <= safe_start)
          || (hidden_right && selection_end >= safe_end)
          || after_length > IME_BUFFER_HARD_CAP) {
        needs_restart = true;
      }
      if (!isNoneRange(step.composition_after)
          && ((hidden_left && static_cast<size_t>(step.composition_after.start_utf16) <= safe_start)
              || (hidden_right && static_cast<size_t>(step.composition_after.end_utf16) >= safe_end))) {
        needs_restart = true;
      }
      const std::optional<std::pair<size_t, size_t>> next_composition =
          isNoneRange(step.composition_after)
              ? std::nullopt
              : std::optional<std::pair<size_t, size_t>> {{
                  static_cast<size_t>(step.composition_after.start_utf16),
                  static_cast<size_t>(step.composition_after.end_utf16)
                }};
      if (staged_composition.has_value() != next_composition.has_value()) {
        ++composition_ownership_transitions;
      } else if (staged_composition.has_value()) {
        const bool disjoint = next_composition->second <= staged_composition->first
            || next_composition->first >= staged_composition->second;
        if (disjoint && next_composition != staged_composition) {
          ++composition_ownership_transitions;
        }
      }
      staged_composition = next_composition;
    }

    if (composition_ownership_transitions > 1) {
      return finishImeAction(before, rejectImeMutation());
    }

    const ImeTextUpdateStep& final_step = batch.steps.back();
    const size_t old_length = StrUtil::utf16Length(buffer.text);
    const size_t new_length = StrUtil::utf16Length(staged_text);
    const Vector<StagedImeReplacement> staged_replacements =
        buildStagedImeReplacements(staged_units, old_length);
    const bool was_composing = hasPreedit();
    const bool is_composing = !isNoneRange(final_step.composition_after);
    if (!was_composing && is_composing && staged_replacements.size() > 1) {
      return finishImeAction(before, rejectImeMutation());
    }
    Vector<DocumentReplacement> physical_replacements;
    physical_replacements.reserve(staged_replacements.size());
    for (const StagedImeReplacement& replacement : staged_replacements) {
      physical_replacements.push_back({
          textRangeFromUtf16Offsets(buffer_start + replacement.start, buffer_start + replacement.end),
          replacement.text
      });
    }
    auto staged_buffer_position = [&](size_t offset) {
      return calcPositionAfterInsert(buffer.document_range.start, utf16Slice(staged_text, 0, offset));
    };
    const size_t selection_anchor_after = static_cast<size_t>(
        final_step.selection_after.anchor_utf16);
    const size_t selection_active_after = static_cast<size_t>(
        final_step.selection_after.active_utf16);
    const std::optional<std::pair<size_t, size_t>> composition_after = is_composing
        ? std::optional<std::pair<size_t, size_t>> {{
            static_cast<size_t>(final_step.composition_after.start_utf16),
            static_cast<size_t>(final_step.composition_after.end_utf16)
          }}
        : std::nullopt;
    const bool state_changed = staged_text != buffer.text
        || selection_anchor_before != selection_anchor_after
        || selection_active_before != selection_active_after
        || composition_before != composition_after
        || composition_ownership_transitions != 0;
    if (state_changed && buffer.state_revision == MAX_IME_WIRE_INTEGER) {
      needs_restart = true;
    }
    ImeActionResult result;
    result.handled = true;
    if (state_changed) {
      CaretState caret;
      caret.anchor = staged_buffer_position(
          static_cast<size_t>(final_step.selection_after.anchor_utf16));
      caret.active = staged_buffer_position(
          static_cast<size_t>(final_step.selection_after.active_utf16));
      caret.active_affinity = final_step.selection_after.affinity;
      std::optional<TextRange> final_composition_range;
      std::optional<std::pair<size_t, size_t>> final_composition_offsets = composition_after;
      if (is_composing) {
        final_composition_range = TextRange {
            staged_buffer_position(composition_after->first),
            staged_buffer_position(composition_after->second)
        };
      } else if (was_composing) {
        final_composition_offsets = composition_before;
        int64_t offset_before = 0;
        int64_t offset_inside = 0;
        for (const StagedImeReplacement& replacement : staged_replacements) {
          const size_t replacement_length = StrUtil::utf16Length(replacement.text);
          const int64_t delta = static_cast<int64_t>(replacement_length)
              - static_cast<int64_t>(replacement.end - replacement.start);
          const bool boundary_insertion = replacement.start == replacement.end
              && (replacement.start == composition_before->first
                  || replacement.start == composition_before->second);
          if (replacement.end <= composition_before->first
              && !boundary_insertion) {
            offset_before += delta;
          } else if (replacement.start < composition_before->second
                     || boundary_insertion) {
            if (replacement.start < composition_before->first
                || replacement.end > composition_before->second) {
              return finishImeAction(before, rejectImeMutation());
            }
            offset_inside += delta;
          }
        }
        final_composition_offsets->first = static_cast<size_t>(
            static_cast<int64_t>(composition_before->first) + offset_before);
        final_composition_offsets->second = static_cast<size_t>(
            static_cast<int64_t>(composition_before->second)
                + offset_before + offset_inside);
      }
      const U8String composition_text = final_composition_offsets.has_value()
          ? utf16Slice(staged_text, final_composition_offsets->first, final_composition_offsets->second)
          : U8String {};
      std::optional<TextRange> rollover_baseline;
      if (!was_composing && is_composing && !staged_replacements.empty()) {
        const StagedImeReplacement& replacement = staged_replacements.front();
        const std::pair<size_t, size_t> inserted {
            replacement.start,
            replacement.start + StrUtil::utf16Length(replacement.text)
        };
        if (*composition_after != inserted) {
          return finishImeAction(before, rejectImeMutation());
        }
      }
      if (was_composing && is_composing) {
        if (staged_replacements.empty()) {
          const bool disjoint = composition_after->second <= composition_before->first
              || composition_after->first >= composition_before->second;
          if (disjoint && composition_after != composition_before) {
            rollover_baseline = textRangeFromUtf16Offsets(
                buffer_start + composition_after->first, buffer_start + composition_after->second);
          } else if (composition_after != composition_before) {
            return finishImeAction(before, rejectImeMutation());
          }
        } else if (staged_replacements.size() == 1) {
          const StagedImeReplacement& replacement = staged_replacements.front();
          const size_t replacement_length = StrUtil::utf16Length(replacement.text);
          const size_t inserted_end = replacement.start + replacement_length;
          const int64_t delta = static_cast<int64_t>(replacement_length)
              - static_cast<int64_t>(replacement.end - replacement.start);
          const bool patch_outside = replacement.end <= composition_before->first
              || replacement.start >= composition_before->second;
          const bool after_is_inserted = composition_after->first == replacement.start
              && composition_after->second == inserted_end;
          const bool replaces_old_owner = replacement.start == composition_before->first
              && replacement.end == composition_before->second;
          if (patch_outside && after_is_inserted && !replaces_old_owner) {
            rollover_baseline = physical_replacements.front().range;
          } else {
            bool same_owner = replaces_old_owner && after_is_inserted;
            const bool patch_inside = composition_before->first <= replacement.start
                && replacement.end <= composition_before->second;
            if (patch_inside) {
              const std::pair<size_t, size_t> internal_after {
                  composition_before->first,
                  static_cast<size_t>(
                      static_cast<int64_t>(composition_before->second) + delta)
              };
              same_owner = same_owner || *composition_after == internal_after;
            }
            if (replacement.end <= composition_before->first) {
              const std::pair<size_t, size_t> external_after {
                  static_cast<size_t>(
                      static_cast<int64_t>(composition_before->first) + delta),
                  static_cast<size_t>(
                      static_cast<int64_t>(composition_before->second) + delta)
              };
              same_owner = same_owner || *composition_after == external_after;
            } else if (replacement.start >= composition_before->second) {
              same_owner = same_owner || *composition_after == *composition_before;
            }
            if (replacement.text.empty()
                && replacement.start < composition_before->second
                && composition_before->first < replacement.end) {
              const auto after_delete = [&](size_t offset) {
                if (offset < replacement.start) {
                  return offset;
                }
                if (offset <= replacement.end) {
                  return replacement.start;
                }
                return offset - (replacement.end - replacement.start);
              };
              const std::pair<size_t, size_t> deletion_after {
                  after_delete(composition_before->first),
                  after_delete(composition_before->second)
              };
              same_owner = same_owner || *composition_after == deletion_after;
            }
            if (!same_owner) {
              return finishImeAction(before, rejectImeMutation());
            }
          }
        } else {
          bool has_surviving_owner = false;
          for (size_t index = 0; index < staged_units.size(); ++index) {
            const std::optional<size_t> original = staged_units[index].original_offset;
            if (!original.has_value()) {
              continue;
            }
            const bool was_owned = composition_before->first <= *original
                && *original < composition_before->second;
            const bool is_owned = composition_after->first <= index
                && index < composition_after->second;
            if (was_owned) {
              has_surviving_owner = true;
              if (!is_owned) {
                return finishImeAction(before, rejectImeMutation());
              }
            } else if (is_owned) {
              return finishImeAction(before, rejectImeMutation());
            }
          }
          if (!has_surviving_owner) {
            return finishImeAction(before, rejectImeMutation());
          }
        }
      }
      result = m_composition_controller_.applyTextUpdatePlan(
          physical_replacements, final_composition_range, rollover_baseline,
          composition_text, caret, needs_restart);
      if (!result.handled) {
        return finishImeAction(before, rejectImeMutation());
      }
    }

    buffer.text = staged_text;
    buffer.document_range.end = m_document_->getPositionFromCharIndex(
        buffer_start + new_length);
    buffer.safe_start_utf16 = static_cast<int64_t>(safe_start);
    buffer.safe_end_utf16 = static_cast<int64_t>(safe_end);
    const U8String actual_buffer_text = logicalizeLineEndings(
        m_document_->getU8Text(buffer.document_range));
    const size_t actual_anchor = m_document_->getCharIndexFromPosition(m_caret_.anchor);
    const size_t actual_active = m_document_->getCharIndexFromPosition(m_caret_.active);
    if (actual_buffer_text != staged_text
        || actual_anchor != buffer_start + selection_anchor_after
        || actual_active != buffer_start + selection_active_after
        || hasPreedit() != is_composing) {
      needs_restart = true;
    } else if (is_composing) {
      const TextRange actual_composition = getCompositionState()->current_range;
      const size_t actual_composition_start =
          m_document_->getCharIndexFromPosition(actual_composition.start);
      const size_t actual_composition_end =
          m_document_->getCharIndexFromPosition(actual_composition.end);
      if (actual_composition_start != buffer_start + composition_after->first
          || actual_composition_end != buffer_start + composition_after->second) {
        needs_restart = true;
      }
    }
    if (state_changed) {
      if (buffer.state_revision == MAX_IME_WIRE_INTEGER) {
        needs_restart = true;
      } else {
        ++buffer.state_revision;
      }
    }
    if (needs_restart) {
      if (hasPreedit()) {
        appendImeEditResult(result.edit_result, m_composition_controller_.finishPreedit());
      }
      closeImeSession();
      result.host_action = m_settings_.read_only
          ? ImeHostAction::CLOSE_SESSION
          : ImeHostAction::RESTART_SESSION;
      result.state = emptyImeState(ImeResultCode::OK);
    } else {
      result.state = buildImeState();
    }
    return finishImeAction(before, result);
  }

  EditorActionResult EditorCore::endImeSession(uint64_t session_id) {
    const ActionSnapshot before = captureActionSnapshot();
    ImeActionResult result;
    result.handled = true;
    if (!hasMatchingImeSession(session_id)) {
      result.state = emptyImeState(ImeResultCode::SESSION_MISMATCH);
      return finishImeAction(before, result);
    }
    if (hasPreedit()) {
      result.edit_result = m_composition_controller_.finishPreedit();
    }
    closeImeSession();
    result.state = emptyImeState(ImeResultCode::OK);
    return finishImeAction(before, result);
  }

  ImeTextContext EditorCore::getImeContext(uint64_t session_id, ImeTextSource source,
                                           int64_t start_utf16, int64_t length_utf16) const {
    ImeTextContext context;
    if (!hasMatchingImeSession(session_id)) {
      context.result_code = ImeResultCode::SESSION_MISMATCH;
      return context;
    }
    if (!isKnownTextSource(source)
        || start_utf16 < 0
        || static_cast<uint64_t>(start_utf16) > MAX_IME_WIRE_INTEGER
        || length_utf16 < -1
        || (length_utf16 >= 0
            && static_cast<uint64_t>(length_utf16) > MAX_IME_WIRE_INTEGER)) {
      context.result_code = ImeResultCode::REJECTED;
      return context;
    }

    int64_t selection_anchor = -1;
    int64_t selection_active = -1;
    CaretAffinity selection_affinity = m_caret_.active_affinity;
    int64_t composition_start = -1;
    int64_t composition_end = -1;
    int64_t total_length = 0;
    std::function<bool(size_t)> source_boundary;
    std::function<U8String(size_t, size_t)> source_slice;
    if (source == ImeTextSource::EDITING_BUFFER) {
      if (!isImeTextUpdateSession() || start_utf16 != 0 || length_utf16 != -1) {
        context.result_code = ImeResultCode::REJECTED;
        return context;
      }
      const EditingBufferState& buffer = *m_ime_session_->editing_buffer;
      total_length = static_cast<int64_t>(StrUtil::utf16Length(buffer.text));
      source_boundary = [&buffer](size_t offset) {
        return isUtf16Boundary(buffer.text, offset);
      };
      source_slice = [&buffer](size_t start, size_t end) {
        return utf16Slice(buffer.text, start, end);
      };
      const int64_t base = static_cast<int64_t>(
          m_document_->getCharIndexFromPosition(buffer.document_range.start));
      selection_anchor = static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.anchor)) - base;
      selection_active = static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.active)) - base;
      if (hasPreedit()) {
        const TextRange range = getCompositionState()->current_range;
        composition_start = static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.start)) - base;
        composition_end = static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.end)) - base;
      }
    } else {
      const size_t editing_length = documentUtf16Length();
      selection_anchor = static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.anchor));
      selection_active = static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.active));
      auto document_boundary = [&](size_t offset) {
        if (offset > editing_length) {
          return false;
        }
        const TextPosition position = m_document_->getPositionFromCharIndex(offset);
        return UnicodeUtil::isCodePointBoundary(
            m_document_->getLineU16TextRef(position.line), position.column);
      };
      auto document_slice = [&](size_t start, size_t end) {
        return logicalizeLineEndings(m_document_->getU8Text(
            textRangeFromUtf16Offsets(start, end)));
      };
      if (hasPreedit()) {
        const CompositionState& composition = *getCompositionState();
        composition_start = static_cast<int64_t>(
            m_document_->getCharIndexFromPosition(composition.current_range.start));
        composition_end = static_cast<int64_t>(
            m_document_->getCharIndexFromPosition(composition.current_range.end));
        if (source == ImeTextSource::COMMITTED
            && composition.baseline_text_raw.has_value()) {
          const U8String baseline = logicalizeLineEndings(*composition.baseline_text_raw);
          const size_t baseline_length = StrUtil::utf16Length(baseline);
          const size_t editing_composition_length = static_cast<size_t>(
              composition_end - composition_start);
          const int64_t baseline_end = composition_start
              + static_cast<int64_t>(baseline_length);
          total_length = static_cast<int64_t>(editing_length)
              - (composition_end - composition_start)
              + static_cast<int64_t>(baseline_length);
          source_boundary = [&, baseline, baseline_length, baseline_end,
                             editing_composition_length](size_t offset) {
            if (offset <= static_cast<size_t>(composition_start)) {
              return document_boundary(offset);
            }
            if (offset >= static_cast<size_t>(baseline_end)) {
              return document_boundary(offset - baseline_length
                  + editing_composition_length);
            }
            return isUtf16Boundary(baseline, offset - static_cast<size_t>(composition_start));
          };
          source_slice = [&, baseline, baseline_length, baseline_end,
                          editing_composition_length](size_t start, size_t end) {
            U8String text;
            const size_t committed_start = static_cast<size_t>(composition_start);
            const size_t committed_end = static_cast<size_t>(baseline_end);
            if (start < committed_start) {
              text += document_slice(start, std::min(end, committed_start));
            }
            if (start < committed_end && committed_start < end) {
              text += utf16Slice(baseline, start > committed_start ? start - committed_start : 0,
                                 std::min(end, committed_end) - committed_start);
            }
            if (committed_end < end) {
              const size_t editing_start = std::max(start, committed_end)
                  - baseline_length
                  + editing_composition_length;
              const size_t editing_end = end
                  - baseline_length
                  + editing_composition_length;
              text += document_slice(editing_start, editing_end);
            }
            return text;
          };
          auto project = [&](int64_t offset, bool active) {
            if (offset < composition_start) return offset;
            if (offset > composition_end) return offset + baseline_end - composition_end;
            if (offset == composition_end) return baseline_end;
            if (active) selection_affinity = CaretAffinity::DOWNSTREAM;
            return composition_start;
          };
          selection_anchor = project(selection_anchor, false);
          selection_active = project(selection_active, true);
          composition_end = baseline_end;
        }
      }
      if (!source_slice) {
        total_length = static_cast<int64_t>(editing_length);
        source_boundary = document_boundary;
        source_slice = document_slice;
      }
    }

    if (start_utf16 > total_length) {
      context.result_code = ImeResultCode::REJECTED;
      return context;
    }
    int64_t end_utf16 = total_length;
    if (length_utf16 >= 0) {
      if (start_utf16 > std::numeric_limits<int64_t>::max() - length_utf16) {
        context.result_code = ImeResultCode::REJECTED;
        return context;
      }
      end_utf16 = std::min(total_length, start_utf16 + length_utf16);
    }
    size_t safe_start = static_cast<size_t>(start_utf16);
    size_t safe_end = static_cast<size_t>(end_utf16);
    if (!source_boundary(safe_start)) {
      ++safe_start;
    }
    if (!source_boundary(safe_end) && safe_end > 0) {
      --safe_end;
    }
    safe_end = std::max(safe_start, safe_end);

    context.result_code = ImeResultCode::OK;
    context.slice_start_utf16 = static_cast<int64_t>(safe_start);
    context.total_length_utf16 = total_length;
    context.text = source_slice(safe_start, safe_end);
    if (selection_anchor >= static_cast<int64_t>(safe_start)
        && selection_anchor <= static_cast<int64_t>(safe_end)
        && selection_active >= static_cast<int64_t>(safe_start)
        && selection_active <= static_cast<int64_t>(safe_end)) {
      context.selection.coordinate_space = ImeCoordinateSpace::CONTEXT_SLICE;
      context.selection.anchor_utf16 = selection_anchor - static_cast<int64_t>(safe_start);
      context.selection.active_utf16 = selection_active - static_cast<int64_t>(safe_start);
      context.selection.affinity = selection_affinity;
    }
    if (composition_start >= static_cast<int64_t>(safe_start)
        && composition_end <= static_cast<int64_t>(safe_end)) {
      context.composition_range = {
          ImeCoordinateSpace::CONTEXT_SLICE,
          composition_start - static_cast<int64_t>(safe_start),
          composition_end - static_cast<int64_t>(safe_start)
      };
    }
    return context;
  }

}
