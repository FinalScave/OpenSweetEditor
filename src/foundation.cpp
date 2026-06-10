//
// Created by Scave on 2025/12/2.
//
#include <cmath>
#include <algorithm>
#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {
#pragma region [Class: TextPosition]
  bool TextPosition::operator<(const TextPosition& other) const {
    if (line != other.line) return line < other.line;
    return column < other.column;
  }

  bool TextPosition::operator<=(const TextPosition& other) const {
    return !(other < *this);
  }

  bool TextPosition::operator==(const TextPosition& other) const {
    return line == other.line && column == other.column;
  }

  bool TextPosition::operator!=(const TextPosition& other) const {
    return !(*this == other);
  }

  TextPosition TextPosition::withLineDelta(int64_t delta) const {
    TextPosition result = *this;
    if (delta >= 0) {
      result.line += static_cast<size_t>(delta);
      return result;
    }

    const size_t amount = static_cast<size_t>(-delta);
    result.line = result.line > amount ? result.line - amount : 0;
    return result;
  }

  U8String TextPosition::dump() const {
    return "TextPosition {line = " + std::to_string(line) + ", column = " + std::to_string(column) + "}";
  }

#pragma endregion

#pragma region [Class: TextRange]
  bool TextRange::operator==(const TextRange& other) const {
    return start == other.start && end == other.end;
  }

  bool TextRange::contains(const TextPosition& pos) const {
    return !(pos < start) && (pos < end || pos == end);
  }

  bool TextRange::isCollapsed() const {
    return start == end;
  }

  bool TextRange::overlaps(const TextRange& other) const {
    const TextRange lhs = normalized();
    const TextRange rhs = other.normalized();

    if (lhs.isCollapsed() && rhs.isCollapsed()) {
      return lhs.start == rhs.start;
    }
    if (lhs.isCollapsed()) {
      return rhs.start <= lhs.start && lhs.start < rhs.end;
    }
    if (rhs.isCollapsed()) {
      return lhs.start <= rhs.start && rhs.start < lhs.end;
    }
    return lhs.start < rhs.end && rhs.start < lhs.end;
  }

  TextRange TextRange::normalized() const {
    TextRange range = *this;
    if (range.end < range.start) {
      std::swap(range.start, range.end);
    }
    return range;
  }

  TextPosition TextRange::transformPositionAfterEdit(TextPosition position, const TextPosition& new_end) const {
    const TextRange old_range = normalized();
    if (position < old_range.start) {
      return position;
    }
    if (position <= old_range.end) {
      return new_end;
    }

    const int64_t line_delta = static_cast<int64_t>(new_end.line) - static_cast<int64_t>(old_range.end.line);
    TextPosition result = position.withLineDelta(line_delta);
    if (position.line == old_range.end.line) {
      if (new_end.line == old_range.end.line) {
        const int64_t column_delta = static_cast<int64_t>(new_end.column) - static_cast<int64_t>(old_range.end.column);
        if (column_delta >= 0) {
          result.column = position.column + static_cast<size_t>(column_delta);
        } else {
          const size_t amount = static_cast<size_t>(-column_delta);
          result.column = position.column > amount ? position.column - amount : 0;
        }
      } else {
        result.column = new_end.column + (position.column - old_range.end.column);
      }
    }
    return result;
  }

  U8String TextRange::dump() const {
    return "TextRange {start = " + start.dump() + ", end = " + end.dump() + "}";
  }

#pragma endregion

#pragma region [Class: IntRange]
  bool IntRange::isEmpty() const {
    return end < start;
  }

  bool IntRange::contains(int32_t value) const {
    return !isEmpty() && value >= start && value <= end;
  }

  int32_t IntRange::length() const {
    return isEmpty() ? 0 : (end - start + 1);
  }

  U8String IntRange::dump() const {
    return "IntRange {start = " + std::to_string(start) + ", end = " + std::to_string(end) + "}";
  }
#pragma endregion

#pragma region [Class: PointF]
  float PointF::distance(const PointF& other) const {
    return sqrtf(powf(other.x - x, 2) + powf(other.y - y, 2));
  }

  U8String PointF::dump() const {
    return "PointF {x = " + std::to_string(x) + ", y = " + std::to_string(y) + "}";
  }
#pragma endregion

#pragma region [Class: OffsetRect]
  bool OffsetRect::contains(float dx, float dy) const {
    return dx >= left && dx <= right && dy >= top && dy <= bottom;
  }
#pragma endregion

}
