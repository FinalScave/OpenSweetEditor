//
// Created by Scave on 2025/12/6.
//

#ifndef SWEETEDITOR_VISUAL_H
#define SWEETEDITOR_VISUAL_H

#include <cstdint>
#include <limits>
#include <sweeteditor/foundation.h>
#include <sweeteditor/editor_types.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {
  inline constexpr size_t kVisualRunOwnerLine = std::numeric_limits<size_t>::max();

  /// Enum for visual render run types
  enum struct SE_PROTOCOL_ENUM(visual, TEXT) VisualRunType {
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
    TAB,
    /// CodeLens clickable label (above code line)
    CODELENS,
    /// Clickable document link embedded in content text
    LINK
  };

  /// Data for each rendered text run
  struct SE_PROTOCOL_OUT(visual) VisualRun {
    /// Run type
    SE_PROTOCOL_WIRE(enum_i32)
    VisualRunType type {VisualRunType::TEXT};
    /// Start column in line
    SE_PROTOCOL_SKIP
    size_t column {0};
    /// Character length in line
    SE_PROTOCOL_SKIP
    size_t length {0};
    /// Source line for projected runs; owner line means VisualLine.logical_line
    SE_PROTOCOL_SKIP
    size_t source_line {kVisualRunOwnerLine};
    /// Start x for drawing
    float x {0};
    /// Start y for drawing
    float y {0};
    /// Run text content (only TEXT, INLAY_HINT(TEXT), and PHANTOM_TEXT use this)
    SE_PROTOCOL_WIRE(u16_as_utf8)
    U16String text;
    /// Text style (color + background color + font style)
    TextStyle style;
    /// Icon resource ID for INLAY_HINT(ICON), or unique command_id for CODELENS
    int32_t icon_id {0};
    /// Color value (ARGB, used by INLAY_HINT(COLOR) only)
    int32_t color_value {0};
    /// Precomputed width (filled during layout, used for viewport clipping and platform drawing)
    float width {0};
    /// Horizontal background padding (InlayHint only; both left and right; width already includes 2*padding)
    float padding {0};
    /// Horizontal margin with previous/next run (InlayHint only; both left and right; width already includes 2*margin)
    float margin {0};
    /// Whether this run is in active state (hovered/pressed), used by clickable runs (CODELENS, future hyperlinks)
    SE_PROTOCOL_WIRE(bool_i32)
    bool active {false};

    U8String dump() const;
  };

  /// Fold arrow display mode
  enum struct SE_PROTOCOL_ENUM(config, AUTO) FoldArrowMode {
    /// Auto: show when fold regions exist, hide otherwise
    AUTO = 0,
    /// Always show (reserve space to avoid width jumping)
    ALWAYS = 1,
    /// Always hide (no reserved space, even when fold regions exist)
    HIDDEN = 2,
  };

  /// Line fold state
  enum struct SE_PROTOCOL_ENUM(visual, NONE) FoldState {
    /// Not the first line of a fold region
    NONE = 0,
    /// Expandable (expanded state, click to fold)
    EXPANDED = 1,
    /// Folded (click to expand)
    COLLAPSED = 2,
  };

  /// Visual line semantic kind
  enum struct SE_PROTOCOL_ENUM(visual, CONTENT) VisualLineKind : uint8_t {
    /// Real content line (primary line or wrapped continuation)
    CONTENT = 0,
    /// Phantom text continuation line
    PHANTOM = 1,
    /// CodeLens virtual line above a code line
    CODELENS = 2,
  };

  /// Pointer cursor hint for desktop platforms
  enum struct SE_PROTOCOL_ENUM(visual, DEFAULT) PointerCursorType : uint8_t {
    DEFAULT = 0,
    TEXT = 1,
    HAND = 2,
  };

  /// Visual rendered line data
  struct SE_PROTOCOL_OUT(visual) VisualLine {
    /// Logical line index
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t logical_line {0};
    /// Wrapped line index in auto-wrap mode (0 = first line, 1,2,... = continuation)
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t wrap_index {0};
    /// Line number position
    PointF line_number_position;
    /// Text runs in this visual line
    Vector<VisualRun> runs;
    /// Semantic kind of this visual line
    SE_PROTOCOL_WIRE(enum_i32)
    VisualLineKind kind {VisualLineKind::CONTENT};
    /// Whether this visual line owns gutter semantics (line number, gutter icon, fold marker)
    bool owns_gutter_semantics {false};
    /// Fold state (NONE=not fold line, EXPANDED=expandable, COLLAPSED=folded)
    SE_PROTOCOL_WIRE(enum_i32)
    FoldState fold_state {FoldState::NONE};

    U8String dump() const;
  };

  /// Cursor data
  struct SE_PROTOCOL_OUT(visual) Cursor {
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

  /// Selection handle (drag handle), used by platform to draw the droplet-style control
  struct SE_PROTOCOL_OUT(visual) SelectionHandle {
    /// Handle position (bottom-center of cursor vertical line; platform draws handle using this anchor)
    PointF position;
    /// Handle height (same as line height, used for drawing vertical line part)
    float height {0};
    /// Whether handle is visible
    bool visible {false};
  };

  /// Guide direction
  enum struct SE_PROTOCOL_ENUM(visual, VERTICAL) GuideDirection {
    HORIZONTAL,
    VERTICAL,
  };

  /// Guide semantic type
  enum struct SE_PROTOCOL_ENUM(visual, INDENT) GuideType {
    INDENT,      // Indent vertical line
    BRACKET,     // Bracket pair branch line (joined by "|-" shape)
    FLOW,        // Control-flow return segment
    SEPARATOR,   // Custom separator line
  };

  /// Guide style
  enum struct SE_PROTOCOL_ENUM(visual, SOLID) GuideStyle {
    SOLID,       // Solid line
    DASHED,      // Dashed line
    DOUBLE,      // Double line (SEPARATOR only)
  };

  /// Render primitive for code structure guides
  struct SE_PROTOCOL_OUT(visual) GuideSegment {
    SE_PROTOCOL_WIRE(enum_i32)
    GuideDirection direction {GuideDirection::VERTICAL};
    SE_PROTOCOL_WIRE(enum_i32)
    GuideType type {GuideType::INDENT};
    SE_PROTOCOL_WIRE(enum_i32)
    GuideStyle style {GuideStyle::SOLID};
    PointF start;
    PointF end;
    SE_PROTOCOL_WIRE(bool_i32)
    bool arrow_end {false};
  };

  /// Gutter icon render item (fully resolved geometry for one icon)
  struct SE_PROTOCOL_OUT(visual) GutterIconRenderItem {
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t logical_line {0};
    int32_t icon_id {0};
    Rect rect;
  };

  /// Fold marker render item (one gutter fold toggle marker)
  struct SE_PROTOCOL_OUT(visual) FoldMarkerRenderItem {
    SE_PROTOCOL_WIRE(size_as_i32)
    size_t logical_line {0};
    SE_PROTOCOL_WIRE(enum_i32)
    FoldState fold_state {FoldState::NONE};
    Rect rect;
  };

  /// Semantic range effect kind.
  enum struct SE_PROTOCOL_ENUM(visual, SELECTION) RangeEffectKind {
    SELECTION = 0,
    SEARCH_MATCH = 1,
    SEARCH_CURRENT = 2,
    DOCUMENT_HIGHLIGHT_TEXT = 3,
    DOCUMENT_HIGHLIGHT_READ = 4,
    DOCUMENT_HIGHLIGHT_WRITE = 5,
    LINKED_EDITING_ACTIVE = 6,
    LINKED_EDITING_INACTIVE = 7,
    IME_COMPOSITION = 8,
    BRACKET_MATCH = 9,
    DIAGNOSTIC_ERROR = 10,
    DIAGNOSTIC_WARNING = 11,
    DIAGNOSTIC_INFO = 12,
    DIAGNOSTIC_HINT = 13,
  };

  /// Fully resolved range effect item for platform renderers.
  struct SE_PROTOCOL_OUT(visual) RangeEffectRenderItem {
    Rect rect;
    SE_PROTOCOL_WIRE(enum_i32)
    RangeEffectKind kind {RangeEffectKind::SELECTION};
    RangeEffectStyle style;
  };

  /// Scrollbar render model (one axis)
  struct SE_PROTOCOL_OUT(visual) ScrollbarModel {
    /// Whether scrollbar is visible for this axis
    SE_PROTOCOL_WIRE(bool_i32)
    bool visible {false};
    /// Scrollbar alpha in [0, 1]
    float alpha {0};
    /// Whether the thumb is currently being dragged
    SE_PROTOCOL_WIRE(bool_i32)
    bool thumb_active {false};
    /// Scrollbar track rectangle
    Rect track;
    /// Scrollbar thumb rectangle
    Rect thumb;
  };

  /// Editor render model
  struct SE_PROTOCOL_OUT(visual) EditorRenderModel {
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
    SE_PROTOCOL_WIRE(enum_i32)
    CurrentLineRenderMode current_line_render_mode {CurrentLineRenderMode::BACKGROUND};
    /// Text lines to render visually (visible region only)
    Vector<VisualLine> lines;
    /// Cursor
    Cursor cursor;
    /// Range effects to render over visible text
    Vector<RangeEffectRenderItem> range_effects;
    /// Selection start handle (anchor side)
    SelectionHandle selection_start_handle;
    /// Selection end handle (active side / cursor side)
    SelectionHandle selection_end_handle;
    /// Code structure guide lines
    Vector<GuideSegment> guide_segments;
    /// Maximum gutter icon count (0=overlay mode, icon overlays line number; >0=exclusive mode with reserved fixed space)
    uint32_t max_gutter_icons {0};
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
    /// Pointer cursor hint for the current mouse location
    SE_PROTOCOL_WIRE(enum_i32)
    PointerCursorType pointer_cursor_type {PointerCursorType::TEXT};

    U8String dump() const;
    U8String toJson() const;
  };

  /// Editor layout metrics
  struct SE_PROTOCOL_OUT(visual) LayoutMetrics {
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
    SE_PROTOCOL_WIRE(enum_i32)
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

}

#endif //SWEETEDITOR_VISUAL_H
