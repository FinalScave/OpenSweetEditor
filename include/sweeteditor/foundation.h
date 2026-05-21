//
// Created by Scave on 2025/12/2.
//
#ifndef SWEETEDITOR_FOUNDATION_H
#define SWEETEDITOR_FOUNDATION_H

#include <cstdint>
#include <sweeteditor/macro.h>

namespace NS_SWEETEDITOR {
  /// Text position
  struct TextPosition {
    /// Line index, starting from 0
    size_t line {0};
    /// Column index, starting from 0
    size_t column {0};

    bool operator<(const TextPosition& other) const;
    bool operator==(const TextPosition& other) const;
    bool operator!=(const TextPosition& other) const;
    U8String dump() const;
  };

  /// Text range
  struct TextRange {
    TextPosition start;
    TextPosition end;

    bool operator==(const TextRange& other) const;
    bool contains(const TextPosition& pos) const;
    U8String dump() const;
  };

  /// Inclusive integer range
  struct IntRange {
    int32_t start {0};
    int32_t end {-1};

    bool isEmpty() const;
    bool contains(int32_t value) const;
    int32_t length() const;
    U8String dump() const;
  };

  /// 2D coordinate wrapper
  struct PointF {
    float x {0};
    float y {0};

    float distance(const PointF& other) const;
    U8String dump() const;
  };

  /// Axis-aligned rectangle (origin + size)
  struct Rect {
    PointF origin;
    float width {0};
    float height {0};
  };

  /// Offset rectangle relative to a reference point
  struct OffsetRect {
    float left {0};
    float top {0};
    float right {0};
    float bottom {0};

    bool contains(float dx, float dy) const;
  };

}

#endif //SWEETEDITOR_FOUNDATION_H
