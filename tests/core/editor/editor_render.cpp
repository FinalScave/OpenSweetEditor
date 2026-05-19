#include <catch2/catch_amalgamated.hpp>
#include <string>
#include "editor_core.h"
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore buildRenderModel exposes normalized selection handles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({320, 120});
  editor.setSelection({{0, 5}, {0, 2}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE_FALSE(model.selection_rects.empty());
  CHECK_FALSE(model.cursor.visible);
  CHECK(model.selection_start_handle.visible);
  CHECK(model.selection_end_handle.visible);
  CHECK(model.selection_start_handle.position.x <= model.selection_end_handle.position.x);
}

TEST_CASE("EditorCore buildRenderModel exposes active composition decoration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("ab"));
  editor.setViewport({320, 120});
  editor.setCursorPosition({0, 1});
  editor.updateImePreedit("xy", ImeScriptClass::LATIN);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE(model.composition_decoration.active);
  CHECK(model.composition_decoration.rect.width > 0.0f);
  CHECK(model.composition_decoration.rect.height > 0.0f);
  CHECK(model.composition_decoration.rect.origin.x == Catch::Approx(editor.getPositionScreenRect({0, 1}).x));
}

TEST_CASE("EditorCore buildRenderModel emits linked editing rectangles for snippet tab stops") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>(""));
  editor.setViewport({320, 120});
  REQUIRE(editor.insertSnippet("${1:foo}-${2:bar}-$0").content_changed);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE(model.linked_editing_rects.size() == 2);
  size_t active_count = 0;
  size_t inactive_count = 0;
  for (const auto& rect : model.linked_editing_rects) {
    CHECK(rect.rect.width > 0.0f);
    CHECK(rect.rect.height > 0.0f);
    if (rect.is_active) active_count++;
    else inactive_count++;
  }
  CHECK(active_count == 1);
  CHECK(inactive_count == 1);
}

TEST_CASE("EditorCore buildRenderModel uses external bracket match positions when provided") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("a(b)c"));
  editor.setViewport({320, 120});
  editor.setMatchedBrackets({0, 1}, {0, 3});

  EditorRenderModel matched_model;
  editor.buildRenderModel(matched_model);

  REQUIRE(matched_model.bracket_highlight_rects.size() == 2);
  for (const auto& rect : matched_model.bracket_highlight_rects) {
    CHECK(rect.width > 0.0f);
    CHECK(rect.height > 0.0f);
  }

  editor.clearMatchedBrackets();
  EditorRenderModel cleared_model;
  editor.buildRenderModel(cleared_model);
  CHECK(cleared_model.bracket_highlight_rects.empty());
}

TEST_CASE("EditorCore handleGestureEvent tap on CodeLens keeps cursor unchanged") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({400, 160});
  editor.setCursorPosition({0, 3});
  Vector<CodeLensItem> items;
  items.push_back({2, "3 references", 101});
  editor.setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& codelens_run = findNthCodeLensRun(codelens_line, 0);
  const float point[2] = {
      codelens_run.x + codelens_run.width * 0.5f,
      codelens_run.y
  };

  const EditorActionResult result = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, point));

  CHECK(result.hit_target.type == HitTargetType::CODELENS);
  CHECK(result.hit_target.column == 2);
  CHECK(result.hit_target.icon_id == 101);
  CHECK(result.cursor_after == (TextPosition{0, 3}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore buildRenderModel activates only hovered CodeLens run") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({480, 160});
  Vector<CodeLensItem> items;
  items.push_back({1, "3 references", 101});
  items.push_back({4, "2 implementations", 202});
  editor.setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const VisualLine& initial_codelens = findCodeLensVisualLine(model, 0);
  const VisualRun& first_initial = findNthCodeLensRun(initial_codelens, 0);
  const VisualRun& second_initial = findNthCodeLensRun(initial_codelens, 1);
  CHECK_FALSE(first_initial.active);
  CHECK_FALSE(second_initial.active);

  const float hover_first[2] = {
      first_initial.x + first_initial.width * 0.5f,
      first_initial.y
  };
  editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_first));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& after_first_hover = findCodeLensVisualLine(model, 0);
  CHECK(findNthCodeLensRun(after_first_hover, 0).active);
  CHECK_FALSE(findNthCodeLensRun(after_first_hover, 1).active);

  const VisualRun& second_hover_target = findNthCodeLensRun(after_first_hover, 1);
  const float hover_second[2] = {
      second_hover_target.x + second_hover_target.width * 0.5f,
      second_hover_target.y
  };
  editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_second));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& after_second_hover = findCodeLensVisualLine(model, 0);
  CHECK_FALSE(findNthCodeLensRun(after_second_hover, 0).active);
  CHECK(findNthCodeLensRun(after_second_hover, 1).active);

  const float hover_exit[2] = {-1.0f, -1.0f};
  editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_exit));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& after_hover_exit = findCodeLensVisualLine(model, 0);
  CHECK_FALSE(findNthCodeLensRun(after_hover_exit, 0).active);
  CHECK_FALSE(findNthCodeLensRun(after_hover_exit, 1).active);
}

