#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <string>
#include <thread>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore buildRenderModel resolves default text foreground in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("plain"));
  editor.setViewport({320, 120});

  EditorRenderColors colors;
  colors.text_foreground = static_cast<int32_t>(0xFF112233u);
  editor.setEditorRenderColors(colors);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE(model.lines.size() == 1);
  const VisualRun& text_run = findFirstRunOfType(model.lines.front(), VisualRunType::TEXT);
  CHECK(text_run.style.color == colors.text_foreground);
}

TEST_CASE("EditorCore buildRenderModel resolves role foregrounds in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abc link"));
  editor.setViewport({420, 160});

  constexpr int32_t syntax_color = static_cast<int32_t>(0xFF010203u);
  constexpr int32_t link_color = static_cast<int32_t>(0xFF445566u);
  constexpr int32_t active_link_color = static_cast<int32_t>(0xFF778899u);
  constexpr int32_t codelens_color = static_cast<int32_t>(0xFFABCDEFu);
  constexpr int32_t active_codelens_color = static_cast<int32_t>(0xFF13579Bu);

  EditorRenderColors colors;
  colors.text_foreground = static_cast<int32_t>(0xFF202020u);
  colors.link_foreground = link_color;
  colors.active_link_foreground = active_link_color;
  colors.codelens_foreground = codelens_color;
  colors.active_codelens_foreground = active_codelens_color;
  editor.setEditorRenderColors(colors);

  editor.registerTextStyle(1, TextStyle{syntax_color, 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, Vector<StyleSpan>{{4, 4, 1}});
  editor.setLineLinks(0, Vector<LinkSpan>{{4, 4, "doc://link"}});
  editor.setLineCodeLens(0, Vector<CodeLensItem>{{4, 101, "1 reference"}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  auto link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(link_runs.size() == 1);
  CHECK(link_runs.front()->style.color == link_color);

  const VisualLine& codelens_line = findCodeLensVisualLine(model, 0);
  const VisualRun& codelens_run = findNthCodeLensRun(codelens_line, 0);
  CHECK(codelens_run.style.color == codelens_color);

  const float hover_point[2] = {
      link_runs.front()->x + link_runs.front()->width * 0.5f,
      link_runs.front()->y
  };
  editor.handleGestureEvent(GestureEvent::createWithModifiers(EventType::MOUSE_MOVE, 1, hover_point, KeyModifier::CTRL));

  model = {};
  editor.buildRenderModel(model);
  link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(link_runs.size() == 1);
  CHECK(link_runs.front()->style.color == active_link_color);
}

TEST_CASE("EditorCore handleGestureEvent tap on CodeLens keeps cursor unchanged") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({400, 160});
  editor.setCursorPosition({0, 3});
  Vector<CodeLensItem> items;
  items.push_back({2, 101, "3 references"});
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
  items.push_back({1, 101, "3 references"});
  items.push_back({4, 202, "2 implementations"});
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
  items.push_back({1, 101, "3 references"});
  items.push_back({4, 202, "2 implementations"});
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
  items.push_back({1, 101, "3 references"});
  items.push_back({4, 202, "2 implementations"});
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

  const EditorActionResult down = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, first_press));
  CHECK(down.handled);

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

  const EditorActionResult cancel_down = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, first_press));
  REQUIRE(cancel_down.handled);
  const EditorActionResult cancel = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_CANCEL, 0, nullptr));
  CHECK(cancel.handled);
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
  items.push_back({1, 101, "3 references"});
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

