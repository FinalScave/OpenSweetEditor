#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/layout.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/document.h>
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("TextLayout hitTest matches getPositionScreenCoord in non-wrap mode") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const float probe_y = layout.getPositionScreenCoord({0, 0}).y + layout.getLineHeight() * 0.5f;
  for (size_t col = 0; col < 6; ++col) {
    const PointF pos = layout.getPositionScreenCoord({0, col});
    const TextPosition mapped = layout.hitTestPointer({pos.x + 1.0f, probe_y}).position;
    CHECK(mapped == (TextPosition{0, col}));
  }

  const PointF end_pos = layout.getPositionScreenCoord({0, 6});
  const TextPosition mapped_end = layout.hitTestPointer({end_pos.x + 4.0f, probe_y}).position;
  CHECK(mapped_end == (TextPosition{0, 6}));
}

TEST_CASE("TextLayout hitTest/getPositionScreenCoord stay consistent in wrap mode") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghij");
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
    const TextPosition mapped = layout.hitTestPointer({pos.x + 1.0f, probe_y}).position;
    CHECK(mapped == (TextPosition{0, col}));
  }
}

TEST_CASE("TextLayout preserves both caret sides at a soft wrap boundary") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghij");
  layout.loadDocument(document);
  layout.setViewport({90, 320});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::CHAR_BREAK);

  EditorRenderModel model;
  layout.layoutVisibleLines(model);

  const TextPosition boundary{0, 6};
  const PointF upstream = layout.getPositionScreenCoord(boundary, CaretAffinity::UPSTREAM);
  const PointF downstream = layout.getPositionScreenCoord(boundary, CaretAffinity::DOWNSTREAM);
  REQUIRE(downstream.y > upstream.y);

  const float line_height = layout.getLineHeight();
  const CaretHit upstream_hit = layout.hitTestPointer({upstream.x + 1.0f, upstream.y + line_height * 0.5f});
  const CaretHit downstream_hit = layout.hitTestPointer({downstream.x + 1.0f, downstream.y + line_height * 0.5f});

  CHECK(upstream_hit.position == boundary);
  CHECK(upstream_hit.affinity == CaretAffinity::UPSTREAM);
  CHECK(downstream_hit.position == boundary);
  CHECK(downstream_hit.affinity == CaretAffinity::DOWNSTREAM);
}

TEST_CASE("TextLayout hitTest snaps emoji modifier graphemes to left and right boundaries") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB"
                                                               "B");
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

  CHECK(layout.hitTestPointer({cluster_start.x + cluster_width * 0.25f, probe_y}).position == (TextPosition{0, 1}));
  CHECK(layout.hitTestPointer({cluster_start.x + cluster_width * 0.75f, probe_y}).position == (TextPosition{0, 5}));
}

TEST_CASE("TextLayout horizontal cropping preserves grapheme hit testing") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB"
                                                               "B");
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
  CHECK(cropped_text
        == "\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB"
           "B");
}

TEST_CASE("TextLayout wrap keeps emoji modifier grapheme on one visual line") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedGraphemeWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB"
                                                               "B");
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
  SharedPtr<TextMeasurer> measurer = makeShared<FixedGraphemeWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document =
      makeShared<LineArrayDocument>("\xF0\x9F\x92\x9D\xF0\x9F\x92\x97\xF0\x9F\x87\xA8\xF0\x9F\x87\xB3\xF0\x9F\x87\xB2"
                                    "\xF0\x9F\x87\xB4\xF0\x9F\x91\x8C\xF0\x9F\x8F\xBB");
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
  CHECK(collectVisualLineText(model.lines[0])
        == "\xF0\x9F\x87\xA8\xF0\x9F\x87\xB3\xF0\x9F\x87\xB2\xF0\x9F\x87\xB4\xF0\x9F\x91\x8C\xF0\x9F\x8F\xBB");
}

