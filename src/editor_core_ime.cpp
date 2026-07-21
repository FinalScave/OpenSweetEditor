//
// Created by Scave on 2025/12/1.
//
#include <algorithm>
#include <cstddef>
#include <functional>
#include <limits>
#include <utility>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "ime_projection.hpp"

namespace NS_SWEETEDITOR {

  constexpr uint64_t MAX_IME_WIRE_INTEGER = (uint64_t{1} << 53u) - 1;
  constexpr size_t IME_BUFFER_SURROUNDING_LENGTH = 1024;
  constexpr size_t IME_BUFFER_GUARD_LENGTH = 256;
  constexpr size_t IME_BUFFER_HARD_CAP = 65536;

  struct StagedImeCodeUnit {
    char16_t value{0};
    std::optional<size_t> original_offset;
  };

  struct StagedImeReplacement {
    size_t start{0};
    size_t end{0};
    U8String text;
  };

  static bool isKnownMutationModel(ImeMutationModel model) {
    return model == ImeMutationModel::COMMAND || model == ImeMutationModel::TEXT_UPDATE;
  }

  static bool isKnownTextSource(ImeTextSource source) {
    return source == ImeTextSource::EDITING || source == ImeTextSource::COMMITTED
           || source == ImeTextSource::EDITING_BUFFER;
  }

  static bool isKnownCoordinateSpace(ImeCoordinateSpace space) {
    return space == ImeCoordinateSpace::DOCUMENT || space == ImeCoordinateSpace::EDITING_BUFFER
           || space == ImeCoordinateSpace::CONTEXT_SLICE || space == ImeCoordinateSpace::COMPOSITION;
  }

  static bool isKnownTextUnit(ImeTextUnit unit) {
    return unit == ImeTextUnit::UTF16_CODE_UNIT || unit == ImeTextUnit::UNICODE_CODE_POINT;
  }

  static bool isKnownCommandKind(ImeCommandKind kind) {
    return kind == ImeCommandKind::SET_SELECTION || kind == ImeCommandKind::BEGIN_COMPOSITION
           || kind == ImeCommandKind::UPDATE_COMPOSITION || kind == ImeCommandKind::COMMIT_TEXT
           || kind == ImeCommandKind::FINISH_COMPOSITION || kind == ImeCommandKind::CANCEL_COMPOSITION
           || kind == ImeCommandKind::DELETE_SURROUNDING;
  }

  static bool isKnownAffinity(CaretAffinity affinity) {
    return affinity == CaretAffinity::DOWNSTREAM || affinity == CaretAffinity::UPSTREAM;
  }

  static bool isNoneRange(const ImeOffsetRange& range) {
    return range.coordinate_space == ImeCoordinateSpace::DOCUMENT && range.start_utf16 == -1 && range.end_utf16 == -1;
  }

  static bool isNoneSelection(const ImeSelection& selection) {
    return selection.coordinate_space == ImeCoordinateSpace::DOCUMENT && selection.anchor_utf16 == -1
           && selection.active_utf16 == -1 && selection.affinity == CaretAffinity::DOWNSTREAM;
  }

  static bool isValidRangeShape(const ImeOffsetRange& range) {
    return isKnownCoordinateSpace(range.coordinate_space) && range.start_utf16 >= 0
           && static_cast<uint64_t>(range.start_utf16) <= MAX_IME_WIRE_INTEGER
           && static_cast<uint64_t>(range.end_utf16) <= MAX_IME_WIRE_INTEGER && range.end_utf16 >= range.start_utf16;
  }

