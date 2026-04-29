#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {
  U8String makeLines(size_t line_count, const U8String& line_text) {
    U8String out;
    for (size_t i = 0; i < line_count; ++i) {
      if (i > 0) out += "\n";
      out += line_text;
    }
    return out;
  }
}

TEST_CASE("EditorCore setScroll is clamped by computed scroll bounds") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(30, "0123456789abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({120, 80});
  EditorRenderModel model;
  editor.buildRenderModel(model);

  editor.setScroll(10000, 10000);
  ScrollMetrics metrics = editor.getScrollMetrics();

  CHECK(metrics.scroll_x == metrics.max_scroll_x);
  CHECK(metrics.scroll_y == metrics.max_scroll_y);
  CHECK(metrics.can_scroll_x);
  CHECK(metrics.can_scroll_y);
}

TEST_CASE("EditorCore wrap mode disables horizontal scrolling and zeroes scroll_x") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghijklmnopqrstuvwxyz");
  editor.loadDocument(document);
  editor.setViewport({120, 80});

  EditorRenderModel model2;
  editor.buildRenderModel(model2);
  editor.setScroll(200, 0);
  ScrollMetrics nowrap = editor.getScrollMetrics();
  REQUIRE(nowrap.max_scroll_x > 0);
  REQUIRE(nowrap.scroll_x > 0);

  editor.setWrapMode(WrapMode::CHAR_BREAK);
  ScrollMetrics wrapped = editor.getScrollMetrics();
  CHECK(wrapped.max_scroll_x == 0.0f);
  CHECK(wrapped.scroll_x == 0.0f);
  CHECK_FALSE(wrapped.can_scroll_x);
}

TEST_CASE("EditorCore viewport change re-clamps existing scroll offset") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(60, "abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({140, 100});

  EditorRenderModel model3;
  editor.buildRenderModel(model3);
  editor.setScroll(0, 10000);
  ScrollMetrics before = editor.getScrollMetrics();
  REQUIRE(before.max_scroll_y > 0);
  REQUIRE(before.scroll_y == before.max_scroll_y);

  editor.setViewport({140, 480});
  ScrollMetrics after = editor.getScrollMetrics();
  CHECK(after.max_scroll_y < before.max_scroll_y);
  CHECK(after.scroll_y == after.max_scroll_y);
}

TEST_CASE("EditorCore selectAll keeps scroll stable when reveal_selection_end_on_select_all is disabled") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(80, "abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({120, 80});

  EditorRenderModel model;
  editor.buildRenderModel(model);
  ScrollMetrics before = editor.getScrollMetrics();

  editor.selectAll();
  ScrollMetrics after = editor.getScrollMetrics();

  CHECK(after.scroll_y == before.scroll_y);
  CHECK(after.scroll_y == 0.0f);
}

TEST_CASE("EditorCore selectAll reveals selection end when reveal_selection_end_on_select_all is enabled") {
  EditorOptions options;
  options.reveal_selection_end_on_select_all = true;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(80, "abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({120, 80});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  editor.selectAll();
  ScrollMetrics after = editor.getScrollMetrics();
  CursorRect cursor_rect = editor.getCursorScreenRect();

  REQUIRE(after.max_scroll_y > 0.0f);
  CHECK(after.scroll_y > 0.0f);
  CHECK(cursor_rect.y >= 0.0f);
  CHECK(cursor_rect.y + cursor_rect.height <= 80.0f);
}
