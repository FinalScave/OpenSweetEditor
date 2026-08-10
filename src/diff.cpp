//
// Created by Scave on 2026/7/31.
//

#include <algorithm>
#include <cstdint>
#include <limits>
#include <optional>
#include <string_view>
#include <simdutf.h>
#include <sweeteditor/diff.h>
#include <sweeteditor/utility.h>
#include "internal/style_span_util.hpp"

namespace NS_SWEETEDITOR {
  const Vector<StyleSpan> Diff::kEmptySpans;

  namespace {
    constexpr size_t kMaxDiffTextBytes = 64u * 1024u * 1024u;
    constexpr size_t kMaxDiffLines = 250000;
    constexpr size_t kMaxMyersTraceCells = 8u * 1024u * 1024u;
    constexpr size_t kMaxRemovedBytes = 64u * 1024u * 1024u;

    struct RawLine {
      std::string_view text;
      LineEnding ending{LineEnding::NONE};

      bool operator==(const RawLine& other) const {
        if (text != other.text) return false;
        // A final line loses or gains its terminator when adjacent lines are inserted or removed.
        // Treat that transition as structural; only differences between real line-ending styles
        // make an otherwise equal line a replacement.
        return ending == other.ending || ending == LineEnding::NONE || other.ending == LineEnding::NONE;
      }
    };

    enum class DiffOperation : uint8_t {
      EQUAL,
      DELETE_ORIGINAL,
      INSERT_CURRENT,
    };

    bool checkedAdd(size_t left, size_t right, size_t& result) {
      if (left > std::numeric_limits<size_t>::max() - right) return false;
      result = left + right;
      return true;
    }

    bool isValidUtf8(std::string_view text) {
      return simdutf::validate_utf8(text.data(), text.size());
    }

    bool parseRawLines(std::string_view text, Vector<RawLine>& lines) {
      if (text.size() > kMaxDiffTextBytes || !isValidUtf8(text)) return false;

      size_t line_start = 0;
      for (size_t index = 0; index < text.size();) {
        LineEnding ending = LineEnding::NONE;
        size_t ending_length = 0;
        if (text[index] == '\r') {
          ending = index + 1 < text.size() && text[index + 1] == '\n' ? LineEnding::CRLF : LineEnding::CR;
          ending_length = ending == LineEnding::CRLF ? 2 : 1;
        } else if (text[index] == '\n') {
          ending = LineEnding::LF;
          ending_length = 1;
        }

        if (ending == LineEnding::NONE) {
          ++index;
          continue;
        }

        lines.push_back({text.substr(line_start, index - line_start), ending});
        if (lines.size() > kMaxDiffLines) return false;
        index += ending_length;
        line_start = index;
      }

      lines.push_back({text.substr(line_start), LineEnding::NONE});
      return lines.size() <= kMaxDiffLines;
    }

