//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <cmath>
#include <algorithm>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "logging.h"
#include "ime_projection.hpp"
#include "render_style_util.hpp"
#include "text_boundary.hpp"

namespace NS_SWEETEDITOR {
  namespace {
    uint32_t advanceVisualColumn(U16Char ch, uint32_t visual_col, uint32_t tab_size) {
      if (ch == u'\t') {
        return (visual_col / tab_size + 1) * tab_size;
      }
      return visual_col + 1;
    }

    uint32_t computeVisualColumn(const U16String& line_text, size_t col, uint32_t tab_size) {
      uint32_t visual_col = 0;
      size_t safe_col = std::min(col, line_text.size());
      for (size_t i = 0; i < safe_col; ++i) {
        visual_col = advanceVisualColumn(line_text[i], visual_col, tab_size);
      }
      return visual_col;
    }
  }

#pragma region [Setup & View State]

  EditorCore::EditorCore(const SharedPtr<TextMeasurer>& measurer, const EditorOptions& options): m_measurer_(measurer), m_options_(options), m_key_resolver_(options.key_chord_timeout_ms) {
    m_decorations_ = makeShared<DecorationManager>();
    m_text_layout_ = makeUnique<TextLayout>(measurer, m_decorations_);
    m_text_layout_->setLineDecorationCollector(
        [this](size_t line, LineLayoutDecorations& decorations) {
          collectLineLayoutDecorations(line, decorations);
        });
    InteractionContext interaction_context;
    interaction_context.touch_config = options.simpleAsTouchConfig();
    interaction_context.settings = &m_settings_;
    interaction_context.view_state = &m_view_state_;
    interaction_context.viewport = &m_viewport_;
    interaction_context.text_layout = m_text_layout_.get();
    interaction_context.caret = &m_caret_;
    m_interaction_ = makeUnique<EditorInteraction>(interaction_context);
    m_render_composer_ = makeUnique<RenderComposer>(
        m_text_layout_.get(), m_decorations_.get(), &m_settings_);
    m_undo_manager_ = makeUnique<UndoManager>(options.max_undo_stack_size);
    m_key_resolver_.setKeyMap(KeyMap::createDefault());
    loadDocument(makeShared<LineArrayDocument>(""));
    LOGD("EditorCore::EditorCore(), options = %s", options.dump().c_str());
  }

