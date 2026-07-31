//
// Created by Scave on 2025/12/7.
//

#ifndef SWEETEDITOR_LAYOUT_H
#define SWEETEDITOR_LAYOUT_H

#include <sweeteditor/document.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/visual.h>
#include <sweeteditor/gesture.h>
#include <functional>
#include <optional>

namespace NS_SWEETEDITOR {

  /// Font metric info
  struct FontMetrics {
    float ascent;
    float descent;
  };

  /// Visible line region info
  struct VisibleLineInfo {
    /// Index of first visible line
    size_t first_line{0};
    /// Index of last visible line
    size_t last_line{0};
    /// Y position of the first visible line (negative when only partially visible)
    float first_line_y{0};
  };

  /// Scroll bounds and content size info (used by platform scrollbar calculations)
  struct ScrollBounds {
    /// Text area start x (usually equal to gutter width)
    float text_area_x{0};
    /// Text area width (viewport - gutter)
    float text_area_width{0};
    /// Total content width (no-wrap = longest visual line; wrap = text area width)
    float content_width{0};
    /// Total content height
    float content_height{0};
    /// Maximum horizontal scroll
    float max_scroll_x{0};
    /// Maximum vertical scroll
    float max_scroll_y{0};
  };

  struct TextRunStyleOverride {
    TextRange range;
    int32_t foreground_color{0};
    bool clear_text_background{false};
    uint32_t priority{0};
  };

  /// Input used to finalize layout runs for the render model.
  /// It does not affect geometry or layout caches.
  struct VisualRunInput {
    /// Active interactive hit target for clickable runs such as CodeLens or Link.
    HitTarget active_hit_target;
    /// Current logical text selection range
    std::optional<TextRange> selection_range;
    /// Render-time editor colors applied to visual runs
    EditorRenderColors colors;
    /// Whitespace marker rendering mode for the emitted render model
    WhitespaceRenderMode whitespace_mode{WhitespaceRenderMode::NONE};
    /// Concrete text style overrides grouped by logical source line
    HashMap<size_t, Vector<TextRunStyleOverride>> style_overrides_by_line;
  };

  enum class PointerHitPolicy : uint8_t {
    CONTENT = 0,
    OWNER_LINE_START = 1,
  };

  enum class TextBoundaryPolicy : uint8_t {
    CONTENT = 0,
    PREVIOUS_VISIBLE_LINE_END = 1,
    OWNER_LINE_END = 2,
  };

  enum class TextSemanticsPolicy : uint8_t {
    PARTICIPATES = 0,
    SKIP = 1,
  };

  struct VisualLineSemantics {
    PointerHitPolicy pointer_hit{PointerHitPolicy::CONTENT};
    TextBoundaryPolicy text_boundary{TextBoundaryPolicy::CONTENT};
    TextSemanticsPolicy text_semantics{TextSemanticsPolicy::PARTICIPATES};
  };

  inline const VisualLineSemantics& getVisualLineSemantics(VisualLineKind kind) {
    static const VisualLineSemantics content{PointerHitPolicy::CONTENT, TextBoundaryPolicy::CONTENT,
                                             TextSemanticsPolicy::PARTICIPATES};
    static const VisualLineSemantics phantom{PointerHitPolicy::CONTENT, TextBoundaryPolicy::OWNER_LINE_END,
                                             TextSemanticsPolicy::SKIP};
    static const VisualLineSemantics codelens{PointerHitPolicy::OWNER_LINE_START,
                                              TextBoundaryPolicy::PREVIOUS_VISIBLE_LINE_END, TextSemanticsPolicy::SKIP};

    switch (kind) {
    case VisualLineKind::PHANTOM:
      return phantom;
    case VisualLineKind::CODELENS:
      return codelens;
    case VisualLineKind::CONTENT:
    default:
      return content;
    }
  }

  /// Text width measurement interface implemented by each platform
  class TextMeasurer {
  public:
    virtual ~TextMeasurer() = default;

