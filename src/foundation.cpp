//
// Created by Scave on 2025/12/2.
//
#include <cmath>
#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {
#pragma region [Class: TextPosition]
  bool TextPosition::operator<(const TextPosition& other) const {
    if (line != other.line) return line < other.line;
    return column < other.column;
  }

  bool TextPosition::operator==(const TextPosition& other) const {
    return line == other.line && column == other.column;
  }

  bool TextPosition::operator!=(const TextPosition& other) const {
    return !(*this == other);
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
