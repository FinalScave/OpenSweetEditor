//
// Created by Scave on 2026/2/27.
//
#ifndef SWEETEDITOR_UNDO_MANAGER_H
#define SWEETEDITOR_UNDO_MANAGER_H

#include <sweeteditor/foundation.h>
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
    bool canMergeWith(const EditAction& next) const;

    /// Merge next action into current action
    void mergeWith(const EditAction& next);
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
    TextPosition cursorBefore() const;
    /// Get cursor position after action
    TextPosition cursorAfter() const;
    /// Get selection state before action
    bool hadSelection() const;
    TextRange selectionBefore() const;
  };

  /// Undo/Redo manager
  class UndoManager {
  public:
    explicit UndoManager(size_t max_stack_size = 512);

    /// Push a new edit action (try to merge with stack top)
    void pushAction(EditAction action);

    /// Begin undo group (all actions in group are rolled back together)
    /// Nested calls are supported
    void beginGroup(TextPosition cursor_before, bool had_selection = false, TextRange selection_before = {});

    /// End undo group
    /// @param cursor_after Cursor position after group ends
    void endGroup(TextPosition cursor_after);

    /// Whether currently in group mode
    bool isInGroup() const;

    /// Pop top of undo stack and push to redo stack
    /// @return Popped entry, or nullptr if stack is empty
    const UndoEntry* undo();

    /// Pop top of redo stack and push to undo stack
    /// @return Popped entry, or nullptr if stack is empty
    const UndoEntry* redo();

    bool canUndo() const;
    bool canRedo() const;

    void clear();

    void setMaxStackSize(size_t size);
    size_t getMaxStackSize() const;

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
