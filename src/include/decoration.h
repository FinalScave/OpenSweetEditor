//
// Created by Scave on 2025/12/7.
//

#ifndef SWEETEDITOR_DECORATION_H
#define SWEETEDITOR_DECORATION_H

#include <cstdint>
#include <array>
#include <macro.h>
#include <foundation.h>

namespace NS_SWEETEDITOR {
  /// Highlight layer enum (priority from low to high, higher layers cover lower layers)
  enum struct SpanLayer : uint8_t {
    SYNTAX   = 0,  // Syntax highlight (base layer, full coverage)
    SEMANTIC = 1,  // Semantic highlight (LSP semantic tokens, covers syntax layer)
  };
  /// Total number of highlight layers
  constexpr size_t kSpanLayerCount = 2;

  /// Font style bit flags, combine multiple styles with bit operations
  /// Platform side unpacks with (font_style & FONT_STYLE_BOLD) != 0
  enum FontStyle : int32_t {
    FONT_STYLE_NORMAL        = 0,
    FONT_STYLE_BOLD          = 1 << 0,  // 0x01
    FONT_STYLE_ITALIC        = 1 << 1,  // 0x02
    FONT_STYLE_STRIKETHROUGH = 1 << 2,  // 0x04
  };

  /// Pack font style bit flags
  inline int32_t packFontStyle(bool bold, bool italic, bool strikethrough) {
    int32_t style = FONT_STYLE_NORMAL;
    if (bold)          style |= FONT_STYLE_BOLD;
    if (italic)        style |= FONT_STYLE_ITALIC;
    if (strikethrough) style |= FONT_STYLE_STRIKETHROUGH;
    return style;
  }

  /// Inline style (color + background color + font style, used in render pipeline)
  struct InlineStyle {
    /// Foreground color value (ARGB), 0 means use default color
    int32_t color {0};
    /// Background color value (ARGB), 0 means transparent/no background
    int32_t background_color {0};
    /// Font style (bit flag combination: BOLD | ITALIC | STRIKETHROUGH)
    int32_t font_style {FONT_STYLE_NORMAL};
  };

  /// Editor style definition (with style_id, for style registry)
  struct Style {
    /// Style ID
    uint32_t style_id {0};
    /// Foreground color value
    int32_t color {0};
    /// Background color value (ARGB), 0 means transparent/no background
    int32_t background_color {0};
    /// Font style (bit flag combination: BOLD | ITALIC | STRIKETHROUGH)
    int32_t font_style {FONT_STYLE_NORMAL};

    /// Convert to lightweight inline style
    InlineStyle toInlineStyle() const { return {color, background_color, font_style}; }
  };

  /// Editor style registry
  class StyleRegistry {
  public:
    /// Register a highlight style
    /// @param style Highlight style info
    void registerStyle(Style&& style);

    /// Get style info by style ID
    /// @param style_id Style ID
    /// @return Matching style info
    Style& getStyle(uint32_t style_id);
  private:
    HashMap<uint32_t, Style> style_map_;
  };

  /// Highlight span definition
  struct StyleSpan {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the span
    uint32_t length {0};
    /// Style ID
    uint32_t style_id {0};
  };

  /// Inlay content type enum
  enum struct InlayType {
    /// Inlay text
    TEXT = 0,
    /// Inlay icon
    ICON = 1,
    /// Inlay color block
    COLOR = 2,
  };

  /// Inlay content
  struct InlayHint {
    /// Inlay type
    InlayType type {InlayType::TEXT};
    /// Start column in the line
    uint32_t column {0};
    /// Inlay text content
    U8String text;
    /// Inlay icon ID
    int32_t icon_id {0};
    /// Inlay color value (ARGB, only used for COLOR type)
    int32_t color {0};
  };

  /// Ghost text
  struct PhantomText {
    /// Start column in the line
    uint32_t column {0};
    /// Text content
    U8String text;
  };

  /// Gutter icon
  struct GutterIcon {
    /// Icon resource ID (defined and drawn on platform side)
    int32_t icon_id {0};
  };

#pragma region Diagnostic (Diagnostic Decorations)

