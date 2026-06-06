#ifndef SWEETEDITOR_RENDER_COMPOSER_H
#define SWEETEDITOR_RENDER_COMPOSER_H

#include <sweeteditor/editor_types.h>
#include <sweeteditor/ime_types.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/search.h>
#include <sweeteditor/visual.h>

namespace NS_SWEETEDITOR {
  class Document;
  class EditorInteraction;
  class LinkedEditingSession;

  class RenderComposer {
  public:
    RenderComposer(TextLayout* text_layout, DecorationManager* decorations, EditorSettings* settings);

    void buildCursorModel(EditorRenderModel& model, const TextPosition& cursor_position,
                          bool has_selection, float line_height) const;

    void buildCompositionRangeEffect(EditorRenderModel& model, const CompositionState& composition,
                                     float line_height) const;

    void buildSelectionRangeEffects(EditorRenderModel& model, Document* document,
                                    const CaretState& caret, float line_height) const;

    void buildSearchRangeEffects(EditorRenderModel& model, Document* document,
                                 const Vector<SearchMatch>& matches,
                                 const Vector<Vector<uint32_t>>& match_indices_by_line,
                                 int32_t current_index,
                                 float line_height) const;

    void buildLinkedEditingRangeEffects(EditorRenderModel& model, Document* document,
                                        const LinkedEditingSession* linked_editing_session, float line_height) const;

    void buildGuideSegments(EditorRenderModel& model, Document* document,
                            TextMeasurer& measurer, float line_height) const;

    void buildDiagnosticRangeEffects(EditorRenderModel& model, Document* document, float line_height) const;

    void buildBracketHighlightRangeEffects(EditorRenderModel& model, Document* document,
                                           const TextPosition& cursor_position, const Vector<BracketPair>& bracket_pairs,
                                           const TextPosition& external_bracket_open, const TextPosition& external_bracket_close,
                                           bool has_external_brackets, float line_height) const;

    void buildScrollbarModel(EditorRenderModel& model, const EditorInteraction& interaction) const;

  private:
    static constexpr size_t kMaxBracketScanChars = 10000;

    void appendRangeEffectsForRange(EditorRenderModel& model,
                                    size_t line,
                                    size_t col_start,
                                    size_t col_end,
                                    float rect_height,
                                    float y_offset,
                                    RangeEffectKind kind,
                                    const RangeEffectStyle& style) const;

    TextLayout* m_text_layout_ {nullptr};
    DecorationManager* m_decorations_ {nullptr};
    EditorSettings* m_settings_ {nullptr};
  };
}

#endif // SWEETEDITOR_RENDER_COMPOSER_H
