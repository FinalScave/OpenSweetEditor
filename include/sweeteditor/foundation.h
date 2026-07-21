//
// Created by Scave on 2025/12/2.
//
#ifndef SWEETEDITOR_FOUNDATION_H
#define SWEETEDITOR_FOUNDATION_H

#include <cstdint>
#include <sweeteditor/macro.h>

namespace NS_SWEETEDITOR {
  /// Text position
  struct SE_PROTOCOL_VALUE(foundation) TextPosition {
    /// Line index, starting from 0
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t line{0};
    /// Column index, starting from 0
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t column{0};

    bool operator<(const TextPosition& other) const;
    bool operator<=(const TextPosition& other) const;
    bool operator==(const TextPosition& other) const;
    bool operator!=(const TextPosition& other) const;
    TextPosition withLineDelta(int64_t delta) const;
    U8String dump() const;
  };

  /// Text range
  struct SE_PROTOCOL_VALUE(foundation) TextRange {
    TextPosition start;
    TextPosition end;

    bool operator==(const TextRange& other) const;
    bool contains(const TextPosition& pos) const;
    bool isCollapsed() const;
    bool overlaps(const TextRange& other) const;
    TextRange normalized() const;
    TextPosition transformPositionAfterEdit(TextPosition position, const TextPosition& new_end) const;
    U8String dump() const;
  };

  /// Atomic text edit item
  struct SE_PROTOCOL_VALUE(foundation) TextEdit {
    TextRange range;
    U8String new_text;
  };

  /// Inclusive integer range
  struct SE_PROTOCOL_VALUE(foundation) IntRange {
    int32_t start{0};
    int32_t end{-1};

    bool isEmpty() const;
    bool contains(int32_t value) const;
    int32_t length() const;
    U8String dump() const;
  };

  /// 2D coordinate wrapper
  struct SE_PROTOCOL_VALUE(foundation) PointF {
    float x{0};
    float y{0};

    float distance(const PointF& other) const;
    U8String dump() const;
  };

  /// 2D size wrapper
  struct SE_PROTOCOL_VALUE(foundation) Size {
    float width{0};
    float height{0};

    bool isEmpty() const;
    U8String dump() const;
  };

  /// Axis-aligned rectangle (origin + size)
  struct SE_PROTOCOL_VALUE(foundation) Rect {
    PointF origin;
    float width{0};
    float height{0};
  };

}

#endif //SWEETEDITOR_FOUNDATION_H