  EditorActionResult EditorCore::setHandleConfig(const HandleConfig& config) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.handle == config) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.handle = config;
    LOGD("EditorCore::setHandleConfig(), start_hit=[%.1f,%.1f,%.1f,%.1f], end_hit=[%.1f,%.1f,%.1f,%.1f]",
         config.start_hit_area.left, config.start_hit_area.top,
         config.start_hit_area.right, config.start_hit_area.bottom,
         config.end_hit_area.left, config.end_hit_area.top,
         config.end_hit_area.right, config.end_hit_area.bottom);
    return finishAction(before, EditorActionSource::SETUP, true);
  }

  EditorActionResult EditorCore::setScrollbarConfig(const ScrollbarConfig& config) {
    const ActionSnapshot before = captureActionSnapshot();
    const ScrollbarConfig previous = m_settings_.scrollbar;
    m_settings_.scrollbar.thickness = std::max(1.0f, config.thickness);
    m_settings_.scrollbar.min_thumb = std::max(m_settings_.scrollbar.thickness, config.min_thumb);
    m_settings_.scrollbar.thumb_hit_padding = std::max(0.0f, config.thumb_hit_padding);
    m_settings_.scrollbar.mode = config.mode;
    m_settings_.scrollbar.thumb_draggable = config.thumb_draggable;
    m_settings_.scrollbar.track_tap_mode = config.track_tap_mode;
    m_settings_.scrollbar.fade_delay_ms = std::max<uint16_t>(0, config.fade_delay_ms);
    m_settings_.scrollbar.fade_duration_ms = std::max<uint16_t>(0, config.fade_duration_ms);
    if (previous != m_settings_.scrollbar) {
      m_interaction_->onScrollbarConfigChanged();
    }
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
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setEditorRenderColors(const EditorRenderColors& colors) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.render_colors == colors) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.render_colors = colors;
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setEditorRangeEffectStyles(const EditorRangeEffectStyles& styles) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.range_effect_styles == styles) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.range_effect_styles = styles;
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::loadDocument(const SharedPtr<Document>& document) {
    const ActionSnapshot before = captureActionSnapshot();
    cancelLinkedEditingInternal();
    cancelPreedit();
    closeImeSession();
    m_undo_manager_->clear();
    m_interaction_->resetForDocumentLoad();
    clearMatchedBrackets();
    m_decorations_->clearAll();
    clearHoverHitTarget();
    clearPressHitTarget();
    m_mouse_button_down_ = false;
    m_has_last_mouse_point_ = false;
    m_pointer_cursor_type_ = PointerCursorType::TEXT;
    const uint64_t search_generation = m_search_generation_->fetch_add(1) + 1;
    m_search_state_ = {};
    m_search_state_.generation = search_generation;
    m_search_matches_.clear();
    m_search_match_indices_by_line_.clear();
    clearPendingSearchResult();
    publishSearchState(m_search_state_);

    m_document_ = document;
    m_text_layout_->loadDocument(document);
    syncFoldState();
    m_caret_ = {};
    setCursorPosition({});
    m_view_state_.scroll_x = 0.0f;
    m_view_state_.scroll_y = 0.0f;
    m_visible_line_range_ = {};
    normalizeScrollState();
    LOGD("EditorCore::loadDocument()");
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setViewport(const Size& viewport) {
    const ActionSnapshot before = captureActionSnapshot();
    PERF_TIMER("setViewport");
    const bool viewport_changed =
        m_viewport_.width != viewport.width || m_viewport_.height != viewport.height;
    bool width_changed = (m_viewport_.width != viewport.width);
    LOGW("setViewport: old=%s new=%s widthChanged=%d", m_viewport_.dump().c_str(), viewport.dump().c_str(), width_changed);
    m_viewport_ = viewport;
    m_text_layout_->setViewport(viewport);
    if (viewport_changed) {
      m_interaction_->onViewportChanged();
    }
    if (width_changed) {
      markAllLinesDirty();
    }
    normalizeScrollState();
    LOGD("EditorCore::setViewport, viewport = %s", m_viewport_.dump().c_str());
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::onFontMetricsChanged() {
    const ActionSnapshot before = captureActionSnapshot();
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
          float h;
          if (lines[mid].height >= 0) {
            h = lines[mid].height;
          } else {
            bool has_codelens = !m_decorations_->getLineCodeLens(mid).empty();
            h = has_codelens ? old_line_height * 2 : old_line_height;
          }
          if (line_y + h <= scroll_y) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        anchor_line = lo < lines.size() ? lo : lines.size() - 1;
        float anchor_y = m_text_layout_->getLineStartY(anchor_line);
        float anchor_h;
        if (lines[anchor_line].height >= 0) {
          anchor_h = lines[anchor_line].height;
        } else {
          bool has_codelens = !m_decorations_->getLineCodeLens(anchor_line).empty();
          anchor_h = has_codelens ? old_line_height * 2 : old_line_height;
        }
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
      auto estimate_wrap_height = [&](size_t line_index, const LogicalLine& line) -> float {
        if (line.is_fold_hidden) return 0.0f;
        if (line.visual_lines.empty()) {
          float old_height;
          if (line.height >= 0) {
            old_height = line.height;
          } else {
            bool has_codelens = !m_decorations_->getLineCodeLens(line_index).empty();
            old_height = has_codelens ? old_line_height * 2 : old_line_height;
          }
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
        lines[i].height = estimate_wrap_height(i, lines[i]);
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
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setWrapMode(WrapMode mode) {
    const ActionSnapshot before = captureActionSnapshot();
    m_settings_.wrap_mode = mode;
    m_text_layout_->setWrapMode(mode);
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setTabSize(uint32_t tab_size) {
    const ActionSnapshot before = captureActionSnapshot();
    m_text_layout_->setTabSize(tab_size);
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setScale(float scale) {
    const ActionSnapshot before = captureActionSnapshot();
    m_interaction_->resetScaleState();
    m_view_state_.scale = std::max(m_settings_.min_scale, std::min(m_settings_.max_scale, scale));
    normalizeScrollState();
    LOGD("EditorCore::setScale, m_view_state_ = %s", m_view_state_.dump().c_str());
    return finishAction(before, EditorActionSource::SETUP, true);
  }

  EditorActionResult EditorCore::setFoldArrowMode(FoldArrowMode mode) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_text_layout_->getLayoutMetrics().fold_arrow_mode == mode) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_text_layout_->getLayoutMetrics().fold_arrow_mode = mode;
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setLineSpacing(float add, float mult) {
    const ActionSnapshot before = captureActionSnapshot();
    auto& params = m_text_layout_->getLayoutMetrics();
    if (params.line_spacing_add == add && params.line_spacing_mult == mult) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    params.line_spacing_add = add;
    params.line_spacing_mult = mult;
    // After line height changes, all lines must be relaid out
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setContentStartPadding(float padding) {
    const ActionSnapshot before = captureActionSnapshot();
    padding = std::max(0.0f, padding);
    auto& params = m_text_layout_->getLayoutMetrics();
    if (params.content_start_padding == padding) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    params.content_start_padding = padding;
    m_settings_.content_start_padding = padding;
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setShowSplitLine(bool show) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.show_split_line == show) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.show_split_line = show;
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setCurrentLineRenderMode(CurrentLineRenderMode mode) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.current_line_render_mode == mode) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.current_line_render_mode = mode;
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setRenderWhitespace(WhitespaceRenderMode mode) {
    const ActionSnapshot before = captureActionSnapshot();
    switch (mode) {
    case WhitespaceRenderMode::NONE:
    case WhitespaceRenderMode::BOUNDARY:
    case WhitespaceRenderMode::SELECTION:
    case WhitespaceRenderMode::TRAILING:
    case WhitespaceRenderMode::ALL:
      break;
    default:
      mode = WhitespaceRenderMode::NONE;
      break;
    }
    if (m_settings_.render_whitespace == mode) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.render_whitespace = mode;
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setRenderLineBreaks(bool enabled) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.render_line_breaks == enabled) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.render_line_breaks = enabled;
    m_text_layout_->setRenderLineBreaks(enabled);
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setGutterSticky(bool sticky) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.gutter_sticky == sticky) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.gutter_sticky = sticky;
    m_text_layout_->getLayoutMetrics().gutter_sticky = sticky;
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

  EditorActionResult EditorCore::setGutterVisible(bool visible) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_settings_.gutter_visible == visible) {
      return finishAction(before, EditorActionSource::SETUP, true);
    }
    m_settings_.gutter_visible = visible;
    m_text_layout_->getLayoutMetrics().gutter_visible = visible;
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::SETUP, true, {}, true);
  }

#pragma endregion

#pragma region [Rendering & Input]

  SharedPtr<TextStyleRegistry> EditorCore::getTextStyleRegistry() const {
    return m_decorations_->getTextStyleRegistry();
  }

  void EditorCore::buildRenderModel(EditorRenderModel& model) {
    drainPendingSearchResult();
    PERF_TIMER("buildRenderModel");
    PERF_BEGIN(compose);
    PresentationContext presentation_context;
    presentation_context.active_hit_target = getActiveHitTarget();
    presentation_context.has_selection = m_caret_.hasSelection();
    if (m_caret_.hasSelection()) {
      presentation_context.selection_range = m_caret_.normalizedSelection();
    }
    presentation_context.render_colors = m_settings_.render_colors;
    presentation_context.range_effect_styles = m_settings_.range_effect_styles;
    presentation_context.render_whitespace = m_settings_.render_whitespace;
    presentation_context.collect_text_effects = [this](size_t line, Vector<TextPresentationEffect>& effects) {
      collectTextPresentationEffectsForLine(line, effects);
    };
    m_visible_line_range_ = {};
    VisibleLineInfo visible_line_info = m_text_layout_->layoutVisibleLines(model, presentation_context);
    if (!model.lines.empty()) {
      m_visible_line_range_.start = static_cast<int32_t>(visible_line_info.first_line);
      m_visible_line_range_.end = static_cast<int32_t>(visible_line_info.last_line);
    }
    model.split_line_visible = m_settings_.show_split_line;
    model.current_line_render_mode = m_settings_.current_line_render_mode;
    model.gutter_sticky = m_settings_.gutter_sticky;
    model.gutter_visible = m_settings_.gutter_visible;
    PERF_END(compose, "buildRenderModel::layoutVisibleLines");

    float line_height = m_text_layout_->getLineHeight();
    const std::optional<CompositionState>& composition = getCompositionState();
    PERF_BEGIN(cursor_sel);
    m_render_composer_->buildCursorModel(model, m_caret_, line_height);
    m_render_composer_->buildDocumentHighlightRangeEffects(
        model, m_document_.get(), composition, line_height);
    m_render_composer_->buildSearchRangeEffects(
        model, m_document_.get(), m_search_matches_, m_search_match_indices_by_line_,
        m_search_state_.current_index, composition, line_height);
    if (composition.has_value()) {
      m_render_composer_->buildCompositionRangeEffect(
          model, m_document_.get(), *composition, line_height);
    }
    m_render_composer_->buildSelectionRangeEffects(model, m_document_.get(), m_caret_, line_height);
    if (m_caret_.hasSelection()) {
      m_interaction_->updateHandleCache(model.selection_start_handle.position,
                                        model.selection_end_handle.position, line_height);
    } else {
      m_interaction_->clearHandleCache();
    }
    PERF_END(cursor_sel, "buildRenderModel::cursorAndSelection");

    PERF_BEGIN(guides);
    m_render_composer_->buildGuideSegments(model, m_document_.get(), *m_measurer_, line_height);
    PERF_END(guides, "buildRenderModel::guideSegments");

    m_render_composer_->buildDiagnosticRangeEffects(
        model, m_document_.get(), composition, line_height);
    m_render_composer_->buildLinkedEditingRangeEffects(
        model, m_document_.get(), m_linked_editing_session_.get(), composition, line_height);
    m_render_composer_->buildBracketHighlightRangeEffects(
        model, m_document_.get(), m_caret_.active, m_bracket_pairs_,
        m_external_bracket_open_, m_external_bracket_close_, m_has_external_brackets_, line_height);
    m_render_composer_->buildScrollbarModel(model, *m_interaction_);
    model.pointer_cursor_type = m_pointer_cursor_type_;
  }

  ViewState EditorCore::getViewState() const {
    return m_view_state_;
  }

  ScrollMetrics EditorCore::getScrollMetrics() const {
    ScrollMetrics metrics;
    metrics.scale = m_view_state_.scale;
    metrics.viewport_size = m_viewport_;

    if (m_text_layout_ == nullptr) {
      return metrics;
    }

    ScrollBounds bounds = m_text_layout_->getScrollBounds();
    metrics.scroll_x = m_view_state_.scroll_x;
    metrics.scroll_y = m_view_state_.scroll_y;
    metrics.max_scroll_x = bounds.max_scroll_x;
    metrics.max_scroll_y = bounds.max_scroll_y;
    metrics.content_size = {bounds.content_width, bounds.content_height};
    metrics.text_area_x = bounds.text_area_x;
    metrics.text_area_width = bounds.text_area_width;
    metrics.can_scroll_x = bounds.max_scroll_x > 0.0f;
    metrics.can_scroll_y = bounds.max_scroll_y > 0.0f;
    return metrics;
  }

  IntRange EditorCore::getVisibleLineRange() const {
    return m_visible_line_range_;
  }

  LayoutMetrics& EditorCore::getLayoutMetrics() const {
    return m_text_layout_->getLayoutMetrics();
  }

  EditorActionResult EditorCore::handleGestureEvent(const GestureEvent& event) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution;
    if (event.type == EventType::TOUCH_DOWN || event.type == EventType::MOUSE_DOWN) {
      m_has_preferred_cursor_x_ = false;
    }
    const bool has_primary_point = !event.points.empty();
    PointerProbeResult primary_probe;
    bool primary_probe_ready = false;
    auto get_primary_probe = [&]() -> const PointerProbeResult& {
      if (!primary_probe_ready) {
        primary_probe = has_primary_point ? probePointer(event.points[0], event.modifiers) : PointerProbeResult {};
        primary_probe_ready = true;
      }
      return primary_probe;
    };

    if (isMousePointerEvent(event.type) && has_primary_point) {
      m_last_mouse_point_ = event.points[0];
      m_has_last_mouse_point_ = true;
      m_pointer_cursor_type_ = get_primary_probe().cursor_type;
    }

    InteractionResult interaction_result = m_interaction_->handleGestureEvent(event);
    GestureIntent& intent = interaction_result.intent;
    GestureResult& result = interaction_result.gesture;
    if (intent.place_cursor || intent.select_word || intent.toggle_fold) {
      resolution = finishCompositionForAction();
    }
    const uint32_t interaction_flags = m_interaction_->resolveInteractionFlags();
    const HitTarget primary_hot_target =
        has_primary_point
            && !(interaction_flags & static_cast<uint32_t>(InteractionFlag::SELECTION_DRAG))
            ? get_primary_probe().hot_target
            : HitTarget {};
    interaction_result.handled =
        updatePointerHitTargetLifecycle(event, primary_hot_target)
        || interaction_result.handled;

    if (intent.cancel_linked_editing) {
      if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        TextPosition tap_pos = m_text_layout_->hitTestPointer(result.tap_point).position;
        bool in_tab_stop = false;
        for (const auto& hl : m_linked_editing_session_->getAllHighlights()) {
          if (hl.range.contains(tap_pos)) { in_tab_stop = true; break; }
        }
        if (!in_tab_stop) {
          cancelLinkedEditingInternal();
        }
      }
    }
    if (intent.place_cursor) {
      placeCursorAt(result.tap_point);
    }
    if (intent.select_word) {
      selectWordAt(result.tap_point);
    }
    bool gesture_decoration_changed = false;
    if (intent.toggle_fold) {
      gesture_decoration_changed = toggleFoldAtInternal(intent.fold_line);
    }

    EditorActionResult action = finishInteractionAction(
        before, std::move(interaction_result), EditorActionSource::GESTURE, event.type, gesture_decoration_changed);
    if (resolution.contentChanged()) {
      action.text_change_kind = resolution.change_kind;
      action.changes = std::move(resolution.changes);
      action.content_changed = true;
      action.needs_redraw = true;
    }
    return action;
  }

  EditorActionResult EditorCore::updatePointerModifiers(KeyModifier modifiers) {
    const ActionSnapshot before = captureActionSnapshot();

    if (m_has_last_mouse_point_) {
      const PointerProbeResult probe = probePointer(m_last_mouse_point_, modifiers);
      m_pointer_cursor_type_ = probe.cursor_type;
      if (!m_mouse_button_down_) {
        m_hover_hit_target_ = probe.hot_target;
      }
    }

    EditorActionResult result = finishAction(before, EditorActionSource::GESTURE, false);
    result.modifiers = modifiers;
    const bool active_hit_target_changed =
        before.active_hit_target != getActiveHitTarget();
    result.handled = active_hit_target_changed || result.pointer_cursor_changed;
    return result;
  }

  EditorActionResult EditorCore::tickAnimations() {
    const ActionSnapshot before = captureActionSnapshot();
    InteractionResult result = m_interaction_->tickAnimations();
    return finishInteractionAction(before, std::move(result), EditorActionSource::ANIMATION);
  }

  EditorActionResult EditorCore::stopFling() {
    const ActionSnapshot before = captureActionSnapshot();
    m_interaction_->stopFling();
    return finishAction(before, EditorActionSource::ANIMATION, true);
  }

  EditorActionResult EditorCore::handleKeyEvent(const KeyEvent& event) {
    PERF_TIMER("handleKeyEvent");
    const ActionSnapshot before = captureActionSnapshot();
    EditorCommandId command = 0;
    auto make_result = [&](bool handled, TextEditResult edit_result = {}) -> EditorActionResult {
      EditorActionResult action = finishAction(before, EditorActionSource::KEYBOARD, handled, std::move(edit_result));
      action.command = command;
      return action;
    };
    if (m_document_ == nullptr) return make_result(false);

    if (hasPreedit() && event.key_code == KeyCode::ESCAPE) {
      cancelPreedit();
      return make_result(true);
    }

    TextEditResult resolution;

    if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
      bool shift = static_cast<uint8_t>(event.modifiers & KeyModifier::SHIFT) != 0;
      if (event.key_code == KeyCode::TAB) {
        resolution = finishCompositionForAction();
        if (shift) {
          linkedEditingPrevTabStopInternal();
        } else {
          linkedEditingNextTabStopInternal();
        }
        return make_result(true, std::move(resolution));
      }
      if (event.key_code == KeyCode::ENTER) {
        resolution = finishCompositionForAction();
        finishLinkedEditingInternal();
        return make_result(true, std::move(resolution));
      }
      if (event.key_code == KeyCode::ESCAPE) {
        cancelLinkedEditingInternal();
        return make_result(true);
      }
    }

    KeyChord chord {event.modifiers, event.key_code};
    ResolveResult resolve = m_key_resolver_.resolve(chord);

    if (resolve.status == ResolveStatus::PENDING) {
      return make_result(true);
    }

    if (resolve.status == ResolveStatus::MATCHED) {
      command = resolve.command;

      if (command == static_cast<EditorCommandId>(EditorBuiltinCommand::PASTE)
          || command == static_cast<EditorCommandId>(EditorBuiltinCommand::CUT)) {
        resolution = finishCompositionForAction();
        return make_result(true, std::move(resolution));
      }
      if (command == static_cast<EditorCommandId>(EditorBuiltinCommand::COPY)
          || command == static_cast<EditorCommandId>(EditorBuiltinCommand::TRIGGER_COMPLETION)
          || command > EDITOR_BUILTIN_COMMAND_MAX) {
        return make_result(true);
      }

      const EditorBuiltinCommand builtin = static_cast<EditorBuiltinCommand>(command);
      if (builtin != EditorBuiltinCommand::UNDO && builtin != EditorBuiltinCommand::REDO) {
        resolution = finishCompositionForAction();
      }

      bool handled = true;
      TextEditResult edit_result;
      switch (builtin) {
      case EditorBuiltinCommand::CURSOR_LEFT:
        moveCursorLeft(false);
        break;
      case EditorBuiltinCommand::CURSOR_RIGHT:
        moveCursorRight(false);
        break;
      case EditorBuiltinCommand::CURSOR_UP:
        moveCursorUp(false);
        break;
      case EditorBuiltinCommand::CURSOR_DOWN:
        moveCursorDown(false);
        break;
      case EditorBuiltinCommand::CURSOR_LINE_START:
        moveCursorToLineStart(false);
        break;
      case EditorBuiltinCommand::CURSOR_LINE_END:
        moveCursorToLineEnd(false);
        break;
      case EditorBuiltinCommand::CURSOR_PAGE_UP:
        moveCursorPageUp(false);
        break;
      case EditorBuiltinCommand::CURSOR_PAGE_DOWN:
        moveCursorPageDown(false);
        break;
      case EditorBuiltinCommand::SELECT_LEFT:
        moveCursorLeft(true);
        break;
      case EditorBuiltinCommand::SELECT_RIGHT:
        moveCursorRight(true);
        break;
      case EditorBuiltinCommand::SELECT_UP:
        moveCursorUp(true);
        break;
      case EditorBuiltinCommand::SELECT_DOWN:
        moveCursorDown(true);
        break;
      case EditorBuiltinCommand::SELECT_LINE_START:
        moveCursorToLineStart(true);
        break;
      case EditorBuiltinCommand::SELECT_LINE_END:
        moveCursorToLineEnd(true);
        break;
      case EditorBuiltinCommand::SELECT_PAGE_UP:
        moveCursorPageUp(true);
        break;
      case EditorBuiltinCommand::SELECT_PAGE_DOWN:
        moveCursorPageDown(true);
        break;
      case EditorBuiltinCommand::SELECT_ALL:
        selectAll();
        break;
      case EditorBuiltinCommand::BACKSPACE:
        edit_result = backspaceInternal();
        break;
      case EditorBuiltinCommand::DELETE_FORWARD:
        edit_result = deleteForwardInternal();
        break;
      case EditorBuiltinCommand::INSERT_TAB:
        if (m_settings_.insert_spaces && m_document_ != nullptr) {
          uint32_t tab_size = std::max<uint32_t>(1, m_text_layout_->getTabSize());
          const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
          uint32_t visual_col = computeVisualColumn(line_text, m_caret_.active.column, tab_size);
          uint32_t spaces_to_insert = tab_size - (visual_col % tab_size);
          if (spaces_to_insert == 0) {
            spaces_to_insert = tab_size;
          }
          edit_result = insertTextInternal(U8String(spaces_to_insert, ' '));
        } else {
          edit_result = insertTextInternal("\t");
        }
        break;
      case EditorBuiltinCommand::INSERT_NEWLINE:
        edit_result = insertTextInternal("\n");
        break;
      case EditorBuiltinCommand::INSERT_LINE_ABOVE:
        edit_result = insertLineAboveInternal();
        break;
      case EditorBuiltinCommand::INSERT_LINE_BELOW:
        edit_result = insertLineBelowInternal();
        break;
      case EditorBuiltinCommand::UNDO:
        edit_result = undoInternal();
        handled = edit_result.handled;
        break;
      case EditorBuiltinCommand::REDO:
        edit_result = redoInternal();
        handled = edit_result.handled;
        break;
      case EditorBuiltinCommand::MOVE_LINE_UP:
        edit_result = moveLineUpInternal();
        break;
      case EditorBuiltinCommand::MOVE_LINE_DOWN:
        edit_result = moveLineDownInternal();
        break;
      case EditorBuiltinCommand::COPY_LINE_UP:
        edit_result = copyLineUpInternal();
        break;
      case EditorBuiltinCommand::COPY_LINE_DOWN:
        edit_result = copyLineDownInternal();
        break;
      case EditorBuiltinCommand::DELETE_LINE:
        edit_result = deleteLineInternal();
        break;
      default:
        handled = false;
        break;
      }

      if (handled) {
        LOGD("EditorCore::handleKeyEvent, key_code = %d, command = %d, handled = %d", (int)event.key_code, (int)command, handled);
        appendTextEditResult(resolution, std::move(edit_result));
        return make_result(handled, std::move(resolution));
      }
    }

    if (event.isTextInput()) {
      resolution = finishCompositionForAction();
      TextEditResult edit_result = insertTextInternal(event.text);
      LOGD("EditorCore::handleKeyEvent, key_code = %d, handled = %d", (int)event.key_code, 1);
      appendTextEditResult(resolution, std::move(edit_result));
      return make_result(true, std::move(resolution));
    }

    LOGD("EditorCore::handleKeyEvent, key_code = %d, handled = %d", (int)event.key_code, 0);
    return make_result(false);
  }

  EditorActionResult EditorCore::setKeyMap(KeyMap key_map) {
    const ActionSnapshot before = captureActionSnapshot();
    m_key_resolver_.setKeyMap(std::move(key_map));
    return finishAction(before, EditorActionSource::SETUP, true);
  }

#pragma endregion

