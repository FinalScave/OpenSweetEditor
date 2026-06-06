#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/document.h>
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

namespace {
  EditorCore makeSearchEditor(const U8String& text) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>(text));
    editor.setViewport({500, 240});
    return editor;
  }
}

TEST_CASE("EditorCore search finds literal matches and navigates current match") {
  EditorCore editor = makeSearchEditor("one two one\nthree one");

  SearchRequest request;
  request.pattern = "one";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 3);
  CHECK(state.current_index == 0);
  CHECK(state.current_range == (TextRange{{0, 0}, {0, 3}}));

  EditorActionResult next = editor.findNextSearchMatch();
  CHECK(next.handled);
  state = editor.getSearchState();
  CHECK(state.current_index == 1);
  CHECK(editor.getSelection() == (TextRange{{0, 8}, {0, 11}}));

  EditorActionResult previous = editor.findPreviousSearchMatch();
  CHECK(previous.handled);
  state = editor.getSearchState();
  CHECK(state.current_index == 0);
}

TEST_CASE("EditorCore search whole word uses shared word classification") {
  EditorCore editor = makeSearchEditor("cat concatenate cat_1 猫 猫眼 dog猫 cat");

  SearchRequest request;
  request.pattern = "cat";
  request.options.whole_word = true;
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 2);
  CHECK(state.current_range == (TextRange{{0, 0}, {0, 3}}));

  request.pattern = "猫";
  editor.search(request);

  state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 1);
}

TEST_CASE("EditorCore search supports regex captures in replace all") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("foo1 foo2");
  editor.loadDocument(document);
  editor.setViewport({500, 240});

  SearchRequest request;
  request.pattern = "foo([0-9])";
  request.options.use_regex = true;
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 2);

  EditorActionResult replace = editor.replaceAllSearchMatches("bar$1");
  CHECK(replace.handled);
  CHECK(replace.content_changed);
  CHECK(document->getU8Text() == "bar1 bar2");

  editor.undo();
  CHECK(document->getU8Text() == "foo1 foo2");
}

TEST_CASE("EditorCore search supports newline patterns") {
  EditorCore editor = makeSearchEditor("alpha\nbeta");

  SearchRequest literal_request;
  literal_request.pattern = "\n";
  editor.search(literal_request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 1);
  CHECK(state.current_range == (TextRange{{0, 5}, {1, 0}}));

  SearchRequest escaped_literal_request;
  escaped_literal_request.pattern = "\\n";
  editor.search(escaped_literal_request);
  state = editor.getSearchState();
  CHECK(state.match_count == 0);

  SearchRequest regex_request;
  regex_request.pattern = "\\n";
  regex_request.options.use_regex = true;
  editor.search(regex_request);

  state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  CHECK(state.match_count == 1);
  CHECK(state.current_range == (TextRange{{0, 5}, {1, 0}}));
}

TEST_CASE("EditorCore clear search clears only the current search selection") {
  EditorCore editor = makeSearchEditor("one two one");

  SearchRequest request;
  request.pattern = "one";
  editor.search(request);
  editor.findNextSearchMatch();
  REQUIRE(editor.hasSelection());
  REQUIRE(editor.getSelection() == (TextRange{{0, 8}, {0, 11}}));

  EditorActionResult clear = editor.clearSearch();
  CHECK(clear.handled);
  CHECK(clear.selection_changed);
  CHECK_FALSE(editor.hasSelection());

  editor.search(request);
  editor.findNextSearchMatch();
  editor.setSelection({{0, 4}, {0, 7}});

  clear = editor.clearSearch();
  CHECK(clear.handled);
  CHECK_FALSE(clear.selection_changed);
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 4}, {0, 7}}));
}

TEST_CASE("EditorCore search marks highlights stale after document edit") {
  EditorCore editor = makeSearchEditor("alpha beta alpha");

  SearchRequest request;
  request.pattern = "alpha";
  editor.search(request);
  REQUIRE(editor.getSearchState().match_count == 2);

  editor.insertText("x");
  SearchState state = editor.getSearchState();
  CHECK(state.status == SearchStatus::STALE);
  CHECK(state.match_count == 0);
  CHECK_FALSE(state.has_current_match);
}

TEST_CASE("EditorCore search reports invalid regex failures") {
  EditorCore editor = makeSearchEditor("abc");

  SearchRequest request;
  request.pattern = "(";
  request.options.use_regex = true;
  editor.search(request);

  SearchState state = editor.getSearchState();
  CHECK(state.status == SearchStatus::FAILED);
  CHECK(state.match_count == 0);
  CHECK_FALSE(state.error_message.empty());
}

TEST_CASE("EditorCore search renders matches projected into folded tail") {
  EditorCore editor = makeSearchEditor("head {\ninside\n} tail");
  EditorRangeEffectStyles styles;
  styles.search_current.background_color = static_cast<int32_t>(0x55FFAA00u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setFoldRegions({{0, 2, true}});

  SearchRequest request;
  request.pattern = "tail";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  REQUIRE(state.match_count == 1);
  CHECK(state.current_range == (TextRange{{2, 2}, {2, 6}}));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  CHECK_FALSE(rangeEffectsOfKind(model, RangeEffectKind::SEARCH_CURRENT).empty());
}