    /// Measure pixel width of editor main-font text
    /// @param text UTF-16 text content
    /// @param font_style Font style bit flags (FontStyle bits: BOLD=1, ITALIC=2, STRIKETHROUGH=4)
    virtual float measureWidth(const U16String& text, int32_t font_style) = 0;

    /// Measure pixel width of InlayHint text (platform uses InlayHint-specific font)
    virtual float measureInlayHintWidth(const U16String& text) = 0;

    /// Measure pixel width of InlayHint icon (platform returns actual drawn width by icon ID)
    virtual float measureIconWidth(int32_t icon_id) = 0;

    /// Get ascent/descent metrics of current font
    virtual FontMetrics getFontMetrics() = 0;
  };

  /// Text layout engine
  class TextLayout {
  public:
    TextLayout(const SharedPtr<TextMeasurer>& measurer, const TextStyleRegistry& text_styles);

    void loadDocument(const SharedPtr<Document>& document);

    void setViewport(const Size& viewport);

    void setViewState(const ViewState& view_state);

    void setWrapMode(WrapMode mode);

    void setRenderLineBreaks(bool enabled);

    void setTabSize(uint32_t tab_size);

    uint32_t getTabSize() const;

    void layoutLine(size_t index, LogicalLine& logical_line);

    VisibleLineInfo layoutVisibleLines(EditorRenderModel& model);

    void finalizeVisualRuns(EditorRenderModel& model, const VisualRunInput& input);

    /// Pointer hit test for cursor placement and taps.
    /// The result preserves the visual side of a soft-wrap boundary.
    /// @param screen_point Screen point (relative to editor view top-left)
    CaretHit hitTestPointer(const PointF& screen_point);

    /// Text-boundary hit test: convert screen point to a stable text boundary
    /// used by selection dragging and handle dragging.
    /// Virtual lines (for example CodeLens) are mapped to adjacent document text boundaries.
    /// Clickable inline runs such as Link still map to their own logical text range.
    /// @param screen_point Screen point (relative to editor view top-left)
    CaretHit hitTestTextBoundary(const PointF& screen_point);

    /// Screen hit test: detect hit on InlayHint, GutterIcon, fold marker, and other decorations
    /// @param screen_point Screen point (relative to editor view top-left)
    HitTarget hitTestDecoration(const PointF& screen_point);

    /// Get screen coordinates for a text position (for cursor, floating panel, etc.)
    /// @return Screen coordinates (x = cursor x, y = line start y)
    PointF getPositionScreenCoord(const TextPosition& position, CaretAffinity affinity = CaretAffinity::DOWNSTREAM);

    /// Get screen x range from one column to another and also return y (avoid repeated query)
    /// @param line Logical line index
    /// @param col_start Start column
    /// @param col_end End column
    /// @param out_x_start Output start x screen coordinate
    /// @param out_x_end Output end x screen coordinate
    /// @param out_y Output y screen coordinate of the line containing start column
    void getColumnScreenRange(size_t line, size_t col_start, size_t col_end, float& out_x_start, float& out_x_end,
                              float& out_y);

    /// Get selection rectangles for a column range, correctly handling wrapped lines.
    /// For non-wrapped lines or single visual lines, produces one rect.
    /// For wrapped lines, produces one rect per visual line that intersects [col_start, col_end).
    /// @param line Logical line index
    /// @param col_start Start column (inclusive)
    /// @param col_end End column (exclusive)
    /// @param rect_height Height of each selection rectangle
    /// @param out_rects Output vector to append selection rects to
    void getColumnSelectionRects(size_t line, size_t col_start, size_t col_end, float rect_height,
                                 Vector<Rect>& out_rects);

    /// Get line height
    float getLineHeight() const;

    /// Get total content height of document (sum of all logical line heights)
    float getContentHeight();

    /// Get width of longest line (meaningful in no-wrap mode)
    float getMaxLineWidth();

    /// Clamp scroll offsets into valid range
    /// @param scroll_x Horizontal scroll offset (input/output)
    /// @param scroll_y Vertical scroll offset (input/output)
    void clampScroll(float& scroll_x, float& scroll_y);

