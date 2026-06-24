//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <algorithm>
#include <utility>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
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

  CompositionController::CompositionController(EditorCore& editor): m_editor_(editor) {
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

  bool CompositionController::hasPreedit() const {
    return m_composition_.kind != CompositionKind::NONE;
  }

  TextRange CompositionController::currentPreeditRange() const {
    if (m_composition_.anchor_range.start != m_composition_.anchor_range.end) {
      return m_composition_.anchor_range;
    }
    return {
      m_composition_.start_position,
      {m_composition_.start_position.line, m_composition_.start_position.column + m_composition_.preedit_columns}
    };
  }

  void CompositionController::resetCompositionState() {
    m_composition_.preedit_text.clear();
    m_composition_.preedit_columns = 0;
    m_composition_.start_position = {};
    m_composition_.anchor_range = {};
    m_composition_.original_text.clear();
    m_composition_.kind = CompositionKind::NONE;
    resetFlowPreservingCandidateWindow();
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

  CompositionController::EditorState CompositionController::captureEditorState() const {
    return {coreCursor(), coreHasSelection(), coreSelection()};
  }

  void CompositionController::finishAction(ImeActionResult& result,
                                           const EditorState& state) const {
    bool clear_system_mark = result.sync.clear_system_mark;
    result.cursor_changed = state.cursor != coreCursor();
    result.selection_changed = state.has_selection != coreHasSelection()
                               || !(state.selection == coreSelection());
    result.sync = buildSyncSnapshot();
    result.sync.clear_system_mark = result.sync.clear_system_mark || clear_system_mark;
  }

  bool CompositionController::coreHasDocument() const {
    return m_editor_.m_document_ != nullptr;
  }

  bool CompositionController::coreReadOnly() const {
    return m_editor_.m_settings_.read_only;
  }

  bool CompositionController::coreIsLinkedEditingActive() const {
    return m_editor_.isInLinkedEditing();
  }

  TextPosition CompositionController::coreCursor() const {
    return m_editor_.m_caret_.cursor;
  }

  bool CompositionController::coreHasSelection() const {
    return m_editor_.m_caret_.has_selection;
  }

  TextRange CompositionController::coreSelection() const {
    return m_editor_.m_caret_.selection;
  }

  TextRange CompositionController::coreClampDocumentRange(const TextRange& range) const {
    if (m_editor_.m_document_ == nullptr) {
      return {};
    }
    return m_editor_.clampDocumentRange(range, false, true);
  }

  bool CompositionController::coreIsDocumentRangeReadable(const TextRange& range) const {
    return m_editor_.isDocumentRangeReadable(range);
  }

  U8String CompositionController::coreDocumentText(const TextRange& range) const {
    if (m_editor_.m_document_ == nullptr) {
      return {};
    }
    return m_editor_.m_document_->getU8Text(range);
  }

  size_t CompositionController::coreDocumentLineCount() const {
    return m_editor_.m_document_ != nullptr ? m_editor_.m_document_->getLineCount() : 0;
  }

  uint32_t CompositionController::coreLineColumns(size_t line) const {
    if (m_editor_.m_document_ == nullptr || line >= m_editor_.m_document_->getLineCount()) {
      return 0;
    }
    return m_editor_.m_document_->getLineColumns(line);
  }

  size_t CompositionController::coreCharIndexFromPosition(const TextPosition& position) const {
    if (m_editor_.m_document_ == nullptr) {
      return 0;
    }
    return m_editor_.m_document_->getCharIndexFromPosition(position);
  }

  TextPosition CompositionController::corePositionAfterInsert(const TextPosition& start, const U8String& text) const {
    return m_editor_.calcPositionAfterInsert(start, text);
  }

  TextEditResult CompositionController::coreApplyEdit(const TextRange& range, const U8String& text) {
    return m_editor_.applyEdit(range, text);
  }

  TextEditResult CompositionController::coreInsertText(const U8String& text) {
    return m_editor_.insertTextInternal(text);
  }

  void CompositionController::coreRecordUndoAction(const TextRange& range,
                                                   const U8String& old_text,
                                                   const U8String& new_text,
                                                   const TextPosition& cursor_before,
                                                   const TextPosition& cursor_after,
                                                   bool had_selection,
                                                   const TextRange& selection_before) {
    EditAction action;
    action.range = range;
    action.old_text = old_text;
    action.new_text = new_text;
    action.cursor_before = cursor_before;
    action.cursor_after = cursor_after;
    action.had_selection = had_selection;
    action.selection_before = selection_before;
    action.timestamp = std::chrono::steady_clock::now();
    m_editor_.m_undo_manager_->pushAction(std::move(action));
  }

  void CompositionController::coreDeleteSelectionForComposition() {
    m_editor_.deleteSelection();
  }

  void CompositionController::coreDeleteDocumentRange(const TextRange& range) {
    if (m_editor_.m_document_ != nullptr) {
      m_editor_.m_document_->deleteU8Text(range);
      m_editor_.noteDocumentContentChanged();
    }
  }

  void CompositionController::coreInsertDocumentText(const TextPosition& position, const U8String& text) {
    if (m_editor_.m_document_ != nullptr) {
      m_editor_.m_document_->insertU8Text(position, text);
      m_editor_.noteDocumentContentChanged();
    }
  }

  TextEditResult CompositionController::coreBackspace() {
    return m_editor_.backspaceInternal();
  }

  TextEditResult CompositionController::coreDeleteForward() {
    return m_editor_.deleteForwardInternal();
  }

  TextEditResult CompositionController::coreDeleteCodePointBackward() {
    return m_editor_.deleteCodePointBackward();
  }

  TextEditResult CompositionController::coreDeleteCodePointForward() {
    return m_editor_.deleteCodePointForward();
  }

  void CompositionController::coreSetCursorPosition(const TextPosition& cursor) {
    m_editor_.setCursorPosition(cursor);
  }

  void CompositionController::coreSetSelection(const TextRange& range) {
    m_editor_.setSelection(range);
  }

  void CompositionController::coreSetCursorPositionInternal(const TextPosition& cursor) {
    m_editor_.setCursorPositionInternal(cursor, false);
  }

  void CompositionController::coreSetSelectionInternal(const TextRange& range) {
    m_editor_.setSelectionInternal(range, false);
  }

  void CompositionController::coreSetRawCursorPosition(const TextPosition& cursor) {
    m_editor_.m_caret_.cursor = cursor;
  }

  void CompositionController::coreInvalidateContentMetrics(size_t line) {
    if (m_editor_.m_text_layout_ != nullptr) {
      m_editor_.m_text_layout_->invalidateContentMetrics(line);
    }
  }

  void CompositionController::coreEnsureCursorVisible() {
    m_editor_.ensureCursorVisible();
  }

  void CompositionController::mergeEditResult(ImeActionResult& result, const TextEditResult& edit_result) {
    if (!edit_result.contentChanged()) return;
    if (!result.edit_result.contentChanged()) {
      result.edit_result = edit_result;
    } else {
      result.edit_result.markHandled(edit_result.change_kind);
      result.edit_result.changes.insert(result.edit_result.changes.end(),
                                        edit_result.changes.begin(),
                                        edit_result.changes.end());
      result.edit_result.cursor_after = edit_result.cursor_after;
    }
    result.content_changed = true;
  }

  void CompositionController::observeKeyboardScriptClass(ImeScriptClass script_class) {
    if (script_class != ImeScriptClass::UNKNOWN) {
      setKeyboardScriptClass(script_class);
    }
  }

  ImeActionResult CompositionController::updatePreedit(const U8String& text,
                                                       ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    EditorState state = captureEditorState();
    handleUpdatePreedit(result, text, script_class);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::commitText(const U8String& text,
                                                    ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    EditorState state = captureEditorState();
    handleCommitText(result, text, script_class);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::finishPreedit() {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleFinishPreedit(result);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::cancelPreedit() {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleCancelPreedit();
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::markDocumentRange(const TextRange& range,
                                                           ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    EditorState state = captureEditorState();
    handleMarkDocumentRange(range);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::replaceText(const TextRange& range,
                                                     const U8String& text,
                                                     ImeScriptClass script_class) {
    ImeActionResult result;
    result.handled = true;
    observeKeyboardScriptClass(script_class);
    EditorState state = captureEditorState();
    handleReplaceText(result, range, text);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::commitDocumentRangeReplacement(const TextRange& range,
                                                                        const U8String& text,
                                                                        ImeScriptClass script_class) {
    ImeActionResult result;
    if (!coreHasDocument()
        || coreReadOnly()
        || !hasPreedit()
        || m_composition_.kind != CompositionKind::DOCUMENT_RANGE) {
      return result;
    }

    TextRange safe_range = coreClampDocumentRange(range);
    if (!(m_composition_.anchor_range == safe_range)) {
      return result;
    }

    result.handled = true;
    observeKeyboardScriptClass(script_class);
    EditorState state = captureEditorState();
    clearPlainLatinInputLock();

    const size_t preedit_start_line = m_composition_.start_position.line;
    resetCompositionState();
    mergeEditResult(result, coreApplyEdit(safe_range, text));
    TextRange candidate_range {
      safe_range.start,
      corePositionAfterInsert(safe_range.start, text)
    };
    openCandidateCommitWindow(candidate_range, text, true);
    coreInvalidateContentMetrics(preedit_start_line);
    coreEnsureCursorVisible();
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteBackward(size_t before_length,
                                                        ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleDelete(result, before_length == 0 ? 1 : before_length, 0, text_unit);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteForward(size_t after_length,
                                                       ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleDelete(result, 0, after_length == 0 ? 1 : after_length, text_unit);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::deleteSurrounding(size_t before_length,
                                                           size_t after_length,
                                                           ImeTextUnit text_unit) {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleDelete(result, before_length, after_length, text_unit);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::notifySelectionChanged(const TextRange& range) {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleSelectionChanged(range);
    finishAction(result, state);
    return result;
  }

  ImeActionResult CompositionController::notifyCursorChanged(const TextPosition& cursor) {
    ImeActionResult result;
    result.handled = true;
    EditorState state = captureEditorState();
    handleCursorChanged(cursor);
    finishAction(result, state);
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

  bool CompositionController::canMoveSelectionInsidePreedit(const TextRange& range) const {
    if (!hasPreedit()) {
      return false;
    }
    TextRange preedit_range = currentPreeditRange();
    return preedit_range.contains(range.start) && preedit_range.contains(range.end);
  }

  bool CompositionController::hasMidDocumentRangePreedit(const CompositionState& composition,
                                                       const TextPosition& cursor) const {
    if (composition.kind != CompositionKind::DOCUMENT_RANGE) {
      return false;
    }
    if (m_flow_.preedit_text_in_document || m_flow_.preedit_replaces_document_range) {
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
    if (!hasMidDocumentRangePreedit(composition, cursor)) {
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

  void CompositionController::beginPlainLatinInputLock(const U8String& preedit_text) {
    m_flow_.plain_latin_input_lock = true;
    m_flow_.plain_latin_preedit_text = preedit_text;
  }

  void CompositionController::clearPlainLatinInputLock() {
    m_flow_.plain_latin_input_lock = false;
    m_flow_.plain_latin_preedit_text.clear();
  }

  void CompositionController::trimPlainLatinInputLock(size_t before_length) {
    if (!m_flow_.plain_latin_input_lock || before_length == 0) {
      return;
    }
    U16String text;
    StrUtil::convertUTF8ToUTF16(m_flow_.plain_latin_preedit_text, text);
    size_t trim_count = std::min(before_length, text.size());
    text.erase(text.size() - trim_count, trim_count);
    StrUtil::convertUTF16ToUTF8(text, m_flow_.plain_latin_preedit_text);
  }

  bool CompositionController::shouldUsePlainLatinInputLock(const U8String& text,
                                                     ImeScriptClass script_class,
                                                     bool is_commit) const {
    if (!m_flow_.plain_latin_input_lock) {
      return false;
    }
    if (text.empty()) {
      return true;
    }
    ImeScriptClass resolved_script = resolveScriptClass(text, script_class);
    if (resolved_script != ImeScriptClass::UNKNOWN && resolved_script != ImeScriptClass::LATIN) {
      return false;
    }

    const U8String& previous = m_flow_.plain_latin_preedit_text;
    if (is_commit) {
      return previous.empty()
          || text == previous
          || text.rfind(previous, 0) == 0
          || StrUtil::utf16Length(text) <= 1;
    }
    if (StrUtil::utf16Length(text) <= 1) {
      return true;
    }
    return !previous.empty()
        && (text.rfind(previous, 0) == 0 || previous.rfind(text, 0) == 0);
  }

  void CompositionController::openCandidateCommitWindow(const TextRange& range,
                                                        const U8String& text,
                                                        bool suppress_exact_range) {
    if (!isInlineCandidateText(text) || range.start == range.end) {
      clearCandidateCommitWindow();
      return;
    }
    m_flow_.has_candidate_commit_window = true;
    m_flow_.candidate_committed_range = range;
    m_flow_.candidate_committed_text = text;
    m_flow_.candidate_deleted_to_prefix = false;
    m_flow_.suppress_candidate_exact_range = suppress_exact_range;
  }

  void CompositionController::clearCandidateCommitWindow() {
    m_flow_.has_candidate_commit_window = false;
    m_flow_.candidate_committed_range = {};
    m_flow_.candidate_committed_text.clear();
    m_flow_.candidate_deleted_to_prefix = false;
    m_flow_.suppress_candidate_exact_range = false;
  }

  void CompositionController::markCandidateDeletedToPrefix() {
    m_flow_.candidate_deleted_to_prefix = true;
    m_flow_.suppress_candidate_exact_range = false;
  }

  void CompositionController::resetFlowPreservingCandidateWindow() {
    bool has_candidate_commit_window = m_flow_.has_candidate_commit_window;
    TextRange candidate_committed_range = m_flow_.candidate_committed_range;
    U8String candidate_committed_text = m_flow_.candidate_committed_text;
    bool candidate_deleted_to_prefix = m_flow_.candidate_deleted_to_prefix;
    bool suppress_candidate_exact_range = m_flow_.suppress_candidate_exact_range;

    m_flow_ = {};
    m_flow_.has_candidate_commit_window = has_candidate_commit_window;
    m_flow_.candidate_committed_range = candidate_committed_range;
    m_flow_.candidate_committed_text = candidate_committed_text;
    m_flow_.candidate_deleted_to_prefix = candidate_deleted_to_prefix;
    m_flow_.suppress_candidate_exact_range = suppress_candidate_exact_range;
  }

  ImeSyncSnapshot CompositionController::buildSyncSnapshot() const {
    ImeSyncSnapshot snapshot;
    snapshot.cursor = coreCursor();
    snapshot.has_selection = coreHasSelection();
    snapshot.selection = coreSelection();
    snapshot.context_policy = inputContextPolicy();

    if (hasPreedit()) {
      TextRange preedit_range = currentPreeditRange();
      snapshot.has_preedit_range = preedit_range.start != preedit_range.end;
      snapshot.preedit_range = preedit_range;
      snapshot.clear_system_mark = false;
      return snapshot;
    }

    snapshot.clear_system_mark = true;
    return snapshot;
  }

  ImeContextPolicy CompositionController::inputContextPolicy() const {
    return m_flow_.plain_latin_input_lock
           ? ImeContextPolicy::NONE
           : ImeContextPolicy::LIMITED_FOR_CANDIDATES;
  }

  bool CompositionController::hasMidDocumentRangePreedit() const {
    return hasMidDocumentRangePreedit(m_composition_, coreCursor());
  }

  bool CompositionController::hasEndDocumentRangePreedit() const {
    if (m_composition_.kind != CompositionKind::DOCUMENT_RANGE) {
      return false;
    }
    if (m_flow_.preedit_text_in_document || m_flow_.preedit_replaces_document_range) {
      return false;
    }
    const TextRange& range = m_composition_.anchor_range;
    return range.start != range.end && coreCursor() == range.end;
  }

  bool CompositionController::resolveDocumentRangePlainEdit(const U8String& text,
                                                            TextRange& range,
                                                            U8String& replacement) const {
    return resolveDocumentRangePlainEdit(m_composition_, coreCursor(), text, range, replacement);
  }

  bool CompositionController::resolveDocumentRangeInsertedText(const U8String& text,
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
    if (StrUtil::utf16Length(text) <= 2) {
      replacement = text;
      return true;
    }
    return false;
  }

  TextEditResult CompositionController::applyDocumentRangeEndReplacement(const TextRange& range,
                                                                         const U8String& replacement,
                                                                         const U8String& preedit_text,
                                                                         const U8String& inserted_text,
                                                                         bool is_commit) {
    TextEditResult result = coreApplyEdit(range, replacement);
    TextPosition new_end = corePositionAfterInsert(range.start, replacement);
    TextRange updated_anchor {m_composition_.anchor_range.start, new_end};

    m_composition_.start_position = updated_anchor.start;
    m_composition_.anchor_range = updated_anchor;
    m_composition_.original_text = coreDocumentText(updated_anchor);
    m_composition_.preedit_text = m_composition_.original_text;
    m_composition_.preedit_columns = StrUtil::utf16Length(m_composition_.preedit_text);
    m_composition_.kind = CompositionKind::DOCUMENT_RANGE;
    m_flow_.preedit_text_in_document = false;
    m_flow_.preedit_replaces_document_range = false;
    m_flow_.preedit_replaced_range = {};
    m_flow_.preedit_replaced_text.clear();
    m_flow_.document_range_end_plain_preedit_text = is_commit ? U8String {} : preedit_text;
    m_flow_.document_range_end_plain_inserted_text = is_commit ? U8String {} : inserted_text;

    coreSetCursorPositionInternal(new_end);
    coreSetSelectionInternal({new_end, new_end});
    coreInvalidateContentMetrics(updated_anchor.start.line);
    coreEnsureCursorVisible();
    return result;
  }

  void CompositionController::setPreeditRange(const TextRange& range) {
    if (!coreHasDocument() || coreReadOnly()) return;

    TextPosition previous_cursor = coreCursor();

    TextRange safe_range = coreClampDocumentRange(range);
    if (safe_range.start == safe_range.end) return;

    if (hasPreedit() && m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange current_range = currentPreeditRange();
      if (current_range == safe_range) {
        TextPosition target_cursor = previous_cursor;
        coreSetCursorPositionInternal(target_cursor);
        coreSetSelectionInternal({target_cursor, target_cursor});
        coreEnsureCursorVisible();
        return;
      }
    }

    if (hasPreedit()) {
      commitPreeditText("", true);
    }

    U8String text = coreDocumentText(safe_range);
    m_composition_.start_position = safe_range.start;
    m_composition_.anchor_range = safe_range;
    m_composition_.original_text = text;
    m_composition_.preedit_text = text;
    m_composition_.preedit_columns = StrUtil::utf16Length(text);
    m_composition_.kind = CompositionKind::DOCUMENT_RANGE;
    m_flow_.preedit_text_in_document = false;

    TextPosition target_cursor = previous_cursor;
    coreSetCursorPositionInternal(target_cursor);
    coreSetSelectionInternal({target_cursor, target_cursor});
    coreEnsureCursorVisible();
    LOGD("CompositionController::setPreeditRange: %s -> %s, text='%s'",
         safe_range.start.dump().c_str(), safe_range.end.dump().c_str(), text.c_str());
  }

  void CompositionController::beginPreeditText() {
    if (!coreHasDocument() || coreReadOnly()) return;

    if (hasPreedit()) {
      cancelPreeditText();
    }

    if (coreHasSelection() && !coreIsLinkedEditingActive()) {
      coreDeleteSelectionForComposition();
    }

    m_composition_.start_position = coreCursor();
    if (coreIsLinkedEditingActive() && coreHasSelection()) {
      TextRange selection = coreSelection();
      m_composition_.start_position = selection.end < selection.start ? selection.end : selection.start;
    }
    m_composition_.anchor_range = {m_composition_.start_position, m_composition_.start_position};
    m_composition_.original_text.clear();
    m_composition_.preedit_text.clear();
    m_composition_.preedit_columns = 0;
    m_composition_.kind = CompositionKind::PREEDIT_TEXT;
    m_flow_.preedit_text_in_document = false;

    LOGD("CompositionController::beginPreeditText, pos = %s", coreCursor().dump().c_str());
  }

  TextEditResult CompositionController::setPreeditText(const U8String& text) {
    if (!coreHasDocument() || coreReadOnly()) return {};

    if (!hasPreedit()) {
      beginPreeditText();
    }

    TextPosition cursor_before = coreCursor();
    TextRange replacement_range = currentPreeditRange();
    U8String replaced_text = m_composition_.preedit_text;

    if (m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange preedit_range = currentPreeditRange();
      m_flow_.preedit_replaces_document_range = true;
      m_flow_.preedit_replaced_range = preedit_range;
      m_flow_.preedit_replaced_text = m_composition_.preedit_text;
      coreDeleteDocumentRange(preedit_range);
      coreSetRawCursorPosition(m_composition_.start_position);
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_flow_.preedit_text_in_document = false;
    }

    if (hasMidDocumentRangePreedit()) {
      TextEditResult plain_edit = applyDocumentRangePlainEdit(text);
      if (plain_edit.contentChanged() || text.empty() || StrUtil::utf16Length(text) <= 2) {
        return plain_edit;
      }
    }

    if (hasEndDocumentRangePreedit()) {
      TextEditResult plain_edit = applyDocumentRangeEndPlainEdit(text, false);
      if (plain_edit.contentChanged() || text.empty()) {
        return plain_edit;
      }
    }

    if (coreIsLinkedEditingActive()) {
      m_composition_.preedit_text = text;
      m_composition_.preedit_columns = StrUtil::utf16Length(text);
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {
        m_composition_.start_position,
        corePositionAfterInsert(m_composition_.start_position, text)
      };
      m_flow_.preedit_text_in_document = false;
      TextPosition new_pos = corePositionAfterInsert(m_composition_.start_position, text);
      coreSetCursorPositionInternal(new_pos);
      coreEnsureCursorVisible();
      LOGD("CompositionController::setPreeditText(linked), text = %s, columns = %zu",
           text.c_str(), m_composition_.preedit_columns);
      return {};
    }

    removePreeditText();

    if (!text.empty()) {
      coreInsertDocumentText(m_composition_.start_position, text);
      size_t new_columns = StrUtil::utf16Length(text);
      m_composition_.preedit_text = text;
      m_composition_.preedit_columns = new_columns;
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {
        m_composition_.start_position,
        corePositionAfterInsert(m_composition_.start_position, text)
      };
      m_flow_.preedit_text_in_document = true;
      TextPosition new_pos = corePositionAfterInsert(m_composition_.start_position, text);
      coreSetCursorPositionInternal(new_pos);
    } else {
      m_composition_.preedit_text.clear();
      m_composition_.preedit_columns = 0;
      m_composition_.kind = CompositionKind::PREEDIT_TEXT;
      m_composition_.anchor_range = {m_composition_.start_position, m_composition_.start_position};
      m_flow_.preedit_text_in_document = false;
      coreSetCursorPositionInternal(m_composition_.start_position);
    }
    coreInvalidateContentMetrics(m_composition_.start_position.line);
    coreEnsureCursorVisible();
    LOGD("CompositionController::setPreeditText, text = %s, columns = %zu",
         text.c_str(), m_composition_.preedit_columns);
    TextEditResult result;
    if (replaced_text != text) {
      result.markHandled(replacement_range.isCollapsed()
                         ? TextChangeKind::INSERTION
                         : (text.empty() ? TextChangeKind::DELETION : TextChangeKind::REPLACEMENT));
      result.cursor_before = cursor_before;
      result.cursor_after = coreCursor();
      result.changes.push_back({replacement_range, replaced_text, text});
    }
    return result;
  }

  TextEditResult CompositionController::finishPreeditText() {
    if (!coreHasDocument() || coreReadOnly()) return {};
    if (!hasPreedit()) return {};
    if (hasPreedit()
        && m_composition_.kind == CompositionKind::DOCUMENT_RANGE
        && !m_flow_.preedit_text_in_document
        && !m_flow_.preedit_replaces_document_range) {
      TextPosition previous_cursor = coreCursor();
      size_t preedit_start_line = m_composition_.start_position.line;
      resetCompositionState();
      coreSetCursorPositionInternal(previous_cursor);
      coreInvalidateContentMetrics(preedit_start_line);
      coreEnsureCursorVisible();
      TextEditResult result;
      result.cursor_before = previous_cursor;
      result.cursor_after = previous_cursor;
      return result;
    }
    return commitPreeditText("", true);
  }

  TextEditResult CompositionController::commitPreeditText(const U8String& committed_text,
                                                            bool empty_text_keeps_preedit) {
    if (!coreHasDocument() || coreReadOnly()) return {};

    if (!hasPreedit()) {
      if (!committed_text.empty()) {
        clearCandidateCommitWindow();
        return coreInsertText(committed_text);
      }
      return {};
    }

    TextRange preedit_range = currentPreeditRange();
    TextPosition previous_cursor = coreCursor();
    U8String final_text = committed_text.empty() && empty_text_keeps_preedit
        ? m_composition_.preedit_text
        : committed_text;
    size_t preedit_start_line = m_composition_.start_position.line;
    if (m_composition_.kind == CompositionKind::DOCUMENT_RANGE) {
      TextRange commit_range = m_composition_.anchor_range;
      U8String original_text = m_composition_.original_text;
      U8String current_text = coreDocumentText(commit_range);
      resetCompositionState();
      coreInvalidateContentMetrics(preedit_start_line);
      coreSetCursorPositionInternal(previous_cursor);

      if ((committed_text.empty() && empty_text_keeps_preedit) || committed_text == current_text) {
        if (!committed_text.empty()) {
          openCandidateCommitWindow(commit_range, committed_text, true);
        }
        coreEnsureCursorVisible();
        TextEditResult edit_result;
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
        return edit_result;
      }
      if (current_text != original_text) {
        coreEnsureCursorVisible();
        TextEditResult edit_result;
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
        return edit_result;
      }
      auto edit_result = coreApplyEdit(commit_range, committed_text);
      TextRange candidate_range {
        commit_range.start,
        corePositionAfterInsert(commit_range.start, committed_text)
      };
      openCandidateCommitWindow(candidate_range, committed_text, true);
      coreEnsureCursorVisible();
      return edit_result;
    }

    bool replaces_document_range = m_flow_.preedit_replaces_document_range;
    TextRange replaced_range = m_flow_.preedit_replaced_range;
    U8String replaced_text = m_flow_.preedit_replaced_text;
    bool should_restore_cursor = committed_text.empty()
                              && !replaces_document_range
                              && m_flow_.preedit_text_in_document
                              && preedit_range.contains(previous_cursor);
    TextPosition candidate_start = replaces_document_range ? replaced_range.start : m_composition_.start_position;
    TextRange candidate_range {candidate_start, corePositionAfterInsert(candidate_start, final_text)};
    if (replaces_document_range
        && coreIsDocumentRangeReadable(candidate_range)
        && coreDocumentText(candidate_range) == final_text) {
      TextEditResult edit_result;
      edit_result.cursor_before = previous_cursor;
      TextPosition cursor_after = final_text != replaced_text ? candidate_range.end : previous_cursor;
      if (final_text != replaced_text) {
        coreRecordUndoAction(replaced_range,
                             replaced_text,
                             final_text,
                             replaced_range.start,
                             cursor_after,
                             coreHasSelection(),
                             coreSelection());
      }
      resetCompositionState();
      coreSetSelectionInternal({cursor_after, cursor_after});
      coreInvalidateContentMetrics(preedit_start_line);
      edit_result.cursor_after = cursor_after;
      openCandidateCommitWindow(candidate_range, final_text, !committed_text.empty());
      coreEnsureCursorVisible();
      LOGD("CompositionController::commitPreeditText, cursor = %s", coreCursor().dump().c_str());
      return edit_result;
    }

    removePreeditText();
    if (replaces_document_range) {
      coreInsertDocumentText(replaced_range.start, replaced_text);
      coreSetRawCursorPosition(replaced_range.start);
    }

    resetCompositionState();

    TextEditResult edit_result;
    if (replaces_document_range) {
      if (final_text != replaced_text) {
        edit_result = coreApplyEdit(replaced_range, final_text);
      } else {
        coreSetCursorPositionInternal(previous_cursor);
        coreInvalidateContentMetrics(preedit_start_line);
        edit_result.cursor_before = previous_cursor;
        edit_result.cursor_after = previous_cursor;
      }
    } else if (!final_text.empty()) {
      edit_result = coreInsertText(final_text);
      if (should_restore_cursor) {
        coreSetCursorPositionInternal(previous_cursor);
        edit_result.cursor_after = previous_cursor;
      }
    }

    openCandidateCommitWindow(candidate_range, final_text, !committed_text.empty());
    coreEnsureCursorVisible();
    LOGD("CompositionController::commitPreeditText, cursor = %s", coreCursor().dump().c_str());
    return edit_result;
  }

  void CompositionController::cancelPreeditText() {
    if (!hasPreedit()) return;

    size_t preedit_start_line = m_composition_.start_position.line;
    bool replaces_document_range = m_flow_.preedit_replaces_document_range;
    TextRange replaced_range = m_flow_.preedit_replaced_range;
    U8String replaced_text = m_flow_.preedit_replaced_text;

    removePreeditText();
    if (replaces_document_range) {
      coreInsertDocumentText(replaced_range.start, replaced_text);
      coreSetRawCursorPosition(replaced_range.start);
    }

    resetCompositionState();
    clearCandidateCommitWindow();

    coreInvalidateContentMetrics(preedit_start_line);
    coreEnsureCursorVisible();
    LOGD("CompositionController::cancelPreeditText, cursor = %s", coreCursor().dump().c_str());
  }

  void CompositionController::removePreeditText() {
    if (!hasPreedit() || m_composition_.preedit_columns == 0) return;
    if (m_composition_.kind != CompositionKind::PREEDIT_TEXT) return;
    if (!m_flow_.preedit_text_in_document) return;
    if (!coreHasDocument()) return;

    TextRange preedit_text_range = {
      m_composition_.start_position,
      {m_composition_.start_position.line, m_composition_.start_position.column + m_composition_.preedit_columns}
    };
    coreDeleteDocumentRange(preedit_text_range);
    coreSetRawCursorPosition(m_composition_.start_position);
    m_flow_.preedit_text_in_document = false;
  }

  TextEditResult CompositionController::applyDocumentRangePlainEdit(const U8String& text) {
    if (!hasMidDocumentRangePreedit()) {
      return {};
    }
    const TextPosition cursor = coreCursor();
    const size_t preedit_start_line = m_composition_.start_position.line;
    if (text.empty()) {
      resetCompositionState();
      clearCandidateCommitWindow();
      coreSetCursorPositionInternal(cursor);
      coreInvalidateContentMetrics(preedit_start_line);
      return {};
    }
    TextRange edit_range {cursor, cursor};
    U8String replacement = text;
    bool has_local_edit = resolveDocumentRangePlainEdit(text, edit_range, replacement);
    if (!has_local_edit && StrUtil::utf16Length(text) <= 2) {
      edit_range = {cursor, cursor};
      replacement = text;
      has_local_edit = true;
    }
    if (!has_local_edit) {
      return {};
    }

    resetCompositionState();
    clearCandidateCommitWindow();
    coreSetCursorPositionInternal(cursor);
    coreInvalidateContentMetrics(preedit_start_line);
    TextEditResult result = coreApplyEdit(edit_range, replacement);
    beginPlainLatinInputLock(text);
    return result;
  }

  TextEditResult CompositionController::applyDocumentRangeEndPlainEdit(const U8String& text,
                                                                       bool is_commit) {
    if (!hasEndDocumentRangePreedit()) {
      return {};
    }
    const U8String previous_preedit = m_flow_.document_range_end_plain_preedit_text;
    const U8String previous_inserted = m_flow_.document_range_end_plain_inserted_text;
    if (!previous_preedit.empty() || !previous_inserted.empty()) {
      if (is_commit && !text.empty() && (text == previous_preedit || text == previous_inserted)) {
        m_flow_.document_range_end_plain_preedit_text.clear();
        m_flow_.document_range_end_plain_inserted_text.clear();
        return {};
      }

      TextRange anchor = m_composition_.anchor_range;
      U8String current_text = coreDocumentText(anchor);
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
        if (!resolveDocumentRangeInsertedText(text, replacement)) {
          return {};
        }
        return applyDocumentRangeEndReplacement({anchor.end, anchor.end},
                                                replacement,
                                                {},
                                                {},
                                                true);
      }

      U8String inserted_text = text_includes_base ? text.substr(base_text.size()) : text;
      if (inserted_text == previous_inserted) {
        if (is_commit) {
          m_flow_.document_range_end_plain_preedit_text.clear();
          m_flow_.document_range_end_plain_inserted_text.clear();
        } else {
          m_flow_.document_range_end_plain_preedit_text = text;
        }
        return {};
      }
      if (!previous_inserted.empty()
          && inserted_text.size() > previous_inserted.size()
          && inserted_text.rfind(previous_inserted, 0) == 0) {
        U8String replacement = inserted_text.substr(previous_inserted.size());
        return applyDocumentRangeEndReplacement({anchor.end, anchor.end},
                                                replacement,
                                                text,
                                                inserted_text,
                                                is_commit);
      }
      size_t previous_columns = StrUtil::utf16Length(previous_inserted);
      if (anchor.end.column < previous_columns) {
        return {};
      }
      TextRange previous_range {
        {anchor.end.line, anchor.end.column - static_cast<uint32_t>(previous_columns)},
        anchor.end
      };
      return applyDocumentRangeEndReplacement(previous_range,
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
    if (!resolveDocumentRangeInsertedText(text, replacement)) {
      return {};
    }

    TextRange anchor = m_composition_.anchor_range;
    return applyDocumentRangeEndReplacement({anchor.end, anchor.end},
                                            replacement,
                                            text,
                                            replacement,
                                            is_commit);
  }

  TextEditResult CompositionController::applyPlainLatinInputLockEdit(const U8String& text,
                                                                     bool is_commit) {
    if (text.empty()) {
      m_flow_.plain_latin_preedit_text.clear();
      return {};
    }

    U8String replacement = text;
    const U8String previous = m_flow_.plain_latin_preedit_text;
    if (!previous.empty()) {
      if (text == previous && is_commit) {
        m_flow_.plain_latin_preedit_text.clear();
        return {};
      }
      if (text.rfind(previous, 0) == 0) {
        replacement = text.substr(previous.size());
      } else if (previous.rfind(text, 0) == 0) {
        size_t delete_columns = StrUtil::utf16Length(previous.substr(text.size()));
        TextPosition cursor = coreCursor();
        if (cursor.column >= delete_columns) {
          TextRange delete_range {
            {cursor.line, cursor.column - static_cast<uint32_t>(delete_columns)},
            cursor
          };
          TextEditResult result = coreApplyEdit(delete_range, "");
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

    TextEditResult result = coreInsertText(replacement);
    beginPlainLatinInputLock(is_commit ? U8String {} : text);
    return result;
  }

  bool CompositionController::trySuppressCandidateCommit(const U8String& text) {
    if (!m_flow_.has_candidate_commit_window || hasPreedit()) {
      return false;
    }
    if (!isInlineCandidateText(text)) {
      if (!text.empty()) {
        clearCandidateCommitWindow();
      }
      return false;
    }
    const U8String& committed_text = m_flow_.candidate_committed_text;
    if (text == committed_text && m_flow_.suppress_candidate_exact_range) {
      return true;
    }
    if (!m_flow_.candidate_deleted_to_prefix) {
      return false;
    }

    TextPosition start = m_flow_.candidate_committed_range.start;
    TextPosition cursor = coreCursor();
    if (cursor < start || cursor.line != start.line) {
      clearCandidateCommitWindow();
      return false;
    }
    TextRange prefix_range {start, cursor};
    U8String current_text;
    if (!(prefix_range.start == prefix_range.end)) {
      if (!coreIsDocumentRangeReadable(prefix_range)) {
        clearCandidateCommitWindow();
        return false;
      }
      current_text = coreDocumentText(prefix_range);
    }
    if (committed_text.rfind(current_text, 0) == 0
        && (committed_text.rfind(text, 0) == 0 || current_text.rfind(text, 0) == 0)) {
      return true;
    }
    clearCandidateCommitWindow();
    return false;
  }

  bool CompositionController::trySuppressCandidateMark(const TextRange& range) {
    if (!m_flow_.has_candidate_commit_window
        || !m_flow_.suppress_candidate_exact_range
        || hasPreedit()) {
      return false;
    }
    if (range.start == range.end) {
      return false;
    }
    if (!(range == m_flow_.candidate_committed_range)) {
      return false;
    }
    if (!coreIsDocumentRangeReadable(range)) {
      clearCandidateCommitWindow();
      return false;
    }
    if (coreDocumentText(range) == m_flow_.candidate_committed_text) {
      return true;
    }
    clearCandidateCommitWindow();
    return false;
  }

  void CompositionController::updateCandidateWindowAfterDelete() {
    if (!m_flow_.has_candidate_commit_window || hasPreedit()) {
      return;
    }
    TextPosition start = m_flow_.candidate_committed_range.start;
    TextPosition cursor = coreCursor();
    if (cursor == start) {
      markCandidateDeletedToPrefix();
      return;
    }
    if (cursor < start) {
      clearCandidateCommitWindow();
      return;
    }
    if (cursor.line != start.line || m_flow_.candidate_committed_range.end < cursor) {
      clearCandidateCommitWindow();
      return;
    }

    TextRange prefix_range {start, cursor};
    if (!coreIsDocumentRangeReadable(prefix_range)) {
      clearCandidateCommitWindow();
      return;
    }
    U8String current_text = coreDocumentText(prefix_range);
    const U8String& committed_text = m_flow_.candidate_committed_text;
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

  void CompositionController::handleUpdatePreedit(ImeActionResult& result,
                                                  const U8String& text,
                                                  ImeScriptClass script_class) {
    if (shouldUsePlainLatinInputLock(text, script_class, false)) {
      mergeEditResult(result, applyPlainLatinInputLockEdit(text, false));
      return;
    }
    if (m_flow_.plain_latin_input_lock && !text.empty()) {
      clearPlainLatinInputLock();
    }
    if (text.empty() && !hasPreedit()) {
      return;
    }
    if (trySuppressCandidateCommit(text)) {
      return;
    }
    clearCandidateCommitWindow();
    mergeEditResult(result, setPreeditText(text));
  }

  void CompositionController::handleCommitText(ImeActionResult& result,
                                               const U8String& text,
                                               ImeScriptClass script_class) {
    if (shouldUsePlainLatinInputLock(text, script_class, true)) {
      mergeEditResult(result, applyPlainLatinInputLockEdit(text, true));
      return;
    }
    if (m_flow_.plain_latin_input_lock && !text.empty()) {
      clearPlainLatinInputLock();
    }
    if (trySuppressCandidateCommit(text)) {
      return;
    }
    if (hasEndDocumentRangePreedit()
        && !text.empty()
        && text == m_flow_.document_range_end_plain_preedit_text) {
      m_flow_.document_range_end_plain_preedit_text.clear();
      m_flow_.document_range_end_plain_inserted_text.clear();
      return;
    }
    if (hasEndDocumentRangePreedit()
        && !text.empty()
        && (!m_flow_.document_range_end_plain_inserted_text.empty() || StrUtil::utf16Length(text) <= 1)) {
      TextEditResult plain_edit = applyDocumentRangeEndPlainEdit(text, true);
      if (plain_edit.contentChanged()) {
        mergeEditResult(result, plain_edit);
        return;
      }
    }
    if (hasMidDocumentRangePreedit()) {
      TextRange plain_range;
      U8String plain_replacement;
      bool looks_like_plain_edit = resolveDocumentRangePlainEdit(
          text,
          plain_range,
          plain_replacement);
      if (looks_like_plain_edit || StrUtil::utf16Length(text) <= 1) {
        mergeEditResult(result, applyDocumentRangePlainEdit(text));
        return;
      }
    }
    mergeEditResult(result, commitPreeditText(text));
  }

  void CompositionController::handleFinishPreedit(ImeActionResult& result) {
    mergeEditResult(result, finishPreeditText());
  }

  void CompositionController::handleCancelPreedit() {
    clearCandidateCommitWindow();
    cancelPreeditText();
  }

  void CompositionController::handleMarkDocumentRange(const TextRange& range) {
    clearPlainLatinInputLock();
    TextRange safe_range = coreClampDocumentRange(range);
    if (trySuppressCandidateMark(safe_range)) {
      return;
    }
    clearCandidateCommitWindow();
    setPreeditRange(safe_range);
  }

  bool CompositionController::tryDeleteFromDocumentRangeEnd(ImeActionResult& result,
                                                            size_t before_length,
                                                            size_t after_length,
                                                            ImeTextUnit text_unit) {
    if (!hasPreedit()
        || m_composition_.kind != CompositionKind::DOCUMENT_RANGE
        || m_flow_.preedit_text_in_document
        || m_flow_.preedit_replaces_document_range) {
      return false;
    }
    TextRange anchor = m_composition_.anchor_range;
    TextPosition cursor = coreCursor();
    if (cursor != anchor.end || anchor.start.line != anchor.end.line || cursor.line != anchor.start.line) {
      return false;
    }
    if (before_length == 0 && after_length == 0) {
      return true;
    }

    U8String current_text = coreDocumentText(anchor);
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
    U8String deleted_text = coreDocumentText(delete_range);
    coreDeleteDocumentRange(delete_range);

    TextPosition new_cursor = delete_range.start;
    const size_t deleted_columns = delete_end_offset - delete_start_offset;
    TextRange updated_anchor {
      anchor.start,
      {anchor.end.line, anchor.end.column - static_cast<uint32_t>(deleted_columns)}
    };

    TextEditResult edit_result;
    edit_result.markHandled(TextChangeKind::DELETION);
    edit_result.cursor_before = cursor;
    edit_result.cursor_after = new_cursor;
    edit_result.changes.push_back({delete_range, deleted_text, ""});
    mergeEditResult(result, edit_result);

    if (updated_anchor.start == updated_anchor.end) {
      resetCompositionState();
      clearCandidateCommitWindow();
      coreSetCursorPositionInternal(new_cursor);
      coreSetSelectionInternal({new_cursor, new_cursor});
      coreInvalidateContentMetrics(anchor.start.line);
      coreEnsureCursorVisible();
      return true;
    }

    m_composition_.anchor_range = updated_anchor;
    m_composition_.start_position = updated_anchor.start;
    m_composition_.original_text = coreDocumentText(updated_anchor);
    m_composition_.preedit_text = m_composition_.original_text;
    m_composition_.preedit_columns = StrUtil::utf16Length(m_composition_.preedit_text);
    coreSetCursorPositionInternal(new_cursor);
    coreSetSelectionInternal({new_cursor, new_cursor});
    coreInvalidateContentMetrics(anchor.start.line);
    coreEnsureCursorVisible();
    return true;
  }

  void CompositionController::handleDelete(ImeActionResult& result,
                                           size_t before_length,
                                           size_t after_length,
                                           ImeTextUnit text_unit) {
    if (tryDeleteFromDocumentRangeEnd(result, before_length, after_length, text_unit)) {
      return;
    }
    bool keep_plain_latin_input = hasMidDocumentRangePreedit() || m_flow_.plain_latin_input_lock;
    U8String plain_latin_text = m_flow_.plain_latin_preedit_text;
    if (coreHasSelection()) {
      mergeEditResult(result, coreBackspace());
      updateCandidateWindowAfterDelete();
      if (keep_plain_latin_input) {
        beginPlainLatinInputLock({});
      }
      return;
    }
    const bool delete_code_points = text_unit == ImeTextUnit::CODE_POINT;
    for (size_t i = 0; i < before_length; ++i) {
      mergeEditResult(result, delete_code_points ? coreDeleteCodePointBackward() : coreBackspace());
    }
    for (size_t i = 0; i < after_length; ++i) {
      mergeEditResult(result, delete_code_points ? coreDeleteCodePointForward() : coreDeleteForward());
    }
    updateCandidateWindowAfterDelete();
    if (keep_plain_latin_input) {
      beginPlainLatinInputLock(plain_latin_text);
      trimPlainLatinInputLock(before_length);
    }
  }

  void CompositionController::handleSelectionChanged(const TextRange& range) {
    clearPlainLatinInputLock();
    clearCandidateCommitWindow();
    if (canMoveSelectionInsidePreedit(range)) {
      if (range.start == range.end) {
        coreSetCursorPositionInternal(range.start);
        coreSetSelectionInternal({range.start, range.start});
      } else {
        coreSetSelectionInternal(range);
      }
      coreEnsureCursorVisible();
      return;
    }
    if (hasPreedit()) {
      commitPreeditText("", true);
    }
    if (range.start == range.end) {
      coreSetCursorPositionInternal(range.start);
      coreSetSelectionInternal({range.start, range.start});
    } else {
      coreSetSelectionInternal(range);
    }
  }

  void CompositionController::handleCursorChanged(const TextPosition& cursor) {
    clearPlainLatinInputLock();
    clearCandidateCommitWindow();
    TextRange cursor_range {cursor, cursor};
    if (canMoveSelectionInsidePreedit(cursor_range)) {
      coreSetCursorPositionInternal(cursor);
      coreSetSelectionInternal({cursor, cursor});
      coreEnsureCursorVisible();
      return;
    }
    if (hasPreedit() && cursor != coreCursor()) {
      commitPreeditText("", true);
    }
    coreSetCursorPositionInternal(cursor);
    coreSetSelectionInternal({cursor, cursor});
  }

  void CompositionController::handleReplaceText(ImeActionResult& result,
                                                const TextRange& range,
                                                const U8String& text) {
    clearCandidateCommitWindow();
    if (hasPreedit()) {
      mergeEditResult(result, finishPreeditText());
    }
    TextRange safe_range = coreClampDocumentRange(range);
    mergeEditResult(result, coreApplyEdit(safe_range, text));
  }

}
