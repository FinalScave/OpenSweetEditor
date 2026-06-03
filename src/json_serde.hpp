//
// Private JSON serialization helpers for core implementation.
// Keep third-party JSON dependencies out of public headers.
//
#ifndef SWEETEDITOR_JSON_SERDE_HPP
#define SWEETEDITOR_JSON_SERDE_HPP

#include <nlohmann/json.hpp>
#include <sweeteditor/editor_types.h>
#include <sweeteditor/gesture.h>
#include <sweeteditor/visual.h>

namespace NS_SWEETEDITOR {
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(PointF, x, y)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextPosition, line, column)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextRange, start, end)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(Rect, origin, width, height)

  NLOHMANN_JSON_SERIALIZE_ENUM(EventType, {
    {EventType::UNDEFINED, "UNDEFINED"},
    {EventType::TOUCH_DOWN, "TOUCH_DOWN"},
    {EventType::TOUCH_POINTER_DOWN, "TOUCH_POINTER_DOWN"},
    {EventType::TOUCH_MOVE, "TOUCH_MOVE"},
    {EventType::TOUCH_POINTER_UP, "TOUCH_POINTER_UP"},
    {EventType::TOUCH_UP, "TOUCH_UP"},
    {EventType::TOUCH_CANCEL, "TOUCH_CANCEL"},
    {EventType::MOUSE_DOWN, "MOUSE_DOWN"},
    {EventType::MOUSE_MOVE, "MOUSE_MOVE"},
    {EventType::MOUSE_UP, "MOUSE_UP"},
    {EventType::MOUSE_WHEEL, "MOUSE_WHEEL"},
    {EventType::MOUSE_RIGHT_DOWN, "MOUSE_RIGHT_DOWN"},
    {EventType::DIRECT_SCALE, "DIRECT_SCALE"},
    {EventType::DIRECT_SCROLL, "DIRECT_SCROLL"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(GestureType, {
    {GestureType::UNDEFINED, "UNDEFINED"},
    {GestureType::TAP, "TAP"},
    {GestureType::DOUBLE_TAP, "DOUBLE_TAP"},
    {GestureType::LONG_PRESS, "LONG_PRESS"},
    {GestureType::SCALE, "SCALE"},
    {GestureType::SCROLL, "SCROLL"},
    {GestureType::FAST_SCROLL, "FAST_SCROLL"},
    {GestureType::DRAG_SELECT, "DRAG_SELECT"},
    {GestureType::CONTEXT_MENU, "CONTEXT_MENU"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(HitTargetType, {
    {HitTargetType::NONE, "NONE"},
    {HitTargetType::INLAY_HINT_TEXT, "INLAY_HINT_TEXT"},
    {HitTargetType::INLAY_HINT_ICON, "INLAY_HINT_ICON"},
    {HitTargetType::GUTTER_ICON, "GUTTER_ICON"},
    {HitTargetType::FOLD_PLACEHOLDER, "FOLD_PLACEHOLDER"},
    {HitTargetType::FOLD_GUTTER, "FOLD_GUTTER"},
    {HitTargetType::INLAY_HINT_COLOR, "INLAY_HINT_COLOR"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(HitTarget, type, line, column, icon_id, color_value)
  NLOHMANN_JSON_SERIALIZE_ENUM(PointerCursorType, {
    {PointerCursorType::DEFAULT, "DEFAULT"},
    {PointerCursorType::TEXT, "TEXT"},
    {PointerCursorType::HAND, "HAND"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GestureResult, type, tap_point, modifiers, scale, scroll_x, scroll_y, cursor_position, has_selection, selection, view_scroll_x, view_scroll_y, view_scale, hit_target, needs_edge_scroll, needs_fling, needs_animation, is_handle_drag, pointer_cursor_type)

  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextChange, range, old_text, new_text)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextEditResult, changed, changes, cursor_before, cursor_after)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(KeyEventResult, handled, content_changed, cursor_changed, selection_changed, edit_result, command)

  NLOHMANN_JSON_SERIALIZE_ENUM(VisualRunType, {
    {VisualRunType::TEXT, "TEXT"},
    {VisualRunType::WHITESPACE, "WHITESPACE"},
    {VisualRunType::NEWLINE, "NEWLINE"},
    {VisualRunType::INLAY_HINT, "INLAY_HINT"},
    {VisualRunType::PHANTOM_TEXT, "PHANTOM_TEXT"},
    {VisualRunType::FOLD_PLACEHOLDER, "FOLD_PLACEHOLDER"},
    {VisualRunType::TAB, "TAB"},
    {VisualRunType::CODELENS, "CODELENS"},
    {VisualRunType::LINK, "LINK"},
  })
  inline void to_json(nlohmann::json& j, const VisualRun& r) {
    U8String u8_text;
    if (!r.text.empty()) {
      StrUtil::convertUTF16ToUTF8(r.text, u8_text);
    }
    nlohmann::json style_j = {
      {"font_style", r.style.font_style},
      {"color", r.style.color},
      {"background_color", r.style.background_color},
    };
    j = nlohmann::json{
      {"type", r.type},
      {"x", r.x},
      {"y", r.y},
      {"text", u8_text},
      {"style", style_j},
      {"icon_id", r.icon_id},
      {"color_value", r.color_value},
      {"width", r.width},
      {"padding", r.padding},
      {"margin", r.margin},
      {"active", r.active},
    };
  }
  inline void from_json(const nlohmann::json& j, VisualRun& r) {
    j.at("type").get_to(r.type);
    j.at("x").get_to(r.x);
    j.at("y").get_to(r.y);
    U8String u8_text;
    j.at("text").get_to(u8_text);
    if (!u8_text.empty()) {
      StrUtil::convertUTF8ToUTF16(u8_text, r.text);
    }
    if (j.contains("style")) {
      const auto& s = j.at("style");
      s.at("font_style").get_to(r.style.font_style);
      if (s.contains("color")) s.at("color").get_to(r.style.color);
      if (s.contains("background_color")) s.at("background_color").get_to(r.style.background_color);
    }
    j.at("icon_id").get_to(r.icon_id);
    if (j.contains("color_value")) j.at("color_value").get_to(r.color_value);
    if (j.contains("width")) j.at("width").get_to(r.width);
    if (j.contains("padding")) j.at("padding").get_to(r.padding);
    if (j.contains("margin")) j.at("margin").get_to(r.margin);
    if (j.contains("active")) j.at("active").get_to(r.active);
  }
  NLOHMANN_JSON_SERIALIZE_ENUM(FoldState, {
    {FoldState::NONE, "NONE"},
    {FoldState::EXPANDED, "EXPANDED"},
    {FoldState::COLLAPSED, "COLLAPSED"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(VisualLineKind, {
    {VisualLineKind::CONTENT, "CONTENT"},
    {VisualLineKind::PHANTOM, "PHANTOM"},
    {VisualLineKind::CODELENS, "CODELENS"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(VisualLine, logical_line, wrap_index, line_number_position, runs, kind, owns_gutter_semantics, fold_state)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(Cursor, text_position, position, height, visible, show_dragger)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(SelectionHandle, position, height, visible)
  NLOHMANN_JSON_SERIALIZE_ENUM(GuideDirection, {
    {GuideDirection::VERTICAL, "VERTICAL"},
    {GuideDirection::HORIZONTAL, "HORIZONTAL"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(GuideType, {
    {GuideType::INDENT, "INDENT"},
    {GuideType::BRACKET, "BRACKET"},
    {GuideType::FLOW, "FLOW"},
    {GuideType::SEPARATOR, "SEPARATOR"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(GuideStyle, {
    {GuideStyle::SOLID, "SOLID"},
    {GuideStyle::DASHED, "DASHED"},
    {GuideStyle::DOUBLE, "DOUBLE"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GuideSegment, direction, type, style, start, end, arrow_end)
  NLOHMANN_JSON_SERIALIZE_ENUM(RangeEffectKind, {
    {RangeEffectKind::SELECTION, "SELECTION"},
    {RangeEffectKind::SEARCH_MATCH, "SEARCH_MATCH"},
    {RangeEffectKind::SEARCH_CURRENT, "SEARCH_CURRENT"},
    {RangeEffectKind::DOCUMENT_HIGHLIGHT_TEXT, "DOCUMENT_HIGHLIGHT_TEXT"},
    {RangeEffectKind::DOCUMENT_HIGHLIGHT_READ, "DOCUMENT_HIGHLIGHT_READ"},
    {RangeEffectKind::DOCUMENT_HIGHLIGHT_WRITE, "DOCUMENT_HIGHLIGHT_WRITE"},
    {RangeEffectKind::LINKED_EDITING_ACTIVE, "LINKED_EDITING_ACTIVE"},
    {RangeEffectKind::LINKED_EDITING_INACTIVE, "LINKED_EDITING_INACTIVE"},
    {RangeEffectKind::IME_COMPOSITION, "IME_COMPOSITION"},
    {RangeEffectKind::BRACKET_MATCH, "BRACKET_MATCH"},
    {RangeEffectKind::DIAGNOSTIC_ERROR, "DIAGNOSTIC_ERROR"},
    {RangeEffectKind::DIAGNOSTIC_WARNING, "DIAGNOSTIC_WARNING"},
    {RangeEffectKind::DIAGNOSTIC_INFO, "DIAGNOSTIC_INFO"},
    {RangeEffectKind::DIAGNOSTIC_HINT, "DIAGNOSTIC_HINT"},
  })
  NLOHMANN_JSON_SERIALIZE_ENUM(RangeEffectUnderlineStyle, {
    {RangeEffectUnderlineStyle::NONE, "NONE"},
    {RangeEffectUnderlineStyle::SOLID, "SOLID"},
    {RangeEffectUnderlineStyle::DASHED, "DASHED"},
    {RangeEffectUnderlineStyle::WAVY, "WAVY"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(RangeEffectStyle, foreground_color, background_color, border_color, underline_color, underline_style)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(RangeEffectRenderItem, rect, kind, style)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GutterIconRenderItem, logical_line, icon_id, rect)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(FoldMarkerRenderItem, logical_line, fold_state, rect)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(ScrollbarModel, visible, alpha, thumb_active, track, thumb)
  NLOHMANN_JSON_SERIALIZE_ENUM(CurrentLineRenderMode, {
    {CurrentLineRenderMode::BACKGROUND, "BACKGROUND"},
    {CurrentLineRenderMode::BORDER, "BORDER"},
    {CurrentLineRenderMode::NONE, "NONE"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(EditorRenderModel, split_x, split_line_visible, scroll_x, scroll_y, viewport_width, viewport_height, current_line, current_line_render_mode, lines, cursor, range_effects, selection_start_handle, selection_end_handle, guide_segments, max_gutter_icons, gutter_icons, fold_markers, vertical_scrollbar, horizontal_scrollbar, gutter_sticky, gutter_visible, pointer_cursor_type)
  NLOHMANN_JSON_SERIALIZE_ENUM(FoldArrowMode, {
    {FoldArrowMode::AUTO, "AUTO"},
    {FoldArrowMode::ALWAYS, "ALWAYS"},
    {FoldArrowMode::HIDDEN, "HIDDEN"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(LayoutMetrics, font_height, font_ascent, line_spacing_add, line_spacing_mult, line_number_margin, line_number_width, content_start_padding, max_gutter_icons, inlay_hint_padding, inlay_hint_margin, fold_arrow_mode, has_fold_regions, gutter_sticky, gutter_visible)
}

#endif //SWEETEDITOR_JSON_SERDE_HPP