    /// Clamp scroll offsets and sync the normalized view state back into layout
    /// @param view_state View state to normalize and apply
    void normalizeViewState(ViewState& view_state);

    /// Get current scroll bounds and content size
    ScrollBounds getScrollBounds();

    void resetMeasurer();

    LayoutMetrics& getLayoutMetrics();

    /// Get start y of a logical line via prefix index
    /// @param line Logical line index
    float getLineStartY(size_t line);

    /// Mark content-size cache as dirty (call after external edits/folding changes)
    /// @param from_line Prefix index becomes dirty starting from this line, default 0 = rebuild all
    void invalidateContentMetrics(size_t from_line = 0);

    /// Check whether a hidden source position is visible as the tail of a collapsed fold.
    bool isFoldTailProjectedPosition(const TextPosition& position, bool include_end, size_t* out_owner_line = nullptr);

    /// Get the visible source range projected as the tail of a collapsed fold owner line.
    bool getFoldTailProjectedRange(size_t owner_line, TextRange& out_range);

  private:
    SharedPtr<TextMeasurer> m_measurer_;
    SharedPtr<Document> m_document_;
    const TextStyleRegistry& m_text_styles_;
    Size m_viewport_;
    ViewState m_view_state_;
    WrapMode m_wrap_mode_{WrapMode::NONE};
    bool m_render_line_breaks_{false};
    LayoutMetrics m_layout_metrics_;
    bool m_is_monospace_{true};
    float m_number_width_;
    float m_space_width_;
    uint32_t m_tab_size_{4};
    // Text width measurement cache (key = text + font_style pair)
    struct TextWidthKey {
      U16String text;
      int32_t font_style;
      bool operator==(const TextWidthKey& other) const {
        return font_style == other.font_style && text == other.text;
      }
    };
    struct TextWidthKeyHash {
      size_t operator()(const TextWidthKey& key) const {
        size_t h1 = std::hash<U16String>{}(key.text);
        size_t h2 = std::hash<int32_t>{}(key.font_style);
        return h1 ^ (h2 << 16);
      }
    };
    HashMap<TextWidthKey, float, TextWidthKeyHash> m_text_widths_;

    struct ContentMetrics {
      float content_height{0};
      float max_line_width{0};
    };

    // content metrics cache
    ContentMetrics m_content_metrics_cache_;
    bool m_content_metrics_dirty_{true};

    struct FoldTailProjection {
      size_t owner_line{0};
      size_t source_line{0};
      size_t visible_start{0};
      size_t visible_end{0};
    };

    // line-height prefix index
    // m_line_prefix_y_[i] = start y of line i (sum of heights of first i lines)
    Vector<float> m_line_prefix_y_;
    // Prefix values from m_prefix_dirty_from_ may be stale and need rebuild
    size_t m_prefix_dirty_from_{0};

    /// Ensure prefix index covers at least up to line up_to_line (inclusive), rebuilding forward from dirty start as needed
    void ensurePrefixIndexUpTo(size_t up_to_line);
    /// Mark prefix index as dirty starting from from_line
    void invalidatePrefixFrom(size_t from_line);

    float measureWidth(const U16String& text, int32_t font_style = FONT_STYLE_NORMAL);
    ContentMetrics computeContentMetrics_();
    /// O(1) fast content size estimation: height via prefix index, max line width from laid-out lines cache.
    /// Used in clampScroll hot path to avoid full O(N) layoutLine traversal.
    ContentMetrics estimateContentMetrics_();
    VisibleLineInfo resolveVisibleLines();
    /// Layout one line of text into full VisualLine list (including highlights, inlay hints, cross-line phantom text expansion, auto wrap)
    void layoutLineIntoVisualLines(size_t line_index, const U16String& line_text, float start_y,
                                   Vector<VisualLine>& out_visual_lines);
    /// Zip-align one line with highlight spans, inlay hints, and phantom texts to build VisualRuns
    void buildLineRuns(size_t line_index, const U16String& line_text, const LineLayoutDecorations& decorations,
                       Vector<VisualRun>& runs);
    void cropVisualLineRuns(VisualLine& visual_line, float scroll_x);
    void finalizeVisualLineRuns(VisualLine& visual_line, const VisualRunInput& input);
    void applyWhitespaceMode(VisualLine& visual_line, const VisualRunInput& input);
    /// Auto-wrap: split one line's runs into multiple VisualLines by available width
    void wrapLineRuns(size_t line_index, float start_y, float line_height, Vector<VisualRun>& runs,
                      Vector<VisualLine>& out_lines, size_t wrap_index_offset = 0);
    /// Append fold placeholder and tail-line runs to collapsed first line (first line + placeholder + tail content)
    void appendFoldTailRuns(size_t index, const U16String& line_text, LogicalLine& logical_line);
    void appendLineBreakRun(size_t owner_line, LogicalLine& logical_line);
    float computeLineNumberWidth() const;