    bool buildMyersOperations(const Vector<RawLine>& original, size_t original_start, size_t original_count,
                              const Vector<RawLine>& current, size_t current_start, size_t current_count,
                              Vector<DiffOperation>& operations) {
      if (original_count == 0) {
        operations.insert(operations.end(), current_count, DiffOperation::INSERT_CURRENT);
        return true;
      }
      if (current_count == 0) {
        operations.insert(operations.end(), original_count, DiffOperation::DELETE_ORIGINAL);
        return true;
      }

      size_t max_distance = 0;
      if (!checkedAdd(original_count, current_count, max_distance)) return false;
      size_t vector_size = 0;
      if (!checkedAdd(max_distance, max_distance, vector_size) || !checkedAdd(vector_size, 1, vector_size)) {
        return false;
      }
      if (vector_size > kMaxMyersTraceCells) return false;

      const int64_t offset = static_cast<int64_t>(max_distance);
      Vector<int64_t> frontier(vector_size, 0);
      Vector<Vector<int64_t>> trace;
      const int64_t original_size = static_cast<int64_t>(original_count);
      const int64_t current_size = static_cast<int64_t>(current_count);

      size_t solved_distance = 0;
      bool solved = false;
      for (size_t distance = 0; distance <= max_distance; ++distance) {
        if ((distance + 1) > kMaxMyersTraceCells / vector_size) return false;
        trace.push_back(frontier);

        const int64_t d = static_cast<int64_t>(distance);
        for (int64_t diagonal = -d; diagonal <= d; diagonal += 2) {
          const size_t diagonal_index = static_cast<size_t>(offset + diagonal);
          int64_t x = 0;
          if (diagonal == -d
              || (diagonal != d && frontier[diagonal_index - 1] < frontier[diagonal_index + 1])) {
            x = frontier[diagonal_index + 1];
          } else {
            x = frontier[diagonal_index - 1] + 1;
          }
          int64_t y = x - diagonal;
          while (x < original_size && y < current_size
                 && original[original_start + static_cast<size_t>(x)]
                        == current[current_start + static_cast<size_t>(y)]) {
            ++x;
            ++y;
          }
          frontier[diagonal_index] = x;
          if (x >= original_size && y >= current_size) {
            solved = true;
            solved_distance = distance;
            break;
          }
        }
        if (solved) break;
      }
      if (!solved) return false;

      Vector<DiffOperation> reversed;
      int64_t x = original_size;
      int64_t y = current_size;
      for (size_t distance = solved_distance; distance > 0; --distance) {
        const Vector<int64_t>& previous_frontier = trace[distance];
        const int64_t d = static_cast<int64_t>(distance);
        const int64_t diagonal = x - y;
        const size_t diagonal_index = static_cast<size_t>(offset + diagonal);
        const int64_t previous_diagonal =
            diagonal == -d
                || (diagonal != d && previous_frontier[diagonal_index - 1]
                                         < previous_frontier[diagonal_index + 1])
                ? diagonal + 1
                : diagonal - 1;
        const int64_t previous_x = previous_frontier[static_cast<size_t>(offset + previous_diagonal)];
        const int64_t previous_y = previous_x - previous_diagonal;

        while (x > previous_x && y > previous_y) {
          reversed.push_back(DiffOperation::EQUAL);
          --x;
          --y;
        }
        if (x == previous_x) {
          reversed.push_back(DiffOperation::INSERT_CURRENT);
          --y;
        } else {
          reversed.push_back(DiffOperation::DELETE_ORIGINAL);
          --x;
        }
      }
      while (x > 0 && y > 0) {
        reversed.push_back(DiffOperation::EQUAL);
        --x;
        --y;
      }
      while (x-- > 0) reversed.push_back(DiffOperation::DELETE_ORIGINAL);
      while (y-- > 0) reversed.push_back(DiffOperation::INSERT_CURRENT);

      std::reverse(reversed.begin(), reversed.end());
      operations.insert(operations.end(), reversed.begin(), reversed.end());
      return true;
    }

    bool normalizeChanges(Vector<DiffChange>& changes, size_t current_line_count) {
      if (current_line_count > static_cast<size_t>(std::numeric_limits<uint32_t>::max())) return false;

      for (const DiffChange& change : changes) {
        size_t current_end = 0;
        size_t original_end = 0;
        if (!checkedAdd(change.current_start_line, change.current_line_count, current_end)
            || !checkedAdd(change.original_start_line, change.removed_lines.size(), original_end)) {
          return false;
        }
        if (change.current_start_line > current_line_count || current_end > current_line_count
            || change.current_line_count == 0 && change.removed_lines.empty()
            || change.current_start_line > static_cast<size_t>(std::numeric_limits<uint32_t>::max())
            || change.current_line_count > static_cast<size_t>(std::numeric_limits<uint32_t>::max())
            || change.original_start_line > static_cast<size_t>(std::numeric_limits<int32_t>::max())
            || original_end > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
          return false;
        }
        for (const U8String& removed_line : change.removed_lines) {
          if (!isValidUtf8(removed_line) || removed_line.find('\r') != U8String::npos
              || removed_line.find('\n') != U8String::npos) {
            return false;
          }
        }
      }

      std::stable_sort(changes.begin(), changes.end(), [](const DiffChange& left, const DiffChange& right) {
        if (left.current_start_line != right.current_start_line) {
          return left.current_start_line < right.current_start_line;
        }
        return left.original_start_line < right.original_start_line;
      });

      Vector<DiffChange> normalized;
      normalized.reserve(changes.size());
      for (DiffChange& change : changes) {
        if (normalized.empty()) {
          // Text before the first hunk is unchanged, so both coordinate spaces must start aligned.
          if (change.current_start_line != change.original_start_line) return false;
          normalized.push_back(std::move(change));
          continue;
        }

        DiffChange& previous = normalized.back();
        const size_t previous_current_end = previous.current_start_line + previous.current_line_count;
        const size_t previous_original_end = previous.original_start_line + previous.removed_lines.size();
        if (change.current_start_line < previous_current_end
            || change.original_start_line < previous_original_end) {
          return false;
        }

        // The gap between normalized hunks represents unchanged lines in both documents.
        if (change.current_start_line - previous_current_end
            != change.original_start_line - previous_original_end) {
          return false;
        }

        // Only ranges that meet in both coordinate spaces are one continuous hunk.
        if (change.current_start_line == previous_current_end
            && change.original_start_line == previous_original_end) {
          previous.current_line_count += change.current_line_count;
          previous.removed_lines.insert(previous.removed_lines.end(),
                                        std::make_move_iterator(change.removed_lines.begin()),
                                        std::make_move_iterator(change.removed_lines.end()));
          continue;
        }
        normalized.push_back(std::move(change));
      }

      changes = std::move(normalized);
      return true;
    }

