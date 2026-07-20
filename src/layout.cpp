//
// Created by Scave on 2025/12/7.
//
#include <cmath>
#include <algorithm>
#include <limits>
#include <utf8/utf8.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/utility.h>
#include "logging.h"
#include "text_boundary.hpp"

namespace NS_SWEETEDITOR {
  namespace {
    bool isSourceTextRun(const VisualRun& run) {
      return run.type == VisualRunType::TEXT
          || run.type == VisualRunType::LINK
          || run.type == VisualRunType::TAB;
    }

    size_t runSourceLine(const VisualLine& visual_line, const VisualRun& run) {
      return run.source_line == kVisualRunOwnerLine ? visual_line.logical_line : run.source_line;
    }
  }

#pragma region [Class: TextLayout]
  TextLayout::TextLayout(const SharedPtr<TextMeasurer>& measurer, const SharedPtr<DecorationManager>& decoration_manager)
    : m_measurer_(measurer), m_decoration_manager_(decoration_manager) {
    resetMeasurer();
  }

  void TextLayout::loadDocument(const SharedPtr<Document>& document) {
    m_document_ = document;
    m_content_metrics_dirty_ = true;
    m_prefix_dirty_from_ = 0;
    m_line_prefix_y_.clear();
  }

  void TextLayout::setViewport(const Size& viewport) {
    if (m_viewport_.width != viewport.width) {
      m_content_metrics_dirty_ = true;
      m_prefix_dirty_from_ = 0;
    } else if (m_viewport_.height != viewport.height) {
      m_content_metrics_dirty_ = true;
    }
    m_viewport_ = viewport;
  }

  void TextLayout::setViewState(const ViewState& view_state) {
    m_view_state_ = view_state;
  }

  void TextLayout::setWrapMode(WrapMode mode) {
    if (m_wrap_mode_ != mode) {
      m_content_metrics_dirty_ = true;
      m_prefix_dirty_from_ = 0;
    }
    m_wrap_mode_ = mode;
  }

  void TextLayout::setRenderLineBreaks(bool enabled) {
    if (m_render_line_breaks_ != enabled) {
      m_content_metrics_dirty_ = true;
      m_prefix_dirty_from_ = 0;
      if (m_document_ != nullptr) {
        for (auto& ll : m_document_->getLogicalLines()) {
          ll.is_layout_dirty = true;
        }
      }
    }
    m_render_line_breaks_ = enabled;
  }

  void TextLayout::setTabSize(uint32_t tab_size) {
    if (tab_size < 1) tab_size = 1;
    if (m_tab_size_ != tab_size) {
      m_tab_size_ = tab_size;
      m_content_metrics_dirty_ = true;
      m_prefix_dirty_from_ = 0;
      if (m_document_ != nullptr) {
        for (auto& ll : m_document_->getLogicalLines()) {
          ll.is_layout_dirty = true;
        }
      }
    }
  }

  uint32_t TextLayout::getTabSize() const {
    return m_tab_size_;
  }

  void TextLayout::layoutLine(size_t index, LogicalLine& logical_line) {
    // Use prefix index to get line start y, and sync to LogicalLine.start_y (derived cache)
    ensurePrefixIndexUpTo(index);
    logical_line.start_y = (index < m_line_prefix_y_.size()) ? m_line_prefix_y_[index] : 0.0f;

    // Fold-hidden line: height is 0, and no visual lines are generated
    if (logical_line.is_fold_hidden) {
      if (logical_line.height != 0) {
        m_content_metrics_dirty_ = true;
        invalidatePrefixFrom(index + 1);
      }
      logical_line.height = 0;
      logical_line.visual_lines.clear();
      logical_line.is_layout_dirty = false;
      return;
    }

    if (!logical_line.is_layout_dirty) {
      // Even if relayout is not needed, still update line number and y in visual_lines
      // (insert/delete in previous lines may change current line index and y)
      float line_height = getLineHeight();
      for (VisualLine& vl : logical_line.visual_lines) {
        vl.logical_line = index;
        float vl_y = logical_line.start_y + vl.wrap_index * line_height;
        vl.line_number_position.y = vl_y;
        for (VisualRun& run : vl.runs) {
          run.y = vl_y;
        }
      }
      return;
    }
    logical_line.visual_lines.clear();
    const U16String& line_text = m_document_->getLineU16TextRef(index);
    float single_line_height = getLineHeight();

    layoutLineIntoVisualLines(index, line_text, logical_line.start_y, logical_line.visual_lines);

    // Collapsed first line: append fold placeholder + tail-line content
    if (m_decoration_manager_->getFoldStateForLine(index) == 2 && !logical_line.visual_lines.empty()) {
      appendFoldTailRuns(index, line_text, logical_line);
    }

    if (m_render_line_breaks_) {
      appendLineBreakRun(index, logical_line);
    }

    float new_height = single_line_height * logical_line.visual_lines.size();
    if (logical_line.height != new_height) {
      m_content_metrics_dirty_ = true;
      invalidatePrefixFrom(index + 1);
    }
    logical_line.height = new_height;

    logical_line.is_layout_dirty = false;
  }

  VisibleLineInfo TextLayout::layoutVisibleLines(EditorRenderModel& model, const PresentationContext& presentation_context) {
    PERF_TIMER("layoutVisibleLines");
    if (!isValidViewportSize(m_viewport_) || m_document_ == nullptr) {
      return {};
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return {};
    }
    // Compute line number width
    m_layout_metrics_.line_number_width = computeLineNumberWidth();
    // Layout dirty lines while resolving visible line range
    VisibleLineInfo visible_line_info = resolveVisibleLines();
    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    // Build visual lines (scan visible area only)
    const bool is_wrap_mode = (m_wrap_mode_ != WrapMode::NONE);
    // Center offset for line spacing (when line height > font height)
    const float line_height = getLineHeight();
    const float top_padding = (line_height - m_layout_metrics_.font_height) * 0.5f;
    const float split_x = m_layout_metrics_.gutterWidth();
    const bool gutter_sticky = m_layout_metrics_.gutter_sticky;
    const float gutter_offset = gutter_sticky ? 0.0f : -scroll_x;
    for (size_t i = visible_line_info.first_line; i <= visible_line_info.last_line; ++i) {
      LogicalLine& logical_line = logical_lines[i];
      // Crop recomposed VisualLine by horizontal viewport, then map to screen coords
      for (const VisualLine& src_line : logical_line.visual_lines) {
        VisualLine visual_line = src_line;
        // Convert absolute coords to screen coords (wrapLineRuns already sets each subline y)
        float abs_y = visual_line.line_number_position.y;
        float screen_y = abs_y - scroll_y;
        // Text draw y should be baseline (line top + top_padding + font_ascent)
        float baseline_y = screen_y + top_padding + m_layout_metrics_.font_ascent;
        visual_line.line_number_position.x += gutter_offset;
        visual_line.line_number_position.y = baseline_y;
        for (VisualRun& run : visual_line.runs) {
          run.y = baseline_y;
        }
        if (!is_wrap_mode) {
          cropVisualLineRuns(visual_line, scroll_x);
        } else {
          // In wrap mode, no horizontal crop is needed; just set run.x to screen coord
          const float text_area_x = m_layout_metrics_.textAreaX();
          for (VisualRun& run : visual_line.runs) {
            run.x += text_area_x;
          }
        }
        applyPresentationState(visual_line, presentation_context);
        // Fill gutter state only for the line that explicitly owns logical-line gutter semantics.
        if (visual_line.owns_gutter_semantics && m_layout_metrics_.gutter_visible) {
          buildGutterIconRenderItems(i, screen_y, gutter_offset, model.gutter_icons);
          // Set fold state (used by platform to draw fold/unfold arrow)
          int fs = m_decoration_manager_->getFoldStateForLine(i);
          visual_line.fold_state = static_cast<FoldState>(fs);
          FoldMarkerRenderItem fold_marker;
          if (buildFoldMarkerRenderItem(i, screen_y, gutter_offset, fold_marker)) {
            model.fold_markers.push_back(std::move(fold_marker));
          }
        }
        model.lines.push_back(std::move(visual_line));
      }
    }
    model.split_x = split_x + gutter_offset;
    model.max_gutter_icons = m_layout_metrics_.max_gutter_icons;
    model.scroll_x = scroll_x;
    model.scroll_y = scroll_y;
    model.viewport_size = m_viewport_;
    return visible_line_info;
  }

  CaretHit TextLayout::hitTestPointer(const PointF& screen_point) {
    return hitTestInternal(screen_point, false);
  }

  CaretHit TextLayout::hitTestTextBoundary(const PointF& screen_point) {
    return hitTestInternal(screen_point, true);
  }

  CaretHit TextLayout::hitTestInternal(const PointF& screen_point, bool text_boundary) {
    CaretHit hit;
    hit.position = hitTestPositionInternal(screen_point, text_boundary);
    if (m_document_ == nullptr || m_wrap_mode_ == WrapMode::NONE) {
      return hit;
    }

    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return hit;
    }
    const float abs_y = screen_point.y + m_view_state_.scroll_y;
    const size_t hit_line = findHitLine(abs_y);
    if (hit_line >= logical_lines.size()) {
      return hit;
    }
    LogicalLine& logical_line = logical_lines[hit_line];
    layoutLine(hit_line, logical_line);
    if (logical_line.visual_lines.empty()) {
      return hit;
    }
    const size_t wrap_index = findHitWrapIndex(logical_line, abs_y, getLineHeight());
    if (wrap_index >= logical_line.visual_lines.size()) {
      return hit;
    }