#pragma region [Editing & Cursor]

  EditorActionResult EditorCore::insertText(const U8String& text) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = insertTextInternal(text);
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::replaceText(const TextRange& range, const U8String& new_text) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = replaceTextInternal(range, new_text);
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::deleteText(const TextRange& range) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = deleteTextInternal(range);
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::applyTextEdits(Vector<TextEdit>&& edits) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = finishCompositionForAction();
    edit_result.cursor_before = m_caret_.active;

    if (m_document_ == nullptr || m_settings_.read_only || edits.empty()) {
      return finishAction(before, EditorActionSource::PROGRAMMATIC, false, std::move(edit_result));
    }

    struct PendingTextEdit {
      TextRange range;
      U8String new_text;
      size_t original_index {0};
      TextPosition new_end;
      bool is_no_op {false};
    };

    Vector<PendingTextEdit> pending;
    pending.reserve(edits.size());
    bool has_real_edits = false;
    for (size_t i = 0; i < edits.size(); ++i) {
      TextRange safe_range = clampDocumentRange(edits[i].range.normalized(), true, false);
      safe_range = safe_range.normalized();
      TextPosition new_end = calcPositionAfterInsert(safe_range.start, edits[i].new_text);
      const bool is_no_op = safe_range.isCollapsed() && edits[i].new_text.empty();
      has_real_edits = has_real_edits || !is_no_op;
      pending.push_back({safe_range, std::move(edits[i].new_text), i, new_end, is_no_op});
    }

    Vector<TextRange> sorted_ranges;
    sorted_ranges.reserve(has_real_edits ? pending.size() : 0);
    for (const auto& edit : pending) {
      if (edit.is_no_op) continue;
      sorted_ranges.push_back(edit.range);
    }
    std::sort(sorted_ranges.begin(), sorted_ranges.end(),
              [](const TextRange& lhs, const TextRange& rhs) {
                if (lhs.start != rhs.start) return lhs.start < rhs.start;
                return lhs.end < rhs.end;
              });
    for (size_t i = 1; i < sorted_ranges.size(); ++i) {
      if (sorted_ranges[i - 1].overlaps(sorted_ranges[i])) {
        return finishAction(before, EditorActionSource::PROGRAMMATIC, false, std::move(edit_result));
      }
    }

    TextPosition primary_cursor = pending[0].new_end;
    if (!has_real_edits) {
      if (primary_cursor != m_caret_.active || hasSelection()) {
        setCursorPositionInternal(primary_cursor);
        clearSelection();
        ensureCursorVisible();
        edit_result.markHandled();
        edit_result.cursor_after = m_caret_.active;
        return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
      }
      edit_result.cursor_after = m_caret_.active;
      return finishAction(before, EditorActionSource::PROGRAMMATIC, false, std::move(edit_result));
    }

    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    std::sort(pending.begin(), pending.end(),
              [](const PendingTextEdit& lhs, const PendingTextEdit& rhs) {
                if (lhs.range.start != rhs.range.start) return rhs.range.start < lhs.range.start;
                return rhs.range.end < lhs.range.end;
              });

    Vector<DocumentReplacement> replacements;
    replacements.reserve(pending.size());
    for (const auto& edit : pending) {
      if (edit.is_no_op) continue;
      replacements.push_back({edit.range, edit.new_text});
      if (edit.original_index != 0) {
        primary_cursor = edit.range.transformPositionAfterEdit(primary_cursor, edit.new_end);
      }
    }

    const CaretState caret_before = m_caret_;
    TextEditResult operation = applyEditBatch(replacements);
    operation.cursor_before = caret_before.active;
    if (operation.contentChanged()) {
      setCursorPositionInternal(primary_cursor);
      clearSelection();
      ensureCursorVisible();
      recordHistory(operation.changes, caret_before, m_caret_);
    }
    operation.cursor_after = m_caret_.active;
    appendTextEditResult(edit_result, std::move(operation));

    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::backspace() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = backspaceInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::deleteForward() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = deleteForwardInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::moveLineUp() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = moveLineUpInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::moveLineDown() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = moveLineDownInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::copyLineUp() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = copyLineUpInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::copyLineDown() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = copyLineDownInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::deleteLine() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = deleteLineInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::insertLineAbove() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = insertLineAboveInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::insertLineBelow() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = insertLineBelowInternal();
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::undo() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = undoInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::redo() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = redoInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  bool EditorCore::canUndo() const {
    return m_undo_manager_->canUndo();
  }

  bool EditorCore::canRedo() const {
    return m_undo_manager_->canRedo();
  }

  EditorActionResult EditorCore::search(const SearchRequest& request) {
    const uint64_t generation = m_search_generation_->fetch_add(1) + 1;
    SearchSnapshot snapshot = buildSearchSnapshot(request, generation);
    publishSearchState(snapshot.state);

    SearchResult searching_result;
    searching_result.state = snapshot.state;
    publishPendingSearchResult(std::move(searching_result));
    SearchResult result = getSearchEngine().search(snapshot);
    if (result.state.generation != m_search_generation_->load()) {
      const ActionSnapshot before = captureActionSnapshot();
      return finishAction(before, EditorActionSource::SEARCH, false);
    }
    chooseCurrentSearchMatch(result, snapshot.cursor_position);
    publishSearchState(result.state);
    publishPendingSearchResult(std::move(result));
    const ActionSnapshot before = captureActionSnapshot();
    return finishAction(before, EditorActionSource::SEARCH, true, {}, true, true);
  }

  EditorActionResult EditorCore::findNextSearchMatch() {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    if (m_search_state_.status != SearchStatus::READY || m_search_matches_.empty()) {
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
    }

    size_t index = m_search_state_.current_index >= 0
        ? static_cast<size_t>(m_search_state_.current_index) + 1
        : firstSearchMatchAtOrAfter(m_caret_.active);
    if (index >= m_search_matches_.size()) {
      if (!m_search_state_.options.wrap_around) {
        return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
      }
      index = 0;
    }

    selectSearchMatch(index);
    return finishAction(before, EditorActionSource::SEARCH, true, std::move(resolution), true, true);
  }

  EditorActionResult EditorCore::findPreviousSearchMatch() {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    if (m_search_state_.status != SearchStatus::READY || m_search_matches_.empty()) {
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
    }

    size_t index = m_search_matches_.size();
    if (m_search_state_.current_index > 0) {
      index = static_cast<size_t>(m_search_state_.current_index) - 1;
    } else if (m_search_state_.current_index == 0) {
      if (!m_search_state_.options.wrap_around) {
        return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
      }
      index = m_search_matches_.size() - 1;
    } else {
      index = firstSearchMatchAtOrAfter(m_caret_.active);
      if (index == 0) {
        if (!m_search_state_.options.wrap_around) {
          return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
        }
        index = m_search_matches_.size() - 1;
      } else if (index >= m_search_matches_.size()) {
        index = m_search_matches_.size() - 1;
      } else {
        --index;
      }
    }

    selectSearchMatch(index);
    return finishAction(before, EditorActionSource::SEARCH, true, std::move(resolution), true, true);
  }

  EditorActionResult EditorCore::replaceCurrentSearchMatch(const U8String& replacement) {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    SearchMatch match;
    SearchOptions options;
    uint64_t generation = 0;

    if (m_document_ == nullptr || m_settings_.read_only
        || m_search_state_.status != SearchStatus::READY
        || m_search_state_.current_index < 0
        || static_cast<size_t>(m_search_state_.current_index) >= m_search_matches_.size()) {
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
    }

    match = m_search_matches_[static_cast<size_t>(m_search_state_.current_index)];
    options = m_search_state_.options;
    generation = m_search_generation_->load();

    const U8String actual_replacement = getSearchEngine().buildReplacement(match, replacement, options);
    if (generation != m_search_generation_->load()) {
      markSearchStaleForDocumentChange();
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution), true, true);
    }
    cancelLinkedEditingInternal();
    TextEditResult edit_result = applyEdit(match.range, actual_replacement);
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::replaceAllSearchMatches(const U8String& replacement) {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    Vector<SearchMatch> matches;
    SearchOptions options;
    uint64_t generation = 0;

    if (m_document_ == nullptr || m_settings_.read_only
        || m_search_state_.status != SearchStatus::READY
        || m_search_matches_.empty()) {
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
    }

    matches = m_search_matches_;
    options = m_search_state_.options;
    generation = m_search_generation_->load();

    Vector<U8String> replacement_texts;
    replacement_texts.reserve(matches.size());
    for (const SearchMatch& match : matches) {
      replacement_texts.push_back(getSearchEngine().buildReplacement(match, replacement, options));
    }
    if (generation != m_search_generation_->load()) {
      markSearchStaleForDocumentChange();
      return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution), true, true);
    }

    TextEditResult edit_result;
    edit_result.cursor_before = m_caret_.active;

    Vector<DocumentReplacement> replacements;
    replacements.reserve(matches.size());
    for (size_t index = 0; index < matches.size(); ++index) {
      replacements.push_back({matches[index].range, replacement_texts[index]});
    }

    const CaretState caret_before = m_caret_;
    cancelLinkedEditingInternal();
    edit_result = applyEditBatch(replacements);
    edit_result.cursor_before = caret_before.active;
    if (edit_result.contentChanged()) {
      const TextPosition cursor_after = calcPositionAfterInsert(
          matches.front().range.start, replacement_texts.front());
      setCursorPositionInternal(cursor_after);
      clearSelection();
      edit_result.cursor_after = m_caret_.active;
      recordHistory(edit_result.changes, caret_before, m_caret_);
    } else {
      edit_result.cursor_after = m_caret_.active;
    }

    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::SEARCH, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::clearSearch() {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    if (m_search_state_.has_current_match
        && hasSelection()
        && m_caret_.normalizedSelection() == m_search_state_.current_range) {
      m_caret_.clearSelection();
    }
    const uint64_t generation = m_search_generation_->fetch_add(1) + 1;
    m_search_state_ = {};
    m_search_state_.generation = generation;
    m_search_matches_.clear();
    m_search_match_indices_by_line_.clear();
    clearPendingSearchResult();
    publishSearchState(m_search_state_);
    return finishAction(before, EditorActionSource::SEARCH, true, {}, true, true);
  }

  SearchState EditorCore::getSearchState() {
    SharedPtr<const SearchState> state = std::atomic_load(&m_published_search_state_);
    if (state == nullptr) {
      return {};
    }
    const uint64_t generation = m_search_generation_->load();
    if (state->generation == generation) {
      SearchState projected = *state;
      if (projected.has_current_match) {
        const std::optional<TextRange> range = ImeProjection::projectCommittedRange(
            *m_document_, getCompositionState(), projected.current_range);
        if (range.has_value()) {
          projected.current_range = *range;
        } else {
          projected.current_index = -1;
          projected.has_current_match = false;
          projected.current_range = {};
        }
      }
      return projected;
    }

    SearchState stale_state = *state;
    stale_state.generation = generation;
    stale_state.status = stale_state.status == SearchStatus::INACTIVE
        ? SearchStatus::INACTIVE
        : SearchStatus::STALE;
    stale_state.match_count = 0;
    stale_state.current_index = -1;
    stale_state.has_current_match = false;
    stale_state.current_range = {};
    return stale_state;
  }

  EditorActionResult EditorCore::setCursorPosition(const TextPosition& position) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    setCursorPositionInternal(position);
    clearSelection();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  TextPosition EditorCore::getCursorPosition() const {
    return m_caret_.active;
  }

  CaretAffinity EditorCore::getCaretAffinity() const {
    return m_caret_.active_affinity;
  }

  EditorActionResult EditorCore::setSelection(const TextRange& range) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    setSelectionInternal(range);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  TextRange EditorCore::getSelection() const {
    return m_caret_.selection();
  }

  bool EditorCore::hasSelection() const {
    return m_caret_.hasSelection();
  }

  EditorActionResult EditorCore::clearSelection() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    m_caret_.clearSelection();
    m_has_preferred_cursor_x_ = false;
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::selectAll() {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();
    size_t last_line = m_document_->getLineCount() > 0 ? m_document_->getLineCount() - 1 : 0;
    uint32_t last_col = m_document_->getLineColumns(last_line);
    setSelectionInternal({{0, 0}, {last_line, last_col}});
    if (m_options_.reveal_selection_end_on_select_all) {
      ensureCursorVisible();
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  U8String EditorCore::getSelectedText() const {
    if (!hasSelection() || m_document_ == nullptr) return "";
    return m_document_->getU8Text(m_caret_.normalizedSelection());
  }

  TextRange EditorCore::getWordRangeAtCursor() const {
    if (m_document_ == nullptr) return {m_caret_.active, m_caret_.active};
    size_t line = m_caret_.active.line;
    const U16String& line_text = m_document_->getLineU16TextRef(line);
    if (line_text.empty()) {
      return {{line, 0}, {line, 0}};
    }

    size_t anchor = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
        line_text,
        std::min(m_caret_.active.column, line_text.length()));
    if (anchor >= line_text.length()) {
      anchor = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, line_text.length());
    } else if (anchor > 0) {
      const size_t previous = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, anchor);
      if (!TextBoundaryUtil::isWordChar(line_text[anchor]) && TextBoundaryUtil::isWordChar(line_text[previous])) {
        anchor = previous;
      }
    }

    return TextBoundaryUtil::findWordRangeInLine(line, line_text, anchor);
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

  EditorActionResult EditorCore::moveCursorLeft(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.start, false);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
    }

    if (m_caret_.active_affinity == CaretAffinity::DOWNSTREAM
        && hasDistinctCaretAffinities(m_caret_.active)) {
      // Move from the next visual-line start to the previous visual-line end first.
      moveCursorTo(m_caret_.active, extend_selection, CaretAffinity::UPSTREAM);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
    }

    TextPosition new_pos = m_caret_.active;
    if (new_pos.column > 0) {
      const U16String& line_text = m_document_->getLineU16TextRef(new_pos.line);
      const size_t cluster_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(line_text, new_pos.column);
      if (cluster_start < new_pos.column) {
        new_pos.column = cluster_start;
      } else {
        new_pos.column = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, new_pos.column);
      }
    } else if (new_pos.line > 0) {
      new_pos.line -= 1;
      new_pos.column = m_document_->getLineColumns(new_pos.line);
    }
    moveCursorTo(new_pos, extend_selection, CaretAffinity::DOWNSTREAM);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorRight(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.end, false);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
    }

    if (m_caret_.active_affinity == CaretAffinity::UPSTREAM
        && hasDistinctCaretAffinities(m_caret_.active)) {
      // Move from the previous visual-line end to the next visual-line start first.
      moveCursorTo(m_caret_.active, extend_selection, CaretAffinity::DOWNSTREAM);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
    }

    TextPosition new_pos = m_caret_.active;
    uint32_t line_cols = m_document_->getLineColumns(new_pos.line);
    if (new_pos.column < line_cols) {
      const U16String& line_text = m_document_->getLineU16TextRef(new_pos.line);
      const size_t cluster_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(line_text, new_pos.column);
      if (cluster_end > new_pos.column) {
        new_pos.column = cluster_end;
      } else {
        new_pos.column = UnicodeUtil::nextGraphemeBoundaryColumn(line_text, new_pos.column);
      }
    } else if (new_pos.line + 1 < m_document_->getLineCount()) {
      new_pos.line += 1;
      new_pos.column = 0;
    }
    const CaretAffinity affinity = hasDistinctCaretAffinities(new_pos)
        ? CaretAffinity::UPSTREAM
        : CaretAffinity::DOWNSTREAM;
    moveCursorTo(new_pos, extend_selection, affinity);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorUp(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) {
      return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    }
    TextEditResult resolution = finishCompositionForAction();

    const PointF current_screen = m_text_layout_->getPositionScreenCoord(
        m_caret_.active, m_caret_.active_affinity);
    // Reuse the first vertical move's x so short lines do not shift later moves left.
    if (!m_has_preferred_cursor_x_) {
      m_preferred_cursor_x_ = current_screen.x;
      m_has_preferred_cursor_x_ = true;
    }
    const float line_height = m_text_layout_->getLineHeight();
    const PointF target_point = {
      m_preferred_cursor_x_, current_screen.y - line_height * 0.5f
    };
    const CaretHit hit = m_text_layout_->hitTestPointer(target_point);
    moveCursorTo(hit.position, extend_selection, hit.affinity, true);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorDown(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) {
      return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    }
    TextEditResult resolution = finishCompositionForAction();

    const PointF current_screen = m_text_layout_->getPositionScreenCoord(
        m_caret_.active, m_caret_.active_affinity);
    if (!m_has_preferred_cursor_x_) {
      m_preferred_cursor_x_ = current_screen.x;
      m_has_preferred_cursor_x_ = true;
    }
    const float line_height = m_text_layout_->getLineHeight();
    const PointF target_point = {
      m_preferred_cursor_x_, current_screen.y + line_height * 1.5f
    };
    const CaretHit hit = m_text_layout_->hitTestPointer(target_point);
    moveCursorTo(hit.position, extend_selection, hit.affinity, true);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorToLineStart(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();
    moveCursorTo({m_caret_.active.line, 0}, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorToLineEnd(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();
    uint32_t cols = m_document_->getLineColumns(m_caret_.active.line);
    moveCursorTo({m_caret_.active.line, cols}, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorPageUp(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) {
      return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
    }
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorUp(extend_selection);
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::moveCursorPageDown(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    TextEditResult resolution = finishCompositionForAction();
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) {
      return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
    }
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorDown(extend_selection);
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  EditorActionResult EditorCore::setReadOnly(bool read_only) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution;
    if (read_only && hasPreedit()) {
      resolution = finishCompositionForAction();
    }
    m_settings_.read_only = read_only;
    LOGD("EditorCore::setReadOnly, read_only = %s", read_only ? "true" : "false");
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, std::move(resolution));
  }

  bool EditorCore::isReadOnly() const {
    return m_settings_.read_only;
  }

  EditorActionResult EditorCore::setAutoIndentMode(AutoIndentMode mode) {
    const ActionSnapshot before = captureActionSnapshot();
    m_settings_.auto_indent_mode = mode;
    LOGD("EditorCore::setAutoIndentMode, mode = %d", (int)mode);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  AutoIndentMode EditorCore::getAutoIndentMode() const {
    return m_settings_.auto_indent_mode;
  }

  EditorActionResult EditorCore::setBackspaceUnindent(bool enabled) {
    const ActionSnapshot before = captureActionSnapshot();
    m_settings_.backspace_unindent = enabled;
    LOGD("EditorCore::setBackspaceUnindent, enabled = %s", enabled ? "true" : "false");
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::setInsertSpaces(bool enabled) {
    const ActionSnapshot before = captureActionSnapshot();
    m_settings_.insert_spaces = enabled;
    LOGD("EditorCore::setInsertSpaces, enabled = %s", enabled ? "true" : "false");
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::insertSnippet(const U8String& snippet_template) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    TextEditResult edit_result = insertSnippetInternal(snippet_template);
    appendTextEditResult(resolution, std::move(edit_result));
    return finishAction(before, EditorActionSource::PROGRAMMATIC, resolution.handled, std::move(resolution));
  }

  EditorActionResult EditorCore::startLinkedEditing(LinkedEditingModel&& model) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    startLinkedEditingInternal(std::move(model));
    return finishAction(before, EditorActionSource::LINKED_EDITING, true, std::move(resolution));
  }

  bool EditorCore::isInLinkedEditing() const {
    return m_linked_editing_session_ != nullptr && m_linked_editing_session_->isActive();
  }

  EditorActionResult EditorCore::linkedEditingNextTabStop() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    bool handled = linkedEditingNextTabStopInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, handled, std::move(resolution));
  }

  EditorActionResult EditorCore::linkedEditingPrevTabStop() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    bool handled = linkedEditingPrevTabStopInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, handled, std::move(resolution));
  }

  EditorActionResult EditorCore::cancelLinkedEditing() {
    const ActionSnapshot before = captureActionSnapshot();
    cancelLinkedEditingInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, true);
  }

  EditorActionResult EditorCore::finishLinkedEditing() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult resolution = finishCompositionForAction();
    finishLinkedEditingInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, true, std::move(resolution));
  }

