#include <sweeteditor/undo.h>

namespace NS_SWEETEDITOR {

  bool EditAction::canMergeWith(const EditAction& next) const {
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
      next.timestamp - timestamp).count();
    if (elapsed > 500) return false;
    if (next.had_selection) return false;

    if (old_text.empty() && next.old_text.empty()
        && !new_text.empty() && next.new_text.size() == 1
        && next.new_text[0] != '\n' && next.new_text[0] != '\r') {
      if (next.range.start == cursor_after) {
        return true;
      }
    }

    if (new_text.empty() && next.new_text.empty()
        && !old_text.empty() && next.old_text.size() == 1) {
      if (next.range.end == range.start) {
        return true;
      }
      if (next.range.start == range.start) {
        return true;
      }
    }

    return false;
  }

  void EditAction::mergeWith(const EditAction& next) {
    if (old_text.empty() && next.old_text.empty()) {
      new_text += next.new_text;
      cursor_after = next.cursor_after;
      timestamp = next.timestamp;
    } else if (new_text.empty() && next.new_text.empty()) {
      if (next.range.end == range.start) {
        old_text = next.old_text + old_text;
        range.start = next.range.start;
        cursor_before = next.cursor_before;
      } else {
        old_text += next.old_text;
        range.end = next.range.end;
      }
      cursor_after = next.cursor_after;
      timestamp = next.timestamp;
    }
  }

  TextPosition UndoEntry::cursorBefore() const {
    return is_compound ? compound.cursor_before : single.cursor_before;
  }

  TextPosition UndoEntry::cursorAfter() const {
    return is_compound ? compound.cursor_after : single.cursor_after;
  }

  bool UndoEntry::hadSelection() const {
    return is_compound ? compound.had_selection : single.had_selection;
  }

  TextRange UndoEntry::selectionBefore() const {
    return is_compound ? compound.selection_before : single.selection_before;
  }

  UndoManager::UndoManager(size_t max_stack_size)
    : m_max_stack_size_(max_stack_size) {}

  void UndoManager::pushAction(EditAction action) {
    if (m_group_depth_ > 0) {
      m_group_actions_.push_back(std::move(action));
      return;
    }

    m_redo_stack_.clear();

    if (!m_undo_stack_.empty() && !m_undo_stack_.back().is_compound) {
      if (m_undo_stack_.back().single.canMergeWith(action)) {
        m_undo_stack_.back().single.mergeWith(action);
        return;
      }
    }

    UndoEntry entry;
    entry.is_compound = false;
    entry.single = std::move(action);
    m_undo_stack_.push_back(std::move(entry));

    if (m_undo_stack_.size() > m_max_stack_size_) {
      m_undo_stack_.erase(m_undo_stack_.begin());
    }
  }

  void UndoManager::beginGroup(TextPosition cursor_before, bool had_selection, TextRange selection_before) {
    if (m_group_depth_ == 0) {
      m_group_actions_.clear();
      m_group_cursor_before_ = cursor_before;
      m_group_had_selection_ = had_selection;
      m_group_selection_before_ = selection_before;
    }
    m_group_depth_++;
  }

  void UndoManager::endGroup(TextPosition cursor_after) {
    if (m_group_depth_ == 0) return;
    m_group_depth_--;
    if (m_group_depth_ > 0) return;

    if (m_group_actions_.empty()) return;

    m_redo_stack_.clear();

    UndoEntry entry;
    entry.is_compound = true;
    entry.compound.actions = std::move(m_group_actions_);
    entry.compound.cursor_before = m_group_cursor_before_;
    entry.compound.cursor_after = cursor_after;
    entry.compound.had_selection = m_group_had_selection_;
    entry.compound.selection_before = m_group_selection_before_;
    m_undo_stack_.push_back(std::move(entry));

    if (m_undo_stack_.size() > m_max_stack_size_) {
      m_undo_stack_.erase(m_undo_stack_.begin());
    }
  }

  bool UndoManager::isInGroup() const {
    return m_group_depth_ > 0;
  }

  const UndoEntry* UndoManager::undo() {
    if (m_undo_stack_.empty()) return nullptr;
    m_redo_stack_.push_back(std::move(m_undo_stack_.back()));
    m_undo_stack_.pop_back();
    return &m_redo_stack_.back();
  }

  const UndoEntry* UndoManager::redo() {
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

  void UndoManager::clear() {
    m_undo_stack_.clear();
    m_redo_stack_.clear();
    m_group_depth_ = 0;
    m_group_actions_.clear();
  }

  void UndoManager::setMaxStackSize(size_t size) {
    m_max_stack_size_ = size;
  }

  size_t UndoManager::getMaxStackSize() const {
    return m_max_stack_size_;
  }
}
