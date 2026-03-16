//
// Created by Scave on 2026/3/5.
//
#include <linked_editing.h>
#include <utf8/utf8.h>
#include <algorithm>

namespace NS_SWEETEDITOR {
#pragma region [Class: SnippetParser]
  /// Calculate absolute TextPosition from offset (line char offset) and insert_position
  /// text is plain text from insert_position to the current offset
  static TextPosition calcAbsolutePosition(const TextPosition& insert_pos,
                                           const U8String& text_before) {
    size_t line = insert_pos.line;
    size_t col = insert_pos.column;
    auto it = text_before.begin();
    while (it != text_before.end()) {
      char ch = *it;
      if (ch == '\n') {
        ++line;
        col = 0;
        ++it;
      } else if (ch == '\r') {
        ++line;
        col = 0;
        ++it;
        if (it != text_before.end() && *it == '\n') ++it;
      } else {
        uint32_t cp = utf8::next(it, text_before.end());
        col += (cp > 0xFFFF) ? 2 : 1;
      }
    }
    return {line, col};
  }

  SnippetParseResult SnippetParser::parse(const U8String& snippet_template,
                                          const TextPosition& insert_position) {
    SnippetParseResult result;
    U8String& plain_text = result.text;

    // Temp storage: index -> (default_text, list of {offset_in_plain, length})
    struct Occurrence {
      size_t offset;  // byte offset in plain_text
      size_t length;  // byte length of default text at that position
    };
    struct TabStopInfo {
      uint32_t index;
      U8String default_text;
      bool has_default {false};
      Vector<Occurrence> occurrences;
    };
    HashMap<uint32_t, TabStopInfo> tab_stop_map;

    size_t i = 0;
    size_t len = snippet_template.size();

    while (i < len) {
      char ch = snippet_template[i];

      // Escape: \$ \\ \}
      if (ch == '\\' && i + 1 < len) {
        char next = snippet_template[i + 1];
        if (next == '$' || next == '\\' || next == '}') {
          plain_text += next;
          i += 2;
          continue;
        }
      }

      // Starts with $: tab stop
      if (ch == '$') {
        i++; // skip $
        if (i >= len) {
          plain_text += '$';
          break;
        }

        if (snippet_template[i] == '{') {
          // ${N} or ${N:default}
          i++; // skip {
          // Parse number
          U8String num_str;
          while (i < len && snippet_template[i] >= '0' && snippet_template[i] <= '9') {
            num_str += snippet_template[i++];
          }
          if (num_str.empty()) {
            // Invalid syntax, output as-is
            plain_text += "${";
            continue;
          }
          uint32_t index = static_cast<uint32_t>(std::stoul(num_str));

          U8String default_text;
          if (i < len && snippet_template[i] == ':') {
            // Has default text
            i++; // skip :
            // Read until matching } (simple handling, no nesting)
            int brace_depth = 1;
            while (i < len && brace_depth > 0) {
              if (snippet_template[i] == '\\' && i + 1 < len) {
                char esc = snippet_template[i + 1];
                if (esc == '$' || esc == '\\' || esc == '}') {
                  default_text += esc;
                  i += 2;
                  continue;
                }
              }
              if (snippet_template[i] == '}') {
                brace_depth--;
                if (brace_depth == 0) {
                  i++; // skip }
                  break;
                }
              }
              if (snippet_template[i] == '{') {
                brace_depth++;
              }
              default_text += snippet_template[i++];
            }
          } else if (i < len && snippet_template[i] == '}') {
            i++; // skip }
          } else {
            // Invalid syntax, output as-is
            plain_text += "${" + num_str;
            continue;
          }

          // Record tab stop
          auto& info = tab_stop_map[index];
          info.index = index;
          // First seen default_text has priority
          if (!info.has_default && !default_text.empty()) {
            info.default_text = default_text;
            info.has_default = true;
          }
          // Use fixed default_text (if set by earlier occurrence)
          const U8String& text_to_insert = info.has_default ? info.default_text : default_text;
          Occurrence occ;
          occ.offset = plain_text.size();
          occ.length = text_to_insert.size();
          info.occurrences.push_back(occ);
          plain_text += text_to_insert;

        } else if (snippet_template[i] >= '0' && snippet_template[i] <= '9') {
          // $N (short form)
          U8String num_str;
          while (i < len && snippet_template[i] >= '0' && snippet_template[i] <= '9') {
            num_str += snippet_template[i++];
          }
          uint32_t index = static_cast<uint32_t>(std::stoul(num_str));

          auto& info = tab_stop_map[index];
          info.index = index;
          const U8String& text_to_insert = info.has_default ? info.default_text : "";
          Occurrence occ;
          occ.offset = plain_text.size();
          occ.length = text_to_insert.size();
          info.occurrences.push_back(occ);
          plain_text += text_to_insert;

        } else {
          // After $, if not digit and not {, output as-is
          plain_text += '$';
        }
        continue;
      }

      // Normal character
      plain_text += ch;
      i++;
    }

    // Convert tab_stop_map to groups, sort by index (1,2,3,...,0 at end)
    Vector<TabStopInfo*> sorted_infos;
    for (auto& [idx, info] : tab_stop_map) {
      sorted_infos.push_back(&info);
    }
    std::sort(sorted_infos.begin(), sorted_infos.end(), [](const TabStopInfo* a, const TabStopInfo* b) {
      // Move index=0 to the end
      if (a->index == 0 && b->index != 0) return false;
      if (a->index != 0 && b->index == 0) return true;
      return a->index < b->index;
    });

    for (const auto* info : sorted_infos) {
      TabStopGroup group;
      group.index = info->index;
      group.default_text = info->has_default ? info->default_text : "";

      for (const auto& occ : info->occurrences) {
        // Calculate this occurrence's absolute position in document
        U8String text_before = plain_text.substr(0, occ.offset);
        TextPosition start = calcAbsolutePosition(insert_position, text_before);

        TextPosition end;
        if (occ.length > 0) {
          U8String text_to_end = plain_text.substr(0, occ.offset + occ.length);
          end = calcAbsolutePosition(insert_position, text_to_end);
        } else {
          end = start;
        }

        group.ranges.push_back({start, end});
      }

      result.model.groups.push_back(std::move(group));
    }

    return result;
  }
#pragma endregion

#pragma region [CLass: LinkedEditingSession]
  LinkedEditingSession::LinkedEditingSession(LinkedEditingModel&& model)
    : m_model_(std::move(model)), m_current_idx_(0), m_active_(true) {
    if (m_model_.groups.empty()) {
      m_active_ = false;
    }
  }

