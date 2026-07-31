#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <thread>
#include <sweeteditor/interaction.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/decoration.h>
#include <sweeteditor/document.h>
#include "test_measurer.h"
#include "test_text_helpers.h"

using namespace NS_SWEETEDITOR;

namespace {
  void primeLayout(TextLayout& layout) {
    EditorRenderModel model;
    layout.layoutVisibleLines(model);
  }
}

TEST_CASE("EditorInteraction track tap jumps vertical scrollbar position") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(80, "abcdefghij"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.track_tap_mode = ScrollbarTrackTapMode::JUMP;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);

  const float tap_x = vertical.track.origin.x + vertical.track.width * 0.5f;
  const float tap_y = std::min(vertical.track.origin.y + vertical.track.height - 2.0f,
                               vertical.thumb.origin.y + vertical.thumb.height + 12.0f);
  const float point[2] = {tap_x, tap_y};
  const InteractionResult result =
      interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point));

  CHECK(result.gesture.type == GestureType::SCROLL);
  CHECK(result.handled);
  CHECK(view_state.scroll_y > 0.0f);
}

TEST_CASE("EditorInteraction thumb drag updates vertical scroll offset") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.thumb_draggable = true;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);
  REQUIRE(vertical.thumb.height > 0.0f);

  const float down_point[2] = {vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
                               vertical.thumb.origin.y + vertical.thumb.height * 0.5f};
  const InteractionResult down =
      interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, down_point));
  CHECK(down.gesture.type == GestureType::UNDEFINED);
  CHECK(down.handled);
  CHECK(down.needs_redraw);

  const float move_point[2] = {down_point[0], down_point[1] + 20.0f};
  const InteractionResult move =
      interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_MOVE, 1, move_point));
  CHECK(move.gesture.type == GestureType::SCROLL);
  CHECK(move.handled);
  CHECK(view_state.scroll_y > 0.0f);

  const InteractionResult up = interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_UP, 1, move_point));
  CHECK(up.gesture.type == GestureType::UNDEFINED);
  CHECK(up.handled);
  CHECK(up.needs_redraw);
}

TEST_CASE("EditorInteraction scrollbar capture stops active fling") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.thumb_draggable = true;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.touch_config.fling_min_velocity = 1.0f;
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  const float down_point[2] = {40.0f, 60.0f};
  const float first_move[2] = {40.0f, 40.0f};
  const float second_move[2] = {40.0f, 20.0f};
  interaction.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, down_point));
  interaction.handleGestureEvent(GestureEvent::create(EventType::TOUCH_MOVE, 1, first_move));
  std::this_thread::sleep_for(std::chrono::milliseconds(5));
  interaction.handleGestureEvent(GestureEvent::create(EventType::TOUCH_MOVE, 1, second_move));
  interaction.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, second_move));

  REQUIRE((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::FLING)) != 0);

  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);
  const float thumb_point[2] = {vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
                                vertical.thumb.origin.y + vertical.thumb.height * 0.5f};

  const InteractionResult scrollbar_down =
      interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, thumb_point));

  CHECK(scrollbar_down.handled);
  CHECK((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::FLING)) == 0);
}

TEST_CASE("EditorInteraction releases scrollbar capture when viewport becomes invalid") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.thumb_draggable = true;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);
  const float point[2] = {vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
                          vertical.thumb.origin.y + vertical.thumb.height * 0.5f};

  REQUIRE(interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point)).handled);

  viewport = {};
  const InteractionResult up = interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_UP, 1, point));
  CHECK(up.handled);
  CHECK(up.needs_redraw);

  viewport = {120.0f, 80.0f};
  const InteractionResult passive_move =
      interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_MOVE, 1, point));
  CHECK_FALSE(passive_move.handled);
}

TEST_CASE("EditorInteraction restarts transient scrollbar hold after thumb release") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::TRANSIENT;
  settings.scrollbar.thumb_draggable = true;
  settings.scrollbar.fade_delay_ms = 20;
  settings.scrollbar.fade_duration_ms = 20;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  interaction.markScrollbarInteraction();
  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);

  const float point[2] = {vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
                          vertical.thumb.origin.y + vertical.thumb.height * 0.5f};
  interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point));
  std::this_thread::sleep_for(std::chrono::milliseconds(45));

  const InteractionResult up = interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_UP, 1, point));
  const InteractionAnimationState schedule = interaction.resolveAnimationState();

  CHECK(up.needs_redraw);
  CHECK((schedule.flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) != 0);
  CHECK(schedule.next_tick_delay_ms > 0);
}

TEST_CASE("EditorInteraction keeps transient scrollbar fully visible after quick thumb release") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::TRANSIENT;
  settings.scrollbar.thumb_draggable = true;
  settings.scrollbar.fade_delay_ms = 500;
  settings.scrollbar.fade_duration_ms = 1000;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  interaction.markScrollbarInteraction();
  ScrollbarModel vertical;
  ScrollbarModel horizontal;
  interaction.computeScrollbarModels(vertical, horizontal);
  REQUIRE(vertical.visible);
  REQUIRE(vertical.alpha < 1.0f);

  const float point[2] = {vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
                          vertical.thumb.origin.y + vertical.thumb.height * 0.5f};
  const InteractionResult down = interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point));
  REQUIRE(down.handled);
  REQUIRE(down.needs_redraw);

  interaction.computeScrollbarModels(vertical, horizontal);
  CHECK(vertical.alpha == Catch::Approx(1.0f));

  const InteractionResult up = interaction.handleGestureEvent(GestureEvent::create(EventType::MOUSE_UP, 1, point));
  REQUIRE(up.handled);
  REQUIRE(up.needs_redraw);

  interaction.computeScrollbarModels(vertical, horizontal);
  CHECK(vertical.alpha == Catch::Approx(1.0f));

  const InteractionAnimationState schedule = interaction.resolveAnimationState();
  CHECK((schedule.flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) != 0);
  CHECK(schedule.next_tick_delay_ms > 0);
}

TEST_CASE("EditorInteraction clears transient scrollbar state when animation becomes ineligible") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  SharedPtr<Document> long_document = makeShared<LineArrayDocument>(makeRepeatedLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, text_styles);
  layout.loadDocument(long_document);

  Size viewport{120.0f, 80.0f};
  ViewState view_state{};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::TRANSIENT;
  settings.scrollbar.fade_delay_ms = 500;
  settings.scrollbar.fade_duration_ms = 1000;
  CaretState caret{};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig{};
  context.settings = &settings;
  context.view_state = &view_state;
  context.viewport = &viewport;
  context.text_layout = &layout;
  context.caret = &caret;
  EditorInteraction interaction(context);

  interaction.markScrollbarInteraction();
  REQUIRE((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) != 0);

  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  CHECK((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) == 0);

  settings.scrollbar.mode = ScrollbarMode::TRANSIENT;
  CHECK((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) == 0);

  interaction.markScrollbarInteraction();
  REQUIRE((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) != 0);

  layout.loadDocument(makeShared<LineArrayDocument>("short"));
  layout.setViewState(view_state);
  primeLayout(layout);
  CHECK((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) == 0);

  layout.loadDocument(long_document);
  layout.setViewState(view_state);
  primeLayout(layout);
  CHECK((interaction.resolveAnimationState().flags & static_cast<uint32_t>(AnimationFlag::TRANSIENT_SCROLLBAR)) == 0);
}
