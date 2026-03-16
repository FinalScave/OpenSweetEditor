//
// Created by Scave on 2025/12/2.
//
#include <cmath>
#include <foundation.h>

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

#pragma region [Class: PointF]
  float PointF::distance(const PointF& other) const {
    return sqrtf(powf(other.x - x, 2) + powf(other.y - y, 2));
  }

  U8String PointF::dump() const {
    return "PointF {x = " + std::to_string(x) + ", y = " + std::to_string(y) + "}";
  }
#pragma endregion

#pragma region [Class: Viewport]
  bool Viewport::valid() const {
    return width > 1 && height > 1;
  }

  U8String Viewport::dump() const {
    return "Viewport {width = " + std::to_string(width) + ", height = " + std::to_string(height) + "}";
  }
#pragma endregion

#pragma region [Class: ViewState]
  U8String ViewState::dump() const {
    return "ViewState {scale = " + std::to_string(scale) + ", scroll_x = " + std::to_string(scroll_x) + ", scroll_y = " + std::to_string(scroll_y) + "}";
  }
#pragma endregion

}