#pragma endregion

#pragma region [Navigation & Decorations]

  EditorActionResult EditorCore::scrollToLine(size_t line, ScrollBehavior behavior) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

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
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::gotoPosition(size_t line, size_t column) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

    scrollToLine(line, ScrollBehavior::GOTO_CENTER);
    clearSelection();
    setCursorPosition({line, column});
    ensureCursorVisible();
    LOGD("EditorCore::gotoLine, line = %zu, column = %zu, cursor = %s",
         line, column, m_caret_.active.dump().c_str());
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::ensureCursorVisible() {
    const ActionSnapshot before = captureActionSnapshot();
    PointF cursor_screen = m_text_layout_->getPositionScreenCoord(
        m_caret_.active, m_caret_.active_affinity);
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
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::setScroll(float scroll_x, float scroll_y) {
    const ActionSnapshot before = captureActionSnapshot();
    m_view_state_.scroll_x = scroll_x;
    m_view_state_.scroll_y = scroll_y;
    normalizeScrollState();
    LOGD("EditorCore::setScroll, m_view_state_ = %s", m_view_state_.dump().c_str());
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
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
    CursorRect rect;
    if (m_text_layout_ == nullptr) {
      return rect;
    }
    const PointF point = m_text_layout_->getPositionScreenCoord(m_caret_.active,
                                                                 m_caret_.active_affinity);
    rect.x = point.x;
    rect.y = point.y;
    rect.height = m_text_layout_->getLineHeight();
    return rect;
  }

  EditorActionResult EditorCore::registerTextStyle(uint32_t style_id, TextStyle&& style) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->getTextStyleRegistry()->registerTextStyle(style_id, std::move(style));
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::registerBatchTextStyles(Vector<std::pair<uint32_t, TextStyle>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto registry = m_decorations_->getTextStyleRegistry();
    for (auto& [style_id, style] : entries) {
      registry->registerTextStyle(style_id, std::move(style));
    }
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineSpans(line, layer, std::move(spans));
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineSpans(SpanLayer layer, Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, spans] : entries) {
      m_decorations_->setLineSpans(line, layer, std::move(spans));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineInlayHints(size_t line, Vector<InlayHint>&& hints) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineInlayHints(line, std::move(hints));
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineInlayHints(Vector<std::pair<size_t, Vector<InlayHint>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, hints] : entries) {
      m_decorations_->setLineInlayHints(line, std::move(hints));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLinePhantomTexts(line, std::move(phantoms));
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLinePhantomTexts(Vector<std::pair<size_t, Vector<PhantomText>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, phantoms] : entries) {
      m_decorations_->setLinePhantomTexts(line, std::move(phantoms));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineGutterIcons(line, std::move(icons));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineGutterIcons(Vector<std::pair<size_t, Vector<GutterIcon>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    for (auto& [line, icons] : entries) {
      m_decorations_->setLineGutterIcons(line, std::move(icons));
    }
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setMaxGutterIcons(uint32_t count) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_text_layout_->getLayoutMetrics().max_gutter_icons == count) return finishAction(before, EditorActionSource::DECORATION, true);
    m_text_layout_->getLayoutMetrics().max_gutter_icons = count;
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineCodeLens(size_t line, Vector<CodeLensItem>&& items) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineCodeLens(line, std::move(items));
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineCodeLens(Vector<std::pair<size_t, Vector<CodeLensItem>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, items] : entries) {
      m_decorations_->setLineCodeLens(line, std::move(items));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearCodeLens() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearCodeLens();
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineLinks(size_t line, Vector<LinkSpan>&& links) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineLinks(line, std::move(links));
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    auto& lines = m_document_->getLogicalLines();
    if (line < lines.size()) {
      lines[line].is_layout_dirty = true;
    }
    m_text_layout_->invalidateContentMetrics(line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineLinks(Vector<std::pair<size_t, Vector<LinkSpan>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    auto& lines = m_document_->getLogicalLines();
    size_t min_line = entries[0].first;
    for (auto& [line, links] : entries) {
      m_decorations_->setLineLinks(line, std::move(links));
      if (line < lines.size()) {
        lines[line].is_layout_dirty = true;
      }
      if (line < min_line) min_line = line;
    }
    if (hasPreedit()) {
      markAllLinesDirty();
      return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
    }
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearLinks() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearLinks();
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  U8String EditorCore::getLinkTargetAt(size_t line, size_t column) const {
    LineLayoutDecorations decorations;
    collectLineLayoutDecorations(line, decorations);
    for (const LinkSpan& link : decorations.links) {
      const size_t end = static_cast<size_t>(link.column) + link.length;
      if (column >= link.column && column < end) {
        return link.target;
      }
    }
    return {};
  }

  EditorActionResult EditorCore::setLineDiagnostics(size_t line, Vector<Diagnostic>&& diagnostics) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineDiagnostics(line, std::move(diagnostics));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineDiagnostics(Vector<std::pair<size_t, Vector<Diagnostic>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    for (auto& [line, diagnostics] : entries) {
      m_decorations_->setLineDiagnostics(line, std::move(diagnostics));
    }
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearDiagnostics() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearDiagnostics();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineDocumentHighlights(size_t line, Vector<DocumentHighlight>&& highlights) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineDocumentHighlights(line, std::move(highlights));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBatchLineDocumentHighlights(Vector<std::pair<size_t, Vector<DocumentHighlight>>>&& entries) {
    const ActionSnapshot before = captureActionSnapshot();
    if (entries.empty()) return finishAction(before, EditorActionSource::DECORATION, true);
    for (auto& [line, highlights] : entries) {
      m_decorations_->setLineDocumentHighlights(line, std::move(highlights));
    }
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearDocumentHighlights() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearDocumentHighlights();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setIndentGuides(Vector<IndentGuide>&& guides) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setIndentGuides(std::move(guides));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBracketGuides(Vector<BracketGuide>&& guides) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setBracketGuides(std::move(guides));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setFlowGuides(Vector<FlowGuide>&& guides) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setFlowGuides(std::move(guides));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setSeparatorGuides(Vector<SeparatorGuide>&& guides) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setSeparatorGuides(std::move(guides));
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setFoldRegions(Vector<FoldRegion>&& regions) {
    const ActionSnapshot before = captureActionSnapshot();
    bool had_fold_regions = m_text_layout_->getLayoutMetrics().has_fold_regions;
    m_text_layout_->getLayoutMetrics().has_fold_regions = !regions.empty();
    if (had_fold_regions != m_text_layout_->getLayoutMetrics().has_fold_regions) {
      markAllLinesDirty();
    }
    m_decorations_->setFoldRegions(std::move(regions));
    syncFoldState();
    return finishAction(before, EditorActionSource::FOLDING, true, {}, true, true);
  }

  EditorActionResult EditorCore::foldAt(size_t line) {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = foldAtInternal(line);
    return finishAction(before, EditorActionSource::FOLDING, handled, {}, handled, handled);
  }

  EditorActionResult EditorCore::unfoldAt(size_t line) {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = unfoldAtInternal(line);
    return finishAction(before, EditorActionSource::FOLDING, handled, {}, handled, handled);
  }

  EditorActionResult EditorCore::toggleFoldAt(size_t line) {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = toggleFoldAtInternal(line);
    return finishAction(before, EditorActionSource::FOLDING, handled, {}, handled, handled);
  }

  EditorActionResult EditorCore::foldAll() {
    const ActionSnapshot before = captureActionSnapshot();
    foldAllInternal();
    return finishAction(before, EditorActionSource::FOLDING, true, {}, true, true);
  }

  EditorActionResult EditorCore::unfoldAll() {
    const ActionSnapshot before = captureActionSnapshot();
    unfoldAllInternal();
    return finishAction(before, EditorActionSource::FOLDING, true, {}, true, true);
  }

  bool EditorCore::isLineVisible(size_t line) const {
    return !m_decorations_->isLineHidden(line);
  }

  EditorActionResult EditorCore::clearHighlights(SpanLayer layer) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearHighlights(layer);
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearHighlights() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearHighlights();
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearInlayHints() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearInlayHints();
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearPhantomTexts() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearPhantomTexts();
    markAllLinesDirty();
    normalizeScrollState();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearGutterIcons() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearGutterIcons();
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearGuides() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearGuides();
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearAllDecorations() {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->clearAll();
    markAllLinesDirty();
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setBracketPairs(Vector<BracketPair>&& pairs) {
    const ActionSnapshot before = captureActionSnapshot();
    m_bracket_pairs_ = std::move(pairs);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true, {}, true);
  }

  EditorActionResult EditorCore::setAutoClosingPairs(Vector<BracketPair>&& pairs) {
    const ActionSnapshot before = captureActionSnapshot();
    m_auto_closing_pairs_ = std::move(pairs);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::setMatchedBrackets(const TextPosition& open, const TextPosition& close) {
    const ActionSnapshot before = captureActionSnapshot();
    m_external_bracket_open_ = open;
    m_external_bracket_close_ = close;
    m_has_external_brackets_ = true;
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::clearMatchedBrackets() {
    const ActionSnapshot before = captureActionSnapshot();
    m_has_external_brackets_ = false;
    m_external_bracket_open_ = {};
    m_external_bracket_close_ = {};
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

#pragma endregion

#pragma region [Setup & View State Internals]

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

#pragma endregion

#pragma region [Rendering & Input Internals]

  void EditorCore::collectLineLayoutDecorations(size_t line, LineLayoutDecorations& decorations) const {
    const std::optional<CompositionState>& composition = getCompositionState();
    const Vector<size_t> source_lines = ImeProjection::committedSourceLinesForEditingLine(
        *m_document_, composition, line);
    for (size_t source_line : source_lines) {
      for (const StyleSpan& span : m_decorations_->getMergedLineSpans(source_line)) {
        const TextRange committed {{source_line, span.column},
                                   {source_line, static_cast<size_t>(span.column) + span.length}};
        const std::optional<TextRange> projected = ImeProjection::projectCommittedRange(
            *m_document_, composition, committed);
        if (!projected.has_value()
            || projected->start.line != line
            || projected->end.line != line
            || projected->end.column <= projected->start.column) {
          continue;
        }
        StyleSpan value = span;
        value.column = static_cast<uint32_t>(projected->start.column);
        value.length = static_cast<uint32_t>(projected->end.column - projected->start.column);
        decorations.spans.push_back(std::move(value));
      }

      for (const InlayHint& hint : m_decorations_->getLineInlayHints(source_line)) {
        const std::optional<TextPosition> projected = ImeProjection::projectCommittedAnchor(
            *m_document_, composition, {source_line, hint.column}, ImeProjection::EndpointBias::AFTER);
        if (!projected.has_value() || projected->line != line) continue;
        InlayHint value = hint;
        value.column = static_cast<uint32_t>(projected->column);
        decorations.inlay_hints.push_back(std::move(value));
      }

      for (const PhantomText& phantom : m_decorations_->getLinePhantomTexts(source_line)) {
        const std::optional<TextPosition> projected = ImeProjection::projectCommittedAnchor(
            *m_document_, composition, {source_line, phantom.column}, ImeProjection::EndpointBias::AFTER);
        if (!projected.has_value() || projected->line != line) continue;
        PhantomText value = phantom;
        value.column = static_cast<uint32_t>(projected->column);
        decorations.phantom_texts.push_back(std::move(value));
      }

      for (const LinkSpan& link : m_decorations_->getLineLinks(source_line)) {
        const TextRange committed {{source_line, link.column},
                                   {source_line, static_cast<size_t>(link.column) + link.length}};
        const std::optional<TextRange> projected = ImeProjection::projectCommittedRange(
            *m_document_, composition, committed);
        if (!projected.has_value()
            || projected->start.line != line
            || projected->end.line != line
            || projected->end.column <= projected->start.column) {
          continue;
        }
        LinkSpan value = link;
        value.column = static_cast<uint32_t>(projected->start.column);
        value.length = static_cast<uint32_t>(projected->end.column - projected->start.column);
        decorations.links.push_back(std::move(value));
      }
    }

    const auto by_column = [](const auto& lhs, const auto& rhs) {
      return lhs.column < rhs.column;
    };
    std::stable_sort(decorations.spans.begin(), decorations.spans.end(), by_column);
    std::stable_sort(decorations.inlay_hints.begin(), decorations.inlay_hints.end(), by_column);
    std::stable_sort(decorations.phantom_texts.begin(), decorations.phantom_texts.end(), by_column);
    std::stable_sort(decorations.links.begin(), decorations.links.end(), by_column);
  }

  void EditorCore::collectTextPresentationEffectsForLine(
      size_t line, Vector<TextPresentationEffect>& effects) const {
    if (m_caret_.hasSelection()) {
      const TextRange selection = m_caret_.normalizedSelection();
      const RangeEffectStyle& selection_style = m_settings_.range_effect_styles.selection;
      if (selection.start != selection.end
          && line >= selection.start.line
          && line <= selection.end.line
          && (selection_style.foreground_color != 0 || selection_style.background_color != 0)) {
        TextPresentationEffect effect;
        effect.range = selection;
        effect.foreground_color = selection_style.foreground_color;
        effect.clear_text_background = selection_style.foreground_color != 0
            || selection_style.background_color != 0;
        effect.priority = 100;
        effects.push_back(effect);
      }
    }

    const std::optional<CompositionState>& composition = getCompositionState();
    const Vector<size_t> highlight_source_lines = ImeProjection::committedSourceLinesForEditingLine(
        *m_document_, composition, line);
    for (size_t source_line : highlight_source_lines) {
      const auto& document_highlights =
          m_decorations_->getLineDocumentHighlights(source_line);
      for (const auto& highlight : document_highlights) {
        if (highlight.length == 0) continue;
        const std::optional<TextRange> projected = ImeProjection::projectCommittedRange(
            *m_document_, composition, {
                {source_line, highlight.column},
                {source_line, static_cast<size_t>(highlight.column) + highlight.length}
            });
        if (!projected.has_value()
            || line < projected->start.line
            || line > projected->end.line) {
          continue;
        }
        const RangeEffectStyle& style =
            RenderStyleUtil::documentHighlightRangeEffectStyle(
                m_settings_.range_effect_styles, highlight.kind);
        if (style.foreground_color == 0 && style.background_color == 0) {
          continue;
        }

        TextPresentationEffect effect;
        effect.range = *projected;
        effect.foreground_color = style.foreground_color;
        effect.clear_text_background = style.background_color != 0;
        effect.priority = 60;
        effects.push_back(effect);
      }
    }

    const auto append_search_effect = [&](uint32_t match_index, const TextRange& range) {
      if (match_index >= m_search_matches_.size()) return;
      const bool is_current = m_search_state_.current_index >= 0
          && match_index == static_cast<uint32_t>(m_search_state_.current_index);
      const RangeEffectStyle& style = is_current
          ? m_settings_.range_effect_styles.search_current
          : m_settings_.range_effect_styles.search_match;
      if (style.foreground_color == 0 && style.background_color == 0) {
        return;
      }

      TextPresentationEffect effect;
      effect.range = range;
      effect.foreground_color = style.foreground_color;
      effect.clear_text_background = style.background_color != 0;
      effect.priority = is_current ? 80 : 70;
      effects.push_back(effect);
    };

    if (hasPreedit()) {
      for (size_t index = 0; index < m_search_matches_.size(); ++index) {
        const std::optional<TextRange> range = ImeProjection::projectCommittedRange(
            *m_document_, composition, m_search_matches_[index].range);
        if (!range.has_value() || line < range->start.line || line > range->end.line) {
          continue;
        }
        append_search_effect(static_cast<uint32_t>(index), *range);
      }
      return;
    }

    if (line >= m_search_match_indices_by_line_.size()) {
      return;
    }

    for (uint32_t match_index : m_search_match_indices_by_line_[line]) {
      if (match_index >= m_search_matches_.size()) continue;
      append_search_effect(match_index, m_search_matches_[match_index].range);
    }
  }

  void EditorCore::clearHoverHitTarget() {
    m_hover_hit_target_ = {};
  }

  void EditorCore::clearPressHitTarget() {
    m_press_hit_target_ = {};
  }

  HitTarget EditorCore::getActiveHitTarget() const {
    return m_press_hit_target_.type != HitTargetType::NONE ? m_press_hit_target_ : m_hover_hit_target_;
  }

  EditorCore::PointerProbeResult EditorCore::probePointer(const PointF& point, KeyModifier modifiers) const {
    PointerProbeResult result;
    if (point.x < 0.0f || point.y < 0.0f
        || point.x >= m_viewport_.width || point.y >= m_viewport_.height) {
      result.cursor_type = PointerCursorType::DEFAULT;
      return result;
    }
    if (m_text_layout_ == nullptr) {
      result.cursor_type = PointerCursorType::TEXT;
      return result;
    }

    if (m_interaction_->isPointInScrollbar(point)) {
      result.cursor_type = PointerCursorType::DEFAULT;
      return result;
    }

    const HitTarget target = m_text_layout_->hitTestDecoration(point);
    if (target.type == HitTargetType::CODELENS
        || (target.type == HitTargetType::LINK
            && hasAnyModifier(modifiers, KeyModifier::CTRL | KeyModifier::META))) {
      result.hot_target = target;
    }
    if (result.hot_target.type != HitTargetType::NONE) {
      result.cursor_type = PointerCursorType::HAND;
      return result;
    }

    result.cursor_type = point.x >= m_text_layout_->getLayoutMetrics().textAreaX()
                           ? PointerCursorType::TEXT
                           : PointerCursorType::DEFAULT;
    return result;
  }

  bool EditorCore::updatePointerHitTargetLifecycle(const GestureEvent& event,
                                                   const HitTarget& primary_hot_target) {
    switch (event.type) {
    case EventType::MOUSE_MOVE:
      if (m_mouse_button_down_) {
        const bool handled = m_press_hit_target_.type != HitTargetType::NONE;
        if (handled && primary_hot_target != m_press_hit_target_) {
          clearPressHitTarget();
        }
        return handled;
      }
      m_hover_hit_target_ = primary_hot_target;
      return false;

    case EventType::MOUSE_DOWN:
      m_mouse_button_down_ = true;
      clearHoverHitTarget();
      m_press_hit_target_ = primary_hot_target;
      return m_press_hit_target_.type != HitTargetType::NONE;

    case EventType::MOUSE_UP: {
      m_mouse_button_down_ = false;
      const bool handled = m_press_hit_target_.type != HitTargetType::NONE;
      clearPressHitTarget();
      return handled;
    }

    case EventType::TOUCH_DOWN:
      m_press_hit_target_ = primary_hot_target;
      return m_press_hit_target_.type != HitTargetType::NONE;

    case EventType::TOUCH_MOVE: {
      const bool handled = m_press_hit_target_.type != HitTargetType::NONE;
      if (handled && primary_hot_target != m_press_hit_target_) {
        clearPressHitTarget();
      }
      return handled;
    }

    case EventType::TOUCH_UP:
    case EventType::TOUCH_CANCEL:
    case EventType::TOUCH_POINTER_DOWN: {
      const bool handled = m_press_hit_target_.type != HitTargetType::NONE;
      clearPressHitTarget();
      return handled;
    }

    default:
      return false;
    }
  }

  EditorCore::ActionSnapshot EditorCore::captureActionSnapshot() const {
    ActionSnapshot snapshot;
    snapshot.caret = m_caret_;
    snapshot.scroll_x = m_view_state_.scroll_x;
    snapshot.scroll_y = m_view_state_.scroll_y;
    snapshot.scale = m_view_state_.scale;
    snapshot.pointer_cursor_type = m_pointer_cursor_type_;
    snapshot.active_hit_target = getActiveHitTarget();
    snapshot.composition = getCompositionState();
    snapshot.ime_session_active = m_ime_session_.has_value();
    return snapshot;
  }

  EditorActionResult EditorCore::finishAction(const ActionSnapshot& before, EditorActionSource source, bool handled,
                                              TextEditResult edit_result, bool force_redraw,
                                              bool decoration_changed) {
    EditorActionResult result;
    result.handled = handled || edit_result.handled;
    result.source = source;
    result.text_change_kind = edit_result.contentChanged()
                              ? edit_result.change_kind
                              : TextChangeKind::NONE;
    result.changes = std::move(edit_result.changes);
    result.content_changed = !result.changes.empty();

    result.cursor_before = before.caret.active;
    result.cursor_after = m_caret_.active;
    result.cursor_changed = result.cursor_before != result.cursor_after
                            || before.caret.active_affinity != m_caret_.active_affinity;

    result.has_selection_before = before.caret.hasSelection();
    result.has_selection_after = hasSelection();
    result.selection_before = before.caret.selection();
    result.selection_after = m_caret_.selection();
    result.selection_changed = result.has_selection_before != result.has_selection_after
                               || (result.has_selection_after
                                   && (!(result.selection_before == result.selection_after)
                                       || before.caret.active_affinity != m_caret_.active_affinity));

    result.scroll_x_before = before.scroll_x;
    result.scroll_y_before = before.scroll_y;
    result.scroll_x_after = m_view_state_.scroll_x;
    result.scroll_y_after = m_view_state_.scroll_y;
    result.scroll_changed = result.scroll_x_before != result.scroll_x_after
                            || result.scroll_y_before != result.scroll_y_after;

    result.scale_before = before.scale;
    result.scale_after = m_view_state_.scale;
    result.scale_changed = result.scale_before != result.scale_after;

    result.pointer_cursor_before = before.pointer_cursor_type;
    result.pointer_cursor_after = m_pointer_cursor_type_;
    result.pointer_cursor_changed = result.pointer_cursor_before != result.pointer_cursor_after;

    const bool active_hit_target_changed = before.active_hit_target != getActiveHitTarget();
    const InteractionAnimationState animation_state = m_interaction_->resolveAnimationState();
    result.composition_changed = before.composition != getCompositionState();
    result.decoration_changed = decoration_changed;
    const bool ime_state_changed = result.content_changed
        || result.cursor_changed
        || result.selection_changed
        || result.composition_changed;
    const bool restart_text_update_session = source != EditorActionSource::IME
        && isImeTextUpdateSession()
        && ime_state_changed;
    const bool session_invalidated = source != EditorActionSource::IME
        && before.ime_session_active
        && !m_ime_session_.has_value();
    if (session_invalidated || restart_text_update_session) {
      if (restart_text_update_session) {
        closeImeSession();
      }
      result.ime_host_action = m_settings_.read_only
          ? ImeHostAction::CLOSE_SESSION
          : ImeHostAction::RESTART_SESSION;
      result.ime_state = emptyImeState(ImeResultCode::OK);
    } else {
      result.ime_state = buildImeState();
    }
    result.needs_redraw = force_redraw
                          || result.content_changed
                          || result.cursor_changed
                          || result.selection_changed
                          || result.scroll_changed
                          || result.scale_changed
                          || result.composition_changed
                          || active_hit_target_changed
                          || result.decoration_changed
                          || animation_state.needs_redraw;
    result.animation_flags = animation_state.flags;
    result.next_animation_delay_ms = animation_state.next_tick_delay_ms;
    result.interaction_flags = m_interaction_->resolveInteractionFlags();
    return result;
  }

  EditorActionResult EditorCore::finishInteractionAction(
      const ActionSnapshot& before, InteractionResult interaction_result, EditorActionSource source,
      EventType event_type, bool decoration_changed) {
    const GestureResult& gesture_result = interaction_result.gesture;
    EditorActionResult result = finishAction(before, source, interaction_result.handled, {},
                                             interaction_result.needs_redraw, decoration_changed);
    result.gesture_type = gesture_result.type;
    result.gesture_event_type = event_type;
    result.tap_point = gesture_result.tap_point;
    result.hit_target = gesture_result.hit_target;
    result.modifiers = gesture_result.modifiers;
    return result;
  }

#pragma endregion

#pragma region [Editing & Cursor Internals]

  TextEditResult EditorCore::insertTextInternal(const U8String& text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (text.empty() && !hasSelection()) return {};

    // Auto-indent: when inserting a newline with KEEP_INDENT enabled, append previous line's leading whitespace
    U8String actual_text = text;
    if (text == "\n" && m_settings_.auto_indent_mode == AutoIndentMode::KEEP_INDENT) {
      size_t current_line = hasSelection() ? m_caret_.normalizedSelection().start.line : m_caret_.active.line;
      const U16String& line_text = m_document_->getLineU16TextRef(current_line);
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

    if (!m_auto_closing_pairs_.empty() && !text.empty() && text != "\n" && !isInLinkedEditing()) {
      auto it = text.begin();
      char32_t input_char = utf8::peek_next(it, text.end());
      auto next_it = it;
      utf8::advance(next_it, 1, text.end());
      bool is_single_char = (next_it == text.end());

      if (is_single_char) {
        const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
        size_t col = m_caret_.active.column;
        char32_t right_char = (col < line_text.size()) ? static_cast<char32_t>(line_text[col]) : 0;

        if (!hasSelection()) {
          for (const auto& pair : m_auto_closing_pairs_) {
            if (input_char == pair.close && right_char == pair.close) {
              const TextPosition cursor_before = m_caret_.active;
              m_caret_.active.column++;
              m_caret_.clearSelection();
              ensureCursorVisible();
              TextEditResult result;
              result.markHandled();
              result.cursor_before = cursor_before;
              result.cursor_after = m_caret_.active;
              return result;
            }
          }
          for (const auto& pair : m_auto_closing_pairs_) {
            if (input_char == pair.open) {
              if (pair.open == pair.close && right_char == pair.close) {
                const TextPosition cursor_before = m_caret_.active;
                m_caret_.active.column++;
                m_caret_.clearSelection();
                ensureCursorVisible();
                TextEditResult result;
                result.markHandled();
                result.cursor_before = cursor_before;
                result.cursor_after = m_caret_.active;
                return result;
              }
              bool should_auto_close = false;
              size_t scan_col = col;
              while (scan_col < line_text.size() && (line_text[scan_col] == u' ' || line_text[scan_col] == u'\t')) {
                scan_col++;
              }
              if (scan_col >= line_text.size()) {
                should_auto_close = true;
              } else {
                char32_t next_ch = static_cast<char32_t>(line_text[scan_col]);
                if (next_ch == u';' || next_ch == u',') {
                  should_auto_close = true;
                } else {
                  for (const auto& p : m_auto_closing_pairs_) {
                    if (next_ch == static_cast<char32_t>(p.close)) {
                      should_auto_close = true;
                      break;
                    }
                  }
                }
              }
              if (should_auto_close) {
                U8String pair_text;
                utf8::append(pair.open, std::back_inserter(pair_text));
                utf8::append(pair.close, std::back_inserter(pair_text));
                TextRange range = {m_caret_.active, m_caret_.active};
                auto result = applyEdit(range, pair_text);
                m_caret_.active.column = static_cast<uint32_t>(col + 1);
                m_caret_.clearSelection();
                ensureCursorVisible();
                return result;
              }
              break;
            }
          }
        } else {
          for (const auto& pair : m_auto_closing_pairs_) {
            if (input_char == pair.open) {
              TextRange sel = m_caret_.normalizedSelection();
              U8String selected = m_document_->getU8Text(sel);
              U8String surround_text;
              utf8::append(pair.open, std::back_inserter(surround_text));
              surround_text += selected;
              utf8::append(pair.close, std::back_inserter(surround_text));
              auto result = applyEdit(sel, surround_text);
              return result;
            }
          }
        }
      }
    }

    const TextRange range = hasSelection()
        ? m_caret_.normalizedSelection()
        : TextRange {m_caret_.active, m_caret_.active};
    TextEditResult result = replaceTextInternal(range, actual_text);
    LOGD("EditorCore::insertText, cursor = %s", m_caret_.active.dump().c_str());
    return result;
  }

  TextEditResult EditorCore::replaceTextInternal(const TextRange& range, const U8String& new_text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (isInLinkedEditing()) {
      TextEditResult result = applyLinkedEditWithResult(range, new_text);
      if (result.handled) {
        LOGD("EditorCore::replaceText(linked), cursor = %s", m_caret_.active.dump().c_str());
        return result;
      }
      cancelLinkedEditingInternal();
    }

    TextEditResult result = applyEdit(range, new_text);
    LOGD("EditorCore::replaceText, cursor = %s", m_caret_.active.dump().c_str());
    return result;
  }

  TextEditResult EditorCore::deleteTextInternal(const TextRange& range) {
    return replaceTextInternal(range, "");
  }

  TextEditResult EditorCore::backspaceInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      auto result = replaceTextInternal(range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    }

    if (m_caret_.active.column > 0) {
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
      size_t col = m_caret_.active.column;

      if (!m_auto_closing_pairs_.empty() && col > 0 && col < line_text.size()) {
        char32_t left_char = static_cast<char32_t>(line_text[col - 1]);
        char32_t right_char = static_cast<char32_t>(line_text[col]);
        for (const auto& pair : m_auto_closing_pairs_) {
          if (left_char == static_cast<char32_t>(pair.open) && right_char == static_cast<char32_t>(pair.close)) {
            TextRange del_range = {{m_caret_.active.line, static_cast<uint32_t>(col - 1)}, {m_caret_.active.line, static_cast<uint32_t>(col + 1)}};
            auto result = replaceTextInternal(del_range, "");
            LOGD("EditorCore::backspace(auto-close-pair), cursor = %s", m_caret_.active.dump().c_str());
            return result;
          }
        }
      }

      if (m_settings_.backspace_unindent && col > 0) {
        bool prefix_all_whitespace = true;
        for (size_t i = 0; i < col; ++i) {
          if (line_text[i] != u' ' && line_text[i] != u'\t') {
            prefix_all_whitespace = false;
            break;
          }
        }
        if (prefix_all_whitespace) {
          bool entire_line_blank = true;
          for (size_t i = col; i < line_text.size(); ++i) {
            if (line_text[i] != u' ' && line_text[i] != u'\t') {
              entire_line_blank = false;
              break;
            }
          }
          if (entire_line_blank && m_caret_.active.line > 0) {
            size_t prev_line = m_caret_.active.line - 1;
            uint32_t prev_cols = m_document_->getLineColumns(prev_line);
            TextRange del_range = {{prev_line, prev_cols}, {m_caret_.active.line, (uint32_t)line_text.size()}};
            auto result = replaceTextInternal(del_range, "");
            LOGD("EditorCore::backspace, cursor = %s", m_caret_.active.dump().c_str());
            return result;
          }
          uint32_t tab_size = std::max<uint32_t>(1, m_text_layout_->getTabSize());
          uint32_t visual_col = computeVisualColumn(line_text, col, tab_size);
          uint32_t target_visual = (visual_col > 0) ? ((visual_col - 1) / tab_size) * tab_size : 0;
          uint32_t cur_visual = 0;
          size_t target_col = 0;
          for (size_t i = 0; i < col; ++i) {
            if (cur_visual >= target_visual) {
              target_col = i;
              break;
            }
            cur_visual = advanceVisualColumn(line_text[i], cur_visual, tab_size);
            target_col = i + 1;
          }
          if (target_col < col) {
            TextRange del_range = {{m_caret_.active.line, (uint32_t)target_col}, {m_caret_.active.line, (uint32_t)col}};
            auto result = replaceTextInternal(del_range, "");
            LOGD("EditorCore::backspace, cursor = %s", m_caret_.active.dump().c_str());
            return result;
          }
        }
      }

      const size_t cluster_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(line_text, col);
      const size_t cluster_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(line_text, col);
      const bool cursor_inside_cluster = (cluster_start < col && cluster_end > col);
      const size_t delete_start = cursor_inside_cluster
          ? cluster_start
          : UnicodeUtil::prevGraphemeBoundaryColumn(line_text, col);
      const size_t delete_end = cursor_inside_cluster ? cluster_end : col;
      TextRange del_range = {{m_caret_.active.line, delete_start}, {m_caret_.active.line, delete_end}};
      auto result = replaceTextInternal(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    } else if (m_caret_.active.line > 0) {
      size_t prev_line = m_caret_.active.line - 1;
      uint32_t prev_cols = m_document_->getLineColumns(prev_line);
      TextRange del_range = {{prev_line, prev_cols}, {m_caret_.active.line, 0}};
      auto result = replaceTextInternal(del_range, "");
      LOGD("EditorCore::backspace, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    }
    return {};
  }

  TextEditResult EditorCore::deleteForwardInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      auto result = replaceTextInternal(range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    }

    uint32_t line_cols = m_document_->getLineColumns(m_caret_.active.line);
    if (m_caret_.active.column < line_cols) {
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
      size_t col = m_caret_.active.column;
      const size_t cluster_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(line_text, col);
      const size_t cluster_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(line_text, col);
      const bool cursor_inside_cluster = (cluster_start < col && cluster_end > col);
      const size_t delete_start = cursor_inside_cluster ? cluster_start : col;
      const size_t delete_end = cursor_inside_cluster
          ? cluster_end
          : UnicodeUtil::nextGraphemeBoundaryColumn(line_text, col);
      TextRange del_range = {{m_caret_.active.line, delete_start}, {m_caret_.active.line, delete_end}};
      auto result = replaceTextInternal(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    } else if (m_caret_.active.line + 1 < m_document_->getLineCount()) {
      TextRange del_range = {{m_caret_.active.line, line_cols}, {m_caret_.active.line + 1, 0}};
      auto result = replaceTextInternal(del_range, "");
      LOGD("EditorCore::deleteForward, cursor = %s", m_caret_.active.dump().c_str());
      return result;
    }
    return {};
  }

  TextEditResult EditorCore::moveLineUpInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.active.line;
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

    const CaretState caret_before = m_caret_;
    cancelLinkedEditingInternal();
    auto result = applyEdit(full_range, new_text, false);
    if (result.contentChanged()) {
      CaretState caret_after = caret_before;
      caret_after.anchor.line = caret_after.anchor.line > 0 ? caret_after.anchor.line - 1 : 0;
      caret_after.active.line = caret_after.active.line > 0 ? caret_after.active.line - 1 : 0;
      restoreCaretState(caret_after);
      result.cursor_after = m_caret_.active;
      recordHistory(result.changes, caret_before, m_caret_);
    }
    ensureCursorVisible();
    if (result.contentChanged()) {
      result.change_kind = TextChangeKind::MOVE;
    }
    return result;
  }

  TextEditResult EditorCore::moveLineDownInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.active.line;
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

    const CaretState caret_before = m_caret_;
    cancelLinkedEditingInternal();
    auto result = applyEdit(full_range, new_text, false);
    if (result.contentChanged()) {
      CaretState caret_after = caret_before;
      ++caret_after.anchor.line;
      ++caret_after.active.line;
      restoreCaretState(caret_after);
      result.cursor_after = m_caret_.active;
      recordHistory(result.changes, caret_before, m_caret_);
    }
    ensureCursorVisible();
    if (result.contentChanged()) {
      result.change_kind = TextChangeKind::MOVE;
    }
    return result;
  }

  TextEditResult EditorCore::copyLineUpInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.active.line;
    }

    U8String block_text;
    for (size_t i = first_line; i <= last_line; ++i) {
      block_text += m_document_->getU8Text({{i, 0}, {i, m_document_->getLineColumns(i)}});
      if (i < last_line) block_text += "\n";
    }

    // Insert copied line block + newline at the start of first_line
    TextPosition insert_pos = {first_line, 0};
    U8String insert_text = block_text + "\n";

    cancelLinkedEditingInternal();
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // Keep cursor at original logical position (inserted text already shifted it down correctly)
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::copyLineDownInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.active.line;
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

    cancelLinkedEditingInternal();
    auto result = applyEdit({insert_pos, insert_pos}, insert_text);

    // applyEdit moves cursor to the end of inserted text (end of copied block), which is what we want
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::deleteLineInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t first_line, last_line;
    if (hasSelection()) {
      TextRange sel = m_caret_.normalizedSelection();
      first_line = sel.start.line;
      last_line = sel.end.column > 0 ? sel.end.line : (sel.end.line > sel.start.line ? sel.end.line - 1 : sel.end.line);
    } else {
      first_line = last_line = m_caret_.active.line;
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

    if (!del_range.isCollapsed()) {
      cancelLinkedEditingInternal();
    }
    auto result = applyEdit(del_range, "");
    return result;
  }

  TextEditResult EditorCore::insertLineAboveInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t line = m_caret_.active.line;
    TextPosition insert_pos = {line, 0};

    const CaretState caret_before = m_caret_;
    cancelLinkedEditingInternal();
    auto result = applyEdit({insert_pos, insert_pos}, "\n", false);

    // Keep cursor on the newly inserted empty line
    if (result.contentChanged()) {
      setCursorPositionInternal({line, 0});
      clearSelection();
      result.cursor_after = m_caret_.active;
      recordHistory(result.changes, caret_before, m_caret_);
    }
    ensureCursorVisible();
    return result;
  }

  TextEditResult EditorCore::insertLineBelowInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    size_t line = m_caret_.active.line;
    uint32_t line_cols = m_document_->getLineColumns(line);
    TextPosition insert_pos = {line, line_cols};

    cancelLinkedEditingInternal();
    auto result = applyEdit({insert_pos, insert_pos}, "\n");
    // applyEdit has already moved cursor to the start of the new line
    return result;
  }

  TextEditResult EditorCore::undoInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    TextEditResult resolution;
    if (hasPreedit()) {
      const bool owns_text = ImeProjection::ownsCompositionText(*getCompositionState());
      resolution = cancelPreedit();
      resolution.markHandled();
      if (owns_text) {
        return resolution;
      }
    }

    // Exit linked editing mode when undoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const HistoryEntry* entry = m_undo_manager_->undo();
    if (entry == nullptr) return resolution;

    TextEditResult edit_result = applyEditBatch(entry->undo_replacements, false);
    edit_result.change_kind = TextChangeKind::UNDO;
    edit_result.cursor_before = entry->caret_after.active;
    restoreCaretState(entry->caret_before);
    edit_result.cursor_after = m_caret_.active;
    ensureCursorVisible();
    LOGD("EditorCore::undo, cursor = %s", m_caret_.active.dump().c_str());
    appendTextEditResult(resolution, std::move(edit_result));
    return resolution;
  }

  TextEditResult EditorCore::redoInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    TextEditResult resolution;
    if (hasPreedit()) {
      const bool owns_text = ImeProjection::ownsCompositionText(*getCompositionState());
      resolution = cancelPreedit();
      resolution.markHandled();
      if (owns_text) {
        return resolution;
      }
    }

    // Exit linked editing mode when redoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const HistoryEntry* entry = m_undo_manager_->redo();
    if (entry == nullptr) return resolution;

    TextEditResult edit_result = applyEditBatch(entry->redo_replacements, false);
    edit_result.change_kind = TextChangeKind::REDO;
    edit_result.cursor_before = entry->caret_before.active;
    restoreCaretState(entry->caret_after);
    edit_result.cursor_after = m_caret_.active;
    ensureCursorVisible();
    LOGD("EditorCore::redo, cursor = %s", m_caret_.active.dump().c_str());
    appendTextEditResult(resolution, std::move(edit_result));
    return resolution;
  }

  TextEditResult EditorCore::finishCompositionForAction() {
    if (!hasPreedit()) {
      return {};
    }
    TextEditResult result = finishPreedit();
    result.markHandled();
    return result;
  }

  void EditorCore::appendTextEditResult(TextEditResult& target, TextEditResult&& source) {
    target.handled = target.handled || source.handled;
    target.editing_content_changed = target.editing_content_changed
        || source.editing_content_changed;
    target.mergeChangeKind(source.change_kind);
    if (!source.changes.empty()) {
      target.changes.insert(target.changes.end(),
                            std::make_move_iterator(source.changes.begin()),
                            std::make_move_iterator(source.changes.end()));
    }
    target.cursor_after = source.cursor_after;
  }

  TextEditResult EditorCore::insertSnippetInternal(const U8String& snippet_template) {
    if (m_document_ == nullptr || snippet_template.empty() || m_settings_.read_only) return {};

    // Exit existing linked editing session
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    // Determine insertion position
    TextPosition insert_pos = m_caret_.active;
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
      m_linked_editing_session_ = makeUnique<LinkedEditingSession>(std::move(parse_result.model));
      activateCurrentTabStop();
    }

    LOGD("EditorCore::insertSnippet, cursor = %s", m_caret_.active.dump().c_str());
    return edit_result;
  }

  void EditorCore::startLinkedEditingInternal(LinkedEditingModel&& model) {
    if (m_document_ == nullptr || m_settings_.read_only) return;
    if (model.groups.empty()) return;

    // Exit existing linked editing session
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    m_linked_editing_session_ = makeUnique<LinkedEditingSession>(std::move(model));
    activateCurrentTabStop();

    LOGD("EditorCore::startLinkedEditing, cursor = %s", m_caret_.active.dump().c_str());
  }

  bool EditorCore::linkedEditingNextTabStopInternal() {
    if (!isInLinkedEditing()) return false;
    bool has_next = m_linked_editing_session_->nextTabStop();
    if (has_next) {
      activateCurrentTabStop();
    } else {
      // At the end: finish session and move cursor to $0
      finishLinkedEditingInternal();
    }
    return has_next;
  }

  bool EditorCore::linkedEditingPrevTabStopInternal() {
    if (!isInLinkedEditing()) return false;
    bool has_prev = m_linked_editing_session_->prevTabStop();
    if (has_prev) {
      activateCurrentTabStop();
    }
    return has_prev;
  }

  void EditorCore::cancelLinkedEditingInternal() {
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }
  }

  void EditorCore::finishLinkedEditingInternal() {
    if (!m_linked_editing_session_) return;
    // Get final cursor position for $0 before cancel
    TextPosition final_pos = m_linked_editing_session_->finalCursorPosition();
    m_linked_editing_session_->cancel();
    m_linked_editing_session_.reset();
    setCursorPosition(final_pos);
    clearSelection();
    ensureCursorVisible();
  }

  bool EditorCore::hasValidLinkedEditingGroup() const {
    if (!isInLinkedEditing()) return false;
    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    if (group == nullptr || group->ranges.empty()) return false;

    for (size_t index = 0; index < group->ranges.size(); ++index) {
      const TextRange& range = group->ranges[index];
      if (range.end < range.start) return false;
      for (size_t previous = 0; previous < index; ++previous) {
        const TextRange& other = group->ranges[previous];
        const bool collapsed_collision = range.isCollapsed()
            ? other.start <= range.start && range.start <= other.end
            : other.isCollapsed() && range.start <= other.start && other.start <= range.end;
        if (range.overlaps(other) || collapsed_collision) {
          return false;
        }
      }
    }
    return true;
  }

  std::optional<Vector<DocumentReplacement>> EditorCore::planLinkedEdit(
      const TextRange& range, const U8String& text) const {
    if (!hasValidLinkedEditingGroup() || m_document_ == nullptr || range.end < range.start) return std::nullopt;
    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    const size_t line_count = m_document_->getLineCount();
    for (const TextRange& group_range : group->ranges) {
      if (group_range.start.line >= line_count || group_range.end.line >= line_count) return std::nullopt;
      const U16String& start_line = m_document_->getLineU16TextRef(group_range.start.line);
      const U16String& end_line = group_range.start.line == group_range.end.line
          ? start_line
          : m_document_->getLineU16TextRef(group_range.end.line);
      if (group_range.start.column > start_line.size() || group_range.end.column > end_line.size()
          || !UnicodeUtil::isCodePointBoundary(start_line, group_range.start.column)
          || !UnicodeUtil::isCodePointBoundary(end_line, group_range.end.column)) {
        return std::nullopt;
      }
    }
    const TextRange& primary = group->ranges[0];
    if (range.start < primary.start || primary.end < range.end) return std::nullopt;

    const U8String final_text = m_document_->getU8Text({primary.start, range.start})
        + text
        + m_document_->getU8Text({range.end, primary.end});
    const Vector<std::pair<TextRange, U8String>> edits = m_linked_editing_session_->computeLinkedEdits(final_text);
    Vector<DocumentReplacement> replacements;
    replacements.reserve(edits.size());
    for (const auto& [edit_range, edit_text] : edits) {
      if (m_document_->getU8Text(edit_range) != edit_text) {
        replacements.push_back({edit_range, edit_text});
      }
    }
    return replacements;
  }

  TextEditResult EditorCore::applyLinkedEditWithResult(
      const TextRange& range, const U8String& text) {
    TextEditResult result;
    if (!isInLinkedEditing() || m_document_ == nullptr) return result;

    const TabStopGroup* group = m_linked_editing_session_->currentGroup();
    if (group == nullptr || group->ranges.empty()) return result;
    const std::optional<Vector<DocumentReplacement>> plan = planLinkedEdit(range, text);
    if (!plan.has_value()) return result;
    const size_t caret_offset = StrUtil::utf16Length(
        m_document_->getU8Text({group->ranges[0].start, range.start}) + text);

    const CaretState caret_before = m_caret_;
    if (!plan->empty()) {
      result = applyEditBatch(*plan);
      if (!result.contentChanged()) return {};

      for (const DocumentReplacement& replacement : *plan) {
        TextPosition new_end = calcPositionAfterInsert(replacement.range.start, replacement.text);
        m_linked_editing_session_->adjustRangesForEdit(replacement.range, new_end);
      }
    }

    group = m_linked_editing_session_->currentGroup();
    if (group && !group->ranges.empty()) {
      const size_t primary_start = m_document_->getCharIndexFromPosition(group->ranges[0].start);
      setCursorPositionInternal(m_document_->getPositionFromCharIndex(primary_start + caret_offset));
      clearSelection();
    }

    result.markHandled(range.isCollapsed()
                       ? TextChangeKind::INSERTION
                       : (text.empty() ? TextChangeKind::DELETION : TextChangeKind::REPLACEMENT));
    result.cursor_before = caret_before.active;
    result.cursor_after = m_caret_.active;
    if (!result.changes.empty()) {
      recordHistory(result.changes, caret_before, m_caret_);
    }
    ensureCursorVisible();
    return result;
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

  TextPosition EditorCore::clampDocumentPosition(const TextPosition& position, bool prefer_right,
                                                 bool line_overflow_to_end) const {
    if (m_document_ == nullptr) {
      return position;
    }
    const size_t line_count = m_document_->getLineCount();
    if (line_count == 0) {
      return {};
    }

    TextPosition safe_position = position;
    if (safe_position.line >= line_count) {
      safe_position.line = line_count - 1;
      if (line_overflow_to_end) {
        safe_position.column = m_document_->getLineColumns(safe_position.line);
      }
    }

    const U16String& line_text = m_document_->getLineU16TextRef(safe_position.line);
    const size_t clamped_column = std::min<size_t>(safe_position.column, line_text.length());
    safe_position.column = prefer_right
                           ? UnicodeUtil::clampColumnToGraphemeBoundaryRight(line_text, clamped_column)
                           : UnicodeUtil::clampColumnToGraphemeBoundaryLeft(line_text, clamped_column);
    return safe_position;
  }

  TextRange EditorCore::clampDocumentRange(const TextRange& range, bool collapse_point_range,
                                           bool line_overflow_to_end) const {
    if (m_document_ == nullptr) {
      return range;
    }

    TextRange safe_range = range;
    if (collapse_point_range && range.start == range.end) {
      safe_range.start = clampDocumentPosition(safe_range.start, false, line_overflow_to_end);
      safe_range.end = safe_range.start;
      return safe_range;
    }

    safe_range.start = clampDocumentPosition(safe_range.start, false, line_overflow_to_end);
    safe_range.end = clampDocumentPosition(safe_range.end, true, line_overflow_to_end);
    return safe_range;
  }

  void EditorCore::setCursorPositionInternal(const TextPosition& position, CaretAffinity affinity,
                                             bool preserve_preferred_cursor_x) {
    const bool had_selection = m_caret_.hasSelection();
    if (!preserve_preferred_cursor_x) {
      m_has_preferred_cursor_x_ = false;
    }
    m_caret_.active = position;
    m_caret_.active_affinity = affinity;
    if (m_document_ != nullptr) {
      size_t line_count = m_document_->getLineCount();
      if (line_count == 0) {
        m_caret_.active = {};
        if (!had_selection) {
          m_caret_.anchor = m_caret_.active;
        }
        return;
      }
      if (m_caret_.active.line >= line_count) {
        m_caret_.active.line = line_count > 0 ? line_count - 1 : 0;
      }
      const U16String& current_line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
      m_caret_.active.column = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
          current_line_text,
          std::min<size_t>(m_caret_.active.column, current_line_text.length()));

      const auto& lines = m_document_->getLogicalLines();
      if (m_caret_.active.line < lines.size() && lines[m_caret_.active.line].is_fold_hidden) {
        const bool projected_tail = m_text_layout_ != nullptr
            && m_text_layout_->isFoldTailProjectedPosition(m_caret_.active, true);
        if (!projected_tail) {
          const FoldRegion* fr = m_decorations_->getFoldRegionForLine(m_caret_.active.line);
          if (fr != nullptr) {
            m_caret_.active.line = fr->start_line;
            m_caret_.active.column = m_document_->getLineColumns(fr->start_line);
          }
        }
      }
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.active.line);
      m_caret_.active.column = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
          line_text,
          std::min<size_t>(m_caret_.active.column, line_text.length()));
    }
    // A collapsed caret has no independent anchor; moving it must move both endpoints.
    if (!had_selection) {
      m_caret_.anchor = m_caret_.active;
    }
  }

  void EditorCore::setSelectionInternal(const TextRange& range, CaretAffinity affinity,
                                        bool preserve_preferred_cursor_x) {
    if (!preserve_preferred_cursor_x) {
      m_has_preferred_cursor_x_ = false;
    }
    TextRange safe_range = clampDocumentRange(range, true, false);
    m_caret_.setSelection(safe_range, affinity);
  }

  void EditorCore::moveCursorTo(const TextPosition& new_pos, bool extend_selection, CaretAffinity affinity,
                                bool preserve_preferred_cursor_x) {
    if (extend_selection) {
      const TextPosition anchor = hasSelection() ? m_caret_.anchor : m_caret_.active;
      setSelectionInternal({anchor, new_pos}, affinity, preserve_preferred_cursor_x);
    } else {
      setCursorPositionInternal(new_pos, affinity, preserve_preferred_cursor_x);
      m_caret_.clearSelection();
    }
    ensureCursorVisible();
  }

  void EditorCore::restoreCaretState(const CaretState& caret) {
    CaretState restored = caret;
    restored.anchor = clampDocumentPosition(restored.anchor, false, false);
    restored.active = clampDocumentPosition(restored.active, false, false);
    m_caret_ = restored;
    m_has_preferred_cursor_x_ = false;
  }

  bool EditorCore::hasDistinctCaretAffinities(const TextPosition& position) {
    if (m_text_layout_ == nullptr) {
      return false;
    }
    const PointF upstream = m_text_layout_->getPositionScreenCoord(position, CaretAffinity::UPSTREAM);
    const PointF downstream = m_text_layout_->getPositionScreenCoord(position, CaretAffinity::DOWNSTREAM);
    return std::abs(upstream.x - downstream.x) > 0.01f
        || std::abs(upstream.y - downstream.y) > 0.01f;
  }

  size_t EditorCore::documentUtf16Length() const {
    if (m_document_ == nullptr || m_document_->getLineCount() == 0) {
      return 0;
    }
    const size_t last_line = m_document_->getLineCount() - 1;
    return m_document_->getCharIndexFromPosition({last_line, m_document_->getLineColumns(last_line)});
  }

  TextRange EditorCore::textRangeFromUtf16Offsets(size_t start_offset, size_t end_offset) const {
    if (m_document_ == nullptr) {
      return {};
    }
    const size_t document_length = documentUtf16Length();
    start_offset = std::min(start_offset, document_length);
    end_offset = std::min(end_offset, document_length);
    if (start_offset > end_offset) {
      std::swap(start_offset, end_offset);
    }
    return {
      m_document_->getPositionFromCharIndex(start_offset),
      m_document_->getPositionFromCharIndex(end_offset)
    };
  }

  SearchSnapshot EditorCore::buildSearchSnapshot(const SearchRequest& request, uint64_t generation) const {
    SearchSnapshot snapshot;
    snapshot.request = request;
    snapshot.state.status = SearchStatus::SEARCHING;
    snapshot.state.pattern = request.pattern;
    snapshot.state.options = request.options;
    snapshot.state.generation = generation;
    snapshot.cursor_position = m_caret_.active;

    if (m_document_ == nullptr || m_document_->getLineCount() == 0) {
      snapshot.state.status = SearchStatus::INACTIVE;
      return snapshot;
    }

    const size_t line_count = m_document_->getLineCount();
    snapshot.line_start_offsets.reserve(line_count);
    snapshot.line_lengths.reserve(line_count);
    for (size_t line = 0; line < line_count; ++line) {
      snapshot.line_start_offsets.push_back(snapshot.text.size());
      U16String line_text = m_document_->getLineU16Text(line);
      snapshot.line_lengths.push_back(line_text.size());
      snapshot.text += line_text;
      if (line + 1 < line_count) {
        snapshot.text.push_back(CHAR16('\n'));
      }
    }
    return snapshot;
  }

  void EditorCore::publishSearchState(const SearchState& state) {
    SharedPtr<const SearchState> next = makeShared<const SearchState>(state);
    while (state.generation == m_search_generation_->load()) {
      SharedPtr<const SearchState> current = std::atomic_load(&m_published_search_state_);
      if (current != nullptr && current->generation > state.generation) {
        return;
      }
      if (std::atomic_compare_exchange_weak(&m_published_search_state_, &current, next)) {
        return;
      }
    }
  }

  void EditorCore::publishPendingSearchResult(SearchResult&& result) {
    if (result.state.generation != m_search_generation_->load()) {
      return;
    }
    SharedPtr<SearchResult> next = makeShared<SearchResult>(std::move(result));
    while (next->state.generation == m_search_generation_->load()) {
      SharedPtr<SearchResult> current = std::atomic_load(&m_pending_search_result_);
      if (current != nullptr && current->state.generation > next->state.generation) {
        return;
      }
      if (std::atomic_compare_exchange_weak(&m_pending_search_result_, &current, next)) {
        return;
      }
    }
  }

  void EditorCore::clearPendingSearchResult() {
    SharedPtr<SearchResult> empty;
    std::atomic_store(&m_pending_search_result_, empty);
  }

  void EditorCore::drainPendingSearchResult() {
    SharedPtr<SearchResult> empty;
    SharedPtr<SearchResult> pending = std::atomic_exchange(&m_pending_search_result_, empty);
    if (pending == nullptr) {
      return;
    }
    if (pending->state.generation != m_search_generation_->load()) {
      return;
    }
    installSearchResult(std::move(*pending));
  }

  void EditorCore::installSearchResult(SearchResult&& result) {
    chooseCurrentSearchMatch(result);
    m_search_state_ = std::move(result.state);
    m_search_matches_ = std::move(result.matches);
    if (m_search_state_.current_index >= 0
        && static_cast<size_t>(m_search_state_.current_index) < m_search_matches_.size()) {
      m_search_state_.has_current_match = true;
      m_search_state_.current_range = m_search_matches_[static_cast<size_t>(m_search_state_.current_index)].range;
    } else {
      m_search_state_.current_index = -1;
      m_search_state_.has_current_match = false;
      m_search_state_.current_range = {};
    }
    m_search_state_.match_count = static_cast<uint32_t>(m_search_matches_.size());
    rebuildSearchLineIndex();
    publishSearchState(m_search_state_);
  }

  void EditorCore::rebuildSearchLineIndex() {
    m_search_match_indices_by_line_.clear();
    if (m_document_ == nullptr || m_search_matches_.empty()) {
      return;
    }

    m_search_match_indices_by_line_.resize(m_document_->getLineCount());
    for (size_t index = 0; index < m_search_matches_.size(); ++index) {
      const SearchMatch& match = m_search_matches_[index];
      if (match.range.start.line >= m_search_match_indices_by_line_.size()) continue;
      const size_t end_line = std::min(match.range.end.line, m_search_match_indices_by_line_.size() - 1);
      for (size_t line = match.range.start.line; line <= end_line; ++line) {
        m_search_match_indices_by_line_[line].push_back(static_cast<uint32_t>(index));
      }
    }
  }

  void EditorCore::markSearchStaleForDocumentChange() {
    if (m_search_state_.status == SearchStatus::INACTIVE) {
      return;
    }
    if (m_search_state_.status != SearchStatus::FAILED) {
      m_search_state_.status = SearchStatus::STALE;
    }
    m_search_state_.generation = m_search_generation_->load();
    m_search_state_.match_count = 0;
    m_search_state_.current_index = -1;
    m_search_state_.has_current_match = false;
    m_search_state_.current_range = {};
    m_search_matches_.clear();
    m_search_match_indices_by_line_.clear();
    publishSearchState(m_search_state_);
  }

  void EditorCore::noteDocumentContentChanged() {
    const uint64_t generation = m_search_generation_->fetch_add(1) + 1;
    m_decorations_->clearDocumentHighlights();
    clearPendingSearchResult();
    if (m_search_state_.status == SearchStatus::INACTIVE) {
      SharedPtr<const SearchState> published_state = std::atomic_load(&m_published_search_state_);
      if (published_state != nullptr && published_state->status != SearchStatus::INACTIVE) {
        m_search_state_ = *published_state;
      }
    }
    if (m_search_state_.status == SearchStatus::INACTIVE) {
      m_search_state_.generation = generation;
      publishSearchState(m_search_state_);
      return;
    }
    markSearchStaleForDocumentChange();
  }

  void EditorCore::chooseCurrentSearchMatch(SearchResult& result) const {
    chooseCurrentSearchMatch(result, m_caret_.active);
  }

  void EditorCore::chooseCurrentSearchMatch(SearchResult& result, const TextPosition& position) const {
    if (result.matches.empty()) {
      result.state.current_index = -1;
      result.state.has_current_match = false;
      result.state.current_range = {};
      return;
    }

    size_t current_index = result.matches.size();
    for (size_t i = 0; i < result.matches.size(); ++i) {
      if (!(result.matches[i].range.start < position)) {
        current_index = i;
        break;
      }
    }
    if (current_index == result.matches.size() && result.state.options.wrap_around) {
      current_index = 0;
    }

    result.state.current_index = current_index < result.matches.size()
        ? static_cast<int32_t>(current_index)
        : -1;
    result.state.has_current_match = current_index < result.matches.size();
    result.state.current_range = result.state.has_current_match
        ? result.matches[current_index].range
        : TextRange {};
  }

  size_t EditorCore::firstSearchMatchAtOrAfter(const TextPosition& position) const {
    for (size_t index = 0; index < m_search_matches_.size(); ++index) {
      if (!(m_search_matches_[index].range.start < position)) {
        return index;
      }
    }
    return m_search_matches_.size();
  }

  void EditorCore::selectSearchMatch(size_t index) {
    if (index >= m_search_matches_.size()) {
      return;
    }
    m_search_state_.current_index = static_cast<int32_t>(index);
    m_search_state_.has_current_match = true;
    m_search_state_.current_range = m_search_matches_[index].range;
    setSelectionInternal(m_search_matches_[index].range);
    ensureCursorVisible();
    publishSearchState(m_search_state_);
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

  TextEditResult EditorCore::applyEditBatch(const Vector<DocumentReplacement>& replacements, bool update_fold_state) {
    TextEditResult result;
    if (m_document_ == nullptr || replacements.empty()) return result;

    struct PendingReplacement {
      DocumentReplacement replacement;
      bool keep_fold_collapsed {false};
      size_t fold_tail_owner_line {0};
    };

    Vector<PendingReplacement> pending;
    pending.reserve(replacements.size());
    const size_t line_count = m_document_->getLineCount();

    for (const DocumentReplacement& replacement : replacements) {
      TextRange safe_range = clampDocumentRange(replacement.range, true, false).normalized();
      if (safe_range.isCollapsed() && replacement.text.empty()) continue;

      PendingReplacement item;
      item.replacement = {safe_range, replacement.text};
      item.fold_tail_owner_line = line_count;

      const bool single_line_text = replacement.text.find('\n') == U8String::npos
                                 && replacement.text.find('\r') == U8String::npos;
      if (update_fold_state
          && single_line_text
          && safe_range.start.line == safe_range.end.line
          && m_text_layout_ != nullptr) {
        size_t start_owner_line = line_count;
        size_t end_owner_line = line_count;
        const bool start_projected =
            m_text_layout_->isFoldTailProjectedPosition(safe_range.start, true, &start_owner_line);
        const bool end_projected =
            m_text_layout_->isFoldTailProjectedPosition(safe_range.end, true, &end_owner_line);
        item.keep_fold_collapsed = start_projected
                                && end_projected
                                && start_owner_line == end_owner_line;
        if (item.keep_fold_collapsed) {
          item.fold_tail_owner_line = start_owner_line;
        }
      }

      if (update_fold_state && !item.keep_fold_collapsed) {
        autoUnfoldForEdit(safe_range);
      }
      pending.push_back(std::move(item));
    }

    if (pending.empty()) return result;

    std::sort(pending.begin(), pending.end(),
              [](const PendingReplacement& lhs, const PendingReplacement& rhs) {
                if (lhs.replacement.range.start != rhs.replacement.range.start) {
                  return lhs.replacement.range.start < rhs.replacement.range.start;
                }
                return lhs.replacement.range.end < rhs.replacement.range.end;
              });

    Vector<DocumentReplacement> document_replacements;
    document_replacements.reserve(pending.size());
    result.changes.reserve(pending.size());
    size_t first_affected_line = line_count;

    for (const PendingReplacement& item : pending) {
      const TextRange& range = item.replacement.range;
      TextChange change;
      change.range = range;
      if (!range.isCollapsed()) {
        change.old_text = m_document_->getU8Text(range);
      }
      change.new_text = item.replacement.text;
      result.changes.push_back(std::move(change));
      document_replacements.push_back(item.replacement);
      first_affected_line = std::min(first_affected_line, range.start.line);

      if (range.isCollapsed()) {
        result.markHandled(TextChangeKind::INSERTION);
      } else if (item.replacement.text.empty()) {
        result.markHandled(TextChangeKind::DELETION);
      } else {
        result.markHandled(TextChangeKind::REPLACEMENT);
      }
    }

    m_document_->replaceU8TextBatch(document_replacements);
    noteDocumentContentChanged();

    for (auto it = pending.rbegin(); it != pending.rend(); ++it) {
      const TextPosition new_end = calcPositionAfterInsert(
          it->replacement.range.start, it->replacement.text);
      m_decorations_->adjustForEdit(it->replacement.range, new_end);
      if (it->keep_fold_collapsed) {
        first_affected_line = std::min(first_affected_line, it->fold_tail_owner_line);
      }
    }

    if (m_text_layout_ != nullptr) {
      m_text_layout_->invalidateContentMetrics(first_affected_line);
    }
    return result;
  }

  void EditorCore::recordHistory(const Vector<TextChange>& changes, const CaretState& caret_before,
                                 const CaretState& caret_after, bool allows_merge) {
    if (changes.empty()) return;

    HistoryEntry entry;
    entry.redo_replacements.reserve(changes.size());
    entry.undo_replacements.reserve(changes.size());
    bool has_previous_change = false;
    TextPosition previous_source_end;
    TextPosition previous_target_end;

    for (const TextChange& change : changes) {
      TextRange current_range = change.range;
      if (has_previous_change) {
        const auto transform_after_previous = [&](const TextPosition& position) {
          if (position.line == previous_source_end.line) {
            return TextPosition {
                previous_target_end.line,
                previous_target_end.column + position.column - previous_source_end.column
            };
          }
          return TextPosition {
              previous_target_end.line + position.line - previous_source_end.line,
              position.column
          };
        };
        current_range.start = transform_after_previous(current_range.start);
        current_range.end = transform_after_previous(current_range.end);
      }

      const TextPosition current_new_end = calcPositionAfterInsert(
          current_range.start, change.new_text);
      entry.redo_replacements.push_back({change.range, change.new_text});
      entry.undo_replacements.push_back({{current_range.start, current_new_end}, change.old_text});
      has_previous_change = true;
      previous_source_end = change.range.end;
      previous_target_end = current_new_end;
    }

    entry.caret_before = caret_before;
    entry.caret_after = caret_after;
    entry.timestamp = std::chrono::steady_clock::now();
    entry.allows_merge = allows_merge;
    m_undo_manager_->pushEntry(std::move(entry));
  }

  TextEditResult EditorCore::applyEdit(const TextRange& range, const U8String& new_text, bool record_undo) {
    const CaretState caret_before = m_caret_;
    TextEditResult edit_result = applyEditBatch({{{range.start, range.end}, new_text}});
    if (!edit_result.contentChanged()) return edit_result;

    edit_result.cursor_before = caret_before.active;
    const TextChange& change = edit_result.changes.front();
    const TextPosition new_cursor = change.new_text.empty()
                                      ? change.range.start
                                      : calcPositionAfterInsert(change.range.start, change.new_text);

    setCursorPositionInternal(new_cursor);
    clearSelection();
    edit_result.cursor_after = m_caret_.active;

    if (record_undo) {
      recordHistory(edit_result.changes, caret_before, m_caret_, true);
    }

    ensureCursorVisible();
    return edit_result;
  }

#pragma endregion

#pragma region [Navigation & Decorations Internals]

  bool EditorCore::foldAtInternal(size_t line) {
    bool result = m_decorations_->foldAt(line);
    if (result) syncFoldState();
    return result;
  }

  bool EditorCore::unfoldAtInternal(size_t line) {
    bool result = m_decorations_->unfoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  bool EditorCore::toggleFoldAtInternal(size_t line) {
    bool result = m_decorations_->toggleFoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  void EditorCore::foldAllInternal() {
    m_decorations_->foldAll();
    syncFoldState();
  }

  void EditorCore::unfoldAllInternal() {
    m_decorations_->unfoldAll();
    syncFoldState();
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
    const std::optional<CompositionState>& composition = getCompositionState();
    const bool has_projection = composition.has_value()
        && ImeProjection::hasNonIdentityProjection(*m_document_, *composition);
    TextPosition baseline_end;
    int64_t composition_line_delta = 0;
    if (has_projection) {
      baseline_end = ImeProjection::baselineRange(*composition).end;
      composition_line_delta = static_cast<int64_t>(composition->current_range.end.line)
          - static_cast<int64_t>(baseline_end.line);
    }

    // Start line of each fold region needs relayout (fold state changes affect FOLD_PLACEHOLDER generation)
    for (const auto& fr : m_decorations_->getFoldRegions()) {
      size_t start_line = fr.start_line;
      size_t end_line = fr.end_line;
      if (has_projection && end_line >= composition->current_range.start.line) {
        if (start_line > baseline_end.line) {
          start_line = TextPosition {start_line, 0}.withLineDelta(composition_line_delta).line;
          end_line = TextPosition {end_line, 0}.withLineDelta(composition_line_delta).line;
        } else {
          continue;
        }
      }
      if (start_line < lines.size()) {
        lines[start_line].is_layout_dirty = true;
      }
      if (!fr.collapsed) continue;
      for (size_t i = start_line + 1; i <= end_line && i < lines.size(); ++i) {
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

  void EditorCore::placeCursorAt(const PointF& screen_point) {
    const CaretHit hit = m_text_layout_->hitTestPointer(screen_point);
    setCursorPosition(hit.position);
    m_caret_.active_affinity = hit.affinity;
    clearSelection();
    m_has_preferred_cursor_x_ = false;
    LOGD("EditorCore::placeCursorAt, pos = %s", hit.position.dump().c_str());
  }

  void EditorCore::selectWordAt(const PointF& screen_point) {
    if (m_document_ == nullptr) return;
    TextPosition pos = m_text_layout_->hitTestPointer(screen_point).position;

    size_t line = pos.line;
    const U16String& line_text = m_document_->getLineU16TextRef(line);
    if (line_text.empty()) {
      setCursorPosition(pos);
      clearSelection();
      return;
    }

    size_t anchor = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
        line_text,
        std::min(pos.column, line_text.length()));

    if (anchor >= line_text.length()) {
      anchor = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, line_text.length());
    } else if (anchor > 0) {
      const float boundary_x = m_text_layout_->getPositionScreenCoord({line, anchor}).x;
      if (screen_point.x < boundary_x) {
        anchor = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, anchor);
      }
    }

    TextRange range = TextBoundaryUtil::findWordRangeInLine(line, line_text, anchor);
    setSelection(range);
    LOGD("EditorCore::selectWordAt, selection = %s", range.dump().c_str());
  }

#pragma endregion

}