TEST_CASE("EditorCore buildRenderModel keeps CodeLens active while mouse is pressed") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({480, 160});
  Vector<CodeLensItem> items;
  items.push_back({1, "3 references", 101});
  items.push_back({4, "2 implementations", 202});
  editor.setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& first = findNthCodeLensRun(codelens_line, 0);
  const float press_point[2] = {
      first.x + first.width * 0.5f,
      first.y
  };

  editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, press_point));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& pressed_model = findCodeLensVisualLine(model, 0);
  CHECK(findNthCodeLensRun(pressed_model, 0).active);
  CHECK_FALSE(findNthCodeLensRun(pressed_model, 1).active);

  editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_UP, 1, press_point));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& released_model = findCodeLensVisualLine(model, 0);
  CHECK_FALSE(findNthCodeLensRun(released_model, 0).active);
  CHECK_FALSE(findNthCodeLensRun(released_model, 1).active);
}

TEST_CASE("EditorCore buildRenderModel clears pressed CodeLens when touch moves away") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({480, 160});
  Vector<CodeLensItem> items;
  items.push_back({1, "3 references", 101});
  items.push_back({4, "2 implementations", 202});
  editor.setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& first = findNthCodeLensRun(codelens_line, 0);
  const VisualRun& second = findNthCodeLensRun(codelens_line, 1);
  const float first_press[2] = {
      first.x + first.width * 0.5f,
      first.y
  };
  const float move_out[2] = {
      second.x + second.width * 0.5f,
      second.y
  };

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, first_press));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& pressed_model = findCodeLensVisualLine(model, 0);
  CHECK(findNthCodeLensRun(pressed_model, 0).active);
  CHECK_FALSE(findNthCodeLensRun(pressed_model, 1).active);

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_MOVE, 1, move_out));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& moved_model = findCodeLensVisualLine(model, 0);
  CHECK_FALSE(findNthCodeLensRun(moved_model, 0).active);
  CHECK_FALSE(findNthCodeLensRun(moved_model, 1).active);

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, move_out));

  model = {};
  editor.buildRenderModel(model);
  const VisualLine& released_model = findCodeLensVisualLine(model, 0);
  CHECK_FALSE(findNthCodeLensRun(released_model, 0).active);
  CHECK_FALSE(findNthCodeLensRun(released_model, 1).active);
}