    /// Find logical line index hit by screen y (skip folded hidden lines)
    size_t findHitLine(float abs_y);
    /// Find wrapped sub-line index hit inside a logical line
    size_t findHitWrapIndex(const LogicalLine& ll, float abs_y, float line_height) const;
    /// Shared implementation behind pointer/text-boundary hit testing.
    CaretHit hitTestInternal(const PointF& screen_point, bool text_boundary);
    /// Resolve the logical position before soft-wrap affinity is attached.
    TextPosition hitTestPositionInternal(const PointF& screen_point, bool text_boundary);
    /// Resolve a virtual visual line under pointer-hit semantics.
    TextPosition mapVisualLineToPointerTarget(size_t logical_line, const VisualLine& visual_line) const;
    /// Resolve a virtual visual line under text-boundary semantics.
    TextPosition mapVisualLineToTextBoundary(size_t logical_line, const VisualLine& visual_line) const;
    /// Find the previous visible logical line and return its end position.
    TextPosition previousVisibleLineEnd(size_t logical_line) const;
    /// Build fold-tail projection metadata from one collapsed region.
    bool buildFoldTailProjection(const FoldRegion& region, FoldTailProjection& out_projection);
    /// Resolve fold-tail projection metadata by visible owner line.
    bool resolveFoldTailProjectionForOwnerLine(size_t owner_line, FoldTailProjection& out_projection);
    /// Resolve fold-tail projection metadata by hidden source line.
    bool resolveFoldTailProjectionForSourceLine(size_t source_line, FoldTailProjection& out_projection);
    /// Resolve which visible logical line owns geometry for a source line range.
    bool resolveSourceVisualOwnerLine(size_t source_line, size_t range_start, size_t range_end, bool include_empty_end,
                                      size_t& out_owner_line);
    /// Get TEXT/TAB logical column extent and total width for one visual line.
    bool getVisualLineTextColumnExtent(const VisualLine& visual_line, size_t source_line, size_t& out_col_min,
                                       size_t& out_col_max, float& out_total_width);
    /// Map one logical column to x within a single visual line.
    bool columnToVisualLineX(const VisualLine& visual_line, size_t source_line, size_t column, bool allow_line_end,
                             float& out_x);
    /// Resolve the screen x range for a logical column interval on one logical line.
    void resolveColumnXRange(size_t line, size_t col_start, size_t col_end, float& out_x_start, float& out_x_end);
    /// Build gutter icon render items for one logical line at the given screen Y
    void buildGutterIconRenderItems(size_t logical_line, float line_top_screen, float gutter_offset,
                                    Vector<GutterIconRenderItem>& out_items) const;
    /// Build one fold marker render item for one logical line at the given screen Y
    bool buildFoldMarkerRenderItem(size_t logical_line, float line_top_screen, float gutter_offset,
                                   FoldMarkerRenderItem& out_item) const;
    /// Find the visual line that owns gutter semantics for a logical line.
    const VisualLine* findGutterOwnerLine(const LogicalLine& logical_line) const;
    /// Get the screen top y of the visual line that owns gutter semantics.
    float getGutterOwnerTopScreen(const LogicalLine& logical_line, float scroll_y) const;
  };
}

#endif //SWEETEDITOR_LAYOUT_H