    bool buildChanges(const Vector<RawLine>& original, const Vector<RawLine>& current,
                      Vector<DiffChange>& changes) {
      size_t prefix = 0;
      while (prefix < original.size() && prefix < current.size() && original[prefix] == current[prefix]) {
        ++prefix;
      }

      size_t suffix = 0;
      while (suffix < original.size() - prefix && suffix < current.size() - prefix
             && original[original.size() - 1 - suffix] == current[current.size() - 1 - suffix]) {
        ++suffix;
      }

      Vector<DiffOperation> operations;
      const size_t original_middle_count = original.size() - prefix - suffix;
      const size_t current_middle_count = current.size() - prefix - suffix;
      if (!buildMyersOperations(original, prefix, original_middle_count, current, prefix,
                                current_middle_count, operations)) {
        return false;
      }

      size_t current_line = prefix;
      size_t original_line = prefix;
      std::optional<DiffChange> pending;
      size_t removed_bytes = 0;
      auto flush = [&]() {
        if (pending.has_value()) {
          changes.push_back(std::move(*pending));
          pending.reset();
        }
      };

      for (DiffOperation operation : operations) {
        if (operation == DiffOperation::EQUAL) {
          flush();
          ++current_line;
          ++original_line;
          continue;
        }
        if (!pending.has_value()) {
          pending = DiffChange{current_line, 0, original_line, {}};
        }
        if (operation == DiffOperation::DELETE_ORIGINAL) {
          const std::string_view line = original[original_line].text;
          if (!checkedAdd(removed_bytes, line.size(), removed_bytes) || removed_bytes > kMaxRemovedBytes) {
            return false;
          }
          pending->removed_lines.emplace_back(line.data(), line.size());
          ++original_line;
        } else {
          ++pending->current_line_count;
          ++current_line;
        }
      }
      flush();
      return normalizeChanges(changes, current.size());
    }
  }

  bool Diff::empty() const {
    return m_changes_.empty();
  }

  void Diff::clear() {
    m_changes_.clear();
    m_max_removed_line_end_ = 0;
    for (auto& layer : m_line_spans_) layer.clear();
    m_merged_line_spans_.clear();
  }

  bool Diff::setChanges(Vector<DiffChange>&& changes, size_t current_line_count) {
    if (!normalizeChanges(changes, current_line_count)) return false;
    replaceChanges(std::move(changes));
    return true;
  }

  bool Diff::compute(const U8String& original_text, Document& current_document) {
    Vector<DiffChange> changes;
    if (!calculateChanges(original_text, current_document, changes)) return false;

    replaceChanges(std::move(changes));
    return true;
  }

  bool Diff::calculateChanges(const U8String& original_text, Document& current_document,
                              Vector<DiffChange>& changes) const {
    Vector<RawLine> original_lines;
    Vector<RawLine> current_lines;
    const U8String current_text = current_document.getU8Text();
    if (!parseRawLines(original_text, original_lines)
        || !parseRawLines(current_text, current_lines)) {
      return false;
    }

    return buildChanges(original_lines, current_lines, changes);
  }

