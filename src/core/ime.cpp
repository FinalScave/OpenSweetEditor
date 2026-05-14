//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <simdutf/simdutf.h>
#include <algorithm>
#include <limits>
#include <ime.h>
#include <utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

  static bool isCjkCodePoint(uint32_t cp) {
    return (cp >= 0x3400 && cp <= 0x4DBF)
        || (cp >= 0x4E00 && cp <= 0x9FFF)
        || (cp >= 0xF900 && cp <= 0xFAFF)
        || (cp >= 0x20000 && cp <= 0x2A6DF)
        || (cp >= 0x2A700 && cp <= 0x2B73F)
        || (cp >= 0x2B740 && cp <= 0x2B81F)
        || (cp >= 0x2B820 && cp <= 0x2CEAF);
  }

  static bool isKanaCodePoint(uint32_t cp) {
    return (cp >= 0x3040 && cp <= 0x30FF)
        || (cp >= 0x31F0 && cp <= 0x31FF)
        || (cp >= 0xFF66 && cp <= 0xFF9D);
  }

  static bool isHangulCodePoint(uint32_t cp) {
    return (cp >= 0x1100 && cp <= 0x11FF)
        || (cp >= 0x3130 && cp <= 0x318F)
        || (cp >= 0xAC00 && cp <= 0xD7AF);
  }

  static bool isLatinCodePoint(uint32_t cp) {
    return (cp >= 'A' && cp <= 'Z')
        || (cp >= 'a' && cp <= 'z')
        || (cp >= 0x00C0 && cp <= 0x024F);
  }

  void CompositionController::setKeyboardScriptClass(ImeScriptClass script_class) {
    m_keyboard_script_class_ = script_class;
    if (isNonLatinScript(script_class)) {
      clearPlainLatinInputLock();
      clearCandidateCommitWindow();
    }
  }

  ImeScriptClass CompositionController::keyboardScriptClass() const {
    return m_keyboard_script_class_;
  }

  const CompositionState& CompositionController::composition() const {
    return m_composition_;
  }

  bool CompositionController::hasComposingSession() const {
    return m_composition_.has_session;
  }

  bool CompositionController::hasVisibleComposition() const {
    return m_composition_.has_session
        && m_composition_.is_composing
        && m_composition_.visible
        && m_composition_.phase == CompositionPhase::ACTIVE;
  }

  TextRange CompositionController::currentComposingRange() const {
    if (m_composition_.anchor_range.start != m_composition_.anchor_range.end) {
      return m_composition_.anchor_range;
    }
    return {
      m_composition_.start_position,
      {m_composition_.start_position.line, m_composition_.start_position.column + m_composition_.composing_columns}
    };
  }

  void CompositionController::resetCompositionState() {
    m_composition_.is_composing = false;
    m_composition_.has_session = false;
    m_composition_.phase = CompositionPhase::INACTIVE;
    m_composition_.visible = false;
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;
    m_composition_.start_position = {};
    m_composition_.anchor_range = {};
    m_composition_.original_text.clear();
    m_composition_.kind = CompositionKind::NONE;
    resetSessionPreservingCandidateWindow();
  }

  bool CompositionController::isNonLatinScript(ImeScriptClass script_class) {
    return script_class == ImeScriptClass::CJK
        || script_class == ImeScriptClass::KANA
        || script_class == ImeScriptClass::HANGUL;
  }

  bool CompositionController::isInlineCandidateText(const U8String& text) {
    return !text.empty()
        && text.find('\n') == U8String::npos
        && text.find('\r') == U8String::npos;
  }

  ImeScriptClass CompositionController::classifyScriptFromText(const U8String& text) {
    bool has_latin = false;
    auto it = text.begin();
    while (it != text.end()) {
      uint32_t cp = utf8::next(it, text.end());
      if (isHangulCodePoint(cp)) return ImeScriptClass::HANGUL;
      if (isKanaCodePoint(cp)) return ImeScriptClass::KANA;
      if (isCjkCodePoint(cp)) return ImeScriptClass::CJK;
      if (isLatinCodePoint(cp)) has_latin = true;
    }
    return has_latin ? ImeScriptClass::LATIN : ImeScriptClass::UNKNOWN;
  }

  size_t CompositionController::calcUtf16Columns(const U8String& text) {
    return simdutf::utf16_length_from_utf8(text.data(), text.size());
  }

  CompositionController::HostState CompositionController::captureHostState(const Host& host) {
    return {host.imeCursor(), host.imeHasSelection(), host.imeSelection()};
  }

  void CompositionController::finishAction(Host& host,
                                           ImeActionResult& result,
                                           const HostState& state) const {
    bool clear_platform_preedit = result.sync.clear_platform_preedit;
    result.cursor_changed = state.cursor != host.imeCursor();
    result.selection_changed = state.has_selection != host.imeHasSelection()
                               || !(state.selection == host.imeSelection());
    result.sync = buildSyncSnapshot(host);
    result.sync.clear_platform_preedit = result.sync.clear_platform_preedit || clear_platform_preedit;
  }

  void CompositionController::mergeEditResult(ImeActionResult& result, const TextEditResult& edit_result) {
    if (!edit_result.changed) return;
    if (!result.edit_result.changed) {
      result.edit_result = edit_result;
    } else {
      result.edit_result.changes.insert(result.edit_result.changes.end(),
                                        edit_result.changes.begin(),
                                        edit_result.changes.end());
      result.edit_result.cursor_after = edit_result.cursor_after;
    }
    result.edit_result.changed = true;
    result.content_changed = true;
  }

  void CompositionController::observeKeyboardScriptClass(ImeScriptClass script_class) {
    if (script_class != ImeScriptClass::UNKNOWN) {
      setKeyboardScriptClass(script_class);
    }
  }

  ImeActionResult CompositionController::updatePreedit(Host& host,
                                                       const U8String& text,
                                                       ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    HostState state = captureHostState(host);
    handleUpdatePreedit(host, result, text, script_class);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::commitText(Host& host,
                                                    const U8String& text,
                                                    ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    HostState state = captureHostState(host);
    handleCommitText(host, result, text, script_class);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::finishPreedit(Host& host) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleFinishPreedit(host, result);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::cancelPreedit(Host& host) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleCancelPreedit(host);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::markDocumentRange(Host& host,
                                                           const TextRange& range,
                                                           ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    HostState state = captureHostState(host);
    handleMarkDocumentRange(host, range);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::replaceText(Host& host,
                                                     const TextRange& range,
                                                     const U8String& text,
                                                     ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    HostState state = captureHostState(host);
    handleReplaceText(host, result, range, text);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::commitDocumentRangeReplacement(Host& host,
                                                                        const TextRange& range,
                                                                        const U8String& text,
                                                                        ImeScriptClass script_class) {
    ImeActionResult result;
    if (!host.imeHasDocument()
        || host.imeReadOnly()
        || !hasVisibleComposition()
        || m_composition_.kind != CompositionKind::DOCUMENT_RANGE) {
      return result;
    }

    TextRange safe_range = host.imeClampDocumentRange(range);
    if (!(m_composition_.anchor_range == safe_range)) {
      return result;
    }

    result.handled = true;
    observeKeyboardScriptClass(script_class);
    HostState state = captureHostState(host);
    clearShadowPreedit();
    clearPlainLatinInputLock();

    const size_t comp_start_line = m_composition_.start_position.line;
    resetCompositionState();
    mergeEditResult(result, host.imeApplyEdit(safe_range, text));
    TextRange candidate_range {
      safe_range.start,
      host.imePositionAfterInsert(safe_range.start, text)
    };
    openCandidateCommitWindow(candidate_range, text, true);
    host.imeInvalidateContentMetrics(comp_start_line);
    host.imeEnsureCursorVisible();
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteBackward(Host& host,
                                                        size_t before_length,
                                                        ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleDelete(host, result, before_length == 0 ? 1 : before_length, 0, text_unit);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteForward(Host& host,
                                                       size_t after_length,
                                                       ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleDelete(host, result, 0, after_length == 0 ? 1 : after_length, text_unit);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteSurrounding(Host& host,
                                                           size_t before_length,
                                                           size_t after_length,
                                                           ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleDelete(host, result, before_length, after_length, text_unit);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::notifySelectionChanged(Host& host, const TextRange& range) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleSelectionChanged(host, range);
    finishAction(host, result, state);
    return result;
  }

  ImeActionResult CompositionController::notifyCursorChanged(Host& host, const TextPosition& cursor) {
    ImeActionResult result;
    result.handled = true;
    HostState state = captureHostState(host);
    handleCursorChanged(host, cursor);
    finishAction(host, result, state);
    return result;
  }

  ImeScriptClass CompositionController::resolveScriptClass(const U8String& text,
                                                     ImeScriptClass script_class) const {
    ImeScriptClass text_script = classifyScriptFromText(text);
    if (text_script != ImeScriptClass::UNKNOWN) {
      return text_script;
    }
    if (script_class != ImeScriptClass::UNKNOWN) {
      return script_class;
    }
    return m_keyboard_script_class_;
  }

  bool CompositionController::canMoveSelectionInsideComposition(const TextRange& range) const {
    if (!hasVisibleComposition()) {
      return false;
    }
    TextRange composing_range = currentComposingRange();
    return composing_range.contains(range.start) && composing_range.contains(range.end);
  }

  bool CompositionController::hasMidDocumentRangeComposition(const CompositionState& composition,
                                                       const TextPosition& cursor) const {
    bool visible = composition.has_session
        && composition.is_composing
        && composition.visible
        && composition.phase == CompositionPhase::ACTIVE;
    if (!visible || composition.kind != CompositionKind::DOCUMENT_RANGE) {
      return false;
    }
    if (m_session_.preedit_text_in_document || m_session_.preedit_replaces_document_range) {
      return false;
    }
    const TextRange& range = composition.anchor_range;
    return range.contains(cursor) && cursor != range.end;
  }

  bool CompositionController::resolveDocumentRangePlainEdit(const CompositionState& composition,
                                                      const TextPosition& cursor,
                                                      const U8String& text,
                                                      TextRange& range,
                                                      U8String& replacement) const {
    if (!hasMidDocumentRangeComposition(composition, cursor)) {
      return false;
    }
    const TextRange& anchor = composition.anchor_range;
    if (anchor.start.line != anchor.end.line || anchor.start.line != cursor.line) {
      return false;
    }

    U16String original;
    U16String updated;
    StrUtil::convertUTF8ToUTF16(composition.original_text, original);
    StrUtil::convertUTF8ToUTF16(text, updated);
    const size_t cursor_offset = cursor.column - anchor.start.column;
    if (cursor_offset > original.size()) {
      return false;
    }

    if (updated.size() >= original.size()
        && std::equal(original.begin(), original.end(), updated.begin())) {
      return false;
    }

    U16String original_prefix(original.begin(), original.begin() + cursor_offset);
    U16String original_suffix(original.begin() + cursor_offset, original.end());
    if (updated.size() >= original_prefix.size()
        && std::equal(original_prefix.begin(), original_prefix.end(), updated.begin())) {
      bool preserves_suffix = updated.size() >= original_prefix.size() + original_suffix.size()
          && std::equal(original_suffix.rbegin(), original_suffix.rend(), updated.rbegin());
      U16String inserted_u16;
      if (preserves_suffix) {
        const size_t inserted_end = updated.size() - original_suffix.size();
        inserted_u16 = U16String(updated.begin() + cursor_offset, updated.begin() + inserted_end);
      } else {
        inserted_u16 = U16String(updated.begin() + cursor_offset, updated.end());
      }
      if (!inserted_u16.empty() && inserted_u16.size() <= 2) {
        StrUtil::convertUTF16ToUTF8(inserted_u16, replacement);
        range = {cursor, cursor};
        return true;
      }
    }

    size_t prefix = 0;
    while (prefix < original.size()
           && prefix < updated.size()
           && original[prefix] == updated[prefix]) {
      ++prefix;
    }

    size_t suffix = 0;
    while (suffix < original.size() - prefix
           && suffix < updated.size() - prefix
           && original[original.size() - suffix - 1] == updated[updated.size() - suffix - 1]) {
      ++suffix;
    }

    const size_t original_end = original.size() - suffix;
    const size_t updated_end = updated.size() - suffix;
    if (prefix == 0 && original_end == original.size() && original.size() > 1) {
      return false;
    }
    if (!(prefix <= cursor_offset && cursor_offset <= original_end)) {
      return false;
    }
    if (original_end != cursor_offset && prefix != cursor_offset) {
      return false;
    }

    U16String replacement_u16(updated.begin() + prefix, updated.begin() + updated_end);
    if (replacement_u16.size() > 2) {
      return false;
    }
    StrUtil::convertUTF16ToUTF8(replacement_u16, replacement);
    range = {
      {anchor.start.line, anchor.start.column + static_cast<uint32_t>(prefix)},
      {anchor.start.line, anchor.start.column + static_cast<uint32_t>(original_end)}
    };
    return true;
  }

  void CompositionController::clearShadowPreedit() {
    m_session_.has_shadow_preedit = false;
    m_session_.shadow_preedit_text.clear();
    m_session_.shadow_script_class = ImeScriptClass::UNKNOWN;
  }

  void CompositionController::setShadowPreedit(const U8String& text, ImeScriptClass script_class) {
    m_session_.has_shadow_preedit = true;
    m_session_.shadow_preedit_text = text;
    m_session_.shadow_script_class = resolveScriptClass(text, script_class);
  }

  void CompositionController::beginPlainLatinInputLock(const U8String& preedit_text) {
    m_session_.plain_latin_input_lock = true;
    m_session_.plain_latin_preedit_text = preedit_text;
  }

  void CompositionController::clearPlainLatinInputLock() {
    m_session_.plain_latin_input_lock = false;
    m_session_.plain_latin_preedit_text.clear();
  }

  void CompositionController::trimPlainLatinInputLock(size_t before_length) {
    if (!m_session_.plain_latin_input_lock || before_length == 0) {
      return;
    }
    U16String text;
    StrUtil::convertUTF8ToUTF16(m_session_.plain_latin_preedit_text, text);
    size_t trim_count = std::min(before_length, text.size());
    text.erase(text.size() - trim_count, trim_count);
    StrUtil::convertUTF16ToUTF8(text, m_session_.plain_latin_preedit_text);
  }

  bool CompositionController::shouldUsePlainLatinInputLock(const U8String& text,
                                                     ImeScriptClass script_class,
                                                     bool is_commit) const {
    if (!m_session_.plain_latin_input_lock) {
      return false;
    }
    if (text.empty()) {
      return true;
    }
    ImeScriptClass resolved_script = resolveScriptClass(text, script_class);
    if (resolved_script != ImeScriptClass::UNKNOWN && resolved_script != ImeScriptClass::LATIN) {
      return false;
    }

    const U8String& previous = m_session_.plain_latin_preedit_text;
    if (is_commit) {
      return previous.empty()
          || text == previous
          || text.rfind(previous, 0) == 0
          || calcUtf16Columns(text) <= 1;
    }
    if (calcUtf16Columns(text) <= 1) {
      return true;
    }
    return !previous.empty()
        && (text.rfind(previous, 0) == 0 || previous.rfind(text, 0) == 0);
  }

  bool CompositionController::shouldShadowPlainLatinLockedPreedit(const U8String& text,
                                                            ImeScriptClass script_class) const {
    return m_session_.plain_latin_input_lock
        && !text.empty()
        && !shouldUsePlainLatinInputLock(text, script_class, false);
  }

  void CompositionController::openCandidateCommitWindow(const TextRange& range,
                                                        const U8String& text,
                                                        bool suppress_exact_range) {
    if (!isInlineCandidateText(text) || range.start == range.end) {
      clearCandidateCommitWindow();
      return;
    }
    m_session_.has_candidate_commit_window = true;
    m_session_.candidate_committed_range = range;
    m_session_.candidate_committed_text = text;
    m_session_.candidate_deleted_to_prefix = false;
    m_session_.suppress_candidate_exact_range = suppress_exact_range;
  }

  void CompositionController::clearCandidateCommitWindow() {
    m_session_.has_candidate_commit_window = false;
    m_session_.candidate_committed_range = {};
    m_session_.candidate_committed_text.clear();
    m_session_.candidate_deleted_to_prefix = false;
    m_session_.suppress_candidate_exact_range = false;
  }

  void CompositionController::markCandidateDeletedToPrefix() {
    m_session_.candidate_deleted_to_prefix = true;
    m_session_.suppress_candidate_exact_range = false;
  }

  void CompositionController::resetSessionPreservingCandidateWindow() {
    bool has_candidate_commit_window = m_session_.has_candidate_commit_window;
    TextRange candidate_committed_range = m_session_.candidate_committed_range;
    U8String candidate_committed_text = m_session_.candidate_committed_text;
    bool candidate_deleted_to_prefix = m_session_.candidate_deleted_to_prefix;
    bool suppress_candidate_exact_range = m_session_.suppress_candidate_exact_range;

    m_session_ = {};
    m_session_.has_candidate_commit_window = has_candidate_commit_window;
    m_session_.candidate_committed_range = candidate_committed_range;
    m_session_.candidate_committed_text = candidate_committed_text;
    m_session_.candidate_deleted_to_prefix = candidate_deleted_to_prefix;
    m_session_.suppress_candidate_exact_range = suppress_candidate_exact_range;
  }

  ImeSyncSnapshot CompositionController::buildSyncSnapshot(const Host& host) const {
    ImeSyncSnapshot snapshot;
    snapshot.cursor = host.imeCursor();
    snapshot.has_selection = host.imeHasSelection();
    snapshot.selection = host.imeSelection();
    snapshot.has_composing_session = hasComposingSession() || m_session_.has_shadow_preedit;
    snapshot.context_policy = ImeContextPolicy::LIMITED_FOR_CANDIDATES;
    if (m_session_.plain_latin_input_lock) {
      snapshot.context_policy = ImeContextPolicy::NONE;
    }

    auto to_i32_offset = [](size_t value) -> int32_t {
      return value > static_cast<size_t>(std::numeric_limits<int32_t>::max())
          ? std::numeric_limits<int32_t>::max()
          : static_cast<int32_t>(value);
    };

    auto fill_platform_text_window = [&]() {
      if (!host.imeHasDocument() || snapshot.context_policy == ImeContextPolicy::NONE) {
        return;
      }
      size_t line_count = host.imeDocumentLineCount();
      if (line_count == 0) {
        return;
      }
      size_t line = std::min(snapshot.cursor.line, line_count - 1);
      TextRange window_range {{line, 0}, {line, host.imeLineColumns(line)}};
      size_t window_start = host.imeCharIndexFromPosition(window_range.start);
      snapshot.platform_text_window_text = host.imeDocumentText(window_range);
      snapshot.platform_text_window_start_offset = to_i32_offset(window_start);

      auto relative_offset = [&](const TextPosition& position) -> int32_t {
        size_t absolute = host.imeCharIndexFromPosition(position);
        if (absolute < window_start) {
          return 0;
        }
        return to_i32_offset(absolute - window_start);
      };

      if (snapshot.has_selection) {
        snapshot.platform_text_window_selection_start_offset = relative_offset(snapshot.selection.start);
        snapshot.platform_text_window_selection_end_offset = relative_offset(snapshot.selection.end);
      } else {
        int32_t cursor_offset = relative_offset(snapshot.cursor);
        snapshot.platform_text_window_selection_start_offset = cursor_offset;
        snapshot.platform_text_window_selection_end_offset = cursor_offset;
      }
      if (snapshot.has_platform_marked_range) {
        snapshot.platform_text_window_composing_start_offset = relative_offset(snapshot.platform_marked_range.start);
        snapshot.platform_text_window_composing_end_offset = relative_offset(snapshot.platform_marked_range.end);
      }
    };

    if (hasVisibleComposition()) {
      TextRange composing_range = currentComposingRange();
      snapshot.has_visible_composition_range = composing_range.start != composing_range.end;
      snapshot.visible_composition_range = composing_range;
      snapshot.has_platform_marked_range = snapshot.has_visible_composition_range;
      if (snapshot.has_platform_marked_range) {
        snapshot.platform_marked_range = composing_range;
      }
      snapshot.preedit_storage = ImePreeditStorage::VISIBLE_DOCUMENT_COMPOSITION;
      snapshot.clear_platform_preedit = false;
      fill_platform_text_window();
      return snapshot;
    }

    if (m_session_.has_shadow_preedit) {
      snapshot.preedit_storage = ImePreeditStorage::SHADOW_ONLY;
      snapshot.clear_platform_preedit = false;
      fill_platform_text_window();
      return snapshot;
    }

    snapshot.clear_platform_preedit = true;
    fill_platform_text_window();
    return snapshot;
  }

  bool CompositionController::hasMidDocumentRangeComposition(const Host& host) const {
    return hasMidDocumentRangeComposition(m_composition_, host.imeCursor());
  }

  bool CompositionController::hasEndDocumentRangeComposition(const Host& host) const {
    bool visible = m_composition_.has_session
        && m_composition_.is_composing
        && m_composition_.visible
        && m_composition_.phase == CompositionPhase::ACTIVE;
    if (!visible || m_composition_.kind != CompositionKind::DOCUMENT_RANGE) {
      return false;
    }
    if (m_session_.preedit_text_in_document || m_session_.preedit_replaces_document_range) {
      return false;
    }
    const TextRange& range = m_composition_.anchor_range;
    return range.start != range.end && host.imeCursor() == range.end;
  }

  bool CompositionController::resolveDocumentRangePlainEdit(const Host& host,
                                                            const U8String& text,
                                                            TextRange& range,
                                                            U8String& replacement) const {
    return resolveDocumentRangePlainEdit(m_composition_, host.imeCursor(), text, range, replacement);
  }

  bool CompositionController::resolveDocumentRangeInsertedText(const Host& host,
                                                               const U8String& text,
                                                               U8String& replacement) const {
    if (text.empty()) {
      return false;
    }
    const U8String& original = m_composition_.original_text;
    if (!original.empty()
        && text.size() > original.size()
        && text.rfind(original, 0) == 0) {
      replacement = text.substr(original.size());
      return !replacement.empty();
    }
    if (host.imeUtf16Columns(text) <= 2) {
      replacement = text;
      return true;
    }
    return false;
  }

  TextEditResult CompositionController::applyDocumentRangeEndReplacement(Host& host,
                                                                         const TextRange& range,
                                                                         const U8String& replacement,
                                                                         const U8String& preedit_text,
                                                                         const U8String& inserted_text,
                                                                         bool is_commit) {
    TextEditResult result = host.imeApplyEdit(range, replacement);
    TextPosition new_end = host.imePositionAfterInsert(range.start, replacement);
    TextRange updated_anchor {m_composition_.anchor_range.start, new_end};

    m_composition_.is_composing = true;
    m_composition_.has_session = true;
    m_composition_.phase = CompositionPhase::ACTIVE;
    m_composition_.visible = true;
    m_composition_.start_position = updated_anchor.start;
    m_composition_.anchor_range = updated_anchor;
    m_composition_.original_text = host.imeDocumentText(updated_anchor);
    m_composition_.composing_text = m_composition_.original_text;
    m_composition_.composing_columns = host.imeUtf16Columns(m_composition_.composing_text);
    m_composition_.kind = CompositionKind::DOCUMENT_RANGE;
    m_session_.preedit_text_in_document = false;
    m_session_.preedit_replaces_document_range = false;
    m_session_.preedit_replaced_range = {};
    m_session_.preedit_replaced_text.clear();
    m_session_.document_range_end_plain_preedit_text = is_commit ? U8String {} : preedit_text;
    m_session_.document_range_end_plain_inserted_text = is_commit ? U8String {} : inserted_text;

    host.imeSetCursorPositionInternal(new_end);
    host.imeSetSelectionInternal({new_end, new_end});
    host.imeInvalidateContentMetrics(updated_anchor.start.line);
    host.imeEnsureCursorVisible();
    return result;
  }

  void CompositionController::setComposingRange(Host& host, const TextRange& range) {
    if (!host.imeHasDocument() || host.imeReadOnly()) return;

    TextPosition previous_cursor = host.imeCursor();

    TextRange safe_range = host.imeClampDocumentRange(range);
    if (safe_range.start == safe_range.end) return;

    if (hasVisibleComposition() && m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange current_range = currentComposingRange();
      if (current_range == safe_range) {
        TextPosition target_cursor = previous_cursor;
        host.imeSetCursorPositionInternal(target_cursor);
        host.imeSetSelectionInternal({target_cursor, target_cursor});
        host.imeEnsureCursorVisible();
        return;
      }
    }

    if (hasVisibleComposition()) {
      commitComposingText(host, "", true);
    } else if (hasComposingSession()) {
      resetCompositionState();
    }

    U8String text = host.imeDocumentText(safe_range);
    m_composition_.is_composing = true;
    m_composition_.has_session = true;
    m_composition_.phase = CompositionPhase::ACTIVE;
    m_composition_.visible = true;
    m_composition_.start_position = safe_range.start;
    m_composition_.anchor_range = safe_range;
    m_composition_.original_text = text;
    m_composition_.composing_text = text;
    m_composition_.composing_columns = host.imeUtf16Columns(text);
    m_composition_.kind = CompositionKind::DOCUMENT_RANGE;
    m_session_.preedit_text_in_document = false;

    TextPosition target_cursor = previous_cursor;
    host.imeSetCursorPositionInternal(target_cursor);
    host.imeSetSelectionInternal({target_cursor, target_cursor});
    host.imeEnsureCursorVisible();
    LOGD("CompositionController::setComposingRange: %s -> %s, text='%s'",
         safe_range.start.dump().c_str(), safe_range.end.dump().c_str(), text.c_str());
  }

  void CompositionController::beginComposingTextSession(Host& host) {
    if (!host.imeHasDocument() || host.imeReadOnly()) return;

    if (hasComposingSession()) {
      cancelComposing(host);
    }

    if (host.imeHasSelection() && !host.imeIsLinkedEditingActive()) {
      host.imeDeleteSelectionForComposition();
    }

    m_composition_.is_composing = true;
    m_composition_.has_session = true;
    m_composition_.phase = CompositionPhase::ACTIVE;
    m_composition_.visible = true;
    m_composition_.start_position = host.imeCursor();
    if (host.imeIsLinkedEditingActive() && host.imeHasSelection()) {
      TextRange selection = host.imeSelection();
      m_composition_.start_position = selection.end < selection.start ? selection.end : selection.start;
    }
    m_composition_.anchor_range = {m_composition_.start_position, m_composition_.start_position};
    m_composition_.original_text.clear();
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;
    m_composition_.kind = CompositionKind::PREEDIT_TEXT;
    m_session_.preedit_text_in_document = false;

    LOGD("CompositionController::beginComposingTextSession, pos = %s", host.imeCursor().dump().c_str());
  }

  TextEditResult CompositionController::setComposingText(Host& host, const U8String& text) {
    if (!host.imeHasDocument() || host.imeReadOnly()) return {};

    if (!hasVisibleComposition()) {
      beginComposingTextSession(host);
    }

    TextPosition cursor_before = host.imeCursor();
    TextRange replacement_range = currentComposingRange();
    U8String replaced_text = m_composition_.composing_text;

    if (m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange composing_range = currentComposingRange();
      m_session_.preedit_replaces_document_range = true;
      m_session_.preedit_replaced_range = composing_range;
      m_session_.preedit_replaced_text = m_composition_.composing_text;
      host.imeDeleteDocumentRange(composing_range);
      host.imeSetRawCursorPosition(m_composition_.start_position);
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_session_.preedit_text_in_document = false;
    }

    if (hasMidDocumentRangeComposition(host)) {
      TextEditResult plain_edit = applyDocumentRangePlainEdit(host, text);
      if (plain_edit.changed || text.empty() || host.imeUtf16Columns(text) <= 2) {
        return plain_edit;
      }
    }

    if (hasEndDocumentRangeComposition(host)) {
      TextEditResult plain_edit = applyDocumentRangeEndPlainEdit(host, text, false);
      if (plain_edit.changed || text.empty()) {
        return plain_edit;
      }
    }

    if (host.imeIsLinkedEditingActive()) {
      m_composition_.composing_text = text;
      m_composition_.composing_columns = host.imeUtf16Columns(text);
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {
        m_composition_.start_position,
        host.imePositionAfterInsert(m_composition_.start_position, text)
      };
      m_session_.preedit_text_in_document = false;
      TextPosition new_pos = host.imePositionAfterInsert(m_composition_.start_position, text);
      host.imeSetCursorPositionInternal(new_pos);
      host.imeEnsureCursorVisible();
      LOGD("CompositionController::setComposingText(linked), text = %s, columns = %zu",
           text.c_str(), m_composition_.composing_columns);
      return {};
    }

    if (m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange composing_range = currentComposingRange();
      m_session_.preedit_replaces_document_range = true;
      m_session_.preedit_replaced_range = composing_range;
      m_session_.preedit_replaced_text = m_composition_.composing_text;
      host.imeDeleteDocumentRange(composing_range);
      host.imeSetRawCursorPosition(m_composition_.start_position);
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_session_.preedit_text_in_document = false;
    } else {
      removeComposingText(host);
    }

    if (!text.empty()) {
      host.imeInsertDocumentText(m_composition_.start_position, text);
      size_t new_columns = host.imeUtf16Columns(text);
      m_composition_.composing_text = text;
      m_composition_.composing_columns = new_columns;
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {
        m_composition_.start_position,
        host.imePositionAfterInsert(m_composition_.start_position, text)
      };
      m_session_.preedit_text_in_document = true;
      TextPosition new_pos = host.imePositionAfterInsert(m_composition_.start_position, text);
      host.imeSetCursorPositionInternal(new_pos);
    } else {
      m_composition_.composing_text.clear();
      m_composition_.composing_columns = 0;
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {m_composition_.start_position, m_composition_.start_position};
      m_session_.preedit_text_in_document = false;
      host.imeSetCursorPositionInternal(m_composition_.start_position);
    }
    host.imeInvalidateContentMetrics(m_composition_.start_position.line);
    host.imeEnsureCursorVisible();
    LOGD("CompositionController::setComposingText, text = %s, columns = %zu",
         text.c_str(), m_composition_.composing_columns);
    TextEditResult result;
    if (replaced_text != text) {
      result.changed = true;
      result.cursor_before = cursor_before;
      result.cursor_after = host.imeCursor();
      result.changes.push_back({replacement_range, replaced_text, text});
    }
    return result;
  }

  TextEditResult CompositionController::finishComposing(Host& host) {
    if (!host.imeHasDocument() || host.imeReadOnly()) return {};
    if (!hasComposingSession()) return {};
    if (hasVisibleComposition()
        && m_composition_.kind == CompositionKind::DOCUMENT_RANGE
        && !m_session_.preedit_text_in_document
        && !m_session_.preedit_replaces_document_range) {
      TextPosition previous_cursor = host.imeCursor();
      size_t comp_start_line = m_composition_.start_position.line;
      resetCompositionState();
      host.imeSetCursorPositionInternal(previous_cursor);
      host.imeInvalidateContentMetrics(comp_start_line);
      host.imeEnsureCursorVisible();
      TextEditResult result;
      result.cursor_before = previous_cursor;
      result.cursor_after = previous_cursor;
      return result;
    }
    return commitComposingText(host, "", true);
  }

  TextEditResult CompositionController::commitComposingText(Host& host,
                                                            const U8String& committed_text,
                                                            bool empty_text_keeps_composition) {
    if (!host.imeHasDocument() || host.imeReadOnly()) return {};

    if (!hasComposingSession()) {
      if (!committed_text.empty()) {
        clearCandidateCommitWindow();
        return host.imeInsertText(committed_text);
      }
      return {};
    }

    TextRange composing_range = currentComposingRange();
    TextPosition previous_cursor = host.imeCursor();
    U8String final_text = committed_text.empty() && empty_text_keeps_composition
        ? m_composition_.composing_text
        : committed_text;
    size_t comp_start_line = m_composition_.start_position.line;
    if (m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange commit_range = m_composition_.anchor_range;
      U8String original_text = m_composition_.original_text;
      U8String current_text = host.imeDocumentText(commit_range);
      resetCompositionState();
      host.imeInvalidateContentMetrics(comp_start_line);
      host.imeSetCursorPositionInternal(previous_cursor);

      if ((committed_text.empty() && empty_text_keeps_composition) || committed_text == current_text) {
        if (!committed_text.empty()) {
          openCandidateCommitWindow(commit_range, committed_text, true);
        }
        host.imeEnsureCursorVisible();
        TextEditResult edit_result;
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
        return edit_result;
      }
      if (current_text != original_text) {
        host.imeEnsureCursorVisible();
        TextEditResult edit_result;
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
        return edit_result;
      }
      auto edit_result = host.imeApplyEdit(commit_range, committed_text);
      TextRange candidate_range {
        commit_range.start,
        host.imePositionAfterInsert(commit_range.start, committed_text)
      };
      openCandidateCommitWindow(candidate_range, committed_text, true);
      host.imeEnsureCursorVisible();
      return edit_result;
    }

    bool replaces_document_range = m_session_.preedit_replaces_document_range;
    TextRange replaced_range = m_session_.preedit_replaced_range;
    U8String replaced_text = m_session_.preedit_replaced_text;
    bool should_restore_cursor = committed_text.empty()
                              && !replaces_document_range
                              && m_session_.preedit_text_in_document
                              && composing_range.contains(previous_cursor);
    TextPosition candidate_start = replaces_document_range ? replaced_range.start : m_composition_.start_position;
    TextRange candidate_range {candidate_start, host.imePositionAfterInsert(candidate_start, final_text)};

    removeComposingText(host);
    if (replaces_document_range) {
      host.imeInsertDocumentText(replaced_range.start, replaced_text);
      host.imeSetRawCursorPosition(replaced_range.start);
    }

    resetCompositionState();

    TextEditResult edit_result;
    if (replaces_document_range) {
      if (final_text != replaced_text) {
        edit_result = host.imeApplyEdit(replaced_range, final_text);
      } else {
        host.imeSetCursorPositionInternal(previous_cursor);
        host.imeInvalidateContentMetrics(comp_start_line);
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
      }
    } else if (!final_text.empty()) {
      edit_result = host.imeInsertText(final_text);
      if (should_restore_cursor) {
        host.imeSetCursorPositionInternal(previous_cursor);
        edit_result.cursor_after = previous_cursor;
      }
    }

    openCandidateCommitWindow(candidate_range, final_text, !committed_text.empty());
    host.imeEnsureCursorVisible();
    LOGD("CompositionController::commitComposingText, cursor = %s", host.imeCursor().dump().c_str());
    return edit_result;
  }

  void CompositionController::cancelComposing(Host& host) {
    if (!hasComposingSession()) return;

    if (!hasVisibleComposition()) {
      resetCompositionState();
      clearCandidateCommitWindow();
      host.imeEnsureCursorVisible();
      return;
    }

    size_t comp_start_line = m_composition_.start_position.line;
    bool replaces_document_range = m_session_.preedit_replaces_document_range;
    TextRange replaced_range = m_session_.preedit_replaced_range;
    U8String replaced_text = m_session_.preedit_replaced_text;

    removeComposingText(host);
    if (replaces_document_range) {
      host.imeInsertDocumentText(replaced_range.start, replaced_text);
      host.imeSetRawCursorPosition(replaced_range.start);
    }

    resetCompositionState();
    clearCandidateCommitWindow();

    host.imeInvalidateContentMetrics(comp_start_line);
    host.imeEnsureCursorVisible();
    LOGD("CompositionController::cancelComposing, cursor = %s", host.imeCursor().dump().c_str());
  }

  void CompositionController::removeComposingText(Host& host) {
    if (!m_composition_.is_composing || m_composition_.composing_columns == 0) return;
    if (m_composition_.kind != CompositionKind::PREEDIT_TEXT) return;
    if (!m_session_.preedit_text_in_document) return;
    if (!host.imeHasDocument()) return;

    TextRange comp_range = {
      m_composition_.start_position,
      {m_composition_.start_position.line, m_composition_.start_position.column + m_composition_.composing_columns}
    };
    host.imeDeleteDocumentRange(comp_range);
    host.imeSetRawCursorPosition(m_composition_.start_position);
    m_session_.preedit_text_in_document = false;
  }

  TextEditResult CompositionController::applyDocumentRangePlainEdit(Host& host, const U8String& text) {
    if (!hasMidDocumentRangeComposition(host)) {
      return {};
    }
    const TextPosition cursor = host.imeCursor();
    const size_t comp_start_line = m_composition_.start_position.line;
    if (text.empty()) {
      resetCompositionState();
      clearCandidateCommitWindow();
      host.imeSetCursorPositionInternal(cursor);
      host.imeInvalidateContentMetrics(comp_start_line);
      return {};
    }
    TextRange edit_range {cursor, cursor};
    U8String replacement = text;
    bool has_local_edit = resolveDocumentRangePlainEdit(host, text, edit_range, replacement);
    if (!has_local_edit && host.imeUtf16Columns(text) <= 2) {
      edit_range = {cursor, cursor};
      replacement = text;
      has_local_edit = true;
    }
    if (!has_local_edit) {
      return {};
    }

    resetCompositionState();
    clearCandidateCommitWindow();
    host.imeSetCursorPositionInternal(cursor);
    host.imeInvalidateContentMetrics(comp_start_line);
    TextEditResult result = host.imeApplyEdit(edit_range, replacement);
    beginPlainLatinInputLock(text);
    return result;
  }

  TextEditResult CompositionController::applyDocumentRangeEndPlainEdit(Host& host,
                                                                       const U8String& text,
                                                                       bool is_commit) {
    if (!hasEndDocumentRangeComposition(host)) {
      return {};
    }
    const U8String previous_preedit = m_session_.document_range_end_plain_preedit_text;
    const U8String previous_inserted = m_session_.document_range_end_plain_inserted_text;
    if (!previous_preedit.empty() || !previous_inserted.empty()) {
      if (is_commit && !text.empty() && (text == previous_preedit || text == previous_inserted)) {
        m_session_.document_range_end_plain_preedit_text.clear();
        m_session_.document_range_end_plain_inserted_text.clear();
        return {};
      }

      TextRange anchor = m_composition_.anchor_range;
      U8String current_text = host.imeDocumentText(anchor);
      U8String base_text = current_text;
      if (!previous_inserted.empty()
          && current_text.size() >= previous_inserted.size()
          && current_text.compare(current_text.size() - previous_inserted.size(),
                                  previous_inserted.size(),
                                  previous_inserted) == 0) {
        base_text = current_text.substr(0, current_text.size() - previous_inserted.size());
      }

      bool text_includes_base = !base_text.empty()
          && text.size() >= base_text.size()
          && text.rfind(base_text, 0) == 0;
      bool text_updates_previous = !previous_inserted.empty()
          && text.size() > previous_inserted.size()
          && text.rfind(previous_inserted, 0) == 0;

      if (is_commit && !text_includes_base && !text_updates_previous) {
        U8String replacement;
        if (!resolveDocumentRangeInsertedText(host, text, replacement)) {
          return {};
        }
        return applyDocumentRangeEndReplacement(host,
                                                {anchor.end, anchor.end},
                                                replacement,
                                                {},
                                                {},
                                                true);
      }

      U8String inserted_text = text_includes_base ? text.substr(base_text.size()) : text;
      if (inserted_text == previous_inserted) {
        if (is_commit) {
          m_session_.document_range_end_plain_preedit_text.clear();
          m_session_.document_range_end_plain_inserted_text.clear();
        } else {
          m_session_.document_range_end_plain_preedit_text = text;
        }
        return {};
      }
      if (!previous_inserted.empty()
          && inserted_text.size() > previous_inserted.size()
          && inserted_text.rfind(previous_inserted, 0) == 0) {
        U8String replacement = inserted_text.substr(previous_inserted.size());
        return applyDocumentRangeEndReplacement(host,
                                                {anchor.end, anchor.end},
                                                replacement,
                                                text,
                                                inserted_text,
                                                is_commit);
      }
      size_t previous_columns = host.imeUtf16Columns(previous_inserted);
      if (anchor.end.column < previous_columns) {
        return {};
      }
      TextRange previous_range {
        {anchor.end.line, anchor.end.column - static_cast<uint32_t>(previous_columns)},
        anchor.end
      };
      return applyDocumentRangeEndReplacement(host,
                                              previous_range,
                                              inserted_text,
                                              text,
                                              inserted_text,
                                              is_commit);
    }

    const U8String& original = m_composition_.original_text;
    if (!original.empty() && original.rfind(text, 0) == 0) {
      return {};
    }
    U8String replacement;
    if (!resolveDocumentRangeInsertedText(host, text, replacement)) {
      return {};
    }

    TextRange anchor = m_composition_.anchor_range;
    return applyDocumentRangeEndReplacement(host,
                                            {anchor.end, anchor.end},
                                            replacement,
                                            text,
                                            replacement,
                                            is_commit);
  }

  TextEditResult CompositionController::applyPlainLatinInputLockEdit(Host& host,
                                                                     const U8String& text,
                                                                     bool is_commit) {
    if (text.empty()) {
      m_session_.plain_latin_preedit_text.clear();
      return {};
    }

    U8String replacement = text;
    const U8String previous = m_session_.plain_latin_preedit_text;
    if (!previous.empty()) {
      if (text == previous && is_commit) {
        m_session_.plain_latin_preedit_text.clear();
        return {};
      }
      if (text.rfind(previous, 0) == 0) {
        replacement = text.substr(previous.size());
      } else if (previous.rfind(text, 0) == 0) {
        size_t delete_columns = host.imeUtf16Columns(previous.substr(text.size()));
        TextPosition cursor = host.imeCursor();
        if (cursor.column >= delete_columns) {
          TextRange delete_range {
            {cursor.line, cursor.column - static_cast<uint32_t>(delete_columns)},
            cursor
          };
          TextEditResult result = host.imeApplyEdit(delete_range, "");
          beginPlainLatinInputLock(is_commit ? U8String {} : text);
          return result;
        }
        replacement.clear();
      }
    }

    if (replacement.empty()) {
      beginPlainLatinInputLock(is_commit ? U8String {} : text);
      return {};
    }

    TextEditResult result = host.imeInsertText(replacement);
    beginPlainLatinInputLock(is_commit ? U8String {} : text);
    return result;
  }

  bool CompositionController::trySuppressCandidateCommit(Host& host, const U8String& text) {
    if (!m_session_.has_candidate_commit_window || hasComposingSession()) {
      return false;
    }
    if (!isInlineCandidateText(text)) {
      if (!text.empty()) {
        clearCandidateCommitWindow();
      }
      return false;
    }
    const U8String& committed_text = m_session_.candidate_committed_text;
    if (text == committed_text && m_session_.suppress_candidate_exact_range) {
      return true;
    }
    if (!m_session_.candidate_deleted_to_prefix) {
      return false;
    }

    TextPosition start = m_session_.candidate_committed_range.start;
    TextPosition cursor = host.imeCursor();
    if (cursor < start || cursor.line != start.line) {
      clearCandidateCommitWindow();
      return false;
    }
    TextRange prefix_range {start, cursor};
    U8String current_text;
    if (!(prefix_range.start == prefix_range.end)) {
      if (!host.imeIsDocumentRangeReadable(prefix_range)) {
        clearCandidateCommitWindow();
        return false;
      }
      current_text = host.imeDocumentText(prefix_range);
    }
    if (committed_text.rfind(current_text, 0) == 0
        && (committed_text.rfind(text, 0) == 0 || current_text.rfind(text, 0) == 0)) {
      return true;
    }
    clearCandidateCommitWindow();
    return false;
  }

  bool CompositionController::trySuppressCandidateMark(Host& host, const TextRange& range) {
    if (!m_session_.has_candidate_commit_window
        || !m_session_.suppress_candidate_exact_range
        || hasComposingSession()) {
      return false;
    }
    if (range.start == range.end) {
      return false;
    }
    if (!(range == m_session_.candidate_committed_range)) {
      return false;
    }
    if (!host.imeIsDocumentRangeReadable(range)) {
      clearCandidateCommitWindow();
      return false;
    }
    if (host.imeDocumentText(range) == m_session_.candidate_committed_text) {
      return true;
    }
    clearCandidateCommitWindow();
    return false;
  }

  void CompositionController::updateCandidateWindowAfterDelete(Host& host) {
    if (!m_session_.has_candidate_commit_window || hasComposingSession()) {
      return;
    }
    TextPosition start = m_session_.candidate_committed_range.start;
    TextPosition cursor = host.imeCursor();
    if (cursor == start) {
      markCandidateDeletedToPrefix();
      return;
    }
    if (cursor < start) {
      clearCandidateCommitWindow();
      return;
    }
    if (cursor.line != start.line || m_session_.candidate_committed_range.end < cursor) {
      clearCandidateCommitWindow();
      return;
    }

    TextRange prefix_range {start, cursor};
    if (!host.imeIsDocumentRangeReadable(prefix_range)) {
      clearCandidateCommitWindow();
      return;
    }
    U8String current_text = host.imeDocumentText(prefix_range);
    const U8String& committed_text = m_session_.candidate_committed_text;
    if (!current_text.empty()
        && current_text.size() < committed_text.size()
        && committed_text.rfind(current_text, 0) == 0) {
      markCandidateDeletedToPrefix();
      return;
    }
    if (current_text != committed_text) {
      clearCandidateCommitWindow();
    }
  }

  void CompositionController::handleUpdatePreedit(Host& host,
                                                  ImeActionResult& result,
                                                  const U8String& text,
                                                  ImeScriptClass script_class) {
    if (shouldUsePlainLatinInputLock(text, script_class, false)) {
      clearShadowPreedit();
      mergeEditResult(result, applyPlainLatinInputLockEdit(host, text, false));
      return;
    }
    if (shouldShadowPlainLatinLockedPreedit(text, script_class)) {
      setShadowPreedit(text, script_class);
      return;
    }
    if (m_session_.plain_latin_input_lock && !text.empty()) {
      clearPlainLatinInputLock();
    }
    if (text.empty()) {
      if (m_session_.has_shadow_preedit) {
        if (hasComposingSession()) {
          mergeEditResult(result, commitComposingText(host, "", true));
        }
        clearShadowPreedit();
        return;
      }
      if (!hasComposingSession()) {
        clearShadowPreedit();
        return;
      }
    }
    clearShadowPreedit();
    if (trySuppressCandidateCommit(host, text)) {
      return;
    }
    clearCandidateCommitWindow();
    mergeEditResult(result, setComposingText(host, text));
  }

  void CompositionController::handleCommitText(Host& host,
                                               ImeActionResult& result,
                                               const U8String& text,
                                               ImeScriptClass script_class) {
    if (shouldUsePlainLatinInputLock(text, script_class, true)) {
      clearShadowPreedit();
      mergeEditResult(result, applyPlainLatinInputLockEdit(host, text, true));
      return;
    }
    if (m_session_.plain_latin_input_lock && !text.empty()) {
      clearPlainLatinInputLock();
    }
    clearShadowPreedit();
    if (trySuppressCandidateCommit(host, text)) {
      return;
    }
    if (hasEndDocumentRangeComposition(host)
        && !text.empty()
        && text == m_session_.document_range_end_plain_preedit_text) {
      m_session_.document_range_end_plain_preedit_text.clear();
      m_session_.document_range_end_plain_inserted_text.clear();
      return;
    }
    if (hasEndDocumentRangeComposition(host)
        && !text.empty()
        && (!m_session_.document_range_end_plain_inserted_text.empty() || host.imeUtf16Columns(text) <= 1)) {
      TextEditResult plain_edit = applyDocumentRangeEndPlainEdit(host, text, true);
      if (plain_edit.changed) {
        mergeEditResult(result, plain_edit);
        return;
      }
    }
    if (hasMidDocumentRangeComposition(host)) {
      TextRange plain_range;
      U8String plain_replacement;
      bool looks_like_plain_edit = resolveDocumentRangePlainEdit(
          host,
          text,
          plain_range,
          plain_replacement);
      if (looks_like_plain_edit || host.imeUtf16Columns(text) <= 1) {
        mergeEditResult(result, applyDocumentRangePlainEdit(host, text));
        return;
      }
    }
    mergeEditResult(result, commitComposingText(host, text));
  }

  void CompositionController::handleFinishPreedit(Host& host, ImeActionResult& result) {
    if (m_session_.has_shadow_preedit) {
      clearShadowPreedit();
      return;
    }
    mergeEditResult(result, finishComposing(host));
  }

  void CompositionController::handleCancelPreedit(Host& host) {
    clearShadowPreedit();
    clearCandidateCommitWindow();
    cancelComposing(host);
  }

  void CompositionController::handleMarkDocumentRange(Host& host, const TextRange& range) {
    clearPlainLatinInputLock();
    clearShadowPreedit();
    TextRange safe_range = host.imeClampDocumentRange(range);
    if (trySuppressCandidateMark(host, safe_range)) {
      return;
    }
    clearCandidateCommitWindow();
    setComposingRange(host, safe_range);
  }

  bool CompositionController::tryDeleteFromDocumentRangeEnd(Host& host,
                                                            ImeActionResult& result,
                                                            size_t before_length,
                                                            size_t after_length,
                                                            ImeTextUnit text_unit) {
    if (!hasVisibleComposition()
        || m_composition_.kind != CompositionKind::DOCUMENT_RANGE
        || m_session_.preedit_text_in_document
        || m_session_.preedit_replaces_document_range) {
      return false;
    }
    TextRange anchor = m_composition_.anchor_range;
    TextPosition cursor = host.imeCursor();
    if (cursor != anchor.end || anchor.start.line != anchor.end.line || cursor.line != anchor.start.line) {
      return false;
    }
    if (before_length == 0 && after_length == 0) {
      return true;
    }

    U8String current_text = host.imeDocumentText(anchor);
    U16String current_u16;
    StrUtil::convertUTF8ToUTF16(current_text, current_u16);
    size_t cursor_offset = std::min<size_t>(cursor.column - anchor.start.column, current_u16.size());
    size_t delete_start_offset = cursor_offset;
    size_t delete_end_offset = cursor_offset;

    for (size_t i = 0; i < before_length && delete_start_offset > 0; ++i) {
      delete_start_offset = text_unit == ImeTextUnit::CODE_POINT
                            ? UnicodeUtil::prevCodePointColumn(current_u16, delete_start_offset)
                            : UnicodeUtil::prevGraphemeBoundaryColumn(current_u16, delete_start_offset);
    }
    for (size_t i = 0; i < after_length && delete_end_offset < current_u16.size(); ++i) {
      delete_end_offset = text_unit == ImeTextUnit::CODE_POINT
                          ? UnicodeUtil::nextCodePointColumn(current_u16, delete_end_offset)
                          : UnicodeUtil::nextGraphemeBoundaryColumn(current_u16, delete_end_offset);
    }
    if (delete_start_offset == delete_end_offset) {
      return true;
    }

    TextRange delete_range {
      {anchor.start.line, anchor.start.column + static_cast<uint32_t>(delete_start_offset)},
      {anchor.start.line, anchor.start.column + static_cast<uint32_t>(delete_end_offset)}
    };
    U8String deleted_text = host.imeDocumentText(delete_range);
    host.imeDeleteDocumentRange(delete_range);

    TextPosition new_cursor = delete_range.start;
    const size_t deleted_columns = delete_end_offset - delete_start_offset;
    TextRange updated_anchor {
      anchor.start,
      {anchor.end.line, anchor.end.column - static_cast<uint32_t>(deleted_columns)}
    };

    TextEditResult edit_result;
    edit_result.changed = true;
    edit_result.cursor_before = cursor;
    edit_result.cursor_after = new_cursor;
    edit_result.changes.push_back({delete_range, deleted_text, ""});
    mergeEditResult(result, edit_result);

    if (updated_anchor.start == updated_anchor.end) {
      resetCompositionState();
      clearCandidateCommitWindow();
      host.imeSetCursorPositionInternal(new_cursor);
      host.imeSetSelectionInternal({new_cursor, new_cursor});
      host.imeInvalidateContentMetrics(anchor.start.line);
      host.imeEnsureCursorVisible();
      return true;
    }

    m_composition_.anchor_range = updated_anchor;
    m_composition_.start_position = updated_anchor.start;
    m_composition_.original_text = host.imeDocumentText(updated_anchor);
    m_composition_.composing_text = m_composition_.original_text;
    m_composition_.composing_columns = host.imeUtf16Columns(m_composition_.composing_text);
    host.imeSetCursorPositionInternal(new_cursor);
    host.imeSetSelectionInternal({new_cursor, new_cursor});
    host.imeInvalidateContentMetrics(anchor.start.line);
    host.imeEnsureCursorVisible();
    return true;
  }

  void CompositionController::handleDelete(Host& host,
                                           ImeActionResult& result,
                                           size_t before_length,
                                           size_t after_length,
                                           ImeTextUnit text_unit) {
    if (tryDeleteFromDocumentRangeEnd(host, result, before_length, after_length, text_unit)) {
      return;
    }
    bool keep_plain_latin_input = hasMidDocumentRangeComposition(host) || m_session_.plain_latin_input_lock;
    U8String plain_latin_text = m_session_.plain_latin_preedit_text;
    if (host.imeHasSelection()) {
      mergeEditResult(result, host.imeBackspace());
      updateCandidateWindowAfterDelete(host);
      if (keep_plain_latin_input) {
        beginPlainLatinInputLock({});
      }
      return;
    }
    const bool delete_code_points = text_unit == ImeTextUnit::CODE_POINT;
    for (size_t i = 0; i < before_length; ++i) {
      mergeEditResult(result, delete_code_points ? host.imeDeleteCodePointBackward() : host.imeBackspace());
    }
    for (size_t i = 0; i < after_length; ++i) {
      mergeEditResult(result, delete_code_points ? host.imeDeleteCodePointForward() : host.imeDeleteForward());
    }
    updateCandidateWindowAfterDelete(host);
    if (keep_plain_latin_input) {
      beginPlainLatinInputLock(plain_latin_text);
      trimPlainLatinInputLock(before_length);
    }
  }

  void CompositionController::handleSelectionChanged(Host& host, const TextRange& range) {
    clearPlainLatinInputLock();
    clearCandidateCommitWindow();
    clearShadowPreedit();
    if (canMoveSelectionInsideComposition(range)) {
      if (range.start == range.end) {
        host.imeSetCursorPositionInternal(range.start);
        host.imeSetSelectionInternal({range.start, range.start});
      } else {
        host.imeSetSelectionInternal(range);
      }
      host.imeEnsureCursorVisible();
      return;
    }
    if (hasComposingSession()) {
      commitComposingText(host, "", true);
    }
    if (range.start == range.end) {
      host.imeSetCursorPositionInternal(range.start);
      host.imeSetSelectionInternal({range.start, range.start});
    } else {
      host.imeSetSelectionInternal(range);
    }
  }

  void CompositionController::handleCursorChanged(Host& host, const TextPosition& cursor) {
    clearPlainLatinInputLock();
    clearCandidateCommitWindow();
    clearShadowPreedit();
    TextRange cursor_range {cursor, cursor};
    if (canMoveSelectionInsideComposition(cursor_range)) {
      host.imeSetCursorPositionInternal(cursor);
      host.imeSetSelectionInternal({cursor, cursor});
      host.imeEnsureCursorVisible();
      return;
    }
    if (hasComposingSession() && cursor != host.imeCursor()) {
      commitComposingText(host, "", true);
    }
    host.imeSetCursorPositionInternal(cursor);
    host.imeSetSelectionInternal({cursor, cursor});
  }

  void CompositionController::handleReplaceText(Host& host,
                                                ImeActionResult& result,
                                                const TextRange& range,
                                                const U8String& text) {
    clearShadowPreedit();
    clearCandidateCommitWindow();
    if (hasComposingSession()) {
      mergeEditResult(result, finishComposing(host));
    }
    TextRange safe_range = host.imeClampDocumentRange(range);
    mergeEditResult(result, host.imeApplyEdit(safe_range, text));
  }

}
