#ifndef SWEETEDITOR_RENDER_COMPOSER_H
#define SWEETEDITOR_RENDER_COMPOSER_H

#include <editor_types.h>
#include <layout.h>
#include <visual.h>

namespace NS_SWEETEDITOR {
  class Document;
  class EditorInteraction;
  class LinkedEditingSession;

  class RenderComposer {
  public:
    RenderComposer(TextLayout* text_layout, DecorationManager* decorations, EditorSettings* settings);

    void buildCursorModel(EditorRenderModel& model, const TextPosition& cursor_position,
                          bool has_selection, float line_height) const;

    void buildCompositionDecoration(EditorRenderModel& model, const CompositionState& composition,
                                    float line_height) const;

    void buildSelectionRects(EditorRenderModel& model, Document* document,
                             const CaretState& caret, float line_height) const;

    void buildLinkedEditingRects(EditorRenderModel& model, Document* document,
                                 const LinkedEditingSession* linked_editing_session, float line_height) const;

    void buildGuideSegments(EditorRenderModel& model, Document* document,
                            TextMeasurer& measurer, float line_height) const;

    void buildDiagnosticDecorations(EditorRenderModel& model, Document* document, float line_height) const;

    void buildBracketHighlightRects(EditorRenderModel& model, Document* document,
                                    const TextPosition& cursor_position, const Vector<BracketPair>& bracket_pairs,
                                    const TextPosition& external_bracket_open, const TextPosition& external_bracket_close,
                                    bool has_external_brackets, float line_height) const;

    void buildScrollbarModel(EditorRenderModel& model, const EditorInteraction& interaction) const;

  private:
    static constexpr size_t kMaxBracketScanChars = 10000;

    TextLayout* m_text_layout_ {nullptr};
    DecorationManager* m_decorations_ {nullptr};
    EditorSettings* m_settings_ {nullptr};
  };
}

#endif // SWEETEDITOR_RENDER_COMPOSER_H
