//
// Created by Scave on 2025/12/1.
//
#include <utf8/utf8.h>
#include <cmath>
#include <algorithm>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "logging.h"
#include "render_style_util.hpp"
#include "text_boundary.hpp"

namespace NS_SWEETEDITOR {
  static uint32_t advanceVisualColumn(U16Char ch, uint32_t visual_col, uint32_t tab_size) {
    if (ch == u'\t') {
      return (visual_col / tab_size + 1) * tab_size;
    }
    return visual_col + 1;
  }

  static uint32_t computeVisualColumn(const U16String& line_text, size_t col, uint32_t tab_size) {
    uint32_t visual_col = 0;
    size_t safe_col = std::min(col, line_text.size());
    for (size_t i = 0; i < safe_col; ++i) {
      visual_col = advanceVisualColumn(line_text[i], visual_col, tab_size);
    }
    return visual_col;
  }

  static bool sameHitTarget(const HitTarget& lhs, const HitTarget& rhs) {
    return lhs.type == rhs.type
           && lhs.line == rhs.line
           && lhs.column == rhs.column
           && lhs.icon_id == rhs.icon_id
           && lhs.color_value == rhs.color_value;
  }

  static bool sameCompositionState(const CompositionState& lhs, const CompositionState& rhs) {
    return lhs.kind == rhs.kind
           && lhs.start_position == rhs.start_position
           && lhs.anchor_range == rhs.anchor_range
           && lhs.original_text == rhs.original_text
           && lhs.preedit_text == rhs.preedit_text
           && lhs.preedit_columns == rhs.preedit_columns;
  }

  static bool imeSyncSnapshotRequestsPlatformUpdate(const ImeSyncSnapshot& snapshot) {
    return snapshot.clear_system_mark
           || snapshot.has_preedit_range
           || snapshot.has_system_mark_range
           || snapshot.context_policy != ImeContextPolicy::NONE;
  }

  static HitTarget toHotInteractiveTarget(const HitTarget& target, KeyModifier modifiers) {
    if (target.type == HitTargetType::CODELENS) {
      return target;
    }
    if (target.type == HitTargetType::LINK
        && hasAnyModifier(modifiers, KeyModifier::CTRL | KeyModifier::META)) {
      return target;
    }
    return {};
  }

