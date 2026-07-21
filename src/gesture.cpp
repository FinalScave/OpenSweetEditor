//
// Created by Scave on 2025/12/6.
//

#include <cmath>
#include <sweeteditor/gesture.h>
#include <sweeteditor/utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

  bool isMousePointerEvent(EventType type) {
    switch (type) {
    case EventType::MOUSE_DOWN:
    case EventType::MOUSE_MOVE:
    case EventType::MOUSE_UP:
    case EventType::MOUSE_WHEEL:
    case EventType::MOUSE_RIGHT_DOWN:
      return true;
    default:
      return false;
    }
  }

  bool isPrimaryPointerDown(EventType type) {
    return type == EventType::TOUCH_DOWN || type == EventType::MOUSE_DOWN;
  }

  bool isPrimaryPointerMove(EventType type) {
    return type == EventType::TOUCH_MOVE || type == EventType::MOUSE_MOVE;
  }

  bool isPrimaryPointerEnd(EventType type) {
    return type == EventType::TOUCH_UP || type == EventType::MOUSE_UP || type == EventType::TOUCH_CANCEL;
  }

  bool HitTarget::operator==(const HitTarget& other) const {
    return type == other.type && line == other.line && column == other.column && icon_id == other.icon_id
           && color_value == other.color_value;
  }

  bool HitTarget::operator!=(const HitTarget& other) const {
    return !(*this == other);
  }

#pragma region[Class: GestureEvent]
  GestureEvent GestureEvent::create(EventType type, const uint8_t pointer_count, const float* points) {
    return createWithModifiers(type, pointer_count, points, KeyModifier::NONE);
  }

  GestureEvent GestureEvent::createWithModifiers(EventType type, const uint8_t pointer_count, const float* points,
                                                 KeyModifier modifiers) {
    GestureEvent event;
    event.type = type;
    event.modifiers = modifiers;
    for (uint8_t i = 0; i < pointer_count; i++) {
      event.points.push_back({points[i * 2], points[i * 2 + 1]});
    }
    return event;
  }

  U8String GestureEvent::dump() const {
    return "GestureEvent {type = " + std::to_string(static_cast<int32_t>(type)) + ", point size = "
           + std::to_string(points.size()) + ", modifiers = " + std::to_string(static_cast<uint8_t>(modifiers)) + "}";
  }
#pragma endregion

