#include <catch2/catch_amalgamated.hpp>
#include "layout.h"
#include "decoration.h"
#include "document.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("TextLayout hitTest/getPositionScreenCoord stay consistent with inlay and phantom runs") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
  TextLayout layout(measurer, decorations);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  decorations->setLineInlayHints(0, {InlayHint{InlayType::TEXT, 1, "hint"}});
  decorations->setLinePhantomTexts(0, {PhantomText{2, "ghost"}});

  EditorRenderModel model;
  layout.layoutVisibleLines(model, PresentationContext {});

  for (size_t col = 0; col <= 4; ++col) {
    const PointF pos = layout.getPositionScreenCoord({0, col});
    const TextPosition mapped = layout.hitTestPointer({pos.x + 1.0f, pos.y + layout.getLineHeight() * 0.5f});
    CHECK(mapped == (TextPosition{0, col}));
  }

  const float x1 = layout.getPositionScreenCoord({0, 1}).x;
  const float x2 = layout.getPositionScreenCoord({0, 2}).x;
  const float x3 = layout.getPositionScreenCoord({0, 3}).x;

  // Inlay/phantom occupy visual width, so logical columns after them should jump more than one glyph width.
  CHECK((x2 - x1) > 10.0f);
  CHECK((x3 - x2) > 10.0f);
}
