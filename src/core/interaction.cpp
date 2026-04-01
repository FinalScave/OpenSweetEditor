//
// Created by Codex on 2026/4/1.
//
#include <algorithm>
#include <chrono>
#include <cmath>
#include <interaction.h>
#include <editor_core.h>
#include <layout.h>
#include <utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

  static bool pointInScrollbarRect(const PointF& point, const ScrollbarRect& rect, float expand = 0.0f) {
    if (rect.width <= 0.0f || rect.height <= 0.0f) return false;
    const float left = rect.origin.x - expand;
    const float right = rect.origin.x + rect.width + expand;
    const float top = rect.origin.y - expand;
    const float bottom = rect.origin.y + rect.height + expand;
    return point.x >= left && point.x <= right
        && point.y >= top && point.y <= bottom;
  }

  static int64_t monotonicNowMs() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
  }

  EditorInteraction::EditorInteraction(const InteractionContext& context)
      : m_context_(context),
        m_gesture_handler_(makeUPtr<GestureHandler>(context.touch_config)),
        m_fling_(makeUPtr<FlingAnimator>(context.touch_config)) {
  }

  void EditorInteraction::setSelection(const TextRange& range) {
    m_selection_ = range;
    m_has_selection_ = !(range.start == range.end);
  }

  void EditorInteraction::clearSelection() {
    m_selection_ = {};
    m_has_selection_ = false;
  }

  const TextRange& EditorInteraction::selection() const {
    return m_selection_;
  }

  bool EditorInteraction::hasSelection() const {
    return m_has_selection_;
  }

  void EditorInteraction::markScrollbarInteraction() {
    const int64_t now_ms = monotonicNowMs();
    const int64_t hide_window_ms =
        static_cast<int64_t>(m_context_.settings->scrollbar.fade_delay_ms) +
        std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
    if (m_scrollbar_last_interaction_ms_ <= 0
        || m_scrollbar_cycle_start_ms_ <= 0
        || now_ms - m_scrollbar_last_interaction_ms_ > hide_window_ms) {
      m_scrollbar_cycle_start_ms_ = now_ms;
    }
    m_scrollbar_last_interaction_ms_ = now_ms;
  }

  void EditorInteraction::computeScrollbarModels(ScrollbarModel& vertical,
                                                 ScrollbarModel& horizontal) const {
    vertical = ScrollbarModel {};
    horizontal = ScrollbarModel {};
    if (!m_context_.viewport->valid() || m_context_.text_layout == nullptr) {
      return;
    }

    const float scrollbar_thickness = std::max(1.0f, m_context_.settings->scrollbar.thickness);
    const float scrollbar_min_thumb = std::max(scrollbar_thickness, m_context_.settings->scrollbar.min_thumb);

    const ScrollBounds bounds = m_context_.text_layout->getScrollBounds();
    const bool logical_vertical = bounds.max_scroll_y > 0.0f;
    const bool logical_horizontal = bounds.max_scroll_x > 0.0f;
    const int64_t now_ms = monotonicNowMs();
    const auto axisAlpha = [&](bool logical_visible, ScrollbarDragTarget drag_target) -> float {
      if (!logical_visible) return 0.0f;
      switch (m_context_.settings->scrollbar.mode) {
      case ScrollbarMode::ALWAYS:
        return 1.0f;
      case ScrollbarMode::NEVER:
        return 0.0f;
      case ScrollbarMode::TRANSIENT: {
        if (m_dragging_scrollbar_ == drag_target) return 1.0f;
        if (m_scrollbar_last_interaction_ms_ <= 0) return 0.0f;

        const int64_t fade_ms = std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
        const int64_t delay_ms = static_cast<int64_t>(m_context_.settings->scrollbar.fade_delay_ms);
        const int64_t elapsed_since_last = std::max<int64_t>(0, now_ms - m_scrollbar_last_interaction_ms_);
        if (elapsed_since_last >= delay_ms + fade_ms) {
          return 0.0f;
        }

        float fade_out_alpha = 1.0f;
        if (elapsed_since_last > delay_ms) {
          fade_out_alpha = 1.0f - static_cast<float>(elapsed_since_last - delay_ms) / static_cast<float>(fade_ms);
        }

        float fade_in_alpha = 1.0f;
        if (m_scrollbar_cycle_start_ms_ > 0) {
          const int64_t elapsed_since_cycle = std::max<int64_t>(0, now_ms - m_scrollbar_cycle_start_ms_);
          fade_in_alpha = std::min(1.0f, static_cast<float>(elapsed_since_cycle + 16) / static_cast<float>(fade_ms));
        }
        return std::clamp(std::min(fade_in_alpha, fade_out_alpha), 0.0f, 1.0f);
      }
      }
      return 1.0f;
    };
    const float vertical_alpha = axisAlpha(logical_vertical, ScrollbarDragTarget::VERTICAL);
    const float horizontal_alpha = axisAlpha(logical_horizontal, ScrollbarDragTarget::HORIZONTAL);
    const bool show_vertical = vertical_alpha > 0.0f;
    const bool show_horizontal = horizontal_alpha > 0.0f;
    const float viewport_width = m_context_.viewport->width;
    const float viewport_height = m_context_.viewport->height;

    const float vertical_track_x = viewport_width - scrollbar_thickness;
    const float vertical_track_height = viewport_height - (show_horizontal ? scrollbar_thickness : 0.0f);
    if (show_vertical && vertical_track_height > 0.0f) {
      vertical.visible = true;
      vertical.alpha = vertical_alpha;
      vertical.thumb_active = (m_dragging_scrollbar_ == ScrollbarDragTarget::VERTICAL);
      vertical.track.origin = {vertical_track_x, 0.0f};
      vertical.track.width = scrollbar_thickness;
      vertical.track.height = vertical_track_height;

      const float viewport = std::max(1.0f, viewport_height);
      const float content_span = std::max(viewport, bounds.max_scroll_y + viewport);
      float thumb_height = std::max(scrollbar_min_thumb, vertical_track_height * viewport / content_span);
      thumb_height = std::min(thumb_height, vertical_track_height);
      const float travel = std::max(0.0f, vertical_track_height - thumb_height);
      const float ratio = bounds.max_scroll_y <= 0.0f
          ? 0.0f
          : std::clamp(m_context_.view_state->scroll_y / bounds.max_scroll_y, 0.0f, 1.0f);
      const float thumb_y = travel <= 0.0f ? 0.0f : travel * ratio;
      vertical.thumb.origin = {vertical_track_x, thumb_y};
      vertical.thumb.width = scrollbar_thickness;
      vertical.thumb.height = thumb_height;
    }

    const float horizontal_track_x = m_context_.settings->gutter_sticky ? std::max(0.0f, bounds.text_area_x) : 0.0f;
    const float horizontal_track_width = viewport_width - horizontal_track_x - (show_vertical ? scrollbar_thickness : 0.0f);
    const float horizontal_track_y = viewport_height - scrollbar_thickness;
    if (show_horizontal && horizontal_track_width > 0.0f && horizontal_track_y >= 0.0f) {
      horizontal.visible = true;
      horizontal.alpha = horizontal_alpha;
      horizontal.thumb_active = (m_dragging_scrollbar_ == ScrollbarDragTarget::HORIZONTAL);
      horizontal.track.origin = {horizontal_track_x, horizontal_track_y};
      horizontal.track.width = horizontal_track_width;
      horizontal.track.height = scrollbar_thickness;

      const float viewport = std::max(1.0f, bounds.text_area_width);
      const float content_span = std::max(viewport, bounds.max_scroll_x + viewport);
      float thumb_width = std::max(scrollbar_min_thumb, horizontal_track_width * viewport / content_span);
      thumb_width = std::min(thumb_width, horizontal_track_width);
      const float travel = std::max(0.0f, horizontal_track_width - thumb_width);
      const float ratio = bounds.max_scroll_x <= 0.0f
          ? 0.0f
          : std::clamp(m_context_.view_state->scroll_x / bounds.max_scroll_x, 0.0f, 1.0f);
      const float thumb_x = horizontal_track_x + (travel <= 0.0f ? 0.0f : travel * ratio);
      horizontal.thumb.origin = {thumb_x, horizontal_track_y};
      horizontal.thumb.width = thumb_width;
      horizontal.thumb.height = scrollbar_thickness;
    }
  }

  void EditorInteraction::fillGestureResult(const TextPosition& cursor_position, GestureResult& result) const {
    result.cursor_position = cursor_position;
    result.has_selection = m_has_selection_;
    result.selection = m_selection_;
    result.view_scroll_x = m_context_.view_state->scroll_x;
    result.view_scroll_y = m_context_.view_state->scroll_y;
    result.view_scale = m_context_.view_state->scale;
    result.is_handle_drag = (m_dragging_handle_ != HandleDragTarget::NONE);
  }

  PointF EditorInteraction::resolveScaleFocus(const GestureEvent& event) const {
    if (event.points.size() >= 2) {
      return {
          (event.points[0].x + event.points[1].x) * 0.5f,
          (event.points[0].y + event.points[1].y) * 0.5f
      };
    }
    if (!event.points.empty()) {
      return event.points[0];
    }
    return {m_context_.viewport->width * 0.5f, m_context_.viewport->height * 0.5f};
  }

  bool EditorInteraction::handleScrollbarGesture(TextPosition& cursor_position,
                                                 const GestureEvent& event,
                                                 GestureResult& result) {
    if (m_context_.text_layout == nullptr || !m_context_.viewport->valid()) {
      return false;
    }
    if (m_dragging_handle_ != HandleDragTarget::NONE
        && m_dragging_scrollbar_ == ScrollbarDragTarget::NONE) {
      return false;
    }

    const auto consume = [&](GestureType type) {
      result.type = type;
      fillGestureResult(cursor_position, result);
      return true;
    };

    ScrollbarModel vertical;
    ScrollbarModel horizontal;
    computeScrollbarModels(vertical, horizontal);
    const ScrollBounds bounds = m_context_.text_layout->getScrollBounds();

    switch (event.type) {
    case EventType::TOUCH_DOWN:
    case EventType::MOUSE_DOWN: {
      if (event.points.empty()) return false;
      const PointF& point = event.points[0];
      const float thumb_hit_padding = m_context_.settings->scrollbar.thumb_hit_padding;

      if (vertical.visible
          && m_context_.settings->scrollbar.thumb_draggable
          && pointInScrollbarRect(point, vertical.thumb, thumb_hit_padding)) {
        m_dragging_scrollbar_ = ScrollbarDragTarget::VERTICAL;
        m_scrollbar_drag_start_point_ = point;
        m_scrollbar_drag_start_scroll_y_ = m_context_.view_state->scroll_y;
        m_scrollbar_drag_travel_y_ = std::max(0.0f, vertical.track.height - vertical.thumb.height);
        m_scrollbar_drag_max_scroll_y_ = std::max(0.0f, bounds.max_scroll_y);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        m_gesture_handler_->resetState();
        return consume(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_context_.settings->scrollbar.thumb_draggable
          && pointInScrollbarRect(point, horizontal.thumb, thumb_hit_padding)) {
        m_dragging_scrollbar_ = ScrollbarDragTarget::HORIZONTAL;
        m_scrollbar_drag_start_point_ = point;
        m_scrollbar_drag_start_scroll_x_ = m_context_.view_state->scroll_x;
        m_scrollbar_drag_travel_x_ = std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
        m_scrollbar_drag_max_scroll_x_ = std::max(0.0f, bounds.max_scroll_x);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        m_gesture_handler_->resetState();
        return consume(GestureType::UNDEFINED);
      }

      if (vertical.visible
          && m_context_.settings->scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInScrollbarRect(point, vertical.track)) {
        if (vertical.track.height > 0.0f && bounds.max_scroll_y > 0.0f) {
          const float travel = std::max(0.0f, vertical.track.height - vertical.thumb.height);
          const float ratio = travel <= 0.0f
              ? 0.0f
              : std::clamp((point.y - vertical.track.origin.y - vertical.thumb.height * 0.5f) / travel, 0.0f, 1.0f);
          m_context_.view_state->scroll_y = ratio * bounds.max_scroll_y;
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
          m_edge_scroll_.active = false;
          markScrollbarInteraction();
          return consume(GestureType::SCROLL);
        }
        markScrollbarInteraction();
        return consume(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_context_.settings->scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInScrollbarRect(point, horizontal.track)) {
        if (horizontal.track.width > 0.0f && bounds.max_scroll_x > 0.0f) {
          const float travel = std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
          const float ratio = travel <= 0.0f
              ? 0.0f
              : std::clamp((point.x - horizontal.track.origin.x - horizontal.thumb.width * 0.5f) / travel, 0.0f, 1.0f);
          m_context_.view_state->scroll_x = ratio * bounds.max_scroll_x;
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
          m_edge_scroll_.active = false;
          markScrollbarInteraction();
          return consume(GestureType::SCROLL);
        }
        markScrollbarInteraction();
        return consume(GestureType::UNDEFINED);
      }
      return false;
    }

    case EventType::TOUCH_MOVE:
    case EventType::MOUSE_MOVE: {
      if (m_dragging_scrollbar_ == ScrollbarDragTarget::NONE) {
        return false;
      }
      if (event.points.empty()) {
        return consume(GestureType::UNDEFINED);
      }
      const PointF& point = event.points[0];
      if (m_dragging_scrollbar_ == ScrollbarDragTarget::VERTICAL) {
        float target_y = m_scrollbar_drag_start_scroll_y_;
        if (m_scrollbar_drag_travel_y_ > 0.0f && m_scrollbar_drag_max_scroll_y_ > 0.0f) {
          const float delta = point.y - m_scrollbar_drag_start_point_.y;
          target_y += delta * m_scrollbar_drag_max_scroll_y_ / m_scrollbar_drag_travel_y_;
        }
        m_context_.view_state->scroll_y = std::clamp(target_y, 0.0f, bounds.max_scroll_y);
        m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        return consume(GestureType::SCROLL);
      }
      if (m_dragging_scrollbar_ == ScrollbarDragTarget::HORIZONTAL) {
        float target_x = m_scrollbar_drag_start_scroll_x_;
        if (m_scrollbar_drag_travel_x_ > 0.0f && m_scrollbar_drag_max_scroll_x_ > 0.0f) {
          const float delta = point.x - m_scrollbar_drag_start_point_.x;
          target_x += delta * m_scrollbar_drag_max_scroll_x_ / m_scrollbar_drag_travel_x_;
        }
        m_context_.view_state->scroll_x = std::clamp(target_x, 0.0f, bounds.max_scroll_x);
        m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        return consume(GestureType::SCROLL);
      }
      return consume(GestureType::UNDEFINED);
    }

    case EventType::TOUCH_POINTER_DOWN: {
      if (m_dragging_scrollbar_ != ScrollbarDragTarget::NONE) {
        m_dragging_scrollbar_ = ScrollbarDragTarget::NONE;
        m_gesture_handler_->resetState();
        return consume(GestureType::UNDEFINED);
      }
      return false;
    }

    case EventType::TOUCH_UP:
    case EventType::MOUSE_UP:
    case EventType::TOUCH_CANCEL: {
      if (m_dragging_scrollbar_ == ScrollbarDragTarget::NONE) {
        return false;
      }
      m_dragging_scrollbar_ = ScrollbarDragTarget::NONE;
      m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
      m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
      m_context_.text_layout->normalizeViewState(*m_context_.view_state);
      m_edge_scroll_.active = false;
      m_gesture_handler_->resetState();
      return consume(GestureType::UNDEFINED);
    }

    default:
      return false;
    }
  }

  EditorInteraction::HandleDragTarget EditorInteraction::hitTestHandle(const PointF& screen_point) const {
    if (!m_cached_handles_valid_ || !m_has_selection_) return HandleDragTarget::NONE;

    const auto& start_rect = m_context_.settings->handle.start_hit_offset;
    const auto& end_rect = m_context_.settings->handle.end_hit_offset;
    const float h = m_cached_handle_height_;

    auto hitTest = [&](const PointF& pos, const OffsetRect& rect) -> bool {
      float dx = screen_point.x - pos.x;
      float dy = screen_point.y - (pos.y + h);
      return rect.contains(dx, dy);
    };

    float dist_start = screen_point.distance(m_cached_start_handle_pos_);
    float dist_end = screen_point.distance(m_cached_end_handle_pos_);

    if (dist_start <= dist_end) {
      if (hitTest(m_cached_start_handle_pos_, start_rect)) return HandleDragTarget::START;
      if (hitTest(m_cached_end_handle_pos_, end_rect)) return HandleDragTarget::END;
    } else {
      if (hitTest(m_cached_end_handle_pos_, end_rect)) return HandleDragTarget::END;
      if (hitTest(m_cached_start_handle_pos_, start_rect)) return HandleDragTarget::START;
    }
    return HandleDragTarget::NONE;
  }

  void EditorInteraction::dragHandleTo(TextPosition& cursor_position,
                                       HandleDragTarget target,
                                       const PointF& screen_point) {
    if (!m_has_selection_ || target == HandleDragTarget::NONE) return;

    const auto& hit_rect = (target == HandleDragTarget::START)
        ? m_context_.settings->handle.start_hit_offset
        : m_context_.settings->handle.end_hit_offset;

    PointF adjusted_point = screen_point;
    adjusted_point.y -= hit_rect.bottom;

    TextPosition pos = m_context_.text_layout->hitTest(adjusted_point);
    TextRange selection = m_selection_;
    TextPosition sel_start = selection.start;
    TextPosition sel_end = selection.end;
    bool swapped = sel_end < sel_start;
    if (swapped) std::swap(sel_start, sel_end);

    if (target == HandleDragTarget::START) {
      sel_start = pos;
    } else {
      sel_end = pos;
    }

    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
      m_dragging_handle_ = (target == HandleDragTarget::START) ? HandleDragTarget::END : HandleDragTarget::START;
    }

    setSelection({sel_start, sel_end});
    cursor_position = (m_dragging_handle_ == HandleDragTarget::END) ? sel_end : sel_start;

    updateEdgeScrollState(screen_point, /*is_handle_drag=*/true, /*is_mouse=*/false);

    LOGD("EditorInteraction::dragHandleTo, selection = %s", m_selection_.dump().c_str());
  }

  void EditorInteraction::dragSelectTo(TextPosition& cursor_position, const PointF& screen_point, bool is_mouse) {
    PointF adjusted_point = screen_point;
    if (!is_mouse) {
      const float hit_bottom = std::max(m_context_.settings->handle.start_hit_offset.bottom,
                                        m_context_.settings->handle.end_hit_offset.bottom);
      adjusted_point.y -= hit_bottom;
    }

    TextPosition pos = m_context_.text_layout->hitTest(adjusted_point);

    if (!m_has_selection_) {
      setSelection({cursor_position, pos});
    } else {
      setSelection({m_selection_.start, pos});
    }
    cursor_position = pos;

    updateEdgeScrollState(screen_point, /*is_handle_drag=*/false, is_mouse);

    LOGD("EditorInteraction::dragSelectTo, selection = %s", m_selection_.dump().c_str());
  }

  void EditorInteraction::updateEdgeScrollState(const PointF& screen_point,
                                                bool is_handle_drag,
                                                bool is_mouse) {
    if (!m_context_.viewport->valid() || m_context_.text_layout == nullptr) {
      m_edge_scroll_.active = false;
      return;
    }

    const float kEdgeZoneRatio = 0.15f;
    const float kMinEdgeZone = 30.0f;
    const float kMaxEdgeZone = 120.0f;
    float edge_zone = std::clamp(m_context_.viewport->height * kEdgeZoneRatio, kMinEdgeZone, kMaxEdgeZone);

    const float line_height = m_context_.text_layout->getLineHeight();
    const float max_speed_per_sec = (line_height * 2.0f) / 0.016f;

    float speed = 0.0f;
    if (screen_point.y < edge_zone) {
      float ratio = (edge_zone - screen_point.y) / edge_zone;
      speed = -max_speed_per_sec * ratio;
    } else if (screen_point.y > m_context_.viewport->height - edge_zone) {
      float ratio = (screen_point.y - (m_context_.viewport->height - edge_zone)) / edge_zone;
      speed = max_speed_per_sec * ratio;
    }

    if (speed != 0.0f) {
      m_edge_scroll_.active = true;
      m_edge_scroll_.speed = speed;
      m_edge_scroll_.last_screen_point = screen_point;
      m_edge_scroll_.is_handle_drag = is_handle_drag;
      m_edge_scroll_.is_mouse = is_mouse;
      if (m_edge_scroll_.last_tick_time == 0) {
        m_edge_scroll_.last_tick_time = TimeUtil::milliTime();
      }
    } else {
      m_edge_scroll_.active = false;
      m_edge_scroll_.speed = 0.0f;
      m_edge_scroll_.last_tick_time = 0;
    }
  }

  GestureResult EditorInteraction::handleGestureEvent(EditorCore& core, const GestureEvent& event) {
    PERF_TIMER("handleGestureEvent");
    GestureResult gesture_result;

    if (handleScrollbarGesture(core.m_cursor_position_, event, gesture_result)) {
      return gesture_result;
    }

    if (event.type == EventType::TOUCH_DOWN || event.type == EventType::MOUSE_DOWN) {
      m_fling_->stop();
      m_fling_->resetSamples();
      if (!event.points.empty()) {
        m_dragging_handle_ = hitTestHandle(event.points[0]);
      }
    }
    if (m_dragging_handle_ != HandleDragTarget::NONE
        && event.type == EventType::TOUCH_POINTER_DOWN) {
      m_dragging_handle_ = HandleDragTarget::NONE;
      m_edge_scroll_.active = false;
    }

    if (m_dragging_handle_ != HandleDragTarget::NONE) {
      if (event.type == EventType::TOUCH_MOVE || event.type == EventType::MOUSE_MOVE) {
        if (!event.points.empty()) {
          dragHandleTo(core.m_cursor_position_, m_dragging_handle_, event.points[0]);
          m_context_.text_layout->setViewState(*m_context_.view_state);
          gesture_result.type = GestureType::DRAG_SELECT;
          gesture_result.is_handle_drag = true;
          fillGestureResult(core.m_cursor_position_, gesture_result);
          gesture_result.needs_edge_scroll = m_edge_scroll_.active;
          gesture_result.needs_animation = m_edge_scroll_.active;
          return gesture_result;
        }
      }
      if (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
          || event.type == EventType::TOUCH_CANCEL) {
        m_dragging_handle_ = HandleDragTarget::NONE;
        m_edge_scroll_.active = false;
        m_gesture_handler_->resetState();
        m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
        m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
        m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        fillGestureResult(core.m_cursor_position_, gesture_result);
        return gesture_result;
      }
    }
    GestureResult result = m_gesture_handler_->handleGestureEvent(event);

    if (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
        || event.type == EventType::TOUCH_CANCEL) {
      m_edge_scroll_.active = false;
      if (event.type == EventType::TOUCH_UP && result.type == GestureType::UNDEFINED && !m_edge_scroll_.active) {
        m_fling_->start();
      }
    }

    if (m_dragging_handle_ != HandleDragTarget::NONE) {
      m_context_.text_layout->setViewState(*m_context_.view_state);
      fillGestureResult(core.m_cursor_position_, result);
      return result;
    }

    switch (result.type) {
    case GestureType::TAP:
      if (static_cast<uint8_t>(result.modifiers & KeyModifier::SHIFT) && m_has_selection_) {
        bool is_mouse_tap = (event.type == EventType::MOUSE_DOWN);
        dragSelectTo(core.m_cursor_position_, result.tap_point, is_mouse_tap);
      } else {
        if (core.m_linked_editing_session_ && core.m_linked_editing_session_->isActive()) {
          TextPosition tap_pos = m_context_.text_layout->hitTest(result.tap_point);
          bool in_tab_stop = false;
          auto highlights = core.m_linked_editing_session_->getAllHighlights();
          for (const auto& hl : highlights) {
            if (hl.range.contains(tap_pos)) {
              in_tab_stop = true;
              break;
            }
          }
          if (!in_tab_stop) {
            core.cancelLinkedEditing();
          }
        }
        core.placeCursorAt(result.tap_point);
      }
      result.hit_target = m_context_.text_layout->hitTestDecoration(result.tap_point);
      if (result.hit_target.type == HitTargetType::FOLD_PLACEHOLDER ||
          result.hit_target.type == HitTargetType::FOLD_GUTTER) {
        core.toggleFoldAt(result.hit_target.line);
      }
      break;
    case GestureType::DOUBLE_TAP:
      core.selectWordAt(result.tap_point);
      break;
    case GestureType::LONG_PRESS:
      core.placeCursorAt(result.tap_point);
      break;
    case GestureType::DRAG_SELECT: {
      bool is_mouse = (event.type == EventType::MOUSE_MOVE);
      dragSelectTo(core.m_cursor_position_, result.tap_point, is_mouse);
      break;
    }
    case GestureType::SCALE: {
      const PointF focus_screen = resolveScaleFocus(event);
      TextPosition anchor_position = m_context_.text_layout->hitTest(focus_screen);
      CursorRect anchor_rect = core.getPositionScreenRect(anchor_position);
      m_pending_scale_anchor_.active = true;
      m_pending_scale_anchor_.focus_screen = focus_screen;
      m_pending_scale_anchor_.anchor_position = anchor_position;
      m_pending_scale_anchor_.offset_x = focus_screen.x - anchor_rect.x;
      m_pending_scale_anchor_.offset_y = focus_screen.y - anchor_rect.y;
      m_scale_gesture_active_ = (event.type == EventType::TOUCH_MOVE && event.points.size() >= 2);
      m_context_.view_state->scale = std::max(1.0f, std::min(m_context_.settings->max_scale, m_context_.view_state->scale * result.scale));
      break;
    }
    case GestureType::SCROLL:
      m_context_.view_state->scroll_x += result.scroll_x;
      m_context_.view_state->scroll_y += result.scroll_y;
      markScrollbarInteraction();
      if (event.type == EventType::TOUCH_MOVE && !event.points.empty()) {
        m_fling_->recordSample(event.points[0], TimeUtil::milliTime());
      }
      break;
    case GestureType::FAST_SCROLL: {
      constexpr float kFastScrollMultiplier = 3.0f;
      m_context_.view_state->scroll_x += result.scroll_x * kFastScrollMultiplier;
      m_context_.view_state->scroll_y += result.scroll_y * kFastScrollMultiplier;
      markScrollbarInteraction();
      break;
    }
    default:
      break;
    }

    const bool scale_gesture_end =
        m_scale_gesture_active_ &&
        (event.type == EventType::TOUCH_POINTER_UP
            || event.type == EventType::TOUCH_UP
            || event.type == EventType::TOUCH_CANCEL);

    if (scale_gesture_end || ((!m_scale_gesture_active_) &&
        (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
            || event.type == EventType::TOUCH_CANCEL))) {
      m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
      m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
    }
    if (scale_gesture_end) {
      m_scale_gesture_active_ = false;
    }
    if (result.type == GestureType::SCALE) {
      m_context_.text_layout->setViewState(*m_context_.view_state);
    } else {
      m_context_.text_layout->normalizeViewState(*m_context_.view_state);
    }
    fillGestureResult(core.m_cursor_position_, result);
    if (result.type == GestureType::DRAG_SELECT) {
      result.needs_edge_scroll = m_edge_scroll_.active;
    }
    result.needs_fling = m_fling_->isActive();
    result.needs_animation = result.needs_edge_scroll || result.needs_fling;

    LOGD("EditorInteraction::handleGestureEvent, m_view_state_ = %s", m_context_.view_state->dump().c_str());
    return result;
  }

  GestureResult EditorInteraction::tickEdgeScroll(TextPosition& cursor_position) {
    GestureResult result;
    result.type = GestureType::DRAG_SELECT;

    if (!m_edge_scroll_.active) {
      fillGestureResult(cursor_position, result);
      result.needs_edge_scroll = false;
      result.needs_animation = m_fling_->isActive();
      return result;
    }

    int64_t now = TimeUtil::milliTime();
    float dt_sec = static_cast<float>(now - m_edge_scroll_.last_tick_time) / 1000.0f;
    if (dt_sec <= 0) dt_sec = 0.016f;
    dt_sec = std::min(dt_sec, 0.1f);
    m_edge_scroll_.last_tick_time = now;

    m_context_.view_state->scroll_y += m_edge_scroll_.speed * dt_sec;
    m_context_.text_layout->normalizeViewState(*m_context_.view_state);
    markScrollbarInteraction();

    if (m_edge_scroll_.is_handle_drag) {
      dragHandleTo(cursor_position, m_dragging_handle_, m_edge_scroll_.last_screen_point);
    } else {
      dragSelectTo(cursor_position, m_edge_scroll_.last_screen_point, m_edge_scroll_.is_mouse);
    }

    fillGestureResult(cursor_position, result);
    result.needs_edge_scroll = m_edge_scroll_.active;
    result.needs_animation = m_edge_scroll_.active || m_fling_->isActive();
    return result;
  }

  GestureResult EditorInteraction::tickFling(const TextPosition& cursor_position) {
    GestureResult result;
    result.type = GestureType::SCROLL;

    if (!m_fling_->isActive()) {
      fillGestureResult(cursor_position, result);
      result.needs_fling = false;
      result.needs_animation = m_edge_scroll_.active;
      return result;
    }

    float dx = 0, dy = 0;
    bool still_active = m_fling_->advance(dx, dy);

    m_context_.view_state->scroll_x -= dx;
    m_context_.view_state->scroll_y -= dy;
    m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
    m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
    m_context_.text_layout->normalizeViewState(*m_context_.view_state);
    markScrollbarInteraction();

    fillGestureResult(cursor_position, result);
    result.needs_fling = still_active;
    result.needs_animation = m_edge_scroll_.active || still_active;
    return result;
  }

  GestureResult EditorInteraction::tickAnimations(TextPosition& cursor_position) {
    GestureResult result;

    bool did_edge_scroll = false;
    if (m_edge_scroll_.active) {
      result = tickEdgeScroll(cursor_position);
      did_edge_scroll = true;
    }

    if (m_fling_->isActive()) {
      GestureResult fling_result = tickFling(cursor_position);
      if (!did_edge_scroll) {
        result = fling_result;
      } else {
        result.needs_fling = fling_result.needs_fling;
        result.view_scroll_x = fling_result.view_scroll_x;
        result.view_scroll_y = fling_result.view_scroll_y;
      }
    }

    if (!did_edge_scroll && !m_fling_->isActive()) {
      fillGestureResult(cursor_position, result);
    }

    result.needs_animation = m_edge_scroll_.active || m_fling_->isActive();
    return result;
  }

  void EditorInteraction::stopFling() {
    m_fling_->stop();
  }

  EditorInteraction::PendingScaleAnchor EditorInteraction::takePendingScaleAnchor() {
    PendingScaleAnchor anchor = m_pending_scale_anchor_;
    m_pending_scale_anchor_.active = false;
    return anchor;
  }

  void EditorInteraction::resetScaleState() {
    m_pending_scale_anchor_.active = false;
    m_scale_gesture_active_ = false;
  }

  bool EditorInteraction::isScaleGestureActive() const {
    return m_scale_gesture_active_;
  }

  void EditorInteraction::clearHandleCache() {
    m_cached_handles_valid_ = false;
  }

  void EditorInteraction::updateHandleCache(const PointF& start, const PointF& end, float line_height) {
    m_cached_start_handle_pos_ = start;
    m_cached_end_handle_pos_ = end;
    m_cached_handle_height_ = line_height;
    m_cached_handles_valid_ = true;
  }
}
