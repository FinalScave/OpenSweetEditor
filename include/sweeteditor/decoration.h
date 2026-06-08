//
// Created by Scave on 2025/12/7.
//

#ifndef SWEETEDITOR_DECORATION_H
#define SWEETEDITOR_DECORATION_H

#include <cstdint>
#include <array>
#include <sweeteditor/macro.h>
#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {
  /// Highlight layer enum (priority from low to high, higher layers cover lower layers)
  enum struct SE_PROTOCOL_ENUM(adornment, SYNTAX) SpanLayer : uint8_t {
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

  /// Text style definition (color + background color + font style)
  struct SE_PROTOCOL_VALUE(adornment) TextStyle {
    /// Foreground color value
    int32_t color {0};
    /// Background color value (ARGB), 0 means transparent/no background
    int32_t background_color {0};
    /// Font style (bit flag combination: BOLD | ITALIC | STRIKETHROUGH)
    int32_t font_style {FONT_STYLE_NORMAL};
  };

  /// Text-style registry
  class TextStyleRegistry {
  public:
    /// Register a text style
    /// @param style_id Style ID
    /// @param style Text style info
    void registerTextStyle(uint32_t style_id, TextStyle&& style);

    /// Get text style info by style ID
    /// @param style_id Style ID
    /// @return Matching text style info
    TextStyle& getStyle(uint32_t style_id);
  private:
    HashMap<uint32_t, TextStyle> style_map_;
  };

  /// Highlight span definition
  struct SE_PROTOCOL_VALUE(adornment) StyleSpan {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the span
    uint32_t length {0};
    /// Style ID
    uint32_t style_id {0};
  };

  /// Inlay content type enum
  enum struct SE_PROTOCOL_ENUM(adornment, TEXT) InlayType {
    /// Inlay text
    TEXT = 0,
    /// Inlay icon
    ICON = 1,
    /// Inlay color block
    COLOR = 2,
  };

  /// Inlay content
  struct SE_PROTOCOL_IN(adornment) InlayHint {
    /// Inlay type
    SE_PROTOCOL_WIRE(enum_i32)
    InlayType type {InlayType::TEXT};
    /// Start column in the line
    uint32_t column {0};
    /// Numeric payload for icon ID or color value
    int32_t int_value {0};
    /// Inlay text content
    U8String text;
  };

  /// Ghost text
  struct SE_PROTOCOL_IN(adornment) PhantomText {
    /// Start column in the line
    uint32_t column {0};
    /// Text content
    U8String text;
  };

  /// Gutter icon
  struct SE_PROTOCOL_IN(adornment) GutterIcon {
    /// Icon resource ID (defined and drawn on platform side)
    int32_t icon_id {0};
  };

  /// CodeLens item (clickable label above a code line)
  struct SE_PROTOCOL_IN(adornment) CodeLensItem {
    /// Anchor column within the owning code line
    int32_t column {0};
    /// Unique command ID (platform-defined, transparently passed back on click)
    int32_t command_id {0};
    /// Display text (UTF8), e.g. "3 references"
    U8String text;
  };

  /// Clickable document link range embedded in source text
  struct SE_PROTOCOL_IN(adornment) LinkSpan {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the link range
    uint32_t length {0};
    /// Link target (URL, file URI, or platform-defined document target)
    U8String target;
  };

#pragma region Diagnostic (Diagnostic Decorations)

  /// Diagnostic severity level
  enum struct SE_PROTOCOL_ENUM(adornment, DIAG_ERROR) DiagnosticSeverity : int32_t {
    DIAG_ERROR   = 0,  // Red wavy underline
    DIAG_WARNING = 1,  // Yellow wavy underline
    DIAG_INFO    = 2,  // Blue thin underline
    DIAG_HINT    = 3,  // Gray dashed line
  };

  /// Diagnostic (wavy/underline decoration)
  struct SE_PROTOCOL_IN(adornment) Diagnostic {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the span
    uint32_t length {0};
    /// Severity level
    SE_PROTOCOL_WIRE(enum_i32)
    DiagnosticSeverity severity {DiagnosticSeverity::DIAG_ERROR};
  };

#pragma endregion

#pragma region Document Highlight

  /// Document highlight kind, aligned with language server document highlights
  enum struct SE_PROTOCOL_ENUM(adornment, TEXT) DocumentHighlightKind : int32_t {
    TEXT  = 0,
    READ  = 1,
    WRITE = 2,
  };

  /// Document highlight range for symbol references on a line
  struct SE_PROTOCOL_IN(adornment) DocumentHighlight {
    /// Start column in the line
    uint32_t column {0};
    /// Character length of the span
    uint32_t length {0};
    /// Highlight role
    SE_PROTOCOL_WIRE(enum_i32)
    DocumentHighlightKind kind {DocumentHighlightKind::TEXT};
  };

#pragma endregion

#pragma region Fold (Code Folding)

  /// Foldable region
  struct SE_PROTOCOL_IN(adornment) FoldRegion {
    /// First line of fold region (stays visible, shows fold placeholder)
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t start_line {0};
    /// Last line of fold region (inclusive), start_line+1 to end_line is hidden when folded
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t end_line {0};
    /// Whether it is in folded (collapsed) state
    SE_PROTOCOL_WIRE(bool_u8)
    bool collapsed {false};
  };

#pragma endregion

#pragma region Guide (Code Structure Lines)

  /// Separator line style
  enum struct SE_PROTOCOL_ENUM(adornment, SINGLE) SeparatorStyle : int32_t {
    SINGLE = 0,  // Single bar (---)
    DOUBLE = 1,  // Double bar (===)
  };

  /// Indent vertical line (from { to })
  struct SE_PROTOCOL_IN(adornment) IndentGuide {
    TextPosition start;
    TextPosition end;
  };

  /// Bracket-pair branch line (switch-case / if-else tree links)
  struct SE_PROTOCOL_IN(adornment) BracketGuide {
    TextPosition parent;
    TextPosition end;
    Vector<TextPosition> children;  // Each child {line, column}, draw horizontal line from parent.column to child.column
  };

  /// Control-flow back arrow (draw from loop tail back to loop head)
  struct SE_PROTOCOL_IN(adornment) FlowGuide {
    TextPosition start;  // Loop head (arrow points here)
    TextPosition end;    // Loop tail (arrow starts here)
  };

  /// Horizontal separator line
  struct SE_PROTOCOL_IN(adornment) SeparatorGuide {
    int32_t line;
    SE_PROTOCOL_WIRE(enum_i32)
    SeparatorStyle style;
    int32_t count;                // Symbol count (number of = or -)
    uint32_t text_end_column;     // End column of comment text (separator starts drawing here)
  };

#pragma endregion

  /// Operation interface for all embedded text and styles
  class DecorationManager {
  public:
    DecorationManager();

    SharedPtr<TextStyleRegistry> getTextStyleRegistry();

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

    /// Set CodeLens items for a given line (replace whole line, empty vector removes codelens on this line)
    void setLineCodeLens(size_t line, Vector<CodeLensItem>&& items);

    /// Get CodeLens items for a given line
    const Vector<CodeLensItem>& getLineCodeLens(size_t line) const;

    /// Clear all CodeLens items
    void clearCodeLens();

    /// Set link ranges for a given line (replace whole line, empty vector removes links on this line)
    void setLineLinks(size_t line, Vector<LinkSpan>&& links);

    /// Get link ranges for a given line
    const Vector<LinkSpan>& getLineLinks(size_t line) const;

    /// Clear all link ranges
    void clearLinks();

    /// Find link span covering the specified logical line and column
    const LinkSpan* findLinkAt(size_t line, size_t column) const;

    /// Get highlight spans for a given line and layer (sorted by column ascending)
    const Vector<StyleSpan>& getLineSpans(size_t line, SpanLayer layer) const;

    /// Get inlay hints for a given line (sorted by column ascending)
    const Vector<InlayHint>& getLineInlayHints(size_t line) const;

    /// Get ghost text for a given line (sorted by column ascending)
    const Vector<PhantomText>& getLinePhantomTexts(size_t line) const;

    /// Get gutter icons for a given line
    const Vector<GutterIcon>& getLineGutterIcons(size_t line) const;

    /// Set diagnostic spans for a given line (externally provided, sorted by column ascending)
    void setLineDiagnostics(size_t line, Vector<Diagnostic>&& diagnostics);

    /// Get diagnostic spans for a given line (sorted by column ascending)
    const Vector<Diagnostic>& getLineDiagnostics(size_t line) const;

    /// Clear all diagnostic spans
    void clearDiagnostics();

    /// Set document highlights for a given line
    void setLineDocumentHighlights(size_t line, Vector<DocumentHighlight>&& highlights);

    /// Get document highlights for a given line
    const Vector<DocumentHighlight>& getLineDocumentHighlights(size_t line) const;

    /// Clear all document highlights
    void clearDocumentHighlights();

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
    SharedPtr<TextStyleRegistry> m_text_style_reg_;
    std::array<Vector<Vector<StyleSpan>>, kSpanLayerCount> m_layer_spans_;
    Vector<Vector<InlayHint>> m_inlay_hints_;
    Vector<Vector<PhantomText>> m_phantom_texts_;
    HashMap<size_t, Vector<GutterIcon>> m_gutter_icons_;
    HashMap<size_t, Vector<CodeLensItem>> m_codelens_items_;
    HashMap<size_t, Vector<LinkSpan>> m_links_;
    Vector<Vector<Diagnostic>> m_diagnostics_;
    Vector<Vector<DocumentHighlight>> m_document_highlights_;

    Vector<IndentGuide> m_indent_guides_;
    Vector<BracketGuide> m_bracket_guides_;
    Vector<FlowGuide> m_flow_guides_;
    Vector<SeparatorGuide> m_separator_guides_;
    Vector<FoldRegion> m_fold_regions_;

    static const Vector<StyleSpan> kEmptySpans;
    static const Vector<InlayHint> kEmptyInlayHints;
    static const Vector<PhantomText> kEmptyPhantomTexts;
    static const Vector<GutterIcon> kEmptyGutterIcons;
    static const Vector<Diagnostic> kEmptyDiagnostics;
    static const Vector<DocumentHighlight> kEmptyDocumentHighlights;
    static const Vector<CodeLensItem> kEmptyCodeLensItems;
    static const Vector<LinkSpan> kEmptyLinks;
  };
}

#endif //SWEETEDITOR_DECORATION_H
