#include <catch2/catch_amalgamated.hpp>
#include "interaction.h"
#include "layout.h"
#include "decoration.h"
#include "document.h"
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

  void primeLayout(TextLayout& layout) {
    EditorRenderModel model;
    layout.layoutVisibleLines(model, PresentationContext {});
  }
}

TEST_CASE("EditorInteraction track tap jumps vertical scrollbar position") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(80, "abcdefghij"));
  TextLayout layout(measurer, decorations);
  layout.loadDocument(document);

  Viewport viewport {120.0f, 80.0f};
  ViewState view_state {};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.track_tap_mode = ScrollbarTrackTapMode::JUMP;
  CaretState caret {};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig {};
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
  GestureIntent intent;
  const GestureResult result = interaction.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, point), intent);

  CHECK(result.type == GestureType::SCROLL);
  CHECK(view_state.scroll_y > 0.0f);
}

TEST_CASE("EditorInteraction thumb drag updates vertical scroll offset") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  SharedPtr<DecorationManager> decorations = makeShared<DecorationManager>();
  SharedPtr<Document> document = makeShared<LineArrayDocument>(makeLines(120, "abcdefghijklmnop"));
  TextLayout layout(measurer, decorations);
  layout.loadDocument(document);

  Viewport viewport {120.0f, 80.0f};
  ViewState view_state {};
  EditorSettings settings;
  settings.scrollbar.mode = ScrollbarMode::ALWAYS;
  settings.scrollbar.thumb_draggable = true;
  CaretState caret {};

  layout.setViewport(viewport);
  layout.setViewState(view_state);
  primeLayout(layout);

  InteractionContext context;
  context.touch_config = TouchConfig {};
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

  const float down_point[2] = {
      vertical.thumb.origin.x + vertical.thumb.width * 0.5f,
      vertical.thumb.origin.y + vertical.thumb.height * 0.5f
  };
  GestureIntent intent;
  const GestureResult down = interaction.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_DOWN, 1, down_point), intent);
  CHECK(down.type == GestureType::UNDEFINED);

  const float move_point[2] = {
      down_point[0],
      down_point[1] + 20.0f
  };
  const GestureResult move = interaction.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_MOVE, 1, move_point), intent);
  CHECK(move.type == GestureType::SCROLL);
  CHECK(view_state.scroll_y > 0.0f);

  const GestureResult up = interaction.handleGestureEvent(
      GestureEvent::create(EventType::MOUSE_UP, 1, move_point), intent);
  CHECK(up.type == GestureType::UNDEFINED);
}
