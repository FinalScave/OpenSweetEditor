//
// Created by Codex on 2026/4/1.
//
#include <algorithm>
#include <chrono>
#include <cmath>
#include <sweeteditor/interaction.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

  static bool pointInRect(const PointF& point, const Rect& rect, float expand = 0.0f) {
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
        m_gesture_handler_(makeUnique<GestureHandler>(context.touch_config)),
        m_fling_(makeUnique<FlingAnimator>(context.touch_config)) {
  }

  uint32_t EditorInteraction::resolveInteractionFlags() const {
    uint32_t flags = 0;
    if (m_interaction_lifecycle_.primary_pointer_active) {
      flags |= static_cast<uint32_t>(InteractionFlag::PRIMARY_POINTER);
    }
    if (m_interaction_lifecycle_.selection_drag_active) {
      flags |= static_cast<uint32_t>(InteractionFlag::SELECTION_DRAG);
    }
    if (m_interaction_lifecycle_.pointer_viewport_gesture_active
        || m_interaction_lifecycle_.direct_viewport_gesture_depth > 0) {
      flags |= static_cast<uint32_t>(InteractionFlag::VIEWPORT_GESTURE);
    }
    return flags;
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

  EditorInteraction::PointerInteractionOwner EditorInteraction::hitTestHandle(
      const PointF& screen_point) const {
    if (!m_cached_handles_valid_ || !m_context_.caret->has_selection) {
      return PointerInteractionOwner::NONE;
    }

    const auto& start_rect = m_context_.settings->handle.start_hit_area;
    const auto& end_rect = m_context_.settings->handle.end_hit_area;
    const float h = m_cached_handle_height_;

    auto hitTest = [&](const PointF& pos, const HandleHitArea& rect) -> bool {
      float dx = screen_point.x - pos.x;
      float dy = screen_point.y - (pos.y + h);
      return rect.contains(dx, dy);
    };

    float dist_start = screen_point.distance(m_cached_start_handle_pos_);
    float dist_end = screen_point.distance(m_cached_end_handle_pos_);

    if (dist_start <= dist_end) {
      if (hitTest(m_cached_start_handle_pos_, start_rect)) {
        return PointerInteractionOwner::HANDLE_START;
      }
      if (hitTest(m_cached_end_handle_pos_, end_rect)) {
        return PointerInteractionOwner::HANDLE_END;
      }
    } else {
      if (hitTest(m_cached_end_handle_pos_, end_rect)) {
        return PointerInteractionOwner::HANDLE_END;
      }
      if (hitTest(m_cached_start_handle_pos_, start_rect)) {
        return PointerInteractionOwner::HANDLE_START;
      }
    }
    return PointerInteractionOwner::NONE;
  }

  void EditorInteraction::dragHandleTo(PointerInteractionOwner target,
                                       const PointF& screen_point) {
    if (!m_context_.caret->has_selection
        || (target != PointerInteractionOwner::HANDLE_START
            && target != PointerInteractionOwner::HANDLE_END)) {
      return;
    }

    const auto& hit_rect = (target == PointerInteractionOwner::HANDLE_START)
        ? m_context_.settings->handle.start_hit_area
        : m_context_.settings->handle.end_hit_area;

    PointF adjusted_point = screen_point;
    adjusted_point.y -= hit_rect.bottom;

    TextPosition pos = m_context_.text_layout->hitTestTextBoundary(adjusted_point);
    TextRange selection = m_context_.caret->selection;
    TextPosition sel_start = selection.start;
    TextPosition sel_end = selection.end;
    bool swapped = sel_end < sel_start;
    if (swapped) std::swap(sel_start, sel_end);

    if (target == PointerInteractionOwner::HANDLE_START) {
      sel_start = pos;
    } else {
      sel_end = pos;
    }

    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
      m_pointer_interaction_.owner =
          target == PointerInteractionOwner::HANDLE_START
              ? PointerInteractionOwner::HANDLE_END
              : PointerInteractionOwner::HANDLE_START;
    }

    m_context_.caret->setSelection({sel_start, sel_end});
    m_context_.caret->cursor =
        m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_END
            ? sel_end
            : sel_start;

    updateEdgeScrollState(screen_point, true, false);
    LOGD("EditorInteraction::dragHandleTo, selection = %s", m_context_.caret->selection.dump().c_str());
  }

  bool EditorInteraction::shouldPlaceCursorOnLongPress(const PointF& screen_point) const {
    if (m_context_.text_layout == nullptr || !m_context_.caret->has_selection) {
      return true;
    }

    const TextRange selection = m_context_.caret->normalizedSelection();
    const TextPosition pressed_position = m_context_.text_layout->hitTestPointer(screen_point);
    return !selection.contains(pressed_position);
  }

  void EditorInteraction::dragSelectTo(const PointF& screen_point, bool is_mouse) {
    PointF adjusted_point = screen_point;
    if (!is_mouse) {
      const float hit_bottom = std::max(m_context_.settings->handle.start_hit_area.bottom,
                                        m_context_.settings->handle.end_hit_area.bottom);
      adjusted_point.y -= hit_bottom;
    }

    TextPosition pos = m_context_.text_layout->hitTestTextBoundary(adjusted_point);

    if (!m_context_.caret->has_selection) {
      m_context_.caret->setSelection({m_context_.caret->cursor, pos});
    } else {
      m_context_.caret->setSelection({m_context_.caret->selection.start, pos});
    }

    updateEdgeScrollState(screen_point, false, is_mouse);
    LOGD("EditorInteraction::dragSelectTo, selection = %s", m_context_.caret->selection.dump().c_str());
  }

  void EditorInteraction::updateEdgeScrollState(const PointF& screen_point,
                                                bool selection_drag,
                                                bool is_mouse) {
    if (!isValidViewportSize(*m_context_.viewport) || m_context_.text_layout == nullptr) {
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
      m_edge_scroll_.selection_drag = selection_drag;
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

  InteractionResult EditorInteraction::handleGestureEvent(const GestureEvent& event) {
    PERF_TIMER("handleGestureEvent");
    InteractionResult interaction_result;

    if (event.type == EventType::DIRECT_GESTURE_BEGIN) {
      resetKineticMotion();
      m_interaction_lifecycle_.direct_viewport_gesture_depth++;
      interaction_result.handled = true;
      return interaction_result;
    }
    if (event.type == EventType::DIRECT_GESTURE_END) {
      if (m_interaction_lifecycle_.direct_viewport_gesture_depth == 0) {
        interaction_result.handled = true;
        return interaction_result;
      }
      m_interaction_lifecycle_.direct_viewport_gesture_depth--;
      if (m_interaction_lifecycle_.direct_viewport_gesture_depth == 0
          && m_context_.view_state != nullptr) {
        m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
        m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
        if (m_context_.text_layout != nullptr
            && m_context_.viewport != nullptr
            && isValidViewportSize(*m_context_.viewport)) {
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        }
      }
      interaction_result.handled = true;
      return interaction_result;
    }

    const bool primary_down = isPrimaryPointerDown(event.type);
    if (primary_down) {
      interaction_result.handled =
          m_pointer_interaction_.owner != PointerInteractionOwner::NONE;
      interaction_result.needs_redraw =
          m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL
          || m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL;
      resetKineticMotion();
      resetPointerState();
      m_interaction_lifecycle_.primary_pointer_active = true;
    }

    if (handleScrollbarGesture(event, interaction_result)) {
      return interaction_result;
    }

    if (primary_down && !event.points.empty()) {
      const PointerInteractionOwner owner = hitTestHandle(event.points[0]);
      if (owner != PointerInteractionOwner::NONE) {
        m_pointer_interaction_.owner = owner;
        m_interaction_lifecycle_.selection_drag_active = true;
        interaction_result.handled = true;
        return interaction_result;
      }
    }

    if (handleSelectionHandleGesture(event, interaction_result)) {
      return interaction_result;
    }

    GestureResult& result = interaction_result.gesture;
    result = m_gesture_handler_->handleGestureEvent(event);

    if (isPrimaryPointerEnd(event.type)) {
      m_edge_scroll_.active = false;
      if (event.type == EventType::TOUCH_UP && result.type == GestureType::UNDEFINED && !m_edge_scroll_.active) {
        m_fling_->start();
      }
    }

    switch (result.type) {
    case GestureType::TAP:
      if (static_cast<uint8_t>(result.modifiers & KeyModifier::SHIFT) && m_context_.caret->has_selection) {
        bool is_mouse_tap = (event.type == EventType::MOUSE_DOWN);
        dragSelectTo(result.tap_point, is_mouse_tap);
      } else {
        interaction_result.intent.cancel_linked_editing = true;
        interaction_result.intent.place_cursor = true;
      }
      result.hit_target = m_context_.text_layout->hitTestDecoration(result.tap_point);
      if (result.hit_target.type == HitTargetType::LINK
          && !hasAnyModifier(result.modifiers, KeyModifier::CTRL | KeyModifier::META)) {
        result.hit_target = {};
      }
      if (result.hit_target.type == HitTargetType::FOLD_PLACEHOLDER ||
          result.hit_target.type == HitTargetType::FOLD_GUTTER) {
        interaction_result.intent.toggle_fold = true;
        interaction_result.intent.fold_line = result.hit_target.line;
        interaction_result.intent.place_cursor = false;
      } else if (result.hit_target.type == HitTargetType::CODELENS) {
        interaction_result.intent.place_cursor = false;
      }
      break;
    case GestureType::DOUBLE_TAP:
      interaction_result.intent.select_word = true;
      break;
    case GestureType::LONG_PRESS:
      result.hit_target = m_context_.text_layout->hitTestDecoration(result.tap_point);
      interaction_result.intent.place_cursor = shouldPlaceCursorOnLongPress(result.tap_point);
      break;
    case GestureType::CONTEXT_MENU:
      result.hit_target = m_context_.text_layout->hitTestDecoration(result.tap_point);
      break;
    case GestureType::DRAG_SELECT: {
      bool is_mouse = (event.type == EventType::MOUSE_MOVE);
      m_interaction_lifecycle_.selection_drag_active = true;
      dragSelectTo(result.tap_point, is_mouse);
      break;
    }
    case GestureType::SCALE: {
      const PointF focus_screen = resolveScaleFocus(event);
          TextPosition anchor_position = m_context_.text_layout->hitTestPointer(focus_screen);
      PointF anchor_coord = m_context_.text_layout->getPositionScreenCoord(anchor_position);
      m_pending_scale_anchor_.active = true;
      m_pending_scale_anchor_.focus_screen = focus_screen;
      m_pending_scale_anchor_.anchor_position = anchor_position;
      m_pending_scale_anchor_.offset_x = focus_screen.x - anchor_coord.x;
      m_pending_scale_anchor_.offset_y = focus_screen.y - anchor_coord.y;
      m_scale_gesture_active_ = (event.type == EventType::TOUCH_MOVE && event.points.size() >= 2);
      if (event.type == EventType::TOUCH_MOVE) {
        m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
      }
      m_context_.view_state->scale = std::max(1.0f, std::min(m_context_.settings->max_scale, m_context_.view_state->scale * result.scale));
      break;
    }
    case GestureType::SCROLL:
      m_context_.view_state->scroll_x += result.scroll_x;
      m_context_.view_state->scroll_y += result.scroll_y;
      markScrollbarInteraction();
      if (event.type == EventType::TOUCH_MOVE && !event.points.empty()) {
        m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
        m_fling_->recordSample(event.points[0], TimeUtil::milliTime());
      }
      break;
    case GestureType::FAST_SCROLL: {
      constexpr float kFastScrollMultiplier = 3.0f;
      m_context_.view_state->scroll_x += result.scroll_x * kFastScrollMultiplier;
      m_context_.view_state->scroll_y += result.scroll_y * kFastScrollMultiplier;
      if (event.type == EventType::TOUCH_MOVE) {
        m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
      }
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

    if (scale_gesture_end
        || (!m_scale_gesture_active_ && isPrimaryPointerEnd(event.type))) {
      m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
      m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
    }
    if (scale_gesture_end) {
      m_scale_gesture_active_ = false;
    }
    if (event.type == EventType::TOUCH_POINTER_UP) {
      m_interaction_lifecycle_.pointer_viewport_gesture_active = false;
    }
    if (result.type == GestureType::SCALE) {
      m_context_.text_layout->setViewState(*m_context_.view_state);
    } else {
      m_context_.text_layout->normalizeViewState(*m_context_.view_state);
    }

    if (isPrimaryPointerEnd(event.type)) {
      m_interaction_lifecycle_.resetPointer();
    }
    interaction_result.handled =
        interaction_result.handled || result.type != GestureType::UNDEFINED;

    LOGD("EditorInteraction::handleGestureEvent, m_view_state_ = %s", m_context_.view_state->dump().c_str());
    return interaction_result;
  }

  GestureResult EditorInteraction::tickEdgeScroll() {
    GestureResult result;
    result.type = GestureType::DRAG_SELECT;

    if (!m_edge_scroll_.active) {
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

    if (m_edge_scroll_.selection_drag) {
      dragHandleTo(m_pointer_interaction_.owner, m_edge_scroll_.last_screen_point);
    } else {
      dragSelectTo(m_edge_scroll_.last_screen_point, m_edge_scroll_.is_mouse);
    }

    return result;
  }

  GestureResult EditorInteraction::tickFling() {
    GestureResult result;
    result.type = GestureType::SCROLL;

    if (!m_fling_->isActive()) {
      return result;
    }

    float dx = 0, dy = 0;
    m_fling_->advance(dx, dy);

    m_context_.view_state->scroll_x -= dx;
    m_context_.view_state->scroll_y -= dy;
    m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
    m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
    m_context_.text_layout->normalizeViewState(*m_context_.view_state);
    markScrollbarInteraction();

    return result;
  }

  InteractionResult EditorInteraction::tickAnimations() {
    InteractionResult interaction_result;
    GestureResult& result = interaction_result.gesture;

    bool did_edge_scroll = false;
    if (m_edge_scroll_.active) {
      result = tickEdgeScroll();
      did_edge_scroll = true;
    }

    if (m_fling_->isActive()) {
      GestureResult fling_result = tickFling();
      if (!did_edge_scroll) {
        result = fling_result;
      }
    }

    return interaction_result;
  }

  InteractionAnimationState EditorInteraction::resolveAnimationState() {
    InteractionAnimationState state;
    if (m_edge_scroll_.active) {
      state.flags |= static_cast<uint32_t>(AnimationFlag::EDGE_SCROLL);
    }
    if (m_fling_->isActive()) {
      state.flags |= static_cast<uint32_t>(AnimationFlag::FLING);
    }

    if (m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL
        || m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL) {
      return state;
    }

    if (!canShowTransientScrollbar()) {
      m_transient_scrollbar_timeline_.reset();
      return state;
    }

    if (!m_transient_scrollbar_timeline_.active()) {
      return state;
    }

    const int64_t now_ms = monotonicNowMs();
    const int64_t fade_ms =
        std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
    const int64_t delay_ms = static_cast<int64_t>(m_context_.settings->scrollbar.fade_delay_ms);
    const int64_t elapsed_since_last =
        std::max<int64_t>(0, now_ms - m_transient_scrollbar_timeline_.last_interaction_ms);

    if (elapsed_since_last >= delay_ms + fade_ms) {
      state.needs_redraw = true;
      m_transient_scrollbar_timeline_.reset();
      return state;
    }

    state.flags |= static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR);

    const int64_t elapsed_since_fade_in =
        std::max<int64_t>(0, now_ms - m_transient_scrollbar_timeline_.fade_in_start_ms);
    const bool fading_in = elapsed_since_fade_in < fade_ms;
    const bool fading_out = elapsed_since_last >= delay_ms;
    if (fading_in || fading_out) {
      state.next_tick_delay_ms = 0;
      state.needs_redraw = true;
    } else if (!(state.flags & (static_cast<uint32_t>(AnimationFlag::EDGE_SCROLL)
                                | static_cast<uint32_t>(AnimationFlag::FLING)))) {
      state.next_tick_delay_ms =
          static_cast<uint32_t>(std::max<int64_t>(1, delay_ms - elapsed_since_last));
    }
    return state;
  }

  void EditorInteraction::stopFling() {
    resetKineticMotion();
  }

  void EditorInteraction::onViewportChanged() {
    if (!isValidViewportSize(*m_context_.viewport)) {
      resetAllInteractionState();
      return;
    }

    const bool handle_active =
        m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_START
        || m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_END;
    if (handle_active) {
      m_edge_scroll_ = {};
    } else {
      resetPointerState();
    }
    m_fling_->resetSamples();
    resetScaleState();
    clearHandleCache();
  }

  void EditorInteraction::onScrollbarConfigChanged() {
    const bool scrollbar_active =
        m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL
        || m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL;
    if (scrollbar_active) {
      resetPointerState();
      markScrollbarControlInteraction();
    }
    if (m_context_.settings->scrollbar.mode != ScrollbarMode::TRANSIENT) {
      m_transient_scrollbar_timeline_.reset();
    }
  }

  void EditorInteraction::resetPointerMechanics() {
    m_pointer_interaction_.reset();
    m_edge_scroll_ = {};
    m_gesture_handler_->resetState();
  }

  void EditorInteraction::resetPointerState() {
    resetPointerMechanics();
    m_interaction_lifecycle_.resetPointer();
  }

  void EditorInteraction::resetKineticMotion() {
    m_fling_->stop();
    m_fling_->resetSamples();
  }

  void EditorInteraction::resetAllInteractionState() {
    resetPointerMechanics();
    resetKineticMotion();
    m_transient_scrollbar_timeline_.reset();
    m_pending_scale_anchor_ = {};
    m_scale_gesture_active_ = false;
    m_interaction_lifecycle_.reset();
    m_cached_start_handle_pos_ = {};
    m_cached_end_handle_pos_ = {};
    m_cached_handle_height_ = 0;
    m_cached_handles_valid_ = false;
  }

  void EditorInteraction::resetForDocumentLoad() {
    resetAllInteractionState();
  }

  bool EditorInteraction::canShowTransientScrollbar() const {
    if (m_context_.settings == nullptr
        || m_context_.settings->scrollbar.mode != ScrollbarMode::TRANSIENT
        || m_context_.text_layout == nullptr
        || m_context_.viewport == nullptr
        || !isValidViewportSize(*m_context_.viewport)) {
      return false;
    }
    const ScrollBounds bounds = m_context_.text_layout->getScrollBounds();
    return bounds.max_scroll_x > 0.0f || bounds.max_scroll_y > 0.0f;
  }

  void EditorInteraction::markScrollbarInteraction() {
    if (!canShowTransientScrollbar()) return;

    const int64_t now_ms = monotonicNowMs();
    const int64_t hide_window_ms =
        static_cast<int64_t>(m_context_.settings->scrollbar.fade_delay_ms) +
        std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
    if (!m_transient_scrollbar_timeline_.active()
        || now_ms - m_transient_scrollbar_timeline_.last_interaction_ms > hide_window_ms) {
      m_transient_scrollbar_timeline_.fade_in_start_ms = now_ms;
    }
    m_transient_scrollbar_timeline_.last_interaction_ms = now_ms;
    m_transient_scrollbar_timeline_.running = true;
  }

  void EditorInteraction::markScrollbarControlInteraction() {
    if (!canShowTransientScrollbar()) return;

    const int64_t now_ms = monotonicNowMs();
    const int64_t fade_ms =
        std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
    m_transient_scrollbar_timeline_.fade_in_start_ms = now_ms - fade_ms;
    m_transient_scrollbar_timeline_.last_interaction_ms = now_ms;
    m_transient_scrollbar_timeline_.running = true;
  }

  void EditorInteraction::computeScrollbarModels(ScrollbarModel& vertical,
                                                 ScrollbarModel& horizontal) const {
    vertical = ScrollbarModel {};
    horizontal = ScrollbarModel {};
    if (!isValidViewportSize(*m_context_.viewport) || m_context_.text_layout == nullptr) {
      return;
    }

    const float scrollbar_thickness = std::max(1.0f, m_context_.settings->scrollbar.thickness);
    const float scrollbar_min_thumb = std::max(scrollbar_thickness, m_context_.settings->scrollbar.min_thumb);

    const ScrollBounds bounds = m_context_.text_layout->getScrollBounds();
    const bool logical_vertical = bounds.max_scroll_y > 0.0f;
    const bool logical_horizontal = bounds.max_scroll_x > 0.0f;
    const int64_t now_ms = monotonicNowMs();
    const auto axisAlpha = [&](bool logical_visible,
                               PointerInteractionOwner owner) -> float {
      if (!logical_visible) return 0.0f;
      switch (m_context_.settings->scrollbar.mode) {
      case ScrollbarMode::ALWAYS:
        return 1.0f;
      case ScrollbarMode::NEVER:
        return 0.0f;
      case ScrollbarMode::TRANSIENT: {
        if (m_pointer_interaction_.owner == owner) return 1.0f;
        if (!m_transient_scrollbar_timeline_.active()) return 0.0f;

        const int64_t fade_ms = std::max<int64_t>(1, static_cast<int64_t>(m_context_.settings->scrollbar.fade_duration_ms));
        const int64_t delay_ms = static_cast<int64_t>(m_context_.settings->scrollbar.fade_delay_ms);
        const int64_t elapsed_since_last =
            std::max<int64_t>(0, now_ms - m_transient_scrollbar_timeline_.last_interaction_ms);
        if (elapsed_since_last >= delay_ms + fade_ms) {
          return 0.0f;
        }

        float fade_out_alpha = 1.0f;
        if (elapsed_since_last > delay_ms) {
          fade_out_alpha = 1.0f - static_cast<float>(elapsed_since_last - delay_ms) / static_cast<float>(fade_ms);
        }

        const int64_t elapsed_since_fade_in =
            std::max<int64_t>(0, now_ms - m_transient_scrollbar_timeline_.fade_in_start_ms);
        const float fade_in_alpha =
            std::min(1.0f, static_cast<float>(elapsed_since_fade_in + 16) / static_cast<float>(fade_ms));
        return std::clamp(std::min(fade_in_alpha, fade_out_alpha), 0.0f, 1.0f);
      }
      }
      return 1.0f;
    };
    const float vertical_alpha =
        axisAlpha(logical_vertical, PointerInteractionOwner::SCROLLBAR_VERTICAL);
    const float horizontal_alpha =
        axisAlpha(logical_horizontal, PointerInteractionOwner::SCROLLBAR_HORIZONTAL);
    const bool show_vertical = vertical_alpha > 0.0f;
    const bool show_horizontal = horizontal_alpha > 0.0f;
    const float viewport_w = m_context_.viewport->width;
    const float viewport_h = m_context_.viewport->height;

    const float vertical_track_x = viewport_w - scrollbar_thickness;
    const float vertical_track_height = viewport_h - (show_horizontal ? scrollbar_thickness : 0.0f);
    if (show_vertical && vertical_track_height > 0.0f) {
      vertical.visible = true;
      vertical.alpha = vertical_alpha;
      vertical.thumb_active =
          m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL;
      vertical.track.origin = {vertical_track_x, 0.0f};
      vertical.track.width = scrollbar_thickness;
      vertical.track.height = vertical_track_height;

      const float viewport = std::max(1.0f, viewport_h);
      const float content_span = std::max(viewport, bounds.content_height);
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
    const float horizontal_track_width = viewport_w - horizontal_track_x - (show_vertical ? scrollbar_thickness : 0.0f);
    const float horizontal_track_y = viewport_h - scrollbar_thickness;
    if (show_horizontal && horizontal_track_width > 0.0f && horizontal_track_y >= 0.0f) {
      horizontal.visible = true;
      horizontal.alpha = horizontal_alpha;
      horizontal.thumb_active =
          m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL;
      horizontal.track.origin = {horizontal_track_x, horizontal_track_y};
      horizontal.track.width = horizontal_track_width;
      horizontal.track.height = scrollbar_thickness;

      const float viewport = std::max(1.0f, bounds.text_area_width);
      const float content_span = std::max(viewport, bounds.content_width);
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

  bool EditorInteraction::isPointInScrollbar(const PointF& point) const {
    ScrollbarModel vertical;
    ScrollbarModel horizontal;
    computeScrollbarModels(vertical, horizontal);
    const float thumb_hit_padding = m_context_.settings->scrollbar.thumb_hit_padding;

    if (vertical.visible
        && (pointInRect(point, vertical.track)
            || (m_context_.settings->scrollbar.thumb_draggable
                && pointInRect(point, vertical.thumb, thumb_hit_padding)))) {
      return true;
    }

    if (horizontal.visible
        && (pointInRect(point, horizontal.track)
            || (m_context_.settings->scrollbar.thumb_draggable
                && pointInRect(point, horizontal.thumb, thumb_hit_padding)))) {
      return true;
    }

    return false;
  }

  bool EditorInteraction::handleSelectionHandleGesture(const GestureEvent& event,
                                                       InteractionResult& result) {
    const bool active =
        m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_START
        || m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_END;
    if (!active) {
      return false;
    }

    if (isPrimaryPointerMove(event.type)) {
      result.handled = true;
      if (!event.points.empty() && m_context_.text_layout != nullptr) {
        dragHandleTo(m_pointer_interaction_.owner, event.points[0]);
        m_context_.text_layout->setViewState(*m_context_.view_state);
        result.gesture.type = GestureType::DRAG_SELECT;
      }
      return true;
    }

    if (event.type == EventType::TOUCH_POINTER_DOWN
        || isPrimaryPointerEnd(event.type)) {
      const bool primary_end = isPrimaryPointerEnd(event.type);
      if (m_context_.view_state != nullptr) {
        m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
        m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
        if (m_context_.text_layout != nullptr
            && m_context_.viewport != nullptr
            && isValidViewportSize(*m_context_.viewport)) {
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        }
      }
      if (primary_end) {
        resetPointerState();
      } else {
        resetPointerMechanics();
        m_interaction_lifecycle_.selection_drag_active = false;
      }
      result.handled = true;
      return true;
    }
    return false;
  }

  bool EditorInteraction::handleScrollbarGesture(const GestureEvent& event,
                                                 InteractionResult& result) {
    const bool active =
        m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL
        || m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL;
    const auto finish = [&](GestureType type, bool needs_redraw = true) {
      result.gesture.type = type;
      result.handled = true;
      result.needs_redraw = needs_redraw;
      return true;
    };

    if (active
        && (event.type == EventType::TOUCH_POINTER_DOWN
            || isPrimaryPointerEnd(event.type))) {
      const bool primary_end = isPrimaryPointerEnd(event.type);
      if (m_context_.view_state != nullptr) {
        m_context_.view_state->scroll_x = std::round(m_context_.view_state->scroll_x);
        m_context_.view_state->scroll_y = std::round(m_context_.view_state->scroll_y);
        if (m_context_.text_layout != nullptr
            && m_context_.viewport != nullptr
            && isValidViewportSize(*m_context_.viewport)) {
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        }
      }
      if (primary_end) {
        resetPointerState();
      } else {
        resetPointerMechanics();
        m_interaction_lifecycle_.pointer_viewport_gesture_active = false;
      }
      markScrollbarControlInteraction();
      return finish(GestureType::UNDEFINED);
    }

    if (m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_START
        || m_pointer_interaction_.owner == PointerInteractionOwner::HANDLE_END) {
      return false;
    }

    if (m_context_.text_layout == nullptr
        || m_context_.viewport == nullptr
        || !isValidViewportSize(*m_context_.viewport)) {
      if (active && isPrimaryPointerMove(event.type)) {
        return finish(GestureType::UNDEFINED, false);
      }
      return false;
    }

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
          && pointInRect(point, vertical.thumb, thumb_hit_padding)) {
        m_pointer_interaction_.owner = PointerInteractionOwner::SCROLLBAR_VERTICAL;
        m_pointer_interaction_.start_point = point;
        m_pointer_interaction_.start_scroll_y = m_context_.view_state->scroll_y;
        m_pointer_interaction_.travel_y =
            std::max(0.0f, vertical.track.height - vertical.thumb.height);
        m_pointer_interaction_.max_scroll_y = std::max(0.0f, bounds.max_scroll_y);
        m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
        markScrollbarControlInteraction();
        return finish(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_context_.settings->scrollbar.thumb_draggable
          && pointInRect(point, horizontal.thumb, thumb_hit_padding)) {
        m_pointer_interaction_.owner = PointerInteractionOwner::SCROLLBAR_HORIZONTAL;
        m_pointer_interaction_.start_point = point;
        m_pointer_interaction_.start_scroll_x = m_context_.view_state->scroll_x;
        m_pointer_interaction_.travel_x =
            std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
        m_pointer_interaction_.max_scroll_x = std::max(0.0f, bounds.max_scroll_x);
        m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
        markScrollbarControlInteraction();
        return finish(GestureType::UNDEFINED);
      }

      if (vertical.visible
          && m_context_.settings->scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInRect(point, vertical.track)) {
        if (vertical.track.height > 0.0f && bounds.max_scroll_y > 0.0f) {
          const float travel = std::max(0.0f, vertical.track.height - vertical.thumb.height);
          const float ratio = travel <= 0.0f
              ? 0.0f
              : std::clamp(
                    (point.y - vertical.track.origin.y - vertical.thumb.height * 0.5f) / travel,
                    0.0f,
                    1.0f);
          m_context_.view_state->scroll_y = ratio * bounds.max_scroll_y;
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
          m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
          markScrollbarControlInteraction();
          return finish(GestureType::SCROLL);
        }
        markScrollbarControlInteraction();
        return finish(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_context_.settings->scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInRect(point, horizontal.track)) {
        if (horizontal.track.width > 0.0f && bounds.max_scroll_x > 0.0f) {
          const float travel = std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
          const float ratio = travel <= 0.0f
              ? 0.0f
              : std::clamp(
                    (point.x - horizontal.track.origin.x - horizontal.thumb.width * 0.5f) / travel,
                    0.0f,
                    1.0f);
          m_context_.view_state->scroll_x = ratio * bounds.max_scroll_x;
          m_context_.text_layout->normalizeViewState(*m_context_.view_state);
          m_interaction_lifecycle_.pointer_viewport_gesture_active = true;
          markScrollbarControlInteraction();
          return finish(GestureType::SCROLL);
        }
        markScrollbarControlInteraction();
        return finish(GestureType::UNDEFINED);
      }
      return false;
    }

    case EventType::TOUCH_MOVE:
    case EventType::MOUSE_MOVE: {
      if (!active) {
        return false;
      }
      if (event.points.empty()) {
        return finish(GestureType::UNDEFINED, false);
      }
      const PointF& point = event.points[0];
      if (m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_VERTICAL) {
        float target_y = m_pointer_interaction_.start_scroll_y;
        if (m_pointer_interaction_.travel_y > 0.0f
            && m_pointer_interaction_.max_scroll_y > 0.0f) {
          const float delta = point.y - m_pointer_interaction_.start_point.y;
          target_y += delta * m_pointer_interaction_.max_scroll_y
                      / m_pointer_interaction_.travel_y;
        }
        m_context_.view_state->scroll_y = std::clamp(target_y, 0.0f, bounds.max_scroll_y);
        m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        markScrollbarControlInteraction();
        return finish(GestureType::SCROLL);
      }
      if (m_pointer_interaction_.owner == PointerInteractionOwner::SCROLLBAR_HORIZONTAL) {
        float target_x = m_pointer_interaction_.start_scroll_x;
        if (m_pointer_interaction_.travel_x > 0.0f
            && m_pointer_interaction_.max_scroll_x > 0.0f) {
          const float delta = point.x - m_pointer_interaction_.start_point.x;
          target_x += delta * m_pointer_interaction_.max_scroll_x
                      / m_pointer_interaction_.travel_x;
        }
        m_context_.view_state->scroll_x = std::clamp(target_x, 0.0f, bounds.max_scroll_x);
        m_context_.text_layout->normalizeViewState(*m_context_.view_state);
        markScrollbarControlInteraction();
        return finish(GestureType::SCROLL);
      }
      return finish(GestureType::UNDEFINED, false);
    }

    default:
      return false;
    }
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
