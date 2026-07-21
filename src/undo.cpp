#include <sweeteditor/undo.h>

namespace NS_SWEETEDITOR {
  namespace {
    bool isSingleInsertion(const HistoryEntry& entry) {
      return entry.redo_replacements.size() == 1
          && entry.undo_replacements.size() == 1
          && entry.redo_replacements[0].range.isCollapsed()
          && !entry.redo_replacements[0].text.empty()
          && entry.undo_replacements[0].text.empty();
    }

    bool isSingleDeletion(const HistoryEntry& entry) {
      return entry.redo_replacements.size() == 1
          && entry.undo_replacements.size() == 1
          && !entry.redo_replacements[0].range.isCollapsed()
          && entry.redo_replacements[0].text.empty()
          && !entry.undo_replacements[0].text.empty();
    }
  }

  bool HistoryEntry::canMergeWith(const HistoryEntry& next) const {
    const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        next.timestamp - timestamp).count();
    if (!allows_merge
        || !next.allows_merge
        || elapsed > 500
        || caret_before.hasSelection()
        || next.caret_before.hasSelection()) {
      return false;
    }

    if (isSingleInsertion(*this) && isSingleInsertion(next)) {
      const auto& next_text = next.redo_replacements[0].text;
      return next_text.size() == 1
          && next_text[0] != '\n'
          && next_text[0] != '\r'
          && next.redo_replacements[0].range.start == caret_after.active;
    }

    if (isSingleDeletion(*this) && isSingleDeletion(next)) {
      const auto& next_text = next.undo_replacements[0].text;
      if (next_text.size() != 1 || next_text[0] == '\n' || next_text[0] == '\r') return false;
      const TextRange& range = redo_replacements[0].range;
      const TextRange& next_range = next.redo_replacements[0].range;
      return next_range.end == range.start || next_range.start == range.start;
    }

    return false;
  }

  void HistoryEntry::mergeWith(const HistoryEntry& next) {
    auto& redo = redo_replacements[0];
    auto& undo = undo_replacements[0];
    const auto& next_redo = next.redo_replacements[0];
    const auto& next_undo = next.undo_replacements[0];

    if (isSingleInsertion(*this) && isSingleInsertion(next)) {
      redo.text += next_redo.text;
      undo.range.end = next_undo.range.end;
    } else if (next_redo.range.end == redo.range.start) {
      redo.range.start = next_redo.range.start;
      undo.range = next_undo.range;
      undo.text = next_undo.text + undo.text;
    } else {
      ++redo.range.end.column;
      undo.text += next_undo.text;
    }

    caret_after = next.caret_after;
    timestamp = next.timestamp;
  }

  UndoManager::UndoManager(size_t max_stack_size)
    : m_max_stack_size_(max_stack_size) {}

  void UndoManager::pushEntry(HistoryEntry entry) {
    m_redo_stack_.clear();

    if (!m_undo_stack_.empty() && m_undo_stack_.back().canMergeWith(entry)) {
      m_undo_stack_.back().mergeWith(entry);
      return;
    }

    m_undo_stack_.push_back(std::move(entry));
    if (m_undo_stack_.size() > m_max_stack_size_) {
      m_undo_stack_.erase(m_undo_stack_.begin());
    }
  }

  const HistoryEntry* UndoManager::undo() {
    if (m_undo_stack_.empty()) return nullptr;
    m_redo_stack_.push_back(std::move(m_undo_stack_.back()));
    m_undo_stack_.pop_back();
    return &m_redo_stack_.back();
  }

  const HistoryEntry* UndoManager::redo() {
    if (m_redo_stack_.empty()) return nullptr;
    m_undo_stack_.push_back(std::move(m_redo_stack_.back()));
    m_redo_stack_.pop_back();
    return &m_undo_stack_.back();
  }

  bool UndoManager::canUndo() const {
    return !m_undo_stack_.empty();
  }

  bool UndoManager::canRedo() const {
    return !m_redo_stack_.empty();
  }

  void UndoManager::breakMergeChain() {
    if (!m_undo_stack_.empty()) {
      m_undo_stack_.back().allows_merge = false;
    }
  }

  void UndoManager::clear() {
    m_undo_stack_.clear();
    m_redo_stack_.clear();
  }

  void UndoManager::setMaxStackSize(size_t size) {
    m_max_stack_size_ = size;
  }

  size_t UndoManager::getMaxStackSize() const {
    return m_max_stack_size_;
  }
}
