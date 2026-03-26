//
// Created by Scave on 2025/12/6.
//

#ifndef SWEETEDITOR_VISUAL_H
#define SWEETEDITOR_VISUAL_H

#include <cstdint>
#include <nlohmann/json.hpp>
#include <foundation.h>
#include <decoration.h>
#include <utility.h>

namespace NS_SWEETEDITOR {
  /// Enum for visual render run types
  enum struct VisualRunType {
    /// Normal text
    TEXT,
    /// Whitespace
    WHITESPACE,
    /// Newline
    NEWLINE,
    /// Inlay content (text or icon)
    INLAY_HINT,
    /// Ghost text (for Copilot-style code suggestions)
    PHANTOM_TEXT,
    /// Fold placeholder ("..." shown at end of folded region first line)
    FOLD_PLACEHOLDER,
    /// Tab character (width computed by core based on tab_size and column position)
    TAB
  };

  /// Data for each rendered text run
  struct VisualRun {
    /// Run type
    VisualRunType type {VisualRunType::TEXT};
    /// Start column in line
    size_t column {0};
    /// Character length in line
    size_t length {0};
    /// Start x for drawing
    float x {0};
    /// Start y for drawing
    float y {0};
    /// Run text content (only TEXT, INLAY_HINT(TEXT), and PHANTOM_TEXT use this)
    U16String text;
    /// Text style (color + background color + font style)
    TextStyle style;
    /// Icon resource ID (used by INLAY_HINT(ICON) only)
    int32_t icon_id {0};
    /// Color value (ARGB, used by INLAY_HINT(COLOR) only)
    int32_t color_value {0};
    /// Precomputed width (filled during layout, used for viewport clipping and platform drawing)
    float width {0};
    /// Horizontal background padding (InlayHint only; both left and right; width already includes 2*padding)
    float padding {0};
    /// Horizontal margin with previous/next run (InlayHint only; both left and right; width already includes 2*margin)
    float margin {0};

    U8String dump() const;
  };

  /// Fold arrow display mode
  enum struct FoldArrowMode {
    /// Auto: show when fold regions exist, hide otherwise
    AUTO = 0,
    /// Always show (reserve space to avoid width jumping)
    ALWAYS = 1,
    /// Always hide (no reserved space, even when fold regions exist)
    HIDDEN = 2,
  };

  /// Line fold state
  enum struct FoldState {
    /// Not the first line of a fold region
    NONE = 0,
    /// Expandable (expanded state, click to fold)
    EXPANDED = 1,
    /// Folded (click to expand)
    COLLAPSED = 2,
  };

  /// Visual rendered line data
  struct VisualLine {
    /// Logical line index
    size_t logical_line {0};
    /// Wrapped line index in auto-wrap mode (0 = first line, 1,2,... = continuation)
    size_t wrap_index {0};
    /// Line number position
    PointF line_number_position;
    /// Text runs in this visual line
    Vector<VisualRun> runs;
    /// Whether this is a ghost-text continuation line (2nd/3rd... line of cross-line phantom text)
    bool is_phantom_line {false};
    /// Fold state (NONE=not fold line, EXPANDED=expandable, COLLAPSED=folded)
    FoldState fold_state {FoldState::NONE};

    U8String dump() const;
  };

  /// Cursor data
  struct Cursor {
    /// Cursor logical position in text
    TextPosition text_position;
    /// Cursor screen position
    PointF position;
    /// Cursor height
    float height {0};
    /// Whether cursor is visible
    bool visible {true};
    /// Whether drag handle is visible
    bool show_dragger {false};

    U8String dump() const;
  };

  /// Single-line highlight rectangle for selection area
  struct SelectionRect {
    /// Top-left corner of rectangle
    PointF origin;
    /// Rectangle width
    float width {0};
    /// Rectangle height
    float height {0};
  };

  /// Selection handle (drag handle), used by platform to draw the droplet-style control
  struct SelectionHandle {
    /// Handle position (bottom-center of cursor vertical line; platform draws handle using this anchor)
    PointF position;
    /// Handle height (same as line height, used for drawing vertical line part)
    float height {0};
    /// Whether handle is visible
    bool visible {false};
  };

  /// Guide direction
  enum struct GuideDirection {
    HORIZONTAL,
    VERTICAL,
  };