TEST_CASE("TextLayout getPositionScreenCoord skips CodeLens virtual line for line start") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);
  layout.getLayoutMetrics().fold_arrow_mode = FoldArrowMode::ALWAYS;

  Vector<CodeLensItem> items;
  items.push_back({0, 101, "3 references"});
  document->getDecorations().setLineCodeLens(0, std::move(items));

  const PointF line_start = layout.getPositionScreenCoord({0, 0});
  CHECK(line_start.y == Catch::Approx(layout.getLineHeight()));
}

TEST_CASE("TextLayout hitTestTextBoundary maps CodeLens virtual line to previous visible line end") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("alpha\nbeta");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  Vector<CodeLensItem> items;
  items.push_back({0, 101, "3 references"});
  document->getDecorations().setLineCodeLens(1, std::move(items));

  const PointF line_start = layout.getPositionScreenCoord({1, 0});
  const float probe_y = line_start.y - layout.getLineHeight() * 0.5f;
  const float probe_x = layout.getLayoutMetrics().textAreaX() + 20.0f;

  const CaretHit pointer = layout.hitTestPointer({probe_x, probe_y});
  CHECK_FALSE(pointer.hits_document_text);
  CHECK(pointer.position == (TextPosition{1, 0}));
  CHECK(layout.hitTestTextBoundary({probe_x, probe_y}).position == (TextPosition{0, 5}));
}

TEST_CASE("TextLayout hitTestDecoration returns unique command ids for CodeLens runs") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  Vector<CodeLensItem> items;
  items.push_back({1, 101, "3 references"});
  items.push_back({4, 202, "2 implementations"});
  document->getDecorations().setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& first = findNthCodeLensRun(codelens_line, 0);
  const VisualRun& second = findNthCodeLensRun(codelens_line, 1);
  const float codelens_y = layout.getPositionScreenCoord({0, 0}).y - layout.getLineHeight() * 0.5f;

  const HitTarget first_target = layout.hitTestDecoration({first.x + first.width * 0.5f, codelens_y});
  CHECK(first_target.type == HitTargetType::CODELENS);
  CHECK(first_target.line == 0);
  CHECK(first_target.column == 1);
  CHECK(first_target.icon_id == 101);

  const HitTarget second_target = layout.hitTestDecoration({second.x + second.width * 0.5f, codelens_y});
  CHECK(second_target.type == HitTargetType::CODELENS);
  CHECK(second_target.line == 0);
  CHECK(second_target.column == 4);
  CHECK(second_target.icon_id == 202);
}

TEST_CASE("TextLayout positions CodeLens runs by anchored columns") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghij");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  Vector<CodeLensItem> items;
  items.push_back({2, 101, "refs"});
  items.push_back({7, 202, "impl"});
  document->getDecorations().setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& first = findNthCodeLensRun(codelens_line, 0);
  const VisualRun& second = findNthCodeLensRun(codelens_line, 1);
  const float text_area_x = layout.getLayoutMetrics().textAreaX();
  const float sep_width = 30.0f; // FixedWidthTextMeasurer(10) and " | "

  CHECK(first.x == Catch::Approx(text_area_x + 20.0f));
  CHECK(second.x >= text_area_x + 70.0f);
  CHECK(second.x >= first.x + first.width + sep_width);
}

TEST_CASE("TextLayout hitTestDecoration resolves LINK target by canonical start column") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("prefixLinkSuffix");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  Vector<LinkSpan> links;
  links.push_back({6, 4, "doc://link"});
  document->getDecorations().setLineLinks(0, std::move(links));

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  REQUIRE_FALSE(model.lines.empty());
  const VisualLine& content_line = model.lines.front();
  const VisualRun& link_run = findFirstRunOfType(content_line, VisualRunType::LINK);

  const HitTarget target = layout.hitTestDecoration({link_run.x + link_run.width * 0.5f, link_run.y});
  CHECK(target.type == HitTargetType::LINK);
  CHECK(target.line == 0);
  CHECK(target.column == 6);
  CHECK(document->getDecorations().findLinkAt(target.line, target.column) != nullptr);
  CHECK(document->getDecorations().findLinkAt(target.line, target.column)->target == "doc://link");
}