  bool Diff::setBatchLineSpans(SpanLayer layer,
                               Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries) {
    const size_t layer_index = static_cast<size_t>(layer);
    if (layer_index >= kSpanLayerCount) return false;
    if (entries.empty()) return true;

    HashSet<size_t> seen_lines;
    for (const auto& entry : entries) {
      if (!seen_lines.insert(entry.first).second) return false;
      const DiffChange* change = getChangeForOriginalLine(entry.first);
      if (change == nullptr) return false;
      const U8String& line = change->removed_lines[entry.first - change->original_start_line];
      const size_t line_length = StrUtil::utf16Length(line);
      for (const StyleSpan& span : entry.second) {
        const size_t column = span.column;
        const size_t length = span.length;
        if (length == 0 || column > line_length || length > line_length - column) return false;
      }
    }

    HashMap<size_t, Vector<StyleSpan>>& line_spans = m_line_spans_[layer_index];
    for (auto& entry : entries) {
      if (entry.second.empty()) {
        line_spans.erase(entry.first);
      } else {
        line_spans.insert_or_assign(entry.first, std::move(entry.second));
      }
    }
    rebuildMergedLineSpans(seen_lines);
    return true;
  }

  const Vector<DiffChange>& Diff::getChanges() const {
    return m_changes_;
  }

  size_t Diff::getMaxRemovedLineEnd() const {
    return m_max_removed_line_end_;
  }

  const DiffChange* Diff::getChangeAtBoundary(size_t current_line) const {
    auto it = std::lower_bound(m_changes_.begin(), m_changes_.end(), current_line,
                               [](const DiffChange& change, size_t line) {
                                 return change.current_start_line < line;
                               });
    return it != m_changes_.end() && it->current_start_line == current_line ? &*it : nullptr;
  }

  const DiffChange* Diff::getChangeForCurrentLine(size_t current_line) const {
    auto it = std::upper_bound(m_changes_.begin(), m_changes_.end(), current_line,
                               [](size_t line, const DiffChange& change) {
                                 return line < change.current_start_line;
                               });
    if (it == m_changes_.begin()) return nullptr;
    --it;
    return current_line >= it->current_start_line
               && current_line - it->current_start_line < it->current_line_count
           ? &*it
           : nullptr;
  }

  const DiffChange* Diff::getChangeForOriginalLine(size_t original_line) const {
    auto it = std::upper_bound(m_changes_.begin(), m_changes_.end(), original_line,
                               [](size_t line, const DiffChange& change) {
                                 return line < change.original_start_line;
                               });
    if (it == m_changes_.begin()) return nullptr;
    --it;
    return original_line >= it->original_start_line
               && original_line - it->original_start_line < it->removed_lines.size()
           ? &*it
           : nullptr;
  }

  const Vector<StyleSpan>& Diff::getMergedLineSpans(size_t original_line) const {
    const auto it = m_merged_line_spans_.find(original_line);
    return it == m_merged_line_spans_.end() ? kEmptySpans : it->second;
  }

  void Diff::replaceChanges(Vector<DiffChange>&& changes) {
    m_changes_ = std::move(changes);
    m_max_removed_line_end_ = 0;
    // Keep the render-time gutter calculation independent of hunk count.
    for (const DiffChange& change : m_changes_) {
      m_max_removed_line_end_ =
          std::max(m_max_removed_line_end_, change.original_start_line + change.removed_lines.size());
    }
    for (auto& layer : m_line_spans_) layer.clear();
    m_merged_line_spans_.clear();
  }

  void Diff::rebuildMergedLineSpans(const HashSet<size_t>& lines) {
    for (size_t line : lines) {
      std::array<const Vector<StyleSpan>*, kSpanLayerCount> layers{};
      for (size_t layer_index = 0; layer_index < kSpanLayerCount; ++layer_index) {
        const auto it = m_line_spans_[layer_index].find(line);
        if (it != m_line_spans_[layer_index].end()) layers[layer_index] = &it->second;
      }
      Vector<StyleSpan> merged = detail::mergeStyleSpanLayers(layers);
      if (merged.empty()) {
        m_merged_line_spans_.erase(line);
      } else {
        m_merged_line_spans_.insert_or_assign(line, std::move(merged));
      }
    }
  }

}