  /// Guide semantic type
  enum struct GuideType {
    INDENT,      // Indent vertical line
    BRACKET,     // Bracket pair branch line (joined by "|-" shape)
    FLOW,        // Control-flow return segment
    SEPARATOR,   // Custom separator line
  };

  /// Guide style
  enum struct GuideStyle {
    SOLID,       // Solid line
    DASHED,      // Dashed line
    DOUBLE,      // Double line (SEPARATOR only)
  };

  /// Render primitive for code structure guides
  struct GuideSegment {
    GuideDirection direction {GuideDirection::VERTICAL};
    GuideType type {GuideType::INDENT};
    GuideStyle style {GuideStyle::SOLID};
    PointF start;
    PointF end;
    bool arrow_end {false};
  };

  /// Render decoration for composition input area (underline)
  struct CompositionDecoration {
    /// Whether composition decoration needs to be drawn
    bool active {false};
    /// Start screen coordinate of composition text area
    PointF origin;
    /// Width of composition text area
    float width {0};
    /// Line height
    float height {0};
  };

  /// Render primitive for diagnostic decoration (wavy underline / underline)
  struct DiagnosticDecoration {
    /// Start screen coordinate of wavy underline area (below baseline)
    PointF origin;
    /// Wavy underline width
    float width {0};
    /// Line height (used to locate baseline offset)
    float height {0};
    /// Severity level (0=ERROR, 1=WARNING, 2=INFO, 3=HINT)
    int32_t severity {0};
    /// Color value (ARGB); 0 means use default color by severity
    int32_t color {0};
  };

  /// Bracket-pair highlight rectangle (bracket near cursor + matching bracket)
  struct BracketHighlightRect {
    /// Top-left corner of rectangle
    PointF origin;
    /// Rectangle width
    float width {0};
    /// Rectangle height
    float height {0};
  };

  /// Gutter icon render item (fully resolved geometry for one icon)
  struct GutterIconRenderItem {
    /// Logical line index this icon belongs to
    size_t logical_line {0};
    /// Icon resource ID
    int32_t icon_id {0};
    /// Top-left corner of icon bounds
    PointF origin;
    /// Icon width
    float width {0};
    /// Icon height
    float height {0};
  };

  /// Fold marker render item (one gutter fold toggle marker)
  struct FoldMarkerRenderItem {
    /// Logical line index this marker belongs to
    size_t logical_line {0};
    /// Fold state on this line (EXPANDED / COLLAPSED)
    FoldState fold_state {FoldState::NONE};
    /// Top-left corner of marker bounds
    PointF origin;
    /// Marker width
    float width {0};
    /// Marker height
    float height {0};
  };

  /// Linked-editing highlight rectangle (visual marker for Tab Stop placeholder)
  struct LinkedEditingRect {
    /// Top-left corner of rectangle
    PointF origin;
    /// Rectangle width
    float width {0};
    /// Rectangle height
    float height {0};
    /// Whether this is the current active tab stop
    bool is_active {false};
  };

  /// Scrollbar rectangle (track/thumb geometry in screen coordinates)
  struct ScrollbarRect {
    /// Top-left corner of rectangle
    PointF origin;
    /// Rectangle width
    float width {0};
    /// Rectangle height
    float height {0};
  };

  /// Scrollbar render model (one axis)
  struct ScrollbarModel {
    /// Whether scrollbar is visible for this axis
    bool visible {false};
    /// Scrollbar alpha in [0, 1]
    float alpha {0};
    /// Whether the thumb is currently being dragged
    bool thumb_active {false};
    /// Scrollbar track rectangle
    ScrollbarRect track;
    /// Scrollbar thumb rectangle
    ScrollbarRect thumb;
  };

  /// Current line render mode
  enum struct CurrentLineRenderMode {
    /// Fill full line background
    BACKGROUND = 0,
    /// Draw line border only
    BORDER = 1,
    /// Disable current-line decoration
    NONE = 2,
  };

