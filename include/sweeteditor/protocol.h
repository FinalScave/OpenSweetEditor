#ifndef SWEETEDITOR_PROTOCOL_H
#define SWEETEDITOR_PROTOCOL_H

#include <utility>
#include <sweeteditor/editor_core.h>

namespace NS_SWEETEDITOR {
namespace protocol {

  struct SE_PROTOCOL_IN(keymap) SetKeyMapPayload {
    Vector<KeyBinding> bindings;
  };

  struct SE_PROTOCOL_IN(foundation) ApplyTextEditsPayload {
    Vector<TextEdit> edits;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineSpansPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    SE_PROTOCOL_WIRE(enum_i32)
    SpanLayer layer {SpanLayer::SYNTAX};
    Vector<StyleSpan> spans;
  };

  struct SE_PROTOCOL_IN(adornment) RegisterBatchTextStylesPayload {
    SE_PROTOCOL_MAP_ENTRY(style_id, style)
    Vector<std::pair<uint32_t, TextStyle>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineSpansPayload {
    SE_PROTOCOL_WIRE(enum_i32)
    SpanLayer layer {SpanLayer::SYNTAX};
    SE_PROTOCOL_MAP_ENTRY(line, spans)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<StyleSpan>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineDiagnosticsPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<Diagnostic> diagnostics;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineDiagnosticsPayload {
    SE_PROTOCOL_MAP_ENTRY(line, diagnostics)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<Diagnostic>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineDocumentHighlightsPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<DocumentHighlight> highlights;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineDocumentHighlightsPayload {
    SE_PROTOCOL_MAP_ENTRY(line, highlights)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<DocumentHighlight>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetFoldRegionsPayload {
    Vector<FoldRegion> regions;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineInlayHintsPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<InlayHint> hints;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineInlayHintsPayload {
    SE_PROTOCOL_MAP_ENTRY(line, hints)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<InlayHint>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLinePhantomTextsPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<PhantomText> phantoms;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLinePhantomTextsPayload {
    SE_PROTOCOL_MAP_ENTRY(line, phantoms)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<PhantomText>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineGutterIconsPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<GutterIcon> icons;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineGutterIconsPayload {
    SE_PROTOCOL_MAP_ENTRY(line, icons)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<GutterIcon>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineCodeLensPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<CodeLensItem> items;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineCodeLensPayload {
    SE_PROTOCOL_MAP_ENTRY(line, items)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<CodeLensItem>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetLineLinksPayload {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t line {0};
    Vector<LinkSpan> links;
  };

  struct SE_PROTOCOL_IN(adornment) SetBatchLineLinksPayload {
    SE_PROTOCOL_MAP_ENTRY(line, links)
    SE_PROTOCOL_KEY_WIRE(size_as_u32)
    Vector<std::pair<size_t, Vector<LinkSpan>>> entries;
  };

  struct SE_PROTOCOL_IN(adornment) SetIndentGuidesPayload {
    Vector<IndentGuide> guides;
  };

  struct SE_PROTOCOL_IN(adornment) SetBracketGuidesPayload {
    Vector<BracketGuide> guides;
  };

  struct SE_PROTOCOL_IN(adornment) SetFlowGuidesPayload {
    Vector<FlowGuide> guides;
  };

  struct SE_PROTOCOL_IN(adornment) SetSeparatorGuidesPayload {
    Vector<SeparatorGuide> guides;
  };

  struct SE_PROTOCOL_IN(linked_editing) StartLinkedEditingPayload {
    Vector<TabStopGroup> groups;
  };

}
}

#endif //SWEETEDITOR_PROTOCOL_H
