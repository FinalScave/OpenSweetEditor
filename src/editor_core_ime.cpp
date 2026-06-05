//
// Created by Scave on 2025/12/1.
//
#include <algorithm>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {

  constexpr size_t LIMITED_IME_DOCUMENT_CONTEXT_LENGTH = 2048;

  struct ImeInputStateRange {
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

  static size_t clampImeOffset(int32_t offset, size_t length) {
    if (offset < 0) {
      return 0;
    }
    return std::min(static_cast<size_t>(offset), length);
  }

  static size_t clampSignedImeOffset(int64_t offset, size_t length) {
    return static_cast<size_t>(std::max<int64_t>(0, std::min<int64_t>(offset, static_cast<int64_t>(length))));
  }

  static ImeInputStateRange normalizeImeSelectionRange(int32_t start, int32_t end, size_t text_length) {
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

  static ImeInputStateRange normalizeImeComposingRange(int32_t start, int32_t end, size_t text_length) {
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

  static ImeInputStateRange transformImeRangeToPreviousText(const ImeInputStateRange& range,
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
                                          const ImeInputStateRange& range) {
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
                                                   const ImeInputStateRange& range) {
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
                                                   const ImeInputStateRange& range) {
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
    target.handled = target.handled || source.handled;
    target.content_changed = target.content_changed || source.content_changed;
    target.cursor_changed = target.cursor_changed || source.cursor_changed;
    target.selection_changed = target.selection_changed || source.selection_changed;
    if (source.edit_result.changed) {
      if (!target.edit_result.changed) {
        target.edit_result = source.edit_result;
      } else {
        target.edit_result.changes.insert(target.edit_result.changes.end(),
                                          source.edit_result.changes.begin(),
                                          source.edit_result.changes.end());
        target.edit_result.cursor_after = source.edit_result.cursor_after;
      }
    }
    target.sync = source.sync;
  }

#pragma region [IME]

  EditorActionResult EditorCore::updateImePreedit(const U8String& text, ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, updateImePreeditInternal(text, script_class));
  }

  EditorActionResult EditorCore::setImeComposingText(const U8String& text,
                                                     int cursor_offset,
                                                     ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, setImeComposingTextInternal(text, cursor_offset, script_class));
  }

  EditorActionResult EditorCore::setImeComposingText(const U8String& text,
                                                     size_t selection_start_offset,
                                                     size_t selection_end_offset,
                                                     ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, setImeComposingTextInternal(text, selection_start_offset, selection_end_offset, script_class));
  }

  EditorActionResult EditorCore::commitImeText(const U8String& text, ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, commitImeTextInternal(text, script_class));
  }

  EditorActionResult EditorCore::commitImeText(const U8String& text,
                                               int cursor_offset,
                                               ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, commitImeTextInternal(text, cursor_offset, script_class));
  }

  EditorActionResult EditorCore::finishImePreedit() {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, finishImePreeditInternal());
  }

  EditorActionResult EditorCore::cancelImePreedit() {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, cancelImePreeditInternal());
  }

  EditorActionResult EditorCore::markImeDocumentRange(const TextRange& range, ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, markImeDocumentRangeInternal(range, script_class));
  }

  EditorActionResult EditorCore::markImeDocumentRange(size_t start_offset,
                                                      size_t end_offset,
                                                      ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, markImeDocumentRangeInternal(start_offset, end_offset, script_class));
  }

  EditorActionResult EditorCore::replaceImeText(const ImeTextReplacement& replacement) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, replaceImeTextInternal(
        replacement.range,
        replacement.text,
        replacement.script_class));
  }

  EditorActionResult EditorCore::replaceImeDocumentText(const ImeDocumentTextReplacement& replacement) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, replaceImeDocumentTextInternal(
        replacement.start_offset,
        replacement.end_offset,
        replacement.text,
        replacement.cursor_offset,
        replacement.script_class));
  }

  EditorActionResult EditorCore::replaceImeInputContextText(const ImeInputContextTextReplacement& replacement) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, replaceImeInputContextTextInternal(
        replacement.start_offset,
        replacement.end_offset,
        replacement.text,
        replacement.cursor_offset,
        replacement.script_class));
  }

  EditorActionResult EditorCore::markImeInputContextRange(size_t start_offset,
                                                          size_t end_offset,
                                                          ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, markImeInputContextRangeInternal(start_offset, end_offset, script_class));
  }

  EditorActionResult EditorCore::notifyImeDocumentSelectionChanged(size_t start_offset, size_t end_offset) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, notifyImeDocumentSelectionChangedInternal(start_offset, end_offset));
  }

  EditorActionResult EditorCore::notifyImeInputContextSelectionChanged(size_t start_offset, size_t end_offset) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, notifyImeInputContextSelectionChangedInternal(start_offset, end_offset));
  }

  EditorActionResult EditorCore::updateImeTextModelState(const ImeTextModelState& state) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, updateImeTextModelStateInternal(
        state.mode,
        state.context_id,
        state.document_start_offset,
        state.text,
        state.selection.start,
        state.selection.end,
        state.composition.start,
        state.composition.end,
        state.script_class));
  }

  EditorActionResult EditorCore::updateImeTextModelDelta(const ImeTextModelDelta& delta) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, updateImeTextModelDeltaInternal(
        delta.mode,
        delta.context_id,
        delta.document_start_offset,
        delta.old_text,
        delta.delta.start,
        delta.delta.end,
        delta.delta_text,
        delta.selection.start,
        delta.selection.end,
        delta.composition.start,
        delta.composition.end,
        delta.script_class));
  }

  EditorActionResult EditorCore::updateImeInputStateSelection(uint64_t context_id,
                                                              int32_t document_start_offset,
                                                              int32_t selection_start_offset,
                                                              int32_t selection_end_offset) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, updateImeInputStateSelectionInternal(context_id,
                                                                        document_start_offset,
                                                                        selection_start_offset,
                                                                        selection_end_offset));
  }

  EditorActionResult EditorCore::replaceImeInputStateText(const ImeInputStateTextReplacement& replacement) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, replaceImeInputStateTextInternal(
        replacement.context_id,
        replacement.document_start_offset,
        replacement.start_offset,
        replacement.end_offset,
        replacement.text,
        replacement.cursor_offset,
        replacement.script_class));
  }

  EditorActionResult EditorCore::deleteImeBackward(size_t before_length, ImeTextUnit text_unit) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, deleteImeBackwardInternal(before_length, text_unit));
  }

  EditorActionResult EditorCore::deleteImeForward(size_t after_length, ImeTextUnit text_unit) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, deleteImeForwardInternal(after_length, text_unit));
  }

  EditorActionResult EditorCore::deleteImeSurrounding(size_t before_length,
                                                      size_t after_length,
                                                      ImeTextUnit text_unit) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, deleteImeSurroundingInternal(before_length, after_length, text_unit));
  }

  EditorActionResult EditorCore::notifyImeSelectionChanged(const TextRange& range) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, notifyImeSelectionChangedInternal(range));
  }

  EditorActionResult EditorCore::notifyImeCursorChanged(const TextPosition& cursor) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    return finishImeAction(before, notifyImeCursorChangedInternal(cursor));
  }

  ImeActionResult EditorCore::updateImePreeditInternal(const U8String& text, ImeScriptClass script_class) {
    return m_composition_controller_.updatePreedit(text, script_class);
  }

  ImeActionResult EditorCore::setImeComposingTextInternal(const U8String& text,
                                                  int cursor_offset,
                                                  ImeScriptClass script_class) {
    ImeActionResult result = updateImePreeditInternal(text, script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::setImeComposingTextInternal(const U8String& text,
                                                  size_t selection_start_offset,
                                                  size_t selection_end_offset,
                                                  ImeScriptClass script_class) {
    ImeActionResult result = updateImePreeditInternal(text, script_class);
    TextRange selection_range = textRangeFromImeCompositionOffsets(
        result,
        selection_start_offset,
        selection_end_offset);
    ImeActionResult selection_result = notifyImeSelectionChangedInternal(selection_range);
    mergeImeActionResult(result, selection_result);
    return result;
  }

  ImeActionResult EditorCore::commitImeTextInternal(const U8String& text, ImeScriptClass script_class) {
    return m_composition_controller_.commitText(text, script_class);
  }

  ImeActionResult EditorCore::commitImeTextInternal(const U8String& text,
                                            int cursor_offset,
                                            ImeScriptClass script_class) {
    ImeActionResult result = commitImeTextInternal(text, script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::finishImePreeditInternal() {
    return m_composition_controller_.finishPreedit();
  }

  ImeActionResult EditorCore::cancelImePreeditInternal() {
    return m_composition_controller_.cancelPreedit();
  }

  ImeActionResult EditorCore::markImeDocumentRangeInternal(const TextRange& range,
                                                   ImeScriptClass script_class) {
    return m_composition_controller_.markDocumentRange(range, script_class);
  }

  ImeActionResult EditorCore::markImeDocumentRangeInternal(size_t start_offset,
                                                   size_t end_offset,
                                                   ImeScriptClass script_class) {
    TextRange range = textRangeFromUtf16Offsets(start_offset, end_offset);
    if (range.start == range.end) {
      return finishImePreeditInternal();
    }
    return markImeDocumentRangeInternal(range, script_class);
  }

  ImeActionResult EditorCore::replaceImeTextInternal(const TextRange& range,
                                             const U8String& text,
                                             ImeScriptClass script_class) {
    return m_composition_controller_.replaceText(range, text, script_class);
  }

  ImeActionResult EditorCore::replaceImeDocumentTextInternal(size_t start_offset,
                                                     size_t end_offset,
                                                     const U8String& text,
                                                     int cursor_offset,
                                                     ImeScriptClass script_class) {
    ImeActionResult result = replaceImeTextInternal(
        textRangeFromUtf16Offsets(start_offset, end_offset),
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::replaceImeInputContextTextInternal(size_t start_offset,
                                                         size_t end_offset,
                                                         const U8String& text,
                                                         int cursor_offset,
                                                         ImeScriptClass script_class) {
    ImeActionResult result = replaceImeTextInternal(
        textRangeFromImeInputContextOffsets(start_offset, end_offset),
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::markImeInputContextRangeInternal(size_t start_offset,
                                                       size_t end_offset,
                                                       ImeScriptClass script_class) {
    TextRange range = textRangeFromImeInputContextOffsets(start_offset, end_offset);
    if (range.start == range.end) {
      return finishImePreeditInternal();
    }
    return markImeDocumentRangeInternal(range, script_class);
  }

  ImeActionResult EditorCore::notifyImeDocumentSelectionChangedInternal(size_t start_offset, size_t end_offset) {
    return notifyImeSelectionChangedInternal(textRangeFromUtf16Offsets(start_offset, end_offset));
  }

  ImeActionResult EditorCore::notifyImeInputContextSelectionChangedInternal(size_t start_offset, size_t end_offset) {
    return notifyImeSelectionChangedInternal(textRangeFromImeInputContextOffsets(start_offset, end_offset));
  }

  ImeActionResult EditorCore::updateImeInputStateTextInternal(uint64_t context_id,
                                                      int32_t document_start_offset,
                                                      const U8String& text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      int32_t composing_start_offset,
                                                      int32_t composing_end_offset,
                                                      ImeScriptClass script_class) {
    ImeActionResult result;
    if (m_document_ == nullptr || m_settings_.read_only) {
      return result;
    }

    ImeInputContext previous_context;
    const bool has_previous_context = context_id != 0 && context_id == m_ime_input_context_.id;
    if (has_previous_context) {
      previous_context = m_ime_input_context_;
    } else {
      previous_context.id = context_id;
      previous_context.document_start_offset = document_start_offset;
      previous_context.kind = ImeInputContextKind::DOCUMENT_WINDOW;
      const size_t text_length = calcUtf16Columns(text);
      const size_t base = static_cast<size_t>(std::max<int32_t>(0, document_start_offset));
      previous_context.text = m_document_->getU8Text(textRangeFromUtf16Offsets(base, base + text_length));
    }

    const size_t old_text_length = calcUtf16Columns(previous_context.text);
    const size_t new_text_length = calcUtf16Columns(text);
    const ImeInputTextDiff diff = computeImeInputTextDiff(previous_context.text, text);
    const ImeInputStateRange selection = normalizeImeSelectionRange(
        selection_start_offset,
        selection_end_offset,
        new_text_length);
    const ImeInputStateRange new_composition = normalizeImeComposingRange(
        composing_start_offset,
        composing_end_offset,
        new_text_length);
    const ImeInputStateRange old_composition = previous_context.has_composition
                                               ? normalizeImeComposingRange(
                                                   previous_context.composition.start,
                                                   previous_context.composition.end,
                                                   old_text_length)
                                               : ImeInputStateRange {};
    const size_t document_start = static_cast<size_t>(
        std::max<int32_t>(0, previous_context.document_start_offset));

    if (diff.changed) {
      const bool replaces_previous_composition =
          old_composition.active
          && imeDiffTouchesPreviousRange(diff, old_composition)
          && imeTextPreservesPreviousRangeContext(previous_context.text, text, old_composition);
      if (replaces_previous_composition) {
        mergeImeActionResult(result, markImeDocumentRangeInternal(
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
          mergeImeActionResult(result, setImeComposingTextInternal(
              preedit_text,
              relative_offset(selection.start),
              relative_offset(selection.end),
              script_class));
        } else {
          const U8String replacement = sliceReplacementForPreviousRange(
              previous_context.text,
              text,
              old_composition);
          mergeImeActionResult(result, commitImeTextInternal(replacement, script_class));
        }
      } else if (new_composition.active) {
        ImeInputStateRange previous_composition = transformImeRangeToPreviousText(
            new_composition,
            diff,
            old_text_length);
        if (!previous_composition.active && old_composition.active) {
          previous_composition = old_composition;
        }
        if (previous_composition.active) {
          mergeImeActionResult(result, markImeDocumentRangeInternal(
              document_start + previous_composition.start,
              document_start + previous_composition.end,
              script_class));
        } else {
          const size_t insertion_offset = document_start + std::min(diff.start, old_text_length);
          mergeImeActionResult(result, notifyImeDocumentSelectionChangedInternal(insertion_offset, insertion_offset));
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
        mergeImeActionResult(result, setImeComposingTextInternal(
            preedit_text,
            relative_offset(selection.start),
            relative_offset(selection.end),
            script_class));
      } else if (old_composition.active || isComposing()) {
        mergeImeActionResult(result, commitImeTextInternal(diff.replacement, script_class));
      } else {
        mergeImeActionResult(result, replaceImeDocumentTextInternal(
            document_start + diff.start,
            document_start + diff.old_end,
            diff.replacement,
            1,
            script_class));
      }
    } else if (new_composition.active) {
      const bool had_visible_composition = isComposing();
      const bool had_document_range_composition =
          had_visible_composition && getCompositionState().kind == CompositionKind::DOCUMENT_RANGE;
      if (!had_visible_composition || had_document_range_composition) {
        mergeImeActionResult(result, markImeDocumentRangeInternal(
            document_start + new_composition.start,
            document_start + new_composition.end,
            script_class));
        mergeImeActionResult(result, notifyImeDocumentSelectionChangedInternal(
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
        mergeImeActionResult(result, setImeComposingTextInternal(
            preedit_text,
            relative_offset(selection.start),
            relative_offset(selection.end),
            script_class));
      }
    } else if (old_composition.active || isComposing()) {
      mergeImeActionResult(result, finishImePreeditInternal());
    }

    if (!new_composition.active) {
      mergeImeActionResult(result, notifyImeDocumentSelectionChangedInternal(
          document_start + selection.start,
          document_start + selection.end));
    }

    rememberImeInputState(context_id,
                          previous_context.document_start_offset,
                          text,
                          selection_start_offset,
                          selection_end_offset,
                          composing_start_offset,
                          composing_end_offset,
                          previous_context.kind);
    return result;
  }

  ImeActionResult EditorCore::updateImeTextModelStateInternal(ImeTextModelMode mode,
                                                      uint64_t context_id,
                                                      int32_t document_start_offset,
                                                      const U8String& text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      int32_t composing_start_offset,
                                                      int32_t composing_end_offset,
                                                      ImeScriptClass script_class) {
    if (mode == ImeTextModelMode::DOCUMENT_WINDOW) {
      resetImeTextModelPendingState();
      return updateImeInputStateTextInternal(context_id,
                                     document_start_offset,
                                     text,
                                     selection_start_offset,
                                     selection_end_offset,
                                     composing_start_offset,
                                     composing_end_offset,
                                     script_class);
    }

    ImeActionResult result;
    if (m_document_ == nullptr || m_settings_.read_only) {
      return result;
    }

    resetImeTextModelPendingState();
    const bool stale_context = context_id != 0
        && m_ime_input_context_.id != 0
        && context_id != m_ime_input_context_.id;
    if (stale_context) {
      result.handled = true;
      result.sync = getImeSyncSnapshot();
      result.sync.clear_platform_preedit = true;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    const size_t text_length = calcUtf16Columns(text);
    const ImeInputStateRange composition = normalizeImeComposingRange(
        composing_start_offset,
        composing_end_offset,
        text_length);
    if (composition.active) {
      rememberImeInputState(context_id,
                            document_start_offset,
                            text,
                            selection_start_offset,
                            selection_end_offset,
                            composing_start_offset,
                            composing_end_offset,
                            ImeInputContextKind::TRANSIENT_INPUT);
      result.handled = true;
      result.sync = getImeSyncSnapshot();
      result.sync.clear_platform_preedit = false;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    const bool had_text_model_state = m_ime_input_context_.id != 0
        && (!m_ime_input_context_.text.empty() || m_ime_input_context_.has_composition);
    if (!text.empty()) {
      result = commitImeTextInternal(text, script_class);
      invalidateImeInputContext();
      result.sync.clear_platform_preedit = true;
      result.sync.context_policy = ImeContextPolicy::NONE;
      return result;
    }

    result.handled = true;
    result.sync = getImeSyncSnapshot();
    result.sync.clear_platform_preedit = had_text_model_state;
    result.sync.context_policy = ImeContextPolicy::NONE;
    if (had_text_model_state) {
      invalidateImeInputContext();
    }
    return result;
  }

  ImeActionResult EditorCore::updateImeTextModelDeltaInternal(ImeTextModelMode mode,
                                                      uint64_t context_id,
                                                      int32_t document_start_offset,
                                                      const U8String& old_text,
                                                      int32_t delta_start_offset,
                                                      int32_t delta_end_offset,
                                                      const U8String& delta_text,
                                                      int32_t selection_start_offset,
                                                      int32_t selection_end_offset,
                                                      int32_t composing_start_offset,
                                                      int32_t composing_end_offset,
                                                      ImeScriptClass script_class) {
    const bool has_text_delta = delta_start_offset >= 0 && delta_end_offset >= 0;
    const size_t old_text_length = calcUtf16Columns(old_text);
    const size_t delta_start = has_text_delta
        ? clampImeOffset(delta_start_offset, old_text_length)
        : 0;
    const size_t delta_end = has_text_delta
        ? clampImeOffset(delta_end_offset, old_text_length)
        : 0;
    const U8String next_text = has_text_delta
        ? replaceUtf16TextRange(old_text, delta_start, delta_end, delta_text)
        : old_text;

    if (mode == ImeTextModelMode::TRANSIENT_INPUT) {
      return updateImeTextModelStateInternal(mode,
                                     context_id,
                                     document_start_offset,
                                     next_text,
                                     selection_start_offset,
                                     selection_end_offset,
                                     composing_start_offset,
                                     composing_end_offset,
                                     script_class);
    }

    const ImeInputStateRange new_composition = normalizeImeComposingRange(
        composing_start_offset,
        composing_end_offset,
        calcUtf16Columns(next_text));
    const ImeInputStateRange previous_composition =
        context_id != 0 && context_id == m_ime_input_context_.id && m_ime_input_context_.has_composition
        ? normalizeImeComposingRange(m_ime_input_context_.composition.start,
                                     m_ime_input_context_.composition.end,
                                     old_text_length)
        : ImeInputStateRange {};

    if (!has_text_delta) {
      if (previous_composition.active && !new_composition.active) {
        m_ime_text_model_has_pending_composition_clear_ = true;
        m_ime_text_model_pending_composition_clear_ = {
          static_cast<int32_t>(previous_composition.start),
          static_cast<int32_t>(previous_composition.end)
        };
        ImeActionResult result;
        result.handled = true;
        result.sync = getImeSyncSnapshot();
        return result;
      }
      resetImeTextModelPendingState();
      return updateImeInputStateTextInternal(context_id,
                                     document_start_offset,
                                     old_text,
                                     selection_start_offset,
                                     selection_end_offset,
                                     composing_start_offset,
                                     composing_end_offset,
                                     script_class);
    }

    if (m_ime_text_model_has_pending_composition_clear_
        && static_cast<int32_t>(delta_start) == m_ime_text_model_pending_composition_clear_.start
        && static_cast<int32_t>(delta_end) == m_ime_text_model_pending_composition_clear_.end) {
      ImeActionResult result = commitImeInputStateTextReplacementInternal(context_id,
                                                                  document_start_offset,
                                                                  delta_start,
                                                                  delta_end,
                                                                  delta_text,
                                                                  1,
                                                                  script_class);
      resetImeTextModelPendingState();
      if (result.handled) {
        invalidateImeInputContext();
        return result;
      }
    } else {
      resetImeTextModelPendingState();
    }

    return updateImeInputStateTextInternal(context_id,
                                   document_start_offset,
                                   next_text,
                                   selection_start_offset,
                                   selection_end_offset,
                                   composing_start_offset,
                                   composing_end_offset,
                                   script_class);
  }

  ImeActionResult EditorCore::updateImeInputStateSelectionInternal(uint64_t context_id,
                                                           int32_t document_start_offset,
                                                           int32_t selection_start_offset,
                                                           int32_t selection_end_offset) {
    auto to_offset = [](int32_t offset) {
      return offset < 0 ? static_cast<size_t>(0) : static_cast<size_t>(offset);
    };
    const TextRange range = textRangeFromImeInputStateOffsets(
        context_id,
        document_start_offset,
        to_offset(selection_start_offset),
        to_offset(selection_end_offset));
    ImeActionResult result = notifyImeSelectionChangedInternal(range);
    if (context_id != 0 && context_id == m_ime_input_context_.id) {
      rememberImeInputState(context_id,
                            m_ime_input_context_.document_start_offset,
                            m_ime_input_context_.text,
                            selection_start_offset,
                            selection_end_offset,
                            m_ime_input_context_.has_composition ? m_ime_input_context_.composition.start : -1,
                            m_ime_input_context_.has_composition ? m_ime_input_context_.composition.end : -1,
                            m_ime_input_context_.kind);
    }
    return result;
  }

  ImeActionResult EditorCore::replaceImeInputStateTextInternal(uint64_t context_id,
                                                       int32_t document_start_offset,
                                                       size_t start_offset,
                                                       size_t end_offset,
                                                       const U8String& text,
                                                       int cursor_offset,
                                                       ImeScriptClass script_class) {
    ImeActionResult result = replaceImeTextInternal(
        textRangeFromImeInputStateOffsets(context_id, document_start_offset, start_offset, end_offset),
        text,
        script_class);
    applyImeCursorOffset(result, text, cursor_offset);
    return result;
  }

  ImeActionResult EditorCore::commitImeInputStateTextReplacementInternal(uint64_t context_id,
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

    const TextRange range = textRangeFromImeInputStateOffsets(
        context_id,
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
    if (m_document_ == nullptr) {
      m_ime_input_context_ = context;
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

    context.id = m_next_ime_input_context_id_++;
    context.revision = ++m_ime_input_context_revision_;
    context.document_start_offset = static_cast<int32_t>(context_start);
    context.text = m_document_->getU8Text(context_range);
    context.selection = {
      static_cast<int32_t>(selection_start - context_start),
      static_cast<int32_t>(selection_end - context_start)
    };

    TextRange platform_marked_range;
    if (m_composition_controller_.currentPlatformMarkedRange(platform_marked_range)) {
      size_t composing_start = m_document_->getCharIndexFromPosition(platform_marked_range.start);
      size_t composing_end = m_document_->getCharIndexFromPosition(platform_marked_range.end);
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

    m_ime_input_context_ = context;
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

  ImeInputContext EditorCore::getImeInputContext(size_t before_length, size_t after_length) {
    auto lock = lockEditorState();
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

  ImeInputContext EditorCore::getImeTextModelInputContext(ImeTextModelMode mode,
                                                          size_t before_length,
                                                          size_t after_length) {
    auto lock = lockEditorState();
    if (mode == ImeTextModelMode::TRANSIENT_INPUT) {
      if (m_ime_input_context_.id != 0
          && (!m_ime_input_context_.text.empty() || m_ime_input_context_.has_composition)) {
        ImeInputContext context = m_ime_input_context_;
        context.kind = ImeInputContextKind::TRANSIENT_INPUT;
        return context;
      }
      return buildImeInputContext(0, 0, ImeInputContextKind::TRANSIENT_INPUT);
    }

    return getImeInputContext(before_length, after_length);
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
    auto lock = lockEditorState();
    return m_composition_controller_.buildSyncSnapshot();
  }

  EditorActionResult EditorCore::setImeKeyboardScriptClass(ImeScriptClass script_class) {
    auto lock = lockEditorState();
    const ActionSnapshot before = captureActionSnapshot();
    m_composition_controller_.setKeyboardScriptClass(script_class);
    return finishAction(before, EditorActionReason::IME, true);
  }

  ImeScriptClass EditorCore::getImeKeyboardScriptClass() const {
    auto lock = lockEditorState();
    return m_composition_controller_.keyboardScriptClass();
  }

  const CompositionState& EditorCore::getCompositionState() const {
    return m_composition_controller_.composition();
  }

  bool EditorCore::isComposing() const {
    auto lock = lockEditorState();
    return m_composition_controller_.hasVisibleComposition();
  }

  bool EditorCore::hasComposingSession() const {
    auto lock = lockEditorState();
    return m_composition_controller_.hasComposingSession();
  }

  TextRange EditorCore::textRangeFromImeInputContextOffsets(size_t start_offset, size_t end_offset) const {
    if (m_ime_input_context_.id == 0) {
      return textRangeFromUtf16Offsets(start_offset, end_offset);
    }
    if (start_offset > end_offset) {
      std::swap(start_offset, end_offset);
    }
    const size_t context_length = calcUtf16Columns(m_ime_input_context_.text);
    start_offset = std::min(start_offset, context_length);
    end_offset = std::min(end_offset, context_length);
    const size_t base = static_cast<size_t>(std::max(0, m_ime_input_context_.document_start_offset));
    return textRangeFromUtf16Offsets(base + start_offset, base + end_offset);
  }

  TextRange EditorCore::textRangeFromImeInputStateOffsets(uint64_t context_id,
                                                          int32_t document_start_offset,
                                                          size_t start_offset,
                                                          size_t end_offset) const {
    if (context_id != 0 && context_id == m_ime_input_context_.id) {
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
    if (result.sync.has_platform_marked_range) {
      composition_range = result.sync.platform_marked_range;
      has_range = true;
    } else if (result.sync.has_visible_composition_range) {
      composition_range = result.sync.visible_composition_range;
      has_range = true;
    } else if (result.edit_result.changed && !result.edit_result.changes.empty()) {
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
    if (result.edit_result.changed && !result.edit_result.changes.empty()) {
      const TextRange& changed_range = result.edit_result.changes.front().range;
      edit_start = m_document_->getCharIndexFromPosition(changed_range.start);
      edit_end = edit_start + calcUtf16Columns(text);
    } else if (result.sync.has_platform_marked_range) {
      edit_start = m_document_->getCharIndexFromPosition(result.sync.platform_marked_range.start);
      edit_end = m_document_->getCharIndexFromPosition(result.sync.platform_marked_range.end);
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

  void EditorCore::rememberImeInputState(uint64_t context_id,
                                         int32_t document_start_offset,
                                         const U8String& text,
                                         int32_t selection_start_offset,
                                         int32_t selection_end_offset,
                                         int32_t composing_start_offset,
                                         int32_t composing_end_offset,
                                         ImeInputContextKind kind) {
    const size_t text_length = calcUtf16Columns(text);
    const ImeInputStateRange selection = normalizeImeSelectionRange(
        selection_start_offset,
        selection_end_offset,
        text_length);
    const ImeInputStateRange composition = normalizeImeComposingRange(
        composing_start_offset,
        composing_end_offset,
        text_length);

    m_ime_input_context_.id = context_id != 0 ? context_id : m_next_ime_input_context_id_++;
    m_ime_input_context_.revision = ++m_ime_input_context_revision_;
    m_ime_input_context_.document_start_offset = std::max<int32_t>(0, document_start_offset);
    m_ime_input_context_.text = text;
    m_ime_input_context_.kind = kind;
    m_ime_input_context_.selection = {
      static_cast<int32_t>(selection.start),
      static_cast<int32_t>(selection.end)
    };
    m_ime_input_context_.has_composition = composition.active;
    m_ime_input_context_.composition = composition.active
                                       ? ImeTextRange {
                                           static_cast<int32_t>(composition.start),
                                           static_cast<int32_t>(composition.end)
                                         }
                                       : ImeTextRange {-1, -1};
  }

  void EditorCore::resetImeTextModelPendingState() {
    m_ime_text_model_has_pending_composition_clear_ = false;
    m_ime_text_model_pending_composition_clear_ = {-1, -1};
  }

  void EditorCore::invalidateImeInputContext() {
    m_ime_input_context_ = {};
    m_ime_input_context_.id = m_next_ime_input_context_id_++;
    m_ime_input_context_.revision = ++m_ime_input_context_revision_;
    resetImeTextModelPendingState();
  }

#pragma endregion

}