  /// Editor render model
  struct EditorRenderModel {
    /// Line-number split x position
    float split_x {0};
    /// Whether split line should be rendered
    bool split_line_visible {true};
    /// Current horizontal scroll offset
    float scroll_x {0};
    /// Current vertical scroll offset
    float scroll_y {0};
    /// Viewport width
    float viewport_width {0};
    /// Viewport height
    float viewport_height {0};
    /// Current line background coordinate
    PointF current_line;
    /// Current line render mode
    CurrentLineRenderMode current_line_render_mode {CurrentLineRenderMode::BACKGROUND};
    /// Text lines to render visually (visible region only)
    Vector<VisualLine> lines;
    /// Cursor
    Cursor cursor;
    /// Selection highlight rectangle list
    Vector<SelectionRect> selection_rects;
    /// Selection start handle (anchor side)
    SelectionHandle selection_start_handle;
    /// Selection end handle (active side / cursor side)
    SelectionHandle selection_end_handle;
    /// Composition decoration (underline area during IME input)
    CompositionDecoration composition_decoration;
    /// Code structure guide lines
    Vector<GuideSegment> guide_segments;
    /// Diagnostic decorations (wavy underline / underline)
    Vector<DiagnosticDecoration> diagnostic_decorations;
    /// Maximum gutter icon count (0=overlay mode, icon overlays line number; >0=exclusive mode with reserved fixed space)
    uint32_t max_gutter_icons {0};
    /// Linked-editing highlight rectangle list (Tab Stop placeholders)
    Vector<LinkedEditingRect> linked_editing_rects;
    /// Bracket-pair highlight rectangle list (bracket near cursor + matching bracket, usually 0 or 2)
    Vector<BracketHighlightRect> bracket_highlight_rects;
    /// Gutter icon render list (fully resolved, visible region only)
    Vector<GutterIconRenderItem> gutter_icons;
    /// Fold marker render list (fully resolved, visible region only)
    Vector<FoldMarkerRenderItem> fold_markers;
    /// Vertical scrollbar render model
    ScrollbarModel vertical_scrollbar;
    /// Horizontal scrollbar render model
    ScrollbarModel horizontal_scrollbar;
    /// Whether gutter stays fixed during horizontal scroll
    bool gutter_sticky {true};
    /// Whether gutter area is visible
    bool gutter_visible {true};

    U8String dump() const;
    U8String toJson() const;
  };

  /// Editor layout metrics
  struct LayoutMetrics {
    /// Font height
    float font_height {20};
    /// Absolute font ascent (distance from baseline to line top, positive)
    float font_ascent {0};
    /// Line spacing (add)
    float line_spacing_add {0};
    /// Line spacing (mult)
    float line_spacing_mult {1.2f};
    /// Line number margin
    float line_number_margin {10};
    /// Line number width
    float line_number_width {10};
    /// Extra horizontal padding between gutter split and text rendering start
    float content_start_padding {0};
    /// Maximum gutter icon count (icon width = line height, reserve fixed space; 0 = no reserve)
    uint32_t max_gutter_icons {0};
    /// Horizontal background padding for InlayHint (left and right)
    float inlay_hint_padding {0};
    /// Horizontal margin between InlayHint and neighboring runs (left and right)
    float inlay_hint_margin {0};
    /// Fold arrow display mode (AUTO=show when fold regions exist, ALWAYS=always reserve, HIDDEN=always hide)
    FoldArrowMode fold_arrow_mode {FoldArrowMode::AUTO};
    /// Whether fold regions exist (auto-updated by EditorCore in setFoldRegions, used in AUTO mode)
    bool has_fold_regions {false};
    /// Whether gutter stays fixed during horizontal scroll
    bool gutter_sticky {true};
    /// Whether gutter area is visible (false = hide line numbers, icons, fold arrows)
    bool gutter_visible {true};

    /// Compute fold-arrow area width
    float foldArrowAreaWidth() const {
      switch (fold_arrow_mode) {
        case FoldArrowMode::AUTO:    return has_fold_regions ? font_height : 0;
        case FoldArrowMode::ALWAYS:  return font_height;
        case FoldArrowMode::HIDDEN:  return 0;
      }
      return 0;
    }

    /// Whether fold arrows should be shown now (used by layout and hit testing)
    bool shouldShowFoldArrows() const {
      switch (fold_arrow_mode) {
        case FoldArrowMode::AUTO:    return has_fold_regions;
        case FoldArrowMode::ALWAYS:  return true;
        case FoldArrowMode::HIDDEN:  return false;
      }
      return false;
    }

    /// Compute total gutter width (line-number area + icon area + fold-arrow area + margins)
    /// = line_number_margin + line_number_width + icon_area + fold_arrow_area + line_number_margin
    float gutterWidth() const {
      if (!gutter_visible) return 0;
      float icon_area = (max_gutter_icons > 0) ? (font_height * max_gutter_icons) : 0;
      return line_number_margin + line_number_width + icon_area + foldArrowAreaWidth() + line_number_margin;
    }

