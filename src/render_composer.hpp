#ifndef SWEETEDITOR_RENDER_COMPOSER_HPP
#define SWEETEDITOR_RENDER_COMPOSER_HPP

#include <sweeteditor/ime_types.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/linked_editing.h>
#include <sweeteditor/search.h>

namespace NS_SWEETEDITOR {

  class EditorInteraction;

  struct RenderModelInput {
    Document& document;
    const CaretState& caret;
    HitTarget active_hit_target;
    const Vector<SearchMatch>& search_matches;
    const Vector<Vector<uint32_t>>& search_match_indices_by_line;
    int32_t current_search_match{-1};
    const std::optional<CompositionState>& composition;
    Vector<LinkedEditingHighlight> linked_editing_highlights;
    const Vector<BracketPair>& bracket_pairs;
    std::optional<TextRange> external_bracket_match;
  };

  class RenderModelComposer {
  public:
    RenderModelComposer(TextLayout& text_layout, TextMeasurer& measurer, EditorSettings& settings,
                        const EditorInteraction& interaction);

    void compose(EditorRenderModel& model, const RenderModelInput& input) const;

  private:
    static constexpr size_t kMaxBracketScanChars = 10000;

    void finalizeTextRuns(EditorRenderModel& model, const RenderModelInput& input) const;
    void composeCursor(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeCompositionEffects(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeSelection(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeSearchEffects(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeDocumentHighlightEffects(EditorRenderModel& model, const RenderModelInput& input,
                                         float line_height) const;
    void composeLinkedEditingEffects(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeGuides(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeDiagnosticEffects(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeBracketMatchEffects(EditorRenderModel& model, const RenderModelInput& input, float line_height) const;
    void composeScrollbars(EditorRenderModel& model) const;
    void appendRangeEffectsForRange(EditorRenderModel& model, size_t line, size_t col_start, size_t col_end,
                                    float rect_height, float y_offset, RangeEffectKind kind,
                                    const RangeEffectStyle& style) const;

    TextLayout& m_text_layout_;
    TextMeasurer& m_measurer_;
    EditorSettings& m_settings_;
    const EditorInteraction& m_interaction_;
  };

}

#endif // SWEETEDITOR_RENDER_COMPOSER_HPP
