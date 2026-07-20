#include <algorithm>
#include <sweeteditor/render_composer.h>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/interaction.h>
#include <sweeteditor/linked_editing.h>
#include "logging.h"
#include "render_style_util.hpp"

namespace NS_SWEETEDITOR {

  namespace {
    void appendRangeEffect(EditorRenderModel& model, const Rect& rect,
                           RangeEffectKind kind, const RangeEffectStyle& style) {
      if (!RenderStyleUtil::hasRangeEffectPaint(style) || rect.width <= 0.0f || rect.height <= 0.0f) {
        return;
      }
      RangeEffectRenderItem item;
      item.rect = rect;
      item.kind = kind;
      item.style = style;
      model.range_effects.push_back(item);
    }

    void collectVisibleRangeEffectSourceLines(const EditorRenderModel& model,
                                              TextLayout* text_layout,
                                              HashSet<size_t>& out_source_lines) {
      for (const VisualLine& visual_line : model.lines) {
        out_source_lines.insert(visual_line.logical_line);

        TextRange projected_range;
        if (text_layout != nullptr
            && text_layout->getFoldTailProjectedRange(visual_line.logical_line, projected_range)) {
          out_source_lines.insert(projected_range.start.line);
        }
      }
    }
  }

  RenderComposer::RenderComposer(TextLayout* text_layout, DecorationManager* decorations, EditorSettings* settings)
      : m_text_layout_(text_layout), m_decorations_(decorations), m_settings_(settings) {
  }

  void RenderComposer::appendRangeEffectsForRange(EditorRenderModel& model,
                                                  size_t line,
                                                  size_t col_start,
                                                  size_t col_end,
                                                  float rect_height,
                                                  float y_offset,
                                                  RangeEffectKind kind,
                                                  const RangeEffectStyle& style) const {
    if (m_text_layout_ == nullptr || col_start >= col_end) {
      return;
    }
    Vector<Rect> rects;
    m_text_layout_->getColumnSelectionRects(line, col_start, col_end, rect_height, rects);
    for (Rect rect : rects) {
      rect.origin.y += y_offset;
      appendRangeEffect(model, rect, kind, style);
    }
  }

  void RenderComposer::buildCursorModel(EditorRenderModel& model, const CaretState& caret,
                                         float line_height) const {
    PointF cursor_screen = m_text_layout_->getPositionScreenCoord(caret.active,
                                                                  caret.active_affinity);
    model.cursor.text_position = caret.active;
    model.cursor.position = cursor_screen;
    model.cursor.height = line_height;
    model.cursor.visible = !caret.hasSelection();
    model.cursor.show_dragger = false;
    model.current_line = {0, cursor_screen.y};
  }

  void RenderComposer::buildCompositionRangeEffect(EditorRenderModel& model, const CompositionState& composition,
                                                   float line_height) const {
    if (composition.kind == CompositionKind::NONE || composition.preedit_columns == 0) return;
    if (m_settings_ == nullptr) return;

    float font_height = m_text_layout_->getLayoutMetrics().font_height;
    float top_padding = (line_height - font_height) * 0.5f;
    appendRangeEffectsForRange(model,
                               composition.start_position.line,
                               composition.start_position.column,
                               composition.start_position.column + composition.preedit_columns,
                               font_height,
                               top_padding,
                               RangeEffectKind::IME_COMPOSITION,
                               m_settings_->range_effect_styles.ime_composition);
    LOGD("buildRenderModel: composition range effect preedit_cols=%zu, start_pos=(%zu,%zu)",
         composition.preedit_columns,
         composition.start_position.line, composition.start_position.column);
  }

  void RenderComposer::buildSelectionRangeEffects(EditorRenderModel& model, Document* document,
                                                  const CaretState& caret, float line_height) const {
    if (!caret.hasSelection() || document == nullptr) {
      return;
    }

    TextRange selection = caret.selection();
    TextPosition sel_start = selection.start;
    TextPosition sel_end = selection.end;
    if (sel_end < sel_start) {
      std::swap(sel_start, sel_end);
    }

    const RangeEffectStyle* selection_style = m_settings_ == nullptr
        ? nullptr
        : &m_settings_->range_effect_styles.selection;
    auto appendSelectionRect = [&](const Rect& rect) {
      if (selection_style == nullptr) return;
      appendRangeEffect(model, rect, RangeEffectKind::SELECTION, *selection_style);
    };
    auto appendSelectionRectsForRange = [&](size_t line, size_t col_begin, size_t col_end) {
      if (selection_style == nullptr) return;
      appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, RangeEffectKind::SELECTION, *selection_style);
    };

    size_t vis_first = sel_start.line;
    size_t vis_last = sel_end.line;
    if (!model.lines.empty()) {
      vis_first = model.lines.front().logical_line;
      vis_last = model.lines.back().logical_line;
    }

    size_t loop_start = std::max(sel_start.line, vis_first);
    size_t loop_end = std::min(sel_end.line, vis_last);