    /// Compute content text area x (gutter split + extra content start padding)
    float textAreaX() const {
      return gutterWidth() + content_start_padding;
    }

    U8String toJson() const;
  };

  U8String dumpEnum(VisualRunType type);
  U8String dumpEnum(GuideDirection direction);
  U8String dumpEnum(GuideType type);
  U8String dumpEnum(GuideStyle style);

  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(PointF, x, y)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextPosition, line, column)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextRange, start, end)
  NLOHMANN_JSON_SERIALIZE_ENUM(VisualRunType, {
    {VisualRunType::TEXT, "TEXT"},
    {VisualRunType::WHITESPACE, "WHITESPACE"},
    {VisualRunType::NEWLINE, "NEWLINE"},
    {VisualRunType::INLAY_HINT, "INLAY_HINT"},
    {VisualRunType::PHANTOM_TEXT, "PHANTOM_TEXT"},
    {VisualRunType::FOLD_PLACEHOLDER, "FOLD_PLACEHOLDER"},
    {VisualRunType::TAB, "TAB"},
  })
  // Custom VisualRun serialization: text (U16String) must be converted to UTF-8 JSON string
  inline void to_json(nlohmann::json& j, const VisualRun& r) {
    U8String u8_text;
    if (!r.text.empty()) {
      StrUtil::convertUTF16ToUTF8(r.text, u8_text);
    }
    nlohmann::json style_j = {{"font_style", r.style.font_style}, {"color", r.style.color}, {"background_color", r.style.background_color}};
    j = nlohmann::json{{"type", r.type}, {"x", r.x}, {"y", r.y}, {"text", u8_text}, {"style", style_j}, {"icon_id", r.icon_id}, {"color_value", r.color_value}, {"width", r.width}, {"padding", r.padding}, {"margin", r.margin}};
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
  }
  NLOHMANN_JSON_SERIALIZE_ENUM(FoldState, {
    {FoldState::NONE, "NONE"},
    {FoldState::EXPANDED, "EXPANDED"},
    {FoldState::COLLAPSED, "COLLAPSED"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(VisualLine, logical_line, wrap_index, line_number_position, runs, is_phantom_line, fold_state)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(Cursor, text_position, position, height, visible, show_dragger)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(SelectionRect, origin, width, height)
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
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(CompositionDecoration, active, origin, width, height)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(DiagnosticDecoration, origin, width, height, severity, color)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GuideSegment, direction, type, style, start, end, arrow_end)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(LinkedEditingRect, origin, width, height, is_active)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(BracketHighlightRect, origin, width, height)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(GutterIconRenderItem, logical_line, icon_id, origin, width, height)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(FoldMarkerRenderItem, logical_line, fold_state, origin, width, height)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(ScrollbarRect, origin, width, height)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(ScrollbarModel, visible, alpha, thumb_active, track, thumb)
  NLOHMANN_JSON_SERIALIZE_ENUM(CurrentLineRenderMode, {
    {CurrentLineRenderMode::BACKGROUND, "BACKGROUND"},
    {CurrentLineRenderMode::BORDER, "BORDER"},
    {CurrentLineRenderMode::NONE, "NONE"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(EditorRenderModel, split_x, split_line_visible, scroll_x, scroll_y, viewport_width, viewport_height, current_line, current_line_render_mode, lines, cursor, selection_rects, selection_start_handle, selection_end_handle, composition_decoration, guide_segments, diagnostic_decorations, max_gutter_icons, linked_editing_rects, bracket_highlight_rects, gutter_icons, fold_markers, vertical_scrollbar, horizontal_scrollbar, gutter_sticky, gutter_visible)
  NLOHMANN_JSON_SERIALIZE_ENUM(FoldArrowMode, {
    {FoldArrowMode::AUTO, "AUTO"},
    {FoldArrowMode::ALWAYS, "ALWAYS"},
    {FoldArrowMode::HIDDEN, "HIDDEN"},
  })
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(LayoutMetrics, font_height, font_ascent, line_spacing_add, line_spacing_mult, line_number_margin, line_number_width, content_start_padding, max_gutter_icons, inlay_hint_padding, inlay_hint_margin, fold_arrow_mode, has_fold_regions, gutter_sticky, gutter_visible)
}

#endif //SWEETEDITOR_VISUAL_H