  static bool isMousePointerEvent(EventType type) {
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

  static EditorActionResult makeSearchActionResult(bool handled, bool needs_redraw = true) {
    EditorActionResult result;
    result.handled = handled;
    result.source = EditorActionSource::SEARCH;
    result.needs_redraw = needs_redraw;
    result.decoration_changed = needs_redraw;
    return result;
  }

#pragma region [Setup & View State]
  EditorCore::EditorCore(const SharedPtr<TextMeasurer>& measurer, const EditorOptions& options): m_measurer_(measurer), m_options_(options), m_key_resolver_(options.key_chord_timeout_ms), m_composition_controller_(*this) {
    m_decorations_ = makeShared<DecorationManager>();
    m_text_layout_ = makeUnique<TextLayout>(measurer, m_decorations_);
    InteractionContext interaction_context;
    interaction_context.touch_config = options.simpleAsTouchConfig();
    interaction_context.settings = &m_settings_;
    interaction_context.view_state = &m_view_state_;
    interaction_context.viewport = &m_viewport_;
    interaction_context.text_layout = m_text_layout_.get();
    interaction_context.caret = &m_caret_;
    m_interaction_ = makeUnique<EditorInteraction>(interaction_context);
    m_render_composer_ = makeUnique<RenderComposer>(m_text_layout_.get(), m_decorations_.get(), &m_settings_);
    m_undo_manager_ = makeUnique<UndoManager>(options.max_undo_stack_size);
    m_key_resolver_.setKeyMap(KeyMap::createDefault());
    loadDocument(makeShared<LineArrayDocument>(""));
    LOGD("EditorCore::EditorCore(), options = %s", options.dump().c_str());
  }

  EditorActionResult EditorCore::setHandleConfig(const HandleConfig& config) {
    const ActionSnapshot before = captureActionSnapshot();
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
    m_composition_controller_.removePreeditText();
    m_composition_controller_.resetCompositionState();
    m_composition_controller_.clearCandidateCommitWindow();
    invalidateImeInputContext();
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
    EditorActionResult result = finishAction(before, EditorActionSource::SETUP, true, {}, true);
    result.needs_ime_sync = true;
    result.ime_sync = getImeSyncSnapshot();
    return result;
  }

  EditorActionResult EditorCore::setViewport(const Size& viewport) {
    const ActionSnapshot before = captureActionSnapshot();
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
    m_view_state_.scale = scale;
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
    presentation_context.has_selection = m_caret_.has_selection;
    if (m_caret_.has_selection) {
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
    PERF_BEGIN(cursor_sel);
    m_render_composer_->buildCursorModel(model, m_caret_.cursor, m_caret_.has_selection, line_height);
    m_render_composer_->buildDocumentHighlightRangeEffects(model, m_document_.get(), line_height);
    m_render_composer_->buildSearchRangeEffects(model,
                                                m_document_.get(),
                                                m_search_matches_,
                                                m_search_match_indices_by_line_,
                                                m_search_state_.current_index,
                                                line_height);
    m_render_composer_->buildCompositionRangeEffect(model, m_composition_controller_.composition(), line_height);
    m_render_composer_->buildSelectionRangeEffects(model, m_document_.get(), m_caret_, line_height);
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

    m_render_composer_->buildDiagnosticRangeEffects(model, m_document_.get(), line_height);
    m_render_composer_->buildLinkedEditingRangeEffects(model, m_document_.get(), m_linked_editing_session_.get(), line_height);
    m_render_composer_->buildBracketHighlightRangeEffects(model,
                                                          m_document_.get(),
                                                          m_caret_.cursor,
                                                          m_bracket_pairs_,
                                                          m_external_bracket_open_,
                                                          m_external_bracket_close_,
                                                          m_has_external_brackets_,
                                                          line_height);
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

    if (event.type == EventType::MOUSE_DOWN) {
      m_mouse_button_down_ = true;
      clearHoverHitTarget();
    } else if (event.type == EventType::MOUSE_UP) {
      m_mouse_button_down_ = false;
    }

    GestureIntent intent;
    GestureResult result = m_interaction_->handleGestureEvent(event, intent);

    switch (event.type) {
      case EventType::MOUSE_MOVE: {
        const HitTarget hot_target = get_primary_probe().hot_target;
        if (m_mouse_button_down_) {
          if (m_press_hit_target_.type != HitTargetType::NONE
              && !sameHitTarget(hot_target, m_press_hit_target_)) {
            clearPressHitTarget();
          }
        } else {
          m_hover_hit_target_ = hot_target;
        }
        break;
      }
      case EventType::MOUSE_DOWN:
        m_press_hit_target_ = get_primary_probe().hot_target;
        break;
      case EventType::MOUSE_UP:
        clearPressHitTarget();
        break;
      case EventType::TOUCH_DOWN:
        m_press_hit_target_ = get_primary_probe().hot_target;
        break;
      case EventType::TOUCH_MOVE: {
        const HitTarget hot_target = get_primary_probe().hot_target;
        if (m_press_hit_target_.type != HitTargetType::NONE
            && !sameHitTarget(hot_target, m_press_hit_target_)) {
          clearPressHitTarget();
        }
        break;
      }
      case EventType::TOUCH_UP:
      case EventType::TOUCH_CANCEL:
      case EventType::TOUCH_POINTER_DOWN:
        clearPressHitTarget();
        break;
      default:
        break;
    }


    if (intent.cancel_linked_editing) {
      if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
        TextPosition tap_pos = m_text_layout_->hitTestPointer(result.tap_point);
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

    finalizeGestureResult(result);
    return finishGestureAction(before,
                               result,
                               EditorActionSource::GESTURE,
                               event.type,
                               gesture_decoration_changed);
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
    result.handled = result.needs_redraw || result.pointer_cursor_changed;
    return result;
  }

  EditorActionResult EditorCore::tickAnimations() {
    const ActionSnapshot before = captureActionSnapshot();
    GestureResult result = m_interaction_->tickAnimations();
    finalizeGestureResult(result);
    return finishGestureAction(before, result, EditorActionSource::ANIMATION);
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
      m_composition_controller_.cancelPreeditText();
      return make_result(true);
    }

    if (m_linked_editing_session_ && m_linked_editing_session_->isActive()) {
      bool shift = static_cast<uint8_t>(event.modifiers & KeyModifier::SHIFT) != 0;
      if (event.key_code == KeyCode::TAB) {
        if (shift) {
          linkedEditingPrevTabStopInternal();
        } else {
          linkedEditingNextTabStopInternal();
        }
        return make_result(true);
      }
      if (event.key_code == KeyCode::ENTER) {
        finishLinkedEditingInternal();
        return make_result(true);
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

      if (command == static_cast<EditorCommandId>(EditorBuiltinCommand::COPY) ||
        command == static_cast<EditorCommandId>(EditorBuiltinCommand::PASTE) ||
        command == static_cast<EditorCommandId>(EditorBuiltinCommand::CUT) ||
        command == static_cast<EditorCommandId>(EditorBuiltinCommand::TRIGGER_COMPLETION) ||
        command > EDITOR_BUILTIN_COMMAND_MAX) {
        return make_result(true);
      }

      bool handled = true;
      TextEditResult edit_result;
      switch (static_cast<EditorBuiltinCommand>(command)) {
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
          const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
          uint32_t visual_col = computeVisualColumn(line_text, m_caret_.cursor.column, tab_size);
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
        handled = edit_result.contentChanged();
        break;
      case EditorBuiltinCommand::REDO:
        edit_result = redoInternal();
        handled = edit_result.contentChanged();
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
        return make_result(handled, std::move(edit_result));
      }
    }

    if (event.isTextInput()) {
      TextEditResult edit_result = insertTextInternal(event.text);
      LOGD("EditorCore::handleKeyEvent, key_code = %d, handled = %d", (int)event.key_code, 1);
      return make_result(true, std::move(edit_result));
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
    TextEditResult edit_result = insertTextInternal(text);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::replaceText(const TextRange& range, const U8String& new_text) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = replaceTextInternal(range, new_text);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::deleteText(const TextRange& range) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = deleteTextInternal(range);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::applyTextEdits(Vector<TextEdit>&& edits) {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result;
    edit_result.cursor_before = m_caret_.cursor;

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
      if (primary_cursor != m_caret_.cursor || hasSelection()) {
        setCursorPositionInternal(primary_cursor, true);
        clearSelection();
        ensureCursorVisible();
        edit_result.markHandled();
        edit_result.cursor_after = m_caret_.cursor;
        return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
      }
      edit_result.cursor_after = m_caret_.cursor;
      return finishAction(before, EditorActionSource::PROGRAMMATIC, false, std::move(edit_result));
    }

    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
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

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    for (const auto& edit : pending) {
      if (edit.is_no_op) continue;
      TextEditResult item_result = applyEdit(edit.range, edit.new_text);
      if (!item_result.contentChanged()) continue;
      edit_result.markHandled(item_result.change_kind);
      edit_result.changes.insert(edit_result.changes.end(),
                                 item_result.changes.begin(),
                                 item_result.changes.end());
      if (edit.original_index != 0) {
        primary_cursor = edit.range.transformPositionAfterEdit(primary_cursor, edit.new_end);
      }
    }

    if (edit_result.contentChanged()) {
      setCursorPositionInternal(primary_cursor, true);
      clearSelection();
      ensureCursorVisible();
    }
    edit_result.cursor_after = m_caret_.cursor;
    m_undo_manager_->endGroup(m_caret_.cursor);

    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::backspace() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = backspaceInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::deleteForward() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = deleteForwardInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  TextEditResult EditorCore::insertTextInternal(const U8String& text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (text.empty() && !hasSelection()) return {};

    // If preedit is active, cancel it before new input
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
    }

    // Auto-indent: when inserting a newline with KEEP_INDENT enabled, append previous line's leading whitespace
    U8String actual_text = text;
    if (text == "\n" && m_settings_.auto_indent_mode == AutoIndentMode::KEEP_INDENT) {
      size_t current_line = hasSelection() ? m_caret_.normalizedSelection().start.line : m_caret_.cursor.line;
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
        const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
        size_t col = m_caret_.cursor.column;
        char32_t right_char = (col < line_text.size()) ? static_cast<char32_t>(line_text[col]) : 0;

        if (!hasSelection()) {
          for (const auto& pair : m_auto_closing_pairs_) {
            if (input_char == pair.close && right_char == pair.close) {
              const TextPosition cursor_before = m_caret_.cursor;
              m_caret_.cursor.column++;
              m_caret_.clearSelection();
              ensureCursorVisible();
              TextEditResult result;
              result.markHandled();
              result.cursor_before = cursor_before;
              result.cursor_after = m_caret_.cursor;
              return result;
            }
          }
          for (const auto& pair : m_auto_closing_pairs_) {
            if (input_char == pair.open) {
              if (pair.open == pair.close && right_char == pair.close) {
                const TextPosition cursor_before = m_caret_.cursor;
                m_caret_.cursor.column++;
                m_caret_.clearSelection();
                ensureCursorVisible();
                TextEditResult result;
                result.markHandled();
                result.cursor_before = cursor_before;
                result.cursor_after = m_caret_.cursor;
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
                TextRange range = {m_caret_.cursor, m_caret_.cursor};
                auto result = applyEdit(range, pair_text);
                m_caret_.cursor.column = static_cast<uint32_t>(col + 1);
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

  TextEditResult EditorCore::replaceTextInternal(const TextRange& range, const U8String& new_text) {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If preedit is active, cancel it first
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
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

  TextEditResult EditorCore::deleteTextInternal(const TextRange& range) {
    return replaceTextInternal(range, "");
  }

  TextEditResult EditorCore::backspaceInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (hasPreedit()) {
      const CompositionState& composition = getCompositionState();
      if (composition.kind == CompositionKind::PREEDIT_TEXT) {
        if (composition.preedit_text.empty()) {
          m_composition_controller_.cancelPreeditText();
        } else {
          U16String preedit_u16;
          StrUtil::convertUTF8ToUTF16(composition.preedit_text, preedit_u16);
          size_t cursor_column = preedit_u16.length();
          if (cursor_column > 0) {
            size_t prev_col = UnicodeUtil::prevGraphemeBoundaryColumn(preedit_u16, cursor_column);
            preedit_u16.erase(prev_col, cursor_column - prev_col);
            U8String next_text;
            StrUtil::convertUTF16ToUTF8(preedit_u16, next_text);
            if (next_text.empty()) {
              m_composition_controller_.cancelPreeditText();
            } else {
              m_composition_controller_.setPreeditText(next_text);
            }
          } else {
            m_composition_controller_.cancelPreeditText();
          }
        }
        return {};
      } else {
        const TextRange range = composition.anchor_range;
        if (composition.kind == CompositionKind::DOCUMENT_RANGE && m_caret_.cursor == range.end) {
          return m_composition_controller_.deleteBackward(1).edit_result;
        }
        m_composition_controller_.commitPreeditText("", true);
      }
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
          cancelLinkedEditingInternal();
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
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      size_t col = m_caret_.cursor.column;

      if (!m_auto_closing_pairs_.empty() && col > 0 && col < line_text.size()) {
        char32_t left_char = static_cast<char32_t>(line_text[col - 1]);
        char32_t right_char = static_cast<char32_t>(line_text[col]);
        for (const auto& pair : m_auto_closing_pairs_) {
          if (left_char == static_cast<char32_t>(pair.open) && right_char == static_cast<char32_t>(pair.close)) {
            TextRange del_range = {{m_caret_.cursor.line, static_cast<uint32_t>(col - 1)}, {m_caret_.cursor.line, static_cast<uint32_t>(col + 1)}};
            auto result = applyEdit(del_range, "");
            LOGD("EditorCore::backspace(auto-close-pair), cursor = %s", m_caret_.cursor.dump().c_str());
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
          if (entire_line_blank && m_caret_.cursor.line > 0) {
            size_t prev_line = m_caret_.cursor.line - 1;
            uint32_t prev_cols = m_document_->getLineColumns(prev_line);
            TextRange del_range = {{prev_line, prev_cols}, {m_caret_.cursor.line, (uint32_t)line_text.size()}};
            auto result = applyEdit(del_range, "");
            LOGD("EditorCore::backspace, cursor = %s", m_caret_.cursor.dump().c_str());
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
            TextRange del_range = {{m_caret_.cursor.line, (uint32_t)target_col}, {m_caret_.cursor.line, (uint32_t)col}};
            auto result = applyEdit(del_range, "");
            LOGD("EditorCore::backspace, cursor = %s", m_caret_.cursor.dump().c_str());
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
      TextRange del_range = {{m_caret_.cursor.line, delete_start}, {m_caret_.cursor.line, delete_end}};
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

  TextEditResult EditorCore::deleteForwardInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    if (hasPreedit()) {
      const CompositionState& composition = getCompositionState();
      if (composition.kind == CompositionKind::PREEDIT_TEXT) {
        m_composition_controller_.cancelPreeditText();
        return {};
      }
      m_composition_controller_.commitPreeditText("", true);
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
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      size_t col = m_caret_.cursor.column;
      const size_t cluster_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(line_text, col);
      const size_t cluster_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(line_text, col);
      const bool cursor_inside_cluster = (cluster_start < col && cluster_end > col);
      const size_t delete_start = cursor_inside_cluster ? cluster_start : col;
      const size_t delete_end = cursor_inside_cluster
          ? cluster_end
          : UnicodeUtil::nextGraphemeBoundaryColumn(line_text, col);
      TextRange del_range = {{m_caret_.cursor.line, delete_start}, {m_caret_.cursor.line, delete_end}};
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

  TextEditResult EditorCore::deleteCodePointBackward() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit() || isInLinkedEditing()) {
      return backspaceInternal();
    }
    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      return applyEdit(range, "");
    }

    if (m_caret_.cursor.column > 0) {
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      const size_t col = std::min<size_t>(m_caret_.cursor.column, line_text.size());
      const size_t code_point_start = UnicodeUtil::clampColumnToCodePointBoundaryLeft(line_text, col);
      const size_t code_point_end = UnicodeUtil::clampColumnToCodePointBoundaryRight(line_text, col);
      const bool cursor_inside_code_point = code_point_start < col && code_point_end > col;
      const size_t delete_start = cursor_inside_code_point
          ? code_point_start
          : UnicodeUtil::prevCodePointColumn(line_text, col);
      const size_t delete_end = cursor_inside_code_point ? code_point_end : col;
      if (delete_start == delete_end) return {};
      TextRange del_range = {
        {m_caret_.cursor.line, static_cast<uint32_t>(delete_start)},
        {m_caret_.cursor.line, static_cast<uint32_t>(delete_end)}
      };
      return applyEdit(del_range, "");
    }

    if (m_caret_.cursor.line > 0) {
      size_t prev_line = m_caret_.cursor.line - 1;
      uint32_t prev_cols = m_document_->getLineColumns(prev_line);
      TextRange del_range = {{prev_line, prev_cols}, {m_caret_.cursor.line, 0}};
      return applyEdit(del_range, "");
    }
    return {};
  }

  TextEditResult EditorCore::deleteCodePointForward() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit() || isInLinkedEditing()) {
      return deleteForwardInternal();
    }
    if (hasSelection()) {
      TextRange range = m_caret_.normalizedSelection();
      return applyEdit(range, "");
    }

    uint32_t line_cols = m_document_->getLineColumns(m_caret_.cursor.line);
    if (m_caret_.cursor.column < line_cols) {
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      const size_t col = std::min<size_t>(m_caret_.cursor.column, line_text.size());
      const size_t code_point_start = UnicodeUtil::clampColumnToCodePointBoundaryLeft(line_text, col);
      const size_t code_point_end = UnicodeUtil::clampColumnToCodePointBoundaryRight(line_text, col);
      const bool cursor_inside_code_point = code_point_start < col && code_point_end > col;
      const size_t delete_start = cursor_inside_code_point ? code_point_start : col;
      const size_t delete_end = cursor_inside_code_point
          ? code_point_end
          : UnicodeUtil::nextCodePointColumn(line_text, col);
      if (delete_start == delete_end) return {};
      TextRange del_range = {
        {m_caret_.cursor.line, static_cast<uint32_t>(delete_start)},
        {m_caret_.cursor.line, static_cast<uint32_t>(delete_end)}
      };
      return applyEdit(del_range, "");
    }

    if (m_caret_.cursor.line + 1 < m_document_->getLineCount()) {
      TextRange del_range = {{m_caret_.cursor.line, line_cols}, {m_caret_.cursor.line + 1, 0}};
      return applyEdit(del_range, "");
    }
    return {};
  }

  void EditorCore::deleteSelection() {
    if (!hasSelection() || m_document_ == nullptr) return;
    TextRange range = m_caret_.normalizedSelection();
    // Internal call; do not record undo (used in composition flow)
    m_document_->deleteU8Text(range);
    noteDocumentContentChanged();
    // Adjust decoration offsets to avoid misalignment (especially after multi-line selection deletion)
    m_decorations_->adjustForEdit(range, range.start);
    m_text_layout_->invalidateContentMetrics(range.start.line);
    m_caret_.cursor = range.start;
    clearSelection();
  }
  EditorActionResult EditorCore::moveLineUp() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = moveLineUpInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::moveLineDown() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = moveLineDownInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::copyLineUp() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = copyLineUpInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::copyLineDown() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = copyLineDownInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::deleteLine() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = deleteLineInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::insertLineAbove() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = insertLineAboveInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::insertLineBelow() {
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = insertLineBelowInternal();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
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

  TextEditResult EditorCore::moveLineUpInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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
    if (result.contentChanged()) {
      result.change_kind = TextChangeKind::MOVE;
    }
    return result;
  }

  TextEditResult EditorCore::moveLineDownInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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
    if (result.contentChanged()) {
      result.change_kind = TextChangeKind::MOVE;
    }
    return result;
  }

  TextEditResult EditorCore::copyLineUpInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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

  TextEditResult EditorCore::copyLineDownInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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

  TextEditResult EditorCore::deleteLineInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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

  TextEditResult EditorCore::insertLineAboveInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

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

  TextEditResult EditorCore::insertLineBelowInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};
    if (hasPreedit()) m_composition_controller_.cancelPreeditText();

    size_t line = m_caret_.cursor.line;
    uint32_t line_cols = m_document_->getLineColumns(line);
    TextPosition insert_pos = {line, line_cols};

    auto result = applyEdit({insert_pos, insert_pos}, "\n");
    // applyEdit has already moved cursor to the start of the new line
    return result;
  }
  TextEditResult EditorCore::undoInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If preedit input is active, cancel it first
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
    }

    // Exit linked editing mode when undoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const UndoEntry* entry = m_undo_manager_->undo();
    if (entry == nullptr) return {};

    TextEditResult edit_result;
    edit_result.markHandled(TextChangeKind::UNDO);

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
    noteDocumentContentChanged();
    ensureCursorVisible();
    LOGD("EditorCore::undo, cursor = %s", m_caret_.cursor.dump().c_str());
    return edit_result;
  }

  TextEditResult EditorCore::redoInternal() {
    if (m_document_ == nullptr || m_settings_.read_only) return {};

    // If preedit input is active, cancel it first
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
    }

    // Exit linked editing mode when redoing
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    const UndoEntry* entry = m_undo_manager_->redo();
    if (entry == nullptr) return {};

    TextEditResult edit_result;
    edit_result.markHandled(TextChangeKind::REDO);

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
    noteDocumentContentChanged();
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

  EditorActionResult EditorCore::search(const SearchRequest& request) {
    const uint64_t generation = m_search_generation_->fetch_add(1) + 1;
    SearchSnapshot snapshot = buildSearchSnapshot(request, generation);
    publishSearchState(snapshot.state);

    SearchResult searching_result;
    searching_result.state = snapshot.state;
    publishPendingSearchResult(std::move(searching_result));
    SearchResult result = getSearchEngine().search(snapshot);
    if (result.state.generation != m_search_generation_->load()) {
      return makeSearchActionResult(false, false);
    }
    chooseCurrentSearchMatch(result, snapshot.cursor_position);
    publishSearchState(result.state);
    publishPendingSearchResult(std::move(result));
    return makeSearchActionResult(true);
  }

  EditorActionResult EditorCore::findNextSearchMatch() {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    if (m_search_state_.status != SearchStatus::READY || m_search_matches_.empty()) {
      return finishAction(before, EditorActionSource::SEARCH, false);
    }

    size_t index = m_search_state_.current_index >= 0
        ? static_cast<size_t>(m_search_state_.current_index) + 1
        : firstSearchMatchAtOrAfter(m_caret_.cursor);
    if (index >= m_search_matches_.size()) {
      if (!m_search_state_.options.wrap_around) {
        return finishAction(before, EditorActionSource::SEARCH, false);
      }
      index = 0;
    }

    selectSearchMatch(index);
    return finishAction(before, EditorActionSource::SEARCH, true, {}, true, true);
  }

  EditorActionResult EditorCore::findPreviousSearchMatch() {
    drainPendingSearchResult();
    const ActionSnapshot before = captureActionSnapshot();
    if (m_search_state_.status != SearchStatus::READY || m_search_matches_.empty()) {
      return finishAction(before, EditorActionSource::SEARCH, false);
    }

    size_t index = m_search_matches_.size();
    if (m_search_state_.current_index > 0) {
      index = static_cast<size_t>(m_search_state_.current_index) - 1;
    } else if (m_search_state_.current_index == 0) {
      if (!m_search_state_.options.wrap_around) {
        return finishAction(before, EditorActionSource::SEARCH, false);
      }
      index = m_search_matches_.size() - 1;
    } else {
      index = firstSearchMatchAtOrAfter(m_caret_.cursor);
      if (index == 0) {
        if (!m_search_state_.options.wrap_around) {
          return finishAction(before, EditorActionSource::SEARCH, false);
        }
        index = m_search_matches_.size() - 1;
      } else if (index >= m_search_matches_.size()) {
        index = m_search_matches_.size() - 1;
      } else {
        --index;
      }
    }

    selectSearchMatch(index);
    return finishAction(before, EditorActionSource::SEARCH, true, {}, true, true);
  }

  EditorActionResult EditorCore::replaceCurrentSearchMatch(const U8String& replacement) {
    drainPendingSearchResult();
    SearchMatch match;
    SearchOptions options;
    uint64_t generation = 0;

    if (m_document_ == nullptr || m_settings_.read_only
        || m_search_state_.status != SearchStatus::READY
        || m_search_state_.current_index < 0
        || static_cast<size_t>(m_search_state_.current_index) >= m_search_matches_.size()) {
      const ActionSnapshot before = captureActionSnapshot();
      return finishAction(before, EditorActionSource::SEARCH, false);
    }

    match = m_search_matches_[static_cast<size_t>(m_search_state_.current_index)];
    options = m_search_state_.options;
    generation = m_search_generation_->load();

    const U8String actual_replacement = getSearchEngine().buildReplacement(match, replacement, options);
    if (generation != m_search_generation_->load()) {
      markSearchStaleForDocumentChange();
      return makeSearchActionResult(false);
    }
    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result = replaceTextInternal(match.range, actual_replacement);
    return finishAction(before, EditorActionSource::SEARCH, edit_result.handled, std::move(edit_result));
  }

  EditorActionResult EditorCore::replaceAllSearchMatches(const U8String& replacement) {
    drainPendingSearchResult();
    Vector<SearchMatch> matches;
    SearchOptions options;
    uint64_t generation = 0;

    if (m_document_ == nullptr || m_settings_.read_only
        || m_search_state_.status != SearchStatus::READY
        || m_search_matches_.empty()) {
      const ActionSnapshot before = captureActionSnapshot();
      return finishAction(before, EditorActionSource::SEARCH, false);
    }

    matches = m_search_matches_;
    options = m_search_state_.options;
    generation = m_search_generation_->load();

    Vector<U8String> replacements;
    replacements.reserve(matches.size());
    for (const SearchMatch& match : matches) {
      replacements.push_back(getSearchEngine().buildReplacement(match, replacement, options));
    }
    if (generation != m_search_generation_->load()) {
      markSearchStaleForDocumentChange();
      return makeSearchActionResult(false);
    }

    const ActionSnapshot before = captureActionSnapshot();
    TextEditResult edit_result;
    edit_result.cursor_before = m_caret_.cursor;

    m_undo_manager_->beginGroup(m_caret_.cursor, hasSelection(), getSelection());
    for (size_t offset = matches.size(); offset > 0; --offset) {
      const size_t index = offset - 1;
      TextEditResult item_result = applyEdit(matches[index].range, replacements[index]);
      if (!item_result.contentChanged()) continue;
      edit_result.markHandled(item_result.change_kind);
      edit_result.changes.insert(edit_result.changes.end(),
                                 item_result.changes.begin(),
                                 item_result.changes.end());
    }
    edit_result.cursor_after = m_caret_.cursor;
    m_undo_manager_->endGroup(m_caret_.cursor);

    return finishAction(before, EditorActionSource::SEARCH, edit_result.handled, std::move(edit_result));
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
      return *state;
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
    if (position != m_caret_.cursor || hasSelection()) {
      m_composition_controller_.clearPlainLatinInputLock();
    }
    setCursorPositionInternal(position, true);
    clearSelection();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  void EditorCore::setCursorPositionInternal(const TextPosition& position, bool commit_composition) {
    if (commit_composition && hasPreedit() && position != m_caret_.cursor) {
      m_composition_controller_.commitPreeditText("", true);
    }
    m_caret_.cursor = position;
    if (m_document_ != nullptr) {
      size_t line_count = m_document_->getLineCount();
      if (line_count == 0) {
        m_caret_.cursor = {};
        return;
      }
      if (m_caret_.cursor.line >= line_count) {
        m_caret_.cursor.line = line_count > 0 ? line_count - 1 : 0;
      }
      const U16String& current_line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      m_caret_.cursor.column = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
          current_line_text,
          std::min<size_t>(m_caret_.cursor.column, current_line_text.length()));

      const auto& lines = m_document_->getLogicalLines();
      if (m_caret_.cursor.line < lines.size() && lines[m_caret_.cursor.line].is_fold_hidden) {
        const bool projected_tail = m_text_layout_ != nullptr
            && m_text_layout_->isFoldTailProjectedPosition(m_caret_.cursor, true);
        if (!projected_tail) {
          const FoldRegion* fr = m_decorations_->getFoldRegionForLine(m_caret_.cursor.line);
          if (fr != nullptr) {
            m_caret_.cursor.line = fr->start_line;
            m_caret_.cursor.column = m_document_->getLineColumns(fr->start_line);
          }
        }
      }
      const U16String& line_text = m_document_->getLineU16TextRef(m_caret_.cursor.line);
      m_caret_.cursor.column = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
          line_text,
          std::min<size_t>(m_caret_.cursor.column, line_text.length()));
    }
  }

  TextPosition EditorCore::clampDocumentPosition(const TextPosition& position,
                                                 bool prefer_right,
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

  TextRange EditorCore::clampDocumentRange(const TextRange& range,
                                           bool collapse_point_range,
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

  TextPosition EditorCore::getCursorPosition() const {
    return m_caret_.cursor;
  }

  EditorActionResult EditorCore::setSelection(const TextRange& range) {
    const ActionSnapshot before = captureActionSnapshot();
    m_composition_controller_.clearPlainLatinInputLock();
    setSelectionInternal(range, true);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  void EditorCore::setSelectionInternal(const TextRange& range, bool commit_composition) {
    if (commit_composition && hasPreedit()) {
      TextRange current_range = hasSelection()
          ? m_caret_.selection
          : TextRange {m_caret_.cursor, m_caret_.cursor};
      if (!(range == current_range)) {
        m_composition_controller_.commitPreeditText("", true);
      }
    }
    TextRange safe_range = clampDocumentRange(range, true, false);
    m_caret_.setSelection(safe_range);
  }

  TextRange EditorCore::getSelection() const {
    return m_caret_.selection;
  }

  bool EditorCore::hasSelection() const {
    return m_caret_.has_selection;
  }

  EditorActionResult EditorCore::clearSelection() {
    const ActionSnapshot before = captureActionSnapshot();
    m_caret_.clearSelection();
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::selectAll() {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    size_t last_line = m_document_->getLineCount() > 0 ? m_document_->getLineCount() - 1 : 0;
    uint32_t last_col = m_document_->getLineColumns(last_line);
    setSelection({{0, 0}, {last_line, last_col}});
    if (m_options_.reveal_selection_end_on_select_all) {
      ensureCursorVisible();
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  U8String EditorCore::getSelectedText() const {
    if (!hasSelection() || m_document_ == nullptr) return "";
    return m_document_->getU8Text(m_caret_.normalizedSelection());
  }

  TextRange EditorCore::getWordRangeAtCursor() const {
    if (m_document_ == nullptr) return {m_caret_.cursor, m_caret_.cursor};
    size_t line = m_caret_.cursor.line;
    const U16String& line_text = m_document_->getLineU16TextRef(line);
    if (line_text.empty()) {
      return {{line, 0}, {line, 0}};
    }

    size_t anchor = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(
        line_text,
        std::min(m_caret_.cursor.column, line_text.length()));
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

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.start, false);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
    }

    TextPosition new_pos = m_caret_.cursor;
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
    moveCursorTo(new_pos, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorRight(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

    if (hasSelection() && !extend_selection) {
      TextRange range = m_caret_.normalizedSelection();
      moveCursorTo(range.end, false);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
    }

    TextPosition new_pos = m_caret_.cursor;
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
    moveCursorTo(new_pos, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorUp(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

    if (m_caret_.cursor.line == 0) {
      moveCursorTo({0, 0}, extend_selection);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
    }

    // Find the nearest visible line above
    size_t target_line = m_caret_.cursor.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      if (target_line == 0) {
        moveCursorTo({0, 0}, extend_selection);
        return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
      }
      --target_line;
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_caret_.cursor);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTestPointer(target_point);
    moveCursorTo(new_pos, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorDown(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);

    size_t line_count = m_document_->getLineCount();
    if (m_caret_.cursor.line + 1 >= line_count) {
      uint32_t cols = m_document_->getLineColumns(m_caret_.cursor.line);
      moveCursorTo({m_caret_.cursor.line, cols}, extend_selection);
      return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
    }

    // Find the nearest visible line below
    size_t target_line = m_caret_.cursor.line;
    const auto& lines = m_document_->getLogicalLines();
    do {
      ++target_line;
      if (target_line >= line_count) {
        uint32_t cols = m_document_->getLineColumns(line_count - 1);
        moveCursorTo({line_count - 1, cols}, extend_selection);
        return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
      }
    } while (target_line < lines.size() && lines[target_line].is_fold_hidden);

    PointF current_screen = m_text_layout_->getPositionScreenCoord(m_caret_.cursor);
    PointF target_coord = m_text_layout_->getPositionScreenCoord({target_line, 0});
    float line_height = m_text_layout_->getLineHeight();
    PointF target_point = {current_screen.x, target_coord.y + line_height * 0.5f};
    TextPosition new_pos = m_text_layout_->hitTestPointer(target_point);
    moveCursorTo(new_pos, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorToLineStart(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    moveCursorTo({m_caret_.cursor.line, 0}, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorToLineEnd(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    uint32_t cols = m_document_->getLineColumns(m_caret_.cursor.line);
    moveCursorTo({m_caret_.cursor.line, cols}, extend_selection);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorPageUp(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorUp(extend_selection);
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::moveCursorPageDown(bool extend_selection) {
    const ActionSnapshot before = captureActionSnapshot();
    if (m_document_ == nullptr || m_text_layout_ == nullptr) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    float line_height = m_text_layout_->getLineHeight();
    if (line_height <= 0) return finishAction(before, EditorActionSource::PROGRAMMATIC, false);
    int page_lines = static_cast<int>(m_viewport_.height / line_height);
    if (page_lines < 1) page_lines = 1;
    for (int i = 0; i < page_lines; ++i) {
      moveCursorDown(extend_selection);
    }
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
  }

  EditorActionResult EditorCore::setReadOnly(bool read_only) {
    const ActionSnapshot before = captureActionSnapshot();
    if (read_only && hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
    }
    m_settings_.read_only = read_only;
    LOGD("EditorCore::setReadOnly, read_only = %s", read_only ? "true" : "false");
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
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
    TextEditResult edit_result = insertSnippetInternal(snippet_template);
    return finishAction(before, EditorActionSource::PROGRAMMATIC, edit_result.handled, std::move(edit_result));
  }

  TextEditResult EditorCore::insertSnippetInternal(const U8String& snippet_template) {
    if (m_document_ == nullptr || snippet_template.empty() || m_settings_.read_only) return {};

    // If preedit is active, cancel it first
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
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
      m_linked_editing_session_ = makeUnique<LinkedEditingSession>(std::move(parse_result.model));
      activateCurrentTabStop();
    }

    LOGD("EditorCore::insertSnippet, cursor = %s", m_caret_.cursor.dump().c_str());
    return edit_result;
  }

  EditorActionResult EditorCore::startLinkedEditing(LinkedEditingModel&& model) {
    const ActionSnapshot before = captureActionSnapshot();
    startLinkedEditingInternal(std::move(model));
    return finishAction(before, EditorActionSource::LINKED_EDITING, true);
  }

  void EditorCore::startLinkedEditingInternal(LinkedEditingModel&& model) {
    if (m_document_ == nullptr || m_settings_.read_only) return;
    if (model.groups.empty()) return;

    // If preedit is active, cancel it first
    if (hasPreedit()) {
      m_composition_controller_.cancelPreeditText();
    }

    // Exit existing linked editing session
    if (m_linked_editing_session_) {
      m_linked_editing_session_->cancel();
      m_linked_editing_session_.reset();
    }

    m_linked_editing_session_ = makeUnique<LinkedEditingSession>(std::move(model));
    activateCurrentTabStop();

    LOGD("EditorCore::startLinkedEditing, cursor = %s", m_caret_.cursor.dump().c_str());
  }

  bool EditorCore::isInLinkedEditing() const {
    return m_linked_editing_session_ != nullptr && m_linked_editing_session_->isActive();
  }

  EditorActionResult EditorCore::linkedEditingNextTabStop() {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = linkedEditingNextTabStopInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, handled);
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

  EditorActionResult EditorCore::linkedEditingPrevTabStop() {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = linkedEditingPrevTabStopInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, handled);
  }

  bool EditorCore::linkedEditingPrevTabStopInternal() {
    if (!isInLinkedEditing()) return false;
    bool has_prev = m_linked_editing_session_->prevTabStop();
    if (has_prev) {
      activateCurrentTabStop();
    }
    return has_prev;
  }

  EditorActionResult EditorCore::finishLinkedEditing() {
    const ActionSnapshot before = captureActionSnapshot();
    finishLinkedEditingInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, true);
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

  EditorActionResult EditorCore::cancelLinkedEditing() {
    const ActionSnapshot before = captureActionSnapshot();
    cancelLinkedEditingInternal();
    return finishAction(before, EditorActionSource::LINKED_EDITING, true);
  }

  void EditorCore::cancelLinkedEditingInternal() {
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

    result.markHandled(primary_before.isCollapsed()
                       ? TextChangeKind::INSERTION
                       : (new_text.empty() ? TextChangeKind::DELETION : TextChangeKind::REPLACEMENT));
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
         line, column, m_caret_.cursor.dump().c_str());
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
    return getPositionScreenRect(m_caret_.cursor);
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
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLineInlayHints(size_t line, Vector<InlayHint>&& hints) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLineInlayHints(line, std::move(hints));
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
    m_text_layout_->invalidateContentMetrics(min_line);
    return finishAction(before, EditorActionSource::DECORATION, true, {}, true, true);
  }

  EditorActionResult EditorCore::setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms) {
    const ActionSnapshot before = captureActionSnapshot();
    m_decorations_->setLinePhantomTexts(line, std::move(phantoms));
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
    const LinkSpan* link = m_decorations_->findLinkAt(line, column);
    return link != nullptr ? link->target : U8String {};
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

  bool EditorCore::foldAtInternal(size_t line) {
    bool result = m_decorations_->foldAt(line);
    if (result) syncFoldState();
    return result;
  }

  EditorActionResult EditorCore::unfoldAt(size_t line) {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = unfoldAtInternal(line);
    return finishAction(before, EditorActionSource::FOLDING, handled, {}, handled, handled);
  }

  bool EditorCore::unfoldAtInternal(size_t line) {
    bool result = m_decorations_->unfoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  EditorActionResult EditorCore::toggleFoldAt(size_t line) {
    const ActionSnapshot before = captureActionSnapshot();
    bool handled = toggleFoldAtInternal(line);
    return finishAction(before, EditorActionSource::FOLDING, handled, {}, handled, handled);
  }

  bool EditorCore::toggleFoldAtInternal(size_t line) {
    bool result = m_decorations_->toggleFoldAt(line);
    if (result) syncFoldState();
    return result;
  }

  EditorActionResult EditorCore::foldAll() {
    const ActionSnapshot before = captureActionSnapshot();
    foldAllInternal();
    return finishAction(before, EditorActionSource::FOLDING, true, {}, true, true);
  }

  void EditorCore::foldAllInternal() {
    m_decorations_->foldAll();
    syncFoldState();
  }

  EditorActionResult EditorCore::unfoldAll() {
    const ActionSnapshot before = captureActionSnapshot();
    unfoldAllInternal();
    return finishAction(before, EditorActionSource::FOLDING, true, {}, true, true);
  }

  void EditorCore::unfoldAllInternal() {
    m_decorations_->unfoldAll();
    syncFoldState();
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

  void EditorCore::placeCursorAt(const PointF& screen_point) {
    TextPosition pos = m_text_layout_->hitTestPointer(screen_point);
    setCursorPosition(pos);
    clearSelection();
    LOGD("EditorCore::placeCursorAt, pos = %s", pos.dump().c_str());
  }


  void EditorCore::selectWordAt(const PointF& screen_point) {
    if (m_document_ == nullptr) return;
    TextPosition pos = m_text_layout_->hitTestPointer(screen_point);

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

  EditorActionResult EditorCore::ensureCursorVisible() {
    const ActionSnapshot before = captureActionSnapshot();
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
    return finishAction(before, EditorActionSource::PROGRAMMATIC, true);
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
    snapshot.cursor_position = m_caret_.cursor;

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
    chooseCurrentSearchMatch(result, m_caret_.cursor);
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

  void EditorCore::collectTextPresentationEffectsForLine(size_t line,
                                                         Vector<TextPresentationEffect>& effects) const {
    if (m_caret_.has_selection) {
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

    const auto& document_highlights = m_decorations_->getLineDocumentHighlights(line);
    for (const auto& highlight : document_highlights) {
      if (highlight.length == 0) continue;
      const RangeEffectStyle& style =
          RenderStyleUtil::documentHighlightRangeEffectStyle(m_settings_.range_effect_styles, highlight.kind);
      if (style.foreground_color == 0 && style.background_color == 0) {
        continue;
      }

      TextPresentationEffect effect;
      effect.range = {{line, highlight.column}, {line, highlight.column + highlight.length}};
      effect.foreground_color = style.foreground_color;
      effect.clear_text_background = style.background_color != 0;
      effect.priority = 60;
      effects.push_back(effect);
    }

    if (line >= m_search_match_indices_by_line_.size()) {
      return;
    }

    for (uint32_t match_index : m_search_match_indices_by_line_[line]) {
      if (match_index >= m_search_matches_.size()) continue;
      const bool is_current = m_search_state_.current_index >= 0
          && match_index == static_cast<uint32_t>(m_search_state_.current_index);
      const RangeEffectStyle& style = is_current
          ? m_settings_.range_effect_styles.search_current
          : m_settings_.range_effect_styles.search_match;
      if (style.foreground_color == 0 && style.background_color == 0) {
        continue;
      }

      TextPresentationEffect effect;
      effect.range = m_search_matches_[match_index].range;
      effect.foreground_color = style.foreground_color;
      effect.clear_text_background = style.background_color != 0;
      effect.priority = is_current ? 80 : 70;
      effects.push_back(effect);
    }
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
    setSelectionInternal(m_search_matches_[index].range, true);
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

  TextEditResult EditorCore::applyEdit(const TextRange& range, const U8String& new_text, bool record_undo) {
    if (m_document_ == nullptr) return {};

    TextRange safe_range = clampDocumentRange(range, true, false);
    safe_range = safe_range.normalized();
    if (safe_range.isCollapsed() && new_text.empty()) {
      return {};
    }
    const bool is_insert = safe_range.isCollapsed();
    const size_t line_count = m_document_->getLineCount();

    const bool single_line_edit_text =
        new_text.find('\n') == U8String::npos && new_text.find('\r') == U8String::npos;
    size_t fold_tail_owner_line = line_count;
    bool keep_fold_collapsed = false;
    if (single_line_edit_text && safe_range.start.line == safe_range.end.line && m_text_layout_ != nullptr) {
      size_t start_owner_line = line_count;
      size_t end_owner_line = line_count;
      const bool start_projected =
          m_text_layout_->isFoldTailProjectedPosition(safe_range.start, true, &start_owner_line);
      const bool end_projected =
          m_text_layout_->isFoldTailProjectedPosition(safe_range.end, true, &end_owner_line);
      keep_fold_collapsed = start_projected && end_projected && start_owner_line == end_owner_line;
      if (keep_fold_collapsed) {
        fold_tail_owner_line = start_owner_line;
      }
    }

    if (!keep_fold_collapsed) {
      autoUnfoldForEdit(safe_range);
    }

    U8String old_text;
    bool is_delete = new_text.empty();
    bool is_replace = !is_delete && !is_insert;
    TextChangeKind change_kind = TextChangeKind::REPLACEMENT;
    if (is_insert) {
      change_kind = TextChangeKind::INSERTION;
    } else if (is_delete) {
      change_kind = TextChangeKind::DELETION;
    }

    TextEditResult edit_result;
    edit_result.markHandled(change_kind);

    // Read old text (for delete/replace)
    if (!is_insert) {
      old_text = m_document_->getU8Text(safe_range);
    }

    TextPosition cursor_before = m_caret_.cursor;
    edit_result.cursor_before = cursor_before;
    bool had_selection = hasSelection();
    TextRange selection_before = getSelection();

    // Perform document operation
    if (is_insert) {
      m_document_->insertU8Text(safe_range.start, new_text);
    } else if (is_delete) {
      m_document_->deleteU8Text(safe_range);
    } else {
      m_document_->replaceU8Text(safe_range, new_text);
    }
    noteDocumentContentChanged();

    // Compute new cursor position
    TextPosition new_cursor;
    if (is_delete) {
      new_cursor = safe_range.start;
    } else {
      new_cursor = calcPositionAfterInsert(safe_range.start, new_text);
    }
    edit_result.cursor_after = new_cursor;

    // Fill changes
    TextChange change;
    change.range = safe_range;
    change.old_text = old_text;
    change.new_text = new_text;
    edit_result.changes.push_back(std::move(change));

    // Adjust decoration offsets
    m_decorations_->adjustForEdit(safe_range, new_cursor);

    if (keep_fold_collapsed && fold_tail_owner_line < line_count) {
      auto& lines = m_document_->getLogicalLines();
      lines[fold_tail_owner_line].is_layout_dirty = true;
      if (safe_range.start.line < lines.size()) {
        lines[safe_range.start.line].is_layout_dirty = true;
        if (lines[safe_range.start.line].is_fold_hidden) {
          lines[safe_range.start.line].height = 0;
          lines[safe_range.start.line].visual_lines.clear();
        }
      }
      m_text_layout_->invalidateContentMetrics(std::min(fold_tail_owner_line, safe_range.start.line));
    } else {
      m_text_layout_->invalidateContentMetrics(safe_range.start.line);
    }

    setCursorPositionInternal(new_cursor, true);
    clearSelection();

    // Record to undo stack
    if (record_undo) {
      EditAction action;
      action.range = safe_range;
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

    result.hot_target = toHotInteractiveTarget(m_text_layout_->hitTestDecoration(point), modifiers);
    if (result.hot_target.type != HitTargetType::NONE) {
      result.cursor_type = PointerCursorType::HAND;
      return result;
    }

    result.cursor_type = point.x >= m_text_layout_->getLayoutMetrics().textAreaX()
                           ? PointerCursorType::TEXT
                           : PointerCursorType::DEFAULT;
    return result;
  }

  void EditorCore::finalizeGestureResult(GestureResult& result) const {
    result.cursor_position = m_caret_.cursor;
    result.has_selection = hasSelection();
    result.selection = m_caret_.selection;
    result.view_scroll_x = m_view_state_.scroll_x;
    result.view_scroll_y = m_view_state_.scroll_y;
    result.view_scale = m_view_state_.scale;
    result.pointer_cursor_type = m_pointer_cursor_type_;
  }

  EditorCore::ActionSnapshot EditorCore::captureActionSnapshot() const {
    ActionSnapshot snapshot;
    snapshot.cursor = m_caret_.cursor;
    snapshot.has_selection = hasSelection();
    snapshot.selection = m_caret_.selection;
    snapshot.scroll_x = m_view_state_.scroll_x;
    snapshot.scroll_y = m_view_state_.scroll_y;
    snapshot.scale = m_view_state_.scale;
    snapshot.pointer_cursor_type = m_pointer_cursor_type_;
    snapshot.active_hit_target = getActiveHitTarget();
    snapshot.composition = m_composition_controller_.composition();
    return snapshot;
  }

  EditorActionResult EditorCore::finishAction(const ActionSnapshot& before,
                                              EditorActionSource source,
                                              bool handled,
                                              TextEditResult edit_result,
                                              bool force_redraw,
                                              bool decoration_changed) const {
    EditorActionResult result;
    result.handled = handled || edit_result.handled;
    result.source = source;
    result.text_change_kind = edit_result.contentChanged()
                              ? edit_result.change_kind
                              : TextChangeKind::NONE;
    result.changes = std::move(edit_result.changes);
    result.content_changed = !result.changes.empty();

    result.cursor_before = before.cursor;
    result.cursor_after = m_caret_.cursor;
    result.cursor_changed = result.cursor_before != result.cursor_after;

    result.has_selection_before = before.has_selection;
    result.has_selection_after = hasSelection();
    result.selection_before = before.selection;
    result.selection_after = m_caret_.selection;
    result.selection_changed = result.has_selection_before != result.has_selection_after
                               || (result.has_selection_after && !(result.selection_before == result.selection_after));

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

    const bool active_hit_target_changed = !sameHitTarget(before.active_hit_target, getActiveHitTarget());
    result.composition_changed = !sameCompositionState(before.composition, m_composition_controller_.composition());
    result.decoration_changed = decoration_changed;
    result.needs_ime_sync = result.content_changed || result.cursor_changed || result.selection_changed || result.composition_changed;
    if (result.needs_ime_sync) {
      result.ime_sync = getImeSyncSnapshot();
    }
    result.needs_redraw = force_redraw
                          || result.content_changed
                          || result.cursor_changed
                          || result.selection_changed
                          || result.scroll_changed
                          || result.scale_changed
                          || result.composition_changed
                          || active_hit_target_changed
                          || result.decoration_changed;
    result.needs_edge_scroll = m_interaction_->hasActiveEdgeScroll();
    result.needs_fling = m_interaction_->hasActiveFling();
    result.needs_animation = result.needs_edge_scroll || result.needs_fling;
    return result;
  }

  EditorActionResult EditorCore::finishGestureAction(const ActionSnapshot& before,
                                                     GestureResult gesture_result,
                                                     EditorActionSource source,
                                                     EventType event_type,
                                                     bool decoration_changed) const {
    EditorActionResult result = finishAction(before, source, true, {}, false, decoration_changed);
    result.gesture_type = gesture_result.type;
    result.gesture_event_type = event_type;
    result.tap_point = gesture_result.tap_point;
    result.hit_target = gesture_result.hit_target;
    result.modifiers = gesture_result.modifiers;
    result.is_handle_drag = gesture_result.is_handle_drag;
    result.pointer_cursor_after = gesture_result.pointer_cursor_type;
    result.pointer_cursor_changed = result.pointer_cursor_before != result.pointer_cursor_after;
    result.handled = gesture_result.type != GestureType::UNDEFINED
                     || result.needs_redraw
                     || result.needs_edge_scroll
                     || result.needs_fling
                     || result.needs_animation
                     || result.pointer_cursor_changed;
    return result;
  }

  EditorActionResult EditorCore::finishImeAction(const ActionSnapshot& before,
                                                 const ImeActionResult& ime_result) const {
    EditorActionResult result = finishAction(before,
                                             EditorActionSource::IME,
                                             ime_result.handled,
                                             ime_result.edit_result);
    result.ime_sync = ime_result.sync;
    result.needs_ime_sync = result.needs_ime_sync
        || imeSyncSnapshotRequestsPlatformUpdate(result.ime_sync);
    result.needs_redraw = result.needs_redraw || result.composition_changed || result.content_changed;
    return result;
  }

  void EditorCore::normalizeScrollState() {
    PERF_TIMER("normalizeScrollState");
    if (m_text_layout_ == nullptr) return;
    m_text_layout_->normalizeViewState(m_view_state_);
  }


#pragma endregion

}
