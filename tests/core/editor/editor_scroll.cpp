#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <thread>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"
#include "test_text_helpers.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore clamps programmatic and gesture scale to the supported range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>(makeRepeatedLines(4, "0123456789")));
  editor.setViewport({120, 80});

  editor.setScale(0.1f);
  CHECK(editor.getScrollMetrics().scale == Catch::Approx(0.75f));

  editor.setScale(10.0f);
  CHECK(editor.getScrollMetrics().scale == Catch::Approx(5.0f));

  editor.setScale(1.0f);
  GestureEvent direct_scale;
  direct_scale.type = EventType::DIRECT_SCALE;
  direct_scale.points.push_back({20.0f, 20.0f});
  direct_scale.direct_scale = 0.1f;
  editor.handleGestureEvent(direct_scale);
  CHECK(editor.getScrollMetrics().scale == Catch::Approx(0.75f));
}

TEST_CASE("EditorCore setScroll is clamped by computed scroll bounds") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(30, "0123456789abcdefghij"));
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

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(60, "abcdefghij"));
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

TEST_CASE("EditorCore viewport resize cancels stale scrollbar capture") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  ScrollbarConfig scrollbar;
  scrollbar.mode = ScrollbarMode::ALWAYS;
  scrollbar.thumb_draggable = true;
  editor.setScrollbarConfig(scrollbar);
  editor.loadDocument(
      makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop")));
  editor.setViewport({120, 80});

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE(model.vertical_scrollbar.visible);
  const float down_point[2] = {
      model.vertical_scrollbar.thumb.origin.x
          + model.vertical_scrollbar.thumb.width * 0.5f,
      model.vertical_scrollbar.thumb.origin.y
          + model.vertical_scrollbar.thumb.height * 0.5f
  };
  const EditorActionResult down = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, down_point));
  REQUIRE(down.handled);
  CHECK(down.hasInteractionFlag(InteractionFlag::PRIMARY_POINTER));
  CHECK(down.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  editor.setViewport({120, 80});
  const float first_move[2] = {down_point[0], down_point[1] + 10.0f};
  const EditorActionResult first_move_result = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, first_move));
  REQUIRE(first_move_result.gesture_type == GestureType::SCROLL);
  const float scroll_after_first_move = first_move_result.scroll_y_after;
  REQUIRE(scroll_after_first_move > 0.0f);

  editor.setViewport({200, 80});
  const float second_move[2] = {down_point[0], down_point[1] + 30.0f};
  const EditorActionResult second_move_result = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, second_move));
  CHECK(second_move_result.gesture_type == GestureType::UNDEFINED);
  CHECK(second_move_result.scroll_y_after == scroll_after_first_move);
  CHECK_FALSE(second_move_result.hasActiveInteraction());
}

TEST_CASE("EditorCore scrollbar config change cancels stale scrollbar capture") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  ScrollbarConfig scrollbar;
  scrollbar.mode = ScrollbarMode::ALWAYS;
  scrollbar.thumb_draggable = true;
  editor.setScrollbarConfig(scrollbar);
  editor.loadDocument(
      makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop")));
  editor.setViewport({120, 80});

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE(model.vertical_scrollbar.visible);
  const float down_point[2] = {
      model.vertical_scrollbar.thumb.origin.x
          + model.vertical_scrollbar.thumb.width * 0.5f,
      model.vertical_scrollbar.thumb.origin.y
          + model.vertical_scrollbar.thumb.height * 0.5f
  };
  const EditorActionResult down = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, down_point));
  REQUIRE(down.handled);
  CHECK(down.hasInteractionFlag(InteractionFlag::PRIMARY_POINTER));
  CHECK(down.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  editor.setScrollbarConfig(scrollbar);
  const float first_move[2] = {down_point[0], down_point[1] + 10.0f};
  const EditorActionResult first_move_result = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, first_move));
  REQUIRE(first_move_result.gesture_type == GestureType::SCROLL);
  const float scroll_after_first_move = first_move_result.scroll_y_after;
  REQUIRE(scroll_after_first_move > 0.0f);

  scrollbar.mode = ScrollbarMode::NEVER;
  const EditorActionResult disabled = editor.setScrollbarConfig(scrollbar);
  CHECK(disabled.animation_flags == 0);
  CHECK_FALSE(disabled.hasActiveInteraction());
  const float second_move[2] = {down_point[0], down_point[1] + 30.0f};
  const EditorActionResult second_move_result = editor.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, second_move));
  CHECK(second_move_result.gesture_type == GestureType::UNDEFINED);
  CHECK(second_move_result.scroll_y_after == scroll_after_first_move);
}

