#include <catch2/catch_amalgamated.hpp>
#include <algorithm>
#include "layout.h"
#include "decoration.h"
#include "document.h"
#include "test_measurer.h"
#include "utility.h"

using namespace NS_SWEETEDITOR;

static U8String collectVisualLineText(const VisualLine& line) {
  U8String out;
  for (const VisualRun& run : line.runs) {
    if (run.text.empty()) continue;
    U8String text;
    StrUtil::convertUTF16ToUTF8(run.text, text);
    out += text;
  }
  return out;
}

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

TEST_CASE("TextLayout hitTest snaps emoji modifier graphemes to left and right boundaries") {
  Ptr<TextMeasurer> measurer = makePtr<FixedWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB" "B");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const PointF cluster_start = layout.getPositionScreenCoord({0, 1});
  const PointF cluster_end = layout.getPositionScreenCoord({0, 5});
  const float probe_y = cluster_start.y + layout.getLineHeight() * 0.5f;
  const float cluster_width = cluster_end.x - cluster_start.x;

  CHECK(layout.hitTest({cluster_start.x + cluster_width * 0.25f, probe_y}) == (TextPosition{0, 1}));
  CHECK(layout.hitTest({cluster_start.x + cluster_width * 0.75f, probe_y}) == (TextPosition{0, 5}));
}

TEST_CASE("TextLayout horizontal cropping preserves grapheme hit testing") {
  Ptr<TextMeasurer> measurer = makePtr<FixedWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB" "B");
  layout.loadDocument(document);
  layout.setViewport({80, 200});
  layout.setWrapMode(WrapMode::NONE);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const float text_area_x = layout.getLayoutMetrics().textAreaX();
  layout.setViewState({1.0f, text_area_x + 15.0f, 0.0f});
  model = {};
  layout.layoutVisibleLines(model);

  REQUIRE_FALSE(model.lines.empty());

  const auto run_it = std::find_if(model.lines[0].runs.begin(), model.lines[0].runs.end(), [](const VisualRun& run) {
    return run.type == VisualRunType::TEXT && !run.text.empty();
  });
  REQUIRE(run_it != model.lines[0].runs.end());

  U8String cropped_text;
  StrUtil::convertUTF16ToUTF8(run_it->text, cropped_text);
  CHECK(cropped_text == "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB" "B");
}

TEST_CASE("TextLayout wrap keeps emoji modifier grapheme on one visual line") {
  Ptr<TextMeasurer> measurer = makePtr<FixedGraphemeWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB" "B");
  layout.loadDocument(document);
  layout.setViewport({120, 200});
  const float text_area_x = layout.getLayoutMetrics().textAreaX();
  layout.setViewport({text_area_x + 15.0f, 200});
  layout.setWrapMode(WrapMode::CHAR_BREAK);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  REQUIRE(model.lines.size() == 3);
  CHECK(collectVisualLineText(model.lines[0]) == "A");
  CHECK(collectVisualLineText(model.lines[1]) == "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  CHECK(collectVisualLineText(model.lines[2]) == "B");
}

TEST_CASE("TextLayout monospace left crop does not over-trim complex graphemes") {
  Ptr<TextMeasurer> measurer = makePtr<FixedGraphemeWidthTextMeasurer>(10.0f);
  Ptr<DecorationManager> decorations = makePtr<DecorationManager>();
  TextLayout layout(measurer, decorations);

  Ptr<Document> document = makePtr<LineArrayDocument>(
      "\xF0\x9F\x92\x9D\xF0\x9F\x92\x97\xF0\x9F\x87\xA8\xF0\x9F\x87\xB3\xF0\x9F\x87\xB2\xF0\x9F\x87\xB4\xF0\x9F\x91\x8C\xF0\x9F\x8F\xBB");
  layout.loadDocument(document);
  layout.setViewport({160, 200});
  layout.setWrapMode(WrapMode::NONE);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const float text_area_x = layout.getLayoutMetrics().textAreaX();
  layout.setViewState({1.0f, text_area_x + 25.0f, 0.0f});
  model = {};
  layout.layoutVisibleLines(model);

  REQUIRE_FALSE(model.lines.empty());
  CHECK(collectVisualLineText(model.lines[0]) ==
        "\xF0\x9F\x87\xA8\xF0\x9F\x87\xB3\xF0\x9F\x87\xB2\xF0\x9F\x87\xB4\xF0\x9F\x91\x8C\xF0\x9F\x8F\xBB");
}