TEST_CASE("EditorCore exposes pointer cursor type for text, CodeLens, gutter and scrollbar") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  ScrollbarConfig scrollbar;
  scrollbar.mode = ScrollbarMode::ALWAYS;
  editor.setScrollbarConfig(scrollbar);

  std::string text;
  for (int i = 0; i < 20; ++i) {
    text += "abcdef\n";
  }

  editor.loadDocument(makeShared<LineArrayDocument>(text));
  editor.setViewport({480, 160});
  Vector<CodeLensItem> items;
  items.push_back({1, "3 references", 101});
  editor.setLineCodeLens(0, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  CHECK(model.pointer_cursor_type == PointerCursorType::TEXT);
  REQUIRE(model.vertical_scrollbar.visible);

  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& codelens_run = findNthCodeLensRun(codelens_line, 0);
  const float code_lens_point[2] = {
      codelens_run.x + codelens_run.width * 0.5f,
      codelens_run.y
  };
  const EditorActionResult hover_codelens = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, code_lens_point));
  CHECK(hover_codelens.pointer_cursor_after == PointerCursorType::HAND);

  model = {};
  editor.buildRenderModel(model);
  CHECK(model.pointer_cursor_type == PointerCursorType::HAND);

  const CursorRect text_rect = editor.getPositionScreenRect({0, 2});
  const float text_point[2] = {
      text_rect.x + 1.0f,
      text_rect.y + text_rect.height * 0.5f
  };
  const EditorActionResult hover_text = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, text_point));
  CHECK(hover_text.pointer_cursor_after == PointerCursorType::TEXT);

  model = {};
  editor.buildRenderModel(model);
  CHECK(model.pointer_cursor_type == PointerCursorType::TEXT);

  const float gutter_point[2] = {
      1.0f,
      text_rect.y + text_rect.height * 0.5f
  };
  const EditorActionResult hover_gutter = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, gutter_point));
  CHECK(hover_gutter.pointer_cursor_after == PointerCursorType::DEFAULT);

  model = {};
  editor.buildRenderModel(model);
  CHECK(model.pointer_cursor_type == PointerCursorType::DEFAULT);

  const float scrollbar_point[2] = {
      model.vertical_scrollbar.track.origin.x + model.vertical_scrollbar.track.width * 0.5f,
      model.vertical_scrollbar.track.origin.y + model.vertical_scrollbar.track.height * 0.5f
  };
  const EditorActionResult hover_scrollbar = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, scrollbar_point));
  CHECK(hover_scrollbar.pointer_cursor_after == PointerCursorType::DEFAULT);

  model = {};
  editor.buildRenderModel(model);
  CHECK(model.pointer_cursor_type == PointerCursorType::DEFAULT);
}

TEST_CASE("EditorCore handleGestureEvent ctrl-tap on LINK resolves target and places cursor at tap") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("prefixLinkSuffix"));
  editor.setViewport({420, 160});
  editor.setCursorPosition({0, 2});
  Vector<LinkSpan> links;
  links.push_back({6, 4, "doc://link"});
  editor.setLineLinks(0, std::move(links));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const auto link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(link_runs.size() == 1);
  const float point[2] = {
      link_runs.front()->x + link_runs.front()->width * 0.5f,
      link_runs.front()->y
  };

  const EditorActionResult result = editor.handleGestureEvent(
      GestureEvent::createWithModifiers(EventType::MOUSE_DOWN, 1, point, KeyModifier::CTRL));

  CHECK(result.hit_target.type == HitTargetType::LINK);
  CHECK(result.hit_target.line == 0);
  CHECK(result.hit_target.column == 6);
  CHECK(editor.getLinkTargetAt(result.hit_target.line, result.hit_target.column) == "doc://link");
  CHECK(result.cursor_after == editor.getCursorPosition());
  CHECK(result.cursor_after.line == 0);
  CHECK(result.cursor_after.column >= 6);
  CHECK(result.cursor_after.column <= 10);
}