TEST_CASE("EditorCore invalid viewport clears interaction animations") {
  EditorOptions options;
  options.fling_min_velocity = 1.0f;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  ScrollbarConfig scrollbar;
  scrollbar.mode = ScrollbarMode::TRANSIENT;
  scrollbar.fade_delay_ms = 1000;
  scrollbar.fade_duration_ms = 1000;
  editor.setScrollbarConfig(scrollbar);
  editor.loadDocument(
      makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop")));
  editor.setViewport({120, 80});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const float down_point[2] = {40.0f, 60.0f};
  const float first_move[2] = {40.0f, 40.0f};
  const float second_move[2] = {40.0f, 20.0f};
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, down_point));
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, first_move));
  std::this_thread::sleep_for(std::chrono::milliseconds(5));
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, second_move));
  const EditorActionResult fling = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_UP, 1, second_move));
  REQUIRE(fling.hasAnimationFlag(AnimationFlag::FLING));
  REQUIRE(fling.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));

  const EditorActionResult resized = editor.setViewport({160, 80});
  CHECK(resized.hasAnimationFlag(AnimationFlag::FLING));
  CHECK(resized.hasAnimationFlag(AnimationFlag::TRANSIENT_SCROLLBAR));

  const EditorActionResult invalid = editor.setViewport({0, 0});
  CHECK(invalid.animation_flags == 0);
  CHECK(invalid.next_animation_delay_ms == 0);

  const EditorActionResult restored = editor.setViewport({120, 80});
  CHECK(restored.animation_flags == 0);
  const EditorActionResult settled = editor.tickAnimations();
  CHECK(settled.animation_flags == 0);
}

TEST_CASE("EditorCore reports pointer and viewport interaction lifecycles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(
      makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop")));
  editor.setViewport({120, 80});

  const float down_point[2] = {40.0f, 60.0f};
  const float move_point[2] = {40.0f, 20.0f};
  const EditorActionResult down = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, down_point));
  CHECK(down.hasInteractionFlag(InteractionFlag::PRIMARY_POINTER));
  CHECK_FALSE(down.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  const EditorActionResult move = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, move_point));
  CHECK(move.hasInteractionFlag(InteractionFlag::PRIMARY_POINTER));
  CHECK(move.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  const EditorActionResult up = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_UP, 1, move_point));
  CHECK_FALSE(up.hasActiveInteraction());
}

TEST_CASE("EditorCore direct gesture begins by stopping an active fling") {
  EditorOptions options;
  options.fling_min_velocity = 1.0f;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(
      makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop")));
  editor.setViewport({120, 80});

  const float down_point[2] = {40.0f, 60.0f};
  const float first_move[2] = {40.0f, 40.0f};
  const float second_move[2] = {40.0f, 20.0f};
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_DOWN, 1, down_point));
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, first_move));
  std::this_thread::sleep_for(std::chrono::milliseconds(5));
  editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_MOVE, 1, second_move));
  const EditorActionResult fling = editor.handleGestureEvent(
      GestureEvent::create(EventType::TOUCH_UP, 1, second_move));
  REQUIRE(fling.hasAnimationFlag(AnimationFlag::FLING));

  GestureEvent begin;
  begin.type = EventType::DIRECT_GESTURE_BEGIN;
  const EditorActionResult direct = editor.handleGestureEvent(begin);
  CHECK(direct.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));
  CHECK_FALSE(direct.hasAnimationFlag(AnimationFlag::FLING));

  GestureEvent end;
  end.type = EventType::DIRECT_GESTURE_END;
  const EditorActionResult settled = editor.handleGestureEvent(end);
  CHECK_FALSE(settled.hasActiveInteraction());
  CHECK_FALSE(settled.hasAnimationFlag(AnimationFlag::FLING));
}

TEST_CASE("EditorCore keeps overlapping direct gesture sessions active until the final end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>(makeRepeatedLines(30, "abcdefghij")));
  editor.setViewport({120, 80});

  GestureEvent begin;
  begin.type = EventType::DIRECT_GESTURE_BEGIN;
  const EditorActionResult first_begin = editor.handleGestureEvent(begin);
  CHECK(first_begin.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  const EditorActionResult second_begin = editor.handleGestureEvent(begin);
  CHECK(second_begin.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  GestureEvent end;
  end.type = EventType::DIRECT_GESTURE_END;
  const EditorActionResult first_end = editor.handleGestureEvent(end);
  CHECK(first_end.hasInteractionFlag(InteractionFlag::VIEWPORT_GESTURE));

  const EditorActionResult second_end = editor.handleGestureEvent(end);
  CHECK_FALSE(second_end.hasActiveInteraction());
}

TEST_CASE("EditorCore ignores unmatched direct gesture end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>(makeRepeatedLines(30, "abcdefghij")));
  editor.setViewport({120, 80});
  editor.setScroll(0.0f, 12.5f);
  const ScrollMetrics before = editor.getScrollMetrics();

  GestureEvent end;
  end.type = EventType::DIRECT_GESTURE_END;
  const EditorActionResult result = editor.handleGestureEvent(end);
  const ScrollMetrics after = editor.getScrollMetrics();

  CHECK(result.handled);
  CHECK_FALSE(result.hasActiveInteraction());
  CHECK(after.scroll_y == before.scroll_y);
  CHECK_FALSE(result.scroll_changed);
}

TEST_CASE("EditorCore selectAll keeps scroll stable when reveal_selection_end_on_select_all is disabled") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(80, "abcdefghij"));
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

  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(80, "abcdefghij"));
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
