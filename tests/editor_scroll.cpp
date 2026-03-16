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
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>(10.0f));

  Ptr<Document> document = makePtr<LineArrayDocument>(makeLines(30, "0123456789abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({120, 80});

  editor.setScroll(10000, 10000);
  ScrollMetrics metrics = editor.getScrollMetrics();

  CHECK(metrics.scroll_x == metrics.max_scroll_x);
  CHECK(metrics.scroll_y == metrics.max_scroll_y);
  CHECK(metrics.can_scroll_x);
  CHECK(metrics.can_scroll_y);
}

TEST_CASE("EditorCore wrap mode disables horizontal scrolling and zeroes scroll_x") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>(10.0f));

  Ptr<Document> document = makePtr<LineArrayDocument>("abcdefghijklmnopqrstuvwxyz");
  editor.loadDocument(document);
  editor.setViewport({120, 80});

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
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>(10.0f));

  Ptr<Document> document = makePtr<LineArrayDocument>(makeLines(60, "abcdefghij"));
  editor.loadDocument(document);
  editor.setViewport({140, 100});

  editor.setScroll(0, 10000);
  ScrollMetrics before = editor.getScrollMetrics();
  REQUIRE(before.max_scroll_y > 0);
  REQUIRE(before.scroll_y == before.max_scroll_y);

  editor.setViewport({140, 480});
  ScrollMetrics after = editor.getScrollMetrics();
  CHECK(after.max_scroll_y < before.max_scroll_y);
  CHECK(after.scroll_y == after.max_scroll_y);
}
