//
// Created by Scave on 2026/3/5.
//
#ifndef SWEETEDITOR_LINKED_EDITING_H
#define SWEETEDITOR_LINKED_EDITING_H

#include <cstdint>
#include <optional>
#include <sweeteditor/macro.h>
#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {

  /// Tab stop group (all positions with the same index are edited together)
  struct SE_PROTOCOL_IN(foundation) TabStopGroup {
    /// Group index that decides Tab navigation order (0 = final cursor position, 1+ = edit order)
    uint32_t index{0};
    /// All text ranges in this group (updated together during linked editing)
    Vector<TextRange> ranges;
    /// Default placeholder text
    U8String default_text;
  };

  /// Snippet parse result
  struct SnippetParseResult {
    /// Expanded plain text (all placeholders replaced with default text)
    U8String text;
    /// Tab stop groups whose ranges use absolute positions relative to the insert point
    Vector<TabStopGroup> groups;
  };

  /// VSCode snippet syntax parser
  class SnippetParser {
  public:
    /// Parse a VSCode snippet template into SnippetParseResult
    /// @param snippet_template Template text, for example "for (int ${1:i}=0; ${1:i}<${2:n}; ${1:i}++) {\n\t$0\n}"
    /// @param insert_position Start position where the template is inserted (used to compute absolute range positions)
    /// @return Parse result: expanded plain text and tab stop groups
    static SnippetParseResult parse(const U8String& snippet_template, const TextPosition& insert_position);
  };

  /// Linked editing highlight info (output to render model)
  struct LinkedEditingHighlight {
    /// Text range
    TextRange range;
    /// Whether this is the currently active tab stop
    bool is_active{false};
  };

  /// Linked editing session (lifecycle managed by EditorCore)
  class LinkedEditingSession {
  public:
    explicit LinkedEditingSession(Vector<TabStopGroup> groups);

    /// Whether the session is still active
    bool isActive() const;

    /// Tab: jump to the next group
    /// @return false if the end is reached ($0 or last group), and the session ends
    bool nextTabStop();

    /// Shift+Tab: jump to the previous group
    /// @return false if already at the first group
    bool prevTabStop();

    /// Exit linked editing mode
    void cancel();

    /// Get final cursor position (primaryRange.start of $0 group)
    /// Call before session end, used to place cursor consistently when finishing with Enter/Tab
    TextPosition finalCursorPosition() const;

    /// Get current active group
    /// @return Pointer to current group; nullptr means the session has ended
    const TabStopGroup* currentGroup() const;

    /// Get primary range of current group (first range, used for cursor/selection placement)
    const TextRange& primaryRange() const;

    /// Get index of current group in groups
    size_t currentGroupIndex() const;

    /// Update every linked range for one shared-pre-state edit batch.
    /// active_group_owners uses an active-group range index for owned replacements and nullopt for external edits.
    bool adjustRangesForEditBatch(const Vector<TextEdit>& edits,
                                  const Vector<std::optional<size_t>>& active_group_owners);

    /// Get highlight info for all tab stops (for rendering)
    Vector<LinkedEditingHighlight> getAllHighlights() const;

  private:
    Vector<TabStopGroup> m_groups_;
    size_t m_current_idx_{0}; ///< Index in m_groups_
    bool m_active_{true};

    /// Internal helper: check if index is valid
    bool isValidIndex() const;
  };

}

#endif //SWEETEDITOR_LINKED_EDITING_H