  LinkedEditingSession::LinkedEditingSession(const LinkedEditingModel& model)
    : m_model_(model), m_current_idx_(0), m_active_(true) {
    if (m_model_.groups.empty()) {
      m_active_ = false;
    }
  }

  bool LinkedEditingSession::isActive() const {
    return m_active_;
  }

  bool LinkedEditingSession::nextTabStop() {
    if (!m_active_) return false;
    if (m_current_idx_ + 1 < m_model_.groups.size()) {
      m_current_idx_++;
      return true;
    }
    // Reached the end ($0 or last group), session ends
    m_active_ = false;
    return false;
  }

  bool LinkedEditingSession::prevTabStop() {
    if (!m_active_) return false;
    if (m_current_idx_ > 0) {
      m_current_idx_--;
      return true;
    }
    return false;
  }

  void LinkedEditingSession::cancel() {
    m_active_ = false;
  }

  TextPosition LinkedEditingSession::finalCursorPosition() const {
    // $0 group is last, use its primaryRange.start as final cursor position
    if (!m_model_.groups.empty()) {
      const auto& last_group = m_model_.groups.back();
      if (!last_group.ranges.empty()) {
        return last_group.ranges[0].start;
      }
    }
    return {}; // fallback
  }

  const TabStopGroup* LinkedEditingSession::currentGroup() const {
    if (!isValidIndex()) return nullptr;
    return &m_model_.groups[m_current_idx_];
  }

