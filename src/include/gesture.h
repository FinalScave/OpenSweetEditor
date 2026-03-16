//
// Created by Scave on 2025/12/6.
//

#ifndef SWEETEDITOR_GESTURE_H
#define SWEETEDITOR_GESTURE_H

#include <cstdint>
#include <limits>
#include <nlohmann/json.hpp>
#include <foundation.h>

namespace NS_SWEETEDITOR {

  struct TouchConfig {
    /// Movement threshold for gesture detection; below this is treated as a tap
    float touch_slop {10};
    /// Time threshold for double tap
    int64_t double_tap_timeout {300};
    /// Time threshold for long press
    int64_t long_press_ms {500};
  };

  /// Gesture event type definitions
  enum EventType : uint8_t {
    /// Undefined gesture
    UNDEFINED = 0,
    // ---- Touch events (Android/iOS/HarmonyOS) ----
    /// Finger down
    TOUCH_DOWN = 1,
    /// Another finger down
    TOUCH_POINTER_DOWN = 2,
    /// Move
    TOUCH_MOVE = 3,
    /// One finger up
    TOUCH_POINTER_UP = 4,
    /// Finger up
    TOUCH_UP = 5,
    /// Cancel event
    TOUCH_CANCEL = 6,
    // ---- Mouse events (Windows/Mac/Web/HarmonyOS PC mode) ----
    /// Mouse down (left button)
    MOUSE_DOWN = 7,
    /// Mouse move (drag while pressed)
    MOUSE_MOVE = 8,
    /// Mouse up
    MOUSE_UP = 9,
    /// Mouse wheel
    MOUSE_WHEEL = 10,
    /// Mouse right button down
    MOUSE_RIGHT_DOWN = 11,
    // ---- Platform passthrough gestures (Mac trackpad / iOS pinch) ----
    /// Scale value passed directly by platform
    DIRECT_SCALE = 12,
    /// Scroll value passed directly by platform (for example, two-finger trackpad scroll)
    DIRECT_SCROLL = 13,
  };

  /// Gesture event data passed from platform layer
  struct GestureEvent {
    /// Gesture event type
    EventType type {EventType::UNDEFINED};
    /// Pointer coordinates
    Vector<PointF> points;
    /// Modifier key state (Shift/Ctrl/Alt/Meta bitmask)
    Modifier modifiers {Modifier::NONE};
    /// Wheel delta for MOUSE_WHEEL (positive: up/right, negative: down/left)
    float wheel_delta_x {0};
    float wheel_delta_y {0};
    /// Scale value for DIRECT_SCALE
    float direct_scale {1};

    static GestureEvent create(EventType type, uint8_t pointer_count, const float* points);
    static GestureEvent createWithModifiers(EventType type, uint8_t pointer_count, const float* points, Modifier modifiers);
    U8String dump() const;
  };

  /// Gesture handling result types
  enum struct GestureType : uint8_t {
    /// Undefined result
    UNDEFINED = 0,
    /// Tap
    TAP = 1,
    /// Double tap
    DOUBLE_TAP = 2,
    /// Long press
    LONG_PRESS = 3,
    /// Scale
    SCALE = 4,
    /// Scroll
    SCROLL = 5,
    /// Fast scroll
    FAST_SCROLL = 6,
    /// Drag selection (mouse drag or drag after touch long press)
    DRAG_SELECT = 7,
    /// Context menu (right click / long press)
    CONTEXT_MENU = 8,
  };

  /// Tap hit target types
  enum struct HitTargetType : uint8_t {
    /// No special target hit (regular text area)
    NONE = 0,
    /// Hit InlayHint (text)
    INLAY_HINT_TEXT = 1,
    /// Hit InlayHint (icon)
    INLAY_HINT_ICON = 2,
    /// Hit gutter icon in line-number area
    GUTTER_ICON = 3,
    /// Hit fold placeholder (tap to expand folded region)
    FOLD_PLACEHOLDER = 4,
    /// Hit fold arrow in gutter (tap to toggle fold/unfold)
    FOLD_GUTTER = 5,
    /// Hit InlayHint (color block)
    INLAY_HINT_COLOR = 6,
  };

  /// Tap hit target info (filled by EditorCore for TAP)
  struct HitTarget {
    HitTargetType type {HitTargetType::NONE};
    /// Hit logical line index (0-based)
    size_t line {0};
    /// Hit column index (0-based, meaningful for INLAY_HINT only)
    size_t column {0};
    /// Icon ID (valid for INLAY_HINT_ICON / GUTTER_ICON)
    int32_t icon_id {0};
    /// Color value (ARGB, valid for INLAY_HINT_COLOR)
    int32_t color_value {0};
  };