TEST_CASE("EditorCore buildRenderModel activates wrapped LINK runs together with ctrl hover") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abLongWrappedLinkTail"));
  editor.setViewport({95, 220});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  Vector<LinkSpan> links;
  links.push_back({2, 15, "doc://wrapped"});
  editor.setLineLinks(0, std::move(links));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  auto initial_link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(initial_link_runs.size() >= 2);
  for (const VisualRun* run : initial_link_runs) {
    CHECK_FALSE(run->active);
  }

  const VisualRun* hover_target = initial_link_runs.back();
  const float hover_point[2] = {
      hover_target->x + hover_target->width * 0.5f,
      hover_target->y
  };
  const EditorActionResult plain_hover = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_point));
  CHECK(plain_hover.pointer_cursor_after == PointerCursorType::TEXT);

  model = {};
  editor.buildRenderModel(model);
  auto inactive_link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(inactive_link_runs.size() >= 2);
  for (const VisualRun* run : inactive_link_runs) {
    CHECK_FALSE(run->active);
  }

  const EditorActionResult hover = editor.handleGestureEvent(
      GestureEvent::createWithModifiers(EventType::MOUSE_MOVE, 1, hover_point, KeyModifier::CTRL));
  CHECK(hover.pointer_cursor_after == PointerCursorType::HAND);

  model = {};
  editor.buildRenderModel(model);
  auto active_link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(active_link_runs.size() >= 2);
  for (const VisualRun* run : active_link_runs) {
    CHECK(run->active);
  }
}

TEST_CASE("EditorCore long press inside selection keeps existing selection") {
  EditorOptions options;
  options.long_press_ms = -1;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({420, 160});
  editor.setSelection({{0, 1}, {0, 4}});

  const CursorRect inside_rect = editor.getPositionScreenRect({0, 2});
  const float point[2] = {
      inside_rect.x + 1.0f,
      inside_rect.y + inside_rect.height * 0.5f
  };

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  const EditorActionResult result = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, point));

  REQUIRE(result.gesture_type == GestureType::LONG_PRESS);
  CHECK(result.has_selection_after);
  CHECK(result.selection_after == (TextRange{{0, 1}, {0, 4}}));
  CHECK(result.cursor_after == (TextPosition{0, 4}));
  CHECK(editor.getSelection() == (TextRange{{0, 1}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore long press outside selection places cursor and clears selection") {
  EditorOptions options;
  options.long_press_ms = -1;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({420, 160});
  editor.setSelection({{0, 1}, {0, 4}});

  const CursorRect outside_rect = editor.getPositionScreenRect({0, 5});
  const float point[2] = {
      outside_rect.x + 1.0f,
      outside_rect.y + outside_rect.height * 0.5f
  };

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  const EditorActionResult result = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, point));

  REQUIRE(result.gesture_type == GestureType::LONG_PRESS);
  CHECK_FALSE(result.has_selection_after);
  CHECK(result.cursor_after == (TextPosition{0, 5}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
  CHECK_FALSE(editor.hasSelection());
}

TEST_CASE("EditorCore line-start word selection end handle can cross CodeLens virtual line") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("alpha\nbeta"));
  editor.setViewport({420, 200});
  editor.setSelection({{1, 0}, {1, 4}});
  Vector<CodeLensItem> items;
  items.push_back({0, "3 references", 101});
  editor.setLineCodeLens(1, std::move(items));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE(model.selection_end_handle.visible);
  const VisualLine& codelens_line = findCodeLensVisualLine(model, 1);
  const float codelens_mid_y = codelens_line.line_number_position.y + model.selection_end_handle.height * 0.5f;

  const float down_point[2] = {
      model.selection_end_handle.position.x + 12.0f,
      model.selection_end_handle.position.y + model.selection_end_handle.height + 12.0f
  };
  const EditorActionResult down = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, down_point));

  CHECK(down.is_handle_drag);
  CHECK(down.has_selection_after);
  CHECK(down.selection_after == (TextRange{{1, 0}, {1, 4}}));

  const float move_point[2] = {
      model.selection_end_handle.position.x + 12.0f,
      codelens_mid_y + 4.0f
  };
  const EditorActionResult move = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, move_point));

  CHECK(move.is_handle_drag);
  CHECK(move.has_selection_after);
  CHECK(move.selection_after == (TextRange{{0, 5}, {1, 0}}));
}