    for (size_t line = loop_start; line <= loop_end && line < document->getLineCount(); ++line) {
      const auto& ll = document->getLogicalLines()[line];
      if (ll.is_fold_hidden) continue;

      size_t col_begin = (line == sel_start.line) ? sel_start.column : 0;
      uint32_t line_cols = document->getLineColumns(line);
      size_t col_end_val = (line == sel_end.line) ? sel_end.column : line_cols;

      if (col_begin >= col_end_val && line != sel_end.line) {
        PointF coord = m_text_layout_->getPositionScreenCoord({line, col_begin});
        Rect rect;
        rect.origin = coord;
        rect.width = m_text_layout_->getLineHeight() * 0.3f;
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
      if (!m_text_layout_->getFoldTailProjectedRange(owner_line, projected_range)) {
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

    PointF start_coord = m_text_layout_->getPositionScreenCoord(sel_start);
    model.selection_start_handle.position = start_coord;
    model.selection_start_handle.height = line_height;
    model.selection_start_handle.visible = true;

    PointF end_coord = m_text_layout_->getPositionScreenCoord(sel_end);
    model.selection_end_handle.position = end_coord;
    model.selection_end_handle.height = line_height;
    model.selection_end_handle.visible = true;
  }

  void RenderComposer::buildSearchRangeEffects(EditorRenderModel& model, Document* document,
                                               const Vector<SearchMatch>& matches,
                                               const Vector<Vector<uint32_t>>& match_indices_by_line,
                                               int32_t current_index,
                                               float line_height) const {
    if (document == nullptr || m_settings_ == nullptr || matches.empty()) return;

    HashSet<size_t> source_lines;
    collectVisibleRangeEffectSourceLines(model, m_text_layout_, source_lines);

    HashSet<uint32_t> emitted_matches;
    for (size_t source_line : source_lines) {
      if (source_line >= match_indices_by_line.size()) continue;

      for (uint32_t match_index : match_indices_by_line[source_line]) {
        if (match_index >= matches.size() || !emitted_matches.insert(match_index).second) {
          continue;
        }

        const SearchMatch& match = matches[match_index];
        const bool is_current = current_index >= 0 && match_index == static_cast<uint32_t>(current_index);
        const RangeEffectKind kind = is_current ? RangeEffectKind::SEARCH_CURRENT : RangeEffectKind::SEARCH_MATCH;
        const RangeEffectStyle& style = is_current
            ? m_settings_->range_effect_styles.search_current
            : m_settings_->range_effect_styles.search_match;

        for (size_t line = match.range.start.line; line <= match.range.end.line && line < document->getLineCount(); ++line) {
          if (source_lines.find(line) == source_lines.end()) continue;
          size_t col_begin = line == match.range.start.line ? match.range.start.column : 0;
          size_t col_end = line == match.range.end.line ? match.range.end.column : document->getLineColumns(line);
          if (col_begin >= col_end) continue;

          appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, kind, style);
        }
      }
    }
  }

  void RenderComposer::buildDocumentHighlightRangeEffects(EditorRenderModel& model, Document* document,
                                                          float line_height) const {
    if (m_decorations_ == nullptr || document == nullptr || m_settings_ == nullptr) return;

    HashSet<size_t> source_lines;
    collectVisibleRangeEffectSourceLines(model, m_text_layout_, source_lines);
    for (size_t source_line : source_lines) {
      if (source_line >= document->getLineCount()) continue;
      const auto& highlights = m_decorations_->getLineDocumentHighlights(source_line);
      if (highlights.empty()) continue;

      for (const auto& highlight : highlights) {
        if (highlight.length == 0) continue;
        const size_t col_begin = highlight.column;
        const size_t col_end = col_begin + static_cast<size_t>(highlight.length);
        appendRangeEffectsForRange(model,
                                   source_line,
                                   col_begin,
                                   col_end,
                                   line_height,
                                   0.0f,
                                   RenderStyleUtil::documentHighlightRangeEffectKind(highlight.kind),
                                   RenderStyleUtil::documentHighlightRangeEffectStyle(m_settings_->range_effect_styles,
                                                                                      highlight.kind));
      }
    }
  }

  void RenderComposer::buildLinkedEditingRangeEffects(EditorRenderModel& model, Document* document,
                                                      const LinkedEditingSession* linked_editing_session,
                                                      float line_height) const {
    if (linked_editing_session == nullptr || !linked_editing_session->isActive()) return;
    if (document == nullptr || m_settings_ == nullptr) return;

    auto highlights = linked_editing_session->getAllHighlights();
    for (const auto& hl : highlights) {
      if (hl.range.start == hl.range.end) continue;
      for (size_t line = hl.range.start.line; line <= hl.range.end.line && line < document->getLineCount(); ++line) {
        size_t col_begin = (line == hl.range.start.line) ? hl.range.start.column : 0;
        uint32_t line_cols = document->getLineColumns(line);
        size_t col_end = (line == hl.range.end.line) ? hl.range.end.column : line_cols;
        if (col_begin >= col_end) continue;
        const RangeEffectStyle& style = hl.is_active
            ? m_settings_->range_effect_styles.linked_editing_active
            : m_settings_->range_effect_styles.linked_editing_inactive;
        RangeEffectKind kind = hl.is_active
            ? RangeEffectKind::LINKED_EDITING_ACTIVE
            : RangeEffectKind::LINKED_EDITING_INACTIVE;
        appendRangeEffectsForRange(model, line, col_begin, col_end, line_height, 0.0f, kind, style);
      }
    }
  }

  void RenderComposer::buildGuideSegments(EditorRenderModel& model, Document* document,
                                          TextMeasurer& measurer, float line_height) const {
    if (m_decorations_ == nullptr || document == nullptr) return;

    const LayoutMetrics& params = m_text_layout_->getLayoutMetrics();
    float half_line = line_height * 0.5f;
    float equal_gap = params.font_height * 0.1f;
    float dash_y_offset = params.font_ascent * 0.75f;

    U16String space_char = CHAR16(" ");
    float char_width = measurer.measureWidth(space_char, FONT_STYLE_NORMAL);

    auto screenY = [&](size_t line) -> float {
      return m_text_layout_->getPositionScreenCoord({line, 0}).y;
    };
    auto screenX = [&](size_t line, size_t col) -> float {
      return m_text_layout_->getPositionScreenCoord({line, col}).x;
    };

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

  void RenderComposer::buildDiagnosticRangeEffects(EditorRenderModel& model, Document* document,
                                                   float line_height) const {
    if (m_decorations_ == nullptr || document == nullptr || m_settings_ == nullptr) return;

    float font_height = m_text_layout_->getLayoutMetrics().font_height;
    float top_padding = (line_height - font_height) * 0.5f;

    HashSet<size_t> emitted_lines;
    for (const auto& vl : model.lines) {
      if (getVisualLineSemantics(vl.kind).text_semantics != TextSemanticsPolicy::PARTICIPATES) continue;
      size_t logical_line = vl.logical_line;
      if (!emitted_lines.insert(logical_line).second) continue;
      const auto& diags = m_decorations_->getLineDiagnostics(logical_line);
      if (diags.empty()) continue;

      for (const auto& ds : diags) {
        if (ds.length == 0) continue;
        appendRangeEffectsForRange(model,
                                   logical_line,
                                   ds.column,
                                   ds.column + ds.length,
                                   font_height,
                                   top_padding,
                                   RenderStyleUtil::diagnosticRangeEffectKind(ds.severity),
                                   RenderStyleUtil::diagnosticRangeEffectStyle(m_settings_->range_effect_styles,
                                                                               ds.severity));
      }
    }
  }

  void RenderComposer::buildBracketHighlightRangeEffects(EditorRenderModel& model, Document* document,
                                                         const TextPosition& cursor_position, const Vector<BracketPair>& bracket_pairs,
                                                         const TextPosition& external_bracket_open, const TextPosition& external_bracket_close,
                                                         bool has_external_brackets, float line_height) const {
    if (document == nullptr || bracket_pairs.empty() || m_settings_ == nullptr) return;

    TextPosition open_pos, close_pos;
    bool found = false;

    if (has_external_brackets) {
      open_pos = external_bracket_open;
      close_pos = external_bracket_close;
      found = true;
    } else {
      size_t cursor_line = cursor_position.line;
      size_t cursor_col = cursor_position.column;
      size_t line_count = document->getLineCount();
      if (cursor_line >= line_count) return;

      const U16String& line_text = document->getLineU16TextRef(cursor_line);

      auto checkChar = [&](size_t line, size_t col) -> bool {
        if (col >= line_text.length()) return false;
        char16_t ch = line_text[col];
        for (const auto& bp : bracket_pairs) {
          if (static_cast<char16_t>(bp.open) == ch) {
            open_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            size_t scan_line = line;
            size_t scan_col = col + 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line < line_count) {
              const U16String& scan_text = (scan_line == line) ? line_text : document->getLineU16TextRef(scan_line);
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
            close_pos = {line, col};
            size_t depth = 1;
            size_t scanned = 0;
            int64_t scan_line_s = static_cast<int64_t>(line);
            int64_t scan_col_s = static_cast<int64_t>(col) - 1;
            while (depth > 0 && scanned < kMaxBracketScanChars && scan_line_s >= 0) {
              const U16String& scan_text = (static_cast<size_t>(scan_line_s) == line)
                  ? line_text
                  : document->getLineU16TextRef(static_cast<size_t>(scan_line_s));
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
                const U16String& prev_text = document->getLineU16TextRef(static_cast<size_t>(scan_line_s));
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
      if (pos.line >= document->getLineCount()) return;
      appendRangeEffectsForRange(model,
                                 pos.line,
                                 pos.column,
                                 pos.column + 1,
                                 line_height,
                                 0.0f,
                                 RangeEffectKind::BRACKET_MATCH,
                                 m_settings_->range_effect_styles.bracket_match);
    };

    addRect(open_pos);
    addRect(close_pos);
  }

  void RenderComposer::buildScrollbarModel(EditorRenderModel& model, const EditorInteraction& interaction) const {
    interaction.computeScrollbarModels(model.vertical_scrollbar, model.horizontal_scrollbar);
  }
}