#pragma region[Class: GestureHandler]
  GestureHandler::GestureHandler(const TouchConfig& config)
      : m_config_(config) {
  }

  void GestureHandler::resetState() {
    m_is_tap_ = false;
    m_is_mouse_down_ = false;
    m_is_dragging_ = false;
    m_is_scaling_ = false;
    m_is_fast_scrolling_ = false;
    m_is_scrolling_ = false;
    m_pinch_confirm_count_ = 0;
    m_last_multi_points_.clear();
    m_down_points_.clear();
    m_down_time_ = std::numeric_limits<int64_t>::max();
    m_active_modifiers_ = KeyModifier::NONE;
  }

  GestureResult GestureHandler::handleGestureEvent(const GestureEvent& event) {
    if (event.points.empty() && event.type != EventType::MOUSE_WHEEL && event.type != EventType::DIRECT_SCALE
        && event.type != EventType::DIRECT_SCROLL && event.type != EventType::TOUCH_CANCEL) {
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
      if (static_cast<uint8_t>(event.modifiers & KeyModifier::CTRL)) {
        float scale = event.wheel_delta_y > 0 ? 1.1f : 0.9f;
        return {GestureType::SCALE, {}, scale, 0, 0, m_active_modifiers_};
      }
      // Normal wheel = scroll (Shift + wheel = horizontal scroll)
      float sx = event.wheel_delta_x;
      float sy = event.wheel_delta_y;
      if (static_cast<uint8_t>(event.modifiers & KeyModifier::SHIFT)) {
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
      m_is_scrolling_ = false;
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
        m_down_points_ = {event.points[0]};
      } else {
        m_down_points_.clear();
      }
      m_last_multi_points_.clear();
      m_is_tap_ = false;
      m_is_scaling_ = false;
      m_is_fast_scrolling_ = false;
      m_is_scrolling_ = false;
      m_pinch_confirm_count_ = 0;
      m_last_distance_ = 0;
      break;
    }

    // Touch move
    case EventType::TOUCH_MOVE: {
      if (m_down_points_.size() == 1) {
        const PointF& curr_point = event.points[0];
        if (curr_point.distance(m_last_move_point_) > m_config_.touch_slop || m_is_dragging_ || m_is_scrolling_) {
          m_is_tap_ = false;
          // If already in long-press state, later moves are drag-select
          if (m_is_dragging_) {
            m_last_move_point_ = curr_point;
            return {GestureType::DRAG_SELECT, curr_point};
          }
          // First frame crossing slop: absorb the accumulated delta
          if (!m_is_scrolling_) {
            m_is_scrolling_ = true;
            m_last_move_point_ = curr_point;
            return {GestureType::SCROLL, {}, 1, 0, 0};
          }
          // Subsequent frames: use real delta
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
      } else if (event.points.size() == 2) {
        // Two-finger: pure scale (no ambiguity with fast-scroll)
        m_is_tap_ = false;
        const PointF& curr_point0 = event.points[0];
        const PointF& curr_point1 = event.points[1];
        float curr_distance = curr_point0.distance(curr_point1);

        if (m_last_distance_ > 0) {
          float scale = curr_distance / m_last_distance_;
          m_last_distance_ = curr_distance;
          m_last_multi_points_ = event.points;
          m_is_scaling_ = true;
          return {GestureType::SCALE, {}, scale};
        }
        m_last_distance_ = curr_distance;
        m_last_multi_points_ = event.points;
      } else if (event.points.size() >= 3) {
        // Three-finger (or more): fast scroll
        m_is_tap_ = false;
        const PointF& curr_point0 = event.points[0];
        const PointF& curr_point1 = event.points[1];

        if (m_last_multi_points_.size() >= 2) {
          float delta_x0 = curr_point0.x - m_last_multi_points_[0].x;
          float delta_y0 = curr_point0.y - m_last_multi_points_[0].y;
          float delta_x1 = curr_point1.x - m_last_multi_points_[1].x;
          float delta_y1 = curr_point1.y - m_last_multi_points_[1].y;
          float avg_dx = (delta_x0 + delta_x1) * 0.5f;
          float avg_dy = (delta_y0 + delta_y1) * 0.5f;
          m_last_multi_points_ = event.points;
          m_is_fast_scrolling_ = true;

          if (std::abs(avg_dx) > 0.5f || std::abs(avg_dy) > 0.5f) {
            if (std::abs(avg_dx) > std::abs(avg_dy)) {
              return {GestureType::FAST_SCROLL, {}, 1, -avg_dx};
            } else {
              return {GestureType::FAST_SCROLL, {}, 1, 0, -avg_dy};
            }
          }
        }
        m_last_multi_points_ = event.points;
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

#pragma region[Class: FlingAnimator]
  FlingAnimator::FlingAnimator(const TouchConfig& config)
      : m_config_(config) {
  }

  void FlingAnimator::recordSample(const PointF& point, int64_t timestamp_ms) {
    if (m_sample_count_ < kMaxSamples) {
      m_samples_[m_sample_count_++] = {point, timestamp_ms};
    } else {
      for (int i = 1; i < kMaxSamples; ++i) {
        m_samples_[i - 1] = m_samples_[i];
      }
      m_samples_[kMaxSamples - 1] = {point, timestamp_ms};
    }
  }

  void FlingAnimator::resetSamples() {
    m_sample_count_ = 0;
  }

  void FlingAnimator::computeVelocity(float& vx, float& vy) const {
    vx = 0;
    vy = 0;
    if (m_sample_count_ < 2) return;

    float weighted_vx = 0;
    float weighted_vy = 0;
    float weight_sum = 0;
    for (int i = 1; i < m_sample_count_; ++i) {
      float dt = static_cast<float>(m_samples_[i].timestamp_ms - m_samples_[i - 1].timestamp_ms);
      if (dt <= 0) continue;
      float seg_vx = (m_samples_[i].point.x - m_samples_[i - 1].point.x) / dt * 1000.0f;
      float seg_vy = (m_samples_[i].point.y - m_samples_[i - 1].point.y) / dt * 1000.0f;
      float w = static_cast<float>(i);
      weighted_vx += seg_vx * w;
      weighted_vy += seg_vy * w;
      weight_sum += w;
    }
    if (weight_sum <= 0) return;

    vx = weighted_vx / weight_sum;
    vy = weighted_vy / weight_sum;
  }

  bool FlingAnimator::start() {
    float vx = 0, vy = 0;
    computeVelocity(vx, vy);

    float speed = std::sqrt(vx * vx + vy * vy);
    if (speed < m_config_.fling_min_velocity) {
      m_active_ = false;
      return false;
    }

    // Clamp velocity magnitude to max
    if (speed > m_config_.fling_max_velocity) {
      float ratio = m_config_.fling_max_velocity / speed;
      vx *= ratio;
      vy *= ratio;
    }

    m_velocity_x_ = vx;
    m_velocity_y_ = vy;
    m_elapsed_ms_ = 0;
    m_last_tick_time_ = TimeUtil::milliTime();
    m_active_ = true;
    return true;
  }

  bool FlingAnimator::advance(float& out_dx, float& out_dy) {
    if (!m_active_) {
      out_dx = 0;
      out_dy = 0;
      return false;
    }

    int64_t now = TimeUtil::milliTime();
    float dt_ms = static_cast<float>(now - m_last_tick_time_);
    if (dt_ms <= 0) dt_ms = 1.0f;
    m_last_tick_time_ = now;

    float t0 = m_elapsed_ms_ / 1000.0f;
    float t1 = (m_elapsed_ms_ + dt_ms) / 1000.0f;
    float friction = m_config_.fling_friction;

    float e0 = std::exp(-friction * t0);
    float e1 = std::exp(-friction * t1);
    float factor = (e0 - e1) / friction;

    out_dx = m_velocity_x_ * factor;
    out_dy = m_velocity_y_ * factor;

    // Stop early when per-frame displacement is sub-pixel to prevent tail jitter
    if (std::abs(out_dx) + std::abs(out_dy) < 0.5f) {
      m_active_ = false;
      out_dx = 0;
      out_dy = 0;
      return false;
    }

    m_elapsed_ms_ += dt_ms;

    float current_vx = m_velocity_x_ * e1;
    float current_vy = m_velocity_y_ * e1;
    float current_speed = std::sqrt(current_vx * current_vx + current_vy * current_vy);
    if (current_speed < m_config_.fling_min_velocity) {
      m_active_ = false;
      return false;
    }
    return true;
  }

  void FlingAnimator::stop() {
    m_active_ = false;
    m_velocity_x_ = 0;
    m_velocity_y_ = 0;
    m_elapsed_ms_ = 0;
    m_last_tick_time_ = 0;
  }

  bool FlingAnimator::isActive() const {
    return m_active_;
  }
#pragma endregion
}
