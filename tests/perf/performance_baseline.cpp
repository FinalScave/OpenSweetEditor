#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "layout.h"
#include "decoration.h"
#include "document.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {
  U8String makeRepeatedLines(size_t line_count, const U8String& line_text) {
    U8String out;
    out.reserve((line_text.size() + 1) * line_count);
    for (size_t i = 0; i < line_count; ++i) {
      if (i > 0) out += "\n";
      out += line_text;
    }
    return out;
  }

  EditorCore makeEditor(const U8String& text,
                        const Viewport& viewport,
                        WrapMode wrap_mode = WrapMode::NONE) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>(text));
    editor.setViewport(viewport);
    editor.setWrapMode(wrap_mode);
    return editor;
  }

  TextLayout makeLayout(const U8String& text,
                        const Viewport& viewport,
                        WrapMode wrap_mode = WrapMode::NONE) {
    SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
    SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
    TextLayout layout(measurer, decorations);
    layout.loadDocument(makeShared<LineArrayDocument>(text));
    layout.setViewport(viewport);
    layout.setViewState({1.0f, 0.0f, 0.0f});
    layout.setWrapMode(wrap_mode);
    return layout;
  }
}

TEST_CASE("Performance baseline: scroll metrics on many short lines") {
  EditorCore editor = makeEditor(makeRepeatedLines(5000, "abcdefghijklmnopqrst"), {180, 120});

  BENCHMARK("ScrollMetrics_LargeShortLines") {
    editor.setScroll(0.0f, 40000.0f);
    ScrollMetrics metrics = editor.getScrollMetrics();
    return metrics.max_scroll_y;
  };
}

TEST_CASE("Performance baseline: build render model on wrapped long lines") {
  EditorCore editor = makeEditor(makeRepeatedLines(600, "abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789"),
                                 {120, 220},
                                 WrapMode::CHAR_BREAK);

  BENCHMARK("BuildRenderModel_WrappedLongLines") {
    editor.setScroll(0.0f, 6000.0f);
    EditorRenderModel model;
    editor.buildRenderModel(model);
    return model.lines.size();
  };
}

TEST_CASE("Performance baseline: hitTest mapping on large wrapped layout") {
  TextLayout layout = makeLayout(makeRepeatedLines(2000, "abcdefghijklmnopqrstuvwxyz0123456789"),
                                 {120, 240},
                                 WrapMode::CHAR_BREAK);

  EditorRenderModel model;
  layout.layoutVisibleLines(model, PresentationContext {});
  REQUIRE_FALSE(model.lines.empty());

  BENCHMARK("HitTest_WrappedLargeLayout") {
    TextPosition last {};
    for (size_t i = 0; i < 60; ++i) {
      const float y = 6.0f + static_cast<float>((i % 12) * 14);
      const float x = 36.0f + static_cast<float>((i % 5) * 18);
      last = layout.hitTestPointer({x, y});
    }
    return last.line + last.column;
  };
}

TEST_CASE("Performance baseline: render model with guide and diagnostic decorations") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>(makeRepeatedLines(800, "    if (value > 0) return value;")));
  editor.setViewport({240, 220});

  editor.setIndentGuides({IndentGuide{{0, 4}, {799, 4}}});
  editor.setBracketGuides({BracketGuide{{0, 4}, {799, 4}, {{200, 8}, {400, 8}, {600, 8}}}});
  editor.setFlowGuides({FlowGuide{{10, 4}, {790, 8}}});
  editor.setSeparatorGuides({SeparatorGuide{300, SeparatorStyle::SINGLE, 20, 4}});
  for (size_t line = 0; line < 800; line += 20) {
    editor.setLineDiagnostics(line, {{4, 8, DiagnosticSeverity::DIAG_WARNING}});
  }

  BENCHMARK("BuildRenderModel_WithDecorations") {
    editor.setScroll(0.0f, 5000.0f);
    EditorRenderModel model;
    editor.buildRenderModel(model);
    return model.guide_segments.size() + model.diagnostic_decorations.size();
  };
}