TEST_CASE("EditorCore schedules transient scrollbar fade through animation flags") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  ScrollbarConfig scrollbar;
  scrollbar.mode = ScrollbarMode::TRANSIENT;
  scrollbar.thumb_draggable = true;
  scrollbar.fade_delay_ms = 100;
  scrollbar.fade_duration_ms = 200;
  editor.setScrollbarConfig(scrollbar);

  std::string text;
  for (int i = 0; i < 80; ++i) {
    text += "abcdefghij\n";
  }
  editor.loadDocument(makeShared<LineArrayDocument>(text));
  editor.setViewport({240, 80});

  GestureEvent wheel;
  wheel.type = EventType::MOUSE_WHEEL;
  wheel.wheel_delta_y = -24.0f;
  const EditorActionResult started = editor.handleGestureEvent(wheel);

  REQUIRE(started.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));
  CHECK(started.next_animation_delay_ms == 0);
  CHECK(started.needs_redraw);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE(model.vertical_scrollbar.visible);
  const float scrollbar_point[2] = {
      model.vertical_scrollbar.thumb.origin.x + model.vertical_scrollbar.thumb.width * 0.5f,
      model.vertical_scrollbar.thumb.origin.y + model.vertical_scrollbar.thumb.height * 0.5f
  };
  const EditorActionResult scrollbar_down = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, scrollbar_point));
  CHECK(scrollbar_down.gesture_type == GestureType::UNDEFINED);
  CHECK(scrollbar_down.handled);

  const EditorActionResult scrollbar_up = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_UP, 1, scrollbar_point));
  CHECK(scrollbar_up.gesture_type == GestureType::UNDEFINED);
  CHECK(scrollbar_up.handled);

  const float hover_point[2] = {40.0f, 40.0f};
  const EditorActionResult passive_hover = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_point));
  REQUIRE(passive_hover.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));
  CHECK(passive_hover.gesture_type == GestureType::UNDEFINED);
  CHECK_FALSE(passive_hover.handled);

  const EditorActionResult unchanged_modifiers =
      editor.updatePointerModifiers(KeyModifier::NONE);
  REQUIRE(unchanged_modifiers.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));
  CHECK_FALSE(unchanged_modifiers.handled);

  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  const EditorActionResult holding = editor.tickAnimations();
  REQUIRE(holding.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));
  CHECK(holding.next_animation_delay_ms > 0);
  CHECK_FALSE(holding.needs_redraw);
  CHECK_FALSE(holding.handled);

  std::this_thread::sleep_for(
      std::chrono::milliseconds(holding.next_animation_delay_ms + 50));
  const EditorActionResult fading = editor.tickAnimations();
  REQUIRE(fading.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));
  CHECK(fading.next_animation_delay_ms == 0);
  CHECK(fading.needs_redraw);
  CHECK_FALSE(fading.handled);

  std::this_thread::sleep_for(std::chrono::milliseconds(170));
  const EditorActionResult finished = editor.tickAnimations();
  CHECK(finished.animation_flags == 0);
  CHECK(finished.next_animation_delay_ms == 0);
  CHECK(finished.needs_redraw);
  CHECK_FALSE(finished.handled);

  model = {};
  editor.buildRenderModel(model);
  CHECK_FALSE(model.vertical_scrollbar.visible);
  CHECK_FALSE(model.horizontal_scrollbar.visible);

  const EditorActionResult settled = editor.tickAnimations();
  CHECK(settled.animation_flags == 0);
  CHECK_FALSE(settled.needs_redraw);
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

TEST_CASE("EditorCore updatePointerModifiers refreshes hovered LINK presentation") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("plain link tail"));
  editor.setViewport({300, 160});
  Vector<LinkSpan> links;
  links.push_back({6, 4, "doc://link"});
  editor.setLineLinks(0, std::move(links));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  auto link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(link_runs.size() == 1);
  const float hover_point[2] = {
      link_runs.front()->x + link_runs.front()->width * 0.5f,
      link_runs.front()->y
  };

  const EditorActionResult plain_hover = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, hover_point));
  CHECK(plain_hover.pointer_cursor_after == PointerCursorType::TEXT);

  const EditorActionResult ctrl_refresh = editor.updatePointerModifiers(KeyModifier::CTRL);
  CHECK(ctrl_refresh.needs_redraw);
  CHECK(ctrl_refresh.pointer_cursor_changed);
  CHECK(ctrl_refresh.pointer_cursor_after == PointerCursorType::HAND);

  model = {};
  editor.buildRenderModel(model);
  auto active_link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(active_link_runs.size() == 1);
  CHECK(active_link_runs.front()->active);

  const EditorActionResult clear_refresh = editor.updatePointerModifiers(KeyModifier::NONE);
  CHECK(clear_refresh.needs_redraw);
  CHECK(clear_refresh.pointer_cursor_changed);
  CHECK(clear_refresh.pointer_cursor_after == PointerCursorType::TEXT);

  model = {};
  editor.buildRenderModel(model);
  auto inactive_link_runs = findRunsOfType(model, 0, VisualRunType::LINK);
  REQUIRE(inactive_link_runs.size() == 1);
  CHECK_FALSE(inactive_link_runs.front()->active);
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
  items.push_back({0, 101, "3 references"});
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

  CHECK(down.handled);
  CHECK(down.is_handle_drag);
  CHECK(down.has_selection_after);
  CHECK(down.selection_after == (TextRange{{1, 0}, {1, 4}}));

  editor.setViewport({440, 200});
  const float move_point[2] = {
      model.selection_end_handle.position.x + 12.0f,
      codelens_mid_y + 4.0f
  };
  const EditorActionResult move = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, move_point));

  CHECK(move.is_handle_drag);
  CHECK(move.has_selection_after);
  CHECK(move.selection_after == (TextRange{{0, 5}, {1, 0}}));

  const EditorActionResult up = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_UP, 1, move_point));
  CHECK(up.handled);
  CHECK_FALSE(up.is_handle_drag);
}
