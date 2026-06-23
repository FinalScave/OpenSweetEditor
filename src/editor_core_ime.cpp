//
// Created by Scave on 2025/12/1.
//
#include <algorithm>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {

  constexpr size_t LIMITED_IME_DOCUMENT_CONTEXT_LENGTH = 2048;

  struct ImeContextRange {
    bool active {false};
    size_t start {0};
    size_t end {0};
  };

  struct ImeInputTextDiff {
    bool changed {false};
    size_t start {0};
    size_t old_end {0};
    size_t new_end {0};
    U8String replacement;
  };

  static bool isImeTextWindowKind(ImeInputContextKind kind) {
    return kind == ImeInputContextKind::DOCUMENT_WINDOW
        || kind == ImeInputContextKind::TRANSIENT_INPUT;
  }

  static bool isImeTextWindowContext(const ImeInputContext& context) {
    return context.id != 0 && isImeTextWindowKind(context.kind);
  }

  static bool isImeDocumentWindowContext(const ImeInputContext& context) {
    return context.id != 0 && context.kind == ImeInputContextKind::DOCUMENT_WINDOW;
  }

  static bool isMatchingImeDocumentWindow(const ImeInputContext& context,
                                          uint64_t context_id,
                                          int32_t context_revision) {
    return context_id != 0
        && context_id == context.id
        && context_revision == context.revision
        && isImeDocumentWindowContext(context);
  }

  static ImeActionResult makeImeInputContextResyncResult(ImeSyncSnapshot sync) {
    ImeActionResult result;
    result.handled = true;
    result.sync = sync;
    result.sync.clear_system_mark = true;
    result.sync.context_policy = ImeContextPolicy::NONE;
    return result;
  }

  static size_t clampImeOffset(int32_t offset, size_t length) {
    if (offset < 0) {
      return 0;
    }
    return std::min(static_cast<size_t>(offset), length);
  }

  static size_t clampSignedImeOffset(int64_t offset, size_t length) {
    return static_cast<size_t>(std::max<int64_t>(0, std::min<int64_t>(offset, static_cast<int64_t>(length))));
  }

  static ImeContextRange normalizeImeSelectionRange(int32_t start, int32_t end, size_t text_length) {
    if (start < 0 || end < 0) {
      return {true, text_length, text_length};
    }
    size_t safe_start = clampImeOffset(start, text_length);
    size_t safe_end = clampImeOffset(end, text_length);
    if (safe_start > safe_end) {
      std::swap(safe_start, safe_end);
    }
    return {true, safe_start, safe_end};
  }

  static ImeContextRange normalizeImeComposingRange(int32_t start, int32_t end, size_t text_length) {
    if (start < 0 || end < 0) {
      return {};
    }
    size_t safe_start = clampImeOffset(start, text_length);
    size_t safe_end = clampImeOffset(end, text_length);
    if (safe_start > safe_end) {
      std::swap(safe_start, safe_end);
    }
    if (safe_start == safe_end) {
      return {};
    }
    return {true, safe_start, safe_end};
  }

  static U8String sliceUtf16Text(const U8String& text, size_t start, size_t end) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);
    start = std::min(start, utf16.size());
    end = std::min(end, utf16.size());
    if (start > end) {
      std::swap(start, end);
    }
    U16String sub = utf16.substr(start, end - start);
    U8String result;
    StrUtil::convertUTF16ToUTF8(sub, result);
    return result;
  }

  static U8String replaceUtf16TextRange(const U8String& text,
                                        size_t start,
                                        size_t end,
                                        const U8String& replacement) {
    U16String utf16;
    U16String replacement_utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);
    StrUtil::convertUTF8ToUTF16(replacement, replacement_utf16);
    start = std::min(start, utf16.size());
    end = std::min(end, utf16.size());
    if (start > end) {
      std::swap(start, end);
    }
    utf16.replace(start, end - start, replacement_utf16);
    U8String result;
    StrUtil::convertUTF16ToUTF8(utf16, result);
    return result;
  }

  static ImeInputTextDiff computeImeInputTextDiff(const U8String& old_text, const U8String& new_text) {
    U16String old_utf16;
    U16String new_utf16;
    StrUtil::convertUTF8ToUTF16(old_text, old_utf16);
    StrUtil::convertUTF8ToUTF16(new_text, new_utf16);

    size_t prefix = 0;
    const size_t max_prefix = std::min(old_utf16.size(), new_utf16.size());
    while (prefix < max_prefix && old_utf16[prefix] == new_utf16[prefix]) {
      ++prefix;
    }

    size_t old_suffix = old_utf16.size();
    size_t new_suffix = new_utf16.size();
    while (old_suffix > prefix
           && new_suffix > prefix
           && old_utf16[old_suffix - 1] == new_utf16[new_suffix - 1]) {
      --old_suffix;
      --new_suffix;
    }

    ImeInputTextDiff diff;
    diff.changed = prefix != old_utf16.size() || prefix != new_utf16.size();
    diff.start = prefix;
    diff.old_end = old_suffix;
    diff.new_end = new_suffix;
    if (new_suffix > prefix) {
      U16String replacement_u16(new_utf16.begin() + static_cast<std::ptrdiff_t>(prefix),
                                new_utf16.begin() + static_cast<std::ptrdiff_t>(new_suffix));
      StrUtil::convertUTF16ToUTF8(replacement_u16, diff.replacement);
    }
    return diff;
  }

  static ImeContextRange transformImeRangeToPreviousText(const ImeContextRange& range,
                                                            const ImeInputTextDiff& diff,
                                                            size_t old_text_length) {
    if (!range.active) {
      return {};
    }

    const size_t normalized_start = std::min(diff.start, old_text_length);
    const size_t normalized_end = std::min(diff.old_end, old_text_length);
    const size_t inserted_end = diff.new_end;
    int64_t start = 0;
    int64_t end = 0;
    if (range.end <= normalized_start) {
      start = static_cast<int64_t>(range.start);
      end = static_cast<int64_t>(range.end);
    } else if (range.start >= inserted_end) {
      const int64_t replacement_delta =
          static_cast<int64_t>(normalized_end - normalized_start)
          - static_cast<int64_t>(diff.new_end - diff.start);
      start = static_cast<int64_t>(range.start) + replacement_delta;
      end = static_cast<int64_t>(range.end) + replacement_delta;
    } else {
      start = static_cast<int64_t>(range.start < normalized_start ? range.start : normalized_start);
      const size_t unchanged_tail = range.end > inserted_end ? range.end - inserted_end : 0;
      end = static_cast<int64_t>(normalized_end + unchanged_tail);
    }

    size_t safe_start = clampSignedImeOffset(start, old_text_length);
    size_t safe_end = clampSignedImeOffset(end, old_text_length);
    if (safe_start > safe_end) {
      std::swap(safe_start, safe_end);
    }
    return {safe_start != safe_end, safe_start, safe_end};
  }

  static bool imeDiffTouchesPreviousRange(const ImeInputTextDiff& diff,
                                          const ImeContextRange& range) {
    if (!diff.changed || !range.active) {
      return false;
    }
    if (diff.start == diff.old_end) {
      return diff.start >= range.start && diff.start <= range.end;
    }
    return diff.start < range.end && diff.old_end > range.start;
  }

  static bool imeTextPreservesPreviousRangeContext(const U8String& old_text,
                                                   const U8String& new_text,
                                                   const ImeContextRange& range) {
    U16String old_utf16;
    U16String new_utf16;
    StrUtil::convertUTF8ToUTF16(old_text, old_utf16);
    StrUtil::convertUTF8ToUTF16(new_text, new_utf16);

    const size_t range_start = std::min(range.start, old_utf16.size());
    const size_t range_end = std::min(range.end, old_utf16.size());
    const size_t suffix_length = old_utf16.size() - range_end;
    if (new_utf16.size() < range_start + suffix_length) {
      return false;
    }
    for (size_t i = 0; i < range_start; ++i) {
      if (old_utf16[i] != new_utf16[i]) {
        return false;
      }
    }
    const size_t new_suffix_start = new_utf16.size() - suffix_length;
    for (size_t i = 0; i < suffix_length; ++i) {
      if (old_utf16[range_end + i] != new_utf16[new_suffix_start + i]) {
        return false;
      }
    }
    return true;
  }

  static U8String sliceReplacementForPreviousRange(const U8String& old_text,
                                                   const U8String& new_text,
                                                   const ImeContextRange& range) {
    U16String old_utf16;
    U16String new_utf16;
    StrUtil::convertUTF8ToUTF16(old_text, old_utf16);
    StrUtil::convertUTF8ToUTF16(new_text, new_utf16);

    const size_t range_start = std::min(range.start, old_utf16.size());
    const size_t range_end = std::min(range.end, old_utf16.size());
    const size_t suffix_length = old_utf16.size() - range_end;
    const size_t replacement_start = std::min(range_start, new_utf16.size());
    size_t replacement_end = new_utf16.size() >= suffix_length
        ? new_utf16.size() - suffix_length
        : replacement_start;
    if (replacement_end < replacement_start) {
      replacement_end = replacement_start;
    }
    return sliceUtf16Text(new_text, replacement_start, replacement_end);
  }

  static void mergeImeActionResult(ImeActionResult& target, const ImeActionResult& source) {
    const bool clear_system_mark = target.sync.clear_system_mark || source.sync.clear_system_mark;
    target.handled = target.handled || source.handled;
    target.content_changed = target.content_changed || source.content_changed;
    target.cursor_changed = target.cursor_changed || source.cursor_changed;
    target.selection_changed = target.selection_changed || source.selection_changed;
    if (source.edit_result.contentChanged()) {
      if (!target.edit_result.contentChanged()) {
        target.edit_result = source.edit_result;
      } else {
        target.edit_result.markHandled(source.edit_result.change_kind);
        target.edit_result.changes.insert(target.edit_result.changes.end(),
                                          source.edit_result.changes.begin(),
                                          source.edit_result.changes.end());
        target.edit_result.cursor_after = source.edit_result.cursor_after;
      }
    }
    target.sync = source.sync;
    target.sync.clear_system_mark = clear_system_mark;
  }

