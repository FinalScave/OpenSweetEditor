//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <simdutf/simdutf.h>
#include <cmath>
#include <algorithm>
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

#pragma region [Setup & View State]

  TouchConfig EditorOptions::simpleAsTouchConfig() const {
    return TouchConfig {touch_slop, double_tap_timeout, long_press_ms, fling_friction, fling_min_velocity, fling_max_velocity};
  }

  U8String EditorOptions::dump() const {
    return "EditorOptions {touch_slop = " + std::to_string(touch_slop) + ", double_tap_timeout = " + std::to_string(double_tap_timeout) + ", long_press_ms = " + std::to_string(long_press_ms) + ", fling_friction = " + std::to_string(fling_friction) + ", fling_min_velocity = " + std::to_string(fling_min_velocity) + ", fling_max_velocity = " + std::to_string(fling_max_velocity) + ", max_undo_stack_size = " + std::to_string(max_undo_stack_size) + ", key_chord_timeout_ms = " + std::to_string(key_chord_timeout_ms) + "}";
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
        + ", gutter_sticky = " + (gutter_sticky ? "true" : "false")
        + ", gutter_visible = " + (gutter_visible ? "true" : "false")
        + ", wrap_mode = " + std::to_string(static_cast<int>(wrap_mode))
        + "}";
  }
  EditorCore::EditorCore(const Ptr<TextMeasurer>& measurer, const EditorOptions& options): m_measurer_(measurer), m_options_(options), m_key_resolver_(options.key_chord_timeout_ms) {
    m_decorations_ = makePtr<DecorationManager>();
    m_text_layout_ = makeUPtr<TextLayout>(measurer, m_decorations_);
    InteractionContext interaction_context;
    interaction_context.touch_config = options.simpleAsTouchConfig();
    interaction_context.settings = &m_settings_;
    interaction_context.view_state = &m_view_state_;
    interaction_context.viewport = &m_viewport_;
    interaction_context.text_layout = m_text_layout_.get();
    interaction_context.caret = &m_caret_;
    m_interaction_ = makeUPtr<EditorInteraction>(interaction_context);
    m_render_composer_ = makeUPtr<RenderComposer>(m_text_layout_.get(), m_decorations_.get(), &m_settings_);
    m_undo_manager_ = makeUPtr<UndoManager>(options.max_undo_stack_size);
    m_key_resolver_.setKeyMap(KeyMap::createDefault());
    loadDocument(makePtr<LineArrayDocument>(""));
    LOGD("EditorCore::EditorCore(), options = %s", options.dump().c_str());
  }

  void EditorCore::setHandleConfig(const HandleConfig& config) {
    m_settings_.handle = config;
    LOGD("EditorCore::setHandleConfig(), start_hit=[%.1f,%.1f,%.1f,%.1f], end_hit=[%.1f,%.1f,%.1f,%.1f]",
         config.start_hit_offset.left, config.start_hit_offset.top,
         config.start_hit_offset.right, config.start_hit_offset.bottom,
         config.end_hit_offset.left, config.end_hit_offset.top,
         config.end_hit_offset.right, config.end_hit_offset.bottom);
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

  void EditorCore::loadDocument(const Ptr<Document>& document) {
    m_document_ = document;
    m_text_layout_->loadDocument(document);
    normalizeScrollState();
    LOGD("EditorCore::loadDocument()");
  }
  void EditorCore::setViewport(const Viewport& viewport) {
    PERF_TIMER("setViewport");
    bool width_changed = (m_viewport_.width != viewport.width);
    LOGW("setViewport: old=%s new=%s widthChanged=%d", m_viewport_.dump().c_str(), viewport.dump().c_str(), width_changed);
    m_viewport_ = viewport;
    m_text_layout_->setViewport(viewport);
    if (width_changed) {
      markAllLinesDirty();
    }
    normalizeScrollState();
    LOGD("EditorCore::setViewport, viewport = %s", m_viewport_.dump().c_str());
  }

  void EditorCore::onFontMetricsChanged() {
    float old_line_height = m_text_layout_->getLineHeight();
    EditorInteraction::PendingScaleAnchor scale_anchor = m_interaction_->takePendingScaleAnchor();
    // Anchor-based scroll preservation
    // Before resetting the measurer, find which logical line sits at the
    // viewport top and what fraction of that line has been scrolled past.
    // After the font change we recompute scroll_y purely from the integer
    // anchor_line and the small fraction, avoiding any large-float arithmetic
    // whose rounding error would diverge from the prefix-sum that
    // resolveVisibleLines later uses for its binary search.
    size_t anchor_line = 0;
    float  anchor_fraction = 0.0f;   // [0,1] intra-line offset
    float  old_scroll_x = 0.0f;

    if (old_line_height > 0 && m_document_ != nullptr) {
      const auto& lines = m_document_->getLogicalLines();
      if (!lines.empty()) {
        const float scroll_y = m_view_state_.scroll_y;
        // Binary search: first line whose bottom > scroll_y
        size_t lo = 0, hi = lines.size();
        while (lo < hi) {
          size_t mid = lo + (hi - lo) / 2;
          float line_y = m_text_layout_->getLineStartY(mid);
          float h = (lines[mid].height >= 0) ? lines[mid].height : old_line_height;
          if (line_y + h <= scroll_y) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        anchor_line = lo < lines.size() ? lo : lines.size() - 1;
        float anchor_y = m_text_layout_->getLineStartY(anchor_line);
        float anchor_h = (lines[anchor_line].height >= 0)
                             ? lines[anchor_line].height
                             : old_line_height;
        anchor_fraction = (anchor_h > 0)
                              ? (scroll_y - anchor_y) / anchor_h
                              : 0.0f;
        anchor_fraction = std::max(0.0f, std::min(1.0f, anchor_fraction));
        old_scroll_x = m_view_state_.scroll_x;
      }
    }

    m_text_layout_->resetMeasurer();
    float new_line_height = m_text_layout_->getLineHeight();

    // Keep old wrap heights during scale-anchor relayout so prefix estimation stays stable.
    const bool use_wrap_scale_anchor = scale_anchor.active && m_settings_.wrap_mode != WrapMode::NONE && m_document_ != nullptr;
    markAllLinesDirty(!use_wrap_scale_anchor);
    const float wrap_scale_ratio = (old_line_height > 0) ? (new_line_height / old_line_height) : 1.0f;
    const float wrap_text_area_width = std::max(1.0f, m_viewport_.width - m_text_layout_->getLayoutMetrics().textAreaX());
    if (use_wrap_scale_anchor) {
      auto& lines = m_document_->getLogicalLines();
      auto estimate_wrap_height = [&](const LogicalLine& line) -> float {
        if (line.is_fold_hidden) return 0.0f;
        if (line.visual_lines.empty()) {
          const float old_height = (line.height >= 0) ? line.height : old_line_height;
          return std::max(new_line_height, old_height * wrap_scale_ratio);
        }
        float old_total_width = 0.0f;
        for (const auto& vl : line.visual_lines) {
          for (const auto& run : vl.runs) {
            old_total_width += run.width;
          }
        }
        if (old_total_width <= 0.0f) {
          const float old_height = (line.height >= 0) ? line.height : old_line_height;
          return std::max(new_line_height, old_height * wrap_scale_ratio);
        }
        const float new_total_width_est = old_total_width * wrap_scale_ratio;
        const float estimated_wrap_count = std::max(1.0f, std::ceil(new_total_width_est / wrap_text_area_width));
        return estimated_wrap_count * new_line_height;
      };
      const size_t estimate_end = std::min(anchor_line, lines.size());
      for (size_t i = 0; i < estimate_end; ++i) {
        lines[i].height = estimate_wrap_height(lines[i]);
      }
    }

    // Recompute scroll_y from anchor using the NEW prefix index.
    // getLineStartY rebuilds the prefix index (which now uses the fixed
    // multiplication-based computation in ensurePrefixIndexUpTo), so
    // scroll_y is guaranteed to be consistent with what resolveVisibleLines
    // will see later.
    if (scale_anchor.active) {
      CursorRect anchor_rect = getPositionScreenRect(scale_anchor.anchor_position);
      float target_scroll_x = m_view_state_.scroll_x + (anchor_rect.x + scale_anchor.offset_x - scale_anchor.focus_screen.x);
      float target_scroll_y = 0.0f;
      if (m_settings_.wrap_mode == WrapMode::NONE) {
        target_scroll_y = m_view_state_.scroll_y + (anchor_rect.y + scale_anchor.offset_y - scale_anchor.focus_screen.y);
      } else if (m_document_ != nullptr) {
        auto& lines = m_document_->getLogicalLines();
        if (anchor_line < lines.size()) {
          m_text_layout_->layoutLine(anchor_line, lines[anchor_line]);
          float new_anchor_y = lines[anchor_line].start_y;
          float new_anchor_h = (lines[anchor_line].height >= 0) ? lines[anchor_line].height : new_line_height;
          target_scroll_y = new_anchor_y + anchor_fraction * new_anchor_h;
        } else {
          target_scroll_y = m_view_state_.scroll_y + (anchor_rect.y + scale_anchor.offset_y - scale_anchor.focus_screen.y);
        }
      } else {
        target_scroll_y = m_view_state_.scroll_y + (anchor_rect.y + scale_anchor.offset_y - scale_anchor.focus_screen.y);
      }
      if (m_interaction_->isScaleGestureActive()) {
        m_view_state_.scroll_x = target_scroll_x;
        m_view_state_.scroll_y = target_scroll_y;
      } else {
        m_view_state_.scroll_x = std::round(target_scroll_x);
        m_view_state_.scroll_y = std::round(target_scroll_y);
      }
      LOGD("onFontMetricsChanged(scale-anchor): focus=%s anchor=%s scroll=(%.3f, %.3f)",
           scale_anchor.focus_screen.dump().c_str(),
           scale_anchor.anchor_position.dump().c_str(),
           m_view_state_.scroll_x,
           m_view_state_.scroll_y);
    } else if (old_line_height > 0 && new_line_height > 0 && old_line_height != new_line_height) {
      float old_scroll_y = m_view_state_.scroll_y;
      float ratio = new_line_height / old_line_height;
      float new_anchor_y = m_text_layout_->getLineStartY(anchor_line);
      m_view_state_.scroll_y = std::round(new_anchor_y + anchor_fraction * new_line_height);
      m_view_state_.scroll_x = std::round(old_scroll_x * ratio);
      LOGD("onFontMetricsChanged: old_h=%.4f new_h=%.4f anchor=%zu frac=%.4f old_scroll=%.1f new_scroll=%.1f",
           old_line_height, new_line_height, anchor_line, anchor_fraction,
           old_scroll_y, m_view_state_.scroll_y);
    }
    normalizeScrollState();
  }

  void EditorCore::setWrapMode(WrapMode mode) {
    m_settings_.wrap_mode = mode;
    m_text_layout_->setWrapMode(mode);
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setTabSize(uint32_t tab_size) {
    m_text_layout_->setTabSize(tab_size);
    normalizeScrollState();
  }

  void EditorCore::setScale(float scale) {
    m_interaction_->resetScaleState();
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

  void EditorCore::setGutterSticky(bool sticky) {
    if (m_settings_.gutter_sticky == sticky) return;
    m_settings_.gutter_sticky = sticky;
    m_text_layout_->getLayoutMetrics().gutter_sticky = sticky;
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setGutterVisible(bool visible) {
    if (m_settings_.gutter_visible == visible) return;
    m_settings_.gutter_visible = visible;
    m_text_layout_->getLayoutMetrics().gutter_visible = visible;
    markAllLinesDirty();
    normalizeScrollState();
  }

  void EditorCore::setCurrentLineRenderMode(CurrentLineRenderMode mode) {
    if (m_settings_.current_line_render_mode == mode) return;
    m_settings_.current_line_render_mode = mode;
  }

#pragma endregion

#pragma region [Rendering & Input]

  Ptr<TextStyleRegistry> EditorCore::getTextStyleRegistry() const {
    return m_decorations_->getTextStyleRegistry();
  }

  void EditorCore::buildRenderModel(EditorRenderModel& model) {
    PERF_TIMER("buildRenderModel");
    PERF_BEGIN(compose);
    m_text_layout_->layoutVisibleLines(model);
    model.split_line_visible = m_settings_.show_split_line;
    model.current_line_render_mode = m_settings_.current_line_render_mode;
    model.gutter_sticky = m_settings_.gutter_sticky;
    model.gutter_visible = m_settings_.gutter_visible;
    PERF_END(compose, "buildRenderModel::layoutVisibleLines");

    float line_height = m_text_layout_->getLineHeight();
    PERF_BEGIN(cursor_sel);
    m_render_composer_->buildCursorModel(model, m_caret_.cursor, m_caret_.has_selection, line_height);
    m_render_composer_->buildCompositionDecoration(model, m_composition_, line_height);
    m_render_composer_->buildSelectionRects(model, m_document_.get(), m_caret_, line_height);
    if (m_caret_.has_selection) {
      m_interaction_->updateHandleCache(model.selection_start_handle.position,
                                        model.selection_end_handle.position, line_height);
    } else {
      m_interaction_->clearHandleCache();
    }
    PERF_END(cursor_sel, "buildRenderModel::cursorAndSelection");

    PERF_BEGIN(guides);
    m_render_composer_->buildGuideSegments(model, m_document_.get(), *m_measurer_, line_height);
    PERF_END(guides, "buildRenderModel::guideSegments");

    m_render_composer_->buildDiagnosticDecorations(model, m_document_.get(), line_height);
    m_render_composer_->buildLinkedEditingRects(model, m_document_.get(), m_linked_editing_session_.get(), line_height);
    m_render_composer_->buildBracketHighlightRects(model,
                                                   m_document_.get(),
                                                   m_caret_.cursor,
                                                   m_bracket_pairs_,
                                                   m_external_bracket_open_,
                                                   m_external_bracket_close_,
                                                   m_has_external_brackets_,
                                                   line_height);
    m_render_composer_->buildScrollbarModel(model, *m_interaction_);
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

  LayoutMetrics& EditorCore::getLayoutMetrics() const {
    return m_text_layout_->getLayoutMetrics();
  }

  GestureResult EditorCore::handleGestureEvent(const GestureEvent& event) {
    GestureIntent intent;
    GestureResult result = m_interaction_->handleGestureEvent(event, intent);

    if (intent.cancel_linked_editing) {
      if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        TextPosition tap_pos = m_text_layout_->hitTest(result.tap_point);
        bool in_tab_stop = false;
        for (const auto& hl : m_linked_editing_session_->getAllHighlights()) {
          if (hl.range.contains(tap_pos)) { in_tab_stop = true; break; }
        }
        if (!in_tab_stop) {
          cancelLinkedEditing();
        }
      }
    }
    if (intent.place_cursor) {
      placeCursorAt(result.tap_point);
    }
    if (intent.select_word) {
      selectWordAt(result.tap_point);
    }
  if (intent.toggle_fold) {
    toggleFoldAt(intent.fold_line);
  }

  result.cursor_position = m_caret_.cursor;
  result.has_selection = hasSelection();
  result.selection = m_caret_.selection;
  result.view_scroll_x = m_view_state_.scroll_x;
  result.view_scroll_y = m_view_state_.scroll_y;
  result.view_scale = m_view_state_.scale;

  return result;
}

  GestureResult EditorCore::tickFling() {
    return m_interaction_->tickFling();
  }

  GestureResult EditorCore::tickEdgeScroll() {
    return m_interaction_->tickEdgeScroll();
  }

  GestureResult EditorCore::tickAnimations() {
    return m_interaction_->tickAnimations();
  }

  void EditorCore::stopFling() {
    m_interaction_->stopFling();
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

    // Linked editing overrides for Tab/Shift+Tab/Enter/Escape
    if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
      bool shift = static_cast<uint8_t>(event.modifiers & KeyModifier::SHIFT) != 0;
      if (event.key_code == KeyCode::TAB) {
        if (shift) {
          linkedEditingPrevTabStop();
        } else {
          linkedEditingNextTabStop();
        }
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        return result;
      }
      if (event.key_code == KeyCode::ENTER) {
        finishLinkedEditing();
        result.handled = true;
        result.cursor_changed = true;
        return result;
      }
      if (event.key_code == KeyCode::ESCAPE) {
        cancelLinkedEditing();
        result.handled = true;
        return result;
      }
    }

    // Resolve key chord through KeyMap
    KeyChord chord {event.modifiers, event.key_code};
    ResolveResult resolve = m_key_resolver_.resolve(chord);

    if (resolve.status == ResolveStatus::PENDING) {
      result.handled = true;
      return result;
    }

    if (resolve.status == ResolveStatus::MATCHED) {
      EditorCommand cmd = resolve.command;
      result.command = cmd;

      // Platform-handled commands: mark but don't execute
      if (cmd == EditorCommand::COPY || cmd == EditorCommand::PASTE || cmd == EditorCommand::CUT) {
        result.handled = true;
        return result;
      }

      switch (cmd) {
      case EditorCommand::CURSOR_LEFT:
        moveCursorLeft(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_RIGHT:
        moveCursorRight(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_UP:
        moveCursorUp(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_DOWN:
        moveCursorDown(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_LINE_START:
        moveCursorToLineStart(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_LINE_END:
        moveCursorToLineEnd(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_PAGE_UP:
        moveCursorPageUp(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::CURSOR_PAGE_DOWN:
        moveCursorPageDown(false);
        result.handled = true;
        result.cursor_changed = true;
        break;
      case EditorCommand::SELECT_LEFT:
        moveCursorLeft(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_RIGHT:
        moveCursorRight(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_UP:
        moveCursorUp(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_DOWN:
        moveCursorDown(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_LINE_START:
        moveCursorToLineStart(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_LINE_END:
        moveCursorToLineEnd(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_PAGE_UP:
        moveCursorPageUp(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_PAGE_DOWN:
        moveCursorPageDown(true);
        result.handled = true;
        result.cursor_changed = true;
        result.selection_changed = true;
        break;
      case EditorCommand::SELECT_ALL:
        selectAll();
        result.handled = true;
        result.selection_changed = true;
        break;
      case EditorCommand::BACKSPACE:
        result.edit_result = backspace();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::DELETE_FORWARD:
        result.edit_result = deleteForward();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::INSERT_TAB:
        result.edit_result = insertText("\t");
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::INSERT_NEWLINE:
        result.edit_result = insertText("\n");
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::INSERT_LINE_ABOVE:
        result.edit_result = insertLineAbove();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::INSERT_LINE_BELOW:
        result.edit_result = insertLineBelow();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::UNDO:
        result.edit_result = undo();
        if (result.edit_result.changed) {
          result.handled = true;
          result.content_changed = true;
          result.cursor_changed = true;
        }
        break;
      case EditorCommand::REDO:
        result.edit_result = redo();
        if (result.edit_result.changed) {
          result.handled = true;
          result.content_changed = true;
          result.cursor_changed = true;
        }
        break;
      case EditorCommand::MOVE_LINE_UP:
        result.edit_result = moveLineUp();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::MOVE_LINE_DOWN:
        result.edit_result = moveLineDown();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::COPY_LINE_UP:
        result.edit_result = copyLineUp();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::COPY_LINE_DOWN:
        result.edit_result = copyLineDown();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      case EditorCommand::DELETE_LINE:
        result.edit_result = deleteLine();
        result.handled = true;
        result.cursor_changed = true;
        result.content_changed = result.edit_result.changed;
        break;
      default:
        break;
      }

      if (result.handled) {
        LOGD("EditorCore::handleKeyEvent, key_code = %d, command = %d, handled = %d", (int)event.key_code, (int)cmd, result.handled);
        return result;
      }
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

  void EditorCore::setKeyMap(KeyMap key_map) {
    m_key_resolver_.setKeyMap(std::move(key_map));
  }

#pragma endregion

#pragma region [Editing & Cursor/IME]

  TextEditResult EditorCore::insertText(const U8String& text) {
    if (m_document_ == nullptr || text.empty() || m_settings_.read_only) return {};

    // If composition is active, end it first (commit current composing text before new input)
    if (m_composition_.is_composing) {
      compositionCancel();
    }

    // Auto-indent: when inserting a newline with KEEP_INDENT enabled, append previous line's leading whitespace
    U8String actual_text = text;
    if (text == "\n" && m_settings_.auto_indent_mode == AutoIndentMode::KEEP_INDENT) {
      size_t current_line = hasSelection() ? m_caret_.normalizedSelection().start.line : m_caret_.cursor.line;
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
      U8String current_text = hasSelection() ? "" : m_document_->getU8Text(group->ranges[0]);
      U8String linked_text = current_text + actual_text;
      TextEditResult result = applyLinkedEditsWithResult(linked_text);
      LOGD("EditorCore::insertText(linked), cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    }

    TextEditResult result;
    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      result = applyEdit(range, actual_text);
    } else {
      TextRange range = {m_caret_.cursor, m_caret_.cursor};
      result = applyEdit(range, actual_text);
    }
    LOGD("EditorCore::insertText, cursor = %s", m_caret_.cursor.dump().c_str());
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
        LOGD("EditorCore::replaceText(linked), cursor = %s", m_caret_.cursor.dump().c_str());
        return result;
      }
    }

    TextEditResult result = applyEdit(range, new_text);
    LOGD("EditorCore::replaceText, cursor = %s", m_caret_.cursor.dump().c_str());
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
        if (hasSelection()) {
          auto result = applyLinkedEditsWithResult("");
          LOGD("EditorCore::backspace(linked), cursor = %s", m_caret_.cursor.dump().c_str());
          return result;
        }
        if (primary.start < primary.end) {
          U8String current_text = m_document_->getU8Text(primary);
          if (!current_text.empty()) {
            auto end_it = current_text.end();
            utf8::prior(end_it, current_text.begin());
            U8String new_text(current_text.begin(), end_it);
            auto result = applyLinkedEditsWithResult(new_text);
            LOGD("EditorCore::backspace(linked), cursor = %s", m_caret_.cursor.dump().c_str());
            return result;
          }
        } else {
          cancelLinkedEditing();
        }
      }
    }

    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      auto result = applyEdit(range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    }

    if (m_caret_.cursor.column > 0) {
      U16String line_text = m_document_->getLineU16Text(m_caret_.cursor.line);
      size_t col = m_caret_.cursor.column;
      size_t del_count = 1;
      if (col >= 2) {
        U16Char low = line_text[col - 1];
        U16Char high = line_text[col - 2];
        if (low >= 0xDC00 && low <= 0xDFFF && high >= 0xD800 && high <= 0xDBFF) {
          del_count = 2;
        }
      }
      TextRange del_range = {{m_caret_.cursor.line, col - del_count}, {m_caret_.cursor.line, col}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    } else if (m_caret_.cursor.line > 0) {
      size_t prev_line = m_caret_.cursor.line - 1;
      uint32_t prev_cols = m_document_->getLineColumns(prev_line);
      TextRange del_range = {{prev_line, prev_cols}, {m_caret_.cursor.line, 0}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.cursor.dump().c_str());
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

    if (isInLinkedEditing() && hasSelection()) {
      auto result = applyLinkedEditsWithResult("");
      LOGD("EditorCore::deleteForward(linked), cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    }

    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      auto result = applyEdit(range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    }

    uint32_t line_cols = m_document_->getLineColumns(m_caret_.cursor.line);
    if (m_caret_.cursor.column < line_cols) {
      U16String line_text = m_document_->getLineU16Text(m_caret_.cursor.line);
      size_t col = m_caret_.cursor.column;
      size_t del_count = 1;
      if (col + 1 < line_text.length()) {
        U16Char high = line_text[col];
        U16Char low = line_text[col + 1];
        if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
          del_count = 2;
        }
      }
      TextRange del_range = {{m_caret_.cursor.line, col}, {m_caret_.cursor.line, col + del_count}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    } else if (m_caret_.cursor.line + 1 < m_document_->getLineCount()) {
      TextRange del_range = {{m_caret_.cursor.line, line_cols}, {m_caret_.cursor.line + 1, 0}};
      auto result = applyEdit(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.cursor.dump().c_str());
      return result;
    }
    return {};
  }

  void EditorCore::deleteSelection() {
    if (!hasSelection() || m_document_ == nullptr) return;
    TextRange range = m_caret_.normalizedSelection();
    // Internal call; do not record undo (used in composition flow)
    m_document_->deleteU8Text(range);
    // Adjust decoration offsets to avoid misalignment (especially after multi-line selection deletion)
    m_decorations_->adjustForEdit(range, range.start);
    m_text_layout_->invalidateContentMetrics(range.start.line);
    m_caret_.cursor = range.start;
    clearSelection();
  }
  TextEditResult EditorCore::moveLineUp() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.cursor.line;
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

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    auto result = applyEdit(full_range, new_text);

    TextPosition new_cursor = {m_caret_.cursor.line > 0 ? m_caret_.cursor.line - 1 : 0, m_caret_.cursor.column};
    setCursorPosition(new_cursor);
    if (hasSelection()) {
      TextRange selection = getSelection();
      setSelection({{selection.start.line > 0 ? selection.start.line - 1 : 0, selection.start.column},
                     {selection.end.line > 0 ? selection.end.line - 1 : 0, selection.end.column}});
    }

    m_undo_manager_->endGroup(m_caret_.cursor);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::moveLineDown() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.cursor.line;
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

    TextPosition original_cursor = m_caret_.cursor;
    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    auto result = applyEdit(full_range, new_text);

    setCursorPosition({original_cursor.line + 1, original_cursor.column});
    if (hasSelection()) {
      TextRange selection = getSelection();
      setSelection({{selection.start.line + 1, selection.start.column},
                     {selection.end.line + 1, selection.end.column}});
    }

    m_undo_manager_->endGroup(m_caret_.cursor);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::copyLineUp() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.cursor.line;
    }

    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    // Insert copied line block + newline at the start of first_line
    TextPosition insert_pos = {first_line, 0};
    U8String insert_text = block_text + "\n";

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // Keep cursor at original logical position (inserted text already shifted it down correctly)
    m_undo_manager_->endGroup(m_caret_.cursor);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::copyLineDown() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.cursor.line;
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

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // applyEdit moves cursor to the end of inserted text (end of copied block), which is what we want
    m_undo_manager_->endGroup(m_caret_.cursor);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::deleteLine() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.cursor.line;
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

    size_t line = m_caret_.cursor.line;
    TextPosition insert_pos = {line, 0};

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    auto result = applyEdit({insert_pos, insert_pos}, "\n");

    // Keep cursor on the newly inserted empty line
    setCursorPosition({line, 0});
    m_undo_manager_->endGroup(m_caret_.cursor);
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::insertLineBelow() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (m_composition_.is_composing) compositionCancel();

    size_t line = m_caret_.cursor.line;
    uint32_t line_cols = m_document_->getLineColumns(line);
    TextPosition insert_pos = {line, line_cols};

    auto result = applyEdit({insert_pos, insert_pos}, "\n");
    // applyEdit has already moved cursor to the start of the new line
    return result;
  }
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
    LOGD("EditorCore::undo, cursor = %s", m_caret_.cursor.dump().c_str());
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
    LOGD("EditorCore::redo, cursor = %s", m_caret_.cursor.dump().c_str());
    return edit_result;
  }

  bool EditorCore::canUndo() const {
    return m_undo_manager_->canUndo();
  }

  bool EditorCore::canRedo() const {
    return m_undo_manager_->canRedo();
  }
  void EditorCore::setCursorPosition(const TextPosition& position) {
    m_caret_.cursor = position;
    if (m_document_ != nullptr) {
      size_t line_count = m_document_->getLineCount();
      if (m_caret_.cursor.line >= line_count) {
        m_caret_.cursor.line = line_count > 0 ? line_count - 1 : 0;
      }
      const auto& lines = m_document_->getLogicalLines();
      if (m_caret_.cursor.line < lines.size() && lines[m_caret_.cursor.line].is_fold_hidden) {
        const FoldRegion* fr = m_decorations_->getFoldRegionForLine(m_caret_.cursor.line);
        if (fr != nullptr) {
          m_caret_.cursor.line = fr->start_line;
          m_caret_.cursor.column = m_document_->getLineColumns(fr->start_line);
          return;
        }
      }
      uint32_t cols = m_document_->getLineColumns(m_caret_.cursor.line);
      if (m_caret_.cursor.column > cols) {
        m_caret_.cursor.column = cols;
      }
    }
  }

  TextPosition EditorCore::getCursorPosition() const {
    return m_caret_.cursor;
  }

  void EditorCore::setSelection(const TextRange& range) {
    m_caret_.setSelection(range);
  }

  TextRange EditorCore::getSelection() const {
    return m_caret_.selection;
  }

  bool EditorCore::hasSelection() const {
    return m_caret_.has_selection;
  }

  void EditorCore::clearSelection() {
    m_caret_.clearSelection();
  }

  void EditorCore::selectAll() {
    if (m_document_ == nullptr) return;
    size_t last_line = m_document_->getLineCount() > 0 ? m_document_->getLineCount() - 1 : 0;
    uint32_t last_col = m_document_->getLineColumns(last_line);
    setSelection({{0, 0}, {last_line, last_col}});
  }

  U8String EditorCore::getSelectedText() const {
    if (!hasSelection() || m_document_ == nullptr) return "";
    TextRange range = m_caret_.normalizedSelection();
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
    if (m_document_ == nullptr) return {m_caret_.cursor, m_caret_.cursor};
    size_t line = m_caret_.cursor.line;
    U16String line_text = m_document_->getLineU16Text(line);
    size_t col = std::min(m_caret_.cursor.column, line_text.length());
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

  void EditorCore::moveCursorLeft(bool extend_selection) {
    if (m_document_ == nullptr) return;

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.start, false);
      return;
    }

    TextPosition new_pos = m_caret_.cursor;
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

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.end, false);
      return;
    }

    TextPosition new_pos = m_caret_.cursor;
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

    if (m_caret_.cursor.line == 0) {
      moveCursorTo({0, 0}, extend_selection);
      return;
    }

    // Find the nearest visible line above
    size_t target_line = m_caret_.cursor.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      if (target_line == 0) {
        moveCursorTo({0, 0}, extend_selection);
        return;
      }
      --target_line;
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_caret_.cursor);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTest(target_point);
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorDown(bool extend_selection) {
    if (m_document_ == nullptr) return;

    size_t line_count = m_document_->getLineCount();
    if (m_caret_.cursor.line + 1 >= line_count) {
      uint32_t cols = m_document_->getLineColumns(m_caret_.cursor.line);
      moveCursorTo({m_caret_.cursor.line, cols}, extend_selection);
      return;
    }

    // Find the nearest visible line below
    size_t target_line = m_caret_.cursor.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      ++target_line;
      if (target_line >= line_count) {
        uint32_t cols = m_document_->getLineColumns(line_count - 1);
        moveCursorTo({line_count - 1, cols}, extend_selection);
        return;
      }
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_caret_.cursor);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTest(target_point);
    moveCursorTo(new_pos, extend_selection);
  }

  void EditorCore::moveCursorToLineStart(bool extend_selection) {
    if (m_document_ == nullptr) return;
    moveCursorTo({m_caret_.cursor.line, 0}, extend_selection);
  }

  void EditorCore::moveCursorToLineEnd(bool extend_selection) {
    if (m_document_ == nullptr) return;
    uint32_t cols = m_document_->getLineColumns(m_caret_.cursor.line);
    moveCursorTo({m_caret_.cursor.line, cols}, extend_selection);
  }

  void EditorCore::moveCursorPageUp(bool extend_selection) {
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return;
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) return;
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorUp(extend_selection);
    }
  }

  void EditorCore::moveCursorPageDown(bool extend_selection) {
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return;
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) return;
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorDown(extend_selection);
    }
  }

  void EditorCore::compositionStart() {
    if (m_document_ == nullptr || m_settings_.read_only) return;

    // If already in composition state, cancel current composition first
    if (m_composition_.is_composing) {
      removeComposingText();
      resetCompositionState();
    }

    // If there is a selection, delete it first (keep selection in linked editing and replace in insertText)
    if (hasSelection() && !isInLinkedEditing()) {
      deleteSelection();
    }

    m_composition_.is_composing = true;
    m_composition_.start_position = m_caret_.cursor;
    if (isInLinkedEditing() && hasSelection()) {
      m_composition_.start_position = m_caret_.normalizedSelection().start;
    }
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;

    LOGD("EditorCore::compositionStart, pos = %s", m_caret_.cursor.dump().c_str());
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
    LOGD("EditorCore::compositionEnd, cursor = %s", m_caret_.cursor.dump().c_str());
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
    LOGD("EditorCore::compositionCancel, cursor = %s", m_caret_.cursor.dump().c_str());
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
  void EditorCore::setAutoIndentMode(AutoIndentMode mode) {
    m_settings_.auto_indent_mode = mode;
    LOGD("EditorCore::setAutoIndentMode, mode = %d", (int)mode);
  }

  AutoIndentMode EditorCore::getAutoIndentMode() const {
    return m_settings_.auto_indent_mode;
  }
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
    TextPosition insert_pos = m_caret_.cursor;
    TextRange replace_range = {insert_pos, insert_pos};
    if (hasSelection()) {
      replace_range = m_caret_.normalizedSelection();
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

    LOGD("EditorCore::insertSnippet, cursor = %s", m_caret_.cursor.dump().c_str());
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

    LOGD("EditorCore::startLinkedEditing, cursor = %s", m_caret_.cursor.dump().c_str());
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

    const TextPosition cursor_before = m_caret_.cursor;
    auto changes = performLinkedEdits(new_text);

    result.changed = true;
    result.changes = std::move(changes);
    result.cursor_before = cursor_before;
    result.cursor_after = m_caret_.cursor;
    return result;
  }

  std::vector<TextChange> EditorCore::performLinkedEdits(const U8String& new_text) {
    std::vector<TextChange> changes;
    if (!isInLinkedEditing()) return changes;

    auto edits = m_linked_editing_session_->computeLinkedEdits(new_text);
    if (edits.empty()) return changes;

    // Begin undo group
    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());

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
    m_undo_manager_->endGroup(m_caret_.cursor);

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

#pragma region [Navigation & Decorations]

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
         line, column, m_caret_.cursor.dump().c_str());
  }

  void EditorCore::setScroll(float scroll_x, float scroll_y) {
    m_view_state_.scroll_x = scroll_x;
    m_view_state_.scroll_y = scroll_y;
    normalizeScrollState();
    LOGD("EditorCore::setScroll, m_view_state_ = %s", m_view_state_.dump().c_str());
  }

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
    return getPositionScreenRect(m_caret_.cursor);
  }

  void EditorCore::registerTextStyle(uint32_t style_id, TextStyle&& style) {
    m_decorations_->getTextStyleRegistry()->registerTextStyle(style_id, std::move(style));
    markAllLinesDirty();
  }

  void EditorCore::registerBatchTextStyles(Vector<std::pair<uint32_t, TextStyle>>&& entries) {
    if (entries.empty()) return;
    auto registry = m_decorations_->getTextStyleRegistry();
    for (auto& [style_id, style] : entries) {
      registry->registerTextStyle(style_id, std::move(style));
    }
    markAllLinesDirty();
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

  void EditorCore::ensureCursorVisible() {
    PointF cursor_screen = m_text_layout_->getPositionScreenCoord(m_caret_.cursor);
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

  void EditorCore::moveCursorTo(const TextPosition& new_pos, bool extend_selection) {
    if (extend_selection) {
      TextRange selection = hasSelection() ? getSelection() : TextRange {m_caret_.cursor, m_caret_.cursor};
      selection.end = new_pos;
      setSelection(selection);
    } else {
      clearSelection();
    }
    setCursorPosition(new_pos);
    ensureCursorVisible();
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

    TextPosition cursor_before = m_caret_.cursor;
    edit_result.cursor_before = cursor_before;
    bool had_selection = hasSelection();
    TextRange selection_before = getSelection();

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

  void EditorCore::markAllLinesDirty(bool reset_heights) {
    if (m_document_ == nullptr) return;
    if (reset_heights) {
      for (auto& line : m_document_->getLogicalLines()) {
        line.is_layout_dirty = true;
        line.height = line.is_fold_hidden ? 0 : -1;
      }
    } else {
      for (auto& line : m_document_->getLogicalLines()) {
        line.is_layout_dirty = true;
      }
    }
    if (m_text_layout_ != nullptr) {
      m_text_layout_->invalidateContentMetrics();
    }
  }

  void EditorCore::normalizeScrollState() {
    PERF_TIMER("normalizeScrollState");
    if (m_text_layout_ == nullptr) return;
    m_text_layout_->normalizeViewState(m_view_state_);
  }

  void EditorCore::resetCompositionState() {
    m_composition_.is_composing = false;
    m_composition_.composing_text.clear();
    m_composition_.composing_columns = 0;
    m_composition_.start_position = {};
    m_composition_text_in_document_ = false;
  }

#pragma endregion

}

