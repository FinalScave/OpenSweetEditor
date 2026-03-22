//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <simdutf/simdutf.h>
#include <cmath>
#include <algorithm>
#include <chrono>
#include <editor_core.h>
#include <utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {

  /// Checks whether a character is a word character (letter, digit, underscore)
  static bool isWordChar(U16Char ch) {
    return (ch >= CHAR16('a') && ch <= CHAR16('z')) ||
           (ch >= CHAR16('A') && ch <= CHAR16('Z')) ||
           (ch >= CHAR16('0') && ch <= CHAR16('9')) ||
           ch == CHAR16('_') ||
           ch > 0x7F; // Treat non-ASCII characters as word characters (supports CJK, etc.)
  }

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

#pragma region [Class: EditorOptions]
  TouchConfig EditorOptions::simpleAsTouchConfig() const {
    return TouchConfig {touch_slop, double_tap_timeout, long_press_ms};
  }

  U8String EditorOptions::dump() const {
    return "EditorOptions {touch_slop = " + std::to_string(touch_slop) + ", double_tap_timeout = " + std::to_string(double_tap_timeout) + ", long_press_ms = " + std::to_string(long_press_ms) + ", max_undo_stack_size = " + std::to_string(max_undo_stack_size) + "}";
  }

  U8String EditorSettings::dump() const {
    return "EditorSettings {max_scale = " + std::to_string(max_scale)
        + ", read_only = " + (read_only ? "true" : "false")
        + ", enable_composition = " + (enable_composition ? "true" : "false")
        + ", content_start_padding = " + std::to_string(content_start_padding)
        + ", show_split_line = " + (show_split_line ? "true" : "false")
        + ", current_line_render_mode = " + std::to_string(static_cast<int>(current_line_render_mode))
        + ", scrollbar.thickness = " + std::to_string(scrollbar.thickness)
        + ", scrollbar.min_thumb = " + std::to_string(scrollbar.min_thumb)
        + ", scrollbar.thumb_hit_padding = " + std::to_string(scrollbar.thumb_hit_padding)
        + ", scrollbar.mode = " + std::to_string(static_cast<int>(scrollbar.mode))
        + ", scrollbar.thumb_draggable = " + (scrollbar.thumb_draggable ? "true" : "false")
        + ", scrollbar.track_tap_mode = " + std::to_string(static_cast<int>(scrollbar.track_tap_mode))
        + ", scrollbar.fade_delay_ms = " + std::to_string(scrollbar.fade_delay_ms)
        + ", scrollbar.fade_duration_ms = " + std::to_string(scrollbar.fade_duration_ms)
        + "}";
  }
#pragma endregion

#pragma region [Class: EditorCore]
  EditorCore::EditorCore(const Ptr<TextMeasurer>& measurer, const EditorOptions& options): m_measurer_(measurer), m_options_(options) {
    m_decorations_ = makePtr<DecorationManager>();
    m_gesture_handler_ = makeUPtr<GestureHandler>(options.simpleAsTouchConfig());
    m_text_layout_ = makeUPtr<TextLayout>(measurer, m_decorations_);
    m_undo_manager_ = makeUPtr<UndoManager>(options.max_undo_stack_size);
    LOGD("EditorCore::EditorCore(), options = %s", options.dump().c_str());
  }

  void EditorCore::setHandleConfig(const HandleConfig& config) {
    m_settings_.handle = config;
    LOGD("EditorCore::setHandleConfig(), radius = %.1f, center_dist = %.1f", config.radius, config.center_dist);
  }

  void EditorCore::setScrollbarConfig(const ScrollbarConfig& config) {
    m_settings_.scrollbar.thickness = std::max(1.0f, config.thickness);
    m_settings_.scrollbar.min_thumb = std::max(m_settings_.scrollbar.thickness, config.min_thumb);
    m_settings_.scrollbar.thumb_hit_padding = std::max(0.0f, config.thumb_hit_padding);
    m_settings_.scrollbar.mode = config.mode;
    m_settings_.scrollbar.thumb_draggable = config.thumb_draggable;
    m_settings_.scrollbar.track_tap_mode = config.track_tap_mode;
    m_settings_.scrollbar.fade_delay_ms = std::max<uint16_t>(0, config.fade_delay_ms);
    m_settings_.scrollbar.fade_duration_ms = std::max<uint16_t>(0, config.fade_duration_ms);
    normalizeScrollState();
    LOGD("EditorCore::setScrollbarConfig(), thickness = %.1f, min_thumb = %.1f, thumb_hit_padding = %.1f, mode = %d, thumb_draggable = %d, track_tap_mode = %d, fade_delay_ms = %u, fade_duration_ms = %u",
         m_settings_.scrollbar.thickness,
         m_settings_.scrollbar.min_thumb,
         m_settings_.scrollbar.thumb_hit_padding,
         static_cast<int>(m_settings_.scrollbar.mode),
         m_settings_.scrollbar.thumb_draggable ? 1 : 0,
         static_cast<int>(m_settings_.scrollbar.track_tap_mode),
         m_settings_.scrollbar.fade_delay_ms,
         m_settings_.scrollbar.fade_duration_ms);
  }

  void EditorCore::markScrollbarInteraction() {
    const int64_t now_ms = monotonicNowMs();
    const int64_t hide_window_ms =
        static_cast<int64_t>(m_settings_.scrollbar.fade_delay_ms) +
        std::max<int64_t>(1, static_cast<int64_t>(m_settings_.scrollbar.fade_duration_ms));
    if (m_scrollbar_last_interaction_ms_ <= 0
        || m_scrollbar_cycle_start_ms_ <= 0
        || now_ms - m_scrollbar_last_interaction_ms_ > hide_window_ms) {
      m_scrollbar_cycle_start_ms_ = now_ms;
    }
    m_scrollbar_last_interaction_ms_ = now_ms;
  }

  void EditorCore::loadDocument(const Ptr<Document>& document) {
    m_document_ = document;
    m_text_layout_->loadDocument(document);
    normalizeScrollState();
    LOGD("EditorCore::loadDocument()");
  }
