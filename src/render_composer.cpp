#include <algorithm>
#include <sweeteditor/interaction.h>
#include "render_composer.hpp"
#include "render_style_util.hpp"

namespace NS_SWEETEDITOR {

  namespace {
    void appendRangeEffect(EditorRenderModel& model, const Rect& rect, RangeEffectKind kind,
                           const RangeEffectStyle& style) {
      if (!RenderStyleUtil::hasRangeEffectPaint(style) || rect.width <= 0.0f || rect.height <= 0.0f) {
        return;
      }
      RangeEffectRenderItem item;
      item.rect = rect;
      item.kind = kind;
      item.style = style;
      model.range_effects.push_back(item);
    }

    void collectVisibleRangeEffectSourceLines(const EditorRenderModel& model, TextLayout& text_layout,
                                              HashSet<size_t>& out_source_lines) {
      for (const VisualLine& visual_line : model.lines) {
        out_source_lines.insert(visual_line.logical_line);

        TextRange projected_range;
        if (text_layout.getFoldTailProjectedRange(visual_line.logical_line, projected_range)) {
          out_source_lines.insert(projected_range.start.line);
        }
      }
    }
  }

  RenderModelComposer::RenderModelComposer(TextLayout& text_layout, TextMeasurer& measurer, EditorSettings& settings,
                                           const EditorInteraction& interaction)
      : m_text_layout_(text_layout),
        m_measurer_(measurer),
        m_settings_(settings),
        m_interaction_(interaction) {
  }

  void RenderModelComposer::compose(EditorRenderModel& model, const RenderModelInput& input) const {
    const float line_height = m_text_layout_.getLineHeight();

    finalizeTextRuns(model, input);
    composeCursor(model, input, line_height);
    composeDocumentHighlightEffects(model, input, line_height);
    composeSearchEffects(model, input, line_height);
    composeCompositionEffects(model, input, line_height);
    composeSelection(model, input, line_height);
    composeGuides(model, input, line_height);
    composeDiagnosticEffects(model, input, line_height);
    composeLinkedEditingEffects(model, input, line_height);
    composeBracketMatchEffects(model, input, line_height);
    composeScrollbars(model);
  }

  void RenderModelComposer::finalizeTextRuns(EditorRenderModel& model, const RenderModelInput& input) const {
    const Vector<SearchMatch>& matches = input.search_matches;
    const int32_t current_index = input.current_search_match;
    const Decorations& decorations = input.document.getDecorations();

    HashSet<size_t> visible_lines;
    collectVisibleRangeEffectSourceLines(model, m_text_layout_, visible_lines);
    VisualRunInput run_input;

    const auto append_search_override = [&](size_t line, uint32_t match_index, const TextRange& range) {
      if (match_index >= matches.size()) return;
      const bool is_current = current_index >= 0 && match_index == static_cast<uint32_t>(current_index);
      const RangeEffectStyle& style =
          is_current ? m_settings_.range_effect_styles.search_current : m_settings_.range_effect_styles.search_match;
      if (style.foreground_color == 0 && style.background_color == 0) return;

      TextRunStyleOverride override;
      override.range = range;
      override.foreground_color = style.foreground_color;
      override.clear_text_background = style.background_color != 0;
      override.priority = is_current ? 80 : 70;
      run_input.style_overrides_by_line[line].push_back(std::move(override));
    };

    for (size_t line : visible_lines) {
      if (input.caret.hasSelection()) {
        const TextRange selection = input.caret.normalizedSelection();
        const RangeEffectStyle& style = m_settings_.range_effect_styles.selection;
        if (!selection.isCollapsed() && line >= selection.start.line && line <= selection.end.line
            && (style.foreground_color != 0 || style.background_color != 0)) {
          TextRunStyleOverride override;
          override.range = selection;
          override.foreground_color = style.foreground_color;
          override.clear_text_background = style.foreground_color != 0 || style.background_color != 0;
          override.priority = 100;
          run_input.style_overrides_by_line[line].push_back(std::move(override));
        }
      }

      for (const DocumentHighlight& highlight : decorations.getLineDocumentHighlights(line)) {
        if (highlight.length == 0) continue;
        const RangeEffectStyle& style =
            RenderStyleUtil::documentHighlightRangeEffectStyle(m_settings_.range_effect_styles, highlight.kind);
        if (style.foreground_color == 0 && style.background_color == 0) continue;

        TextRunStyleOverride override;
        override.range = {{line, highlight.column}, {line, static_cast<size_t>(highlight.column) + highlight.length}};
        override.foreground_color = style.foreground_color;
        override.clear_text_background = style.background_color != 0;
        override.priority = 60;
        run_input.style_overrides_by_line[line].push_back(std::move(override));
      }

      if (line < input.search_match_indices_by_line.size()) {
        for (uint32_t match_index : input.search_match_indices_by_line[line]) {
          if (match_index >= matches.size()) continue;
          append_search_override(line, match_index, matches[match_index].range);
        }
      }
    }

    run_input.active_hit_target = input.active_hit_target;
    if (input.caret.hasSelection()) {
      run_input.selection_range = input.caret.normalizedSelection();
    }
    run_input.colors = m_settings_.render_colors;
    run_input.whitespace_mode = m_settings_.render_whitespace;
    m_text_layout_.finalizeVisualRuns(model, run_input);
  }

