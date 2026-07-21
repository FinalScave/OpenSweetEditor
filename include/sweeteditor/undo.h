//
// Created by Scave on 2026/2/27.
//
#ifndef SWEETEDITOR_UNDO_MANAGER_H
#define SWEETEDITOR_UNDO_MANAGER_H

#include <sweeteditor/document.h>
#include <chrono>

namespace NS_SWEETEDITOR {
  /// One atomic undo/redo history entry.
  struct HistoryEntry {
    /// Replacements in the coordinates of the document before the edit.
    Vector<DocumentReplacement> redo_replacements;
    /// Inverse replacements in the coordinates of the document after the edit.
    Vector<DocumentReplacement> undo_replacements;
    CaretState caret_before;
    CaretState caret_after;
    std::chrono::steady_clock::time_point timestamp;
    /// Whether this entry may coalesce with an adjacent character edit.
    bool allows_merge {false};

    /// Check whether this entry can merge with the next continuous character edit.
    bool canMergeWith(const HistoryEntry& next) const;

    /// Merge the next continuous character edit into this entry.
    void mergeWith(const HistoryEntry& next);
  };

  /// Undo/Redo manager.
  class UndoManager {
  public:
    explicit UndoManager(size_t max_stack_size = 512);

    /// Push one atomic history entry and try to merge it with the stack top.
    void pushEntry(HistoryEntry entry);

    /// Move the latest undo entry to the redo stack.
    const HistoryEntry* undo();

    /// Move the latest redo entry to the undo stack.
    const HistoryEntry* redo();

    bool canUndo() const;
    bool canRedo() const;

    /// Prevent the latest history entry from merging with a later edit.
    void breakMergeChain();

    void clear();

    void setMaxStackSize(size_t size);
    size_t getMaxStackSize() const;

  private:
    Vector<HistoryEntry> m_undo_stack_;
    Vector<HistoryEntry> m_redo_stack_;
    size_t m_max_stack_size_;
  };
}

#endif //SWEETEDITOR_UNDO_MANAGER_H