#pragma region [IME]

  EditorActionResult EditorCore::handleImeCommandMessage(const ImeCommandMessage& message) {
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, handleImeCommandMessageInternal(message));
  }

  EditorActionResult EditorCore::handleImeTextUpdateMessage(const ImeTextUpdateMessage& message) {
    const ActionSnapshot before = captureActionSnapshot();
    ImeActionResult result;
    switch (message.kind) {
      case ImeTextUpdateKind::SNAPSHOT:
        result = handleImeTextSnapshotInternal(message.scope,
                                               message.context_id,
                                               message.context_revision,
                                               message.document_start_offset,
                                               message.text,
                                               message.selection.start,
                                               message.selection.end,
                                               message.marked_range,
                                               message.script_class);
        break;
      case ImeTextUpdateKind::PATCH:
        result = handleImeTextPatchInternal(message.scope,
                                            message.context_id,
                                            message.context_revision,
                                            message.document_start_offset,
                                            message.text,
                                            message.patch.range.start,
                                            message.patch.range.end,
                                            message.patch.text,
                                            message.selection.start,
                                            message.selection.end,
                                            message.marked_range,
                                            message.script_class);
        break;
    }
    return finishImeAction(before, result);
  }

  ImeActionResult EditorCore::setImePreeditTextInternal(const U8String& text, ImeScriptClass script_class) {
    return m_composition_controller_.updatePreedit(text, script_class);
  }

  ImeActionResult EditorCore::setImePreeditTextInternal(const U8String& text,
                                                  int cursor_offset,
                                                  ImeScriptClass script_class) {
    ImeActionResult result = setImePreeditTextInternal(text, script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::setImePreeditTextInternal(const U8String& text,
                                                  size_t selection_start_offset,
                                                  size_t selection_end_offset,
                                                  ImeScriptClass script_class) {
    ImeActionResult result = setImePreeditTextInternal(text, script_class);
    TextRange selection_range = textRangeFromImeCompositionOffsets(
        result,
        selection_start_offset,
        selection_end_offset);
    ImeActionResult selection_result = notifyImeSelectionChangedInternal(selection_range);
    mergeImeActionResult(result, selection_result);
    return result;
  }

  ImeActionResult EditorCore::applyImeCommitTextCommandInternal(const U8String& text, ImeScriptClass script_class) {
    return m_composition_controller_.commitText(text, script_class);
  }

  ImeActionResult EditorCore::applyImeCommitTextCommandInternal(const U8String& text,
                                            int cursor_offset,
                                            ImeScriptClass script_class) {
    ImeActionResult result = applyImeCommitTextCommandInternal(text, script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::applyImeFinishPreeditCommandInternal() {
    return m_composition_controller_.finishPreedit();
  }

  ImeActionResult EditorCore::applyImeCancelPreeditCommandInternal() {
    return m_composition_controller_.cancelPreedit();
  }

  ImeActionResult EditorCore::setImePreeditRangeInternal(const TextRange& range,
                                                   ImeScriptClass script_class) {
    return m_composition_controller_.markDocumentRange(range, script_class);
  }

  ImeActionResult EditorCore::setImePreeditRangeInternal(size_t start_offset,
                                                   size_t end_offset,
                                                   ImeScriptClass script_class) {
    TextRange range = textRangeFromUtf16Offsets(start_offset, end_offset);
    if (range.start == range.end) {
      return applyImeFinishPreeditCommandInternal();
    }
    return setImePreeditRangeInternal(range, script_class);
  }

  ImeActionResult EditorCore::replaceImeDocumentRangeInternal(const TextRange& range,
                                             const U8String& text,
                                             ImeScriptClass script_class) {
    return m_composition_controller_.replaceText(range, text, script_class);
  }

  ImeActionResult EditorCore::handleImeCommandMessageInternal(const ImeCommandMessage& message) {
    auto non_negative_length = [](int32_t length) {
      return length < 0 ? static_cast<size_t>(0) : static_cast<size_t>(length);
    };
    const auto has_message_selection = [&]() {
      return message.selection.start >= 0 || message.selection.end >= 0;
    };
    const auto has_valid_message_selection = [&]() {
      return message.selection.start >= 0 && message.selection.end >= 0;
    };
    const auto message_selection = [&]() {
      return has_message_selection()
          ? message.selection
          : message.range;
    };
    const bool matches_input_context = isMatchingImeDocumentWindow(
        m_ime_input_context_,
        message.context_id,
        message.context_revision);
    const bool has_context = message.context_id != 0;
    const bool had_system_mark_range =
        m_ime_text_update_has_system_mark_range_
        || m_ime_input_context_.has_system_mark_range;
    const auto clear_system_mark_range = [&]() -> ImeActionResult {
      clearImeTextUpdateSystemMarkRange();
      m_ime_input_context_.has_system_mark_range = false;
      m_ime_input_context_.system_mark_range = {-1, -1};
      ImeActionResult result;
      result.handled = true;
      result.sync = getImeSyncSnapshot();
      result.sync.clear_system_mark = true;
      return result;
    };
    const auto mark_system_mark_clear = [&](ImeActionResult& result) {
      if (had_system_mark_range) {
        result.sync.clear_system_mark = true;
      }
    };
    switch (message.kind) {
      case ImeCommandKind::SET_SELECTION: {
        const ImeOffsetRange selection = message_selection();
        return setImeContextSelectionInternal(message.context_id,
                                                    message.context_revision,
                                                    message.document_start_offset,
                                                    selection.start,
                                                    selection.end);
      }
      case ImeCommandKind::SET_PREEDIT_TEXT: {
        if (has_context && !matches_input_context) {
          return makeImeInputContextResyncResult(getImeSyncSnapshot());
        }
        ImeActionResult result;
        if (had_system_mark_range) {
          mergeImeActionResult(result, clear_system_mark_range());
        }
        ImeActionResult preedit_result;
        if (has_message_selection()) {
          const ImeOffsetRange selection = message_selection();
          preedit_result = setImePreeditTextInternal(
              message.text,
              non_negative_length(selection.start),
              non_negative_length(selection.end),
              message.script_class);
        } else {
          preedit_result = setImePreeditTextInternal(
              message.text,
              message.cursor_offset,
              message.script_class);
        }
        mergeImeActionResult(result, preedit_result);
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::COMMIT_TEXT: {
        if (has_context && !matches_input_context) {
          return makeImeInputContextResyncResult(getImeSyncSnapshot());
        }
        clear_system_mark_range();
        ImeActionResult result = applyImeCommitTextCommandInternal(
            message.text,
            message.cursor_offset,
            message.script_class);
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::FINISH_PREEDIT: {
        clear_system_mark_range();
        ImeActionResult result = applyImeFinishPreeditCommandInternal();
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::CANCEL_PREEDIT: {
        clear_system_mark_range();
        ImeActionResult result = applyImeCancelPreeditCommandInternal();
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::SET_MARKED_RANGE: {
        if (!matches_input_context) {
          return makeImeInputContextResyncResult(getImeSyncSnapshot());
        }
        if (message.marked_role == ImeMarkedRangeRole::PREEDIT) {
          clear_system_mark_range();
          const size_t context_text_length = StrUtil::utf16Length(m_ime_input_context_.text);
          const size_t start = clampImeOffset(message.range.start, context_text_length);
          const size_t end = clampImeOffset(message.range.end, context_text_length);
          if (start == end) {
            ImeActionResult result = applyImeFinishPreeditCommandInternal();
            mark_system_mark_clear(result);
            return result;
          }
          ImeActionResult result = setImePreeditRangeInternal(
              textRangeFromImeContextOffsets(message.context_id,
                                             message.context_revision,
                                             message.document_start_offset,
                                             start,
                                             end),
              message.script_class);
          mark_system_mark_clear(result);
          return result;
        }
        return setImeContextSystemMarkRangeInternal(message.context_id,
                                                         message.context_revision,
                                                         message.document_start_offset,
                                                         message.range.start,
                                                         message.range.end);
      }
      case ImeCommandKind::CLEAR_MARKED_RANGE: {
        if (message.marked_role == ImeMarkedRangeRole::SYSTEM_MARK) {
          return clear_system_mark_range();
        }
        if (message.marked_role == ImeMarkedRangeRole::PREEDIT) {
          return applyImeFinishPreeditCommandInternal();
        }
        ImeActionResult result = applyImeFinishPreeditCommandInternal();
        mergeImeActionResult(result, clear_system_mark_range());
        return result;
      }
      case ImeCommandKind::REPLACE_TEXT: {
        if (!matches_input_context) {
          return makeImeInputContextResyncResult(getImeSyncSnapshot());
        }
        clear_system_mark_range();
        const size_t context_text_length = matches_input_context
            ? StrUtil::utf16Length(m_ime_input_context_.text)
            : 0;
        ImeActionResult result = replaceImeContextTextInternal(
            message.context_id,
            message.context_revision,
            message.document_start_offset,
            clampImeOffset(message.range.start, context_text_length),
            clampImeOffset(message.range.end, context_text_length),
            message.text,
            message.cursor_offset,
            message.script_class);
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::DELETE_SURROUNDING_TEXT: {
        if (has_context && !matches_input_context) {
          return makeImeInputContextResyncResult(getImeSyncSnapshot());
        }
        if (has_valid_message_selection() && matches_input_context) {
          const size_t context_text_length = StrUtil::utf16Length(m_ime_input_context_.text);
          const size_t selection_start = clampImeOffset(message.selection.start, context_text_length);
          const size_t selection_end = clampImeOffset(message.selection.end, context_text_length);
          setSelectionInternal(
              textRangeFromImeContextOffsets(message.context_id,
                                             message.context_revision,
                                             message.document_start_offset,
                                             selection_start,
                                             selection_end),
              false);
        }
        const size_t delete_before = non_negative_length(message.delete_before);
        const size_t delete_after = non_negative_length(message.delete_after);
        clear_system_mark_range();
        ImeActionResult result = deleteImeSurroundingInternal(
            delete_before,
            delete_after,
            message.text_unit);
        mark_system_mark_clear(result);
        return result;
      }
      case ImeCommandKind::SET_KEYBOARD_SCRIPT: {
        m_composition_controller_.setKeyboardScriptClass(message.script_class);
        ImeActionResult result;
        result.handled = true;
        result.sync = getImeSyncSnapshot();
        return result;
      }
    }

    ImeActionResult result;
    return result;
  }

  ImeActionResult EditorCore::replaceImeDocumentTextByOffsetInternal(size_t start_offset,
                                                     size_t end_offset,
                                                     const U8String& text,
                                                     int cursor_offset,
                                                     ImeScriptClass script_class) {
    ImeActionResult result = replaceImeDocumentRangeInternal(
        textRangeFromUtf16Offsets(start_offset, end_offset),
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::setImeDocumentSelectionByOffsetInternal(size_t start_offset, size_t end_offset) {
    return notifyImeSelectionChangedInternal(textRangeFromUtf16Offsets(start_offset, end_offset));
  }

  ImeActionResult EditorCore::applyImeDocumentWindowSnapshotInternal(uint64_t context_id,
                                                      int32_t context_revision,
                                                      int32_t document_start_offset,
                                                      const U8String& text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      ImeMarkedRange marked_range,
                                                      ImeScriptClass script_class) {
    ImeActionResult result;
    if (m_document_ == nullptr || m_settings_.read_only) {
      return result;
    }

    const bool matches_input_context =
        isMatchingImeDocumentWindow(m_ime_input_context_, context_id, context_revision);
    ImeInputContext previous_context = m_ime_input_context_;
    if (!matches_input_context) {
      if (context_id == 0
          || !isImeDocumentWindowContext(m_ime_input_context_)
          || m_ime_input_context_.document_start_offset != document_start_offset) {
        return makeImeInputContextResyncResult(getImeSyncSnapshot());
      }
      const size_t text_length = StrUtil::utf16Length(text);
      const size_t document_start = static_cast<size_t>(
          std::max<int32_t>(0, document_start_offset));
      size_t context_length = text_length;
      context_length = std::max(context_length, StrUtil::utf16Length(m_ime_input_context_.text));
      previous_context.has_composition = m_ime_input_context_.has_composition;
      previous_context.composition = m_ime_input_context_.composition;
      previous_context.has_system_mark_range = m_ime_input_context_.has_system_mark_range;
      previous_context.system_mark_range = m_ime_input_context_.system_mark_range;
      previous_context.id = context_id;
      previous_context.revision = context_revision;
      previous_context.document_start_offset = static_cast<int32_t>(document_start);
      previous_context.text = m_document_->getU8Text(
          textRangeFromUtf16Offsets(document_start, document_start + context_length));
      previous_context.selection = {selection_start_offset, selection_end_offset};
      previous_context.kind = ImeInputContextKind::DOCUMENT_WINDOW;
    }
    const size_t old_text_length = StrUtil::utf16Length(previous_context.text);
    const size_t new_text_length = StrUtil::utf16Length(text);
    const ImeInputTextDiff diff = computeImeInputTextDiff(previous_context.text, text);
    const ImeContextRange selection = normalizeImeSelectionRange(
        selection_start_offset,
        selection_end_offset,
        new_text_length);
    const ImeContextRange reported_marked_range = normalizeImeComposingRange(
        marked_range.range.start,
        marked_range.range.end,
        new_text_length);
    const bool marked_range_is_composition =
        marked_range.role == ImeMarkedRangeRole::PREEDIT;
    const bool marked_range_is_platform =
        marked_range.role == ImeMarkedRangeRole::SYSTEM_MARK;
    const ImeContextRange new_composition =
        marked_range_is_composition ? reported_marked_range : ImeContextRange {};
    const ImeContextRange new_system_mark =
        marked_range_is_platform ? reported_marked_range : ImeContextRange {};
    const ImeContextRange old_composition = previous_context.has_composition
                                               ? normalizeImeComposingRange(
                                                   previous_context.composition.start,
                                                   previous_context.composition.end,
                                                   old_text_length)
                                               : ImeContextRange {};
    const ImeContextRange old_system_mark =
        previous_context.has_system_mark_range
        ? normalizeImeComposingRange(previous_context.system_mark_range.start,
                                     previous_context.system_mark_range.end,
                                     old_text_length)
        : ImeContextRange {};
    const size_t document_start = static_cast<size_t>(
        std::max<int32_t>(0, previous_context.document_start_offset));
    const bool had_visible_composition = isComposing();
    const bool new_system_mark_only =
        new_system_mark.active && !new_composition.active;
    const bool clears_previous_system_mark =
        old_system_mark.active && !new_system_mark.active;
    const auto notify_reported_selection = [&]() {
      mergeImeActionResult(result, setImeDocumentSelectionByOffsetInternal(
          document_start + selection.start,
          document_start + selection.end));
    };

    if (diff.changed) {
      const bool replaces_previous_composition =
          old_composition.active
          && imeDiffTouchesPreviousRange(diff, old_composition)
          && imeTextPreservesPreviousRangeContext(previous_context.text, text, old_composition);
      if (replaces_previous_composition) {
        mergeImeActionResult(result, setImePreeditRangeInternal(
            document_start + old_composition.start,
            document_start + old_composition.end,
            script_class));
        if (new_composition.active) {
          const U8String preedit_text = sliceUtf16Text(text, new_composition.start, new_composition.end);
          const size_t composing_length = new_composition.end - new_composition.start;
          const auto relative_offset = [&](size_t offset) {
            if (offset <= new_composition.start) {
              return static_cast<size_t>(0);
            }
            if (offset >= new_composition.end) {
              return composing_length;
            }
            return offset - new_composition.start;
          };
          mergeImeActionResult(result, setImePreeditTextInternal(
              preedit_text,
              relative_offset(selection.start),
              relative_offset(selection.end),
              script_class));
        } else {
          const U8String replacement = sliceReplacementForPreviousRange(
              previous_context.text,
              text,
              old_composition);
          mergeImeActionResult(result, applyImeCommitTextCommandInternal(replacement, script_class));
        }
      } else if (new_composition.active) {
        ImeContextRange previous_composition = transformImeRangeToPreviousText(
            new_composition,
            diff,
            old_text_length);
        if (!previous_composition.active && old_composition.active) {
          previous_composition = old_composition;
        }
        if (previous_composition.active) {
          mergeImeActionResult(result, setImePreeditRangeInternal(
              document_start + previous_composition.start,
              document_start + previous_composition.end,
              script_class));
        } else {
          const size_t insertion_offset = document_start + std::min(diff.start, old_text_length);
          mergeImeActionResult(result, setImeDocumentSelectionByOffsetInternal(insertion_offset, insertion_offset));
        }

        const U8String preedit_text = sliceUtf16Text(text, new_composition.start, new_composition.end);
        const size_t composing_length = new_composition.end - new_composition.start;
        const auto relative_offset = [&](size_t offset) {
          if (offset <= new_composition.start) {
            return static_cast<size_t>(0);
          }
          if (offset >= new_composition.end) {
            return composing_length;
          }
          return offset - new_composition.start;
        };
        mergeImeActionResult(result, setImePreeditTextInternal(
            preedit_text,
            relative_offset(selection.start),
            relative_offset(selection.end),
            script_class));
      } else if (old_composition.active || isComposing()) {
        mergeImeActionResult(result, applyImeCommitTextCommandInternal(diff.replacement, script_class));
      } else {
        mergeImeActionResult(result, replaceImeDocumentTextByOffsetInternal(
            document_start + diff.start,
            document_start + diff.old_end,
            diff.replacement,
            1,
            script_class));
      }
      if (new_system_mark_only) {
        notify_reported_selection();
      }
    } else if (new_composition.active) {
      const bool had_document_range_composition =
          had_visible_composition && getCompositionState().kind == CompositionKind::DOCUMENT_RANGE;
      if (!had_visible_composition || had_document_range_composition) {
        mergeImeActionResult(result, setImePreeditRangeInternal(
            document_start + new_composition.start,
            document_start + new_composition.end,
            script_class));
        mergeImeActionResult(result, setImeDocumentSelectionByOffsetInternal(
            document_start + selection.start,
            document_start + selection.end));
      } else {
        const U8String preedit_text = sliceUtf16Text(text, new_composition.start, new_composition.end);
        const size_t composing_length = new_composition.end - new_composition.start;
        const auto relative_offset = [&](size_t offset) {
          if (offset <= new_composition.start) {
            return static_cast<size_t>(0);
          }
          if (offset >= new_composition.end) {
            return composing_length;
          }
          return offset - new_composition.start;
        };
        mergeImeActionResult(result, setImePreeditTextInternal(
            preedit_text,
            relative_offset(selection.start),
            relative_offset(selection.end),
            script_class));
      }
    } else if (new_system_mark_only) {
      result.handled = true;
      notify_reported_selection();
    } else if (old_composition.active || isComposing()) {
      mergeImeActionResult(result, applyImeFinishPreeditCommandInternal());
    } else if (old_system_mark.active) {
      result.handled = true;
    }

    if (!new_composition.active && !new_system_mark_only) {
      mergeImeActionResult(result, setImeDocumentSelectionByOffsetInternal(
          document_start + selection.start,
          document_start + selection.end));
    }

    rememberImeDocumentWindowContext(context_id,
                          context_revision,
                          previous_context.document_start_offset,
                          text,
                          selection_start_offset,
                          selection_end_offset,
                          marked_range,
                          previous_context.kind);
    const bool clear_system_mark =
        (result.sync.clear_system_mark || clears_previous_system_mark) && !new_system_mark.active;
    if (new_system_mark_only) {
      rememberImeTextUpdateSystemMarkRange(context_id,
                                              context_revision,
                                              previous_context.document_start_offset,
                                              new_system_mark.start,
                                              new_system_mark.end);
    } else {
      clearImeTextUpdateSystemMarkRange();
    }
    if (result.handled) {
      result.sync = buildImeSyncSnapshot();
      result.sync.clear_system_mark = result.sync.clear_system_mark || clear_system_mark;
    }
    return result;
  }

  ImeActionResult EditorCore::handleImeTextSnapshotInternal(ImeTextUpdateScope mode,
                                                      uint64_t context_id,
                                                      int32_t context_revision,
                                                      int32_t document_start_offset,
                                                      const U8String& text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      ImeMarkedRange marked_range,
                                                      ImeScriptClass script_class) {
    if (mode == ImeTextUpdateScope::DOCUMENT_WINDOW) {
      resetImeTextUpdatePendingState();
      return applyImeDocumentWindowSnapshotInternal(context_id,
                                     context_revision,
                                     document_start_offset,
                                     text,
                                     selection_start_offset,
                                     selection_end_offset,
                                     marked_range,
                                     script_class);
    }

    ImeActionResult result;
    if (m_document_ == nullptr || m_settings_.read_only) {
      return result;
    }

    resetImeTextUpdatePendingState();
    const bool stale_context = context_id != 0
        && isImeTextWindowContext(m_ime_input_context_)
        && context_id != m_ime_input_context_.id;
    if (stale_context) {
      result.handled = true;
      result.sync = getImeSyncSnapshot();
      result.sync.clear_system_mark = true;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    const ImeContextRange composition = normalizeImeComposingRange(
        marked_range.range.start,
        marked_range.range.end,
        StrUtil::utf16Length(text));
    if (marked_range.role == ImeMarkedRangeRole::PREEDIT && composition.active) {
      rememberImeDocumentWindowContext(context_id,
                            context_revision,
                            0,
                            text,
                            selection_start_offset,
                            selection_end_offset,
                            marked_range,
                            ImeInputContextKind::TRANSIENT_INPUT);
      result.handled = true;
      result.sync = getImeSyncSnapshot();
      result.sync.clear_system_mark = false;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    const bool had_text_update_state = isImeTextWindowContext(m_ime_input_context_)
        && (!m_ime_input_context_.text.empty()
            || m_ime_input_context_.has_composition
            || m_ime_input_context_.has_system_mark_range);
    if (!text.empty()) {
      result = applyImeCommitTextCommandInternal(text, script_class);
      invalidateImeInputContext();
      result.sync.clear_system_mark = true;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    result.handled = true;
    result.sync = getImeSyncSnapshot();
    result.sync.clear_system_mark = had_text_update_state;
    result.sync.context_policy = ImeContextPolicy::NONE;
    if (had_text_update_state) {
      invalidateImeInputContext();
    }
    return result;
  }

  ImeActionResult EditorCore::handleImeTextPatchInternal(ImeTextUpdateScope mode,
                                                      uint64_t context_id,
                                                      int32_t context_revision,
                                                      int32_t document_start_offset,
                                                      const U8String& old_text,
                                                      int32_t delta_start_offset,
                                                      int32_t delta_end_offset,
                                                      const U8String& delta_text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      ImeMarkedRange marked_range,
                                                      ImeScriptClass script_class) {
    const bool has_text_delta = delta_start_offset >= 0 && delta_end_offset >= 0;
    const size_t old_text_length = StrUtil::utf16Length(old_text);
    const size_t delta_start = has_text_delta
        ? clampImeOffset(delta_start_offset, old_text_length)
        : 0;
    const size_t delta_end = has_text_delta
        ? clampImeOffset(delta_end_offset, old_text_length)
        : 0;
    const U8String next_text = has_text_delta
        ? replaceUtf16TextRange(old_text, delta_start, delta_end, delta_text)
        : old_text;

    if (mode == ImeTextUpdateScope::TRANSIENT_INPUT) {
      return handleImeTextSnapshotInternal(mode,
                                     context_id,
                                     context_revision,
                                     document_start_offset,
                                     next_text,
                                     selection_start_offset,
                                      selection_end_offset,
                                      marked_range,
                                      script_class);
    }

    const ImeContextRange reported_marked_range = normalizeImeComposingRange(
        marked_range.range.start,
        marked_range.range.end,
        StrUtil::utf16Length(next_text));
    const ImeContextRange new_composition =
        marked_range.role == ImeMarkedRangeRole::PREEDIT
        ? reported_marked_range
        : ImeContextRange {};
    const ImeContextRange new_system_mark =
        marked_range.role == ImeMarkedRangeRole::SYSTEM_MARK
        ? reported_marked_range
        : ImeContextRange {};
    const ImeContextRange previous_composition =
        isMatchingImeDocumentWindow(m_ime_input_context_, context_id, context_revision)
            && m_ime_input_context_.has_composition
        ? normalizeImeComposingRange(m_ime_input_context_.composition.start,
                                     m_ime_input_context_.composition.end,
                                     old_text_length)
        : ImeContextRange {};
    const ImeContextRange previous_system_mark =
        isMatchingImeDocumentWindow(m_ime_input_context_, context_id, context_revision)
            && m_ime_input_context_.has_system_mark_range
        ? normalizeImeComposingRange(m_ime_input_context_.system_mark_range.start,
                                     m_ime_input_context_.system_mark_range.end,
                                     old_text_length)
        : ImeContextRange {};

    if (!has_text_delta) {
      const bool clears_previous_composition =
          previous_composition.active && !new_composition.active;
      const bool clears_previous_system_mark =
          previous_system_mark.active && !new_system_mark.active;
      if (clears_previous_composition) {
        m_ime_text_update_has_pending_composition_clear_ = true;
        m_ime_text_update_pending_composition_clear_ = {
          static_cast<int32_t>(previous_composition.start),
          static_cast<int32_t>(previous_composition.end)
        };
        ImeActionResult result;
        result.handled = true;
        result.sync = getImeSyncSnapshot();
        return result;
      }
      if (clears_previous_system_mark) {
        ImeActionResult result;
        result.handled = true;
        rememberImeDocumentWindowContext(context_id,
                              context_revision,
                              m_ime_input_context_.document_start_offset,
                              old_text,
                              selection_start_offset,
                              selection_end_offset,
                              {},
                              m_ime_input_context_.kind);
        clearImeTextUpdateSystemMarkRange();
        result.sync = getImeSyncSnapshot();
        return result;
      }
      resetImeTextUpdatePendingState();
      return applyImeDocumentWindowSnapshotInternal(context_id,
                                     context_revision,
                                     document_start_offset,
                                     old_text,
                                     selection_start_offset,
                                      selection_end_offset,
                                      marked_range,
                                      script_class);
    }

    if (m_ime_text_update_has_pending_composition_clear_
        && static_cast<int32_t>(delta_start) == m_ime_text_update_pending_composition_clear_.start
        && static_cast<int32_t>(delta_end) == m_ime_text_update_pending_composition_clear_.end) {
      ImeActionResult result = isComposing()
          ? commitImeContextTextReplacementInternal(context_id,
                                                       context_revision,
                                                       document_start_offset,
                                                       delta_start,
                                                       delta_end,
                                                       delta_text,
                                                       1,
                                                       script_class)
          : replaceImeContextTextInternal(context_id,
                                             context_revision,
                                             document_start_offset,
                                             delta_start,
                                             delta_end,
                                             delta_text,
                                             1,
                                             script_class);
      resetImeTextUpdatePendingState();
      if (result.handled) {
        invalidateImeInputContext();
        return result;
      }
    } else {
      resetImeTextUpdatePendingState();
    }

    return applyImeDocumentWindowSnapshotInternal(context_id,
                                     context_revision,
                                     document_start_offset,
                                     next_text,
                                     selection_start_offset,
                                    selection_end_offset,
                                    marked_range,
                                    script_class);
  }

  ImeActionResult EditorCore::setImeContextSelectionInternal(uint64_t context_id,
                                                           int32_t context_revision,
                                                           int32_t document_start_offset,
                                                           int32_t selection_start_offset,
                                                           int32_t selection_end_offset) {
    auto to_offset = [](int32_t offset) {
      return offset < 0 ? static_cast<size_t>(0) : static_cast<size_t>(offset);
    };
    const TextRange range = textRangeFromImeContextOffsets(
        context_id,
        context_revision,
        document_start_offset,
        to_offset(selection_start_offset),
        to_offset(selection_end_offset));
    ImeActionResult result = notifyImeSelectionChangedInternal(range);
    if (context_id != 0 && context_id == m_ime_input_context_.id) {
      const bool has_composition = m_ime_input_context_.has_composition;
      const bool has_system_mark = m_ime_input_context_.has_system_mark_range;
      const ImeOffsetRange marked_range = has_composition
                                          ? m_ime_input_context_.composition
                                          : (has_system_mark
                                             ? m_ime_input_context_.system_mark_range
                                             : ImeOffsetRange {-1, -1});
      const ImeMarkedRangeRole marked_range_role =
          has_composition
          ? ImeMarkedRangeRole::PREEDIT
          : (has_system_mark
             ? ImeMarkedRangeRole::SYSTEM_MARK
             : ImeMarkedRangeRole::NONE);
      rememberImeDocumentWindowContext(context_id,
                            context_revision,
                            m_ime_input_context_.document_start_offset,
                            m_ime_input_context_.text,
                            selection_start_offset,
                            selection_end_offset,
                            {marked_range_role, marked_range},
                            m_ime_input_context_.kind);
    }
    return result;
  }

  ImeActionResult EditorCore::replaceImeContextTextInternal(uint64_t context_id,
                                                       int32_t context_revision,
                                                       int32_t document_start_offset,
                                                       size_t start_offset,
                                                       size_t end_offset,
                                                       const U8String& text,
                                                       int cursor_offset,
                                                       ImeScriptClass script_class) {
    ImeActionResult result = replaceImeDocumentRangeInternal(
        textRangeFromImeContextOffsets(context_id,
                                       context_revision,
                                       document_start_offset,
                                       start_offset,
                                       end_offset),
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::setImeContextSystemMarkRangeInternal(uint64_t context_id,
                                                                int32_t context_revision,
                                                                int32_t document_start_offset,
                                                                int32_t start_offset,
                                                                int32_t end_offset) {
    ImeActionResult result;
    if (m_document_ == nullptr) {
      return result;
    }
    const ImeContextRange range = normalizeImeComposingRange(
        start_offset,
        end_offset,
        StrUtil::utf16Length(m_ime_input_context_.text));
    if (!range.active) {
      return clearImeContextSystemMarkRangeInternal(context_id, context_revision, document_start_offset);
    }

    m_ime_input_context_.has_system_mark_range = true;
    m_ime_input_context_.system_mark_range = {
      static_cast<int32_t>(range.start),
      static_cast<int32_t>(range.end)
    };
    rememberImeTextUpdateSystemMarkRange(context_id,
                                            context_revision,
                                            document_start_offset,
                                            range.start,
                                            range.end);
    result.handled = true;
    result.sync = buildImeSyncSnapshot();
    result.sync.clear_system_mark = false;
    return result;
  }

  ImeActionResult EditorCore::clearImeContextSystemMarkRangeInternal(uint64_t context_id,
                                                                  int32_t context_revision,
                                                                  int32_t document_start_offset) {
    ImeActionResult result;
    if (m_document_ == nullptr) {
      return result;
    }
    if (!isMatchingImeDocumentWindow(m_ime_input_context_, context_id, context_revision)
        && document_start_offset < 0) {
      return makeImeInputContextResyncResult(getImeSyncSnapshot());
    }

    m_ime_input_context_.has_system_mark_range = false;
    m_ime_input_context_.system_mark_range = {-1, -1};
    clearImeTextUpdateSystemMarkRange();
    result.handled = true;
    result.sync = buildImeSyncSnapshot();
    result.sync.clear_system_mark = true;
    return result;
  }

  ImeActionResult EditorCore::commitImeContextTextReplacementInternal(uint64_t context_id,
                                                                 int32_t context_revision,
                                                                 int32_t document_start_offset,
                                                                 size_t start_offset,
                                                                 size_t end_offset,
                                                                 const U8String& text,
                                                                 int cursor_offset,
                                                                 ImeScriptClass script_class) {
    ImeActionResult result;
    if (m_document_ == nullptr || m_settings_.read_only) {
      return result;
    }

    const CompositionState& composition = getCompositionState();
    if (!composition.is_composing
        || !composition.visible
        || composition.kind != CompositionKind::DOCUMENT_RANGE) {
      return result;
    }

    const TextRange range = textRangeFromImeContextOffsets(
        context_id,
        context_revision,
        document_start_offset,
        start_offset,
        end_offset);
    if (!(composition.anchor_range == range)) {
      return result;
    }

    result = m_composition_controller_.commitDocumentRangeReplacement(
        range,
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::deleteImeBackwardInternal(size_t before_length, ImeTextUnit text_unit) {
    return m_composition_controller_.deleteBackward(before_length, text_unit);
  }

  ImeActionResult EditorCore::deleteImeForwardInternal(size_t after_length, ImeTextUnit text_unit) {
    return m_composition_controller_.deleteForward(after_length, text_unit);
  }

  ImeActionResult EditorCore::deleteImeSurroundingInternal(size_t before_length,
                                                  size_t after_length,
                                                  ImeTextUnit text_unit) {
    return m_composition_controller_.deleteSurrounding(before_length, after_length, text_unit);
  }

  ImeActionResult EditorCore::notifyImeSelectionChangedInternal(const TextRange& range) {
    return m_composition_controller_.notifySelectionChanged(range);
  }

  ImeActionResult EditorCore::notifyImeCursorChangedInternal(const TextPosition& cursor) {
    return m_composition_controller_.notifyCursorChanged(cursor);
  }

  ImeInputContext EditorCore::buildImeInputContext(size_t before_length,
                                                   size_t after_length,
                                                   ImeInputContextKind kind) {
    ImeInputContext context;
    context.kind = kind;
    const bool text_window = isImeTextWindowKind(kind);
    if (m_document_ == nullptr) {
      if (text_window) {
        m_ime_input_context_ = {};
      }
      return context;
    }

    const size_t document_length = documentUtf16Length();
    TextRange selection = hasSelection()
                          ? m_caret_.normalizedSelection()
                          : TextRange {m_caret_.cursor, m_caret_.cursor};
    size_t selection_start = m_document_->getCharIndexFromPosition(selection.start);
    size_t selection_end = m_document_->getCharIndexFromPosition(selection.end);
    if (selection_start > selection_end) {
      std::swap(selection_start, selection_end);
    }

    const size_t context_start = selection_start > before_length ? selection_start - before_length : 0;
    const size_t context_end = std::min(document_length, selection_end + after_length);
    TextRange context_range = textRangeFromUtf16Offsets(context_start, context_end);

    if (text_window) {
      context.id = m_next_ime_input_context_id_++;
      context.revision = ++m_ime_input_context_revision_;
    } else {
      context.revision = m_ime_input_context_revision_;
    }
    context.document_start_offset = static_cast<int32_t>(context_start);
    context.text = m_document_->getU8Text(context_range);
    context.selection = {
      static_cast<int32_t>(selection_start - context_start),
      static_cast<int32_t>(selection_end - context_start)
    };

    if (m_composition_controller_.hasVisibleComposition()) {
      TextRange composition_range = m_composition_controller_.currentComposingRange();
      size_t composing_start = m_document_->getCharIndexFromPosition(composition_range.start);
      size_t composing_end = m_document_->getCharIndexFromPosition(composition_range.end);
      if (composing_start > composing_end) {
        std::swap(composing_start, composing_end);
      }
      if (composing_start >= context_start && composing_end <= context_end && composing_start != composing_end) {
        context.has_composition = true;
        context.composition = {
          static_cast<int32_t>(composing_start - context_start),
          static_cast<int32_t>(composing_end - context_start)
        };
      }
    }

    if (m_ime_text_update_has_system_mark_range_) {
      size_t marked_start = m_document_->getCharIndexFromPosition(m_ime_text_update_system_mark_range_.start);
      size_t marked_end = m_document_->getCharIndexFromPosition(m_ime_text_update_system_mark_range_.end);
      if (marked_start > marked_end) {
        std::swap(marked_start, marked_end);
      }
      if (marked_start >= context_start && marked_end <= context_end && marked_start != marked_end) {
        context.has_system_mark_range = true;
        context.system_mark_range = {
          static_cast<int32_t>(marked_start - context_start),
          static_cast<int32_t>(marked_end - context_start)
        };
      }
    }

    if (text_window) {
      m_ime_input_context_ = context;
    }
    return context;
  }

  ImeInputContextKind EditorCore::resolveImeDocumentInputContextKind(size_t before_length,
                                                                     size_t after_length) const {
    if (before_length != 0 || after_length != 0) {
      return ImeInputContextKind::DOCUMENT_WINDOW;
    }
    return hasSelection()
           ? ImeInputContextKind::SELECTION_ONLY
           : ImeInputContextKind::NONE;
  }

  ImeSyncSnapshot EditorCore::buildImeSyncSnapshot() const {
    ImeSyncSnapshot snapshot = m_composition_controller_.buildSyncSnapshot();
    if (!snapshot.has_visible_composition_range && m_ime_text_update_has_system_mark_range_) {
      snapshot.has_system_mark_range = true;
      snapshot.system_mark_range = m_ime_text_update_system_mark_range_;
      snapshot.clear_system_mark = false;
    }
    return snapshot;
  }

  ImeInputContext EditorCore::getImeCommandInputContext(size_t before_length, size_t after_length) {
    const ImeContextPolicy policy = m_composition_controller_.inputContextPolicy();
    if (policy == ImeContextPolicy::NONE) {
      return buildImeInputContext(0, 0, resolveImeDocumentInputContextKind(0, 0));
    }

    const size_t context_before = std::min(before_length, LIMITED_IME_DOCUMENT_CONTEXT_LENGTH);
    const size_t context_after = std::min(after_length, LIMITED_IME_DOCUMENT_CONTEXT_LENGTH);
    return buildImeInputContext(
        context_before,
        context_after,
        resolveImeDocumentInputContextKind(context_before, context_after));
  }

  ImeInputContext EditorCore::getImeTextUpdateInputContext(ImeTextUpdateScope mode,
                                                          size_t before_length,
                                                          size_t after_length) {
    if (mode == ImeTextUpdateScope::TRANSIENT_INPUT) {
      if (isImeTextWindowContext(m_ime_input_context_)
          && (!m_ime_input_context_.text.empty()
              || m_ime_input_context_.has_composition
              || m_ime_input_context_.has_system_mark_range)) {
        ImeInputContext context = m_ime_input_context_;
        context.kind = ImeInputContextKind::TRANSIENT_INPUT;
        return context;
      }
      return buildImeInputContext(0, 0, ImeInputContextKind::TRANSIENT_INPUT);
    }

    const size_t context_before = std::min(before_length, LIMITED_IME_DOCUMENT_CONTEXT_LENGTH);
    const size_t context_after = std::min(after_length, LIMITED_IME_DOCUMENT_CONTEXT_LENGTH);
    return buildImeInputContext(
        context_before,
        context_after,
        ImeInputContextKind::DOCUMENT_WINDOW);
  }

  bool EditorCore::isDocumentRangeReadable(const TextRange& range) const {
    if (m_document_ == nullptr || range.end < range.start) {
      return false;
    }
    size_t line_count = m_document_->getLineCount();
    if (range.start.line >= line_count || range.end.line >= line_count) {
      return false;
    }
    return range.start.column <= m_document_->getLineColumns(range.start.line)
        && range.end.column <= m_document_->getLineColumns(range.end.line);
  }

  ImeSyncSnapshot EditorCore::getImeSyncSnapshot() const {
    return buildImeSyncSnapshot();
  }

  ImeScriptClass EditorCore::getImeKeyboardScriptClass() const {
    return m_composition_controller_.keyboardScriptClass();
  }

  const CompositionState& EditorCore::getCompositionState() const {
    return m_composition_controller_.composition();
  }

  bool EditorCore::isComposing() const {
    return m_composition_controller_.hasVisibleComposition();
  }

  bool EditorCore::hasComposingSession() const {
    return m_composition_controller_.hasComposingSession();
  }

  TextRange EditorCore::textRangeFromImeInputContextOffsets(size_t start_offset, size_t end_offset) const {
    if (!isImeDocumentWindowContext(m_ime_input_context_)) {
      return textRangeFromUtf16Offsets(start_offset, end_offset);
    }
    if (start_offset > end_offset) {
      std::swap(start_offset, end_offset);
    }
    const size_t context_length = StrUtil::utf16Length(m_ime_input_context_.text);
    start_offset = std::min(start_offset, context_length);
    end_offset = std::min(end_offset, context_length);
    const size_t base = static_cast<size_t>(std::max(0, m_ime_input_context_.document_start_offset));
    return textRangeFromUtf16Offsets(base + start_offset, base + end_offset);
  }

  TextRange EditorCore::textRangeFromImeContextOffsets(uint64_t context_id,
                                                          int32_t context_revision,
                                                          int32_t document_start_offset,
                                                          size_t start_offset,
                                                          size_t end_offset) const {
    if (isMatchingImeDocumentWindow(m_ime_input_context_, context_id, context_revision)) {
      return textRangeFromImeInputContextOffsets(start_offset, end_offset);
    }
    if (start_offset > end_offset) {
      std::swap(start_offset, end_offset);
    }
    const size_t base = static_cast<size_t>(std::max<int32_t>(0, document_start_offset));
    return textRangeFromUtf16Offsets(base + start_offset, base + end_offset);
  }

  TextRange EditorCore::textRangeFromImeCompositionOffsets(const ImeActionResult& result,
                                                          size_t start_offset,
                                                          size_t end_offset) const {
    TextRange composition_range;
    bool has_range = false;
    if (result.sync.has_system_mark_range) {
      composition_range = result.sync.system_mark_range;
      has_range = true;
    } else if (result.sync.has_visible_composition_range) {
      composition_range = result.sync.visible_composition_range;
      has_range = true;
    } else if (result.edit_result.contentChanged()) {
      const TextChange& change = result.edit_result.changes.front();
      composition_range = {
        change.range.start,
        calcPositionAfterInsert(change.range.start, change.new_text)
      };
      has_range = true;
    }

    if (!has_range || m_document_ == nullptr) {
      const size_t cursor_offset = m_document_ == nullptr
                                   ? 0
                                   : m_document_->getCharIndexFromPosition(result.sync.cursor);
      return textRangeFromUtf16Offsets(cursor_offset, cursor_offset);
    }

    size_t base = m_document_->getCharIndexFromPosition(composition_range.start);
    size_t end = m_document_->getCharIndexFromPosition(composition_range.end);
    if (base > end) {
      std::swap(base, end);
    }
    if (start_offset > end_offset) {
      std::swap(start_offset, end_offset);
    }
    const size_t length = end - base;
    start_offset = std::min(start_offset, length);
    end_offset = std::min(end_offset, length);
    return textRangeFromUtf16Offsets(base + start_offset, base + end_offset);
  }

  void EditorCore::applyImeCursorOffset(ImeActionResult& result, const U8String& text, int cursor_offset) {
    if (m_document_ == nullptr || cursor_offset == 1) {
      return;
    }

    size_t edit_start = m_document_->getCharIndexFromPosition(result.sync.cursor);
    size_t edit_end = edit_start;
    if (result.edit_result.contentChanged()) {
      const TextRange& changed_range = result.edit_result.changes.front().range;
      edit_start = m_document_->getCharIndexFromPosition(changed_range.start);
      edit_end = edit_start + StrUtil::utf16Length(text);
    } else if (result.sync.has_system_mark_range) {
      edit_start = m_document_->getCharIndexFromPosition(result.sync.system_mark_range.start);
      edit_end = m_document_->getCharIndexFromPosition(result.sync.system_mark_range.end);
    } else if (result.sync.has_visible_composition_range) {
      edit_start = m_document_->getCharIndexFromPosition(result.sync.visible_composition_range.start);
      edit_end = m_document_->getCharIndexFromPosition(result.sync.visible_composition_range.end);
    }
    if (edit_start > edit_end) {
      std::swap(edit_start, edit_end);
    }

    const int64_t raw_target = cursor_offset > 0
                               ? static_cast<int64_t>(edit_end) + cursor_offset - 1
                               : static_cast<int64_t>(edit_start) + cursor_offset;
    const size_t document_length = documentUtf16Length();
    const size_t target_offset = static_cast<size_t>(
        std::max<int64_t>(0, std::min<int64_t>(raw_target, static_cast<int64_t>(document_length))));
    ImeActionResult cursor_result = notifyImeCursorChangedInternal(
        m_document_->getPositionFromCharIndex(target_offset));
    mergeImeActionResult(result, cursor_result);
  }

  void EditorCore::rememberImeDocumentWindowContext(uint64_t context_id,
                                         int32_t context_revision,
                                         int32_t document_start_offset,
                                         const U8String& text,
                                         int32_t selection_start_offset,
                                         int32_t selection_end_offset,
                                         ImeMarkedRange marked_range,
                                         ImeInputContextKind kind) {
    const size_t text_length = StrUtil::utf16Length(text);
    const ImeContextRange selection = normalizeImeSelectionRange(
        selection_start_offset,
        selection_end_offset,
        text_length);
    const ImeContextRange normalized_marked_range = normalizeImeComposingRange(
        marked_range.range.start,
        marked_range.range.end,
        text_length);
    const bool has_composition =
        normalized_marked_range.active && marked_range.role == ImeMarkedRangeRole::PREEDIT;
    const bool has_system_mark_range =
        normalized_marked_range.active && marked_range.role == ImeMarkedRangeRole::SYSTEM_MARK;

    m_ime_input_context_.id = context_id != 0 ? context_id : m_next_ime_input_context_id_++;
    m_ime_input_context_.revision = context_revision != 0
                                    ? context_revision
                                    : ++m_ime_input_context_revision_;
    m_ime_input_context_.document_start_offset = std::max<int32_t>(0, document_start_offset);
    m_ime_input_context_.text = text;
    m_ime_input_context_.kind = kind;
    m_ime_input_context_.selection = {
      static_cast<int32_t>(selection.start),
      static_cast<int32_t>(selection.end)
    };
    m_ime_input_context_.has_composition = has_composition;
    m_ime_input_context_.composition = has_composition
                                           ? ImeOffsetRange {
                                           static_cast<int32_t>(normalized_marked_range.start),
                                           static_cast<int32_t>(normalized_marked_range.end)
                                          }
                                       : ImeOffsetRange {-1, -1};
    m_ime_input_context_.has_system_mark_range = has_system_mark_range;
    m_ime_input_context_.system_mark_range = has_system_mark_range
                                                 ? ImeOffsetRange {
                                                     static_cast<int32_t>(normalized_marked_range.start),
                                                     static_cast<int32_t>(normalized_marked_range.end)
                                                   }
                                                 : ImeOffsetRange {-1, -1};
  }

  void EditorCore::rememberImeTextUpdateSystemMarkRange(uint64_t context_id,
                                                           int32_t context_revision,
                                                           int32_t document_start_offset,
                                                           size_t start_offset,
                                                           size_t end_offset) {
    if (start_offset == end_offset) {
      clearImeTextUpdateSystemMarkRange();
      return;
    }
    m_ime_text_update_system_mark_range_ = textRangeFromImeContextOffsets(
        context_id,
        context_revision,
        document_start_offset,
        std::min(start_offset, end_offset),
        std::max(start_offset, end_offset));
    m_ime_text_update_has_system_mark_range_ =
        m_ime_text_update_system_mark_range_.start != m_ime_text_update_system_mark_range_.end;
  }

  void EditorCore::clearImeTextUpdateSystemMarkRange() {
    m_ime_text_update_has_system_mark_range_ = false;
    m_ime_text_update_system_mark_range_ = {};
  }

  void EditorCore::resetImeTextUpdatePendingState() {
    m_ime_text_update_has_pending_composition_clear_ = false;
    m_ime_text_update_pending_composition_clear_ = {-1, -1};
  }

  void EditorCore::invalidateImeInputContext() {
    m_ime_input_context_ = {};
    m_ime_input_context_.revision = ++m_ime_input_context_revision_;
    resetImeTextUpdatePendingState();
    clearImeTextUpdateSystemMarkRange();
  }

#pragma endregion

}
