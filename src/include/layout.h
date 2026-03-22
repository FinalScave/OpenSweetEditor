//
// Created by Scave on 2025/12/7.
//

#ifndef SWEETEDITOR_LAYOUT_H
#define SWEETEDITOR_LAYOUT_H

#include <document.h>
#include <decoration.h>
#include <visual.h>
#include <gesture.h>

namespace NS_SWEETEDITOR {
  /// Auto-wrap mode enum
  enum struct WrapMode {
    /// No wrapping
    NONE,
    /// Character-level wrapping
    CHAR_BREAK,
    /// Word-level wrapping
    WORD_BREAK,
  };

  /// Font metric info
  struct FontMetrics {
    float ascent;
    float descent;
  };

  /// Visible line region info
  struct VisibleLineInfo {
    /// Index of first visible line
    size_t first_line {0};
    /// Index of last visible line
    size_t last_line {0};
    /// Y position of the first visible line (negative when only partially visible)
    float first_line_y {0};
  };

  /// Scroll bounds and content size info (used by platform scrollbar calculations)
  struct ScrollBounds {
    /// Text area start x (usually equal to gutter width)
    float text_area_x {0};
    /// Text area width (viewport - gutter)
    float text_area_width {0};
    /// Total content width (no-wrap = longest visual line; wrap = text area width)
    float content_width {0};
    /// Total content height
    float content_height {0};
    /// Maximum horizontal scroll
    float max_scroll_x {0};
    /// Maximum vertical scroll
    float max_scroll_y {0};
  };

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
    TextLayout(const Ptr<TextMeasurer>& measurer, const Ptr<DecorationManager>& decoration_manager);

    void loadDocument(const Ptr<Document>& document);

    void setViewport(const Viewport& viewport);

    void setViewState(const ViewState& view_state);

    void setWrapMode(WrapMode mode);

    void layoutLine(size_t index, LogicalLine& logical_line);

    void layoutVisibleLines(EditorRenderModel& model);

    /// Screen hit test: convert screen point to text position (for cursor placement)
    /// @param screen_point Screen point (relative to editor view top-left)
    TextPosition hitTest(const PointF& screen_point);

    /// Screen hit test: detect hit on InlayHint, GutterIcon, fold marker, and other decorations
    /// @param screen_point Screen point (relative to editor view top-left)
    HitTarget hitTestDecoration(const PointF& screen_point);

    /// Get screen coordinates for a text position (for cursor, floating panel, etc.)
    /// @return Screen coordinates (x = cursor x, y = line start y)
    PointF getPositionScreenCoord(const TextPosition& position);

    /// Get screen x range from one column to another on a line (for selection highlight)
    /// @param line Logical line index
    /// @param col_start Start column
    /// @param col_end End column
    /// @param out_x_start Output start x screen coordinate
    /// @param out_x_end Output end x screen coordinate
    void getColumnScreenRange(size_t line, size_t col_start, size_t col_end, float& out_x_start, float& out_x_end);

    /// Get screen x range from one column to another and also return y (avoid repeated query)
    /// @param line Logical line index
    /// @param col_start Start column
    /// @param col_end End column
    /// @param out_x_start Output start x screen coordinate
    /// @param out_x_end Output end x screen coordinate
    /// @param out_y Output y screen coordinate of the line containing start column
    void getColumnScreenRange(size_t line, size_t col_start, size_t col_end,
                              float& out_x_start, float& out_x_end, float& out_y);

    /// Get selection rectangles for a column range, correctly handling wrapped lines.
    /// For non-wrapped lines or single visual lines, produces one rect.
    /// For wrapped lines, produces one rect per visual line that intersects [col_start, col_end).
    /// @param line Logical line index
    /// @param col_start Start column (inclusive)
    /// @param col_end End column (exclusive)
    /// @param rect_height Height of each selection rectangle
    /// @param out_rects Output vector to append selection rects to
    void getColumnSelectionRects(size_t line, size_t col_start, size_t col_end,
                                 float rect_height, Vector<SelectionRect>& out_rects);

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

    /// Get current scroll bounds and content size
    ScrollBounds getScrollBounds();

    void resetMeasurer();

    LayoutMetrics& getLayoutMetrics();

    /// Mark content-size cache as dirty (call after external edits/folding changes)
    /// @param from_line Prefix index becomes dirty starting from this line, default 0 = rebuild all
    void invalidateContentMetrics(size_t from_line = 0);
  private:
    Ptr<TextMeasurer> m_measurer_;
    Ptr<Document> m_document_;
    Ptr<DecorationManager> m_decoration_manager_;
    Viewport m_viewport_;
    ViewState m_view_state_;
    WrapMode m_wrap_mode_ {WrapMode::NONE};
    LayoutMetrics m_layout_metrics_;
    bool m_is_monospace_ {true};
    float m_number_width_;
    float m_space_width_;
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
      float content_height {0};
      float max_line_width {0};
    };

    // content metrics cache
    ContentMetrics m_content_metrics_cache_;
    bool m_content_metrics_dirty_ {true};

    // line-height prefix index
    // m_line_prefix_y_[i] = start y of line i (sum of heights of first i lines)
    Vector<float> m_line_prefix_y_;
    // Prefix values from m_prefix_dirty_from_ may be stale and need rebuild
    size_t m_prefix_dirty_from_ {0};

    /// Ensure prefix index covers at least up to line up_to_line (inclusive), rebuilding forward from dirty start as needed
    void ensurePrefixIndexUpTo(size_t up_to_line);
    /// Get start y of line via prefix index
    float getLineStartY(size_t line);
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
    void buildLineRuns(size_t line_index, const U16String& line_text, float start_y, Vector<VisualRun>& runs);
    void cropVisualLineRuns(VisualLine& visual_line, float scroll_x);
    /// Auto-wrap: split one line's runs into multiple VisualLines by available width
    void wrapLineRuns(size_t line_index, float start_y, float line_height,
                      Vector<VisualRun>& runs, Vector<VisualLine>& out_lines);
    /// Append fold placeholder and tail-line runs to collapsed first line (first line + … + tail content)
    void appendFoldTailRuns(size_t index, const U16String& line_text, LogicalLine& logical_line);
    float computeLineNumberWidth() const;
    static bool isWordBreakChar(U16Char ch);

    /// Find logical line index hit by screen y (skip folded hidden lines)
    size_t findHitLine(float abs_y);
    /// Find wrapped sub-line index hit inside a logical line
    size_t findHitWrapIndex(const LogicalLine& ll, float abs_y, float line_height) const;
    /// Build gutter icon render items for one logical line at the given screen Y
    void buildGutterIconRenderItems(size_t logical_line, float line_top_screen,
                                    Vector<GutterIconRenderItem>& out_items) const;
    /// Build one fold marker render item for one logical line at the given screen Y
    bool buildFoldMarkerRenderItem(size_t logical_line, float line_top_screen,
                                   FoldMarkerRenderItem& out_item) const;
  };
}

#endif //SWEETEDITOR_LAYOUT_H