  static bool isValidSelectionShape(const ImeSelection& selection) {
    return isKnownCoordinateSpace(selection.coordinate_space) && isKnownAffinity(selection.affinity)
           && selection.anchor_utf16 >= 0 && selection.active_utf16 >= 0
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
    staged.erase(staged.begin() + static_cast<ptrdiff_t>(start), staged.begin() + static_cast<ptrdiff_t>(end));
    staged.insert(staged.begin() + static_cast<ptrdiff_t>(start), replacement_units.begin(), replacement_units.end());
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

  static size_t transformImeOffset(size_t offset, size_t start, size_t end, size_t replacement_length, bool after) {
    if (offset < start || (offset == start && !after)) {
      return offset;
    }
    if (offset > end || (offset == end && after)) {
      return offset - (end - start) + replacement_length;
    }
    return after ? start + replacement_length : start;
  }

  static void appendImeEditResult(TextEditResult& target, const TextEditResult& source) {
    target.editing_content_changed = target.editing_content_changed || source.editing_content_changed;
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

#pragma region[IME]

  ImeState EditorCore::beginImeSession(ImeMutationModel mutation_model) {
    if (m_settings_.read_only) {
      return emptyImeState(ImeResultCode::READ_ONLY);
    }
    if (m_document_ == nullptr || m_ime_session_.has_value() || !isKnownMutationModel(mutation_model)
        || m_next_ime_session_id_ == 0 || m_next_ime_session_id_ > MAX_IME_WIRE_INTEGER) {
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
      size_t total_buffer_length = selection_end - selection_start + left_length + right_length;
      if (total_buffer_length > IME_BUFFER_HARD_CAP) {
        size_t overflow = total_buffer_length - IME_BUFFER_HARD_CAP;
        const size_t right_guard = std::min(IME_BUFFER_GUARD_LENGTH, document_length - selection_end);
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
      start_position.column = UnicodeUtil::clampColumnToCodePointBoundaryLeft(start_line, start_position.column);
      end_position.column = UnicodeUtil::clampColumnToCodePointBoundaryRight(end_line, end_position.column);
      start = m_document_->getCharIndexFromPosition(start_position);
      end = m_document_->getCharIndexFromPosition(end_position);
      EditingBufferState buffer;
      buffer.document_range = {start_position, end_position};
      buffer.text = logicalizeLineEndings(m_document_->getU8Text(buffer.document_range));
      buffer.safe_start_utf16 = static_cast<int64_t>(std::min(IME_BUFFER_GUARD_LENGTH, selection_start - start));
      buffer.safe_end_utf16 =
          static_cast<int64_t>(end - start - std::min(IME_BUFFER_GUARD_LENGTH, document_length - selection_end));
      session.editing_buffer = std::move(buffer);
    }
    session.session_id = m_next_ime_session_id_++;
    m_ime_session_ = std::move(session);
    return buildImeState();
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
      result.edit_result = finishPreedit();
    }
    closeImeSession();
    result.state = emptyImeState(ImeResultCode::OK);
    return finishImeAction(before, result);
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

    ImeActionResult result = applyCommandBatch(batch.commands);
    if (!result.handled) {
      return finishImeAction(before, rejectImeMutation());
    }
    result.state = buildImeState();
    return finishImeAction(before, result);
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
    const size_t selection_anchor_before = m_document_->getCharIndexFromPosition(m_caret_.anchor) - buffer_start;
    const size_t selection_active_before = m_document_->getCharIndexFromPosition(m_caret_.active) - buffer_start;
    std::optional<std::pair<size_t, size_t>> composition_before;
    if (hasPreedit()) {
      const TextRange range = getCompositionState()->current_range;
      composition_before = {m_document_->getCharIndexFromPosition(range.start) - buffer_start,
                            m_document_->getCharIndexFromPosition(range.end) - buffer_start};
    }
    U8String staged_text = buffer.text;
    Vector<StagedImeCodeUnit> staged_units = makeStagedImeText(buffer.text);
    std::optional<std::pair<size_t, size_t>> staged_composition = composition_before;
    size_t composition_ownership_transitions = 0;
    for (const ImeTextUpdateStep& step : batch.steps) {
      const size_t text_length = StrUtil::utf16Length(staged_text);
      if (step.old_text != staged_text
          || (!isNoneRange(step.patch_range) && static_cast<uint64_t>(step.patch_range.end_utf16) > text_length)) {
        return finishImeAction(before, rejectImeMutation());
      }
      if (!isNoneRange(step.patch_range)) {
        const size_t start = static_cast<size_t>(step.patch_range.start_utf16);
        const size_t end = static_cast<size_t>(step.patch_range.end_utf16);
        if (!isUtf16Boundary(staged_text, start) || !isUtf16Boundary(staged_text, end)) {
          return finishImeAction(before, rejectImeMutation());
        }
        staged_text = utf16Slice(staged_text, 0, start) + step.replacement_text
                      + utf16Slice(staged_text, end, StrUtil::utf16Length(staged_text));
        replaceStagedImeText(staged_units, start, end, step.replacement_text);
        const size_t replacement_length = StrUtil::utf16Length(step.replacement_text);
        if ((hidden_left && start <= safe_start) || (hidden_right && end >= safe_end)) {
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
      const size_t selection_start =
          static_cast<size_t>(std::min(step.selection_after.anchor_utf16, step.selection_after.active_utf16));
      const size_t selection_end =
          static_cast<size_t>(std::max(step.selection_after.anchor_utf16, step.selection_after.active_utf16));
      if ((hidden_left && selection_start <= safe_start) || (hidden_right && selection_end >= safe_end)
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
              : std::optional<std::pair<size_t, size_t>>{{static_cast<size_t>(step.composition_after.start_utf16),
                                                          static_cast<size_t>(step.composition_after.end_utf16)}};
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
    const Vector<StagedImeReplacement> staged_replacements = buildStagedImeReplacements(staged_units, old_length);
    const bool was_composing = hasPreedit();
    const bool is_composing = !isNoneRange(final_step.composition_after);
    if (!was_composing && is_composing && staged_replacements.size() > 1) {
      return finishImeAction(before, rejectImeMutation());
    }
    Vector<DocumentReplacement> physical_replacements;
    physical_replacements.reserve(staged_replacements.size());
    for (const StagedImeReplacement& replacement : staged_replacements) {
      physical_replacements.push_back(
          {textRangeFromUtf16Offsets(buffer_start + replacement.start, buffer_start + replacement.end),
           replacement.text});
    }
    auto staged_buffer_position = [&](size_t offset) {
      return calcPositionAfterInsert(buffer.document_range.start, utf16Slice(staged_text, 0, offset));
    };
    const size_t selection_anchor_after = static_cast<size_t>(final_step.selection_after.anchor_utf16);
    const size_t selection_active_after = static_cast<size_t>(final_step.selection_after.active_utf16);
    const std::optional<std::pair<size_t, size_t>> composition_after =
        is_composing
            ? std::optional<std::pair<size_t, size_t>>{{static_cast<size_t>(final_step.composition_after.start_utf16),
                                                        static_cast<size_t>(final_step.composition_after.end_utf16)}}
            : std::nullopt;
    const bool state_changed = staged_text != buffer.text || selection_anchor_before != selection_anchor_after
                               || selection_active_before != selection_active_after
                               || composition_before != composition_after || composition_ownership_transitions != 0;
    if (state_changed && buffer.state_revision == MAX_IME_WIRE_INTEGER) {
      needs_restart = true;
    }
    ImeActionResult result;
    result.handled = true;
    if (state_changed) {
      CaretState caret;
      caret.anchor = staged_buffer_position(static_cast<size_t>(final_step.selection_after.anchor_utf16));
      caret.active = staged_buffer_position(static_cast<size_t>(final_step.selection_after.active_utf16));
      caret.active_affinity = final_step.selection_after.affinity;
      std::optional<TextRange> final_composition_range;
      std::optional<std::pair<size_t, size_t>> final_composition_offsets = composition_after;
      if (is_composing) {
        final_composition_range = TextRange{staged_buffer_position(composition_after->first),
                                            staged_buffer_position(composition_after->second)};
      } else if (was_composing) {
        final_composition_offsets = composition_before;
        int64_t offset_before = 0;
        int64_t offset_inside = 0;
        for (const StagedImeReplacement& replacement : staged_replacements) {
          const size_t replacement_length = StrUtil::utf16Length(replacement.text);
          const int64_t delta =
              static_cast<int64_t>(replacement_length) - static_cast<int64_t>(replacement.end - replacement.start);
          const bool boundary_insertion =
              replacement.start == replacement.end
              && (replacement.start == composition_before->first || replacement.start == composition_before->second);
          if (replacement.end <= composition_before->first && !boundary_insertion) {
            offset_before += delta;
          } else if (replacement.start < composition_before->second || boundary_insertion) {
            if (replacement.start < composition_before->first || replacement.end > composition_before->second) {
              return finishImeAction(before, rejectImeMutation());
            }
            offset_inside += delta;
          }
        }
        final_composition_offsets->first =
            static_cast<size_t>(static_cast<int64_t>(composition_before->first) + offset_before);
        final_composition_offsets->second =
            static_cast<size_t>(static_cast<int64_t>(composition_before->second) + offset_before + offset_inside);
      }
      const U8String composition_text =
          final_composition_offsets.has_value()
              ? utf16Slice(staged_text, final_composition_offsets->first, final_composition_offsets->second)
              : U8String{};
      std::optional<TextRange> rollover_baseline;
      if (!was_composing && is_composing && !staged_replacements.empty()) {
        const StagedImeReplacement& replacement = staged_replacements.front();
        const std::pair<size_t, size_t> inserted{replacement.start,
                                                 replacement.start + StrUtil::utf16Length(replacement.text)};
        if (*composition_after != inserted) {
          return finishImeAction(before, rejectImeMutation());
        }
      }
      if (was_composing && is_composing) {
        if (staged_replacements.empty()) {
          const bool disjoint = composition_after->second <= composition_before->first
                                || composition_after->first >= composition_before->second;
          if (disjoint && composition_after != composition_before) {
            rollover_baseline = textRangeFromUtf16Offsets(buffer_start + composition_after->first,
                                                          buffer_start + composition_after->second);
          } else if (composition_after != composition_before) {
            return finishImeAction(before, rejectImeMutation());
          }
        } else if (staged_replacements.size() == 1) {
          const StagedImeReplacement& replacement = staged_replacements.front();
          const size_t replacement_length = StrUtil::utf16Length(replacement.text);
          const size_t inserted_end = replacement.start + replacement_length;
          const int64_t delta =
              static_cast<int64_t>(replacement_length) - static_cast<int64_t>(replacement.end - replacement.start);
          const bool patch_outside =
              replacement.end <= composition_before->first || replacement.start >= composition_before->second;
          const bool after_is_inserted =
              composition_after->first == replacement.start && composition_after->second == inserted_end;
          const bool replaces_old_owner =
              replacement.start == composition_before->first && replacement.end == composition_before->second;
          if (patch_outside && after_is_inserted && !replaces_old_owner) {
            rollover_baseline = physical_replacements.front().range;
          } else {
            bool same_owner = replaces_old_owner && after_is_inserted;
            const bool patch_inside =
                composition_before->first <= replacement.start && replacement.end <= composition_before->second;
            if (patch_inside) {
              const std::pair<size_t, size_t> internal_after{
                  composition_before->first,
                  static_cast<size_t>(static_cast<int64_t>(composition_before->second) + delta)};
              same_owner = same_owner || *composition_after == internal_after;
            }
            if (replacement.end <= composition_before->first) {
              const std::pair<size_t, size_t> external_after{
                  static_cast<size_t>(static_cast<int64_t>(composition_before->first) + delta),
                  static_cast<size_t>(static_cast<int64_t>(composition_before->second) + delta)};
              same_owner = same_owner || *composition_after == external_after;
            } else if (replacement.start >= composition_before->second) {
              same_owner = same_owner || *composition_after == *composition_before;
            }
            if (replacement.text.empty() && replacement.start < composition_before->second
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
              const std::pair<size_t, size_t> deletion_after{after_delete(composition_before->first),
                                                             after_delete(composition_before->second)};
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
            const bool was_owned = composition_before->first <= *original && *original < composition_before->second;
            const bool is_owned = composition_after->first <= index && index < composition_after->second;
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
      result = applyTextUpdatePlan(physical_replacements, final_composition_range, rollover_baseline, composition_text,
                                   caret, needs_restart);
      if (!result.handled) {
        return finishImeAction(before, rejectImeMutation());
      }
    }

    buffer.text = staged_text;
    buffer.document_range.end = m_document_->getPositionFromCharIndex(buffer_start + new_length);
    buffer.safe_start_utf16 = static_cast<int64_t>(safe_start);
    buffer.safe_end_utf16 = static_cast<int64_t>(safe_end);
    const U8String actual_buffer_text = logicalizeLineEndings(m_document_->getU8Text(buffer.document_range));
    const size_t actual_anchor = m_document_->getCharIndexFromPosition(m_caret_.anchor);
    const size_t actual_active = m_document_->getCharIndexFromPosition(m_caret_.active);
    if (actual_buffer_text != staged_text || actual_anchor != buffer_start + selection_anchor_after
        || actual_active != buffer_start + selection_active_after || hasPreedit() != is_composing) {
      needs_restart = true;
    } else if (is_composing) {
      const TextRange actual_composition = getCompositionState()->current_range;
      const size_t actual_composition_start = m_document_->getCharIndexFromPosition(actual_composition.start);
      const size_t actual_composition_end = m_document_->getCharIndexFromPosition(actual_composition.end);
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
        appendImeEditResult(result.edit_result, finishPreedit());
      }
      closeImeSession();
      result.host_action = m_settings_.read_only ? ImeHostAction::CLOSE_SESSION : ImeHostAction::RESTART_SESSION;
      result.state = emptyImeState(ImeResultCode::OK);
    } else {
      result.state = buildImeState();
    }
    return finishImeAction(before, result);
  }

  ImeState EditorCore::getImeState(uint64_t session_id) const {
    return hasMatchingImeSession(session_id) ? buildImeState() : emptyImeState(ImeResultCode::SESSION_MISMATCH);
  }

  ImeTextContext EditorCore::getImeContext(uint64_t session_id, ImeTextSource source, int64_t start_utf16,
                                           int64_t length_utf16) const {
    ImeTextContext context;
    if (!hasMatchingImeSession(session_id)) {
      context.result_code = ImeResultCode::SESSION_MISMATCH;
      return context;
    }
    if (!isKnownTextSource(source) || start_utf16 < 0 || static_cast<uint64_t>(start_utf16) > MAX_IME_WIRE_INTEGER
        || length_utf16 < -1 || (length_utf16 >= 0 && static_cast<uint64_t>(length_utf16) > MAX_IME_WIRE_INTEGER)) {
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
      const int64_t base = static_cast<int64_t>(m_document_->getCharIndexFromPosition(buffer.document_range.start));
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
        return UnicodeUtil::isCodePointBoundary(m_document_->getLineU16TextRef(position.line), position.column);
      };
      auto document_slice = [&](size_t start, size_t end) {
        return logicalizeLineEndings(m_document_->getU8Text(textRangeFromUtf16Offsets(start, end)));
      };
      if (hasPreedit()) {
        const CompositionState& composition = *getCompositionState();
        composition_start =
            static_cast<int64_t>(m_document_->getCharIndexFromPosition(composition.current_range.start));
        composition_end = static_cast<int64_t>(m_document_->getCharIndexFromPosition(composition.current_range.end));
        if (source == ImeTextSource::COMMITTED && composition.baseline_text_raw.has_value()) {
          const U8String baseline = logicalizeLineEndings(*composition.baseline_text_raw);
          const size_t baseline_length = StrUtil::utf16Length(baseline);
          const size_t editing_composition_length = static_cast<size_t>(composition_end - composition_start);
          const int64_t baseline_end = composition_start + static_cast<int64_t>(baseline_length);
          total_length = static_cast<int64_t>(editing_length) - (composition_end - composition_start)
                         + static_cast<int64_t>(baseline_length);
          source_boundary = [&, baseline, baseline_length, baseline_end, editing_composition_length](size_t offset) {
            if (offset <= static_cast<size_t>(composition_start)) {
              return document_boundary(offset);
            }
            if (offset >= static_cast<size_t>(baseline_end)) {
              return document_boundary(offset - baseline_length + editing_composition_length);
            }
            return isUtf16Boundary(baseline, offset - static_cast<size_t>(composition_start));
          };
          source_slice = [&, baseline, baseline_length, baseline_end, editing_composition_length](size_t start,
                                                                                                  size_t end) {
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
              const size_t editing_start =
                  std::max(start, committed_end) - baseline_length + editing_composition_length;
              const size_t editing_end = end - baseline_length + editing_composition_length;
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
    if (selection_anchor >= static_cast<int64_t>(safe_start) && selection_anchor <= static_cast<int64_t>(safe_end)
        && selection_active >= static_cast<int64_t>(safe_start) && selection_active <= static_cast<int64_t>(safe_end)) {
      context.selection.coordinate_space = ImeCoordinateSpace::CONTEXT_SLICE;
      context.selection.anchor_utf16 = selection_anchor - static_cast<int64_t>(safe_start);
      context.selection.active_utf16 = selection_active - static_cast<int64_t>(safe_start);
      context.selection.affinity = selection_affinity;
    }
    if (composition_start >= static_cast<int64_t>(safe_start) && composition_end <= static_cast<int64_t>(safe_end)) {
      context.composition_range = {ImeCoordinateSpace::CONTEXT_SLICE,
                                   composition_start - static_cast<int64_t>(safe_start),
                                   composition_end - static_cast<int64_t>(safe_start)};
    }
    return context;
  }

  const std::optional<CompositionState>& EditorCore::getCompositionState() const {
    return compositionState();
  }

  bool EditorCore::hasPreedit() const {
    return getCompositionState().has_value();
  }

#pragma endregion

#pragma region[IME Internals]

  struct EditorCore::EditTransaction {
    Vector<DocumentReplacement> physical_replacements;
    Vector<TextChange> committed_changes;
    CaretState caret_before;
    CaretState caret_after;
    std::optional<size_t> composition_replacement_index;
    std::optional<U8String> composition_text;
    std::optional<TextRange> composition_baseline_range;
    bool update_composition{false};
    std::optional<CompositionState> composition_after;
    bool cancel_linked_editing{false};
    bool break_history_merge{false};
  };

  namespace {
    TextChangeKind replacementChangeKind(const TextRange& range, const U8String& text) {
      if (range.isCollapsed()) {
        return text.empty() ? TextChangeKind::NONE : TextChangeKind::INSERTION;
      }
      return text.empty() ? TextChangeKind::DELETION : TextChangeKind::REPLACEMENT;
    }
  }

  const std::optional<CompositionState>& EditorCore::compositionState() const {
    static const std::optional<CompositionState> empty;
    return m_ime_session_.has_value() ? m_ime_session_->composition : empty;
  }

  CaretState EditorCore::transformCaretForChanges(const CaretState& caret, const Vector<TextChange>& changes) const {
    CaretState transformed = caret;
    for (auto it = changes.rbegin(); it != changes.rend(); ++it) {
      const TextPosition new_end = calcPositionAfterInsert(it->range.start, it->new_text);
      const bool active_collapsed = it->range.start <= transformed.active && transformed.active <= it->range.end;
      transformed.anchor =
          ImeProjection::transformPosition(it->range, new_end, transformed.anchor, ImeProjection::EndpointBias::BEFORE);
      transformed.active =
          ImeProjection::transformPosition(it->range, new_end, transformed.active, ImeProjection::EndpointBias::AFTER);
      if (active_collapsed) {
        transformed.active_affinity = CaretAffinity::DOWNSTREAM;
      }
    }
    return transformed;
  }

  bool EditorCore::isDocumentRangeValid(const TextRange& range) const {
    if (m_document_ == nullptr || range.end < range.start) {
      return false;
    }
    if (range.start.line >= m_document_->getLineCount() || range.end.line >= m_document_->getLineCount()) {
      return false;
    }
    const U16String& start_line = m_document_->getLineU16TextRef(range.start.line);
    const U16String& end_line =
        range.start.line == range.end.line ? start_line : m_document_->getLineU16TextRef(range.end.line);
    return range.start.column <= start_line.size() && range.end.column <= end_line.size()
           && UnicodeUtil::isCodePointBoundary(start_line, range.start.column)
           && UnicodeUtil::isCodePointBoundary(end_line, range.end.column);
  }

  bool EditorCore::validateTransaction(const EditTransaction& transaction) const {
    if (transaction.update_composition && !m_ime_session_.has_value()) {
      return false;
    }
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

  void EditorCore::beginComposition(const TextRange& range, EditTransaction& transaction) {
    const TextRange safe_range = clampDocumentRange(range.normalized(), true, false);
    CompositionState state;
    state.current_range = safe_range;
    state.baseline_caret = transaction.caret_after;
    transaction.update_composition = true;
    transaction.composition_after = std::move(state);
  }

  void EditorCore::replaceCompositionText(const U8String& text, EditTransaction& transaction) {
    std::optional<CompositionState> state =
        transaction.update_composition ? transaction.composition_after : compositionState();
    if (!state.has_value()) {
      const TextRange range =
          m_caret_.hasSelection() ? m_caret_.normalizedSelection() : TextRange{m_caret_.active, m_caret_.active};
      beginComposition(range, transaction);
      state = transaction.composition_after;
    }

    const TextRange current_range = state->current_range;
    if (!ImeProjection::ownsCompositionText(*state)) {
      state->baseline_text_raw = m_document_->getU8Text(current_range);
      transaction.composition_baseline_range = current_range;
      transaction.break_history_merge = true;
    }
    if (transaction.composition_replacement_index.has_value()) {
      transaction.physical_replacements[*transaction.composition_replacement_index].text = text;
    } else if (m_document_->getU8Text(current_range) != text) {
      transaction.composition_replacement_index = transaction.physical_replacements.size();
      transaction.physical_replacements.push_back({current_range, text});
    }
    const TextPosition new_end = calcPositionAfterInsert(current_range.start, text);
    state->current_range = {current_range.start, new_end};
    transaction.update_composition = true;
    transaction.composition_after = std::move(state);
    transaction.composition_text = text;
    transaction.caret_after.setSelection({new_end, new_end});
  }

  bool EditorCore::stageLinkedEdit(const TextRange& range, const U8String& text, EditTransaction& transaction) {
    if (!isInLinkedEditing()) return false;
    const std::optional<Vector<DocumentReplacement>> plan = planLinkedEdit(range, text);
    if (!plan.has_value()) {
      transaction.cancel_linked_editing = true;
      return false;
    }
    for (const DocumentReplacement& replacement : *plan) {
      const U8String old_text = m_document_->getU8Text(replacement.range);
      transaction.physical_replacements.push_back(replacement);
      transaction.committed_changes.push_back({replacement.range, old_text, replacement.text});
    }
    return true;
  }

  void EditorCore::appendLinkedCompositionEdits(const CompositionState& state, const TextRange& baseline_range,
                                                const U8String& final_text_raw, EditTransaction& transaction) {
    LinkedEditingSession* session = m_linked_editing_session_.get();
    if (session == nullptr) {
      return;
    }
    const TabStopGroup* group = session->currentGroup();
    if (!hasValidLinkedEditingGroup() || group == nullptr) {
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
      editing_primary.start = primary.start == baseline_range.start ? state.current_range.start : primary.start;
      editing_primary.end = primary.end == baseline_range.end
                                ? state.current_range.end
                                : ImeProjection::transformPosition(baseline_range, state.current_range.end, primary.end,
                                                                   ImeProjection::EndpointBias::AFTER);
    }
    if (!isDocumentRangeValid(editing_primary) || state.current_range.start < editing_primary.start
        || editing_primary.end < state.current_range.end) {
      transaction.cancel_linked_editing = true;
      return;
    }

    const U8String prefix = m_document_->getU8Text({editing_primary.start, state.current_range.start});
    const U8String suffix = m_document_->getU8Text({state.current_range.end, editing_primary.end});
    const U8String linked_text = prefix + final_text_raw + suffix;
    const Vector<std::pair<TextRange, U8String>> edits = session->computeLinkedEdits(linked_text);
    for (const auto& [committed_range, edit_text] : edits) {
      if (committed_range == group->ranges[0]) continue;
      const std::optional<TextRange> projected =
          ImeProjection::projectCommittedRange(*m_document_, compositionState(), committed_range);
      if (!projected.has_value() || !isDocumentRangeValid(*projected)) {
        transaction.cancel_linked_editing = true;
        return;
      }
      const TextRange& editing_secondary = *projected;
      const U8String secondary_text = m_document_->getU8Text(editing_secondary);
      if (secondary_text == edit_text) continue;
      transaction.physical_replacements.push_back({editing_secondary, edit_text});
      transaction.committed_changes.push_back({committed_range, secondary_text, edit_text});
    }
  }

  bool EditorCore::linkedRangesAffectedByChanges(const Vector<TextChange>& changes) const {
    if (m_linked_editing_session_ == nullptr || !m_linked_editing_session_->isActive()) {
      return false;
    }
    const Vector<LinkedEditingHighlight> highlights = m_linked_editing_session_->getAllHighlights();
    for (const TextChange& change : changes) {
      for (const LinkedEditingHighlight& highlight : highlights) {
        const bool affected =
            change.range.isCollapsed()
                ? highlight.range.start <= change.range.start && change.range.start <= highlight.range.end
                : change.range.overlaps(highlight.range)
                      || (highlight.range.isCollapsed() && change.range.start <= highlight.range.start
                          && highlight.range.start <= change.range.end);
        if (affected) {
          return true;
        }
      }
    }
    return false;
  }

  void EditorCore::settleComposition(const U8String& final_text_raw, EditTransaction& transaction,
                                     bool replace_current_text) {
    const std::optional<CompositionState>& staged_composition =
        transaction.update_composition ? transaction.composition_after : compositionState();
    if (!staged_composition.has_value()) {
      return;
    }

    const CompositionState state = *staged_composition;
    if (!ImeProjection::ownsCompositionText(state)) {
      if (replace_current_text) {
        const U8String old_text = m_document_->getU8Text(state.current_range);
        if (old_text != final_text_raw) {
          transaction.composition_replacement_index = transaction.physical_replacements.size();
          transaction.physical_replacements.push_back({state.current_range, final_text_raw});
          transaction.composition_text = final_text_raw;
          transaction.committed_changes.push_back({state.current_range, old_text, final_text_raw});
        }
        const TextPosition caret = calcPositionAfterInsert(state.current_range.start, final_text_raw);
        transaction.caret_after.setSelection({caret, caret});
        transaction.break_history_merge = true;
      }
      transaction.update_composition = true;
      transaction.composition_after.reset();
      return;
    }
    const TextRange baseline_range =
        transaction.composition_baseline_range.value_or(ImeProjection::baselineRange(state));
    const bool has_net_change = ImeProjection::logicalizeLineEndings(final_text_raw)
                                != ImeProjection::logicalizeLineEndings(*state.baseline_text_raw);

    transaction.caret_before = state.baseline_caret;
    transaction.break_history_merge = true;
    if (!has_net_change) {
      const U8String current_text = replace_current_text ? final_text_raw
                                    : transaction.composition_replacement_index.has_value()
                                        ? *transaction.composition_text
                                        : m_document_->getU8Text(state.current_range);
      if (current_text != *state.baseline_text_raw) {
        if (transaction.composition_replacement_index.has_value()) {
          DocumentReplacement& replacement =
              transaction.physical_replacements[*transaction.composition_replacement_index];
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
      const U8String& caret_text = has_net_change ? final_text_raw : *state.baseline_text_raw;
      const TextPosition caret = calcPositionAfterInsert(state.current_range.start, caret_text);
      transaction.caret_after.setSelection({caret, caret});
    }
    transaction.update_composition = true;
    transaction.composition_after.reset();
  }

  void EditorCore::cancelComposition(EditTransaction& transaction) {
    const std::optional<CompositionState>& staged_composition =
        transaction.update_composition ? transaction.composition_after : compositionState();
    if (!staged_composition.has_value()) {
      return;
    }
    const CompositionState& composition = *staged_composition;
    if (!ImeProjection::ownsCompositionText(composition)) {
      transaction.update_composition = true;
      transaction.composition_after.reset();
      return;
    }
    if (transaction.composition_replacement_index.has_value()) {
      DocumentReplacement& replacement = transaction.physical_replacements[*transaction.composition_replacement_index];
      replacement.text = *composition.baseline_text_raw;
    } else if (m_document_->getU8Text(composition.current_range) != *composition.baseline_text_raw) {
      transaction.physical_replacements.push_back({composition.current_range, *composition.baseline_text_raw});
    }
    transaction.caret_before = m_caret_;
    transaction.caret_after = composition.baseline_caret;
    transaction.break_history_merge = true;
    transaction.update_composition = true;
    transaction.composition_after.reset();
  }

  TextEditResult EditorCore::commitTransaction(EditTransaction& transaction) {
    TextEditResult result;
    if (m_document_ == nullptr) {
      return result;
    }

    std::sort(transaction.committed_changes.begin(), transaction.committed_changes.end(),
              [](const TextChange& lhs, const TextChange& rhs) {
                if (lhs.range.start != rhs.range.start) {
                  return lhs.range.start < rhs.range.start;
                }
                return lhs.range.end < rhs.range.end;
              });
    Vector<TextChange> normalized_changes;
    normalized_changes.reserve(transaction.committed_changes.size());
    for (TextChange& change : transaction.committed_changes) {
      if (!normalized_changes.empty() && normalized_changes.back().new_text.empty() && change.new_text.empty()
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
      m_document_->replaceU8TextBatch(transaction.physical_replacements);
      result.editing_content_changed = true;
    }

    if (transaction.update_composition) {
      m_ime_session_->composition = transaction.composition_after;
    }
    if (transaction.cancel_linked_editing && m_linked_editing_session_ != nullptr) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    if (!transaction.committed_changes.empty()) {
      for (auto it = transaction.committed_changes.rbegin(); it != transaction.committed_changes.rend(); ++it) {
        const TextPosition new_end = calcPositionAfterInsert(it->range.start, it->new_text);
        autoUnfoldForEdit(it->range);
        m_decorations_->adjustForEdit(it->range, new_end);
        if (m_linked_editing_session_ != nullptr) {
          m_linked_editing_session_->adjustRangesForEdit(it->range, new_end);
        }
        result.markHandled(replacementChangeKind(it->range, it->new_text));
      }
      noteDocumentContentChanged();
      result.changes = transaction.committed_changes;
      result.cursor_before = transaction.caret_before.active;
    }

    const std::optional<CompositionState>& composition = compositionState();
    if (composition.has_value() && ImeProjection::hasNonIdentityProjection(*m_document_, *composition)) {
      m_decorations_->setEditingProjection(ImeProjection::baselineRange(*composition), composition->current_range);
    } else {
      m_decorations_->clearEditingProjection();
    }

    restoreCaretState(transaction.caret_after);
    result.cursor_after = m_caret_.active;

    if (!transaction.committed_changes.empty()) {
      recordHistory(transaction.committed_changes, transaction.caret_before, transaction.caret_after);
      syncFoldState();
    } else if (!transaction.physical_replacements.empty() || transaction.update_composition) {
      syncFoldState();
    }
    if (!transaction.physical_replacements.empty() || transaction.update_composition) {
      markAllLinesDirty(true);
    }

    if (transaction.break_history_merge) {
      m_undo_manager_->breakMergeChain();
    }
    if (!transaction.physical_replacements.empty() || !transaction.committed_changes.empty()
        || transaction.break_history_merge) {
      ensureCursorVisible();
    }
    return result;
  }

  ImeActionResult EditorCore::applyTextUpdatePlan(const Vector<DocumentReplacement>& replacements,
                                                  const std::optional<TextRange>& composition_after,
                                                  const std::optional<TextRange>& rollover_baseline,
                                                  const U8String& composition_text, const CaretState& caret_after,
                                                  bool finish_after) {
    ImeActionResult result;
    result.handled = m_document_ != nullptr && !m_settings_.read_only;
    if (!result.handled) {
      return result;
    }

    EditTransaction transaction;
    transaction.caret_before = m_caret_;
    transaction.caret_after = caret_after;
    transaction.physical_replacements = replacements;
    transaction.break_history_merge = !replacements.empty();
    const std::optional<CompositionState>& initial_composition = compositionState();
    const bool initial_owns_text =
        initial_composition.has_value() && ImeProjection::ownsCompositionText(*initial_composition);
    if (initial_owns_text) {
      transaction.composition_baseline_range = ImeProjection::baselineRange(*initial_composition);
    }
    if (!initial_owns_text) {
      if (!composition_after.has_value()) {
        bool linked_edit_staged = false;
        if (!initial_composition.has_value() && replacements.size() == 1 && isInLinkedEditing()) {
          transaction.physical_replacements.clear();
          linked_edit_staged = stageLinkedEdit(replacements.front().range, replacements.front().text, transaction);
          if (!linked_edit_staged) {
            transaction.physical_replacements = replacements;
          }
        }
        if (!linked_edit_staged) {
          transaction.committed_changes.reserve(replacements.size());
          for (const DocumentReplacement& replacement : replacements) {
            const U8String old_text = m_document_->getU8Text(replacement.range);
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
        CompositionState state = initial_composition.value_or(CompositionState{});
        state.current_range = *composition_after;
        if (replacements.empty()) {
          state.baseline_text_raw.reset();
        } else {
          const TextRange baseline = replacements.front().range;
          state.baseline_text_raw = m_document_->getU8Text(baseline);
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
      const CaretState rollover_caret = m_caret_;
      U8String rollover_baseline_text;
      if (rollover_baseline.has_value()) {
        rollover_baseline_text = m_document_->getU8Text(*rollover_baseline);
        settleComposition(m_document_->getU8Text(current_range), transaction, false);
        transaction.composition_baseline_range = *rollover_baseline;
      }
      for (const DocumentReplacement& replacement : replacements) {
        if (rollover_baseline.has_value() && replacement.range == *rollover_baseline) {
          continue;
        }
        bool inside = current_range.start <= replacement.range.start && replacement.range.end <= current_range.end;
        if (inside && replacement.range.isCollapsed()
            && (replacement.range.start == current_range.start || replacement.range.start == current_range.end)
            && composition_after.has_value()) {
          const TextPosition inserted_end = calcPositionAfterInsert(replacement.range.start, replacement.text);
          inside = composition_after->start <= replacement.range.start && inserted_end <= composition_after->end;
        }
        if (inside) {
          continue;
        }
        if (replacement.range.overlaps(current_range)) {
          if (!replacement.text.empty()) {
            result.handled = false;
            return result;
          }
          const TextRange baseline = ImeProjection::baselineRange(*initial_composition);
          const TextPosition left_end = std::min(replacement.range.end, current_range.start);
          if (replacement.range.start < left_end) {
            const TextRange editing_left{replacement.range.start, left_end};
            transaction.committed_changes.push_back(
                {{ImeProjection::transformPosition(current_range, baseline.end, editing_left.start,
                                                   ImeProjection::EndpointBias::AFTER),
                  ImeProjection::transformPosition(current_range, baseline.end, editing_left.end,
                                                   ImeProjection::EndpointBias::BEFORE)},
                 m_document_->getU8Text(editing_left),
                 ""});
          }
          const TextPosition right_start = std::max(replacement.range.start, current_range.end);
          if (right_start < replacement.range.end) {
            const TextRange editing_right{right_start, replacement.range.end};
            transaction.committed_changes.push_back(
                {{ImeProjection::transformPosition(current_range, baseline.end, editing_right.start,
                                                   ImeProjection::EndpointBias::AFTER),
                  ImeProjection::transformPosition(current_range, baseline.end, editing_right.end,
                                                   ImeProjection::EndpointBias::BEFORE)},
                 m_document_->getU8Text(editing_right),
                 ""});
          }
          continue;
        }
        const TextRange baseline = ImeProjection::baselineRange(*initial_composition);
        TextRange committed_range;
        if (replacement.range.isCollapsed() && replacement.range.start == current_range.start) {
          committed_range = {baseline.start, baseline.start};
        } else if (replacement.range.isCollapsed() && replacement.range.start == current_range.end) {
          committed_range = {baseline.end, baseline.end};
        } else {
          committed_range = {ImeProjection::transformPosition(current_range, baseline.end, replacement.range.start,
                                                              ImeProjection::EndpointBias::AFTER),
                             ImeProjection::transformPosition(current_range, baseline.end, replacement.range.end,
                                                              ImeProjection::EndpointBias::BEFORE)};
        }
        const U8String old_text = m_document_->getU8Text(replacement.range);
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

  ImeActionResult EditorCore::applyCommandBatch(const Vector<ImeCommand>& commands) {
    ImeActionResult result;
    result.handled = m_document_ != nullptr && !m_settings_.read_only && !commands.empty();
    if (!result.handled) {
      return result;
    }

    EditTransaction transaction;
    transaction.caret_before = m_caret_;
    transaction.caret_after = m_caret_;
    const std::optional<CompositionState>& initial_composition = compositionState();
    if (initial_composition.has_value() && ImeProjection::ownsCompositionText(*initial_composition)) {
      transaction.composition_baseline_range = ImeProjection::baselineRange(*initial_composition);
    }
    const size_t initial_document_length = documentUtf16Length();

    auto stagedComposition = [&]() -> const std::optional<CompositionState>& {
      return transaction.update_composition ? transaction.composition_after : initial_composition;
    };
    auto stagedCompositionOffsets = [&]() -> std::pair<size_t, size_t> {
      const std::optional<CompositionState>& state = stagedComposition();
      if (!state.has_value()) {
        return {0, 0};
      }
      const size_t start =
          transaction.composition_replacement_index.has_value()
              ? m_document_->getCharIndexFromPosition(
                  transaction.physical_replacements[*transaction.composition_replacement_index].range.start)
              : m_document_->getCharIndexFromPosition(state->current_range.start);
      const size_t end = start
                         + (transaction.composition_replacement_index.has_value()
                                ? StrUtil::utf16Length(*transaction.composition_text)
                                : m_document_->getCharIndexFromPosition(state->current_range.end)
                                      - m_document_->getCharIndexFromPosition(state->current_range.start));
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
      std::stable_sort(replacements.begin(), replacements.end(),
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
        const TextPosition source_start = m_document_->getPositionFromCharIndex(source_offset);
        const TextPosition source_end = m_document_->getPositionFromCharIndex(target_offset);
        if (source_start.line == source_end.line) {
          staged_position.column += source_end.column - source_start.column;
        } else {
          staged_position.line += source_end.line - source_start.line;
          staged_position.column = source_end.column;
        }
        source_offset = target_offset;
      };

      for (const DocumentReplacement* replacement : replacements) {
        const size_t old_start = m_document_->getCharIndexFromPosition(replacement->range.start);
        const size_t old_end = m_document_->getCharIndexFromPosition(replacement->range.end);
        if (old_start < source_offset || old_end < old_start || old_end > initial_document_length) {
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
          StrUtil::convertUTF16ToUTF8(replacement_text.substr(0, prefix_length), prefix);
          return calcPositionAfterInsert(staged_position, prefix);
        }
        staged_position = calcPositionAfterInsert(staged_position, replacement->text);
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
      return TextRange{*start_position, *end_position};
    };
    auto resolveSelection = [&](const ImeSelection& selection) -> std::optional<CaretState> {
      ImeOffsetRange range{selection.coordinate_space, std::min(selection.anchor_utf16, selection.active_utf16),
                           std::max(selection.anchor_utf16, selection.active_utf16)};
      const std::optional<TextRange> resolved = resolveRange(range);
      if (!resolved.has_value()) {
        return std::nullopt;
      }
      CaretState caret;
      caret.anchor = selection.anchor_utf16 <= selection.active_utf16 ? resolved->start : resolved->end;
      caret.active = selection.anchor_utf16 <= selection.active_utf16 ? resolved->end : resolved->start;
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
          const TextRange range =
              target.value_or(transaction.caret_after.hasSelection()
                                  ? transaction.caret_after.normalizedSelection()
                                  : TextRange{transaction.caret_after.active, transaction.caret_after.active});
          beginComposition(range, transaction);
        }
        U8String composition_text = transaction.composition_text.has_value()
                                        ? *transaction.composition_text
                                        : m_document_->getU8Text(stagedComposition()->current_range);
        if (has_target && was_active) {
          if (command.target_range.coordinate_space != ImeCoordinateSpace::COMPOSITION) {
            result.handled = false;
            return result;
          }
          U16String utf16;
          StrUtil::convertUTF8ToUTF16(composition_text, utf16);
          const size_t start = static_cast<size_t>(command.target_range.start_utf16);
          const size_t end = static_cast<size_t>(command.target_range.end_utf16);
          if (end > utf16.size() || !UnicodeUtil::isCodePointBoundary(utf16, start)
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
          if (ImeProjection::ownsCompositionText(*stagedComposition())) {
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
          const TextRange staged_range =
              resolved_range.value_or(transaction.caret_after.hasSelection()
                                          ? transaction.caret_after.normalizedSelection()
                                          : TextRange{transaction.caret_after.active, transaction.caret_after.active});
          TextRange physical_range = staged_range;
          if (transaction.composition_replacement_index.has_value()) {
            const DocumentReplacement& composition_replacement =
                transaction.physical_replacements[*transaction.composition_replacement_index];
            const size_t staged_start = m_document_->getCharIndexFromPosition(composition_replacement.range.start);
            const size_t staged_end = staged_start + StrUtil::utf16Length(composition_replacement.text);
            const size_t target_start = staged_range.start == composition_replacement.range.start
                                            ? staged_start
                                            : m_document_->getCharIndexFromPosition(staged_range.start);
            const size_t target_end = m_document_->getCharIndexFromPosition(staged_range.end);
            if (target_start < staged_end && staged_start < target_end) {
              result.handled = false;
              return result;
            }
          }
          TextRange committed_range = physical_range;
          if (initial_composition.has_value() && ImeProjection::ownsCompositionText(*initial_composition)) {
            const TextRange initial_baseline = ImeProjection::baselineRange(*initial_composition);
            if (physical_range.overlaps(initial_composition->current_range)) {
              result.handled = false;
              return result;
            }
            committed_range = {
                ImeProjection::transformPosition(initial_composition->current_range, initial_baseline.end,
                                                 physical_range.start, ImeProjection::EndpointBias::AFTER),
                ImeProjection::transformPosition(initial_composition->current_range, initial_baseline.end,
                                                 physical_range.end, ImeProjection::EndpointBias::BEFORE)};
          }
          bool linked_edit_staged = false;
          if (!initial_composition.has_value() && transaction.physical_replacements.empty() && isInLinkedEditing()) {
            linked_edit_staged = stageLinkedEdit(physical_range, command.text, transaction);
          }
          if (!linked_edit_staged) {
            const U8String old_text = m_document_->getU8Text(physical_range);
            if (old_text != command.text) {
              transaction.physical_replacements.push_back({physical_range, command.text});
              transaction.committed_changes.push_back({committed_range, old_text, command.text});
            }
          }
          transaction.caret_after.setSelection({calcPositionAfterInsert(physical_range.start, command.text),
                                                calcPositionAfterInsert(physical_range.start, command.text)});
          transaction.break_history_merge = true;
        }
        break;
      }
      case ImeCommandKind::FINISH_COMPOSITION:
        if (stagedComposition().has_value()) {
          const U8String final_text = transaction.composition_text.has_value()
                                          ? *transaction.composition_text
                                          : m_document_->getU8Text(stagedComposition()->current_range);
          settleComposition(final_text, transaction, false);
        }
        break;
      case ImeCommandKind::CANCEL_COMPOSITION:
        cancelComposition(transaction);
        break;
      case ImeCommandKind::DELETE_SURROUNDING: {
        if (!transaction.physical_replacements.empty() || transaction.composition_replacement_index.has_value()) {
          result.handled = false;
          return result;
        }
        const Vector<TextRange> ranges =
            deletionRangesForCaret(transaction.caret_after, static_cast<size_t>(command.delete_before),
                                   static_cast<size_t>(command.delete_after), command.text_unit);
        if (ranges.empty()) {
          break;
        }

        const std::optional<CompositionState>& state = stagedComposition();
        const bool owns_text = state.has_value() && ImeProjection::ownsCompositionText(*state);
        bool linked_edit_staged = false;
        if (!state.has_value() && ranges.size() == 1 && isInLinkedEditing()) {
          linked_edit_staged = stageLinkedEdit(ranges.front(), "", transaction);
        }
        Vector<TextChange> editing_changes;
        if (!linked_edit_staged) {
          for (const TextRange& range : ranges) {
            transaction.physical_replacements.push_back({range, ""});
            editing_changes.push_back({range, m_document_->getU8Text(range), ""});
            if (!owns_text) {
              transaction.committed_changes.push_back({range, m_document_->getU8Text(range), ""});
              continue;
            }

            const TextRange baseline = ImeProjection::baselineRange(*state);
            const TextPosition left_end = std::min(range.end, state->current_range.start);
            if (range.start < left_end) {
              const TextRange editing_left{range.start, left_end};
              transaction.committed_changes.push_back(
                  {{ImeProjection::transformPosition(state->current_range, baseline.end, editing_left.start,
                                                     ImeProjection::EndpointBias::AFTER),
                    ImeProjection::transformPosition(state->current_range, baseline.end, editing_left.end,
                                                     ImeProjection::EndpointBias::BEFORE)},
                   m_document_->getU8Text(editing_left),
                   ""});
            }
            const TextPosition right_start = std::max(range.start, state->current_range.end);
            if (right_start < range.end) {
              const TextRange editing_right{right_start, range.end};
              transaction.committed_changes.push_back(
                  {{ImeProjection::transformPosition(state->current_range, baseline.end, editing_right.start,
                                                     ImeProjection::EndpointBias::AFTER),
                    ImeProjection::transformPosition(state->current_range, baseline.end, editing_right.end,
                                                     ImeProjection::EndpointBias::BEFORE)},
                   m_document_->getU8Text(editing_right),
                   ""});
            }
          }
        }
        if (owns_text) {
          U16String composition_text;
          StrUtil::convertUTF8ToUTF16(transaction.composition_text.has_value()
                                          ? *transaction.composition_text
                                          : m_document_->getU8Text(state->current_range),
                                      composition_text);
          const size_t composition_start = m_document_->getCharIndexFromPosition(state->current_range.start);
          Vector<std::pair<size_t, size_t>> composition_deletions;
          for (const TextRange& range : ranges) {
            const TextPosition overlap_start = std::max(range.start, state->current_range.start);
            const TextPosition overlap_end = std::min(range.end, state->current_range.end);
            if (overlap_start < overlap_end) {
              composition_deletions.push_back({m_document_->getCharIndexFromPosition(overlap_start) - composition_start,
                                               m_document_->getCharIndexFromPosition(overlap_end) - composition_start});
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
            next_state.current_range = {ImeProjection::transformPosition(*it, it->start, next_state.current_range.start,
                                                                         ImeProjection::EndpointBias::BEFORE),
                                        ImeProjection::transformPosition(*it, it->start, next_state.current_range.end,
                                                                         ImeProjection::EndpointBias::AFTER)};
          }
          next_state.baseline_caret = transformCaretForChanges(state->baseline_caret, transaction.committed_changes);
          transaction.update_composition = true;
          transaction.composition_after = next_state;
          transaction.caret_after = transformCaretForChanges(transaction.caret_after, editing_changes);
        } else if (linked_edit_staged) {
          Vector<TextChange> ordered_changes = transaction.committed_changes;
          std::sort(ordered_changes.begin(), ordered_changes.end(), [](const TextChange& lhs, const TextChange& rhs) {
            return lhs.range.start < rhs.range.start;
          });
          transaction.caret_after = transformCaretForChanges(transaction.caret_after, ordered_changes);
        } else {
          transaction.caret_after = transformCaretForChanges(transaction.caret_after, transaction.committed_changes);
          if (state.has_value()) {
            CompositionState next_state = *state;
            for (auto it = ranges.rbegin(); it != ranges.rend(); ++it) {
              next_state.current_range = {ImeProjection::transformPosition(*it, it->start,
                                                                           next_state.current_range.start,
                                                                           ImeProjection::EndpointBias::BEFORE),
                                          ImeProjection::transformPosition(*it, it->start, next_state.current_range.end,
                                                                           ImeProjection::EndpointBias::AFTER)};
            }
            next_state.baseline_caret =
                transformCaretForChanges(next_state.baseline_caret, transaction.committed_changes);
            transaction.update_composition = true;
            transaction.composition_after = std::move(next_state);
          }
        }
        if (!linked_edit_staged && linkedRangesAffectedByChanges(transaction.committed_changes)) {
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

  TextEditResult EditorCore::finishPreedit() {
    TextEditResult result;
    const std::optional<CompositionState>& composition = compositionState();
    if (composition.has_value() && m_document_ != nullptr && !m_settings_.read_only) {
      EditTransaction transaction;
      transaction.caret_before = composition->baseline_caret;
      transaction.caret_after = m_caret_;
      const U8String final_text = m_document_->getU8Text(composition->current_range);
      settleComposition(final_text, transaction, false);
      result = commitTransaction(transaction);
    }
    return result;
  }

  TextEditResult EditorCore::cancelPreedit() {
    TextEditResult result;
    if (compositionState().has_value() && m_document_ != nullptr) {
      EditTransaction transaction;
      transaction.caret_before = m_caret_;
      transaction.caret_after = m_caret_;
      cancelComposition(transaction);
      result = commitTransaction(transaction);
    }
    return result;
  }

  Vector<TextRange> EditorCore::deletionRangesForCaret(const CaretState& caret, size_t before_length,
                                                       size_t after_length, ImeTextUnit text_unit) const {
    if (m_document_ == nullptr) {
      return {};
    }

    const bool has_selection = caret.hasSelection();
    const TextRange selection = has_selection ? caret.normalizedSelection() : TextRange{caret.active, caret.active};
    TextPosition start = selection.start;
    TextPosition end = selection.end;
    for (size_t index = 0; index < before_length; ++index) {
      if (start.column > 0) {
        const U16String& line = m_document_->getLineU16TextRef(start.line);
        start.column = text_unit == ImeTextUnit::UNICODE_CODE_POINT
                           ? UnicodeUtil::prevCodePointColumn(line, start.column)
                           : start.column - 1;
      } else if (start.line > 0) {
        --start.line;
        start.column = m_document_->getLineColumns(start.line);
      }
    }
    for (size_t index = 0; index < after_length; ++index) {
      const U16String& line = m_document_->getLineU16TextRef(end.line);
      if (end.column < line.size()) {
        end.column = text_unit == ImeTextUnit::UNICODE_CODE_POINT ? UnicodeUtil::nextCodePointColumn(line, end.column)
                                                                  : end.column + 1;
      } else if (end.line + 1 < m_document_->getLineCount()) {
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

  ImeActionResult EditorCore::rejectImeMutation() {
    ImeActionResult result;
    result.handled = true;
    result.state = emptyImeState(ImeResultCode::REJECTED);
    if (hasPreedit()) {
      result.edit_result = finishPreedit();
    }
    closeImeSession();
    result.host_action = m_settings_.read_only ? ImeHostAction::CLOSE_SESSION : ImeHostAction::RESTART_SESSION;
    return result;
  }

  ImeState EditorCore::buildImeState() const {
    if (!m_ime_session_.has_value() || m_document_ == nullptr) {
      return emptyImeState(ImeResultCode::OK);
    }

    ImeState state;
    state.result_code = ImeResultCode::OK;
    state.session_id = m_ime_session_->session_id;
    state.state_revision =
        m_ime_session_->editing_buffer.has_value() ? m_ime_session_->editing_buffer->state_revision : 0;
    state.selection = {
        ImeCoordinateSpace::DOCUMENT, static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.anchor)),
        static_cast<int64_t>(m_document_->getCharIndexFromPosition(m_caret_.active)), m_caret_.active_affinity};
    if (getCompositionState().has_value()) {
      const TextRange range = getCompositionState()->current_range;
      state.composition_range = {ImeCoordinateSpace::DOCUMENT,
                                 static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.start)),
                                 static_cast<int64_t>(m_document_->getCharIndexFromPosition(range.end))};
    }
    return state;
  }

  ImeState EditorCore::emptyImeState(ImeResultCode result_code) const {
    ImeState state;
    state.result_code = result_code;
    return state;
  }

  bool EditorCore::hasMatchingImeSession(uint64_t session_id) const {
    return session_id != 0 && m_ime_session_.has_value() && m_ime_session_->session_id == session_id;
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
      return !has_target && has_selection && command.text.empty() && command.delete_before == 0
             && command.delete_after == 0 && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
    case ImeCommandKind::BEGIN_COMPOSITION:
      return has_target && command.text.empty() && command.delete_before == 0 && command.delete_after == 0
             && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
    case ImeCommandKind::UPDATE_COMPOSITION:
    case ImeCommandKind::COMMIT_TEXT:
      return command.delete_before == 0 && command.delete_after == 0
             && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
    case ImeCommandKind::FINISH_COMPOSITION:
    case ImeCommandKind::CANCEL_COMPOSITION:
      return !has_target && !has_selection && command.text.empty() && command.delete_before == 0
             && command.delete_after == 0 && command.text_unit == ImeTextUnit::UTF16_CODE_UNIT;
    case ImeCommandKind::DELETE_SURROUNDING:
      if (has_target || has_selection || !command.text.empty() || command.delete_before < 0 || command.delete_after < 0
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

  bool EditorCore::validateImeTextUpdateStep(const ImeTextUpdateStep& step) const {
    const bool has_patch = !isNoneRange(step.patch_range);
    const bool has_composition = !isNoneRange(step.composition_after);
    if (!isValidSelectionShape(step.selection_after)
        || step.selection_after.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER
        || (has_patch
            && (!isValidRangeShape(step.patch_range)
                || step.patch_range.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER))
        || (!has_patch && !step.replacement_text.empty())
        || (has_composition
            && (!isValidRangeShape(step.composition_after)
                || step.composition_after.coordinate_space != ImeCoordinateSpace::EDITING_BUFFER))) {
      return false;
    }
    return true;
  }

  EditorActionResult EditorCore::finishImeAction(const ActionSnapshot& before, const ImeActionResult& ime_result) {
    EditorActionResult result =
        finishAction(before, EditorActionSource::IME, ime_result.handled, ime_result.edit_result);
    if (ime_result.edit_result.editing_content_changed && !result.content_changed) {
      result.composition_changed = true;
    }
    result.ime_host_action = ime_result.host_action;
    result.ime_state = ime_result.state;
    result.needs_redraw = result.needs_redraw || result.composition_changed;
    return result;
  }

#pragma endregion
}
