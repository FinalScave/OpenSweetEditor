#include <catch2/catch_amalgamated.hpp>
#include "layout.h"
#include "decoration.h"
#include "document.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("TextLayout hitTest matches getPositionScreenCoord in non-wrap mode") {
  Ptr<TextMeasurer> measurer = makePtr<FixedWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>("abcdef");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const float probe_y = layout.getPositionScreenCoord({0, 0}).y + layout.getLineHeight() * 0.5f;
  for (size_t col = 0; col < 6; ++col) {
    const PointF pos = layout.getPositionScreenCoord({0, col});
    const TextPosition mapped = layout.hitTest({pos.x + 1.0f, probe_y});
    CHECK(mapped == (TextPosition{0, col}));
  }

  const PointF end_pos = layout.getPositionScreenCoord({0, 6});
  const TextPosition mapped_end = layout.hitTest({end_pos.x + 4.0f, probe_y});
  CHECK(mapped_end == (TextPosition{0, 6}));
}

TEST_CASE("TextLayout hitTest/getPositionScreenCoord stay consistent in wrap mode") {
  Ptr<TextMeasurer> measurer = makePtr<FixedWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>("abcdefghij");
  layout.loadDocument(document);
  layout.setViewport({90, 320}); // text area width ~= 60 => force wrap
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::CHAR_BREAK);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const PointF p0 = layout.getPositionScreenCoord({0, 0});
  const PointF p7 = layout.getPositionScreenCoord({0, 7});
  CHECK(p7.y > p0.y);

  for (size_t col = 0; col < 10; ++col) {
    const PointF pos = layout.getPositionScreenCoord({0, col});
    const float probe_y = pos.y + layout.getLineHeight() * 0.5f;
    const TextPosition mapped = layout.hitTest({pos.x + 1.0f, probe_y});
    CHECK(mapped == (TextPosition{0, col}));
  }
}
