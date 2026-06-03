//
// Created by Scave on 2026/4/4.
//
#include <algorithm>
#include <sweeteditor/editor_types.h>
#include <sweeteditor/gesture.h>

namespace NS_SWEETEDITOR {
  bool Viewport::valid() const {
    return width > 1 && height > 1;
  }

  U8String Viewport::dump() const {
    return "Viewport {width = " + std::to_string(width) + ", height = " + std::to_string(height) + "}";
  }

  U8String ViewState::dump() const {
    return "ViewState {scale = " + std::to_string(scale) + ", scroll_x = " + std::to_string(scroll_x) + ", scroll_y = " + std::to_string(scroll_y) + "}";
  }

  bool KeyEvent::isTextInput() const {
    return key_code == KeyCode::NONE && !text.empty();
  }

  void CaretState::setSelection(const TextRange& range) {
    selection = range;
    has_selection = !(range.start == range.end);
    cursor = range.end;
  }

  void CaretState::clearSelection() {
    selection = {};
    has_selection = false;
  }

  TextRange CaretState::normalizedSelection() const {
    TextRange r = selection;
    if (r.end < r.start) std::swap(r.start, r.end);
    return r;
  }

  TouchConfig EditorOptions::simpleAsTouchConfig() const {
    return TouchConfig {touch_slop, double_tap_timeout, long_press_ms, fling_friction, fling_min_velocity, fling_max_velocity};
  }

  U8String EditorOptions::dump() const {
    return "EditorOptions {touch_slop = " + std::to_string(touch_slop)
        + ", double_tap_timeout = " + std::to_string(double_tap_timeout)
        + ", long_press_ms = " + std::to_string(long_press_ms)
        + ", fling_friction = " + std::to_string(fling_friction)
        + ", fling_min_velocity = " + std::to_string(fling_min_velocity)
        + ", fling_max_velocity = " + std::to_string(fling_max_velocity)
        + ", max_undo_stack_size = " + std::to_string(max_undo_stack_size)
        + ", key_chord_timeout_ms = " + std::to_string(key_chord_timeout_ms)
        + ", reveal_selection_end_on_select_all = " + (reveal_selection_end_on_select_all ? "true" : "false")
        + "}";
  }

  bool EditorRenderColors::operator==(const EditorRenderColors& other) const {
    return text_foreground == other.text_foreground
        && link_foreground == other.link_foreground
        && active_link_foreground == other.active_link_foreground
        && codelens_foreground == other.codelens_foreground
        && active_codelens_foreground == other.active_codelens_foreground;
  }

  bool EditorRenderColors::operator!=(const EditorRenderColors& other) const {
    return !(*this == other);
  }

  bool RangeEffectStyle::operator==(const RangeEffectStyle& other) const {
    return foreground_color == other.foreground_color
        && background_color == other.background_color
        && border_color == other.border_color
        && underline_color == other.underline_color
        && underline_style == other.underline_style;
  }

  bool RangeEffectStyle::operator!=(const RangeEffectStyle& other) const {
    return !(*this == other);
  }

  bool EditorRangeEffectStyles::operator==(const EditorRangeEffectStyles& other) const {
    return selection == other.selection
        && search_match == other.search_match
        && search_current == other.search_current
        && document_highlight_text == other.document_highlight_text
        && document_highlight_read == other.document_highlight_read
        && document_highlight_write == other.document_highlight_write
        && linked_editing_active == other.linked_editing_active
        && linked_editing_inactive == other.linked_editing_inactive
        && ime_composition == other.ime_composition
        && bracket_match == other.bracket_match
        && diagnostic_error == other.diagnostic_error
        && diagnostic_warning == other.diagnostic_warning
        && diagnostic_info == other.diagnostic_info
        && diagnostic_hint == other.diagnostic_hint;
  }

  bool EditorRangeEffectStyles::operator!=(const EditorRangeEffectStyles& other) const {
    return !(*this == other);
  }

  U8String EditorSettings::dump() const {
    return "EditorSettings {max_scale = " + std::to_string(max_scale)
        + ", read_only = " + (read_only ? "true" : "false")
        + ", insert_spaces = " + (insert_spaces ? "true" : "false")
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
        + ", render_colors.text_foreground = " + std::to_string(render_colors.text_foreground)
        + ", render_colors.link_foreground = " + std::to_string(render_colors.link_foreground)
        + ", render_colors.active_link_foreground = " + std::to_string(render_colors.active_link_foreground)
        + ", render_colors.codelens_foreground = " + std::to_string(render_colors.codelens_foreground)
        + ", render_colors.active_codelens_foreground = " + std::to_string(render_colors.active_codelens_foreground)
        + "}";
  }
}