    size_t column_min = SIZE_MAX;
    size_t column_max = 0;
    float width = 0;
    if (!getVisualLineTextColumnExtent(logical_line.visual_lines[wrap_index],
                                       hit.position.line,
                                       column_min,
                                       column_max,
                                       width)) {
      return hit;
    }
    // A wrap boundary has one logical position but two visual caret locations.
    if (wrap_index > 0 && hit.position.column == column_min) {
      hit.affinity = CaretAffinity::DOWNSTREAM;
    } else if (wrap_index + 1 < logical_line.visual_lines.size()
               && hit.position.column == column_max) {
      hit.affinity = CaretAffinity::UPSTREAM;
    }
    return hit;
  }

  TextPosition TextLayout::hitTestPositionInternal(const PointF& screen_point, bool text_boundary) {
    PERF_TIMER("hitTest");
    if (m_document_ == nullptr) {
      return {0, 0};
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return {0, 0};
    }

    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    const float split_x = m_layout_metrics_.gutterWidth();
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float line_height = getLineHeight();

    // Convert screen coords to absolute document coords
    const float abs_x = screen_point.x - text_area_x + scroll_x;
    const float abs_y = screen_point.y + scroll_y;

    // Find hit logical line (skip fold-hidden lines)
    size_t hit_line = findHitLine(abs_y);

    const LogicalLine& ll = logical_lines[hit_line];
    const U16String& line_text = ll.cached_u16_text;

    // In wrap mode, find the exact VisualLine (subline)
    size_t target_wrap = findHitWrapIndex(ll, abs_y, line_height);

    const VisualLine& vl = ll.visual_lines[target_wrap];

    const auto& semantics = getVisualLineSemantics(vl.kind);
    if (text_boundary && semantics.text_boundary != TextBoundaryPolicy::CONTENT) {
      return mapVisualLineToTextBoundary(hit_line, vl);
    }

    // Click on the left of text area (line number area): go to line start
    const bool in_line_number_area = (screen_point.x < split_x);
    if (in_line_number_area) {
      return {hit_line, 0};
    }

    // In both wrap and non-wrap modes, run.x is relative to the line
    // Compute relative click x inside the line
    float click_x;
    if (m_wrap_mode_ != WrapMode::NONE) {
      click_x = screen_point.x - text_area_x;
    } else {
      click_x = abs_x;
    }

    // If click is left of line start, return column of first TEXT/TAB run in this VisualLine
    if (click_x <= 0 || vl.runs.empty()) {
      if (!vl.runs.empty()) {
        for (const VisualRun& run : vl.runs) {
          if (isSourceTextRun(run)) {
            return {runSourceLine(vl, run), run.column};
          }
          if (run.type == VisualRunType::PHANTOM_TEXT) {
            return {hit_line, run.column};
          }
        }
      }
      return {hit_line, 0};
    }

    if (semantics.pointer_hit != PointerHitPolicy::CONTENT) {
      return mapVisualLineToPointerTarget(hit_line, vl);
    }

    // Iterate runs to find the hit character
    float run_x = 0;
    for (const VisualRun& run : vl.runs) {
      float run_right = run_x + run.width;

      if (run.type == VisualRunType::INLAY_HINT || run.type == VisualRunType::PHANTOM_TEXT
          || run.type == VisualRunType::FOLD_PLACEHOLDER || run.type == VisualRunType::CODELENS) {
        run_x = run_right;
        continue;
      }

      if (run.type == VisualRunType::TAB) {
        const size_t source_line = runSourceLine(vl, run);
        if (click_x < run_x + run.width * 0.5f) {
          return {source_line, run.column};
        } else if (click_x < run_right) {
          return {source_line, run.column + 1};
        }
        run_x = run_right;
        continue;
      }

      if (run.type == VisualRunType::NEWLINE) {
        const size_t source_line = runSourceLine(vl, run);
        if (click_x < run_right) {
          return {source_line, run.column};
        }
        run_x = run_right;
        continue;
      }

      if (click_x < run_right || &run == &vl.runs.back()) {
        if (run.text.empty()) {
          run_x = run_right;
          continue;
        }

        float char_x = run_x;
        size_t cluster_start = 0;
        const size_t source_line = runSourceLine(vl, run);

        while (cluster_start < run.text.length()) {
          size_t cluster_end = UnicodeUtil::nextGraphemeBoundaryColumn(run.text, cluster_start);
          if (cluster_end <= cluster_start) {
            break;
          }
          U16String grapheme = run.text.substr(cluster_start, cluster_end - cluster_start);
          float char_width = measureWidth(grapheme, run.style.font_style);

          // If click is left of cluster center, place on this cluster; else next cluster boundary.
          if (click_x < char_x + char_width * 0.5f) {
            return {source_line, run.column + cluster_start};
          }
          char_x += char_width;
          cluster_start = cluster_end;
        }
        // Click after run end
        return {source_line, run.column + cluster_start};
      }
      run_x = run_right;
    }

    // Click after line end
    for (auto it = vl.runs.rbegin(); it != vl.runs.rend(); ++it) {
      if (isSourceTextRun(*it)) {
        return {runSourceLine(vl, *it), it->column + it->length};
      }
    }
    return {hit_line, line_text.length()};
  }

  HitTarget TextLayout::hitTestDecoration(const PointF& screen_point) {
    if (m_document_ == nullptr) {
      return {};
    }
    if (screen_point.x < 0.0f || screen_point.y < 0.0f
        || screen_point.x >= m_viewport_.width || screen_point.y >= m_viewport_.height) {
      return {};
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return {};
    }

    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    const float split_x = m_layout_metrics_.gutterWidth();
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float line_height = getLineHeight();
    const float abs_y = screen_point.y + scroll_y;

    // Find hit logical line (skip fold-hidden lines)
    size_t hit_line = findHitLine(abs_y);

    const LogicalLine& ll = logical_lines[hit_line];

    // Detect click in gutter area (line number area)
    if (screen_point.x < split_x) {
      const float line_top_screen = getGutterOwnerTopScreen(ll, scroll_y);
      const float icon_size = m_layout_metrics_.font_height;
      const float marker_height = m_layout_metrics_.font_height;
      const float item_top = line_top_screen + std::max(0.0f, (line_height - marker_height) * 0.5f);

      // Fold marker hit-test
      const bool show_fold_arrows = m_layout_metrics_.shouldShowFoldArrows();
      const int fold_state = m_decoration_manager_->getFoldStateForLine(hit_line);
      if (show_fold_arrows && fold_state != 0) {
        const float fold_width = m_layout_metrics_.foldArrowAreaWidth();
        if (fold_width > 0) {
          const float fold_left = split_x - m_layout_metrics_.line_number_margin - fold_width;
          if (screen_point.x >= fold_left && screen_point.x < fold_left + fold_width &&
              screen_point.y >= item_top && screen_point.y < item_top + marker_height) {
            return {HitTargetType::FOLD_GUTTER, hit_line, 0, 0};
          }
        }
      }

      // Gutter icon hit-test
      const auto& gutter_icons = m_decoration_manager_->getLineGutterIcons(hit_line);
      if (!gutter_icons.empty() && icon_size > 0 &&
          screen_point.y >= item_top && screen_point.y < item_top + icon_size) {
        if (m_layout_metrics_.max_gutter_icons == 0) {
          const float icon_left = m_layout_metrics_.line_number_margin;
          if (screen_point.x >= icon_left && screen_point.x < icon_left + icon_size) {
            return {HitTargetType::GUTTER_ICON, hit_line, 0, gutter_icons[0].icon_id};
          }
        } else {
          const size_t max_icons = std::min(static_cast<size_t>(m_layout_metrics_.max_gutter_icons), gutter_icons.size());
          const float fold_lane_left = split_x - m_layout_metrics_.line_number_margin - m_layout_metrics_.foldArrowAreaWidth();
          float icon_right = show_fold_arrows ? fold_lane_left : (split_x - 2.0f);
          for (size_t idx = 0; idx < max_icons; ++idx) {
            const size_t icon_index = max_icons - 1 - idx;
            const float icon_left = icon_right - icon_size;
            if (screen_point.x >= icon_left && screen_point.x < icon_right) {
              return {HitTargetType::GUTTER_ICON, hit_line, 0, gutter_icons[icon_index].icon_id};
            }
            icon_right -= icon_size;
          }
        }
      }

      // If fold arrows are hidden, keep legacy behavior: click in gutter toggles fold line
      if (!show_fold_arrows && fold_state != 0) {
        return {HitTargetType::FOLD_GUTTER, hit_line, 0, 0};
      }
      return {};
    }

    // Find hit VisualLine (wrapped subline)
    size_t target_wrap = findHitWrapIndex(ll, abs_y, line_height);

    const VisualLine& vl = ll.visual_lines[target_wrap];

    // Compute relative click x inside the line
    float click_x;
    if (m_wrap_mode_ != WrapMode::NONE) {
      click_x = screen_point.x - text_area_x;
    } else {
      click_x = screen_point.x - text_area_x + scroll_x;
    }

    // Iterate runs to check hit on InlayHint, FoldPlaceholder, CodeLens, or Link.
    float run_x = 0;
    for (const VisualRun& run : vl.runs) {
      float run_right = run_x + run.width;

      if (run.type == VisualRunType::FOLD_PLACEHOLDER) {
        if (click_x >= run_x && click_x < run_right) {
          return {HitTargetType::FOLD_PLACEHOLDER, hit_line, run.column, 0};
        }
      } else if (run.type == VisualRunType::INLAY_HINT) {
        if (click_x >= run_x && click_x < run_right) {
          if (run.color_value != 0) {
            return {HitTargetType::INLAY_HINT_COLOR, hit_line, run.column, 0, run.color_value};
          } else if (run.icon_id > 0) {
            return {HitTargetType::INLAY_HINT_ICON, hit_line, run.column, run.icon_id};
          } else {
            return {HitTargetType::INLAY_HINT_TEXT, hit_line, run.column, 0};
          }
        }
      } else if (run.type == VisualRunType::CODELENS) {
        if (click_x >= run_x && click_x < run_right) {
          return {HitTargetType::CODELENS, hit_line, run.column, run.icon_id};
        }
      } else if (run.type == VisualRunType::LINK) {
        if (click_x >= run_x && click_x < run_right) {
          const size_t source_line = runSourceLine(vl, run);
          const LinkSpan* link = m_decoration_manager_->findLinkAt(source_line, run.column);
          if (link != nullptr) {
            return {HitTargetType::LINK, source_line, link->column, 0};
          }
        }
      }

      run_x = run_right;
    }

    return {};
  }

  PointF TextLayout::getPositionScreenCoord(const TextPosition& position,
                                            CaretAffinity affinity) {
    if (m_document_ == nullptr) {
      return {0, 0};
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (position.line >= logical_lines.size()) {
      return {0, 0};
    }

    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    const float text_area_x = m_layout_metrics_.textAreaX();

    const U16String& source_text = m_document_->getLineU16TextRef(position.line);
    size_t target_col = std::min(position.column, source_text.length());
    size_t owner_line = position.line;
    if (!resolveSourceVisualOwnerLine(position.line, target_col, target_col, true, owner_line)) {
      const FoldRegion* fold_region = m_decoration_manager_ != nullptr
          ? m_decoration_manager_->getFoldRegionForLine(position.line)
          : nullptr;
      if (fold_region != nullptr && fold_region->start_line < logical_lines.size()) {
        return getPositionScreenCoord({fold_region->start_line, m_document_->getLineColumns(fold_region->start_line)});
      }
      return {0, 0};
    }

    LogicalLine& owner_ll = logical_lines[owner_line];
    layoutLine(owner_line, owner_ll);
    const bool projected = owner_line != position.line;
    const float scroll_offset = (m_wrap_mode_ == WrapMode::NONE) ? scroll_x : 0.0f;

    if (target_col > 0 || projected) {
      for (const VisualLine& vl : owner_ll.visual_lines) {
        float x_offset = 0;
        const bool allow_line_end = m_wrap_mode_ == WrapMode::NONE
            || affinity == CaretAffinity::UPSTREAM;
        if (columnToVisualLineX(vl,
                                position.line,
                                target_col,
                                allow_line_end,
                                x_offset)) {
          return {text_area_x + x_offset - scroll_offset, vl.line_number_position.y - scroll_y};
        }
      }

      for (auto it = owner_ll.visual_lines.rbegin(); it != owner_ll.visual_lines.rend(); ++it) {
        size_t vl_col_min = SIZE_MAX;
        size_t vl_col_max = 0;
        float vl_width = 0;
        if (getVisualLineTextColumnExtent(*it, position.line, vl_col_min, vl_col_max, vl_width)) {
          return {text_area_x + vl_width - scroll_offset, it->line_number_position.y - scroll_y};
        }
      }

      if (!owner_ll.visual_lines.empty()) {
        const VisualLine& last_vl = owner_ll.visual_lines.back();
        float vl_width = 0;
        for (const VisualRun& run : last_vl.runs) {
          vl_width += run.width;
        }
        return {text_area_x + vl_width - scroll_offset, last_vl.line_number_position.y - scroll_y};
      }
    }

    float screen_y = getGutterOwnerTopScreen(owner_ll, scroll_y);
    return {text_area_x - (m_wrap_mode_ == WrapMode::NONE ? scroll_x : 0), screen_y};
  }

  void TextLayout::resolveColumnXRange(size_t line, size_t col_start, size_t col_end,
                                      float& out_x_start, float& out_x_end) {
    if (m_document_ == nullptr) {
      out_x_start = out_x_end = 0;
      return;
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (line >= logical_lines.size()) {
      out_x_start = out_x_end = 0;
      return;
    }

    const float scroll_x = m_view_state_.scroll_x;
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float scroll_offset = (m_wrap_mode_ == WrapMode::NONE) ? scroll_x : 0.0f;

    const U16String& line_text = m_document_->getLineU16TextRef(line);
    size_t safe_start = std::min(col_start, line_text.length());
    size_t safe_end = std::min(col_end, line_text.length());

    if (safe_start > safe_end) std::swap(safe_start, safe_end);

    size_t owner_line = line;
    if (!resolveSourceVisualOwnerLine(line, safe_start, safe_end, true, owner_line)) {
      out_x_start = out_x_end = 0;
      return;
    }

    LogicalLine& ll = logical_lines[owner_line];
    layoutLine(owner_line, ll);
    const bool projected = owner_line != line;
    bool found_start = (!projected && safe_start == 0);
    bool found_end = (!projected && safe_end == 0);
    float x_start = 0;
    float x_end = 0;
    float last_x = 0;
    for (const VisualLine& vl : ll.visual_lines) {
      size_t vl_col_min = SIZE_MAX;
      size_t vl_col_max = 0;
      float vl_width = 0;
      bool has_text = getVisualLineTextColumnExtent(vl, line, vl_col_min, vl_col_max, vl_width);
      if (!has_text) continue;
      last_x = vl_width;

      if (!found_start && safe_start >= vl_col_min && safe_start < vl_col_max) {
        found_start = columnToVisualLineX(vl, line, safe_start, false, x_start);
      }
      if (!found_end && safe_end >= vl_col_min && safe_end <= vl_col_max) {
        found_end = columnToVisualLineX(vl, line, safe_end, true, x_end);
      }
      if (found_start && found_end) break;
    }

    if (!found_start) x_start = last_x;
    if (!found_end) x_end = last_x;

    out_x_start = text_area_x + x_start - scroll_offset;
    out_x_end = text_area_x + x_end - scroll_offset;
  }

  void TextLayout::getColumnScreenRange(size_t line, size_t col_start, size_t col_end,
                                         float& out_x_start, float& out_x_end, float& out_y) {
    resolveColumnXRange(line, col_start, col_end, out_x_start, out_x_end);
    out_y = getPositionScreenCoord({line, col_start}).y;
  }

  void TextLayout::getColumnSelectionRects(size_t line, size_t col_start, size_t col_end,
                                            float rect_height, Vector<Rect>& out_rects) {
    if (m_document_ == nullptr) return;
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (line >= logical_lines.size()) return;

    const U16String& line_text = m_document_->getLineU16TextRef(line);
    size_t safe_start = std::min(col_start, line_text.length());
    size_t safe_end = std::min(col_end, line_text.length());
    if (safe_start > safe_end) std::swap(safe_start, safe_end);
    if (safe_start == safe_end) return;

    size_t owner_line = line;
    if (!resolveSourceVisualOwnerLine(line, safe_start, safe_end, true, owner_line)) {
      return;
    }

    LogicalLine& ll = logical_lines[owner_line];
    layoutLine(owner_line, ll);

    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float scroll_offset = (m_wrap_mode_ == WrapMode::NONE) ? scroll_x : 0.0f;

    for (const VisualLine& vl : ll.visual_lines) {
      size_t vl_col_min = SIZE_MAX;
      size_t vl_col_max = 0;
      float vl_width = 0;
      bool has_text = getVisualLineTextColumnExtent(vl, line, vl_col_min, vl_col_max, vl_width);
      if (!has_text) continue;

      size_t intersect_start = std::max(safe_start, vl_col_min);
      size_t intersect_end = std::min(safe_end, vl_col_max);
      if (intersect_start >= intersect_end) continue;

      float x_start = 0;
      float x_end = 0;
      bool found_start = columnToVisualLineX(vl, line, intersect_start, false, x_start);
      bool found_end = columnToVisualLineX(vl, line, intersect_end, true, x_end);
      if (!found_start) x_start = vl_width;
      if (!found_end) x_end = vl_width;

      Rect rect;
      rect.origin = {text_area_x + x_start - scroll_offset,
                     vl.line_number_position.y - scroll_y};
      rect.width = x_end - x_start;
      rect.height = rect_height;
      out_rects.push_back(rect);
    }
  }

  float TextLayout::getLineHeight() const {
    return m_layout_metrics_.font_height * m_layout_metrics_.line_spacing_mult + m_layout_metrics_.line_spacing_add;
  }

  TextLayout::ContentMetrics TextLayout::computeContentMetrics_() {
    if (!m_content_metrics_dirty_) {
      return m_content_metrics_cache_;
    }
    ContentMetrics metrics;
    if (m_document_ == nullptr) return metrics;
    Vector<LogicalLine>& lines = m_document_->getLogicalLines();
    if (lines.empty()) return metrics;

    // max_line_width needs all lines (runs only when dirty; cached between updates)
    float max_width = 0;
    for (size_t i = 0; i < lines.size(); ++i) {
      layoutLine(i, lines[i]);
      for (const VisualLine& vl : lines[i].visual_lines) {
        float line_width = 0;
        for (const VisualRun& run : vl.runs) {
          line_width += run.width;
        }
        max_width = std::max(max_width, line_width);
      }
    }

    // content_height comes from prefix index (layoutLine already ensures valid line heights)
    const size_t last_idx = lines.size() - 1;
    metrics.content_height = m_line_prefix_y_[last_idx] + lines[last_idx].height;
    metrics.max_line_width = max_width;

    m_content_metrics_cache_ = metrics;
    m_content_metrics_dirty_ = false;
    return metrics;
  }

  TextLayout::ContentMetrics TextLayout::estimateContentMetrics_() {
    PERF_TIMER("estimateContentMetrics_");
    // Cache is clean, return the exact cached value directly
    if (!m_content_metrics_dirty_) {
      return m_content_metrics_cache_;
    }
    size_t line_count = m_document_ ? m_document_->getLogicalLines().size() : 0;
    LOGW("estimateContentMetrics_: dirty=1 lines=%zu prefixDirtyFrom=%zu", line_count, m_prefix_dirty_from_);
    ContentMetrics metrics;
    if (m_document_ == nullptr) return metrics;
    Vector<LogicalLine>& lines = m_document_->getLogicalLines();
    if (lines.empty()) return metrics;

    // content_height: O(1) lookup via prefix index (unlaid-out lines use estimated height)
    const size_t last_idx = lines.size() - 1;
    PERF_BEGIN(prefix);
    ensurePrefixIndexUpTo(last_idx);
    PERF_END(prefix, "estimateContentMetrics_::ensurePrefixIndexUpTo");
    float last_h = (lines[last_idx].height >= 0) ? lines[last_idx].height : getLineHeight();
    metrics.content_height = m_line_prefix_y_[last_idx] + last_h;

    // max_line_width: scan already-laid-out lines (non-empty visual_lines) for max width,
    // O(number of laid-out lines). No new layoutLine calls; also takes max with cached value as fallback
    PERF_BEGIN(width_scan);
    float max_width = m_content_metrics_cache_.max_line_width;
    size_t scanned = 0;
    for (size_t i = 0; i < lines.size(); ++i) {
      if (lines[i].visual_lines.empty()) continue;
      ++scanned;
      for (const VisualLine& vl : lines[i].visual_lines) {
        float line_width = 0;
        for (const VisualRun& run : vl.runs) {
          line_width += run.width;
        }
        max_width = std::max(max_width, line_width);
      }
    }
    PERF_END(width_scan, "estimateContentMetrics_::widthScan");
    LOGW("estimateContentMetrics_: scanned %zu/%zu lines for max_width", scanned, lines.size());
    metrics.max_line_width = max_width;
    return metrics;
  }

  float TextLayout::getContentHeight() {
    return computeContentMetrics_().content_height;
  }

  float TextLayout::getMaxLineWidth() {
    return computeContentMetrics_().max_line_width;
  }

  ScrollBounds TextLayout::getScrollBounds() {
    ScrollBounds bounds;
    bounds.text_area_x = m_layout_metrics_.textAreaX();
    bounds.text_area_width = std::max(0.0f, m_viewport_.width - bounds.text_area_x);

    if (m_document_ == nullptr || !isValidViewportSize(m_viewport_)) {
      return bounds;
    }

    ContentMetrics metrics = estimateContentMetrics_();
    bounds.content_height = metrics.content_height;
    bounds.max_scroll_y = std::max(0.0f, bounds.content_height - m_viewport_.height * 0.25f);

    if (m_wrap_mode_ == WrapMode::NONE) {
      bounds.content_width = metrics.max_line_width;
      float extra = m_layout_metrics_.gutter_sticky ? 0.0f : bounds.text_area_x;
      bounds.max_scroll_x = std::max(0.0f, metrics.max_line_width - bounds.text_area_width + getLineHeight() * 2 + extra);
    } else {
      bounds.content_width = bounds.text_area_width;
      bounds.max_scroll_x = 0;
    }

    return bounds;
  }

  void TextLayout::clampScroll(float& scroll_x, float& scroll_y) {
    if (m_document_ == nullptr || !isValidViewportSize(m_viewport_)) return;

    ScrollBounds bounds = getScrollBounds();
    scroll_y = std::clamp(scroll_y, 0.0f, bounds.max_scroll_y);
    scroll_x = std::clamp(scroll_x, 0.0f, bounds.max_scroll_x);
  }

  void TextLayout::normalizeViewState(ViewState& view_state) {
    clampScroll(view_state.scroll_x, view_state.scroll_y);
    setViewState(view_state);
  }

  void TextLayout::resetMeasurer() {
    PERF_TIMER("resetMeasurer");
    m_text_widths_.clear();
    m_content_metrics_dirty_ = true;
    m_prefix_dirty_from_ = 0;
    FontMetrics metrics = m_measurer_->getFontMetrics();
    m_layout_metrics_.font_height = metrics.descent - metrics.ascent;
    // ascent is negative on most platforms (up is negative); use abs value for baseline-to-top distance
    m_layout_metrics_.font_ascent = -metrics.ascent;
    static const U16String test_chars = CHAR16("iIl1!.,;:W0@");
    static const U16String test_number = CHAR16("9");
    static const U16String test_space = CHAR16(" ");
#ifdef _MSC_VER
    static const size_t test_chars_len = 12;
#else
    static const size_t test_chars_len = test_chars.size();
#endif
    float widths[test_chars_len];
    float sum = 0;
    // Measure width of each character
    for (int i = 0; i < test_chars_len; i++) {
      widths[i] = m_measurer_->measureWidth(test_chars.substr(i, 1), FONT_STYLE_NORMAL);
      sum += widths[i];
    }
    // Compute average width and standard deviation
    float average = sum / test_chars_len;
    float variance = 0;
    for (float w : widths) {
      variance += pow(w - average, 2);
    }
    float std_dev = sqrt(variance / test_chars_len);
    // If std deviation is very small, treat chars as same width
    float tolerance = 0.5f;
    m_is_monospace_ = std_dev < tolerance;
    LOGD("m_is_monospace_: %s", m_is_monospace_ ? "true" : "false");
    m_number_width_ = m_measurer_->measureWidth(test_number, FONT_STYLE_NORMAL);
    m_space_width_ = m_measurer_->measureWidth(test_space, FONT_STYLE_NORMAL);
    // InlayHint background padding: based on font-height ratio
    m_layout_metrics_.inlay_hint_padding = std::round(m_layout_metrics_.font_height * 0.15f);
    // InlayHint margin: spacing from previous/next run
    m_layout_metrics_.inlay_hint_margin = std::round(m_layout_metrics_.font_height * 0.1f);
  }

  LayoutMetrics& TextLayout::getLayoutMetrics() {
    return m_layout_metrics_;
  }

  void TextLayout::invalidateContentMetrics(size_t from_line) {
    m_content_metrics_dirty_ = true;
    invalidatePrefixFrom(from_line);
  }

  bool TextLayout::buildFoldTailProjection(const FoldRegion& region, FoldTailProjection& out_projection) {
    if (m_document_ == nullptr || m_decoration_manager_ == nullptr) {
      return false;
    }
    const auto& lines = m_document_->getLogicalLines();
    if (!region.collapsed || region.end_line <= region.start_line ||
        region.start_line >= lines.size() || region.end_line >= lines.size()) {
      return false;
    }

    const U16String& line_text = m_document_->getLineU16TextRef(region.end_line);
    size_t trim_pos = 0;
    while (trim_pos < line_text.size() &&
           (line_text[trim_pos] == u' ' || line_text[trim_pos] == u'\t')) {
      ++trim_pos;
    }
    if (trim_pos >= line_text.size()) {
      return false;
    }

    out_projection.owner_line = region.start_line;
    out_projection.source_line = region.end_line;
    out_projection.visible_start = trim_pos;
    out_projection.visible_end = line_text.size();
    return true;
  }

  bool TextLayout::resolveFoldTailProjectionForOwnerLine(size_t owner_line,
                                                         FoldTailProjection& out_projection) {
    if (m_document_ == nullptr || m_decoration_manager_ == nullptr) {
      return false;
    }
    const auto& lines = m_document_->getLogicalLines();
    if (owner_line >= lines.size() || lines[owner_line].is_fold_hidden) {
      return false;
    }

    for (const FoldRegion& region : m_decoration_manager_->getFoldRegions()) {
      if (region.start_line != owner_line) {
        continue;
      }
      if (buildFoldTailProjection(region, out_projection)) {
        return true;
      }
    }
    return false;
  }

  bool TextLayout::resolveFoldTailProjectionForSourceLine(size_t source_line,
                                                          FoldTailProjection& out_projection) {
    if (m_document_ == nullptr || m_decoration_manager_ == nullptr) {
      return false;
    }
    const auto& lines = m_document_->getLogicalLines();
    if (source_line >= lines.size() || !lines[source_line].is_fold_hidden) {
      return false;
    }

    bool found = false;
    FoldTailProjection best_projection;
    for (const FoldRegion& region : m_decoration_manager_->getFoldRegions()) {
      if (region.end_line != source_line ||
          region.start_line >= lines.size() || lines[region.start_line].is_fold_hidden) {
        continue;
      }

      FoldTailProjection candidate;
      if (!buildFoldTailProjection(region, candidate)) {
        continue;
      }
      if (!found || candidate.owner_line > best_projection.owner_line) {
        best_projection = candidate;
        found = true;
      }
    }
    if (!found) {
      return false;
    }

    out_projection = best_projection;
    return true;
  }

  bool TextLayout::resolveSourceVisualOwnerLine(size_t source_line,
                                                size_t range_start,
                                                size_t range_end,
                                                bool include_empty_end,
                                                size_t& out_owner_line) {
    if (m_document_ == nullptr) {
      return false;
    }
    const auto& lines = m_document_->getLogicalLines();
    if (source_line >= lines.size()) {
      return false;
    }

    const U16String& line_text = m_document_->getLineU16TextRef(source_line);
    size_t safe_start = std::min(range_start, line_text.size());
    size_t safe_end = std::min(range_end, line_text.size());
    if (safe_start > safe_end) {
      std::swap(safe_start, safe_end);
    }

    if (!lines[source_line].is_fold_hidden) {
      out_owner_line = source_line;
      return true;
    }

    FoldTailProjection projection;
    if (!resolveFoldTailProjectionForSourceLine(source_line, projection)) {
      return false;
    }

    const bool intersects = (safe_start == safe_end)
        ? (include_empty_end
              ? (safe_start >= projection.visible_start && safe_start <= projection.visible_end)
              : (safe_start >= projection.visible_start && safe_start < projection.visible_end))
        : (safe_start < projection.visible_end && safe_end > projection.visible_start);
    if (!intersects) {
      return false;
    }

    out_owner_line = projection.owner_line;
    return true;
  }

  bool TextLayout::isFoldTailProjectedPosition(const TextPosition& position,
                                               bool include_end,
                                               size_t* out_owner_line) {
    FoldTailProjection projection;
    if (!resolveFoldTailProjectionForSourceLine(position.line, projection)) {
      return false;
    }

    const bool inside = include_end
        ? (position.column >= projection.visible_start && position.column <= projection.visible_end)
        : (position.column >= projection.visible_start && position.column < projection.visible_end);
    if (!inside) {
      return false;
    }
    if (out_owner_line != nullptr) {
      *out_owner_line = projection.owner_line;
    }
    return true;
  }

  bool TextLayout::getFoldTailProjectedRange(size_t owner_line, TextRange& out_range) {
    FoldTailProjection projection;
    if (!resolveFoldTailProjectionForOwnerLine(owner_line, projection)) {
      return false;
    }
    out_range = {{projection.source_line, projection.visible_start},
                 {projection.source_line, projection.visible_end}};
    return true;
  }

  void TextLayout::ensurePrefixIndexUpTo(size_t up_to_line) {
    if (m_document_ == nullptr) return;
    Vector<LogicalLine>& lines = m_document_->getLogicalLines();
    if (lines.empty()) return;

    // Limit up_to_line to document line count
    if (up_to_line >= lines.size()) {
      up_to_line = lines.size() - 1;
    }

    // Ensure array capacity (resize when document line count grows)
    if (m_line_prefix_y_.size() != lines.size()) {
      m_line_prefix_y_.resize(lines.size(), 0.0f);
      // If array size changed, rebuild from old dirty start or new range start
      if (m_prefix_dirty_from_ > lines.size()) {
        m_prefix_dirty_from_ = 0;
      }
    }

    // Rebuild prefix from dirty start
    size_t start = m_prefix_dirty_from_;
    if (start > up_to_line) return;  // No dirty data in target range

    // Use default line height as estimated height for never-laid-out lines,
    // to avoid full-document layoutLine just for exact heights.
    // When a line is actually laid out and height changes,
    // invalidatePrefixFrom marks following prefixes dirty.
    const float default_height = getLineHeight();

    // Track long runs of equal-height lines with multiplication.
    // When consecutive lines share the same height (typically default_height for
    // unlaid-out lines after markAllLinesDirty), we compute prefix_y as
    //   run_base_y + run_count * height
    // instead of repeated addition (prefix[i-1] + height).
    // This eliminates O(N) float accumulation error that otherwise grows to
    // ~120 px at line 14000 with non-power-of-two line heights, causing visible
    // viewport jitter during pinch-to-zoom.
    float run_base_y = 0.0f;     // prefix_y where the current same-height run started
    float run_height = 0.0f;     // height value of the current run
    size_t run_count = 0;        // how many lines of run_height have been accumulated

    for (size_t i = start; i <= up_to_line; ++i) {
      if (i == 0) {
        m_line_prefix_y_[0] = 0.0f;
        // Reset run tracking; line 0's height feeds into line 1
        run_base_y = 0.0f;
        run_height = 0.0f;
        run_count = 0;
      } else {
        const LogicalLine& prev = lines[i - 1];
        float h;
        if (prev.height >= 0) {
          h = prev.height;
        } else {
          bool has_codelens = !m_decoration_manager_->getLineCodeLens(i - 1).empty();
          h = has_codelens ? default_height * 2 : default_height;
        }
        if (h == run_height && run_count > 0) {
          // Same height as current run: extend and use multiplication
          run_count++;
          m_line_prefix_y_[i] = run_base_y + static_cast<float>(run_count) * run_height;
        } else {
          // Height changed: start a new run from the previous prefix value
          run_base_y = m_line_prefix_y_[i - 1];
          run_height = h;
          run_count = 1;
          m_line_prefix_y_[i] = run_base_y + h;
        }
      }
    }

    if (m_prefix_dirty_from_ <= up_to_line) {
      m_prefix_dirty_from_ = up_to_line + 1;
    }
  }

  float TextLayout::getLineStartY(size_t line) {
    ensurePrefixIndexUpTo(line);
    if (line < m_line_prefix_y_.size()) {
      return m_line_prefix_y_[line];
    }
    return 0.0f;
  }

  void TextLayout::invalidatePrefixFrom(size_t from_line) {
    m_prefix_dirty_from_ = std::min(m_prefix_dirty_from_, from_line);
  }

  float TextLayout::measureWidth(const U16String& text, int32_t font_style) {
    TextWidthKey key{text, font_style};
    const auto it = m_text_widths_.find(key);
    if (it != m_text_widths_.end()) {
      return it->second;
    }
    float width = m_measurer_->measureWidth(text, font_style);
    m_text_widths_.emplace(std::move(key), width);
    return width;
  }

  VisibleLineInfo TextLayout::resolveVisibleLines() {
    PERF_TIMER("resolveVisibleLines");
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return {};
    }
    const size_t size = logical_lines.size();
    const float scroll_y = m_view_state_.scroll_y;
    const float viewport_bottom = scroll_y + m_viewport_.height;

    // Ensure prefix index covers whole document (no layout trigger; use estimated heights)
    ensurePrefixIndexUpTo(size - 1);

    // Binary search first visible line: smallest i with prefix_y[i] + height[i] > scroll_y
    // Note: prefix index uses estimated heights, so result may be slightly off,
    // and later exact layout will self-correct.
    const float default_height = getLineHeight();
    size_t first_line = 0;
    {
      size_t lo = 0, hi = size;
      while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        float h = (logical_lines[mid].height >= 0) ? logical_lines[mid].height : default_height;
        float line_bottom = m_line_prefix_y_[mid] + h;
        if (line_bottom <= scroll_y) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      first_line = lo < size ? lo : size - 1;
    }

    // Layout first_line exactly (layoutLine will fix start_y and height)
    layoutLine(first_line, logical_lines[first_line]);
    float first_y = m_line_prefix_y_[first_line] - scroll_y;

    // Scan forward from first_line and lay out only visible lines exactly
    size_t last_line = size - 1;
    for (size_t i = first_line; i < size; ++i) {
      layoutLine(i, logical_lines[i]);
      if (m_line_prefix_y_[i] > viewport_bottom) {
        last_line = i > 0 ? i - 1 : 0;
        return {first_line, last_line, first_y};
      }
    }

    return {first_line, last_line, first_y};
  }

  void TextLayout::layoutLineIntoVisualLines(size_t line_index, const U16String& line_text, float start_y,
                                      Vector<VisualLine>& out_visual_lines) {
    float line_height = getLineHeight();
    const float base_start_y = start_y;  // Save original start_y for phantom continuation y calculation

    const auto& line_codelens_items = m_decoration_manager_->getLineCodeLens(line_index);
    const bool has_codelens = !line_codelens_items.empty();
    if (has_codelens) {
      start_y += line_height;
    }

    // Build runs for original line (includes first phantom line segment)
    Vector<VisualRun> all_runs;
    buildLineRuns(line_index, line_text, all_runs);

    // Build content lines first so CodeLens anchors can reuse current visual-column geometry.
    Vector<VisualLine> content_visual_lines;
    const size_t codelens_line_count = has_codelens ? 1 : 0;
    if (m_wrap_mode_ == WrapMode::NONE) {
      VisualLine visual_line = {line_index, codelens_line_count};
      visual_line.line_number_position = {m_layout_metrics_.line_number_margin, start_y};
      visual_line.kind = VisualLineKind::CONTENT;
      visual_line.owns_gutter_semantics = true;
      visual_line.runs = std::move(all_runs);
      content_visual_lines.push_back(std::move(visual_line));
    } else {
      wrapLineRuns(line_index, start_y, line_height, all_runs, content_visual_lines, codelens_line_count);
    }

    if (has_codelens) {
      Vector<CodeLensItem> codelens_items = line_codelens_items;
      std::stable_sort(codelens_items.begin(), codelens_items.end(),
                       [](const CodeLensItem& lhs, const CodeLensItem& rhs) {
                         return lhs.column < rhs.column;
                       });

      auto resolveCodeLensAnchorX = [&](int32_t column) -> float {
        const size_t safe_column = column <= 0
            ? 0
            : std::min(static_cast<size_t>(column), line_text.length());

        float line_end_x = 0;
        bool has_line_end = false;
        for (const VisualLine& vl : content_visual_lines) {
          size_t vl_col_min = SIZE_MAX;
          size_t vl_col_max = 0;
          float vl_width = 0;
          const bool has_text = getVisualLineTextColumnExtent(vl, line_index, vl_col_min, vl_col_max, vl_width);
          if (!has_text) {
            continue;
          }
          if (safe_column >= vl_col_min && safe_column < vl_col_max) {
            float anchor_x = 0;
            if (columnToVisualLineX(vl, line_index, safe_column, false, anchor_x)) {
              return anchor_x;
            }
          }
          if (safe_column == line_text.length() && safe_column == vl_col_max) {
            float anchor_x = 0;
            if (columnToVisualLineX(vl, line_index, safe_column, true, anchor_x)) {
              line_end_x = anchor_x;
              has_line_end = true;
            }
          }
        }
        return has_line_end ? line_end_x : 0.0f;
      };

      VisualLine codelens_vl = {line_index, 0};
      codelens_vl.line_number_position = {m_layout_metrics_.line_number_margin, base_start_y};
      codelens_vl.kind = VisualLineKind::CODELENS;

      static const U16String kSepText = {CHAR16(' '), CHAR16('|'), CHAR16(' ')};
      const float sep_width = measureWidth(kSepText, FONT_STYLE_NORMAL);
      float run_x = 0;
      for (size_t ci = 0; ci < codelens_items.size(); ++ci) {
        const CodeLensItem& codelens_item = codelens_items[ci];
        if (ci > 0) {
          VisualRun sep;
          sep.type = VisualRunType::TEXT;
          sep.column = 0;
          sep.length = 0;
          sep.x = run_x;
          sep.text = kSepText;
          sep.width = sep_width;
          run_x += sep.width;
          codelens_vl.runs.push_back(std::move(sep));
        }

        const float anchor_x = std::max(0.0f, resolveCodeLensAnchorX(codelens_item.column));
        if (anchor_x > run_x) {
          VisualRun spacer;
          spacer.type = VisualRunType::WHITESPACE;
          spacer.column = codelens_item.column <= 0 ? 0 : static_cast<size_t>(codelens_item.column);
          spacer.length = 0;
          spacer.x = run_x;
          spacer.width = anchor_x - run_x;
          run_x = anchor_x;
          codelens_vl.runs.push_back(std::move(spacer));
        }

        VisualRun cl_run;
        cl_run.type = VisualRunType::CODELENS;
        cl_run.column = codelens_item.column <= 0 ? 0 : static_cast<size_t>(codelens_item.column);
        cl_run.length = 0;
        cl_run.x = run_x;
        cl_run.icon_id = codelens_item.command_id;
        U16String cl_u16;
        StrUtil::convertUTF8ToUTF16(codelens_item.text, cl_u16);
        cl_run.text = std::move(cl_u16);
        cl_run.width = cl_run.text.empty() ? 0 : measureWidth(cl_run.text, FONT_STYLE_NORMAL);
        run_x += cl_run.width;
        codelens_vl.runs.push_back(std::move(cl_run));
      }

      out_visual_lines.push_back(std::move(codelens_vl));
    }

    for (auto& visual_line : content_visual_lines) {
      out_visual_lines.push_back(std::move(visual_line));
    }

    // Handle cross-line phantom text continuation (2nd, 3rd... lines), each segment also wraps
    const auto& phantom_texts = m_decoration_manager_->getLinePhantomTexts(line_index);
    for (const auto& phantom : phantom_texts) {
      size_t nl_pos = phantom.text.find('\n');
      if (nl_pos == U8String::npos) continue;

      // Split continuation lines by \n
      U8String remaining = phantom.text.substr(nl_pos + 1);
      while (!remaining.empty()) {
        U8String seg;
        size_t next_nl = remaining.find('\n');
        if (next_nl != U8String::npos) {
          seg = remaining.substr(0, next_nl);
          remaining = remaining.substr(next_nl + 1);
        } else {
          seg = remaining;
          remaining.clear();
        }

        // Build one PHANTOM_TEXT run for this continuation line
        size_t base_wrap_idx = out_visual_lines.size();
        float seg_y = base_start_y + base_wrap_idx * line_height;

        VisualRun run;
        run.type = VisualRunType::PHANTOM_TEXT;
        run.column = phantom.column;
        run.length = 0;

        run.style.font_style = FONT_STYLE_ITALIC;
        U16String seg_u16;
        StrUtil::convertUTF8ToUTF16(seg, seg_u16);
        run.text = std::move(seg_u16);
        run.width = run.text.empty() ? 0 : measureWidth(run.text, FONT_STYLE_ITALIC);

        if (m_wrap_mode_ == WrapMode::NONE) {
          // No wrap: generate one phantom VisualLine directly
          VisualLine phantom_vl = {line_index, base_wrap_idx};
          phantom_vl.line_number_position = {m_layout_metrics_.line_number_margin, seg_y};
          phantom_vl.kind = VisualLineKind::PHANTOM;
          phantom_vl.runs.push_back(std::move(run));
          out_visual_lines.push_back(std::move(phantom_vl));
        } else {
          // Wrap mode: phantom continuation line also goes through wrapLineRuns
          Vector<VisualRun> seg_runs;
          seg_runs.push_back(std::move(run));
          Vector<VisualLine> wrapped_lines;
          wrapLineRuns(line_index, seg_y, line_height, seg_runs, wrapped_lines);
          // Fix wrap_index and mark as phantom lines
          for (auto& wl : wrapped_lines) {
            wl.wrap_index = out_visual_lines.size();
            wl.kind = VisualLineKind::PHANTOM;
            wl.owns_gutter_semantics = false;
            wl.line_number_position.y = base_start_y + wl.wrap_index * line_height;
            out_visual_lines.push_back(std::move(wl));
          }
        }
      }
    }
  }

  void TextLayout::buildLineRuns(size_t line_index, const U16String& line_text, Vector<VisualRun>& runs) {
    const auto merged_spans = m_decoration_manager_->getMergedLineSpans(line_index);
    const auto& inlay_hints = m_decoration_manager_->getLineInlayHints(line_index);
    const auto& phantom_texts = m_decoration_manager_->getLinePhantomTexts(line_index);
    const auto& links = m_decoration_manager_->getLineLinks(line_index);

    const size_t text_len = line_text.length();

    // Helper: split a TEXT run by tab characters, emitting TEXT and TAB runs
    auto splitTabsInRun = [&](const VisualRun& src_run, size_t& current_column) {
      const U16String& t = src_run.text;
      size_t pos = 0;
      while (pos < t.length()) {
        size_t tab_pos = t.find(u'	', pos);
        if (tab_pos == U16String::npos) tab_pos = t.length();
        if (tab_pos > pos) {
          VisualRun text_part;
          text_part.type = src_run.type;
          text_part.column = src_run.column + static_cast<uint32_t>(pos);
          text_part.length = tab_pos - pos;
          text_part.style = src_run.style;
          text_part.source_line = src_run.source_line;
          text_part.text = t.substr(pos, tab_pos - pos);
          text_part.width = measureWidth(text_part.text, text_part.style.font_style);
          runs.push_back(text_part);
          current_column += text_part.length;
        }
        if (tab_pos < t.length()) {
          uint32_t spaces = m_tab_size_ - (current_column % m_tab_size_);
          VisualRun tab_run;
          tab_run.type = VisualRunType::TAB;
          tab_run.column = src_run.column + static_cast<uint32_t>(tab_pos);
          tab_run.length = 1;
          tab_run.style = src_run.style;
          tab_run.source_line = src_run.source_line;
          tab_run.width = spaces * m_space_width_;
          runs.push_back(tab_run);
          current_column += 1;
          pos = tab_pos + 1;
        } else {
          break;
        }
      }
    };

    // If there is no decoration, generate runs directly (split tabs)
    if (merged_spans.empty() && inlay_hints.empty() && phantom_texts.empty() && links.empty()) {
      VisualRun run = {VisualRunType::TEXT, 0, text_len};
      run.style.font_style = FONT_STYLE_NORMAL;
      run.text = line_text;
      if (line_text.find(u'	') != U16String::npos) {
        size_t col = 0;
        splitTabsInRun(run, col);
      } else {
        run.width = measureWidth(line_text, FONT_STYLE_NORMAL);
        runs.push_back(run);
      }
      return;
    }

    // Collect all split points (column boundaries)
    // Sources: span [column, column+length), inlay_hint column, phantom_text column
    HashSet<uint32_t> split_set;
    split_set.insert(0);
    split_set.insert(static_cast<uint32_t>(text_len));
    for (const auto& span : merged_spans) {
      split_set.insert(span.column);
      uint32_t end_col = std::min(span.column + span.length, static_cast<uint32_t>(text_len));
      split_set.insert(end_col);
    }
    for (const auto& hint : inlay_hints) {
      if (hint.column <= text_len) {
        split_set.insert(hint.column);
      }
    }
    for (const auto& phantom : phantom_texts) {
      if (phantom.column <= text_len) {
        split_set.insert(phantom.column);
      }
    }
    for (const auto& link : links) {
      if (link.column <= text_len) {
        split_set.insert(link.column);
        uint32_t end_col = std::min(link.column + link.length, static_cast<uint32_t>(text_len));
        split_set.insert(end_col);
      }
    }

    // Sort split points
    Vector<uint32_t> splits(split_set.begin(), split_set.end());
    std::sort(splits.begin(), splits.end());

    // For faster span lookup, preprocess: find covering span for each column
    // spans are assumed sorted by column and may overlap; use simple linear match here
    auto findSpanStyle = [&](uint32_t col) -> TextStyle {
      for (const auto& span : merged_spans) {
        if (col >= span.column && col < span.column + span.length) {
          return m_decoration_manager_->getTextStyleRegistry()->getStyle(span.style_id);
        }
      }
      return {};
    };

    auto findLink = [&](uint32_t col) -> const LinkSpan* {
      for (const auto& link : links) {
        if (col >= link.column && col < link.column + link.length) {
          return &link;
        }
      }
      return nullptr;
    };

    // Helper to build InlayHint VisualRun
    auto makeInlayHintRun = [&](const InlayHint& hint) -> VisualRun {
      VisualRun run;
      run.type = VisualRunType::INLAY_HINT;
      run.column = hint.column;
      run.length = 0;
      run.padding = m_layout_metrics_.inlay_hint_padding;
      run.margin = m_layout_metrics_.inlay_hint_margin;
      run.style.font_style = FONT_STYLE_NORMAL;
      if (hint.type == InlayType::TEXT) {
        U16String hint_u16;
        StrUtil::convertUTF8ToUTF16(hint.text, hint_u16);
        run.text = std::move(hint_u16);
        run.width = m_measurer_->measureInlayHintWidth(run.text) + run.padding * 2 + run.margin * 2;
      } else if (hint.type == InlayType::COLOR) {
        run.color_value = hint.int_value;
        // Color block is a square: side = font_height, no padding needed
        run.width = m_layout_metrics_.font_height + run.margin * 2;
      } else {
        run.icon_id = hint.int_value;
        run.width = m_measurer_->measureIconWidth(hint.int_value) + run.padding * 2 + run.margin * 2;
      }
      return run;
    };

    // Helper to build PhantomText VisualRun (first line only, before \n)
    auto makePhantomTextRun = [&](const PhantomText& phantom) -> VisualRun {
      VisualRun run;
      run.type = VisualRunType::PHANTOM_TEXT;
      run.column = phantom.column;
      run.length = 0;
      run.style.font_style = FONT_STYLE_ITALIC;
      U8String first_line_text = phantom.text;
      size_t nl_pos = phantom.text.find('\n');
      if (nl_pos != U8String::npos) {
        first_line_text = phantom.text.substr(0, nl_pos);
      }
      U16String phantom_u16;
      StrUtil::convertUTF8ToUTF16(first_line_text, phantom_u16);
      run.text = std::move(phantom_u16);
      run.width = run.text.empty() ? 0 : measureWidth(run.text, FONT_STYLE_ITALIC);
      return run;
    };

    size_t hint_idx = 0;
    size_t phantom_idx = 0;

    for (size_t i = 0; i + 1 < splits.size(); ++i) {
      uint32_t seg_start = splits[i];
      uint32_t seg_end = splits[i + 1];

      // At this column, insert all inlay_hint and phantom_text first
      while (hint_idx < inlay_hints.size() && inlay_hints[hint_idx].column == seg_start) {
        runs.push_back(makeInlayHintRun(inlay_hints[hint_idx]));
        ++hint_idx;
      }
      while (phantom_idx < phantom_texts.size() && phantom_texts[phantom_idx].column == seg_start) {
        runs.push_back(makePhantomTextRun(phantom_texts[phantom_idx]));
        ++phantom_idx;
      }

      // Build source TEXT segment (if seg_start < seg_end, there is real text)
      if (seg_start < seg_end && seg_start < text_len) {
        uint32_t actual_end = std::min(seg_end, static_cast<uint32_t>(text_len));
        VisualRun text_run;
        text_run.type = findLink(seg_start) != nullptr ? VisualRunType::LINK : VisualRunType::TEXT;
        text_run.column = seg_start;
        text_run.length = actual_end - seg_start;
        text_run.style = findSpanStyle(seg_start);
        text_run.text = line_text.substr(seg_start, actual_end - seg_start);
        if (text_run.text.find(u'	') != U16String::npos) {
          size_t col = seg_start;
          splitTabsInRun(text_run, col);
        } else {
          text_run.width = measureWidth(text_run.text, text_run.style.font_style);
          runs.push_back(text_run);
        }
      }
    }

    // Handle trailing inlay_hint and phantom_text (column == text_len)
    while (hint_idx < inlay_hints.size()) {
      runs.push_back(makeInlayHintRun(inlay_hints[hint_idx]));
      ++hint_idx;
    }
    while (phantom_idx < phantom_texts.size()) {
      runs.push_back(makePhantomTextRun(phantom_texts[phantom_idx]));
      ++phantom_idx;
    }
  }

  void TextLayout::cropVisualLineRuns(VisualLine& visual_line, float scroll_x) {
    const float text_area_x = m_layout_metrics_.textAreaX();
    // Expand crop bounds outward to keep a few extra chars, so crop points stay under
    // line-number background cover and avoid render jitter from char-level cropping
    const float crop_margin = text_area_x;
    const float visible_left = scroll_x - crop_margin;
    const float visible_right = scroll_x + m_viewport_.width - text_area_x + crop_margin;
    float current_x = 0; // Logical x relative to text area start

    auto run_it = visual_line.runs.begin();
    while (run_it != visual_line.runs.end()) {
      VisualRun& run = *run_it;
      const float run_left = current_x;
      const float run_right = current_x + run.width;

      // Whole run is left of visible area; remove it
      if (run_right <= visible_left) {
        current_x = run_right;
        run_it = visual_line.runs.erase(run_it);
        continue;
      }

      // Whole run is right of visible area; remove all following runs
      if (run_left >= visible_right) {
        visual_line.runs.erase(run_it, visual_line.runs.end());
        break;
      }

      // Set screen x (can be negative; overflow is covered by platform line-number background)
      run.x = text_area_x + run_left - scroll_x;

      // Decorator and marker runs are atomic for viewport cropping.
      if (run.type == VisualRunType::INLAY_HINT || run.type == VisualRunType::TAB
          || run.type == VisualRunType::CODELENS || run.type == VisualRunType::NEWLINE) {
        current_x = run_right;
        ++run_it;
        continue;
      }

      // TEXT / PHANTOM_TEXT: crop only when run clearly crosses bounds, keep margin
      bool need_crop_left = (run_left < visible_left);
      bool need_crop_right = (run_right > visible_right);
      const bool updates_source_range = isSourceTextRun(run) && run.length > 0;

      if (need_crop_left || need_crop_right) {
        if (m_is_monospace_ && run.length > 0 && !UnicodeUtil::hasComplexGrapheme(run.text)) {
          float char_width = run.width / run.length;
          if (char_width > 0) {
            size_t skip_left = 0;
            size_t skip_right = 0;
            if (need_crop_left) {
              skip_left = static_cast<size_t>((visible_left - run_left) / char_width);
              if (skip_left > run.length) skip_left = run.length;
            }
            if (need_crop_right) {
              float right_excess = run_right - visible_right;
              skip_right = static_cast<size_t>(right_excess / char_width);
              if (skip_right > run.length - skip_left) skip_right = run.length - skip_left;
            }
            size_t visible_start = skip_left;
            size_t visible_len = run.length - skip_left - skip_right;
            size_t visible_end = visible_start + visible_len;

            visible_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(run.text, visible_start);
            visible_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(run.text, visible_end);
            visible_len = (visible_end > visible_start) ? (visible_end - visible_start) : 0;

            if (visible_len == 0) {
              current_x = run_right;
              run_it = visual_line.runs.erase(run_it);
              continue;
            }
            if (visible_start > 0 || visible_len < run.length) {
              float crop_offset = visible_start > 0
                  ? measureWidth(run.text.substr(0, visible_start), run.style.font_style) : 0;
              run.x = text_area_x + (run_left + crop_offset) - scroll_x;
              if (updates_source_range) {
                run.column += visible_start;
                run.length = visible_len;
              }
              run.text = run.text.substr(visible_start, visible_len);
              run.width = measureWidth(run.text, run.style.font_style);
            }
          }
        } else {
          // Non-monospace font: crop grapheme by grapheme
          size_t start_u16_index = 0;
          size_t end_u16_index = run.text.length();
          size_t current_u16_index = 0;
          float char_x = run_left;
          float crop_start_x = run_left;
          bool found_start = !need_crop_left;

          while (current_u16_index < run.text.length()) {
            size_t next_u16_index = UnicodeUtil::nextGraphemeBoundaryColumn(run.text, current_u16_index);
            if (next_u16_index <= current_u16_index) {
              break;
            }
            U16String u16_char_text = run.text.substr(current_u16_index, next_u16_index - current_u16_index);
            float char_width = measureWidth(u16_char_text, run.style.font_style);

            if (!found_start) {
              if (char_x + char_width > visible_left) {
                start_u16_index = current_u16_index;
                crop_start_x = char_x;
                found_start = true;
              }
            }
            if (found_start && char_x + char_width > visible_right) {
              end_u16_index = next_u16_index;
              break;
            }
            char_x += char_width;
            current_u16_index = next_u16_index;
          }

          if (!found_start || start_u16_index >= end_u16_index) {
            current_x = run_right;
            run_it = visual_line.runs.erase(run_it);
            continue;
          }

          if (start_u16_index > 0 || end_u16_index < run.text.length()) {
            run.x = text_area_x + crop_start_x - scroll_x;
            if (updates_source_range) {
              run.column += start_u16_index;
              run.length = end_u16_index - start_u16_index;
            }
            run.text = run.text.substr(start_u16_index, end_u16_index - start_u16_index);
            run.width = measureWidth(run.text, run.style.font_style);
          }
        }
      }

      current_x = run_right;
      ++run_it;
    }
  }

  void TextLayout::applyPresentationState(VisualLine& visual_line,
                                          const PresentationContext& presentation_context) {
    const EditorRenderColors& colors = presentation_context.render_colors;

    Vector<VisualRun> runs;
    bool has_split = false;
    HashMap<size_t, Vector<TextPresentationEffect>> line_effect_cache;

    auto ensure_runs = [&](size_t current_index) {
      if (has_split) return;
      runs.reserve(visual_line.runs.size() + 2);
      runs.insert(runs.end(), visual_line.runs.begin(), visual_line.runs.begin() + current_index);
      has_split = true;
    };

    auto get_line_effects = [&](size_t source_line) -> const Vector<TextPresentationEffect>& {
      auto it = line_effect_cache.find(source_line);
      if (it != line_effect_cache.end()) {
        return it->second;
      }

      Vector<TextPresentationEffect> effects;
      if (presentation_context.collect_text_effects) {
        presentation_context.collect_text_effects(source_line, effects);
      }
      auto inserted = line_effect_cache.emplace(source_line, std::move(effects));
      return inserted.first->second;
    };

    auto is_active_run = [&](const VisualRun& run) {
      const HitTarget& active_hit_target = presentation_context.active_hit_target;
      if (active_hit_target.type == HitTargetType::NONE) return false;
      const size_t source_line = runSourceLine(visual_line, run);
      if (source_line != active_hit_target.line) return false;

      if (run.type == VisualRunType::CODELENS) {
        return run.column == active_hit_target.column
            && run.icon_id == active_hit_target.icon_id;
      }
      if (run.type == VisualRunType::LINK) {
        const LinkSpan* link = m_decoration_manager_->findLinkAt(source_line, run.column);
        return link != nullptr && link->column == active_hit_target.column;
      }
      return false;
    };

    auto apply_foreground = [&](VisualRun& run) {
      int32_t role_color = 0;
      if (run.type == VisualRunType::LINK) {
        role_color = run.active && colors.active_link_foreground != 0
            ? colors.active_link_foreground : colors.link_foreground;
      } else if (run.type == VisualRunType::CODELENS) {
        role_color = run.active && colors.active_codelens_foreground != 0
            ? colors.active_codelens_foreground : colors.codelens_foreground;
      }

      if (role_color != 0) {
        run.style.color = role_color;
      } else if (run.style.color == 0 && colors.text_foreground != 0) {
        switch (run.type) {
          case VisualRunType::TEXT:
          case VisualRunType::LINK:
          case VisualRunType::TAB:
          case VisualRunType::CODELENS:
            run.style.color = colors.text_foreground;
            break;
          default:
            break;
        }
      }
    };

    auto collect_effect_segments = [&](const VisualRun& run,
                                       Vector<size_t>& cuts,
                                       const Vector<TextPresentationEffect>*& line_effects) {
      if (!presentation_context.collect_text_effects || !isSourceTextRun(run)
          || run.text.empty() || run.length == 0) {
        return false;
      }

      const size_t source_line = runSourceLine(visual_line, run);
      line_effects = &get_line_effects(source_line);
      if (line_effects->empty()) return false;

      const size_t run_start = run.column;
      const size_t run_end = run.column + run.length;
      bool has_effect = false;
      cuts.clear();
      cuts.push_back(0);
      cuts.push_back(run.text.length());

      for (const TextPresentationEffect& effect : *line_effects) {
        if (source_line < effect.range.start.line || source_line > effect.range.end.line) {
          continue;
        }

        const size_t effect_start = source_line == effect.range.start.line
            ? effect.range.start.column : 0;
        const size_t effect_end = source_line == effect.range.end.line
            ? effect.range.end.column : std::numeric_limits<size_t>::max();
        const size_t intersect_start = std::max(run_start, effect_start);
        const size_t intersect_end = std::min(run_end, effect_end);
        if (intersect_start >= intersect_end) {
          continue;
        }

        size_t local_start = std::min(intersect_start - run_start, run.text.length());
        size_t local_end = std::min(intersect_end - run_start, run.text.length());
        local_start = UnicodeUtil::clampColumnToGraphemeBoundaryLeft(run.text, local_start);
        local_end = UnicodeUtil::clampColumnToGraphemeBoundaryRight(run.text, local_end);
        if (local_start >= local_end) {
          continue;
        }
        cuts.push_back(local_start);
        cuts.push_back(local_end);
        has_effect = true;
      }

      if (!has_effect) return false;
      std::sort(cuts.begin(), cuts.end());
      cuts.erase(std::unique(cuts.begin(), cuts.end()), cuts.end());
      return cuts.size() > 1;
    };

    auto resolve_effect_for_part = [&](const VisualRun& run,
                                       size_t part_start,
                                       size_t part_end,
                                       const Vector<TextPresentationEffect>& line_effects,
                                       int32_t& foreground,
                                       bool& clear_background) {
      foreground = 0;
      clear_background = false;
      uint32_t foreground_priority = 0;
      const size_t source_line = runSourceLine(visual_line, run);
      const size_t source_start = run.column + part_start;
      const size_t source_end = run.column + part_end;

      for (const TextPresentationEffect& effect : line_effects) {
        if (source_line < effect.range.start.line || source_line > effect.range.end.line) {
          continue;
        }
        const size_t effect_start = source_line == effect.range.start.line
            ? effect.range.start.column : 0;
        const size_t effect_end = source_line == effect.range.end.line
            ? effect.range.end.column : std::numeric_limits<size_t>::max();
        if (std::max(source_start, effect_start) >= std::min(source_end, effect_end)) {
          continue;
        }
        if (effect.clear_text_background) {
          clear_background = true;
        }
        if (effect.foreground_color != 0 && effect.priority >= foreground_priority) {
          foreground = effect.foreground_color;
          foreground_priority = effect.priority;
        }
      }
    };

    auto append_part = [&](const VisualRun& run,
                           size_t start,
                           size_t end,
                           int32_t foreground,
                           bool clear_background) {
      if (start >= end) return;
      VisualRun part = run;
      part.column = run.column + start;
      part.length = end - start;
      part.text = run.text.substr(start, end - start);
      const float prefix_width = start == 0
          ? 0.0f : measureWidth(run.text.substr(0, start), run.style.font_style);
      part.x = run.x + prefix_width;
      part.width = measureWidth(part.text, part.style.font_style);
      if (foreground != 0) {
        part.style.color = foreground;
      }
      if (clear_background) {
        part.style.background_color = 0;
      }
      runs.push_back(std::move(part));
    };

    for (size_t index = 0; index < visual_line.runs.size(); ++index) {
      VisualRun& run = visual_line.runs[index];
      run.active = is_active_run(run);
      apply_foreground(run);

      Vector<size_t> cuts;
      const Vector<TextPresentationEffect>* line_effects = nullptr;
      if (!collect_effect_segments(run, cuts, line_effects)) {
        if (has_split) runs.push_back(run);
        continue;
      }

      ensure_runs(index);
      for (size_t cut_index = 0; cut_index + 1 < cuts.size(); ++cut_index) {
        const size_t start = cuts[cut_index];
        const size_t end = cuts[cut_index + 1];
        int32_t foreground = 0;
        bool clear_background = false;
        resolve_effect_for_part(run, start, end, *line_effects, foreground, clear_background);
        append_part(run, start, end, foreground, clear_background);
      }
    }

    if (has_split) {
      visual_line.runs = std::move(runs);
    }

    materializeWhitespaceRuns(visual_line, presentation_context);
  }

  void TextLayout::materializeWhitespaceRuns(VisualLine& visual_line,
                                             const PresentationContext& presentation_context) {
    if (presentation_context.render_whitespace == WhitespaceRenderMode::NONE || visual_line.runs.empty()) {
      return;
    }

    struct LineWhitespaceInfo {
      const U16String* text {nullptr};
      size_t leading_end {0};
      size_t trailing_start {0};
    };

    HashMap<size_t, LineWhitespaceInfo> line_info_cache;
    auto get_line_info = [&](size_t source_line) -> const LineWhitespaceInfo* {
      auto it = line_info_cache.find(source_line);
      if (it != line_info_cache.end()) {
        return &it->second;
      }
      if (m_document_ == nullptr || source_line >= m_document_->getLineCount()) {
        return nullptr;
      }
      const U16String& line_text = m_document_->getLineU16TextRef(source_line);
      LineWhitespaceInfo info;
      info.text = &line_text;
      info.leading_end = TextBoundaryUtil::leadingWhitespaceEndColumn(line_text);
      info.trailing_start = TextBoundaryUtil::trailingWhitespaceStartColumn(line_text);
      auto inserted = line_info_cache.emplace(source_line, info);
      return &inserted.first->second;
    };

    auto is_column_selected = [&](size_t source_line, size_t column) {
      if (!presentation_context.has_selection) return false;
      const TextRange& selection = presentation_context.selection_range;
      if (selection.start == selection.end) return false;
      if (source_line < selection.start.line || source_line > selection.end.line) return false;
      if (selection.start.line == selection.end.line) {
        return column >= selection.start.column && column < selection.end.column;
      }
      if (source_line == selection.start.line) return column >= selection.start.column;
      if (source_line == selection.end.line) return column < selection.end.column;
      return true;
    };

    auto should_render_space = [&](size_t source_line, size_t column) {
      const LineWhitespaceInfo* info = get_line_info(source_line);
      if (info == nullptr || info->text == nullptr) return false;
      const U16String& line_text = *info->text;
      if (column >= line_text.length() || line_text[column] != CHAR16(' ')) return false;
      switch (presentation_context.render_whitespace) {
      case WhitespaceRenderMode::ALL:
        return true;
      case WhitespaceRenderMode::TRAILING:
        return column >= info->trailing_start;
      case WhitespaceRenderMode::SELECTION:
        return is_column_selected(source_line, column);
      case WhitespaceRenderMode::BOUNDARY: {
        if (column < info->leading_end || column >= info->trailing_start) return true;
        const bool prev_space = column > 0 && line_text[column - 1] == CHAR16(' ');
        const bool next_space = column + 1 < line_text.length() && line_text[column + 1] == CHAR16(' ');
        return prev_space || next_space;
      }
      case WhitespaceRenderMode::NONE:
      default:
        return false;
      }
    };

    auto should_render_tab = [&](size_t source_line, size_t column) {
      const LineWhitespaceInfo* info = get_line_info(source_line);
      if (info == nullptr || info->text == nullptr) return false;
      const U16String& line_text = *info->text;
      if (column >= line_text.length() || line_text[column] != CHAR16('\t')) return false;
      switch (presentation_context.render_whitespace) {
      case WhitespaceRenderMode::ALL:
      case WhitespaceRenderMode::BOUNDARY:
        return true;
      case WhitespaceRenderMode::TRAILING:
        return column >= info->trailing_start;
      case WhitespaceRenderMode::SELECTION:
        return is_column_selected(source_line, column);
      case WhitespaceRenderMode::NONE:
      default:
        return false;
      }
    };

    Vector<VisualRun> runs;
    runs.reserve(visual_line.runs.size() + 4);
    bool changed = false;

    auto append_text_part = [&](const VisualRun& run, size_t start, size_t end, VisualRunType type) {
      if (start >= end) return;
      VisualRun part = run;
      part.type = type;
      part.column = run.column + start;
      part.length = end - start;
      part.text = run.text.substr(start, end - start);
      const float prefix_width = start == 0
          ? 0.0f : measureWidth(run.text.substr(0, start), run.style.font_style);
      part.x = run.x + prefix_width;
      part.width = measureWidth(part.text, part.style.font_style);
      runs.push_back(std::move(part));
    };

    for (VisualRun run : visual_line.runs) {
      const size_t source_line = runSourceLine(visual_line, run);
      if (run.type == VisualRunType::TAB) {
        if (should_render_tab(source_line, run.column)) {
          run.text = CHAR16("\t");
          changed = true;
        } else {
          run.text.clear();
        }
        runs.push_back(std::move(run));
        continue;
      }

      if ((run.type != VisualRunType::TEXT && run.type != VisualRunType::LINK) || run.text.empty()) {
        runs.push_back(std::move(run));
        continue;
      }

      size_t segment_start = 0;
      bool segment_marker = false;
      bool has_segment = false;
      for (size_t index = 0; index < run.text.length(); ++index) {
        const bool is_visible_space = run.text[index] == CHAR16(' ')
            && should_render_space(source_line, run.column + index);
        if (!has_segment) {
          segment_start = index;
          segment_marker = is_visible_space;
          has_segment = true;
          continue;
        }
        if (is_visible_space != segment_marker) {
          append_text_part(run, segment_start, index,
                           segment_marker ? VisualRunType::WHITESPACE : run.type);
          changed = changed || segment_marker;
          segment_start = index;
          segment_marker = is_visible_space;
        }
      }

      if (has_segment) {
        append_text_part(run, segment_start, run.text.length(),
                         segment_marker ? VisualRunType::WHITESPACE : run.type);
        changed = changed || segment_marker;
      } else {
        runs.push_back(std::move(run));
      }
    }

    if (changed) {
      visual_line.runs = std::move(runs);
    }
  }

  void TextLayout::wrapLineRuns(size_t line_index, float start_y, float line_height,
                                Vector<VisualRun>& runs, Vector<VisualLine>& out_lines,
                                size_t wrap_index_offset) {
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float wrap_width = m_viewport_.width - text_area_x;
    if (wrap_width <= 0) {
      // Viewport is too small: do not wrap, output single line
      VisualLine vl = {line_index, wrap_index_offset};
      vl.line_number_position = {m_layout_metrics_.line_number_margin, start_y};
      vl.kind = VisualLineKind::CONTENT;
      vl.owns_gutter_semantics = true;
      vl.runs = std::move(runs);
      out_lines.push_back(std::move(vl));
      return;
    }

    size_t wrap_index = wrap_index_offset;
    float current_x = 0; // Accumulated width in current line
    VisualLine current_line = {line_index, wrap_index};
    current_line.line_number_position = {m_layout_metrics_.line_number_margin, start_y};
    current_line.kind = VisualLineKind::CONTENT;
    current_line.owns_gutter_semantics = true;

    for (size_t ri = 0; ri < runs.size(); ++ri) {
      VisualRun& run = runs[ri];

      // For non-TEXT type (INLAY_HINT / TAB), keep as whole and do not split
      if (run.type == VisualRunType::INLAY_HINT || run.type == VisualRunType::TAB) {
        if (current_x + run.width > wrap_width && current_x > 0) {
          // Wrap to next line
          out_lines.push_back(std::move(current_line));
          ++wrap_index;
          float new_y = start_y + wrap_index * line_height;
          current_line = {line_index, wrap_index};
          current_line.line_number_position = {m_layout_metrics_.line_number_margin, new_y};
          current_line.kind = VisualLineKind::CONTENT;
          current_line.owns_gutter_semantics = false;
          current_x = 0;
        }
        run.x = current_x;
        current_x += run.width;
        current_line.runs.push_back(run);
        continue;
      }

      // TEXT / PHANTOM_TEXT: wrap grapheme by grapheme
      const U16String& run_text = run.text;
      if (run_text.empty()) {
        current_line.runs.push_back(run);
        continue;
      }

      // If full run fits, add directly
      if (current_x + run.width <= wrap_width) {
        run.x = current_x;
        current_x += run.width;
        current_line.runs.push_back(run);
        continue;
      }

      // Need to split run
      size_t seg_start_u16 = 0;
      size_t current_u16 = 0;
      float seg_width = 0;
      // In WORD_BREAK mode, record nearest word boundary
      size_t last_word_break_u16 = 0;
      float last_word_break_width = 0;
      bool has_word_break = false;

      while (current_u16 < run_text.length()) {
        const size_t grapheme_end = UnicodeUtil::nextGraphemeBoundaryColumn(run_text, current_u16);
        if (grapheme_end <= current_u16) {
          break;
        }
        const size_t grapheme_u16_len = grapheme_end - current_u16;
        U16String grapheme_text = run_text.substr(current_u16, grapheme_u16_len);
        float char_width = measureWidth(grapheme_text, run.style.font_style);

        // WORD_BREAK mode: check whether there is a word boundary after this grapheme.
        if (m_wrap_mode_ == WrapMode::WORD_BREAK && grapheme_u16_len > 0) {
          U16Char ch = run_text[current_u16];
          if (TextBoundaryUtil::isWordWrapBreakChar(ch)) {
            last_word_break_u16 = grapheme_end;
            last_word_break_width = seg_width + char_width;
            has_word_break = true;
          }
        }

        if (current_x + seg_width + char_width > wrap_width && (seg_start_u16 < current_u16 || current_x > 0)) {
          // Need to break line here
          size_t break_u16;
          float break_width;
          if (m_wrap_mode_ == WrapMode::WORD_BREAK && has_word_break && last_word_break_u16 > seg_start_u16) {
            break_u16 = last_word_break_u16;
            break_width = last_word_break_width;
          } else {
            break_u16 = current_u16;
            break_width = seg_width;
          }

          // Output [seg_start_u16, break_u16) to current line
          if (break_u16 > seg_start_u16) {
            U16String seg_text = run_text.substr(seg_start_u16, break_u16 - seg_start_u16);
            VisualRun seg_run;
            seg_run.type = run.type;
            seg_run.column = run.column + seg_start_u16;
            seg_run.length = break_u16 - seg_start_u16;
            seg_run.style = run.style;
            seg_run.source_line = run.source_line;
            seg_run.x = current_x;
            seg_run.width = break_width;
            seg_run.text = std::move(seg_text);
            current_line.runs.push_back(seg_run);
          }

          // Wrap to next line
          out_lines.push_back(std::move(current_line));
          ++wrap_index;
          float new_y = start_y + wrap_index * line_height;
          current_line = {line_index, wrap_index};
          current_line.line_number_position = {m_layout_metrics_.line_number_margin, new_y};
          current_line.kind = VisualLineKind::CONTENT;
          current_line.owns_gutter_semantics = false;
          current_x = 0;
          seg_start_u16 = break_u16;
          seg_width = 0;
          has_word_break = false;
          last_word_break_u16 = seg_start_u16;
          last_word_break_width = 0;

          // Recompute width from seg_start_u16 to current_u16 (scanned but not output yet)
          if (seg_start_u16 < current_u16) {
            U16String leftover = run_text.substr(seg_start_u16, current_u16 - seg_start_u16);
            seg_width = measureWidth(leftover, run.style.font_style);
          }
          // Add current grapheme
          seg_width += char_width;
          current_u16 = grapheme_end;
          continue;
        }

        seg_width += char_width;
        current_u16 = grapheme_end;
      }

      // Output remaining segment
      if (seg_start_u16 < run_text.length()) {
        U16String remaining = run_text.substr(seg_start_u16);
        VisualRun rem_run;
        rem_run.type = run.type;
        rem_run.column = run.column + seg_start_u16;
        rem_run.length = run_text.length() - seg_start_u16;
        rem_run.style = run.style;
        rem_run.source_line = run.source_line;
        rem_run.x = current_x;
        rem_run.width = seg_width;
        rem_run.text = std::move(remaining);
        current_line.runs.push_back(rem_run);
        current_x += seg_width;
      }
    }

    // Output last line (output even if empty)
    out_lines.push_back(std::move(current_line));
  }

  void TextLayout::appendFoldTailRuns(size_t index, const U16String& line_text, LogicalLine& logical_line) {
    VisualLine& last_vl = logical_line.visual_lines.back();
    last_vl.fold_state = FoldState::COLLAPSED;

    // Calculate placeholder start x (after existing runs)
    float fold_x = 0;
    for (const VisualRun& run : last_vl.runs) {
      fold_x += run.width;
    }

    // Append fold placeholder.
    VisualRun fold_run;
    fold_run.type = VisualRunType::FOLD_PLACEHOLDER;
    fold_run.column = line_text.length();
    fold_run.length = 0;
    fold_run.x = fold_x;

    static const U16String kFoldText = CHAR16(" \u2026 ");
    fold_run.text = kFoldText;
    fold_run.width = measureWidth(kFoldText, FONT_STYLE_NORMAL);
    fold_run.padding = m_layout_metrics_.inlay_hint_padding;
    fold_run.margin = m_layout_metrics_.inlay_hint_margin;
    fold_run.width += fold_run.padding * 2 + fold_run.margin * 2;
    last_vl.runs.push_back(std::move(fold_run));

    // Append projected tail-line VisualRuns while preserving source styles.
    FoldTailProjection projection;
    if (!resolveFoldTailProjectionForOwnerLine(index, projection)) return;

    const size_t end_line_idx = projection.source_line;
    const U16String& end_text = m_document_->getLineU16TextRef(end_line_idx);

    // Use buildLineRuns to get complete runs for the tail line (with highlight styles)
    Vector<VisualRun> end_runs;
    buildLineRuns(end_line_idx, end_text, end_runs);

    // Sum widths of all runs in last_vl as the starting x for appended runs
    float append_x = 0;
    for (const VisualRun& r : last_vl.runs) {
      append_x += r.width;
    }

    // Iterate tail-line runs, skip leading whitespace region, append the rest
    for (VisualRun& end_run : end_runs) {
      if (!isSourceTextRun(end_run)) continue;

      size_t run_start = end_run.column;
      size_t run_end = end_run.column + end_run.length;

      // Entire run is within the trim region, skip it
      if (run_end <= projection.visible_start) continue;

      // Partially within trim region, clip leading portion
      if (run_start < projection.visible_start) {
        size_t skip_chars = projection.visible_start - run_start;
        end_run.text = end_run.text.substr(skip_chars);
        end_run.column += skip_chars;
        end_run.length -= skip_chars;
        end_run.width = measureWidth(end_run.text, end_run.style.font_style);
      }

      end_run.x = append_x;
      end_run.source_line = projection.source_line;

      append_x += end_run.width;
      last_vl.runs.push_back(std::move(end_run));
    }
  }

  void TextLayout::appendLineBreakRun(size_t owner_line, LogicalLine& logical_line) {
    if (m_document_ == nullptr || logical_line.visual_lines.empty()) return;
    auto& lines = m_document_->getLogicalLines();
    if (owner_line >= lines.size()) return;

    size_t source_line = owner_line;
    FoldTailProjection projection;
    if (resolveFoldTailProjectionForOwnerLine(owner_line, projection)) {
      source_line = projection.source_line;
    }
    if (source_line >= lines.size() || lines[source_line].line_ending == LineEnding::NONE) {
      return;
    }

    VisualLine* target_line = nullptr;
    for (auto it = logical_line.visual_lines.rbegin(); it != logical_line.visual_lines.rend(); ++it) {
      if (it->kind == VisualLineKind::CONTENT) {
        target_line = &(*it);
        break;
      }
    }
    if (target_line == nullptr) return;

    float marker_x = 0.0f;
    for (const VisualRun& run : target_line->runs) {
      marker_x += run.width;
    }

    static const U16String kLineBreakText = CHAR16("\u21B5");
    VisualRun run;
    run.type = VisualRunType::NEWLINE;
    run.column = m_document_->getLineU16TextRef(source_line).length();
    run.length = 0;
    run.source_line = source_line == target_line->logical_line ? kVisualRunOwnerLine : source_line;
    run.x = marker_x;
    run.text = kLineBreakText;
    run.width = measureWidth(kLineBreakText, FONT_STYLE_NORMAL);
    target_line->runs.push_back(std::move(run));
  }

  float TextLayout::computeLineNumberWidth() const {
    size_t line_count = std::max(static_cast<size_t>(1), m_document_->getLogicalLines().size());
    uint32_t line_number_bits = static_cast<uint32_t>(std::log10(line_count) + 1 + 1e-10);
    if (m_is_monospace_) {
      return m_number_width_ * line_number_bits;
    } else {
      U16String test_text;
      test_text.reserve(line_number_bits);
      for (uint32_t i = 0; i < line_number_bits; ++i) {
        test_text.push_back(CHAR16('9'));
      }
      return m_measurer_->measureWidth(test_text, FONT_STYLE_NORMAL);
    }
  }

  void TextLayout::buildGutterIconRenderItems(size_t logical_line, float line_top_screen,
                                              float gutter_offset,
                                              Vector<GutterIconRenderItem>& out_items) const {
    const auto& gutter_icons = m_decoration_manager_->getLineGutterIcons(logical_line);
    if (gutter_icons.empty()) return;

    const float line_height = getLineHeight();
    const float icon_size = m_layout_metrics_.font_height;
    if (icon_size <= 0) return;
    const float icon_top = line_top_screen + std::max(0.0f, (line_height - icon_size) * 0.5f);

    if (m_layout_metrics_.max_gutter_icons == 0) {
      GutterIconRenderItem item;
      item.logical_line = logical_line;
      item.icon_id = gutter_icons[0].icon_id;
      item.rect = {{m_layout_metrics_.line_number_margin + gutter_offset, icon_top}, icon_size, icon_size};
      out_items.push_back(std::move(item));
      return;
    }

    const size_t max_icons = std::min(static_cast<size_t>(m_layout_metrics_.max_gutter_icons), gutter_icons.size());
    const float split_x = m_layout_metrics_.gutterWidth();
    const bool show_fold_arrows = m_layout_metrics_.shouldShowFoldArrows();
    const float fold_lane_left = split_x - m_layout_metrics_.line_number_margin - m_layout_metrics_.foldArrowAreaWidth();
    float icon_right = show_fold_arrows ? fold_lane_left : (split_x - 2.0f);
    icon_right += gutter_offset;
    for (size_t idx = 0; idx < max_icons; ++idx) {
      const size_t icon_index = max_icons - 1 - idx;
      GutterIconRenderItem item;
      item.logical_line = logical_line;
      item.icon_id = gutter_icons[icon_index].icon_id;
      item.rect = {{icon_right - icon_size, icon_top}, icon_size, icon_size};
      out_items.push_back(std::move(item));
      icon_right -= icon_size;
    }
  }

  bool TextLayout::buildFoldMarkerRenderItem(size_t logical_line, float line_top_screen,
                                             float gutter_offset,
                                             FoldMarkerRenderItem& out_item) const {
    if (!m_layout_metrics_.shouldShowFoldArrows()) return false;
    int fs = m_decoration_manager_->getFoldStateForLine(logical_line);
    if (fs == 0) return false;
    const float fold_width = m_layout_metrics_.foldArrowAreaWidth();
    if (fold_width <= 0) return false;
    const float split_x = m_layout_metrics_.gutterWidth();
    const float fold_left = split_x - m_layout_metrics_.line_number_margin - fold_width + gutter_offset;
    const float marker_height = m_layout_metrics_.font_height;
    const float line_height = getLineHeight();
    const float marker_top = line_top_screen + std::max(0.0f, (line_height - marker_height) * 0.5f);
    out_item.logical_line = logical_line;
    out_item.fold_state = static_cast<FoldState>(fs);
    out_item.rect = {{fold_left, marker_top}, fold_width, marker_height};
    return true;
  }

  const VisualLine* TextLayout::findGutterOwnerLine(const LogicalLine& logical_line) const {
    for (const VisualLine& visual_line : logical_line.visual_lines) {
      if (visual_line.owns_gutter_semantics) {
        return &visual_line;
      }
    }
    return nullptr;
  }

  float TextLayout::getGutterOwnerTopScreen(const LogicalLine& logical_line, float scroll_y) const {
    const VisualLine* gutter_owner = findGutterOwnerLine(logical_line);
    const float abs_y = gutter_owner != nullptr ? gutter_owner->line_number_position.y : logical_line.start_y;
    return abs_y - scroll_y;
  }

  size_t TextLayout::findHitLine(float abs_y) {
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    const size_t size = logical_lines.size();
    if (size == 0) return 0;

    // Ensure prefix index covers whole document (no layout trigger; use estimated heights)
    ensurePrefixIndexUpTo(size - 1);

    // Binary search: find the last line with prefix_y[i] <= abs_y
    const float default_height = getLineHeight();
    size_t hit_line = size - 1;
    {
      size_t lo = 0, hi = size;
      while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        float h = (logical_lines[mid].height >= 0) ? logical_lines[mid].height : default_height;
        float line_bottom = m_line_prefix_y_[mid] + h;
        if (line_bottom <= abs_y) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      hit_line = lo < size ? lo : size - 1;
    }

    // Layout hit line exactly (ensure later visual_lines data is valid)
    layoutLine(hit_line, logical_lines[hit_line]);

    // Skip fold-hidden lines: search backward for nearest visible line
    while (hit_line < size && logical_lines[hit_line].is_fold_hidden) {
      if (hit_line == 0) break;
      --hit_line;
    }

    return hit_line;
  }

  size_t TextLayout::findHitWrapIndex(const LogicalLine& ll, float abs_y, float line_height) const {
    size_t target_wrap = 0;
    if (ll.visual_lines.size() > 1) {
      for (size_t vi = 0; vi < ll.visual_lines.size(); ++vi) {
        float vl_y = ll.visual_lines[vi].line_number_position.y;
        if (abs_y < vl_y + line_height) {
          target_wrap = vi;
          break;
        }
        target_wrap = vi;
      }
    }
    return target_wrap;
  }

  TextPosition TextLayout::mapVisualLineToPointerTarget(size_t logical_line, const VisualLine& visual_line) const {
    const auto& semantics = getVisualLineSemantics(visual_line.kind);
    switch (semantics.pointer_hit) {
      case PointerHitPolicy::OWNER_LINE_START:
        return {logical_line, 0};
      case PointerHitPolicy::CONTENT:
      default:
        return {logical_line, 0};
    }
  }

  TextPosition TextLayout::mapVisualLineToTextBoundary(size_t logical_line, const VisualLine& visual_line) const {
    if (m_document_ == nullptr) {
      return {0, 0};
    }
    const auto& semantics = getVisualLineSemantics(visual_line.kind);
    switch (semantics.text_boundary) {
      case TextBoundaryPolicy::PREVIOUS_VISIBLE_LINE_END:
        return previousVisibleLineEnd(logical_line);
      case TextBoundaryPolicy::OWNER_LINE_END:
        return {logical_line, m_document_->getLineColumns(logical_line)};
      case TextBoundaryPolicy::CONTENT:
      default:
        return {logical_line, 0};
    }
  }

  bool TextLayout::getVisualLineTextColumnExtent(const VisualLine& visual_line,
                                                  size_t source_line,
                                                  size_t& out_col_min,
                                                  size_t& out_col_max,
                                                  float& out_total_width) {
    out_col_min = SIZE_MAX;
    out_col_max = 0;
    out_total_width = 0;
    float vl_x = 0;
    for (const VisualRun& run : visual_line.runs) {
      const float run_right = vl_x + run.width;
      if (!isSourceTextRun(run) || runSourceLine(visual_line, run) != source_line) {
        vl_x = run_right;
        continue;
      }
      out_col_min = std::min(out_col_min, static_cast<size_t>(run.column));
      out_col_max = std::max(out_col_max, static_cast<size_t>(run.column + run.length));
      out_total_width = run_right;
      vl_x = run_right;
    }
    return out_col_min != SIZE_MAX;
  }

  bool TextLayout::columnToVisualLineX(const VisualLine& visual_line,
                                       size_t source_line,
                                       size_t column,
                                       bool allow_line_end,
                                       float& out_x) {
    float vl_x = 0;
    for (const VisualRun& run : visual_line.runs) {
      if (!isSourceTextRun(run) || runSourceLine(visual_line, run) != source_line) {
        vl_x += run.width;
        continue;
      }

      size_t run_start = run.column;
      size_t run_end = run.column + run.length;
      bool inside = allow_line_end
                    ? (column >= run_start && column <= run_end)
                    : (column >= run_start && column < run_end);
      if (!inside) {
        vl_x += run.width;
        continue;
      }

      if (run.type == VisualRunType::TAB) {
        out_x = (column == run_start) ? vl_x : vl_x + run.width;
      } else {
        size_t offset = column - run_start;
        float prefix_w = 0;
        if (offset > 0) {
          U16String prefix = run.text.substr(0, offset);
          prefix_w = measureWidth(prefix, run.style.font_style);
        }
        out_x = vl_x + prefix_w;
      }
      return true;
    }
    return false;
  }

  TextPosition TextLayout::previousVisibleLineEnd(size_t logical_line) const {
    if (m_document_ == nullptr) {
      return {0, 0};
    }
    const auto& logical_lines = m_document_->getLogicalLines();
    if (logical_line == 0 || logical_lines.empty()) {
      return {0, 0};
    }
    size_t line = logical_line;
    while (line > 0) {
      --line;
      if (!logical_lines[line].is_fold_hidden) {
        return {line, m_document_->getLineColumns(line)};
      }
    }
    return {0, 0};
  }
#pragma endregion
}