#pragma region [Appearance-Font]
  void EditorCore::setViewport(const Viewport& viewport) {
    m_viewport_ = viewport;
    m_text_layout_->setViewport(viewport);
    markAllLinesDirty();
    normalizeScrollState();
    LOGD("EditorCore::setViewport, viewport = %s", m_viewport_.dump().c_str());
  }

  void EditorCore::resetMeasurer() {
    m_text_layout_->resetMeasurer();
    // After font metrics change, all lines must be relaid out (line height, run width, etc. may change)
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setWrapMode(WrapMode mode) {
    m_text_layout_->setWrapMode(mode);
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setScale(float scale) {
    m_view_state_.scale = scale;
    normalizeScrollState();
    LOGD("EditorCore::setScale, m_view_state_ = %s", m_view_state_.dump().c_str());
  }

  void EditorCore::setFoldArrowMode(FoldArrowMode mode) {
    if (m_text_layout_->getLayoutMetrics().fold_arrow_mode == mode) return;
    m_text_layout_->getLayoutMetrics().fold_arrow_mode = mode;
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setLineSpacing(float add, float mult) {
    auto& params = m_text_layout_->getLayoutMetrics();
    if (params.line_spacing_add == add && params.line_spacing_mult == mult) return;
    params.line_spacing_add = add;
    params.line_spacing_mult = mult;
    // After line height changes, all lines must be relaid out
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setContentStartPadding(float padding) {
    padding = std::max(0.0f, padding);
    auto& params = m_text_layout_->getLayoutMetrics();
    if (params.content_start_padding == padding) return;
    params.content_start_padding = padding;
    m_settings_.content_start_padding = padding;
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setShowSplitLine(bool show) {
    if (m_settings_.show_split_line == show) return;
    m_settings_.show_split_line = show;
  }

  void EditorCore::setCurrentLineRenderMode(CurrentLineRenderMode mode) {
    if (m_settings_.current_line_render_mode == mode) return;
    m_settings_.current_line_render_mode = mode;
  }
#pragma endregion

#pragma region [Rendering]
  Ptr<TextStyleRegistry> EditorCore::getTextStyleRegistry() const {
    return m_decorations_->getTextStyleRegistry();
  }

  void EditorCore::buildRenderModel(EditorRenderModel& model) {
    PERF_TIMER("buildRenderModel");
    PERF_BEGIN(compose);
    m_text_layout_->layoutVisibleLines(model);
    model.split_line_visible = m_settings_.show_split_line;
    model.current_line_render_mode = m_settings_.current_line_render_mode;
    PERF_END(compose, "buildRenderModel::layoutVisibleLines");

    float line_height = m_text_layout_->getLineHeight();
    float font_height = m_text_layout_->getLayoutMetrics().font_height;

    PERF_BEGIN(cursor_sel);
    buildCursorModel(model, line_height);
    buildCompositionDecoration(model, line_height, font_height);
    buildSelectionRects(model, line_height);
    PERF_END(cursor_sel, "buildRenderModel::cursorAndSelection");

    PERF_BEGIN(guides);
    buildGuideSegments(model, line_height);
    PERF_END(guides, "buildRenderModel::guideSegments");

    buildDiagnosticDecorations(model, line_height);
    buildLinkedEditingRects(model, line_height);
    buildBracketHighlightRects(model, line_height);
    buildScrollbarModel(model);
  }

  ViewState EditorCore::getViewState() const {
    return m_view_state_;
  }

  ScrollMetrics EditorCore::getScrollMetrics() const {
    ScrollMetrics metrics;
    metrics.scale = m_view_state_.scale;
    metrics.viewport_width = m_viewport_.width;
    metrics.viewport_height = m_viewport_.height;

    if (m_text_layout_ == nullptr) {
      return metrics;
    }

    ScrollBounds bounds = m_text_layout_->getScrollBounds();
    metrics.scroll_x = m_view_state_.scroll_x;
    metrics.scroll_y = m_view_state_.scroll_y;
    metrics.max_scroll_x = bounds.max_scroll_x;
    metrics.max_scroll_y = bounds.max_scroll_y;
    metrics.content_width = bounds.content_width;
    metrics.content_height = bounds.content_height;
    metrics.text_area_x = bounds.text_area_x;
    metrics.text_area_width = bounds.text_area_width;
    metrics.can_scroll_x = bounds.max_scroll_x > 0.0f;
    metrics.can_scroll_y = bounds.max_scroll_y > 0.0f;
    return metrics;
  }

  void EditorCore::computeScrollbarModels(ScrollbarModel& vertical, ScrollbarModel& horizontal) const {
    vertical = ScrollbarModel{};
    horizontal = ScrollbarModel{};
    if (!m_viewport_.valid() || m_text_layout_ == nullptr) {
      return;
    }

    const float scrollbar_thickness = std::max(1.0f, m_settings_.scrollbar.thickness);
    const float scrollbar_min_thumb = std::max(scrollbar_thickness, m_settings_.scrollbar.min_thumb);

    const ScrollBounds bounds = m_text_layout_->getScrollBounds();
    const bool logical_vertical = bounds.max_scroll_y > 0.0f;
    const bool logical_horizontal = bounds.max_scroll_x > 0.0f;
    const int64_t now_ms = monotonicNowMs();
    const auto axisAlpha = [&](bool logical_visible, ScrollbarDragTarget drag_target) -> float {
      if (!logical_visible) return 0.0f;
      switch (m_settings_.scrollbar.mode) {
      case ScrollbarMode::ALWAYS:
        return 1.0f;
      case ScrollbarMode::NEVER:
        return 0.0f;
      case ScrollbarMode::TRANSIENT: {
        if (m_dragging_scrollbar_ == drag_target) return 1.0f;
        if (m_scrollbar_last_interaction_ms_ <= 0) return 0.0f;

        const int64_t fade_ms = std::max<int64_t>(1, static_cast<int64_t>(m_settings_.scrollbar.fade_duration_ms));
        const int64_t delay_ms = static_cast<int64_t>(m_settings_.scrollbar.fade_delay_ms);
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
          // +16ms frame compensation avoids fully invisible first frame when interaction just starts.
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
    const float viewport_width = m_viewport_.width;
    const float viewport_height = m_viewport_.height;

    const float vertical_track_x = viewport_width - scrollbar_thickness;
    const float vertical_track_height = viewport_height - (show_horizontal ? scrollbar_thickness : 0.0f);
    if (show_vertical && vertical_track_height > 0.0f) {
      vertical.visible = true;
      vertical.alpha = vertical_alpha;
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
        : std::clamp(m_view_state_.scroll_y / bounds.max_scroll_y, 0.0f, 1.0f);
      const float thumb_y = travel <= 0.0f ? 0.0f : travel * ratio;
      vertical.thumb.origin = {vertical_track_x, thumb_y};
      vertical.thumb.width = scrollbar_thickness;
      vertical.thumb.height = thumb_height;
    }

    const float horizontal_track_x = std::max(0.0f, bounds.text_area_x);
    const float horizontal_track_width = viewport_width - horizontal_track_x - (show_vertical ? scrollbar_thickness : 0.0f);
    const float horizontal_track_y = viewport_height - scrollbar_thickness;
    if (show_horizontal && horizontal_track_width > 0.0f && horizontal_track_y >= 0.0f) {
      horizontal.visible = true;
      horizontal.alpha = horizontal_alpha;
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
        : std::clamp(m_view_state_.scroll_x / bounds.max_scroll_x, 0.0f, 1.0f);
      const float thumb_x = horizontal_track_x + (travel <= 0.0f ? 0.0f : travel * ratio);
      horizontal.thumb.origin = {thumb_x, horizontal_track_y};
      horizontal.thumb.width = thumb_width;
      horizontal.thumb.height = scrollbar_thickness;
    }
  }

  void EditorCore::buildScrollbarModel(EditorRenderModel& model) const {
    computeScrollbarModels(model.vertical_scrollbar, model.horizontal_scrollbar);
  }

  LayoutMetrics& EditorCore::getLayoutMetrics() const {
    return m_text_layout_->getLayoutMetrics();
  }
#pragma endregion

#pragma region [Gesture-KeyEvent]
  void EditorCore::fillGestureResult(GestureResult& result) const {
    result.cursor_position = m_cursor_position_;
    result.has_selection = m_has_selection_;
    result.selection = m_selection_;
    result.view_scroll_x = m_view_state_.scroll_x;
    result.view_scroll_y = m_view_state_.scroll_y;
    result.view_scale = m_view_state_.scale;
  }

  bool EditorCore::handleScrollbarGesture(const GestureEvent& event, GestureResult& result) {
    if (m_text_layout_ == nullptr || !m_viewport_.valid()) {
      return false;
    }
    // While dragging selection handles, ignore scrollbar hit-test.
    if (m_dragging_handle_ != HandleDragTarget::NONE
        && m_dragging_scrollbar_ == ScrollbarDragTarget::NONE) {
      return false;
    }

    const auto consume = [&](GestureType type) {
      result.type = type;
      fillGestureResult(result);
      return true;
    };
    const auto markScrollbarInteraction = [&]() {
      this->markScrollbarInteraction();
    };

    ScrollbarModel vertical;
    ScrollbarModel horizontal;
    computeScrollbarModels(vertical, horizontal);
    const ScrollBounds bounds = m_text_layout_->getScrollBounds();

    switch (event.type) {
    case EventType::TOUCH_DOWN:
    case EventType::MOUSE_DOWN: {
      if (event.points.empty()) return false;
      const PointF& point = event.points[0];
      const float thumb_hit_padding = m_settings_.scrollbar.thumb_hit_padding;

      if (vertical.visible
          && m_settings_.scrollbar.thumb_draggable
          && pointInScrollbarRect(point, vertical.thumb, thumb_hit_padding)) {
        m_dragging_scrollbar_ = ScrollbarDragTarget::VERTICAL;
        m_scrollbar_drag_start_point_ = point;
        m_scrollbar_drag_start_scroll_y_ = m_view_state_.scroll_y;
        m_scrollbar_drag_travel_y_ = std::max(0.0f, vertical.track.height - vertical.thumb.height);
        m_scrollbar_drag_max_scroll_y_ = std::max(0.0f, bounds.max_scroll_y);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        m_gesture_handler_->resetState();
        return consume(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_settings_.scrollbar.thumb_draggable
          && pointInScrollbarRect(point, horizontal.thumb, thumb_hit_padding)) {
        m_dragging_scrollbar_ = ScrollbarDragTarget::HORIZONTAL;
        m_scrollbar_drag_start_point_ = point;
        m_scrollbar_drag_start_scroll_x_ = m_view_state_.scroll_x;
        m_scrollbar_drag_travel_x_ = std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
        m_scrollbar_drag_max_scroll_x_ = std::max(0.0f, bounds.max_scroll_x);
        m_edge_scroll_.active = false;
        markScrollbarInteraction();
        m_gesture_handler_->resetState();
        return consume(GestureType::UNDEFINED);
      }

      if (vertical.visible
          && m_settings_.scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInScrollbarRect(point, vertical.track)) {
        if (vertical.track.height > 0.0f && bounds.max_scroll_y > 0.0f) {
          const float travel = std::max(0.0f, vertical.track.height - vertical.thumb.height);
          const float ratio = travel <= 0.0f
            ? 0.0f
            : std::clamp((point.y - vertical.track.origin.y - vertical.thumb.height * 0.5f) / travel, 0.0f, 1.0f);
          m_view_state_.scroll_y = ratio * bounds.max_scroll_y;
          normalizeScrollState();
          m_edge_scroll_.active = false;
          markScrollbarInteraction();
          return consume(GestureType::SCROLL);
        }
        markScrollbarInteraction();
        return consume(GestureType::UNDEFINED);
      }

      if (horizontal.visible
          && m_settings_.scrollbar.track_tap_mode == ScrollbarTrackTapMode::JUMP
          && pointInScrollbarRect(point, horizontal.track)) {
        if (horizontal.track.width > 0.0f && bounds.max_scroll_x > 0.0f) {
          const float travel = std::max(0.0f, horizontal.track.width - horizontal.thumb.width);
          const float ratio = travel <= 0.0f
            ? 0.0f
            : std::clamp((point.x - horizontal.track.origin.x - horizontal.thumb.width * 0.5f) / travel, 0.0f, 1.0f);
          m_view_state_.scroll_x = ratio * bounds.max_scroll_x;
          normalizeScrollState();
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
        m_view_state_.scroll_y = std::clamp(target_y, 0.0f, bounds.max_scroll_y);
        normalizeScrollState();
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
        m_view_state_.scroll_x = std::clamp(target_x, 0.0f, bounds.max_scroll_x);
        normalizeScrollState();
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
      m_view_state_.scroll_x = std::round(m_view_state_.scroll_x);
      m_view_state_.scroll_y = std::round(m_view_state_.scroll_y);
      normalizeScrollState();
      m_edge_scroll_.active = false;
      m_gesture_handler_->resetState();
      return consume(GestureType::UNDEFINED);
    }

    default:
      return false;
    }
  }

  GestureResult EditorCore::handleGestureEvent(const GestureEvent& event) {
    PERF_TIMER("handleGestureEvent");
    GestureResult gesture_result;

    if (handleScrollbarGesture(event, gesture_result)) {
      return gesture_result;
    }

    // On TOUCH_DOWN / MOUSE_DOWN, check whether the cursor handle was pressed
    if (event.type == EventType::TOUCH_DOWN || event.type == EventType::MOUSE_DOWN) {
      if (!event.points.empty()) {
        m_dragging_handle_ = hitTestHandle(event.points[0]);
      }
    }
    // When a second finger touches down, cancel handle drag (user intent is two-finger scroll/zoom)
    if (m_dragging_handle_ != HandleDragTarget::NONE
        && event.type == EventType::TOUCH_POINTER_DOWN) {
      m_dragging_handle_ = HandleDragTarget::NONE;
      m_edge_scroll_.active = false;
    }

    // While dragging a handle: intercept TOUCH_MOVE / MOUSE_MOVE and update selection
    if (m_dragging_handle_ != HandleDragTarget::NONE) {
      if (event.type == EventType::TOUCH_MOVE || event.type == EventType::MOUSE_MOVE) {
        if (!event.points.empty()) {
          dragHandleTo(m_dragging_handle_, event.points[0]);
          m_text_layout_->setViewState(m_view_state_);
          gesture_result.type = GestureType::DRAG_SELECT;
          fillGestureResult(gesture_result);
          gesture_result.needs_edge_scroll = m_edge_scroll_.active;
          return gesture_result;
        }
      }
      if (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
          || event.type == EventType::TOUCH_CANCEL) {
        m_dragging_handle_ = HandleDragTarget::NONE;
        m_edge_scroll_.active = false;
        // Reset gesture handler state so skipped TOUCH_MOVE events during handle drag
        // do not leave m_is_tap_ as true and affect later double-tap detection
        m_gesture_handler_->resetState();
        // Snap scroll to integer pixels for crisp text when idle
        m_view_state_.scroll_x = std::round(m_view_state_.scroll_x);
        m_view_state_.scroll_y = std::round(m_view_state_.scroll_y);
        normalizeScrollState();
        fillGestureResult(gesture_result);
        return gesture_result;
      }
    }
    GestureResult result = m_gesture_handler_->handleGestureEvent(event);

    // Stop edge scroll on pointer release (non-handle-drag path)
    if (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
        || event.type == EventType::TOUCH_CANCEL) {
      m_edge_scroll_.active = false;
    }

    // If TOUCH_DOWN just hit a cursor handle, skip follow-up actions such as TAP
    if (m_dragging_handle_ != HandleDragTarget::NONE) {
      m_text_layout_->setViewState(m_view_state_);
      fillGestureResult(result);
      return result;
    }

    switch (result.type) {
    case GestureType::TAP:
      if (static_cast<uint8_t>(result.modifiers & Modifier::SHIFT) && m_has_selection_) {
        // Shift+Click from mouse should not apply touch y-offset
        bool is_mouse_tap = (event.type == EventType::MOUSE_DOWN);
        dragSelectTo(result.tap_point, is_mouse_tap);
      } else {
        // Tap in linked editing mode: check whether it is inside a tab stop range
        if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
          TextPosition tap_pos = m_text_layout_->hitTest(result.tap_point);
          bool in_tab_stop = false;
          auto highlights = m_linked_editing_session_->getAllHighlights();
          for (const auto& hl : highlights) {
            if (hl.range.contains(tap_pos)) {
              in_tab_stop = true;
              break;
            }
          }
          if (!in_tab_stop) {
            cancelLinkedEditing();
          }
        }
        placeCursorAt(result.tap_point);
      }
      // Check whether InlayHint, GutterIcon, or fold-related targets were hit
      result.hit_target = m_text_layout_->hitTestDecoration(result.tap_point);
      // Toggle fold/unfold when tapping a fold placeholder or gutter fold arrow
      if (result.hit_target.type == HitTargetType::FOLD_PLACEHOLDER ||
          result.hit_target.type == HitTargetType::FOLD_GUTTER) {
        toggleFoldAt(result.hit_target.line);
      }
      break;
    case GestureType::DOUBLE_TAP:
      selectWordAt(result.tap_point);
      break;
    case GestureType::LONG_PRESS:
      placeCursorAt(result.tap_point);
      break;
    case GestureType::DRAG_SELECT: {
      // Mouse events (MOUSE_MOVE) should not apply touch y-offset
      bool is_mouse = (event.type == EventType::MOUSE_MOVE);
      dragSelectTo(result.tap_point, is_mouse);
      break;
    }
    case GestureType::SCALE: {
      float old_scale = m_view_state_.scale;
      m_view_state_.scale = std::max(1.0f, std::min(m_settings_.max_scale, m_view_state_.scale * result.scale));
      float scale_ratio = m_view_state_.scale / old_scale;
      m_view_state_.scroll_y *= scale_ratio;
      m_view_state_.scroll_x *= scale_ratio;
      break;
    }
    case GestureType::SCROLL:
      m_view_state_.scroll_x += result.scroll_x;
      m_view_state_.scroll_y += result.scroll_y;
      markScrollbarInteraction();
      break;
    case GestureType::FAST_SCROLL: {
      constexpr float kFastScrollMultiplier = 3.0f;
      m_view_state_.scroll_x += result.scroll_x * kFastScrollMultiplier;
      m_view_state_.scroll_y += result.scroll_y * kFastScrollMultiplier;
      markScrollbarInteraction();
      break;
    }
    default:
      break;
    }

    // Snap scroll to integer pixels for crisp text when pointer is released
    if (event.type == EventType::TOUCH_UP || event.type == EventType::MOUSE_UP
        || event.type == EventType::TOUCH_CANCEL) {
      m_view_state_.scroll_x = std::round(m_view_state_.scroll_x);
      m_view_state_.scroll_y = std::round(m_view_state_.scroll_y);
    }

    normalizeScrollState();
    fillGestureResult(result);
    // Propagate edge-scroll flag for DRAG_SELECT gestures
    if (result.type == GestureType::DRAG_SELECT) {
      result.needs_edge_scroll = m_edge_scroll_.active;
    }

    LOGD("EditorCore::handleGestureEvent, m_view_state_ = %s", m_view_state_.dump().c_str());
    return result;
  }

  KeyEventResult EditorCore::handleKeyEvent(const KeyEvent& event) {
    PERF_TIMER("handleKeyEvent");
    KeyEventResult result;
    if (m_document_ == nullptr) return result;

    // If composition input is active, some keys need special handling
    if (m_composition_.is_composing) {
      switch (event.key_code) {
      case KeyCode::ESCAPE:
        compositionCancel();
        result.handled = true;
        result.content_changed = true;
        result.cursor_changed = true;
        return result;
      default:
        break;
      }
    }

    bool shift = static_cast<uint8_t>(event.modifiers & Modifier::SHIFT) != 0;
    bool ctrl = static_cast<uint8_t>(event.modifiers & Modifier::CTRL) != 0;
    bool meta = static_cast<uint8_t>(event.modifiers & Modifier::META) != 0;
    bool alt = static_cast<uint8_t>(event.modifiers & Modifier::ALT) != 0;
    bool cmd = ctrl || meta;

    switch (event.key_code) {
    case KeyCode::BACKSPACE:
      result.edit_result = backspace();
      result.handled = true;
      result.cursor_changed = true;
      result.content_changed = result.edit_result.changed;
      break;
    case KeyCode::DELETE_KEY:
      result.edit_result = deleteForward();
      result.handled = true;
      result.cursor_changed = true;
      result.content_changed = result.edit_result.changed;
      break;
    case KeyCode::ENTER:
      if (cmd && shift) {
        result.edit_result = insertLineAbove();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else if (cmd) {
        result.edit_result = insertLineBelow();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        // Enter finishes linked editing, confirms current text, and moves cursor to $0
        finishLinkedEditing();
        result.handled = true;
        result.cursor_changed = true;
      } else {
        result.edit_result = insertText("\n");
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      }
      break;
    case KeyCode::TAB:
      if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        if (shift) {
          linkedEditingPrevTabStop();
        } else {
          linkedEditingNextTabStop();
        }
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
      } else {
        result.edit_result = insertText("\t");
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      }
      break;
    case KeyCode::ESCAPE:
      if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        cancelLinkedEditing();
        result.handled = true;
      }
      break;
    case KeyCode::LEFT:
      moveCursorLeft(shift);
      result.handled = true;
      result.cursor_changed = true;
      result.selection_changed = shift;
      break;
    case KeyCode::RIGHT:
      moveCursorRight(shift);
      result.handled = true;
      result.cursor_changed = true;
      result.selection_changed = shift;
      break;
    case KeyCode::UP:
      if (alt && shift) {
        result.edit_result = copyLineUp();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else if (alt) {
        result.edit_result = moveLineUp();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else {
        moveCursorUp(shift);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = shift;
      }
      break;
    case KeyCode::DOWN:
      if (alt && shift) {
        result.edit_result = copyLineDown();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else if (alt) {
        result.edit_result = moveLineDown();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      } else {
        moveCursorDown(shift);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = shift;
      }
      break;
    case KeyCode::HOME:
      moveCursorToLineStart(shift);
      result.handled = true;
      result.cursor_changed = true;
      result.selection_changed = shift;
      break;
    case KeyCode::END:
      moveCursorToLineEnd(shift);
      result.handled = true;
      result.cursor_changed = true;
      result.selection_changed = shift;
      break;
    case KeyCode::A:
      if (cmd) {
        selectAll();
        result.handled = true;
        result.selection_changed = true;
      }
      break;
    case KeyCode::Z:
      if (cmd && shift) {
        result.edit_result = redo();
        if (result.edit_result.changed) {
          result.handled = true;
          result.content_changed = true;
          result.cursor_changed = true;
        }
      } else if (cmd) {
        result.edit_result = undo();
        if (result.edit_result.changed) {
          result.handled = true;
          result.content_changed = true;
          result.cursor_changed = true;
        }
      }
      break;
    case KeyCode::Y:
      if (cmd) {
        result.edit_result = redo();
        if (result.edit_result.changed) {
          result.handled = true;
          result.content_changed = true;
          result.cursor_changed = true;
        }
      }
      break;
    case KeyCode::K:
      if (cmd && shift) {
        result.edit_result = deleteLine();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
      }
      break;
    default:
      break;
    }

    // Handle plain text input (direct character input when not in IME composition)
    if (!result.handled && event.isTextInput()) {
      result.edit_result = insertText(event.text);
      result.handled = true;
      result.cursor_changed = true;
      result.content_changed = result.edit_result.changed;
    }

    LOGD("EditorCore::handleKeyEvent, key_code = %d, handled = %d", (int)event.key_code, result.handled);
    return result;
  }
#pragma endregion

#pragma region [Editing]
  TextEditResult EditorCore::insertText(const U8String& text) {
    if (m_document_ == nullptr || text.empty() || m_settings_.read_only) return {};

    // If composition is active, end it first (commit current composing text before new input)
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Auto-indent: when inserting a newline with KEEP_INDENT enabled, append previous line's leading whitespace
    U8String actual_text = text;
    if (text == "\n" && m_settings_.auto_indent_mode == AutoIndentMode::KEEP_INDENT) {
      size_t current_line = m_has_selection_ ? getNormalizedSelection().start.line : m_cursor_position_.line;
      U16String line_text = m_document_->getLineU16Text(current_line);
      U8String indent;
      for (auto ch : line_text) {
        if (ch == CHAR16(' ') || ch == CHAR16('\t')) {
          indent += static_cast<char>(ch);
        } else {
          break;
        }
      }
      if (!indent.empty()) {
        actual_text = "\n" + indent;
      }
    }

    if (isInLinkedEditing()) {
      const TabStopGroup* group = m_linked_editing_session_->currentGroup();
      if (group == nullptr || group->ranges.empty()) return {};
      U8String current_text = m_has_selection_ ? "" : m_document_->getU8Text(group->ranges[0]);
      U8String linked_text = current_text + actual_text;
      TextEditResult result = applyLinkedEditsWithResult(linked_text);
      LOGD("EditorCore::insertText(linked), cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }

    TextEditResult result;
    if (m_has_selection_) {
      TextRange range = getNormalizedSelection();
      result = applyEdit(range, actual_text);
    } else {
      TextRange range = {m_cursor_position_, m_cursor_position_};
      result = applyEdit(range, actual_text);
    }
    LOGD("EditorCore::insertText, cursor = %s", m_cursor_position_.dump().c_str());
    return result;
  }

  TextEditResult EditorCore::replaceText(const TextRange& range, const U8String& new_text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If composition is active, cancel it first
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    if (isInLinkedEditing()) {
      const TabStopGroup* group = m_linked_editing_session_->currentGroup();
      if (group && !group->ranges.empty() && range == group->ranges[0]) {
        TextEditResult result = applyLinkedEditsWithResult(new_text);
        LOGD("EditorCore::replaceText(linked), cursor = %s", m_cursor_position_.dump().c_str());
        return result;
      }
    }

    TextEditResult result = applyEdit(range, new_text);
    LOGD("EditorCore::replaceText, cursor = %s", m_cursor_position_.dump().c_str());
    return result;
  }

  TextEditResult EditorCore::deleteText(const TextRange& range) {
    return replaceText(range, "");
  }

  TextEditResult EditorCore::backspace() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (m_composition_.is_composing) {
      compositionCancel();
      return {};
    }

    if (isInLinkedEditing()) {
      const TabStopGroup* group = m_linked_editing_session_->currentGroup();
      if (group && !group->ranges.empty()) {
        const TextRange& primary = group->ranges[0];
        if (m_has_selection_) {
          auto result = applyLinkedEditsWithResult("");
          LOGD("EditorCore::backspace(linked), cursor = %s", m_cursor_position_.dump().c_str());
          return result;
        }
        if (primary.start < primary.end) {
          U8String current_text = m_document_->getU8Text(primary);
          if (!current_text.empty()) {
            auto end_it = current_text.end();
            utf8::prior(end_it, current_text.begin());
            U8String new_text(current_text.begin(), end_it);
            auto result = applyLinkedEditsWithResult(new_text);
            LOGD("EditorCore::backspace(linked), cursor = %s", m_cursor_position_.dump().c_str());
            return result;
          }
        } else {
          cancelLinkedEditing();
        }
      }
    }

    if (m_has_selection_) {
      TextRange range = getNormalizedSelection();
      auto result = applyEdit(range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }

    if (m_cursor_position_.column > 0) {
      U16String line_text = m_document_->getLineU16Text(m_cursor_position_.line);
      size_t col = m_cursor_position_.column;
      size_t del_count = 1;
      if (col >= 2) {
        U16Char low = line_text[col - 1];
        U16Char high = line_text[col - 2];
        if (low >= 0xDC00 && low <= 0xDFFF && high >= 0xD800 && high <= 0xDBFF) {
          del_count = 2;
        }
      }
      TextRange del_range = {{m_cursor_position_.line, col - del_count}, {m_cursor_position_.line, col}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    } else if (m_cursor_position_.line > 0) {
      size_t prev_line = m_cursor_position_.line - 1;
      uint32_t prev_cols = m_document_->getLineColumns(prev_line);
      TextRange del_range = {{prev_line, prev_cols}, {m_cursor_position_.line, 0}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }
    return {};
  }

  TextEditResult EditorCore::deleteForward() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (m_composition_.is_composing) {
      compositionCancel();
      return {};
    }

    if (isInLinkedEditing() && m_has_selection_) {
      auto result = applyLinkedEditsWithResult("");
      LOGD("EditorCore::deleteForward(linked), cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }

    if (m_has_selection_) {
      TextRange range = getNormalizedSelection();
      auto result = applyEdit(range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }

    uint32_t line_cols = m_document_->getLineColumns(m_cursor_position_.line);
    if (m_cursor_position_.column < line_cols) {
      U16String line_text = m_document_->getLineU16Text(m_cursor_position_.line);
      size_t col = m_cursor_position_.column;
      size_t del_count = 1;
      if (col + 1 < line_text.length()) {
        U16Char high = line_text[col];
        U16Char low = line_text[col + 1];
        if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
          del_count = 2;
        }
      }
      TextRange del_range = {{m_cursor_position_.line, col}, {m_cursor_position_.line, col + del_count}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    } else if (m_cursor_position_.line + 1 < m_document_->getLineCount()) {
      TextRange del_range = {{m_cursor_position_.line, line_cols}, {m_cursor_position_.line + 1, 0}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_cursor_position_.dump().c_str());
      return result;
    }
    return {};
  }

  void EditorCore::deleteSelection() {
    if (!m_has_selection_ || m_document_ == nullptr) return;
    TextRange range = getNormalizedSelection();
    // Internal call; do not record undo (used in composition flow)
    m_document_->deleteU8Text(range);
    // Adjust decoration offsets to avoid misalignment (especially after multi-line selection deletion)
    m_decorations_->adjustForEdit(range, range.start);
    m_text_layout_->invalidateContentMetrics(range.start.line);
    m_cursor_position_ = range.start;
    clearSelection();
  }
#pragma endregion

#pragma region [Line-Operation]
  TextEditResult EditorCore::moveLineUp() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (m_has_selection_) {
      TextRange sel = getNormalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_cursor_position_.line;
    }

    if (first_line == 0) return {};

    U8String prev_text = m_document_->getU8Text({{first_line - 1, 0}, {first_line - 1, m_document_->getLineColumns(first_line - 1)}});
    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    TextRange full_range = {{first_line - 1, 0}, {last_line, m_document_->getLineColumns(last_line)}};
    U8String new_text = block_text + "\n" + prev_text;

    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);
    auto result = applyEdit(full_range, new_text);

    TextPosition new_cursor = {m_cursor_position_.line > 0 ? m_cursor_position_.line - 1 : 0, m_cursor_position_.column};
    setCursorPosition(new_cursor);
    if (m_has_selection_) {
      setSelection({{m_selection_.start.line > 0 ? m_selection_.start.line - 1 : 0, m_selection_.start.column},
                     {m_selection_.end.line > 0 ? m_selection_.end.line - 1 : 0, m_selection_.end.column}});
    }

    m_undo_manager_->endGroup(m_cursor_position_);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::moveLineDown() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (m_has_selection_) {
      TextRange sel = getNormalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_cursor_position_.line;
    }

    size_t line_count = m_document_->getLineCount();
    if (last_line + 1 >= line_count) return {};

    U8String next_text = m_document_->getU8Text({{last_line + 1, 0}, {last_line + 1, m_document_->getLineColumns(last_line + 1)}});
    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    TextRange full_range = {{first_line, 0}, {last_line + 1, m_document_->getLineColumns(last_line + 1)}};
    U8String new_text = next_text + "\n" + block_text;

    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);
    auto result = applyEdit(full_range, new_text);

    setCursorPosition({m_cursor_position_.line + 1, m_cursor_position_.column});
    if (m_has_selection_) {
      setSelection({{m_selection_.start.line + 1, m_selection_.start.column},
                     {m_selection_.end.line + 1, m_selection_.end.column}});
    }

    m_undo_manager_->endGroup(m_cursor_position_);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::copyLineUp() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (m_has_selection_) {
      TextRange sel = getNormalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_cursor_position_.line;
    }

    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    // Insert copied line block + newline at the start of first_line
    TextPosition insert_pos = {first_line, 0};
    U8String insert_text = block_text + "\n";

    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // Keep cursor at original logical position (inserted text already shifted it down correctly)
    m_undo_manager_->endGroup(m_cursor_position_);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::copyLineDown() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (m_has_selection_) {
      TextRange sel = getNormalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_cursor_position_.line;
    }

    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    // Insert newline + copied line block at the end of last_line
    uint32_t last_cols = m_document_->getLineColumns(last_line);
    TextPosition insert_pos = {last_line, last_cols};
    U8String insert_text = "\n" + block_text;

    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // applyEdit moves cursor to the end of inserted text (end of copied block), which is what we want
    m_undo_manager_->endGroup(m_cursor_position_);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::deleteLine() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (m_has_selection_) {
      TextRange sel = getNormalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_cursor_position_.line;
    }

    size_t line_count = m_document_->getLineCount();
    TextRange del_range;
    if (last_line + 1 < line_count) {
      // Delete the line block + following newline
      del_range = {{first_line, 0}, {last_line + 1, 0}};
    } else if (first_line > 0) {
      // Last lines: delete preceding newline + line block
      del_range = {{first_line - 1, m_document_->getLineColumns(first_line - 1)}, {last_line, m_document_->getLineColumns(last_line)}};
    } else {
      // Only line: clear content
      del_range = {{0, 0}, {last_line, m_document_->getLineColumns(last_line)}};
    }

    auto result = applyEdit(del_range, "");
    return result;
  }

  TextEditResult EditorCore::insertLineAbove() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t line = m_cursor_position_.line;
    TextPosition insert_pos = {line, 0};

    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);
    auto result = applyEdit({insert_pos, insert_pos}, "\n");

    // Keep cursor on the newly inserted empty line
    setCursorPosition({line, 0});
    m_undo_manager_->endGroup(m_cursor_position_);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::insertLineBelow() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t line = m_cursor_position_.line;
    uint32_t line_cols = m_document_->getLineColumns(line);
    TextPosition insert_pos = {line, line_cols};

    auto result = applyEdit({insert_pos, insert_pos}, "\n");
    // applyEdit has already moved cursor to the start of the new line
    return result;
  }
#pragma endregion

#pragma region [Undo-Redo]
  TextEditResult EditorCore::undo() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If composition input is active, cancel it first
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Exit linked editing mode when undoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const UndoEntry* entry = m_undo_manager_->undo();
    if (entry == nullptr) return {};

    TextEditResult edit_result;
    edit_result.changed = true;

    if (entry->is_compound) {
      // Compound operation: run undo for all actions in reverse order
      const auto& actions = entry->compound.actions;
      for (auto it = actions.rbegin(); it != actions.rend(); ++it) {
        const EditAction& action = *it;
        TextChange change;
        if (action.new_text.empty()) {
          m_document_->insertU8Text(action.range.start, action.old_text);
          TextPosition new_end = calcPositionAfterInsert(action.range.start, action.old_text);
          m_decorations_->adjustForEdit({action.range.start, action.range.start}, new_end);
          change.range = {action.range.start, action.range.start};
          change.old_text = "";
          change.new_text = action.old_text;
        } else if (action.old_text.empty()) {
          TextPosition end_pos = calcPositionAfterInsert(action.range.start, action.new_text);
          m_document_->deleteU8Text({action.range.start, end_pos});
          m_decorations_->adjustForEdit({action.range.start, end_pos}, action.range.start);
          change.range = {action.range.start, end_pos};
          change.old_text = action.new_text;
          change.new_text = "";
        } else {
          TextPosition end_pos = calcPositionAfterInsert(action.range.start, action.new_text);
          m_document_->replaceU8Text({action.range.start, end_pos}, action.old_text);
          TextPosition new_end = calcPositionAfterInsert(action.range.start, action.old_text);
          m_decorations_->adjustForEdit({action.range.start, end_pos}, new_end);
          change.range = {action.range.start, end_pos};
          change.old_text = action.new_text;
          change.new_text = action.old_text;
        }
        edit_result.changes.push_back(std::move(change));
      }
      edit_result.cursor_before = entry->compound.cursor_after;
      edit_result.cursor_after = entry->compound.cursor_before;
      setCursorPosition(entry->compound.cursor_before);
      if (entry->compound.had_selection) {
        setSelection(entry->compound.selection_before);
      } else {
        clearSelection();
      }
    } else {
      // Single-operation undo (existing logic)
      const EditAction& action = entry->single;
      edit_result.cursor_before = action.cursor_after;
      edit_result.cursor_after = action.cursor_before;

      TextChange change;
      if (action.new_text.empty()) {
        m_document_->insertU8Text(action.range.start, action.old_text);
        TextPosition new_end = calcPositionAfterInsert(action.range.start, action.old_text);
        m_decorations_->adjustForEdit({action.range.start, action.range.start}, new_end);
        change.range = {action.range.start, action.range.start};
        change.old_text = "";
        change.new_text = action.old_text;
      } else if (action.old_text.empty()) {
        TextPosition end_pos = calcPositionAfterInsert(action.range.start, action.new_text);
        m_document_->deleteU8Text({action.range.start, end_pos});
        m_decorations_->adjustForEdit({action.range.start, end_pos}, action.range.start);
        change.range = {action.range.start, end_pos};
        change.old_text = action.new_text;
        change.new_text = "";
      } else {
        TextPosition end_pos = calcPositionAfterInsert(action.range.start, action.new_text);
        m_document_->replaceU8Text({action.range.start, end_pos}, action.old_text);
        TextPosition new_end = calcPositionAfterInsert(action.range.start, action.old_text);
        m_decorations_->adjustForEdit({action.range.start, end_pos}, new_end);
        change.range = {action.range.start, end_pos};
        change.old_text = action.new_text;
        change.new_text = action.old_text;
      }
      edit_result.changes.push_back(std::move(change));

      setCursorPosition(action.cursor_before);
      if (action.had_selection) {
        setSelection(action.selection_before);
      } else {
        clearSelection();
      }
    }

    m_text_layout_->invalidateContentMetrics();
    ensureCursorVisible();
    LOGD("EditorCore::undo, cursor = %s", m_cursor_position_.dump().c_str());
    return edit_result;
  }

  TextEditResult EditorCore::redo() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If composition input is active, cancel it first
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Exit linked editing mode when redoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const UndoEntry* entry = m_undo_manager_->redo();
    if (entry == nullptr) return {};

    TextEditResult edit_result;
    edit_result.changed = true;

    if (entry->is_compound) {
      // Compound operation: run redo for all actions in forward order
      const auto& actions = entry->compound.actions;
      for (const auto& action : actions) {
        TextChange change;
        change.range = action.range;
        change.old_text = action.old_text;
        change.new_text = action.new_text;
        if (action.new_text.empty()) {
          m_document_->deleteU8Text(action.range);
          m_decorations_->adjustForEdit(action.range, action.range.start);
        } else if (action.old_text.empty()) {
          m_document_->insertU8Text(action.range.start, action.new_text);
          TextPosition new_end = calcPositionAfterInsert(action.range.start, action.new_text);
          m_decorations_->adjustForEdit({action.range.start, action.range.start}, new_end);
        } else {
          m_document_->replaceU8Text(action.range, action.new_text);
          TextPosition new_end = calcPositionAfterInsert(action.range.start, action.new_text);
          m_decorations_->adjustForEdit(action.range, new_end);
        }
        edit_result.changes.push_back(std::move(change));
      }
      edit_result.cursor_before = entry->compound.cursor_before;
      edit_result.cursor_after = entry->compound.cursor_after;
      setCursorPosition(entry->compound.cursor_after);
      clearSelection();
    } else {
      // Single-operation redo (existing logic)
      const EditAction& action = entry->single;
      edit_result.cursor_before = action.cursor_before;

      TextChange change;
      change.range = action.range;
      change.old_text = action.old_text;
      change.new_text = action.new_text;

      if (action.new_text.empty()) {
        m_document_->deleteU8Text(action.range);
        m_decorations_->adjustForEdit(action.range, action.range.start);
      } else if (action.old_text.empty()) {
        m_document_->insertU8Text(action.range.start, action.new_text);
        TextPosition new_end = calcPositionAfterInsert(action.range.start, action.new_text);
        m_decorations_->adjustForEdit({action.range.start, action.range.start}, new_end);
      } else {
        m_document_->replaceU8Text(action.range, action.new_text);
        TextPosition new_end = calcPositionAfterInsert(action.range.start, action.new_text);
        m_decorations_->adjustForEdit(action.range, new_end);
      }
      edit_result.changes.push_back(std::move(change));

      setCursorPosition(action.cursor_after);
      edit_result.cursor_after = action.cursor_after;
      clearSelection();
    }

    m_text_layout_->invalidateContentMetrics();
    ensureCursorVisible();
    LOGD("EditorCore::redo, cursor = %s", m_cursor_position_.dump().c_str());
    return edit_result;
  }

  bool EditorCore::canUndo() const {
    return m_undo_manager_->canUndo();
  }

  bool EditorCore::canRedo() const {
    return m_undo_manager_->canRedo();
  }
#pragma endregion

#pragma region [Cursor-Selection]
  void EditorCore::setCursorPosition(const TextPosition& position) {
    m_cursor_position_ = position;
    if (m_document_ != nullptr) {
      size_t line_count = m_document_->getLineCount();
      if (m_cursor_position_.line >= line_count) {
        m_cursor_position_.line = line_count > 0 ? line_count - 1 : 0;
      }
      // If cursor lands in a fold-hidden line, move it to end of the fold start line
      const auto& lines = m_document_->getLogicalLines();
      if (m_cursor_position_.line < lines.size() && lines[m_cursor_position_.line].is_fold_hidden) {
        const FoldRegion* fr = m_decorations_->getFoldRegionForLine(m_cursor_position_.line);
        if (fr != nullptr) {
          m_cursor_position_.line = fr->start_line;
          m_cursor_position_.column = m_document_->getLineColumns(fr->start_line);
          return;
        }
      }
      uint32_t cols = m_document_->getLineColumns(m_cursor_position_.line);
      if (m_cursor_position_.column > cols) {
        m_cursor_position_.column = cols;
      }
    }
  }

  TextPosition EditorCore::getCursorPosition() const {
    return m_cursor_position_;
  }

  void EditorCore::setSelection(const TextRange& range) {
    m_selection_ = range;
    m_has_selection_ = !(range.start == range.end);
    m_cursor_position_ = range.end;
  }

  TextRange EditorCore::getSelection() const {
    return m_selection_;
  }

  bool EditorCore::hasSelection() const {
    return m_has_selection_;
  }

  void EditorCore::clearSelection() {
    m_has_selection_ = false;
    m_selection_ = {};
  }

  void EditorCore::selectAll() {
    if (m_document_ == nullptr) return;
    size_t last_line = m_document_->getLineCount() > 0 ? m_document_->getLineCount() - 1 : 0;
    uint32_t last_col = m_document_->getLineColumns(last_line);
    setSelection({{0, 0}, {last_line, last_col}});
  }

  U8String EditorCore::getSelectedText() const {
    if (!m_has_selection_ || m_document_ == nullptr) return "";
    TextRange range = getNormalizedSelection();
    U8String result;
    for (size_t line = range.start.line; line <= range.end.line && line < m_document_->getLineCount(); ++line) {
      U16String line_text = m_document_->getLineU16Text(line);
      size_t col_start = (line == range.start.line) ? range.start.column : 0;
      size_t col_end = (line == range.end.line) ? range.end.column : line_text.length();
      col_start = std::min(col_start, line_text.length());
      col_end = std::min(col_end, line_text.length());
      if (col_start < col_end) {
        U16String sub = line_text.substr(col_start, col_end - col_start);
        U8String u8_sub;
        StrUtil::convertUTF16ToUTF8(sub, u8_sub);
        result += u8_sub;
      }
      if (line < range.end.line) {
        result += "\n";
      }
    }
    return result;
  }

  TextRange EditorCore::getWordRangeAtCursor() const {
    if (m_document_ == nullptr) return {m_cursor_position_, m_cursor_position_};
    size_t line = m_cursor_position_.line;
    U16String line_text = m_document_->getLineU16Text(line);
    size_t col = std::min(m_cursor_position_.column, line_text.length());
    size_t start = col;
    while (start > 0 && isWordChar(line_text[start - 1])) {
      --start;
    }
    return {{line, start}, {line, col}};
  }

  U8String EditorCore::getWordAtCursor() const {
    if (m_document_ == nullptr) return "";
    TextRange range = getWordRangeAtCursor();
    if (range.start.column >= range.end.column) return "";
    U16String line_text = m_document_->getLineU16Text(range.start.line);
    size_t s = std::min(range.start.column, line_text.length());
    size_t e = std::min(range.end.column, line_text.length());
    if (s >= e) return "";
    U16String sub = line_text.substr(s, e - s);
    U8String result;
    StrUtil::convertUTF16ToUTF8(sub, result);
    return result;
  }

  EditorCore::HandleDragTarget EditorCore::hitTestHandle(const PointF& screen_point) const {
    if (!m_cached_handles_valid_ || !m_has_selection_) return HandleDragTarget::NONE;

    // Read handle params from HandleConfig (kept in sync with platform teardrop drawing)
    const float kHandleRadius = m_settings_.handle.radius;
    const float kHandleCenterDist = m_settings_.handle.center_dist;
    const float kTouchPadding = m_settings_.handle.touch_padding;

    // start handle: tip at top of vertical line (handle_pos), teardrop above-left
    // end handle: tip at bottom of vertical line (handle_pos.y + height), teardrop below-right
    auto hitTestStart = [&](const PointF& pos) -> bool {
      // Teardrop circle center: (pos.x - radius + lineWidth/2, pos.y - centerDist)
      float cx = pos.x - kHandleRadius;
      float cy = pos.y - kHandleCenterDist;
      // Hit area: vertical line area + teardrop circle area (with padding)
      float dx_line = std::abs(screen_point.x - pos.x);
      bool in_line = dx_line <= kTouchPadding
                     && screen_point.y >= pos.y - kTouchPadding
                     && screen_point.y <= pos.y + m_cached_handle_height_ + kTouchPadding;
      float dx_circle = screen_point.x - cx;
      float dy_circle = screen_point.y - cy;
      bool in_circle = (dx_circle * dx_circle + dy_circle * dy_circle)
                       <= (kHandleRadius + kTouchPadding) * (kHandleRadius + kTouchPadding);
      return in_line || in_circle;
    };

    auto hitTestEnd = [&](const PointF& pos) -> bool {
      // Teardrop circle center: (pos.x + radius, pos.y + height + centerDist)
      float cx = pos.x + kHandleRadius;
      float cy = pos.y + m_cached_handle_height_ + kHandleCenterDist;
      // Vertical line area
      float dx_line = std::abs(screen_point.x - pos.x);
      bool in_line = dx_line <= kTouchPadding
                     && screen_point.y >= pos.y - kTouchPadding
                     && screen_point.y <= pos.y + m_cached_handle_height_ + kTouchPadding;
      // Teardrop circle area
      float dx_circle = screen_point.x - cx;
      float dy_circle = screen_point.y - cy;
      bool in_circle = (dx_circle * dx_circle + dy_circle * dy_circle)
                       <= (kHandleRadius + kTouchPadding) * (kHandleRadius + kTouchPadding);
      return in_line || in_circle;
    };

    // Prioritize checking the handle closer to the touch point
    float dist_start = screen_point.distance(m_cached_start_handle_pos_);
    float dist_end = screen_point.distance(m_cached_end_handle_pos_);

    if (dist_start <= dist_end) {
      if (hitTestStart(m_cached_start_handle_pos_)) return HandleDragTarget::START;
      if (hitTestEnd(m_cached_end_handle_pos_)) return HandleDragTarget::END;
    } else {
      if (hitTestEnd(m_cached_end_handle_pos_)) return HandleDragTarget::END;
      if (hitTestStart(m_cached_start_handle_pos_)) return HandleDragTarget::START;
    }
    return HandleDragTarget::NONE;
  }

  void EditorCore::dragHandleTo(HandleDragTarget target, const PointF& screen_point) {
    if (!m_has_selection_ || target == HandleDragTarget::NONE) return;

    // Use line_height-aware offset so the cursor stays clear of the finger regardless of
    // font size or zoom level.  Total offset = configured drag_y_offset + one line height.
    const float line_height = m_text_layout_->getLineHeight();
    const float total_offset = m_settings_.handle.drag_y_offset + line_height;

    // START handle (teardrop above): finger is above, cursor below -> offset downward
    // END handle (teardrop below): finger is below, cursor above -> offset upward
    PointF adjusted_point = screen_point;
    if (target == HandleDragTarget::START) {
      adjusted_point.y += total_offset;
    } else {
      adjusted_point.y -= total_offset;
    }

    TextPosition pos = m_text_layout_->hitTest(adjusted_point);

    // Normalize current selection
    TextPosition sel_start = m_selection_.start;
    TextPosition sel_end = m_selection_.end;
    bool swapped = sel_end < sel_start;
    if (swapped) std::swap(sel_start, sel_end);

    if (target == HandleDragTarget::START) {
      sel_start = pos;
    } else {
      sel_end = pos;
    }

    // If dragging causes start > end, swap them and switch drag target
    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
      m_dragging_handle_ = (target == HandleDragTarget::START) ? HandleDragTarget::END : HandleDragTarget::START;
    }

    m_selection_.start = sel_start;
    m_selection_.end = sel_end;
    m_has_selection_ = !(sel_start == sel_end);
    m_cursor_position_ = (m_dragging_handle_ == HandleDragTarget::END) ? sel_end : sel_start;

    // Compute edge-scroll state (does NOT scroll here; just records speed/direction).
    // Actual scrolling happens in tickEdgeScroll() called by platform timer.
    updateEdgeScrollState(screen_point, /*is_handle_drag=*/true, /*is_mouse=*/false);

    LOGD("EditorCore::dragHandleTo, selection = %s", m_selection_.dump().c_str());
  }

  void EditorCore::moveCursorLeft(bool extend_selection) {
    if (m_document_ == nullptr) return;

    if (m_has_selection_ && !extend_selection) {
      TextRange range = getNormalizedSelection();
      moveCursorTo(range.start, false);
      return;
    }

    TextPosition new_pos = m_cursor_position_;
    if (new_pos.column > 0) {
      U16String line_text = m_document_->getLineU16Text(new_pos.line);
      size_t col = new_pos.column;
      if (col >= 2) {
        U16Char low = line_text[col - 1];
        U16Char high = line_text[col - 2];
        if (low >= 0xDC00 && low <= 0xDFFF && high >= 0xD800 && high <= 0xDBFF) {
          new_pos.column -= 2;
        } else {
          new_pos.column -= 1;
        }
      } else {
        new_pos.column -= 1;
      }
    } else if (new_pos.line > 0) {
      new_pos.line -= 1;
      new_pos.column = m_document_->getLineColumns(new_pos.line);
    }
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorRight(bool extend_selection) {
    if (m_document_ == nullptr) return;

    if (m_has_selection_ && !extend_selection) {
      TextRange range = getNormalizedSelection();
      moveCursorTo(range.end, false);
      return;
    }

    TextPosition new_pos = m_cursor_position_;
    uint32_t line_cols = m_document_->getLineColumns(new_pos.line);
    if (new_pos.column < line_cols) {
      U16String line_text = m_document_->getLineU16Text(new_pos.line);
      size_t col = new_pos.column;
      if (col + 1 < line_text.length()) {
        U16Char high = line_text[col];
        U16Char low = line_text[col + 1];
        if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
          new_pos.column += 2;
        } else {
          new_pos.column += 1;
        }
      } else {
        new_pos.column += 1;
      }
    } else if (new_pos.line + 1 < m_document_->getLineCount()) {
      new_pos.line += 1;
      new_pos.column = 0;
    }
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorUp(bool extend_selection) {
    if (m_document_ == nullptr) return;

    if (m_cursor_position_.line == 0) {
      moveCursorTo({0, 0}, extend_selection);
      return;
    }

    // Find the nearest visible line above
    size_t target_line = m_cursor_position_.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      if (target_line == 0) {
        moveCursorTo({0, 0}, extend_selection);
        return;
      }
      --target_line;
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_cursor_position_);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTest(target_point);
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorDown(bool extend_selection) {
    if (m_document_ == nullptr) return;

    size_t line_count = m_document_->getLineCount();
    if (m_cursor_position_.line + 1 >= line_count) {
      uint32_t cols = m_document_->getLineColumns(m_cursor_position_.line);
      moveCursorTo({m_cursor_position_.line, cols}, extend_selection);
      return;
    }

    // Find the nearest visible line below
    size_t target_line = m_cursor_position_.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      ++target_line;
      if (target_line >= line_count) {
        uint32_t cols = m_document_->getLineColumns(line_count - 1);
        moveCursorTo({line_count - 1, cols}, extend_selection);
        return;
      }
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_cursor_position_);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTest(target_point);
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorToLineStart(bool extend_selection) {
    if (m_document_ == nullptr) return;
    moveCursorTo({m_cursor_position_.line, 0}, extend_selection);
  }

  void EditorCore::moveCursorToLineEnd(bool extend_selection) {
    if (m_document_ == nullptr) return;
    uint32_t cols = m_document_->getLineColumns(m_cursor_position_.line);
    moveCursorTo({m_cursor_position_.line, cols}, extend_selection);
  }
#pragma endregion

#pragma region [IME-Composition]
  void EditorCore::compositionStart() {
    if (m_document_ == nullptr || m_settings_.read_only) return;

    // If already in composition state, cancel current composition first
    if (m_composition_.is_composing) {
      removeComposingText();
      resetCompositionState();
    }

    // If there is a selection, delete it first (keep selection in linked editing and replace in insertText)
    if (m_has_selection_ && !isInLinkedEditing()) {
      deleteSelection();
    }

    m_composition_.is_composing = true;
    m_composition_.start_position = m_cursor_position_;
    if (isInLinkedEditing() && m_has_selection_) {
      m_composition_.start_position = getNormalizedSelection().start;
    }
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;

    LOGD("EditorCore::compositionStart, pos = %s", m_cursor_position_.dump().c_str());
  }

  void EditorCore::compositionUpdate(const U8String& text) {
    if (m_document_ == nullptr || m_settings_.read_only) return;

    // When composition is disabled, ignore intermediate composing text and handle at compositionEnd
    if (!m_settings_.enable_composition) {
      return;
    }

    // If composition has not started yet, start it automatically
    if (!m_composition_.is_composing) {
      compositionStart();
    }

    if (isInLinkedEditing()) {
      m_composition_.composing_text = text;
      m_composition_.composing_columns = calcUtf16Columns(text);
      m_composition_text_in_document_ = false;
      TextPosition new_pos = calcPositionAfterInsert(m_composition_.start_position, text);
      setCursorPosition(new_pos);
      ensureCursorVisible();
      LOGD("EditorCore::compositionUpdate(linked), text = %s, columns = %zu",
           text.c_str(), m_composition_.composing_columns);
      return;
    }

    // Remove previous composing text first
    removeComposingText();

    // Insert new composing text into document
    if (!text.empty()) {
      m_document_->insertU8Text(m_composition_.start_position, text);
      size_t new_columns = calcUtf16Columns(text);
      m_composition_.composing_text = text;
      m_composition_.composing_columns = new_columns;
      m_composition_text_in_document_ = true;
      // Move cursor to end of composing text
      TextPosition new_pos = calcPositionAfterInsert(m_composition_.start_position, text);
      setCursorPosition(new_pos);
    } else {
      m_composition_.composing_text.clear();
      m_composition_.composing_columns = 0;
      m_composition_text_in_document_ = false;
    }

    m_text_layout_->invalidateContentMetrics(m_composition_.start_position.line);
    ensureCursorVisible();
    LOGD("EditorCore::compositionUpdate, text = %s, columns = %zu",
         text.c_str(), m_composition_.composing_columns);
  }

  TextEditResult EditorCore::compositionEnd(const U8String& committed_text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // When composition is disabled, fall back to direct insertion
    if (!m_settings_.enable_composition) {
      if (!committed_text.empty()) {
        return insertText(committed_text);
      }
      return {};
    }

    if (!m_composition_.is_composing) {
      // Not in composition state, insert committed text directly
      if (!committed_text.empty()) {
        return insertText(committed_text);
      }
      return {};
    }

    // Decide final text to commit
    U8String final_text = committed_text.empty() ? m_composition_.composing_text : committed_text;

    removeComposingText();

    resetCompositionState();

    TextEditResult edit_result;
    if (!final_text.empty()) {
      edit_result = insertText(final_text);
    }

    ensureCursorVisible();
    LOGD("EditorCore::compositionEnd, cursor = %s", m_cursor_position_.dump().c_str());
    return edit_result;
  }

  void EditorCore::compositionCancel() {
    if (!m_composition_.is_composing) return;

    removeComposingText();

    // Save start line first, then clear composition state (resetCompositionState resets start_position)
    size_t comp_start_line = m_composition_.start_position.line;
    resetCompositionState();

    m_text_layout_->invalidateContentMetrics(comp_start_line);
    ensureCursorVisible();
    LOGD("EditorCore::compositionCancel, cursor = %s", m_cursor_position_.dump().c_str());
  }

  const CompositionState& EditorCore::getCompositionState() const {
    return m_composition_;
  }

  bool EditorCore::isComposing() const {
    return m_composition_.is_composing;
  }

  void EditorCore::setCompositionEnabled(bool enabled) {
    if (!enabled && m_composition_.is_composing) {
      compositionCancel();
    }
    m_settings_.enable_composition = enabled;
    LOGD("EditorCore::setCompositionEnabled, enabled = %s", enabled ? "true" : "false");
  }

  bool EditorCore::isCompositionEnabled() const {
    return m_settings_.enable_composition;
  }
#pragma endregion

#pragma region [ReadOnly]
  void EditorCore::setReadOnly(bool read_only) {
    if (read_only && m_composition_.is_composing) {
      compositionCancel();
    }
    m_settings_.read_only = read_only;
    LOGD("EditorCore::setReadOnly, read_only = %s", read_only ? "true" : "false");
  }

  bool EditorCore::isReadOnly() const {
    return m_settings_.read_only;
  }
#pragma endregion

#pragma region [AutoIndent]
  void EditorCore::setAutoIndentMode(AutoIndentMode mode) {
    m_settings_.auto_indent_mode = mode;
    LOGD("EditorCore::setAutoIndentMode, mode = %d", (int)mode);
  }

  AutoIndentMode EditorCore::getAutoIndentMode() const {
    return m_settings_.auto_indent_mode;
  }
#pragma endregion

#pragma region [Cursor-ScreenRect]
  CursorRect EditorCore::getPositionScreenRect(const TextPosition& position) {
    CursorRect rect;
    if (m_text_layout_ == nullptr) return rect;
    PointF coord = m_text_layout_->getPositionScreenCoord(position);
    rect.x = coord.x;
    rect.y = coord.y;
    rect.height = m_text_layout_->getLineHeight();
    return rect;
  }

  CursorRect EditorCore::getCursorScreenRect() {
    return getPositionScreenRect(m_cursor_position_);
  }
#pragma endregion

#pragma region [LinkedEditing]
  TextEditResult EditorCore::insertSnippet(const U8String& snippet_template) {
    if (m_document_ == nullptr || snippet_template.empty() || m_settings_.read_only) return {};

    // If composition is active, cancel it first
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Exit existing linked editing session
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    // Determine insertion position
    TextPosition insert_pos = m_cursor_position_;
    TextRange replace_range = {insert_pos, insert_pos};
    if (m_has_selection_) {
      replace_range = getNormalizedSelection();
      insert_pos = replace_range.start;
    }

    // Parse snippet
    SnippetParseResult parse_result = SnippetParser::parse(snippet_template, insert_pos);

    // Insert expanded plain text
    TextEditResult edit_result = applyEdit(replace_range, parse_result.text);

    // If tab stops exist, start linked editing
    if (!parse_result.model.groups.empty()) {
      m_linked_editing_session_ = makeUPtr<LinkedEditingSession>(std::move(parse_result.model));
      activateCurrentTabStop();
    }

    LOGD("EditorCore::insertSnippet, cursor = %s", m_cursor_position_.dump().c_str());
    return edit_result;
  }

  void EditorCore::startLinkedEditing(LinkedEditingModel&& model) {
    if (m_document_ == nullptr || m_settings_.read_only) return;
    if (model.groups.empty()) return;

    // If composition is active, cancel it first
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Exit existing linked editing session
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    m_linked_editing_session_ = makeUPtr<LinkedEditingSession>(std::move(model));
    activateCurrentTabStop();

    LOGD("EditorCore::startLinkedEditing, cursor = %s", m_cursor_position_.dump().c_str());
  }

  bool EditorCore::isInLinkedEditing() const {
    return m_linked_editing_session_ != nullptr && m_linked_editing_session_->isActive();
  }

  bool EditorCore::linkedEditingNextTabStop() {
    if (!isInLinkedEditing()) return false;
    bool has_next = m_linked_editing_session_->nextTabStop();
    if (has_next) {
      activateCurrentTabStop();
    } else {
      // At the end: finish session and move cursor to $0
      finishLinkedEditing();
    }
    return has_next;
  }

  bool EditorCore::linkedEditingPrevTabStop() {
    if (!isInLinkedEditing()) return false;
    bool has_prev = m_linked_editing_session_->prevTabStop();
    if (has_prev) {
      activateCurrentTabStop();
    }
    return has_prev;
  }

  void EditorCore::finishLinkedEditing() {
    if (!m_linked_editing_session_) return;
    // Get final cursor position for $0 before cancel
    TextPosition final_pos = m_linked_editing_session_->finalCursorPosition();
    m_linked_editing_session_->cancel();
    m_linked_editing_session_.reset();
    setCursorPosition(final_pos);
    clearSelection();
    ensureCursorVisible();
  }

  void EditorCore::cancelLinkedEditing() {
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }
  }

  TextEditResult EditorCore::applyLinkedEditsWithResult(const U8String& new_text) {
    TextEditResult result;
    if (!isInLinkedEditing() || m_document_ == nullptr) return result;

    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    if (group == nullptr || group->ranges.empty()) return result;

    const TextRange primary_before = group->ranges[0];
    const U8String old_text = m_document_->getU8Text(primary_before);
    if (old_text == new_text) return result;

    const TextPosition cursor_before = m_cursor_position_;
    auto changes = performLinkedEdits(new_text);

    result.changed = true;
    result.changes = std::move(changes);
    result.cursor_before = cursor_before;
    result.cursor_after = m_cursor_position_;
    return result;
  }

  std::vector<TextChange> EditorCore::performLinkedEdits(const U8String& new_text) {
    std::vector<TextChange> changes;
    if (!isInLinkedEditing()) return changes;

    auto edits = m_linked_editing_session_->computeLinkedEdits(new_text);
    if (edits.empty()) return changes;

    // Begin undo group
    m_undo_manager_->beginGroup(m_cursor_position_, m_has_selection_, m_selection_);

    // Replace from back to front to avoid offset issues
    for (const auto& [range, text] : edits) {
      // Collect change info (coordinates before replacement)
      TextChange change;
      change.range = range;
      if (range.start != range.end) {
        change.old_text = m_document_->getU8Text(range);
      }
      change.new_text = text;
      changes.push_back(std::move(change));

      applyEdit(range, text, true);
      // After each applyEdit, update session range offsets
      TextPosition new_end = calcPositionAfterInsert(range.start, text);
      m_linked_editing_session_->adjustRangesForEdit(range, new_end);
    }

    // End undo group
    m_undo_manager_->endGroup(m_cursor_position_);

    // Reverse to forward order (edits were back-to-front; now sorted by document position)
    std::reverse(changes.begin(), changes.end());

    // Move cursor to end of primary range
    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    if (group && !group->ranges.empty()) {
      setCursorPosition(group->ranges[0].end);
      clearSelection();
    }

    ensureCursorVisible();
    return changes;
  }

  void EditorCore::activateCurrentTabStop() {
    if (!isInLinkedEditing()) return;
    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    if (group == nullptr || group->ranges.empty()) return;

    const TextRange& primary = group->ranges[0];
    if (primary.start == primary.end) {
      // Empty range: only move cursor
      setCursorPosition(primary.start);
      clearSelection();
    } else {
      // Has default text: select it
      setSelection(primary);
    }
    ensureCursorVisible();
  }
#pragma endregion

#pragma region [Scroll-Goto]
  void EditorCore::scrollToLine(size_t line, ScrollBehavior behavior) {
    if (m_document_ == nullptr) return;

    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) return;

    // Clamp line number to valid range
    if (line >= logical_lines.size()) {
      line = logical_lines.size() - 1;
    }

    // Ensure lines from 0 to target are laid out (layoutLine depends on previous line's start_y + height)
    for (size_t i = 0; i <= line; ++i) {
      m_text_layout_->layoutLine(i, logical_lines[i]);
    }

    float target_y = logical_lines[line].start_y;
    float line_height = logical_lines[line].height;

    switch (behavior) {
      case ScrollBehavior::GOTO_TOP:
        m_view_state_.scroll_y = target_y;
        break;
      case ScrollBehavior::GOTO_CENTER:
        m_view_state_.scroll_y = target_y - (m_viewport_.height - line_height) * 0.5f;
        break;
      case ScrollBehavior::GOTO_BOTTOM:
        m_view_state_.scroll_y = target_y - m_viewport_.height + line_height;
        break;
    }

    normalizeScrollState();
    LOGD("EditorCore::scrollToLine, line = %zu, m_view_state_ = %s", line, m_view_state_.dump().c_str());
  }

  void EditorCore::gotoPosition(size_t line, size_t column) {
    if (m_document_ == nullptr) return;

    scrollToLine(line, ScrollBehavior::GOTO_CENTER);
    clearSelection();
    setCursorPosition({line, column});
    ensureCursorVisible();
    LOGD("EditorCore::gotoLine, line = %zu, column = %zu, cursor = %s",
         line, column, m_cursor_position_.dump().c_str());
  }

  void EditorCore::setScroll(float scroll_x, float scroll_y) {
    m_view_state_.scroll_x = scroll_x;
    m_view_state_.scroll_y = scroll_y;
    normalizeScrollState();
    LOGD("EditorCore::setScroll, m_view_state_ = %s", m_view_state_.dump().c_str());
  }
#pragma endregion

#pragma region [Decorations]
  void EditorCore::registerTextStyle(uint32_t style_id, TextStyle&& style) {
    m_decorations_->getTextStyleRegistry()->registerTextStyle(style_id, std::move(style));
  }

  void EditorCore::setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans) {
    m_decorations_->setLineSpans(line, layer, std::move(spans));
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
  }

  void EditorCore::setBatchLineSpans(SpanLayer layer, Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries) {
    if (entries.empty()) return;
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, spans] : entries) {
      m_decorations_->setLineSpans(line, layer, std::move(spans));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    m_text_layout_->invalidateContentMetrics(min_line);
  }

  void EditorCore::setLineInlayHints(size_t line, Vector<InlayHint>&& hints) {
    m_decorations_->setLineInlayHints(line, std::move(hints));
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
  }

  void EditorCore::setBatchLineInlayHints(Vector<std::pair<size_t, Vector<InlayHint>>>&& entries) {
    if (entries.empty()) return;
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, hints] : entries) {
      m_decorations_->setLineInlayHints(line, std::move(hints));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    m_text_layout_->invalidateContentMetrics(min_line);
  }

  void EditorCore::setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms) {
    m_decorations_->setLinePhantomTexts(line, std::move(phantoms));
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
  }

  void EditorCore::setBatchLinePhantomTexts(Vector<std::pair<size_t, Vector<PhantomText>>>&& entries) {
    if (entries.empty()) return;
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, phantoms] : entries) {
      m_decorations_->setLinePhantomTexts(line, std::move(phantoms));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    m_text_layout_->invalidateContentMetrics(min_line);
  }

  void EditorCore::setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons) {
    m_decorations_->setLineGutterIcons(line, std::move(icons));
  }

  void EditorCore::setBatchLineGutterIcons(Vector<std::pair<size_t, Vector<GutterIcon>>>&& entries) {
    if (entries.empty()) return;
    for (auto& [line, icons] : entries) {
      m_decorations_->setLineGutterIcons(line, std::move(icons));
    }
  }

  void EditorCore::setMaxGutterIcons(uint32_t count) {
    if (m_text_layout_->getLayoutMetrics().max_gutter_icons == count) return;
    m_text_layout_->getLayoutMetrics().max_gutter_icons = count;
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setLineDiagnostics(size_t line, Vector<DiagnosticSpan>&& diagnostics) {
    m_decorations_->setLineDiagnostics(line, std::move(diagnostics));
  }

  void EditorCore::setBatchLineDiagnostics(Vector<std::pair<size_t, Vector<DiagnosticSpan>>>&& entries) {
    if (entries.empty()) return;
    for (auto& [line, diagnostics] : entries) {
      m_decorations_->setLineDiagnostics(line, std::move(diagnostics));
    }
  }

  void EditorCore::clearDiagnostics() {
    m_decorations_->clearDiagnostics();
  }

  void EditorCore::setIndentGuides(Vector<IndentGuide>&& guides) {
    m_decorations_->setIndentGuides(std::move(guides));
  }

  void EditorCore::setBracketGuides(Vector<BracketGuide>&& guides) {
    m_decorations_->setBracketGuides(std::move(guides));
  }

  void EditorCore::setFlowGuides(Vector<FlowGuide>&& guides) {
    m_decorations_->setFlowGuides(std::move(guides));
  }

  void EditorCore::setSeparatorGuides(Vector<SeparatorGuide>&& guides) {
    m_decorations_->setSeparatorGuides(std::move(guides));
  }

  void EditorCore::buildCursorModel(EditorRenderModel& model, float line_height) {
    PointF cursor_screen = m_text_layout_->getPositionScreenCoord(m_cursor_position_);
    model.cursor.text_position = m_cursor_position_;
    model.cursor.position = cursor_screen;
    model.cursor.height = line_height;
    model.cursor.visible = !m_has_selection_;
    model.cursor.show_dragger = false;
    model.current_line = {0, cursor_screen.y};
  }

  void EditorCore::buildCompositionDecoration(EditorRenderModel& model, float line_height, float font_height) {
    if (!m_composition_.is_composing || m_composition_.composing_columns == 0) return;
    float top_padding = (line_height - font_height) * 0.5f;
    float x_start, x_end, comp_y;
    m_text_layout_->getColumnScreenRange(
      m_composition_.start_position.line,
      m_composition_.start_position.column,
      m_composition_.start_position.column + m_composition_.composing_columns,
      x_start, x_end, comp_y);
    model.composition_decoration.active = true;
    model.composition_decoration.origin = {x_start, comp_y + top_padding};
    model.composition_decoration.width = x_end - x_start;
    model.composition_decoration.height = font_height;
    LOGD("buildRenderModel: composition_decoration active=true, origin=(%.1f, %.1f), w=%.1f, h=%.1f, composing_cols=%zu, start_pos=(%zu,%zu)",
         x_start, comp_y + top_padding, x_end - x_start, font_height,
         m_composition_.composing_columns,
         m_composition_.start_position.line, m_composition_.start_position.column);
  }

  void EditorCore::buildSelectionRects(EditorRenderModel& model, float line_height) {
    if (!m_has_selection_ || m_document_ == nullptr) {
      m_cached_handles_valid_ = false;
      return;
    }

    // Normalize selection range (ensure start < end)
    TextPosition sel_start = m_selection_.start;
    TextPosition sel_end = m_selection_.end;
    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
    }

    for (size_t line = sel_start.line; line <= sel_end.line && line < m_document_->getLineCount(); ++line) {
      // Skip fold-hidden lines
      const auto& ll = m_document_->getLogicalLines()[line];
      if (ll.is_fold_hidden) continue;

      size_t col_begin = (line == sel_start.line) ? sel_start.column : 0;
      uint32_t line_cols = m_document_->getLineColumns(line);
      size_t col_end_val = (line == sel_end.line) ? sel_end.column : line_cols;

      if (col_begin >= col_end_val && line != sel_end.line) {
        // Empty line or line-start selection: draw a minimum-width rectangle
        PointF coord = m_text_layout_->getPositionScreenCoord({line, col_begin});
        SelectionRect rect;
        rect.origin = coord;
        rect.width = m_text_layout_->getLineHeight() * 0.3f;
        rect.height = line_height;
        model.selection_rects.push_back(rect);
        continue;
      }

      if (col_begin < col_end_val) {
        m_text_layout_->getColumnSelectionRects(line, col_begin, col_end_val, line_height,
                                                 model.selection_rects);
      }
    }

    // Compute cursor positions at both selection ends
    PointF start_coord = m_text_layout_->getPositionScreenCoord(sel_start);
    model.selection_start_handle.position = start_coord;
    model.selection_start_handle.height = line_height;
    model.selection_start_handle.visible = true;

    PointF end_coord = m_text_layout_->getPositionScreenCoord(sel_end);
    model.selection_end_handle.position = end_coord;
    model.selection_end_handle.height = line_height;
    model.selection_end_handle.visible = true;

    // Cache cursor positions for hit testing in next frame
    m_cached_start_handle_pos_ = start_coord;
    m_cached_end_handle_pos_ = end_coord;
    m_cached_handle_height_ = line_height;
    m_cached_handles_valid_ = true;
  }

  void EditorCore::buildLinkedEditingRects(EditorRenderModel& model, float line_height) {
    if (!m_linked_editing_session_ || !m_linked_editing_session_->isActive()) return;
    if (m_document_ == nullptr) return;

    auto highlights = m_linked_editing_session_->getAllHighlights();
    for (const auto& hl : highlights) {
      if (hl.range.start == hl.range.end) continue;
      for (size_t line = hl.range.start.line; line <= hl.range.end.line && line < m_document_->getLineCount(); ++line) {
        size_t col_begin = (line == hl.range.start.line) ? hl.range.start.column : 0;
        uint32_t line_cols = m_document_->getLineColumns(line);
        size_t col_end = (line == hl.range.end.line) ? hl.range.end.column : line_cols;
        if (col_begin >= col_end) continue;
        float x_start, x_end, y;
        m_text_layout_->getColumnScreenRange(line, col_begin, col_end, x_start, x_end, y);
        LinkedEditingRect rect;
        rect.origin = {x_start, y};
        rect.width = x_end - x_start;
        rect.height = line_height;
        rect.is_active = hl.is_active;
        model.linked_editing_rects.push_back(rect);
      }
    }
  }

  void EditorCore::buildGuideSegments(EditorRenderModel& model, float line_height) {
    if (m_decorations_ == nullptr || m_document_ == nullptr) return;

    const LayoutMetrics& params = getLayoutMetrics();
    float half_line = line_height * 0.5f;
    float equal_gap = params.font_height * 0.1f;
    float dash_y_offset = params.font_ascent * 0.75f;

    U16String space_char = CHAR16(" ");
    float char_width = m_measurer_->measureWidth(space_char, FONT_STYLE_NORMAL);

    auto screenY = [&](size_t line) -> float {
      return m_text_layout_->getPositionScreenCoord({line, 0}).y;
    };
    auto screenX = [&](size_t line, size_t col) -> float {
      return m_text_layout_->getPositionScreenCoord({line, col}).x;
    };

    // 1) IndentGuide: vertical line from bottom of start line to top of end line (skip guides in folded regions)
    for (const auto& ig : m_decorations_->getIndentGuides()) {
      if (m_decorations_->isLineHidden(ig.start.line) || m_decorations_->isLineHidden(ig.end.line)) continue;
      float x = screenX(ig.start.line, ig.start.column);
      float y_top = screenY(ig.start.line) + line_height;
      float y_bot = screenY(ig.end.line);
      if (y_top >= y_bot) continue;
      GuideSegment seg;
      seg.direction = GuideDirection::VERTICAL;
      seg.type = GuideType::INDENT;
      seg.style = GuideStyle::SOLID;
      seg.start = {x, y_top};
      seg.end = {x, y_bot};
      model.guide_segments.push_back(seg);
    }

    // 2) BracketGuide: vertical line + horizontal connector for each child (T shape, skip folded regions)
    for (const auto& bg : m_decorations_->getBracketGuides()) {
      if (m_decorations_->isLineHidden(bg.parent.line) || m_decorations_->isLineHidden(bg.end.line)) continue;
      float x = screenX(bg.parent.line, bg.parent.column);
      float y_top = screenY(bg.parent.line) + line_height;
      float y_bot = screenY(bg.end.line);
      if (y_top < y_bot) {
        GuideSegment vline;
        vline.direction = GuideDirection::VERTICAL;
        vline.type = GuideType::BRACKET;
        vline.style = GuideStyle::SOLID;
        vline.start = {x, y_top};
        vline.end = {x, y_bot};
        model.guide_segments.push_back(vline);
      }
      for (const auto& child : bg.children) {
        if (m_decorations_->isLineHidden(child.line)) continue;
        float child_y = screenY(child.line) + half_line;
        float child_x = screenX(child.line, child.column);
        GuideSegment hline;
        hline.direction = GuideDirection::HORIZONTAL;
        hline.type = GuideType::BRACKET;
        hline.style = GuideStyle::SOLID;
        hline.start = {x, child_y};
        hline.end = {child_x, child_y};
        model.guide_segments.push_back(hline);
      }
    }

    // 3) FlowGuide: three segments (skip folded regions)
    for (const auto& fg : m_decorations_->getFlowGuides()) {
      if (m_decorations_->isLineHidden(fg.start.line) || m_decorations_->isLineHidden(fg.end.line)) continue;
      float indent_x = screenX(fg.end.line, fg.end.column);
      float left_x = indent_x - char_width * 2;
      float y_bot = screenY(fg.end.line) + half_line;
      float y_top = screenY(fg.start.line) + half_line;

      GuideSegment h_bot;
      h_bot.direction = GuideDirection::HORIZONTAL;
      h_bot.type = GuideType::FLOW;
      h_bot.style = GuideStyle::SOLID;
      h_bot.start = {indent_x, y_bot};
      h_bot.end = {left_x, y_bot};
      model.guide_segments.push_back(h_bot);

      GuideSegment vline;
      vline.direction = GuideDirection::VERTICAL;
      vline.type = GuideType::FLOW;
      vline.style = GuideStyle::SOLID;
      vline.start = {left_x, y_bot};
      vline.end = {left_x, y_top};
      model.guide_segments.push_back(vline);

      GuideSegment h_top;
      h_top.direction = GuideDirection::HORIZONTAL;
      h_top.type = GuideType::FLOW;
      h_top.style = GuideStyle::SOLID;
      h_top.start = {left_x, y_top};
      h_top.end = {indent_x, y_top};
      h_top.arrow_end = true;
      model.guide_segments.push_back(h_top);
    }

    // 4) SeparatorGuide: horizontal line (skip fold-hidden lines)
    for (const auto& sep : m_decorations_->getSeparatorGuides()) {
      if (m_decorations_->isLineHidden(static_cast<size_t>(sep.line))) continue;
      float x_start = screenX(static_cast<size_t>(sep.line), sep.text_end_column);
      float sep_width = static_cast<float>(sep.count) * 16.0f * char_width;
      float y_center = screenY(static_cast<size_t>(sep.line)) + half_line;
      GuideSegment seg;
      seg.direction = GuideDirection::HORIZONTAL;
      seg.type = GuideType::SEPARATOR;
      seg.style = GuideStyle::SOLID;
      if (sep.style == SeparatorStyle::DOUBLE) {
        seg.start = {x_start, y_center - equal_gap};
        seg.end = {x_start + sep_width, y_center - equal_gap};
        model.guide_segments.push_back(seg);
        seg.start = {x_start, y_center + equal_gap};
        seg.end = {x_start + sep_width, y_center + equal_gap};
        model.guide_segments.push_back(seg);
      } else {
        float line_top = screenY(static_cast<size_t>(sep.line));
        float y_dash = line_top + dash_y_offset;
        seg.start = {x_start, y_dash};
        seg.end = {x_start + sep_width, y_dash};
        model.guide_segments.push_back(seg);
      }
    }
  }

  void EditorCore::syncFoldState() {
    if (m_document_ == nullptr) return;
    auto& lines = m_document_->getLogicalLines();
    // Record old state first, then reset
    for (auto& ll : lines) {
      bool was_hidden = ll.is_fold_hidden;
      ll.is_fold_hidden = false;
      // Lines changed from hidden to visible need relayout (visual_lines has been cleared)
      if (was_hidden) {
        ll.is_layout_dirty = true;
      }
    }
    // Start line of each fold region needs relayout (fold state changes affect FOLD_PLACEHOLDER generation)
    for (const auto& fr : m_decorations_->getFoldRegions()) {
      if (fr.start_line < lines.size()) {
        lines[fr.start_line].is_layout_dirty = true;
      }
      if (!fr.collapsed) continue;
      for (size_t i = fr.start_line + 1; i <= fr.end_line && i < lines.size(); ++i) {
        lines[i].is_fold_hidden = true;
        lines[i].is_layout_dirty = true;
      }
    }
    normalizeScrollState();
  }

  void EditorCore::autoUnfoldForEdit(const TextRange& range) {
    bool unfolded = false;
    for (auto& fr : m_decorations_->getFoldRegionsMut()) {
      if (!fr.collapsed) continue;
      bool overlaps = range.start.line <= fr.end_line && range.end.line >= fr.start_line;
      if (overlaps) {
        fr.collapsed = false;
        unfolded = true;
      }
    }
    if (unfolded) {
      syncFoldState();
    }
  }

  void EditorCore::setFoldRegions(Vector<FoldRegion>&& regions) {
    bool had_fold_regions = m_text_layout_->getLayoutMetrics().has_fold_regions;
    m_text_layout_->getLayoutMetrics().has_fold_regions = !regions.empty();
    if (had_fold_regions != m_text_layout_->getLayoutMetrics().has_fold_regions) {
      markAllLinesDirty();
    }
    m_decorations_->setFoldRegions(std::move(regions));
    syncFoldState();
  }

  bool EditorCore::foldAt(size_t line) {
    bool result = m_decorations_->foldAt(line);
    if (result) syncFoldState();
    return result;
  }

  bool EditorCore::unfoldAt(size_t line) {
    bool result = m_decorations_->unfoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  bool EditorCore::toggleFoldAt(size_t line) {
    bool result = m_decorations_->toggleFoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  void EditorCore::foldAll() {
    m_decorations_->foldAll();
    syncFoldState();
  }

  void EditorCore::unfoldAll() {
    m_decorations_->unfoldAll();
    syncFoldState();
  }

  bool EditorCore::isLineVisible(size_t line) const {
    return !m_decorations_->isLineHidden(line);
  }

  void EditorCore::clearHighlights(SpanLayer layer) {
    m_decorations_->clearHighlights(layer);
    markAllLinesDirty();
  }

  void EditorCore::clearHighlights() {
    m_decorations_->clearHighlights();
    markAllLinesDirty();
  }

  void EditorCore::clearInlayHints() {
    m_decorations_->clearInlayHints();
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::clearPhantomTexts() {
    m_decorations_->clearPhantomTexts();
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::clearGutterIcons() {
    m_decorations_->clearGutterIcons();
    markAllLinesDirty();
  }

  void EditorCore::clearGuides() {
    m_decorations_->clearGuides();
    markAllLinesDirty();
  }

  void EditorCore::clearAllDecorations() {
    m_decorations_->clearAll();
    markAllLinesDirty();
  }

  void EditorCore::buildDiagnosticDecorations(EditorRenderModel& model, float line_height) {
    if (m_decorations_ == nullptr || m_document_ == nullptr) return;

    // Compute centered vertical offset so decoration lines follow text bottom, not line bottom
    float font_height = m_text_layout_->getLayoutMetrics().font_height;
    float top_padding = (line_height - font_height) * 0.5f;

    for (const auto& vl : model.lines) {
      if (vl.is_phantom_line) continue;
      size_t logical_line = vl.logical_line;
      const auto& diags = m_decorations_->getLineDiagnostics(logical_line);
      if (diags.empty()) continue;

      for (const auto& ds : diags) {
        if (ds.length == 0) continue;
        float x_start, x_end, y;
        m_text_layout_->getColumnScreenRange(
          logical_line,
          ds.column,
          ds.column + ds.length,
          x_start, x_end, y);
        DiagnosticDecoration dd;
        dd.origin = {x_start, y + top_padding};
        dd.width = x_end - x_start;
        dd.height = font_height;
        dd.severity = static_cast<int32_t>(ds.severity);
        dd.color = ds.color;
        model.diagnostic_decorations.push_back(dd);
      }
    }
  }

  void EditorCore::setBracketPairs(Vector<BracketPair> pairs) {
    m_bracket_pairs_ = std::move(pairs);
  }

  void EditorCore::setMatchedBrackets(const TextPosition& open, const TextPosition& close) {
    m_external_bracket_open_ = open;
    m_external_bracket_close_ = close;
    m_has_external_brackets_ = true;
  }

  void EditorCore::clearMatchedBrackets() {
    m_has_external_brackets_ = false;
    m_external_bracket_open_ = {};
    m_external_bracket_close_ = {};
  }
#pragma endregion

  void EditorCore::placeCursorAt(const PointF& screen_point) {
    TextPosition pos = m_text_layout_->hitTest(screen_point);
    setCursorPosition(pos);
    clearSelection();
    LOGD("EditorCore::placeCursorAt, pos = %s", pos.dump().c_str());
  }


  void EditorCore::selectWordAt(const PointF& screen_point) {
    if (m_document_ == nullptr) return;
    TextPosition pos = m_text_layout_->hitTest(screen_point);

    size_t line = pos.line;
    U16String line_text = m_document_->getLineU16Text(line);
    if (line_text.empty()) {
      setCursorPosition(pos);
      clearSelection();
      return;
    }

    size_t col = std::min(pos.column, line_text.length());

    // If click is beyond end of line, select the last word
    if (col >= line_text.length()) {
      col = line_text.length() > 0 ? line_text.length() - 1 : 0;
    }

    U16Char ch = line_text[col];
    bool is_word = isWordChar(ch);

    // Search left for word boundary
    size_t word_start = col;
    while (word_start > 0) {
      U16Char prev_ch = line_text[word_start - 1];
      if (is_word ? !isWordChar(prev_ch) : isWordChar(prev_ch)) break;
      if (!is_word && prev_ch != ch) break; // Non-word characters: group only identical ones
      --word_start;
    }

    // Search right for word boundary
    size_t word_end = col;
    while (word_end < line_text.length()) {
      U16Char next_ch = line_text[word_end];
      if (is_word ? !isWordChar(next_ch) : isWordChar(next_ch)) break;
      if (!is_word && next_ch != ch) break;
      ++word_end;
    }

    TextRange range = {{line, word_start}, {line, word_end}};
    setSelection(range);
    LOGD("EditorCore::selectWordAt, selection = %s", range.dump().c_str());
  }

  void EditorCore::dragSelectTo(const PointF& screen_point, bool is_mouse) {
    // Long-press drag selection: offset upward by drag_y_offset + line_height to keep
    // the selection endpoint well above the finger.
    // Mouse drag does NOT apply this offset (cursor does not occlude text).
    PointF adjusted_point = screen_point;
    if (!is_mouse) {
      const float line_height = m_text_layout_->getLineHeight();
      const float total_offset = m_settings_.handle.drag_y_offset + line_height;
      adjusted_point.y -= total_offset;
    }

    TextPosition pos = m_text_layout_->hitTest(adjusted_point);

    if (!m_has_selection_) {
      m_selection_.start = m_cursor_position_;
      m_selection_.end = pos;
      m_has_selection_ = !(m_selection_.start == pos);
    } else {
      m_selection_.end = pos;
      m_has_selection_ = !(m_selection_.start == m_selection_.end);
    }
    m_cursor_position_ = pos;

    // Compute edge-scroll state (does NOT scroll here; just records speed/direction).
    // Actual scrolling happens in tickEdgeScroll() called by platform timer.
    updateEdgeScrollState(screen_point, /*is_handle_drag=*/false, is_mouse);

    LOGD("EditorCore::dragSelectTo, selection = %s", m_selection_.dump().c_str());
  }

  void EditorCore::ensureCursorVisible() {
    PointF cursor_screen = m_text_layout_->getPositionScreenCoord(m_cursor_position_);
    float line_height = m_text_layout_->getLineHeight();

    if (cursor_screen.y < 0) {
      m_view_state_.scroll_y = std::max(0.0f, m_view_state_.scroll_y + cursor_screen.y);
    } else if (cursor_screen.y + line_height > m_viewport_.height) {
      m_view_state_.scroll_y += (cursor_screen.y + line_height - m_viewport_.height);
    }

    float text_area_x = m_text_layout_->getLayoutMetrics().gutterWidth();
    if (cursor_screen.x < text_area_x) {
      m_view_state_.scroll_x = std::max(0.0f, m_view_state_.scroll_x - (text_area_x - cursor_screen.x));
    } else if (cursor_screen.x > m_viewport_.width - 10) {
      m_view_state_.scroll_x += (cursor_screen.x - m_viewport_.width + 40);
    }

    normalizeScrollState();
  }

  void EditorCore::updateEdgeScrollState(const PointF& screen_point, bool is_handle_drag, bool is_mouse) {
    if (!m_viewport_.valid()) {
      m_edge_scroll_.active = false;
      return;
    }

    // Edge zone: 15% of viewport height, clamped to [30, 120] px
    const float kEdgeZoneRatio = 0.15f;
    const float kMinEdgeZone = 30.0f;
    const float kMaxEdgeZone = 120.0f;
    float edge_zone = std::clamp(m_viewport_.height * kEdgeZoneRatio,
                                 kMinEdgeZone, kMaxEdgeZone);

    // Max speed per 16ms tick: 2 line-heights
    const float line_height = m_text_layout_->getLineHeight();
    const float max_speed = line_height * 2.0f;

    float speed = 0.0f;
    if (screen_point.y < edge_zone) {
      float ratio = (edge_zone - screen_point.y) / edge_zone;
      speed = -max_speed * ratio;
    } else if (screen_point.y > m_viewport_.height - edge_zone) {
      float ratio = (screen_point.y - (m_viewport_.height - edge_zone)) / edge_zone;
      speed = max_speed * ratio;
    }

    if (speed != 0.0f) {
      m_edge_scroll_.active = true;
      m_edge_scroll_.speed = speed;
      m_edge_scroll_.last_screen_point = screen_point;
      m_edge_scroll_.is_handle_drag = is_handle_drag;
      m_edge_scroll_.is_mouse = is_mouse;
    } else {
      m_edge_scroll_.active = false;
      m_edge_scroll_.speed = 0.0f;
    }
  }

  GestureResult EditorCore::tickEdgeScroll() {
    GestureResult result;
    result.type = GestureType::DRAG_SELECT;

    if (!m_edge_scroll_.active) {
      fillGestureResult(result);
      result.needs_edge_scroll = false;
      return result;
    }

    // Apply scroll delta; the same screen point now maps to a new text position.
    m_view_state_.scroll_y += m_edge_scroll_.speed;
    normalizeScrollState();
    markScrollbarInteraction();

    // Reuse existing drag logic to update selection with the shifted viewport.
    // Both functions internally call updateEdgeScrollState() to re-evaluate
    // whether the edge zone is still active after scrolling.
    if (m_edge_scroll_.is_handle_drag) {
      dragHandleTo(m_dragging_handle_, m_edge_scroll_.last_screen_point);
    } else {
      dragSelectTo(m_edge_scroll_.last_screen_point, m_edge_scroll_.is_mouse);
    }

    fillGestureResult(result);
    result.needs_edge_scroll = m_edge_scroll_.active;
    return result;
  }

  void EditorCore::moveCursorTo(const TextPosition& new_pos, bool extend_selection) {
    if (extend_selection) {
      if (!m_has_selection_) {
        m_selection_.start = m_cursor_position_;
      }
      m_selection_.end = new_pos;
      m_has_selection_ = !(m_selection_.start == new_pos);
    } else {
      clearSelection();
    }
    setCursorPosition(new_pos);
    ensureCursorVisible();
  }

  TextRange EditorCore::getNormalizedSelection() const {
    TextRange range = m_selection_;
    if (range.end < range.start) {
      std::swap(range.start, range.end);
    }
    return range;
  }

  size_t EditorCore::calcUtf16Columns(const U8String& text) {
    return simdutf::utf16_length_from_utf8(text.data(), text.size());
  }

  TextPosition EditorCore::calcPositionAfterInsert(const TextPosition& start, const U8String& text) const {
    size_t new_line = start.line;
    size_t new_col = start.column;
    auto it = text.begin();
    while (it != text.end()) {
      char ch = *it;
      if (ch == '\n') {
        ++new_line;
        new_col = 0;
        ++it;
      } else if (ch == '\r') {
        ++new_line;
        new_col = 0;
        ++it;
        if (it != text.end() && *it == '\n') ++it;
      } else {
        uint32_t cp = utf8::next(it, text.end());
        new_col += (cp > 0xFFFF) ? 2 : 1;  // Supplementary-plane characters occupy 2 UTF-16 code units
      }
    }
    return {new_line, new_col};
  }

  void EditorCore::removeComposingText() {
    if (!m_composition_.is_composing || m_composition_.composing_columns == 0) return;
    if (!m_composition_text_in_document_) return;
    if (m_document_ == nullptr) return;

    // Composing text range: from start_position to start_position + composing_columns
    TextRange comp_range = {
      m_composition_.start_position,
      {m_composition_.start_position.line, m_composition_.start_position.column + m_composition_.composing_columns}
    };
    m_document_->deleteU8Text(comp_range);
    setCursorPosition(m_composition_.start_position);
    m_composition_text_in_document_ = false;
  }

  TextEditResult EditorCore::applyEdit(const TextRange& range, const U8String& new_text, bool record_undo) {
    if (m_document_ == nullptr) return {};

    // Auto-unfold when edit range overlaps a folded region
    autoUnfoldForEdit(range);

    TextEditResult edit_result;
    edit_result.changed = true;

    U8String old_text;
    bool is_delete = new_text.empty();
    bool is_insert = (range.start == range.end);
    bool is_replace = !is_delete && !is_insert;

    // Read old text (for delete/replace)
    if (!is_insert) {
      old_text = m_document_->getU8Text(range);
    }

    TextPosition cursor_before = m_cursor_position_;
    edit_result.cursor_before = cursor_before;
    bool had_selection = m_has_selection_;
    TextRange selection_before = m_selection_;

    // Perform document operation
    if (is_insert) {
      m_document_->insertU8Text(range.start, new_text);
    } else if (is_delete) {
      m_document_->deleteU8Text(range);
    } else {
      m_document_->replaceU8Text(range, new_text);
    }

    // Compute new cursor position
    TextPosition new_cursor;
    if (is_delete) {
      new_cursor = range.start;
    } else {
      new_cursor = calcPositionAfterInsert(range.start, new_text);
    }
    edit_result.cursor_after = new_cursor;

    // Fill changes
    TextChange change;
    change.range = range;
    change.old_text = old_text;
    change.new_text = new_text;
    edit_result.changes.push_back(std::move(change));

    // Adjust decoration offsets
    m_decorations_->adjustForEdit(range, new_cursor);

    // Mark content metrics cache dirty after edit (starting from edit start line)
    m_text_layout_->invalidateContentMetrics(range.start.line);

    setCursorPosition(new_cursor);
    clearSelection();

    // Record to undo stack
    if (record_undo) {
      EditAction action;
      action.range = range;
      action.old_text = old_text;
      action.new_text = new_text;
      action.cursor_before = cursor_before;
      action.cursor_after = new_cursor;
      action.had_selection = had_selection;
      action.selection_before = selection_before;
      action.timestamp = std::chrono::steady_clock::now();
      m_undo_manager_->pushAction(std::move(action));
    }

    ensureCursorVisible();
    return edit_result;
  }

  void EditorCore::markAllLinesDirty() {
    if (m_document_ == nullptr) return;
    for (auto& line : m_document_->getLogicalLines()) {
      line.is_layout_dirty = true;
    }
    if (m_text_layout_ != nullptr) {
      m_text_layout_->invalidateContentMetrics();
    }
  }

  void EditorCore::normalizeScrollState() {
    if (m_text_layout_ == nullptr) return;
    m_text_layout_->clampScroll(m_view_state_.scroll_x, m_view_state_.scroll_y);
    m_text_layout_->setViewState(m_view_state_);
  }

  void EditorCore::resetCompositionState() {
    m_composition_.is_composing = false;
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;
    m_composition_.start_position = {};
    m_composition_text_in_document_ = false;
  }

#pragma region [Bracket-Highlight]

  void EditorCore::buildBracketHighlightRects(EditorRenderModel& model, float line_height) {
    if (m_document_ == nullptr || m_bracket_pairs_.empty()) return;

    TextPosition open_pos, close_pos;
    bool found = false;

    if (m_has_external_brackets_) {
      // External override takes priority
      open_pos = m_external_bracket_open_;
      close_pos = m_external_bracket_close_;
      found = true;
    } else {
      // Built-in character-level scan
      size_t cursor_line = m_cursor_position_.line;
      size_t cursor_col = m_cursor_position_.column;
      size_t line_count = m_document_->getLineCount();
      if (cursor_line >= line_count) return;

      U16String line_text = m_document_->getLineU16Text(cursor_line);

      // Check right-side char (at cursor) and left-side char (cursor - 1)
      auto checkChar = [&](size_t line, size_t col) -> bool {
        if (col >= line_text.length()) return false;
        char16_t ch = line_text[col];
        for (const auto& bp : m_bracket_pairs_) {
          if (static_cast<char16_t>(bp.open) == ch) {
            // Found opening bracket -> scan forward for closing bracket
            open_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            size_t scan_line = line;
            size_t scan_col = col + 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line < line_count) {
              U16String scan_text = (scan_line == line) ? line_text : m_document_->getLineU16Text(scan_line);
              while (scan_col < scan_text.length() && scanned < kMaxBracketScanChars) {
                char16_t sc = scan_text[scan_col];
                if (sc == static_cast<char16_t>(bp.open)) ++depth;
                else if (sc == static_cast<char16_t>(bp.close)) {
                  --depth;
                  if (depth == 0) {
                    close_pos = {scan_line, scan_col};
                    return true;
                  }
                }
                ++scan_col;
                ++scanned;
              }
              ++scan_line;
              scan_col = 0;
            }
            return false;
          }
          if (static_cast<char16_t>(bp.close) == ch) {
            // Found closing bracket -> scan backward for opening bracket
            close_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            // Scan backward from col - 1
            int64_t scan_line_s = static_cast<int64_t>(line);
            int64_t scan_col_s = static_cast<int64_t>(col) - 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line_s >= 0) {
              U16String scan_text = (static_cast<size_t>(scan_line_s) == line) ? line_text : m_document_->getLineU16Text(static_cast<size_t>(scan_line_s));
              while (scan_col_s >= 0 && scanned < kMaxBracketScanChars) {
                char16_t sc = scan_text[static_cast<size_t>(scan_col_s)];
                if (sc == static_cast<char16_t>(bp.close)) ++depth;
                else if (sc == static_cast<char16_t>(bp.open)) {
                  --depth;
                  if (depth == 0) {
                    open_pos = {static_cast<size_t>(scan_line_s), static_cast<size_t>(scan_col_s)};
                    return true;
                  }
                }
                --scan_col_s;
                ++scanned;
              }
              --scan_line_s;
              if (scan_line_s >= 0) {
                U16String prev_text = m_document_->getLineU16Text(static_cast<size_t>(scan_line_s));
                scan_col_s = static_cast<int64_t>(prev_text.length()) - 1;
              }
            }
            return false;
          }
        }
        return false;
      };

      // Check cursor-right first (char at cursor), then left side
      found = checkChar(cursor_line, cursor_col);
      if (!found && cursor_col > 0) {
        found = checkChar(cursor_line, cursor_col - 1);
      }
    }

    if (!found) return;

    // Generate highlight rects for both bracket positions
    auto addRect = [&](const TextPosition& pos) {
      if (pos.line >= m_document_->getLineCount()) return;
      float x_start, x_end, y;
      m_text_layout_->getColumnScreenRange(pos.line, pos.column, pos.column + 1, x_start, x_end, y);
      BracketHighlightRect rect;
      rect.origin = {x_start, y};
      rect.width = x_end - x_start;
      rect.height = line_height;
      model.bracket_highlight_rects.push_back(rect);
    };

    addRect(open_pos);
    addRect(close_pos);
  }
#pragma endregion
}