  /// Diagnostic severity level
  enum struct DiagnosticSeverity : int32_t {
    DIAG_ERROR   = 0,  // Red wavy underline
    DIAG_WARNING = 1,  // Yellow wavy underline
    DIAG_INFO    = 2,  // Blue thin underline
    DIAG_HINT    = 3,  // Gray dashed line
  };

  /// Diagnostic span (wavy/underline decoration)
  struct DiagnosticSpan {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the span
    uint32_t length {0};
    /// Severity level
    DiagnosticSeverity severity {DiagnosticSeverity::DIAG_ERROR};
    /// Custom color (ARGB), 0 means use severity default color
    int32_t color {0};
  };

#pragma endregion

#pragma region Fold (Code Folding)

  /// Foldable region
  struct FoldRegion {
    /// First line of fold region (stays visible, shows fold placeholder)
    size_t start_line {0};
    /// Last line of fold region (inclusive), start_line+1 to end_line is hidden when folded
    size_t end_line {0};
    /// Whether it is in folded (collapsed) state
    bool collapsed {false};
  };

#pragma endregion

#pragma region Guide (Code Structure Lines)

  /// Separator line style
  enum struct SeparatorStyle : int32_t {
    SINGLE = 0,  // Single bar (---)
    DOUBLE = 1,  // Double bar (===)
  };

  /// Indent vertical line (from { to })
  struct IndentGuide {
    TextPosition start;
    TextPosition end;
  };

  /// Bracket-pair branch line (switch-case / if-else tree links)
  struct BracketGuide {
    TextPosition parent;
    TextPosition end;
    Vector<TextPosition> children;  // Each child {line, column}, draw horizontal line from parent.column to child.column
  };

  /// Control-flow back arrow (draw from loop tail back to loop head)
  struct FlowGuide {
    TextPosition start;  // Loop head (arrow points here)
    TextPosition end;    // Loop tail (arrow starts here)
  };

  /// Horizontal separator line
  struct SeparatorGuide {
    int32_t line;
    SeparatorStyle style;
    int32_t count;                // Symbol count (number of = or -)
    uint32_t text_end_column;     // End column of comment text (separator starts drawing here)
  };

#pragma endregion

  /// Operation interface for all embedded text and styles
  class DecorationManager {
  public:
    DecorationManager();

    Ptr<StyleRegistry> getStyleRegistry();

    /// Set highlight spans for a given line and layer (externally provided, sorted by column ascending)
    void setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans);

    /// Get merged highlight spans for a given line (higher layers cover lower, sorted by column ascending)
    Vector<StyleSpan> getMergedLineSpans(size_t line) const;

    /// Set inlay hints for a given line (replace whole line, externally provided, sorted by column ascending)
    void setLineInlayHints(size_t line, Vector<InlayHint>&& hints);

    /// Set ghost text for a given line (replace whole line, externally provided, sorted by column ascending)
    void setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms);

    /// Set gutter icons for a given line (replace whole line, empty vector removes icons on this line)
    void setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons);

    /// Get highlight spans for a given line and layer (sorted by column ascending)
    const Vector<StyleSpan>& getLineSpans(size_t line, SpanLayer layer) const;

    /// Get inlay hints for a given line (sorted by column ascending)
    const Vector<InlayHint>& getLineInlayHints(size_t line) const;

    /// Get ghost text for a given line (sorted by column ascending)
    const Vector<PhantomText>& getLinePhantomTexts(size_t line) const;

    /// Get gutter icons for a given line
    const Vector<GutterIcon>& getLineGutterIcons(size_t line) const;

    /// Set diagnostic spans for a given line (externally provided, sorted by column ascending)
    void setLineDiagnostics(size_t line, Vector<DiagnosticSpan>&& diagnostics);

    /// Get diagnostic spans for a given line (sorted by column ascending)
    const Vector<DiagnosticSpan>& getLineDiagnostics(size_t line) const;

    /// Clear all diagnostic spans
    void clearDiagnostics();

    /// Clear all decoration data for a given line
    void clearLine(size_t line);

    /// Clear all highlight spans in a given layer
    void clearHighlights(SpanLayer layer);

    /// Clear all highlight spans in all layers
    void clearHighlights();

    /// Clear all inlay hints
    void clearInlayHints();

    /// Clear all ghost text
    void clearPhantomTexts();

    /// Clear all gutter icons
    void clearGutterIcons();

    /// Clear all decoration data
    void clearAll();