  void RenderModelComposer::appendRangeEffectsForRange(EditorRenderModel& model, size_t line, size_t col_start,
                                                       size_t col_end, float rect_height, float y_offset,
                                                       RangeEffectKind kind, const RangeEffectStyle& style) const {
    if (col_start >= col_end) {
      return;
    }
    Vector<Rect> rects;
    m_text_layout_.getColumnSelectionRects(line, col_start, col_end, rect_height, rects);
    for (Rect rect : rects) {
      rect.origin.y += y_offset;
      appendRangeEffect(model, rect, kind, style);
    }
  }

  void RenderModelComposer::composeCursor(EditorRenderModel& model, const RenderModelInput& input,
                                          float line_height) const {
    PointF cursor_screen = m_text_layout_.getPositionScreenCoord(input.caret.active, input.caret.active_affinity);
    model.cursor.text_position = input.caret.active;
    model.cursor.position = cursor_screen;
    model.cursor.height = line_height;
    model.cursor.visible = !input.caret.hasSelection();
    model.cursor.show_dragger = false;
    model.current_line = {0, cursor_screen.y};
  }

  void RenderModelComposer::composeCompositionEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                      float line_height) const {
    if (!input.composition.has_value()) return;

    const TextRange range = input.composition->current_range.normalized();
    if (range.isCollapsed()) return;

    float font_height = m_text_layout_.getLayoutMetrics().font_height;
    float top_padding = (line_height - font_height) * 0.5f;
    for (size_t line = range.start.line; line <= range.end.line && line < input.document.getLineCount(); ++line) {
      const size_t start_column = line == range.start.line ? range.start.column : 0;
      const size_t end_column = line == range.end.line ? range.end.column : input.document.getLineColumns(line);
      appendRangeEffectsForRange(model, line, start_column, end_column, font_height, top_padding,
                                 RangeEffectKind::IME_COMPOSITION, m_settings_.range_effect_styles.ime_composition);
    }
  }

  void RenderModelComposer::composeSelection(EditorRenderModel& model, const RenderModelInput& input,
                                             float line_height) const {
    if (!input.caret.hasSelection()) {
      return;
    }

    TextRange selection = input.caret.selection();
    TextPosition sel_start = selection.start;
    TextPosition sel_end = selection.end;
    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
    }

    const RangeEffectStyle& selection_style = m_settings_.range_effect_styles.selection;
    auto appendSelectionRect = [&](const Rect& rect) {
      appendRangeEffect(model, rect, RangeEffectKind::SELECTION, selection_style);
    };
    auto appendSelectionRectsForRange = [&](size_t line, size_t col_begin, size_t col_end) {
      appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, RangeEffectKind::SELECTION,
                                 selection_style);
    };

    size_t vis_first = sel_start.line;
    size_t vis_last = sel_end.line;
    if (!model.lines.empty()) {
      vis_first = model.lines.front().logical_line;
      vis_last = model.lines.back().logical_line;
    }

    size_t loop_start = std::max(sel_start.line, vis_first);
    size_t loop_end = std::min(sel_end.line, vis_last);

    for (size_t line = loop_start; line <= loop_end && line < input.document.getLineCount(); ++line) {
      const auto& ll = input.document.getLogicalLines()[line];
      if (ll.is_fold_hidden) continue;

      size_t col_begin = (line == sel_start.line) ? sel_start.column : 0;
      uint32_t line_cols = input.document.getLineColumns(line);
      size_t col_end_val = (line == sel_end.line) ? sel_end.column : line_cols;

      if (col_begin >= col_end_val && line != sel_end.line) {
        PointF coord = m_text_layout_.getPositionScreenCoord({line, col_begin});
        Rect rect;
        rect.origin = coord;
        rect.width = m_text_layout_.getLineHeight() * 0.3f;
        rect.height = line_height;
        appendSelectionRect(rect);
        continue;
      }

      if (col_begin < col_end_val) {
        appendSelectionRectsForRange(line, col_begin, col_end_val);
      }
    }

    auto appendProjectedSelectionForOwner = [&](size_t owner_line) {
      TextRange projected_range;
      if (!m_text_layout_.getFoldTailProjectedRange(owner_line, projected_range)) {
        return;
      }

      const size_t source_line = projected_range.start.line;
      if (source_line < sel_start.line || source_line > sel_end.line) {
        return;
      }

      size_t col_begin = projected_range.start.column;
      size_t col_end_val = projected_range.end.column;
      if (source_line == sel_start.line) {
        col_begin = std::max(col_begin, sel_start.column);
      }
      if (source_line == sel_end.line) {
        col_end_val = std::min(col_end_val, sel_end.column);
      }
      if (col_begin >= col_end_val) {
        return;
      }
      appendSelectionRectsForRange(source_line, col_begin, col_end_val);
    };

    HashSet<size_t> projected_owners;
    for (const VisualLine& visual_line : model.lines) {
      if (!projected_owners.insert(visual_line.logical_line).second) {
        continue;
      }
      appendProjectedSelectionForOwner(visual_line.logical_line);
    }

    PointF start_coord = m_text_layout_.getPositionScreenCoord(sel_start);
    model.selection_start_handle.position = start_coord;
    model.selection_start_handle.height = line_height;
    model.selection_start_handle.visible = true;

    PointF end_coord = m_text_layout_.getPositionScreenCoord(sel_end);
    model.selection_end_handle.position = end_coord;
    model.selection_end_handle.height = line_height;
    model.selection_end_handle.visible = true;
  }

  void RenderModelComposer::composeSearchEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                 float line_height) const {
    if (input.search_matches.empty()) return;

    HashSet<size_t> source_lines;
    collectVisibleRangeEffectSourceLines(model, m_text_layout_, source_lines);

    HashSet<uint32_t> emitted_matches;
    for (size_t source_line : source_lines) {
      if (source_line >= input.search_match_indices_by_line.size()) continue;

      for (uint32_t match_index : input.search_match_indices_by_line[source_line]) {
        if (match_index >= input.search_matches.size() || !emitted_matches.insert(match_index).second) {
          continue;
        }

        const TextRange& range = input.search_matches[match_index].range;
        const bool is_current =
            input.current_search_match >= 0 && match_index == static_cast<uint32_t>(input.current_search_match);
        const RangeEffectKind kind = is_current ? RangeEffectKind::SEARCH_CURRENT : RangeEffectKind::SEARCH_MATCH;
        const RangeEffectStyle& style =
            is_current ? m_settings_.range_effect_styles.search_current : m_settings_.range_effect_styles.search_match;

        for (size_t line = range.start.line; line <= range.end.line && line < input.document.getLineCount(); ++line) {
          if (source_lines.find(line) == source_lines.end()) continue;
          const size_t col_begin = line == range.start.line ? range.start.column : 0;
          const size_t col_end = line == range.end.line ? range.end.column : input.document.getLineColumns(line);
          if (col_begin >= col_end) continue;

          appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, kind, style);
        }
      }
    }
  }

  void RenderModelComposer::composeDocumentHighlightEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                             float line_height) const {
    const Decorations& decorations = input.document.getDecorations();
    HashSet<size_t> source_lines;
    collectVisibleRangeEffectSourceLines(model, m_text_layout_, source_lines);
    for (size_t editing_line : source_lines) {
      for (const DocumentHighlight& highlight : decorations.getLineDocumentHighlights(editing_line)) {
        if (highlight.length == 0) continue;
        appendRangeEffectsForRange(
            model, editing_line, highlight.column, static_cast<size_t>(highlight.column) + highlight.length,
            line_height, 0.0f, RenderStyleUtil::documentHighlightRangeEffectKind(highlight.kind),
            RenderStyleUtil::documentHighlightRangeEffectStyle(m_settings_.range_effect_styles, highlight.kind));
      }
    }
  }

  void RenderModelComposer::composeLinkedEditingEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                        float line_height) const {
    for (const LinkedEditingHighlight& highlight : input.linked_editing_highlights) {
      if (highlight.range.isCollapsed()) continue;
      for (size_t line = highlight.range.start.line;
           line <= highlight.range.end.line && line < input.document.getLineCount();
           ++line) {
        size_t col_begin = line == highlight.range.start.line ? highlight.range.start.column : 0;
        uint32_t line_cols = input.document.getLineColumns(line);
        size_t col_end = line == highlight.range.end.line ? highlight.range.end.column : line_cols;
        if (col_begin >= col_end) continue;
        const RangeEffectStyle& style = highlight.is_active ? m_settings_.range_effect_styles.linked_editing_active
                                                            : m_settings_.range_effect_styles.linked_editing_inactive;
        RangeEffectKind kind =
            highlight.is_active ? RangeEffectKind::LINKED_EDITING_ACTIVE : RangeEffectKind::LINKED_EDITING_INACTIVE;
        appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, kind, style);
      }
    }
  }

  void RenderModelComposer::composeGuides(EditorRenderModel& model, const RenderModelInput& input,
                                          float line_height) const {
    const Decorations& decorations = input.document.getDecorations();
    const LayoutMetrics& params = m_text_layout_.getLayoutMetrics();
    float half_line = line_height * 0.5f;
    float equal_gap = params.font_height * 0.1f;
    float dash_y_offset = params.font_ascent * 0.75f;

    U16String space_char = CHAR16(" ");
    float char_width = m_measurer_.measureWidth(space_char, FONT_STYLE_NORMAL);

    auto screenY = [&](size_t line) -> float {
      return m_text_layout_.getPositionScreenCoord({line, 0}).y;
    };
    auto screenX = [&](size_t line, size_t col) -> float {
      return m_text_layout_.getPositionScreenCoord({line, col}).x;
    };

    const auto is_hidden = [&](size_t line) {
      return line >= input.document.getLineCount() || input.document.getLogicalLines()[line].is_fold_hidden;
    };

    for (const IndentGuide& guide : decorations.getIndentGuides()) {
      if (is_hidden(guide.start.line) || is_hidden(guide.end.line)) {
        continue;
      }
      float x = screenX(guide.start.line, guide.start.column);
      float y_top = screenY(guide.start.line) + line_height;
      float y_bot = screenY(guide.end.line);
      if (y_top >= y_bot) continue;
      GuideSegment seg;
      seg.direction = GuideDirection::VERTICAL;
      seg.type = GuideType::INDENT;
      seg.style = GuideStyle::SOLID;
      seg.start = {x, y_top};
      seg.end = {x, y_bot};
      model.guide_segments.push_back(seg);
    }

    for (const BracketGuide& guide : decorations.getBracketGuides()) {
      if (is_hidden(guide.parent.line) || is_hidden(guide.end.line)) {
        continue;
      }
      float x = screenX(guide.parent.line, guide.parent.column);
      float y_top = screenY(guide.parent.line) + line_height;
      float y_bot = screenY(guide.end.line);
      if (y_top < y_bot) {
        GuideSegment vline;
        vline.direction = GuideDirection::VERTICAL;
        vline.type = GuideType::BRACKET;
        vline.style = GuideStyle::SOLID;
        vline.start = {x, y_top};
        vline.end = {x, y_bot};
        model.guide_segments.push_back(vline);
      }
      for (const TextPosition& child : guide.children) {
        if (is_hidden(child.line)) continue;
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

    for (const FlowGuide& guide : decorations.getFlowGuides()) {
      if (is_hidden(guide.start.line) || is_hidden(guide.end.line)) {
        continue;
      }
      float indent_x = screenX(guide.end.line, guide.end.column);
      float left_x = indent_x - char_width * 2;
      float y_bot = screenY(guide.end.line) + half_line;
      float y_top = screenY(guide.start.line) + half_line;

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

    for (const SeparatorGuide& guide : decorations.getSeparatorGuides()) {
      if (guide.line < 0) continue;
      const size_t line = static_cast<size_t>(guide.line);
      if (is_hidden(line)) continue;
      float x_start = screenX(line, guide.text_end_column);
      float sep_width = static_cast<float>(guide.count) * 16.0f * char_width;
      float y_center = screenY(line) + half_line;
      GuideSegment seg;
      seg.direction = GuideDirection::HORIZONTAL;
      seg.type = GuideType::SEPARATOR;
      seg.style = GuideStyle::SOLID;
      if (guide.style == SeparatorStyle::DOUBLE) {
        seg.start = {x_start, y_center - equal_gap};
        seg.end = {x_start + sep_width, y_center - equal_gap};
        model.guide_segments.push_back(seg);
        seg.start = {x_start, y_center + equal_gap};
        seg.end = {x_start + sep_width, y_center + equal_gap};
        model.guide_segments.push_back(seg);
      } else {
        float line_top = screenY(line);
        float y_dash = line_top + dash_y_offset;
        seg.start = {x_start, y_dash};
        seg.end = {x_start + sep_width, y_dash};
        model.guide_segments.push_back(seg);
      }
    }
  }

  void RenderModelComposer::composeDiagnosticEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                      float line_height) const {
    const Decorations& decorations = input.document.getDecorations();
    float font_height = m_text_layout_.getLayoutMetrics().font_height;
    float top_padding = (line_height - font_height) * 0.5f;

    HashSet<size_t> emitted_lines;
    for (const auto& vl : model.lines) {
      if (getVisualLineSemantics(vl.kind).text_semantics != TextSemanticsPolicy::PARTICIPATES) continue;
      const size_t editing_line = vl.logical_line;
      if (!emitted_lines.insert(editing_line).second) continue;
      for (const Diagnostic& diagnostic : decorations.getLineDiagnostics(editing_line)) {
        if (diagnostic.length == 0) continue;
        appendRangeEffectsForRange(
            model, editing_line, diagnostic.column, static_cast<size_t>(diagnostic.column) + diagnostic.length,
            font_height, top_padding, RenderStyleUtil::diagnosticRangeEffectKind(diagnostic.severity),
            RenderStyleUtil::diagnosticRangeEffectStyle(m_settings_.range_effect_styles, diagnostic.severity));
      }
    }
  }

  void RenderModelComposer::composeBracketMatchEffects(EditorRenderModel& model, const RenderModelInput& input,
                                                       float line_height) const {
    if (input.bracket_pairs.empty()) return;

    TextPosition open_pos, close_pos;
    bool found = false;

    if (input.external_bracket_match.has_value()) {
      open_pos = input.external_bracket_match->start;
      close_pos = input.external_bracket_match->end;
      found = true;
    } else {
      size_t cursor_line = input.caret.active.line;
      size_t cursor_col = input.caret.active.column;
      size_t line_count = input.document.getLineCount();
      if (cursor_line >= line_count) return;

      const U16String& line_text = input.document.getLineU16TextRef(cursor_line);

      auto checkChar = [&](size_t line, size_t col) -> bool {
        if (col >= line_text.length()) return false;
        char16_t ch = line_text[col];
        for (const BracketPair& pair : input.bracket_pairs) {
          if (static_cast<char16_t>(pair.open) == ch) {
            open_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            size_t scan_line = line;
            size_t scan_col = col + 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line < line_count) {
              const U16String& scan_text = scan_line == line ? line_text : input.document.getLineU16TextRef(scan_line);
              while (scan_col < scan_text.length() && scanned < kMaxBracketScanChars) {
                char16_t sc = scan_text[scan_col];
                if (sc == static_cast<char16_t>(pair.open))
                  ++depth;
                else if (sc == static_cast<char16_t>(pair.close)) {
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
          if (static_cast<char16_t>(pair.close) == ch) {
            close_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            int64_t scan_line_s = static_cast<int64_t>(line);
            int64_t scan_col_s = static_cast<int64_t>(col) - 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line_s >= 0) {
              const U16String& scan_text = (static_cast<size_t>(scan_line_s) == line)
                                               ? line_text
                                               : input.document.getLineU16TextRef(static_cast<size_t>(scan_line_s));
              while (scan_col_s >= 0 && scanned < kMaxBracketScanChars) {
                char16_t sc = scan_text[static_cast<size_t>(scan_col_s)];
                if (sc == static_cast<char16_t>(pair.close))
                  ++depth;
                else if (sc == static_cast<char16_t>(pair.open)) {
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
                const U16String& prev_text = input.document.getLineU16TextRef(static_cast<size_t>(scan_line_s));
                scan_col_s = static_cast<int64_t>(prev_text.length()) - 1;
              }
            }
            return false;
          }
        }
        return false;
      };

      found = checkChar(cursor_line, cursor_col);
      if (!found && cursor_col > 0) {
        found = checkChar(cursor_line, cursor_col - 1);
      }
    }

    if (!found) return;

    auto addRect = [&](const TextPosition& pos) {
      if (pos.line >= input.document.getLineCount()) return;
      appendRangeEffectsForRange(model, pos.line, pos.column, pos.column + 1, line_height, 0.0f,
                                 RangeEffectKind::BRACKET_MATCH, m_settings_.range_effect_styles.bracket_match);
    };

    addRect(open_pos);
    addRect(close_pos);
  }

  void RenderModelComposer::composeScrollbars(EditorRenderModel& model) const {
    m_interaction_.computeScrollbarModels(model.vertical_scrollbar, model.horizontal_scrollbar);
  }
}