TEST_CASE("TextLayout maps collapsed fold tail runs to their source line") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("if {\n  body\n}");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);

  Vector<FoldRegion> folds;
  folds.push_back({0, 2, true});
  document->getDecorations().setFoldRegions(std::move(folds));

  auto& lines = document->getLogicalLines();
  lines[1].is_fold_hidden = true;
  lines[2].is_fold_hidden = true;
  lines[0].is_layout_dirty = true;

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  REQUIRE_FALSE(model.lines.empty());

  const VisualLine& folded_line = model.lines.front();
  const auto tail_it = std::find_if(folded_line.runs.begin(), folded_line.runs.end(), [](const VisualRun& run) {
    return run.source_line == 2 && run.type == VisualRunType::TEXT;
  });
  REQUIRE(tail_it != folded_line.runs.end());

  const PointF tail_start = layout.getPositionScreenCoord({2, 0});
  const PointF tail_end = layout.getPositionScreenCoord({2, 1});
  CHECK(tail_start.x == Catch::Approx(tail_it->x));
  CHECK(tail_end.x == Catch::Approx(tail_it->x + tail_it->width));

  const float probe_y = layout.getPositionScreenCoord({0, 0}).y + layout.getLineHeight() * 0.5f;
  CHECK(layout.hitTestPointer({tail_it->x + 1.0f, probe_y}).position == (TextPosition{2, 0}));
  CHECK(layout.hitTestPointer({tail_it->x + tail_it->width * 0.75f, probe_y}).position == (TextPosition{2, 1}));
}

TEST_CASE("TextLayout gutter fold hit uses content line geometry when CodeLens exists") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("head\nbody");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);
  layout.getLayoutMetrics().fold_arrow_mode = FoldArrowMode::ALWAYS;

  Vector<CodeLensItem> items;
  items.push_back({0, 101, "3 references"});
  document->getDecorations().setLineCodeLens(0, std::move(items));
  Vector<FoldRegion> folds;
  folds.push_back({0, 1, false});
  document->getDecorations().setFoldRegions(std::move(folds));

  const float line_height = layout.getLineHeight();
  const LayoutMetrics& metrics = layout.getLayoutMetrics();
  const float content_top = layout.getPositionScreenCoord({0, 0}).y;
  const float fold_width = metrics.foldArrowAreaWidth();
  REQUIRE(fold_width > 0.0f);

  const float fold_x = metrics.gutterWidth() - metrics.line_number_margin - fold_width * 0.5f;
  const float fold_y = content_top + line_height * 0.5f;
  const HitTarget target = layout.hitTestDecoration({fold_x, fold_y});

  CHECK(target.type == HitTargetType::FOLD_GUTTER);
  CHECK(target.line == 0);
}

TEST_CASE("TextLayout gutter icon hit uses content line geometry when CodeLens exists") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  TextLayout layout(measurer, text_styles);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("head");
  layout.loadDocument(document);
  layout.setViewport({320, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});
  layout.setWrapMode(WrapMode::NONE);
  layout.getLayoutMetrics().max_gutter_icons = 0;

  Vector<CodeLensItem> items;
  items.push_back({0, 101, "3 references"});
  document->getDecorations().setLineCodeLens(0, std::move(items));
  Vector<GutterIcon> icons;
  icons.push_back({77});
  document->getDecorations().setLineGutterIcons(0, std::move(icons));

  const float line_height = layout.getLineHeight();
  const LayoutMetrics& metrics = layout.getLayoutMetrics();
  const float content_top = layout.getPositionScreenCoord({0, 0}).y;
  const float icon_x = metrics.line_number_margin + metrics.font_height * 0.5f;
  const float icon_y = content_top + line_height * 0.5f;
  const HitTarget target = layout.hitTestDecoration({icon_x, icon_y});

  CHECK(target.type == HitTargetType::GUTTER_ICON);
  CHECK(target.line == 0);
  CHECK(target.icon_id == 77);
}