  const TextRange& LinkedEditingSession::primaryRange() const {
    static const TextRange empty_range = {};
    const TabStopGroup* group = currentGroup();
    if (group == nullptr || group->ranges.empty()) return empty_range;
    return group->ranges[0];
  }

  size_t LinkedEditingSession::currentGroupIndex() const {
    return m_current_idx_;
  }

  Vector<std::pair<TextRange, U8String>> LinkedEditingSession::computeLinkedEdits(
      const U8String& new_text) const {
    Vector<std::pair<TextRange, U8String>> edits;
    const TabStopGroup* group = currentGroup();
    if (group == nullptr) return edits;

    // Collect all ranges
    for (const auto& range : group->ranges) {
      edits.push_back({range, new_text});
    }

    // Sort by document position in descending order (replace back to front)
    std::sort(edits.begin(), edits.end(),
      [](const auto& a, const auto& b) {
        if (a.first.start.line != b.first.start.line)
          return a.first.start.line > b.first.start.line;
        return a.first.start.column > b.first.start.column;
      });

    return edits;
  }

  void LinkedEditingSession::adjustRangesForEdit(const TextRange& old_range,
                                                  const TextPosition& new_end) {
    if (!m_active_) return;

    // Compute line delta and column delta on the last line
    int64_t old_end_line = static_cast<int64_t>(old_range.end.line);
    int64_t old_end_col = static_cast<int64_t>(old_range.end.column);
    int64_t new_end_line = static_cast<int64_t>(new_end.line);
    int64_t new_end_col = static_cast<int64_t>(new_end.column);
    int64_t line_delta = new_end_line - old_end_line;
    int64_t col_delta = new_end_col - old_end_col;

    for (auto& group : m_model_.groups) {
      for (auto& range : group.ranges) {
        // Only adjust ranges after the edit point
        // Start position adjustment
        if (range.start.line == old_range.end.line && range.start.column >= old_range.end.column) {
          // Same line, after edit point
          range.start.line = static_cast<size_t>(static_cast<int64_t>(range.start.line) + line_delta);
          if (line_delta == 0) {
            range.start.column = static_cast<size_t>(static_cast<int64_t>(range.start.column) + col_delta);
          } else {
            // Crossed lines, column is based on new_end_col on the new line
            range.start.column = static_cast<size_t>(
              new_end_col + (static_cast<int64_t>(range.start.column) - old_end_col));
          }
        } else if (range.start.line > old_range.end.line) {
          // Lines after the edit point
          range.start.line = static_cast<size_t>(static_cast<int64_t>(range.start.line) + line_delta);
        }

        // End position adjustment (same logic)
        if (range.end.line == old_range.end.line && range.end.column >= old_range.end.column) {
          range.end.line = static_cast<size_t>(static_cast<int64_t>(range.end.line) + line_delta);
          if (line_delta == 0) {
            range.end.column = static_cast<size_t>(static_cast<int64_t>(range.end.column) + col_delta);
          } else {
            range.end.column = static_cast<size_t>(
              new_end_col + (static_cast<int64_t>(range.end.column) - old_end_col));
          }
        } else if (range.end.line > old_range.end.line) {
          range.end.line = static_cast<size_t>(static_cast<int64_t>(range.end.line) + line_delta);
        }
      }
    }
  }

  Vector<LinkedEditingHighlight> LinkedEditingSession::getAllHighlights() const {
    Vector<LinkedEditingHighlight> highlights;
    if (!m_active_) return highlights;

    for (size_t i = 0; i < m_model_.groups.size(); ++i) {
      bool is_active = (i == m_current_idx_);
      for (const auto& range : m_model_.groups[i].ranges) {
        highlights.push_back({range, is_active});
      }
    }
    return highlights;
  }

  bool LinkedEditingSession::isValidIndex() const {
    return m_active_ && m_current_idx_ < m_model_.groups.size();
  }
#pragma endregion
}
