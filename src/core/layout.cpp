//
// Created by Scave on 2025/12/7.
//
#include <cmath>
#include <algorithm>
#include <simdutf/simdutf.h>
#include <utf8/utf8.h>
#include <layout.h>
#include <utility.h>
#include "logging.h"

namespace NS_SWEETEDITOR {
#pragma region [Class: TextLayout]
  TextLayout::TextLayout(const Ptr<TextMeasurer>& measurer, const Ptr<DecorationManager>& decoration_manager)
    : m_measurer_(measurer), m_decoration_manager_(decoration_manager) {
    resetMeasurer();
  }

  void TextLayout::loadDocument(const Ptr<Document>& document) {
    m_document_ = document;
    m_content_metrics_dirty_ = true;
    m_prefix_dirty_from_ = 0;
    m_line_prefix_y_.clear();
  }

  void TextLayout::setViewport(const Viewport& viewport) {
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
    m_document_->updateDirtyLine(index, logical_line);
    const U16String& line_text = logical_line.cached_text;
    float single_line_height = getLineHeight();

    layoutLineIntoVisualLines(index, line_text, logical_line.start_y, logical_line.visual_lines);

    // Collapsed first line: append fold placeholder + tail-line content
    if (m_decoration_manager_->getFoldStateForLine(index) == 2 && !logical_line.visual_lines.empty()) {
      appendFoldTailRuns(index, line_text, logical_line);
    }

    float new_height = single_line_height * logical_line.visual_lines.size();
    if (logical_line.height != new_height) {
      m_content_metrics_dirty_ = true;
      invalidatePrefixFrom(index + 1);
    }
    logical_line.height = new_height;

    logical_line.is_layout_dirty = false;
  }

  void TextLayout::layoutVisibleLines(EditorRenderModel& model) {
    PERF_TIMER("layoutVisibleLines");
    if (!m_viewport_.valid() || m_document_ == nullptr) {
      return;
    }
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (logical_lines.empty()) {
      return;
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
        // For first line (not continuation, not phantom), fill fold state and gutter icon render items
        if (visual_line.wrap_index == 0 && !visual_line.is_phantom_line && m_layout_metrics_.gutter_visible) {
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
    model.viewport_width = m_viewport_.width;
    model.viewport_height = m_viewport_.height;
  }

  TextPosition TextLayout::hitTest(const PointF& screen_point) {
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

    // Click on the left of text area (line number area): go to line start
    const bool in_line_number_area = (screen_point.x < split_x);

    // Find hit logical line (skip fold-hidden lines)
    size_t hit_line = findHitLine(abs_y);

    if (in_line_number_area) {
      return {hit_line, 0};
    }

    const LogicalLine& ll = logical_lines[hit_line];
    const U16String& line_text = ll.cached_text;

    // In wrap mode, find the exact VisualLine (subline)
    size_t target_wrap = findHitWrapIndex(ll, abs_y, line_height);

    const VisualLine& vl = ll.visual_lines[target_wrap];

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
          if (run.type == VisualRunType::TEXT || run.type == VisualRunType::TAB
              || run.type == VisualRunType::PHANTOM_TEXT) {
            return {hit_line, run.column};
          }
        }
      }
      return {hit_line, 0};
    }

    // Iterate runs to find the hit character
    float run_x = 0;
    for (const VisualRun& run : vl.runs) {
      float run_right = run_x + run.width;

      if (run.type == VisualRunType::INLAY_HINT || run.type == VisualRunType::PHANTOM_TEXT
          || run.type == VisualRunType::FOLD_PLACEHOLDER) {
        run_x = run_right;
        continue;
      }

      if (run.type == VisualRunType::TAB) {
        if (click_x < run_x + run.width * 0.5f) {
          return {hit_line, run.column};
        } else if (click_x < run_right) {
          return {hit_line, run.column + 1};
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
        auto text_begin = run.text.begin();
        auto text_end = run.text.end();
        size_t col_offset = 0;

        while (text_begin != text_end) {
          auto char_start = text_begin;
          utf8::next16(text_begin, text_end);
          size_t char_u16_len = static_cast<size_t>(text_begin - char_start);
          U16String u16_char(char_start, text_begin);
          float char_width = measureWidth(u16_char, run.style.font_style);

          // If click is left of char center, place on this char; else next char
          if (click_x < char_x + char_width * 0.5f) {
            return {hit_line, run.column + col_offset};
          }
          char_x += char_width;
          col_offset += char_u16_len;
        }
        // Click after run end
        return {hit_line, run.column + col_offset};
      }
      run_x = run_right;
    }

    // Click after line end
    return {hit_line, line_text.length()};
  }

