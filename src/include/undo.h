//
// Created by Scave on 2026/2/27.
//
#ifndef SWEETEDITOR_UNDO_MANAGER_H
#define SWEETEDITOR_UNDO_MANAGER_H

#include <foundation.h>
#include <chrono>

namespace NS_SWEETEDITOR {
  /// Record for one edit action
  struct EditAction {
    /// Text range before edit (the region deleted/replaced)
    TextRange range;
    /// Old text that was deleted/replaced (used for undo)
    U8String old_text;
    /// New text after insert/replace (used for redo)
    U8String new_text;
    /// Cursor position before edit
    TextPosition cursor_before;
    /// Cursor position after edit
    TextPosition cursor_after;
    /// Whether there was a selection before edit
    bool had_selection {false};
    /// Selection range before edit
    TextRange selection_before;
    /// Action timestamp (used to decide merge)
    std::chrono::steady_clock::time_point timestamp;

    /// Check whether this action can merge with the next one (continuous single-char input/delete)
    bool canMergeWith(const EditAction& next) const {
      // Only merge pure insert or pure delete
      auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        next.timestamp - timestamp).count();
      if (elapsed > 500) return false;
      // Do not merge if next action has selection
      if (next.had_selection) return false;

      // Continuous single-character insertion
      if (old_text.empty() && next.old_text.empty()
          && !new_text.empty() && next.new_text.size() == 1
          && next.new_text[0] != '\n' && next.new_text[0] != '\r') {
        // Insert position is right after previous insertion end
        if (next.range.start == cursor_after) {
          return true;
        }
      }

      // Continuous single-character deletion (backspace)
      if (new_text.empty() && next.new_text.empty()
          && !old_text.empty() && next.old_text.size() == 1) {
        // backspace: next deletion is right before previous deletion start
        if (next.range.end == range.start) {
          return true;
        }
        // delete forward: next deletion starts at same position
        if (next.range.start == range.start) {
          return true;
        }
      }

      return false;
    }

    /// Merge next action into current action
    void mergeWith(const EditAction& next) {
      if (old_text.empty() && next.old_text.empty()) {
        // Continuous insert: extend new_text
        new_text += next.new_text;
        cursor_after = next.cursor_after;
        timestamp = next.timestamp;
      } else if (new_text.empty() && next.new_text.empty()) {
        // Continuous delete
        if (next.range.end == range.start) {
          // backspace: extend backward
          old_text = next.old_text + old_text;
          range.start = next.range.start;
          cursor_before = next.cursor_before;
        } else {
          // delete forward: extend forward
          old_text += next.old_text;
          range.end = next.range.end;
        }
        cursor_after = next.cursor_after;
        timestamp = next.timestamp;
      }
    }
  };

  /// Compound edit action (a group of EditAction as one atomic undo/redo unit)
  struct CompoundEditAction {
    Vector<EditAction> actions;
    /// Cursor position before the whole group
    TextPosition cursor_before;
    /// Cursor position after the whole group
    TextPosition cursor_after;
    /// Whether there was a selection before the whole group
    bool had_selection {false};
    /// Selection range before the whole group
    TextRange selection_before;
  };

  /// Undo stack entry: single action or compound action
  struct UndoEntry {
    bool is_compound {false};
    EditAction single;
    CompoundEditAction compound;

    /// Get cursor position before action
    TextPosition cursorBefore() const {
      return is_compound ? compound.cursor_before : single.cursor_before;
    }
    /// Get cursor position after action
    TextPosition cursorAfter() const {
      return is_compound ? compound.cursor_after : single.cursor_after;
    }
    /// Get selection state before action
    bool hadSelection() const {
      return is_compound ? compound.had_selection : single.had_selection;
    }
    TextRange selectionBefore() const {
      return is_compound ? compound.selection_before : single.selection_before;
    }
  };

  /// Undo/Redo manager
  class UndoManager {
  public:
    explicit UndoManager(size_t max_stack_size = 512)
      : m_max_stack_size_(max_stack_size) {}

    /// Push a new edit action (try to merge with stack top)
    void pushAction(EditAction action) {
      // In group mode, accumulate into group buffer
      if (m_group_depth_ > 0) {
        m_group_actions_.push_back(std::move(action));
        return;
      }

      // Push new action and clear redo stack
      m_redo_stack_.clear();

      // Try to merge with stack top (single action only)
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

      // Limit stack size
      if (m_undo_stack_.size() > m_max_stack_size_) {
        m_undo_stack_.erase(m_undo_stack_.begin());
      }
    }

    /// Begin undo group (all actions in group are rolled back together)
    /// Nested calls are supported
    void beginGroup(TextPosition cursor_before, bool had_selection = false, TextRange selection_before = {}) {
      if (m_group_depth_ == 0) {
        m_group_actions_.clear();
        m_group_cursor_before_ = cursor_before;
        m_group_had_selection_ = had_selection;
        m_group_selection_before_ = selection_before;
      }
      m_group_depth_++;
    }

    /// End undo group
    /// @param cursor_after Cursor position after group ends
    void endGroup(TextPosition cursor_after) {
      if (m_group_depth_ == 0) return;
      m_group_depth_--;
      if (m_group_depth_ > 0) return; // Nested groups not fully closed yet

      if (m_group_actions_.empty()) return;

      // Clear redo stack
      m_redo_stack_.clear();

      // Merge into CompoundEditAction
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

    /// Whether currently in group mode
    bool isInGroup() const { return m_group_depth_ > 0; }

    /// Pop top of undo stack and push to redo stack
    /// @return Popped entry, or nullptr if stack is empty
    const UndoEntry* undo() {
      if (m_undo_stack_.empty()) return nullptr;
      m_redo_stack_.push_back(std::move(m_undo_stack_.back()));
      m_undo_stack_.pop_back();
      return &m_redo_stack_.back();
    }

    /// Pop top of redo stack and push to undo stack
    /// @return Popped entry, or nullptr if stack is empty
    const UndoEntry* redo() {
      if (m_redo_stack_.empty()) return nullptr;
      m_undo_stack_.push_back(std::move(m_redo_stack_.back()));
      m_redo_stack_.pop_back();
      return &m_undo_stack_.back();
    }

    bool canUndo() const { return !m_undo_stack_.empty(); }
    bool canRedo() const { return !m_redo_stack_.empty(); }

    void clear() {
      m_undo_stack_.clear();
      m_redo_stack_.clear();
      m_group_depth_ = 0;
      m_group_actions_.clear();
    }

    void setMaxStackSize(size_t size) { m_max_stack_size_ = size; }
    size_t getMaxStackSize() const { return m_max_stack_size_; }

  private:
    Vector<UndoEntry> m_undo_stack_;
    Vector<UndoEntry> m_redo_stack_;
    size_t m_max_stack_size_;

    /// Group mechanism
    size_t m_group_depth_ {0};
    Vector<EditAction> m_group_actions_;
    TextPosition m_group_cursor_before_;
    bool m_group_had_selection_ {false};
    TextRange m_group_selection_before_;
  };
}

#endif //SWEETEDITOR_UNDO_MANAGER_H
