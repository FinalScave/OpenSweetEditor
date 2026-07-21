#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/layout.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/document.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {
  EditorRenderModel renderInvisibleModel(const U8String& text, WhitespaceRenderMode mode, bool line_breaks = false,
                                         TextRange selection = {}) {
    SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
    SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
    TextLayout layout(measurer, decorations);
    SharedPtr<Document> document = makeShared<LineArrayDocument>(text);
    layout.loadDocument(document);
    layout.setViewport({640, 240});
    layout.setViewState({1.0f, 0.0f, 0.0f});
    layout.setWrapMode(WrapMode::NONE);
    layout.setRenderLineBreaks(line_breaks);

    VisualRunInput input;
    input.whitespace_mode = mode;
    if (selection.start != selection.end) {
      input.selection_range = selection;
    }

    EditorRenderModel model;
    layout.layoutVisibleLines(model);
    layout.finalizeVisualRuns(model, input);
    return model;
  }

  size_t countWhitespaceColumns(const EditorRenderModel& model) {
    size_t count = 0;
    for (const VisualLine& line : model.lines) {
      for (const VisualRun& run : line.runs) {
        if (run.type == VisualRunType::WHITESPACE && run.length > 0) {
          count += run.length;
        }
      }
    }
    return count;
  }

  size_t countVisibleTabs(const EditorRenderModel& model) {
    size_t count = 0;
    for (const VisualLine& line : model.lines) {
      for (const VisualRun& run : line.runs) {
        if (run.type == VisualRunType::TAB && !run.text.empty()) {
          ++count;
        }
      }
    }
    return count;
  }

  size_t countLineBreakMarkers(const EditorRenderModel& model) {
    size_t count = 0;
    for (const VisualLine& line : model.lines) {
      for (const VisualRun& run : line.runs) {
        if (run.type == VisualRunType::NEWLINE && !run.text.empty()) {
          ++count;
        }
      }
    }
    return count;
  }
}

TEST_CASE("TextLayout materializes whitespace markers by render mode") {
  const U8String text = "  foo bar  \n\tbaz";

  CHECK(countWhitespaceColumns(renderInvisibleModel(text, WhitespaceRenderMode::NONE)) == 0);
  CHECK(countVisibleTabs(renderInvisibleModel(text, WhitespaceRenderMode::NONE)) == 0);

  CHECK(countWhitespaceColumns(renderInvisibleModel(text, WhitespaceRenderMode::ALL)) == 5);
  CHECK(countVisibleTabs(renderInvisibleModel(text, WhitespaceRenderMode::ALL)) == 1);

  CHECK(countWhitespaceColumns(renderInvisibleModel(text, WhitespaceRenderMode::TRAILING)) == 2);
  CHECK(countVisibleTabs(renderInvisibleModel(text, WhitespaceRenderMode::TRAILING)) == 0);

  CHECK(countWhitespaceColumns(renderInvisibleModel(text, WhitespaceRenderMode::BOUNDARY)) == 4);
  CHECK(countVisibleTabs(renderInvisibleModel(text, WhitespaceRenderMode::BOUNDARY)) == 1);
}

TEST_CASE("TextLayout materializes whitespace markers only inside selection") {
  const U8String text = "a b c";
  EditorRenderModel model = renderInvisibleModel(text, WhitespaceRenderMode::SELECTION, false, {{0, 1}, {0, 4}});
  CHECK(countWhitespaceColumns(model) == 2);
}

TEST_CASE("TextLayout materializes line break markers from real line endings") {
  EditorRenderModel model = renderInvisibleModel("a\nb\r\nc", WhitespaceRenderMode::NONE, true);
  CHECK(countLineBreakMarkers(model) == 2);
}

TEST_CASE("TextLayout hit test on line break marker maps to line end") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
  TextLayout layout(measurer, decorations);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc\n");
  layout.loadDocument(document);
  layout.setViewport({320, 120});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);
  layout.setRenderLineBreaks(true);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  REQUIRE(countLineBreakMarkers(model) == 1);

  PointF line_end = layout.getPositionScreenCoord({0, 3});
  float probe_y = line_end.y + layout.getLineHeight() * 0.5f;
  CHECK(layout.hitTestPointer({line_end.x + 5.0f, probe_y}).position == (TextPosition{0, 3}));
}