  HitTarget TextLayout::hitTestDecoration(const PointF& screen_point) {
    if (m_document_ == nullptr) {
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
      const float line_top_screen = ll.start_y - scroll_y;
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

    // Iterate runs to check hit on InlayHint or FoldPlaceholder
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
      }

      run_x = run_right;
    }

    return {};
  }

  PointF TextLayout::getPositionScreenCoord(const TextPosition& position) {
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

    LogicalLine& ll = logical_lines[position.line];
    layoutLine(position.line, ll);
    const U16String& line_text = ll.cached_text;
    size_t target_col = std::min(position.column, line_text.length());

    // Compute width from line start to target_col
    float x_offset = 0;
    if (target_col > 0) {
      // Iterate visual_lines to find run containing target_col
      for (const VisualLine& vl : ll.visual_lines) {
        bool found = false;
        float vl_x = 0;
        for (const VisualRun& run : vl.runs) {
          if (run.type != VisualRunType::TEXT && run.type != VisualRunType::TAB) {
            vl_x += run.width;
            continue;
          }
          size_t run_end_col = run.column + run.length;
          if (target_col >= run.column && target_col <= run_end_col) {
            if (run.type == VisualRunType::TAB) {
              if (target_col == run.column) {
                float screen_x = text_area_x + vl_x - (m_wrap_mode_ == WrapMode::NONE ? scroll_x : 0);
                float screen_y = vl.line_number_position.y - scroll_y;
                return {screen_x, screen_y};
              }
            } else {
              size_t offset_in_run = target_col - run.column;
              if (offset_in_run > 0) {
                U16String prefix = run.text.substr(0, offset_in_run);
                vl_x += measureWidth(prefix, run.style.font_style);
              }
              float screen_x = text_area_x + vl_x - (m_wrap_mode_ == WrapMode::NONE ? scroll_x : 0);
              float screen_y = vl.line_number_position.y - scroll_y;
              return {screen_x, screen_y};
            }
          }
          vl_x += run.width;
        }
      }
      // If no run found (maybe beyond end), use end of last VisualLine
      if (!ll.visual_lines.empty()) {
        const VisualLine& last_vl = ll.visual_lines.back();
        float vl_x = 0;
        for (const VisualRun& run : last_vl.runs) {
          vl_x += run.width;
        }
        float screen_x = text_area_x + vl_x - (m_wrap_mode_ == WrapMode::NONE ? scroll_x : 0);
        float screen_y = last_vl.line_number_position.y - scroll_y;
        return {screen_x, screen_y};
      }
    }

    // column = 0, at start of first VisualLine
    float screen_y = ll.start_y - scroll_y;
    return {text_area_x - (m_wrap_mode_ == WrapMode::NONE ? scroll_x : 0), screen_y};
  }

  void TextLayout::getColumnScreenRange(size_t line, size_t col_start, size_t col_end,
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

    LogicalLine& ll = logical_lines[line];
    layoutLine(line, ll);
    const U16String& line_text = ll.cached_text;
    size_t safe_start = std::min(col_start, line_text.length());
    size_t safe_end = std::min(col_end, line_text.length());

    // Ensure col_start <= col_end
    if (safe_start > safe_end) std::swap(safe_start, safe_end);

    bool found_start = (safe_start == 0);
    bool found_end = (safe_end == 0);
    float x_start = 0;
    float x_end = 0;

    // Single pass over visual_lines and runs to locate both columns
    for (const VisualLine& vl : ll.visual_lines) {
      float vl_x = 0;
      for (const VisualRun& run : vl.runs) {
        if (run.type != VisualRunType::TEXT && run.type != VisualRunType::TAB) {
          vl_x += run.width;
          continue;
        }
        size_t run_end_col = run.column + run.length;

        if (!found_start && safe_start >= run.column && safe_start <= run_end_col) {
          if (run.type == VisualRunType::TAB) {
            x_start = (safe_start == run.column) ? vl_x : vl_x + run.width;
          } else {
            size_t offset = safe_start - run.column;
            float prefix_w = 0;
            if (offset > 0) {
              U16String prefix = run.text.substr(0, offset);
              prefix_w = measureWidth(prefix, run.style.font_style);
            }
            x_start = vl_x + prefix_w;
          }
          found_start = true;
        }

        if (!found_end && safe_end >= run.column && safe_end <= run_end_col) {
          if (run.type == VisualRunType::TAB) {
            x_end = (safe_end == run.column) ? vl_x : vl_x + run.width;
          } else {
            size_t offset = safe_end - run.column;
            float prefix_w = 0;
            if (offset > 0) {
              U16String prefix = run.text.substr(0, offset);
              prefix_w = measureWidth(prefix, run.style.font_style);
            }
            x_end = vl_x + prefix_w;
          }
          found_end = true;
        }

        if (found_start && found_end) break;
        vl_x += run.width;
      }
      if (found_start && found_end) break;
    }

    // If still not found (column beyond end), use end width of last visual line
    if (!found_start || !found_end) {
      float last_x = 0;
      if (!ll.visual_lines.empty()) {
        for (const VisualRun& run : ll.visual_lines.back().runs) {
          last_x += run.width;
        }
      }
      if (!found_start) x_start = last_x;
      if (!found_end) x_end = last_x;
    }

    out_x_start = text_area_x + x_start - scroll_offset;
    out_x_end = text_area_x + x_end - scroll_offset;
  }

  void TextLayout::getColumnScreenRange(size_t line, size_t col_start, size_t col_end,
                                         float& out_x_start, float& out_x_end, float& out_y) {
    // Reuse the 2-output version to get x range
    getColumnScreenRange(line, col_start, col_end, out_x_start, out_x_end);

    // Get y directly from laid-out line to avoid another traversal
    if (m_document_ != nullptr) {
      Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
      if (line < logical_lines.size()) {
        LogicalLine& ll = logical_lines[line];
        // layoutLine was called in getColumnScreenRange above; ll is already up to date
        const float scroll_y = m_view_state_.scroll_y;
        // Find y of the visual line containing col_start
        size_t safe_col = std::min(col_start, ll.cached_text.length());
        for (const VisualLine& vl : ll.visual_lines) {
          for (const VisualRun& run : vl.runs) {
            if ((run.type == VisualRunType::TEXT || run.type == VisualRunType::TAB) &&
                safe_col >= run.column && safe_col <= run.column + run.length) {
              out_y = vl.line_number_position.y - scroll_y;
              return;
            }
          }
        }
        // If not found, use line-start y
        out_y = ll.start_y - scroll_y;
        return;
      }
    }
    out_y = 0;
  }

  void TextLayout::getColumnSelectionRects(size_t line, size_t col_start, size_t col_end,
                                            float rect_height, Vector<SelectionRect>& out_rects) {
    if (m_document_ == nullptr) return;
    Vector<LogicalLine>& logical_lines = m_document_->getLogicalLines();
    if (line >= logical_lines.size()) return;

    LogicalLine& ll = logical_lines[line];
    layoutLine(line, ll);

    const U16String& line_text = ll.cached_text;
    size_t safe_start = std::min(col_start, line_text.length());
    size_t safe_end = std::min(col_end, line_text.length());
    if (safe_start > safe_end) std::swap(safe_start, safe_end);
    if (safe_start == safe_end) return;

    const float scroll_x = m_view_state_.scroll_x;
    const float scroll_y = m_view_state_.scroll_y;
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float scroll_offset = (m_wrap_mode_ == WrapMode::NONE) ? scroll_x : 0.0f;

    for (const VisualLine& vl : ll.visual_lines) {
      // 计算该视觉行中 TEXT runs 覆盖的逻辑列范围
      size_t vl_col_min = SIZE_MAX;
      size_t vl_col_max = 0;
      for (const VisualRun& run : vl.runs) {
        if (run.type != VisualRunType::TEXT && run.type != VisualRunType::TAB) continue;
        if (run.column < vl_col_min) vl_col_min = run.column;
        size_t run_end = run.column + run.length;
        if (run_end > vl_col_max) vl_col_max = run_end;
      }
      if (vl_col_min == SIZE_MAX) continue;

      // 与选区列范围取交集
      size_t intersect_start = std::max(safe_start, vl_col_min);
      size_t intersect_end = std::min(safe_end, vl_col_max);
      if (intersect_start >= intersect_end) continue;

      // 在该视觉行的 runs 中计算交集范围的 x 坐标
      float x_start = 0, x_end = 0;
      bool found_start = false, found_end = false;
      float vl_x = 0;

      for (const VisualRun& run : vl.runs) {
        if (run.type != VisualRunType::TEXT && run.type != VisualRunType::TAB) {
          vl_x += run.width;
          continue;
        }
        size_t run_end_col = run.column + run.length;

        if (!found_start && intersect_start >= run.column && intersect_start <= run_end_col) {
          if (run.type == VisualRunType::TAB) {
            x_start = (intersect_start == run.column) ? vl_x : vl_x + run.width;
          } else {
            size_t offset = intersect_start - run.column;
            float prefix_w = 0;
            if (offset > 0) {
              U16String prefix = run.text.substr(0, offset);
              prefix_w = measureWidth(prefix, run.style.font_style);
            }
            x_start = vl_x + prefix_w;
          }
          found_start = true;
        }

        if (!found_end && intersect_end >= run.column && intersect_end <= run_end_col) {
          if (run.type == VisualRunType::TAB) {
            x_end = (intersect_end == run.column) ? vl_x : vl_x + run.width;
          } else {
            size_t offset = intersect_end - run.column;
            float prefix_w = 0;
            if (offset > 0) {
              U16String prefix = run.text.substr(0, offset);
              prefix_w = measureWidth(prefix, run.style.font_style);
            }
            x_end = vl_x + prefix_w;
          }
          found_end = true;
        }

        if (found_start && found_end) break;
        vl_x += run.width;
      }

      // 未找到则使用视觉行末尾
      if (!found_start || !found_end) {
        float last_x = 0;
        for (const VisualRun& run : vl.runs) {
          last_x += run.width;
        }
        if (!found_start) x_start = last_x;
        if (!found_end) x_end = last_x;
      }

      SelectionRect rect;
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

    if (m_document_ == nullptr || !m_viewport_.valid()) {
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
    if (m_document_ == nullptr || !m_viewport_.valid()) return;

    ScrollBounds bounds = getScrollBounds();
    scroll_y = std::clamp(scroll_y, 0.0f, bounds.max_scroll_y);
    scroll_x = std::clamp(scroll_x, 0.0f, bounds.max_scroll_x);
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

    // ── Multiplication-based run tracking ──
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
        float h = (prev.height >= 0) ? prev.height : default_height;
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

    // Build runs for original line (includes first phantom line segment)
    Vector<VisualRun> all_runs;
    buildLineRuns(line_index, line_text, start_y, all_runs);

    // Handle original line based on wrap mode
    if (m_wrap_mode_ == WrapMode::NONE) {
      VisualLine visual_line = {line_index, 0};
      visual_line.line_number_position = {m_layout_metrics_.line_number_margin, start_y};
      visual_line.runs = std::move(all_runs);
      out_visual_lines.push_back(std::move(visual_line));
    } else {
      wrapLineRuns(line_index, start_y, line_height, all_runs, out_visual_lines);
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
        float seg_y = start_y + base_wrap_idx * line_height;

        VisualRun run;
        run.type = VisualRunType::PHANTOM_TEXT;
        run.column = phantom.column;
        run.length = 0;
        run.y = seg_y;
        run.style.font_style = FONT_STYLE_ITALIC;
        U16String seg_u16;
        StrUtil::convertUTF8ToUTF16(seg, seg_u16);
        run.text = std::move(seg_u16);
        run.width = run.text.empty() ? 0 : measureWidth(run.text, FONT_STYLE_ITALIC);

        if (m_wrap_mode_ == WrapMode::NONE) {
          // No wrap: generate one phantom VisualLine directly
          VisualLine phantom_vl = {line_index, base_wrap_idx};
          phantom_vl.line_number_position = {m_layout_metrics_.line_number_margin, seg_y};
          phantom_vl.is_phantom_line = true;
          phantom_vl.runs.push_back(std::move(run));
          out_visual_lines.push_back(std::move(phantom_vl));
        } else {
          // Wrap mode: phantom continuation line also goes through wrapLineRuns
          Vector<VisualRun> seg_runs;
          seg_runs.push_back(std::move(run));
          Vector<VisualLine> wrapped_lines;
          wrapLineRuns(line_index, seg_y, line_height, seg_runs, wrapped_lines);
          // Fix wrap_index and mark as phantom line
          for (auto& wl : wrapped_lines) {
            wl.wrap_index = out_visual_lines.size();
            wl.is_phantom_line = true;
            wl.line_number_position.y = start_y + wl.wrap_index * line_height;
            for (auto& r : wl.runs) {
              r.y = wl.line_number_position.y;
            }
            out_visual_lines.push_back(std::move(wl));
          }
        }
      }
    }
  }

  void TextLayout::buildLineRuns(size_t line_index, const U16String& line_text, float start_y, Vector<VisualRun>& runs) {
    const auto merged_spans = m_decoration_manager_->getMergedLineSpans(line_index);
    const auto& inlay_hints = m_decoration_manager_->getLineInlayHints(line_index);
    const auto& phantom_texts = m_decoration_manager_->getLinePhantomTexts(line_index);

    const size_t text_len = line_text.length();

    // Helper: split a TEXT run by tab characters, emitting TEXT and TAB runs
    auto splitTabsInRun = [&](const VisualRun& src_run, size_t& current_column) {
      const U16String& t = src_run.text;
      size_t pos = 0;
      while (pos < t.length()) {
        size_t tab_pos = t.find(u'\t', pos);
        if (tab_pos == U16String::npos) tab_pos = t.length();
        if (tab_pos > pos) {
          VisualRun text_part;
          text_part.type = VisualRunType::TEXT;
          text_part.column = src_run.column + static_cast<uint32_t>(pos);
          text_part.length = tab_pos - pos;
          text_part.y = src_run.y;
          text_part.style = src_run.style;
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
          tab_run.y = src_run.y;
          tab_run.style = src_run.style;
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
    if (merged_spans.empty() && inlay_hints.empty() && phantom_texts.empty()) {
      VisualRun run = {VisualRunType::TEXT, 0, text_len};
      run.y = start_y;
      run.style.font_style = FONT_STYLE_NORMAL;
      run.text = line_text;
      if (line_text.find(u'\t') != U16String::npos) {
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

    // Helper to build InlayHint VisualRun
    auto makeInlayHintRun = [&](const InlayHint& hint) -> VisualRun {
      VisualRun run;
      run.type = VisualRunType::INLAY_HINT;
      run.column = hint.column;
      run.length = 0;
      run.y = start_y;
      run.padding = m_layout_metrics_.inlay_hint_padding;
      run.margin = m_layout_metrics_.inlay_hint_margin;
      run.style.font_style = FONT_STYLE_NORMAL;
      if (hint.type == InlayType::TEXT) {
        U16String hint_u16;
        StrUtil::convertUTF8ToUTF16(hint.text, hint_u16);
        run.text = std::move(hint_u16);
        run.width = m_measurer_->measureInlayHintWidth(run.text) + run.padding * 2 + run.margin * 2;
      } else if (hint.type == InlayType::COLOR) {
        run.color_value = hint.color;
        // Color block is a square: side = font_height, no padding needed
        run.width = m_layout_metrics_.font_height + run.margin * 2;
      } else {
        run.icon_id = hint.icon_id;
        run.width = m_measurer_->measureIconWidth(hint.icon_id) + run.padding * 2 + run.margin * 2;
      }
      return run;
    };

    // Helper to build PhantomText VisualRun (first line only, before \n)
    auto makePhantomTextRun = [&](const PhantomText& phantom) -> VisualRun {
      VisualRun run;
      run.type = VisualRunType::PHANTOM_TEXT;
      run.column = phantom.column;
      run.length = 0;
      run.y = start_y;
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
        text_run.type = VisualRunType::TEXT;
        text_run.column = seg_start;
        text_run.length = actual_end - seg_start;
        text_run.y = start_y;
        text_run.style = findSpanStyle(seg_start);
        text_run.text = line_text.substr(seg_start, actual_end - seg_start);
        if (text_run.text.find(u'\t') != U16String::npos) {
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

      // INLAY_HINT / TAB: do not split
      if (run.type == VisualRunType::INLAY_HINT || run.type == VisualRunType::TAB) {
        current_x = run_right;
        ++run_it;
        continue;
      }

      // TEXT / PHANTOM_TEXT: crop only when run clearly crosses bounds, keep margin
      bool need_crop_left = (run_left < visible_left);
      bool need_crop_right = (run_right > visible_right);

      if (need_crop_left || need_crop_right) {
        if (m_is_monospace_ && run.length > 0) {
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
            if (visible_len == 0) {
              current_x = run_right;
              run_it = visual_line.runs.erase(run_it);
              continue;
            }
            if (visible_start > 0 || visible_len < run.length) {
              run.x = text_area_x + (run_left + skip_left * char_width) - scroll_x;
              run.text = run.text.substr(visible_start, visible_len);
              run.width = visible_len * char_width;
            }
          }
        } else {
          // Non-monospace font: crop char by char
          auto text_begin = run.text.begin();
          auto text_end = run.text.end();
          size_t start_u16_index = 0;
          size_t end_u16_index = run.text.length();
          size_t current_u16_index = 0;
          float char_x = run_left;
          float crop_start_x = run_left;
          bool found_start = !need_crop_left;

          while (text_begin != text_end) {
            auto char_start = text_begin;
            utf8::next16(text_begin, text_end);
            U16String u16_char_text(char_start, text_begin);
            float char_width = measureWidth(u16_char_text, run.style.font_style);

            if (!found_start) {
              if (char_x + char_width > visible_left) {
                start_u16_index = current_u16_index;
                crop_start_x = char_x;
                found_start = true;
              }
            }
            if (found_start && char_x + char_width > visible_right) {
              end_u16_index = current_u16_index + u16_char_text.length();
              break;
            }
            char_x += char_width;
            current_u16_index += u16_char_text.length();
          }

          if (!found_start || start_u16_index >= end_u16_index) {
            current_x = run_right;
            run_it = visual_line.runs.erase(run_it);
            continue;
          }

          if (start_u16_index > 0 || end_u16_index < run.text.length()) {
            run.x = text_area_x + crop_start_x - scroll_x;
            run.text = run.text.substr(start_u16_index, end_u16_index - start_u16_index);
          }
        }
      }

      current_x = run_right;
      ++run_it;
    }
  }

  void TextLayout::wrapLineRuns(size_t line_index, float start_y, float line_height,
                                Vector<VisualRun>& runs, Vector<VisualLine>& out_lines) {
    const float text_area_x = m_layout_metrics_.textAreaX();
    const float wrap_width = m_viewport_.width - text_area_x;
    if (wrap_width <= 0) {
      // Viewport is too small: do not wrap, output single line
      VisualLine vl = {line_index, 0};
      vl.line_number_position = {m_layout_metrics_.line_number_margin, start_y};
      vl.runs = std::move(runs);
      out_lines.push_back(std::move(vl));
      return;
    }

    size_t wrap_index = 0;
    float current_x = 0; // Accumulated width in current line
    VisualLine current_line = {line_index, wrap_index};
    current_line.line_number_position = {m_layout_metrics_.line_number_margin, start_y};

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
          current_x = 0;
        }
        run.x = current_x;
        current_x += run.width;
        current_line.runs.push_back(run);
        continue;
      }

      // TEXT / PHANTOM_TEXT: wrap char by char
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
      auto text_begin = run_text.begin();
      auto text_end = run_text.end();
      size_t seg_start_u16 = 0;
      size_t current_u16 = 0;
      float seg_width = 0;
      // In WORD_BREAK mode, record nearest word boundary
      size_t last_word_break_u16 = 0;
      float last_word_break_width = 0;
      bool has_word_break = false;

      while (text_begin != text_end) {
        auto char_start = text_begin;
        utf8::next16(text_begin, text_end);
        size_t char_u16_len = static_cast<size_t>(text_begin - char_start);
        U16String u16_char(char_start, text_begin);
        float char_width = measureWidth(u16_char, run.style.font_style);

        // WORD_BREAK mode: check whether there is a word boundary after this char
        if (m_wrap_mode_ == WrapMode::WORD_BREAK && char_u16_len > 0) {
          U16Char ch = *char_start;
          if (isWordBreakChar(ch)) {
            last_word_break_u16 = current_u16 + char_u16_len;
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
          // Add current character
          seg_width += char_width;
          current_u16 += char_u16_len;
          continue;
        }

        seg_width += char_width;
        current_u16 += char_u16_len;
      }

      // Output remaining segment
      if (seg_start_u16 < run_text.length()) {
        U16String remaining = run_text.substr(seg_start_u16);
        VisualRun rem_run;
        rem_run.type = run.type;
        rem_run.column = run.column + seg_start_u16;
        rem_run.length = run_text.length() - seg_start_u16;
        rem_run.style = run.style;
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

    // Append fold placeholder " … "
    VisualRun fold_run;
    fold_run.type = VisualRunType::FOLD_PLACEHOLDER;
    fold_run.column = line_text.length();
    fold_run.length = 0;
    fold_run.x = fold_x;
    fold_run.y = logical_line.start_y;
    static const U16String kFoldText = CHAR16(" \u2026 ");
    fold_run.text = kFoldText;
    fold_run.width = measureWidth(kFoldText, FONT_STYLE_NORMAL);
    fold_run.padding = m_layout_metrics_.inlay_hint_padding;
    fold_run.margin = m_layout_metrics_.inlay_hint_margin;
    fold_run.width += fold_run.padding * 2 + fold_run.margin * 2;
    last_vl.runs.push_back(std::move(fold_run));

    // Append tail-line VisualRuns (JetBrains style: first line + … + tail content, preserving highlights)
    const FoldRegion* fold_region = m_decoration_manager_->getFoldRegionForLine(index);
    if (!fold_region || fold_region->end_line <= fold_region->start_line) return;

    size_t end_line_idx = fold_region->end_line;
    Vector<LogicalLine>& all_lines = m_document_->getLogicalLines();
    if (end_line_idx >= all_lines.size()) return;

    LogicalLine& end_ll = all_lines[end_line_idx];
    m_document_->updateDirtyLine(end_line_idx, end_ll);
    const U16String& end_text = end_ll.cached_text;

    // Count leading whitespace characters (skip spaces and tabs)
    size_t trim_pos = 0;
    while (trim_pos < end_text.size() &&
           (end_text[trim_pos] == u' ' || end_text[trim_pos] == u'\t')) {
      ++trim_pos;
    }
    if (trim_pos >= end_text.size()) return;

    // Use buildLineRuns to get complete runs for the tail line (with highlight styles)
    Vector<VisualRun> end_runs;
    buildLineRuns(end_line_idx, end_text, logical_line.start_y, end_runs);

    // Sum widths of all runs in last_vl as the starting x for appended runs
    float append_x = 0;
    for (const VisualRun& r : last_vl.runs) {
      append_x += r.width;
    }

    // Iterate tail-line runs, skip leading whitespace region, append the rest
    for (VisualRun& end_run : end_runs) {
      // Only process TEXT type runs (skip INLAY_HINT / PHANTOM_TEXT and other decorations)
      if (end_run.type != VisualRunType::TEXT) continue;

      size_t run_start = end_run.column;
      size_t run_end = end_run.column + end_run.length;

      // Entire run is within the trim region, skip it
      if (run_end <= trim_pos) continue;

      // Partially within trim region, clip leading portion
      if (run_start < trim_pos) {
        size_t skip_chars = trim_pos - run_start;
        end_run.text = end_run.text.substr(skip_chars);
        end_run.column += skip_chars;
        end_run.length -= skip_chars;
        end_run.width = measureWidth(end_run.text, end_run.style.font_style);
      }

      // Set x/y coordinates and append
      end_run.x = append_x;
      end_run.y = logical_line.start_y;
      append_x += end_run.width;
      last_vl.runs.push_back(std::move(end_run));
    }
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

  bool TextLayout::isWordBreakChar(U16Char ch) {
    return ch == CHAR16(' ') || ch == CHAR16('\t') ||
           ch == CHAR16('-') || ch == CHAR16('/') ||
           ch == CHAR16('\\') || ch == CHAR16('.') ||
           ch == CHAR16(',') || ch == CHAR16(';') ||
           ch == CHAR16(':') || ch == CHAR16('!') ||
           ch == CHAR16('?') || ch == CHAR16(')') ||
           ch == CHAR16(']') || ch == CHAR16('}') ||
           ch == CHAR16('>');
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
      item.origin = {m_layout_metrics_.line_number_margin + gutter_offset, icon_top};
      item.width = icon_size;
      item.height = icon_size;
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
      item.origin = {icon_right - icon_size, icon_top};
      item.width = icon_size;
      item.height = icon_size;
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
    out_item.origin = {fold_left, marker_top};
    out_item.width = fold_width;
    out_item.height = marker_height;
    return true;
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
#pragma endregion
}