  /// Gesture handling result
  struct GestureResult {
    GestureType type {GestureType::UNDEFINED};
    PointF tap_point {};
    float scale {1};
    float scroll_x {0};
    float scroll_y {0};
    /// Modifier key state (returned to upper layer, used for Shift+Click, etc.)
    Modifier modifiers {Modifier::NONE};
    /// Cursor position (filled by EditorCore)
    TextPosition cursor_position;
    /// Whether there is a selection (filled by EditorCore)
    bool has_selection {false};
    /// Selection range (filled by EditorCore)
    TextRange selection;
    /// View scroll offset (filled by EditorCore)
    float view_scroll_x {0};
    float view_scroll_y {0};
    /// View scale (filled by EditorCore)
    float view_scale {1};
    /// Tap hit target (filled by EditorCore on TAP)
    HitTarget hit_target;
  };

  /// Gesture handler class
  class GestureHandler {
  public:
    explicit GestureHandler(const TouchConfig& config);

    /// Handle a gesture event
    /// @param event Gesture data passed from platform side
    GestureResult handleGestureEvent(const GestureEvent& event);

    /// Reset all gesture states (call after drag handle operations end, etc.)
    void resetState();
  private:

    const TouchConfig m_config_;
    Vector<PointF> m_down_points_;
    int64_t m_down_time_ {std::numeric_limits<int64_t>::max()};
    PointF m_last_move_point_;
    float m_last_distance_ {0};
    bool m_is_tap_ {false};
    bool m_is_mouse_down_ {false};
    bool m_is_dragging_ {false};
    bool m_is_scaling_ {false};
    bool m_is_fast_scrolling_ {false};
    int m_pinch_confirm_count_ {0};
    Vector<PointF> m_last_multi_points_;
    PointF m_last_tap_point_;
    int64_t m_last_tap_time_ {0};
    Modifier m_active_modifiers_ {Modifier::NONE};
  };

  NLOHMANN_JSON_SERIALIZE_ENUM(EventType, {
    {EventType::UNDEFINED, "UNDEFINED"},
    {EventType::TOUCH_DOWN, "TOUCH_DOWN"},
    {EventType::TOUCH_POINTER_DOWN, "TOUCH_POINTER_DOWN"},
    {EventType::TOUCH_MOVE, "TOUCH_MOVE"},
    {EventType::TOUCH_POINTER_UP, "TOUCH_POINTER_UP"},
    {EventType::TOUCH_UP, "TOUCH_UP"},
    {EventType::TOUCH_CANCEL, "TOUCH_CANCEL"},
    {EventType::MOUSE_DOWN, "MOUSE_DOWN"},
    {EventType::MOUSE_MOVE, "MOUSE_MOVE"},
    {EventType::MOUSE_UP, "MOUSE_UP"},
    {EventType::MOUSE_WHEEL, "MOUSE_WHEEL"},
    {EventType::MOUSE_RIGHT_DOWN, "MOUSE_RIGHT_DOWN"},
    {EventType::DIRECT_SCALE, "DIRECT_SCALE"},
    {EventType::DIRECT_SCROLL, "DIRECT_SCROLL"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(GestureType, {
    {GestureType::UNDEFINED, "UNDEFINED"},
    {GestureType::TAP, "TAP"},
    {GestureType::DOUBLE_TAP, "DOUBLE_TAP"},
    {GestureType::LONG_PRESS, "LONG_PRESS"},
    {GestureType::SCALE, "SCALE"},
    {GestureType::SCROLL, "SCROLL"},
    {GestureType::FAST_SCROLL, "FAST_SCROLL"},
    {GestureType::DRAG_SELECT, "DRAG_SELECT"},
    {GestureType::CONTEXT_MENU, "CONTEXT_MENU"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(HitTargetType, {
    {HitTargetType::NONE, "NONE"},
    {HitTargetType::INLAY_HINT_TEXT, "INLAY_HINT_TEXT"},
    {HitTargetType::INLAY_HINT_ICON, "INLAY_HINT_ICON"},
    {HitTargetType::GUTTER_ICON, "GUTTER_ICON"},
    {HitTargetType::FOLD_PLACEHOLDER, "FOLD_PLACEHOLDER"},
    {HitTargetType::FOLD_GUTTER, "FOLD_GUTTER"},
    {HitTargetType::INLAY_HINT_COLOR, "INLAY_HINT_COLOR"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(HitTarget, type, line, column, icon_id, color_value)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GestureResult, type, tap_point, modifiers, scale, scroll_x, scroll_y, cursor_position, has_selection, selection, view_scroll_x, view_scroll_y, view_scale, hit_target)
}

#endif //SWEETEDITOR_GESTURE_H
