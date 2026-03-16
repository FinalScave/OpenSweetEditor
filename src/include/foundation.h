//
// Created by Scave on 2025/12/2.
//
#ifndef SWEETEDITOR_FOUNDATION_H
#define SWEETEDITOR_FOUNDATION_H

#include <cstdint>
#include <macro.h>

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

  /// 2D coordinate wrapper
  struct PointF {
    float x {0};
    float y {0};

    float distance(const PointF& other) const;
    U8String dump() const;
  };

  /// Editor viewport
  struct Viewport {
    /// Editor width
    float width {0};
    /// Editor height
    float height {0};

    bool valid() const;
    U8String dump() const;
  };

  /// Editor view state
  struct ViewState {
    /// Scale factor
    float scale {1};
    /// Horizontal scroll offset
    float scroll_x {0};
    /// Vertical scroll offset
    float scroll_y {0};

    U8String dump() const;
  };

  /// Keyboard key code definitions
  enum struct KeyCode : uint16_t {
    NONE = 0,
    BACKSPACE = 8,
    TAB = 9,
    ENTER = 13,
    ESCAPE = 27,
    DELETE_KEY = 46,
    LEFT = 37,
    UP = 38,
    RIGHT = 39,
    DOWN = 40,
    HOME = 36,
    END = 35,
    PAGE_UP = 33,
    PAGE_DOWN = 34,
    A = 65,
    C = 67,
    V = 86,
    X = 88,
    Z = 90,
    Y = 89,
    K = 75,
  };

  /// Modifier key flags
  enum struct Modifier : uint8_t {
    NONE  = 0,
    SHIFT = 1 << 0,
    CTRL  = 1 << 1,
    ALT   = 1 << 2,
    META  = 1 << 3,
  };
  inline Modifier operator&(Modifier a, Modifier b) { return static_cast<Modifier>(static_cast<uint8_t>(a) & static_cast<uint8_t>(b)); }
  inline Modifier operator|(Modifier a, Modifier b) { return static_cast<Modifier>(static_cast<uint8_t>(a) | static_cast<uint8_t>(b)); }

  /// Keyboard event data
  struct KeyEvent {
    /// Key code
    KeyCode key_code {KeyCode::NONE};
    /// Input text (used for regular character input, such as letters, numbers, symbols)
    U8String text;
    /// Modifier key state
    Modifier modifiers {Modifier::NONE};

    /// Whether this is plain text input (no special key code, text only)
    bool isTextInput() const { return key_code == KeyCode::NONE && !text.empty(); }
  };

  enum struct ScrollBehavior {
    /// Make the target line visible at the top
    GOTO_TOP,
    /// Scroll the target line to the center
    GOTO_CENTER,
    /// Scroll the target line to the bottom
    GOTO_BOTTOM,
  };

  /// Auto-indent modes
  enum struct AutoIndentMode {
    /// No auto-indent; new line starts at column 0
    NONE = 0,
    /// Keep previous line indent (copy leading whitespace)
    KEEP_INDENT = 1,
  };
}

#endif //SWEETEDITOR_FOUNDATION_H
