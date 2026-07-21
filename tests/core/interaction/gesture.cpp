#include <catch2/catch_amalgamated.hpp>
#include <chrono>
#include <thread>
#include <sweeteditor/editor_types.h>
#include <sweeteditor/gesture.h>

using namespace NS_SWEETEDITOR;

TEST_CASE("EventType helpers classify primary pointer events") {
  CHECK(isMousePointerEvent(EventType::MOUSE_DOWN));
  CHECK(isMousePointerEvent(EventType::MOUSE_WHEEL));
  CHECK_FALSE(isMousePointerEvent(EventType::TOUCH_DOWN));

  CHECK(isPrimaryPointerDown(EventType::TOUCH_DOWN));
  CHECK(isPrimaryPointerDown(EventType::MOUSE_DOWN));
  CHECK_FALSE(isPrimaryPointerDown(EventType::TOUCH_POINTER_DOWN));

  CHECK(isPrimaryPointerMove(EventType::TOUCH_MOVE));
  CHECK(isPrimaryPointerMove(EventType::MOUSE_MOVE));
  CHECK_FALSE(isPrimaryPointerMove(EventType::DIRECT_SCROLL));

  CHECK(isPrimaryPointerEnd(EventType::TOUCH_UP));
  CHECK(isPrimaryPointerEnd(EventType::MOUSE_UP));
  CHECK(isPrimaryPointerEnd(EventType::TOUCH_CANCEL));
  CHECK_FALSE(isPrimaryPointerEnd(EventType::TOUCH_POINTER_UP));
}

TEST_CASE("Interaction value types compare all fields") {
  HandleConfig handle;
  HandleConfig changed_handle = handle;
  CHECK(handle == changed_handle);
  changed_handle.end_hit_area.right += 1.0f;
  CHECK(handle != changed_handle);

  ScrollbarConfig scrollbar;
  ScrollbarConfig changed_scrollbar = scrollbar;
  CHECK(scrollbar == changed_scrollbar);
  changed_scrollbar.fade_duration_ms += 1;
  CHECK(scrollbar != changed_scrollbar);

  HitTarget target;
  target.type = HitTargetType::CODELENS;
  target.line = 3;
  target.column = 4;
  target.icon_id = 5;
  HitTarget changed_target = target;
  CHECK(target == changed_target);
  changed_target.icon_id += 1;
  CHECK(target != changed_target);
}

TEST_CASE("GestureHandler maps wheel modifiers to scale and horizontal scroll") {
  GestureHandler handler(TouchConfig{});

  GestureEvent zoom_event;
  zoom_event.type = EventType::MOUSE_WHEEL;
  zoom_event.modifiers = KeyModifier::CTRL;
  zoom_event.wheel_delta_y = 1.0f;

  const GestureResult zoom = handler.handleGestureEvent(zoom_event);
  REQUIRE(zoom.type == GestureType::SCALE);
  CHECK(zoom.scale == Catch::Approx(1.1f));

  GestureEvent shift_scroll_event;
  shift_scroll_event.type = EventType::MOUSE_WHEEL;
  shift_scroll_event.modifiers = KeyModifier::SHIFT;
  shift_scroll_event.wheel_delta_y = 24.0f;

  const GestureResult shift_scroll = handler.handleGestureEvent(shift_scroll_event);
  REQUIRE(shift_scroll.type == GestureType::SCROLL);
  CHECK(shift_scroll.scroll_x == Catch::Approx(-24.0f));
  CHECK(shift_scroll.scroll_y == Catch::Approx(0.0f));
}

TEST_CASE("GestureHandler recognizes touch double tap") {
  TouchConfig config;
  config.double_tap_timeout = 1000;
  GestureHandler handler(config);

  const float point[2] = {40.0f, 24.0f};

  handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  const GestureResult first_up = handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, point));
  REQUIRE(first_up.type == GestureType::TAP);

  handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  const GestureResult second_up = handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, point));
  CHECK(second_up.type == GestureType::DOUBLE_TAP);
}

TEST_CASE("GestureHandler recognizes long press and three-finger fast scroll") {
  TouchConfig config;
  config.long_press_ms = 1;
  GestureHandler handler(config);

  const float press_point[2] = {50.0f, 50.0f};
  handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, press_point));
  std::this_thread::sleep_for(std::chrono::milliseconds(4));

  const GestureResult long_press =
      handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_MOVE, 1, press_point));
  REQUIRE(long_press.type == GestureType::LONG_PRESS);

  handler.resetState();

  const float multi_down[6] = {10.0f, 10.0f, 30.0f, 10.0f, 50.0f, 10.0f};
  handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_POINTER_DOWN, 3, multi_down));

  const float multi_move[6] = {10.0f, 26.0f, 30.0f, 26.0f, 50.0f, 26.0f};
  const GestureResult fast_scroll =
      handler.handleGestureEvent(GestureEvent::create(EventType::TOUCH_MOVE, 3, multi_move));
  REQUIRE(fast_scroll.type == GestureType::FAST_SCROLL);
  CHECK(fast_scroll.scroll_y != Catch::Approx(0.0f));
}

TEST_CASE("FlingAnimator starts only above minimum velocity and advances with delta") {
  TouchConfig config;
  config.fling_min_velocity = 50.0f;
  config.fling_friction = 2.0f;
  FlingAnimator fling(config);

  SECTION("slow swipe does not start fling") {
    fling.recordSample({0.0f, 0.0f}, 0);
    fling.recordSample({0.0f, 1.0f}, 100);
    CHECK_FALSE(fling.start());
    CHECK_FALSE(fling.isActive());
  }

  SECTION("fast swipe starts and produces movement") {
    fling.resetSamples();
    fling.recordSample({0.0f, 0.0f}, 0);
    fling.recordSample({0.0f, 60.0f}, 16);
    fling.recordSample({0.0f, 120.0f}, 32);

    REQUIRE(fling.start());
    REQUIRE(fling.isActive());

    float dx = 0.0f;
    float dy = 0.0f;
    const bool active = fling.advance(dx, dy);
    CHECK(active);
    CHECK(dx == Catch::Approx(0.0f));
    CHECK(dy > 0.0f);
  }
}