#pragma region Guide (Code Structure Lines)

    void setIndentGuides(Vector<IndentGuide>&& guides);
    void setBracketGuides(Vector<BracketGuide>&& guides);
    void setFlowGuides(Vector<FlowGuide>&& guides);
    void setSeparatorGuides(Vector<SeparatorGuide>&& guides);

    void clearGuides();

    const Vector<IndentGuide>& getIndentGuides() const { return m_indent_guides_; }
    const Vector<BracketGuide>& getBracketGuides() const { return m_bracket_guides_; }
    const Vector<FlowGuide>& getFlowGuides() const { return m_flow_guides_; }
    const Vector<SeparatorGuide>& getSeparatorGuides() const { return m_separator_guides_; }

#pragma endregion

#pragma region Fold (Code Folding)

    /// Set foldable region list (replace current list, sorted by start_line ascending)
    void setFoldRegions(Vector<FoldRegion>&& regions);

    /// Fold the region that contains the given line
    /// @return true if region is found and folded
    bool foldAt(size_t line);

    /// Unfold the region that contains the given line
    /// @return true if region is found and unfolded
    bool unfoldAt(size_t line);

    /// Toggle fold state of the region that contains the given line
    /// @return true if region is found
    bool toggleFoldAt(size_t line);

    /// Fold all regions
    void foldAll();

    /// Unfold all regions
    void unfoldAll();

    /// Check whether a line is hidden by folding (inside start_line+1 ~ end_line of a folded region)
    bool isLineHidden(size_t line) const;

    /// Query fold state for a line (0=NONE, 1=EXPANDED, 2=COLLAPSED)
    /// Only start_line of a fold region returns a non-zero value
    int getFoldStateForLine(size_t line) const;

    /// Get fold region containing the given line (if the line is inside a fold region)
    /// @return Pointer to the region, nullptr if not found
    const FoldRegion* getFoldRegionForLine(size_t line) const;

    /// Get all fold regions
    const Vector<FoldRegion>& getFoldRegions() const { return m_fold_regions_; }

    /// Get all fold regions (modifiable, for internal sync)
    Vector<FoldRegion>& getFoldRegionsMut() { return m_fold_regions_; }

    /// Clear all fold regions
    void clearFoldRegions();

#pragma endregion

    /// Adjust row/column offsets of all decorations after text edits
    /// @param old_range Text range before edit (deleted/replaced range)
    /// @param new_end New end position of that range after edit
    void adjustForEdit(const TextRange& old_range, const TextPosition& new_end);
  private:
    void ensureLineCapacity_(size_t line_count);
    Ptr<StyleRegistry> m_style_reg_;
    std::array<Vector<Vector<StyleSpan>>, kSpanLayerCount> m_layer_spans_;
    Vector<Vector<InlayHint>> m_inlay_hints_;
    Vector<Vector<PhantomText>> m_phantom_texts_;
    HashMap<size_t, Vector<GutterIcon>> m_gutter_icons_;
    Vector<Vector<DiagnosticSpan>> m_diagnostics_;

    Vector<IndentGuide> m_indent_guides_;
    Vector<BracketGuide> m_bracket_guides_;
    Vector<FlowGuide> m_flow_guides_;
    Vector<SeparatorGuide> m_separator_guides_;
    Vector<FoldRegion> m_fold_regions_;

    static const Vector<StyleSpan> kEmptySpans;
    static const Vector<InlayHint> kEmptyInlayHints;
    static const Vector<PhantomText> kEmptyPhantomTexts;
    static const Vector<GutterIcon> kEmptyGutterIcons;
    static const Vector<DiagnosticSpan> kEmptyDiagnostics;
  };
}

#endif //SWEETEDITOR_DECORATION_H
