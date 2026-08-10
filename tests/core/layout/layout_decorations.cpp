#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/layout.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/document.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("TextLayout hitTest/getPositionScreenCoord stay consistent with inlay and phantom runs") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  document->getDecorations().setLineInlayHints(0, {InlayHint{InlayType::TEXT, 1, 0, "hint"}});
  document->getDecorations().setLinePhantomTexts(0, {PhantomText{2, "ghost"}});

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  for (size_t col = 0; col <= 4; ++col) {
    const PointF pos = layout.getPositionScreenCoord({0, col});
    const TextPosition mapped = layout.hitTestPointer({pos.x + 1.0f, pos.y + layout.getLineHeight() * 0.5f}).position;
    CHECK(mapped == (TextPosition{0, col}));
  }

  const float x1 = layout.getPositionScreenCoord({0, 1}).x;
  const float x2 = layout.getPositionScreenCoord({0, 2}).x;
  const float x3 = layout.getPositionScreenCoord({0, 3}).x;

  // Inlay/phantom occupy visual width, so logical columns after them should jump more than one glyph width.
  CHECK((x2 - x1) > 10.0f);
  CHECK((x3 - x2) > 10.0f);
}

TEST_CASE("TextLayout maps phantom continuation rows to document boundaries") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);
  document->getDecorations().setLinePhantomTexts(0, {PhantomText{2, "first\nsecond"}});

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  const auto phantom = std::find_if(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::PHANTOM;
  });
  REQUIRE(phantom != model.lines.end());
  const PointF point{phantom->runs.front().x + 1.0f, phantom->line_number_position.y};

  const CaretHit pointer = layout.hitTestPointer(point);
  CHECK_FALSE(pointer.hits_document_text);
  CHECK(pointer.position == (TextPosition{0, 4}));
  CHECK(layout.hitTestTextBoundary(point).position == (TextPosition{0, 4}));
}
