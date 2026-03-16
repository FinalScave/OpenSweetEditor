//
// Created by Scave on 2025/12/6.
//

#include <cmath>
#include <gesture.h>
#include <utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

#pragma region [Class: GestureEvent]
  GestureEvent GestureEvent::create(EventType type, const uint8_t pointer_count, const float* points) {
    return createWithModifiers(type, pointer_count, points, Modifier::NONE);
  }

  GestureEvent GestureEvent::createWithModifiers(EventType type, const uint8_t pointer_count, const float* points, Modifier modifiers) {
    GestureEvent event;
    event.type = type;
    event.modifiers = modifiers;
    for (uint8_t i = 0; i < pointer_count; i++) {
      event.points.push_back({points[i * 2], points[i * 2 + 1]});
    }
    return event;
  }

  U8String GestureEvent::dump() const {
    return "GestureEvent {type = " + std::to_string(type) + ", point size = " + std::to_string(points.size())
         + ", modifiers = " + std::to_string(static_cast<uint8_t>(modifiers)) + "}";
  }
#pragma endregion

#pragma region [Class: GestureHandler]
  GestureHandler::GestureHandler(const TouchConfig& config): m_config_(config) {
  }

  void GestureHandler::resetState() {
    m_is_tap_ = false;
    m_is_mouse_down_ = false;
    m_is_dragging_ = false;
    m_is_scaling_ = false;
    m_is_fast_scrolling_ = false;
    m_pinch_confirm_count_ = 0;
    m_last_multi_points_.clear();
    m_down_points_.clear();
    m_down_time_ = std::numeric_limits<int64_t>::max();
    m_active_modifiers_ = Modifier::NONE;
  }

  GestureResult GestureHandler::handleGestureEvent(const GestureEvent& event) {
    if (event.points.empty()
        && event.type != EventType::MOUSE_WHEEL
        && event.type != EventType::DIRECT_SCALE
        && event.type != EventType::DIRECT_SCROLL
        && event.type != EventType::TOUCH_CANCEL) {
      LOGD("GestureHandler::handleGestureEvent, points empty");
      return {};
    }
    int64_t current_time = TimeUtil::milliTime();
    m_active_modifiers_ = event.modifiers;

    switch (event.type) {

    // Mouse down (left button)
    case EventType::MOUSE_DOWN: {
      m_down_points_ = event.points;
      m_is_mouse_down_ = true;
      m_is_dragging_ = false;
      m_last_move_point_ = m_down_points_[0];
      m_down_time_ = current_time;
      // Double-tap check
      if (current_time - m_last_tap_time_ <= m_config_.double_tap_timeout
        && m_down_points_[0].distance(m_last_tap_point_) < m_config_.touch_slop) {
        m_is_tap_ = false;
        m_last_tap_time_ = 0;
        return {GestureType::DOUBLE_TAP, m_down_points_[0], 1, 0, 0, m_active_modifiers_};
      } else {
        m_last_tap_time_ = current_time;
        m_last_tap_point_ = m_down_points_[0];
        m_is_tap_ = true;
        return {GestureType::TAP, m_down_points_[0], 1, 0, 0, m_active_modifiers_};
      }
    }

    // Mouse move (drag)
    case EventType::MOUSE_MOVE: {
      if (!m_is_mouse_down_ || event.points.empty()) {
        break;
      }
      const PointF& curr_point = event.points[0];
      if (curr_point.distance(m_last_move_point_) > m_config_.touch_slop || m_is_dragging_) {
        m_is_tap_ = false;
        m_is_dragging_ = true;
        m_last_move_point_ = curr_point;
        return {GestureType::DRAG_SELECT, curr_point, 1, 0, 0, m_active_modifiers_};
      }
      break;
    }

    // Mouse up
    case EventType::MOUSE_UP: {
      m_is_mouse_down_ = false;
      m_is_dragging_ = false;
      break;
    }

    // Mouse wheel
    case EventType::MOUSE_WHEEL: {
      // Ctrl + wheel = zoom
      if (static_cast<uint8_t>(event.modifiers & Modifier::CTRL)) {
        float scale = event.wheel_delta_y > 0 ? 1.1f : 0.9f;
        return {GestureType::SCALE, {}, scale, 0, 0, m_active_modifiers_};
      }
      // Normal wheel = scroll (Shift + wheel = horizontal scroll)
      float sx = event.wheel_delta_x;
      float sy = event.wheel_delta_y;
      if (static_cast<uint8_t>(event.modifiers & Modifier::SHIFT)) {
        sx = sy;
        sy = 0;
      }
      return {GestureType::SCROLL, {}, 1, -sx, -sy, m_active_modifiers_};
    }

    // Mouse right button
    case EventType::MOUSE_RIGHT_DOWN: {
      if (!event.points.empty()) {
        return {GestureType::CONTEXT_MENU, event.points[0], 1, 0, 0, m_active_modifiers_};
      }
      break;
    }

    // Platform direct scale
    case EventType::DIRECT_SCALE: {
      return {GestureType::SCALE, {}, event.direct_scale, 0, 0, m_active_modifiers_};
    }

    // Platform direct scroll
    case EventType::DIRECT_SCROLL: {
      return {GestureType::SCROLL, {}, 1, -event.wheel_delta_x, -event.wheel_delta_y, m_active_modifiers_};
    }

    // Touch down
    case EventType::TOUCH_DOWN: {
      m_down_points_ = event.points;
      m_down_time_ = current_time;
      m_last_move_point_ = m_down_points_[0];
      m_is_tap_ = true;
      m_is_dragging_ = false;
      break;
    }

    // Multi-touch pointer down
    case EventType::TOUCH_POINTER_DOWN: {
      m_down_points_ = event.points;
      m_last_multi_points_ = event.points;
      if (m_down_points_.size() > 1) {
        m_last_distance_ = m_down_points_[0].distance(m_down_points_[1]);
      }
      m_is_tap_ = false;
      m_is_scaling_ = false;
      m_is_fast_scrolling_ = false;
      m_pinch_confirm_count_ = 0;
      break;
    }

    // Multi-touch pointer up
    case EventType::TOUCH_POINTER_UP: {
      // Restore from multi-touch to single-touch: use the first point
      // to init single-touch state, so later TOUCH_MOVE delta is correct
      if (!event.points.empty()) {
        m_last_move_point_ = event.points[0];
        m_down_points_ = { event.points[0] };
      } else {
        m_down_points_.clear();
      }
      m_last_multi_points_.clear();
      m_is_tap_ = false;
      m_is_scaling_ = false;
      m_is_fast_scrolling_ = false;
      m_pinch_confirm_count_ = 0;
      m_last_distance_ = 0;
      break;
    }

    // Touch move
    case EventType::TOUCH_MOVE: {
      if (m_down_points_.size() == 1) {
        const PointF& curr_point = event.points[0];
        if (curr_point.distance(m_last_move_point_) > m_config_.touch_slop || m_is_dragging_) {
          m_is_tap_ = false;
          // If already in long-press state, later moves are drag-select
          if (m_is_dragging_) {
            m_last_move_point_ = curr_point;
            return {GestureType::DRAG_SELECT, curr_point};
          }
          // Normal scroll
          float scroll_x = curr_point.x - m_last_move_point_.x;
          float scroll_y = curr_point.y - m_last_move_point_.y;
          m_last_move_point_ = curr_point;
          return {GestureType::SCROLL, {}, 1, -scroll_x, -scroll_y};
        }
        // Check whether long-press threshold is reached
        if (m_is_tap_ && current_time - m_down_time_ > m_config_.long_press_ms) {
          m_is_tap_ = false;
          // Do not set m_is_dragging_ to avoid tiny move after long press
          // triggering DRAG_SELECT and selecting multiple lines
          return {GestureType::LONG_PRESS, m_down_points_[0]};
        }
      } else if (event.points.size() >= 2) {
        m_is_tap_ = false;
        const PointF& curr_point0 = event.points[0];
        const PointF& curr_point1 = event.points[1];

        // Locked in scale mode, keep scaling until fingers are lifted
        if (m_is_scaling_) {
          float curr_distance = curr_point0.distance(curr_point1);
          if (m_last_distance_ > 0) {
            float scale = curr_distance / m_last_distance_;
            m_last_distance_ = curr_distance;
            m_last_multi_points_ = event.points;
            return {GestureType::SCALE, {}, scale};
          }
          m_last_distance_ = curr_distance;
          m_last_multi_points_ = event.points;
          break;
        }

        // Locked in fast-scroll mode, keep scrolling until fingers are lifted
        if (m_is_fast_scrolling_) {
          if (m_last_multi_points_.size() >= 2) {
            float delta_x0 = curr_point0.x - m_last_multi_points_[0].x;
            float delta_y0 = curr_point0.y - m_last_multi_points_[0].y;
            float delta_x1 = curr_point1.x - m_last_multi_points_[1].x;
            float delta_y1 = curr_point1.y - m_last_multi_points_[1].y;
            float avg_dx = (delta_x0 + delta_x1) * 0.5f;
            float avg_dy = (delta_y0 + delta_y1) * 0.5f;
            m_last_multi_points_ = event.points;
            m_last_distance_ = curr_point0.distance(curr_point1);
            if (std::abs(avg_dx) > 0.5f || std::abs(avg_dy) > 0.5f) {
              if (std::abs(avg_dx) > std::abs(avg_dy)) {
                return {GestureType::FAST_SCROLL, {}, 1, -avg_dx};
              } else {
                return {GestureType::FAST_SCROLL, {}, 1, 0, -avg_dy};
              }
            }
          }
          m_last_multi_points_ = event.points;
          m_last_distance_ = curr_point0.distance(curr_point1);
          break;
        }

        // Not locked yet, decide frame by frame
        if (m_last_multi_points_.size() >= 2) {
          float delta_x0 = curr_point0.x - m_last_multi_points_[0].x;
          float delta_y0 = curr_point0.y - m_last_multi_points_[0].y;
          float delta_x1 = curr_point1.x - m_last_multi_points_[1].x;
          float delta_y1 = curr_point1.y - m_last_multi_points_[1].y;

          float curr_distance = curr_point0.distance(curr_point1);
          float distance_change = std::abs(curr_distance - m_last_distance_);

          // Centroid shift (average movement of two fingers)
          float avg_dx = (delta_x0 + delta_x1) * 0.5f;
          float avg_dy = (delta_y0 + delta_y1) * 0.5f;
          float pan_magnitude = std::sqrt(avg_dx * avg_dx + avg_dy * avg_dy);

          // Scale vs scroll decision:
          // - If spacing change passes threshold and is not too small vs pan,
          //   treat it as scale-dominant
          // Use a lower minimum threshold to make two-finger scale
          // trigger more stable on Android
          float pinch_threshold = m_config_.touch_slop * 0.25f;
          if (pinch_threshold < 1.5f) {
            pinch_threshold = 1.5f;
          }
          bool pinch_dominant = (distance_change > pinch_threshold) &&
                                (distance_change >= pan_magnitude * 0.35f);

          if (pinch_dominant) {
            m_is_scaling_ = true;
            m_is_fast_scrolling_ = false;
            m_pinch_confirm_count_ = 0;
            float base_distance = m_last_distance_ > 0 ? m_last_distance_ : curr_distance;
            float scale = curr_distance / base_distance;
            m_last_distance_ = curr_distance;
            m_last_multi_points_ = event.points;
            return {GestureType::SCALE, {}, scale};
          }

          m_pinch_confirm_count_ = 0;
          m_last_multi_points_ = event.points;
          m_last_distance_ = curr_distance;

          // If pan is large enough and not scale-dominant, lock fast-scroll mode
          if (pan_magnitude > m_config_.touch_slop && distance_change < pinch_threshold) {
            m_is_fast_scrolling_ = true;
          }

          if (std::abs(avg_dx) > 0.5f || std::abs(avg_dy) > 0.5f) {
            if (std::abs(avg_dx) > std::abs(avg_dy)) {
              return {GestureType::FAST_SCROLL, {}, 1, -avg_dx};
            } else {
              return {GestureType::FAST_SCROLL, {}, 1, 0, -avg_dy};
            }
          }
        }
        m_last_multi_points_ = event.points;
        if (m_last_distance_ <= 0) {
          m_last_distance_ = curr_point0.distance(curr_point1);
        }
      }
      break;
    }

    // Touch up
    case EventType::TOUCH_UP: {
      if (m_is_dragging_) {
        m_is_dragging_ = false;
        m_down_time_ = std::numeric_limits<int64_t>::max();
        break;
      }
      if (m_is_tap_) {
        // Double-tap check: use DOWN-to-DOWN timing to match
        // platform double_tap_timeout semantics
        if (m_down_time_ - m_last_tap_time_ <= m_config_.double_tap_timeout
            && m_down_points_[0].distance(m_last_tap_point_) < m_config_.touch_slop) {
          m_is_tap_ = false;
          m_last_tap_time_ = 0;
          return {GestureType::DOUBLE_TAP, m_down_points_[0]};
        } else {
          if (current_time - m_down_time_ > m_config_.long_press_ms) {
            return {GestureType::LONG_PRESS, m_down_points_[0]};
          } else {
            m_last_tap_time_ = m_down_time_;
            m_last_tap_point_ = m_down_points_[0];
            return {GestureType::TAP, m_last_tap_point_};
          }
        }
      }
      m_down_time_ = std::numeric_limits<int64_t>::max();
      break;
    }

    // Touch cancel
    case EventType::TOUCH_CANCEL: {
      resetState();
      break;
    }

    default:
      break;
    }
    return {};
  }
#pragma endregion
}
