#include <catch2/catch_amalgamated.hpp>
#include <cstring>
#include "macro.h"
#ifndef __stdcall
#define __stdcall
#endif
#include "c_api.h"
#include "utility.h"

using namespace NS_SWEETEDITOR;

namespace {
  float __stdcall measureTextWidth(const U16Char* text, int32_t /*font_style*/) {
    if (text == nullptr) return 0.0f;
    return static_cast<float>(U16String(text).size()) * 10.0f;
  }

  float __stdcall measureInlayHintWidth(const U16Char* text) {
    if (text == nullptr) return 0.0f;
    return static_cast<float>(U16String(text).size()) * 8.0f;
  }

  float __stdcall measureIconWidth(int32_t /*icon_id*/) {
    return 10.0f;
  }

  void __stdcall getFontMetrics(float* arr, size_t length) {
    if (arr == nullptr || length < 2) return;
    arr[0] = -8.0f;
    arr[1] = 2.0f;
  }

  text_measurer_t makeMeasurer() {
    text_measurer_t measurer {};
    measurer.measure_text_width = measureTextWidth;
    measurer.measure_inlay_hint_width = measureInlayHintWidth;
    measurer.measure_icon_width = measureIconWidth;
    measurer.get_font_metrics = getFontMetrics;
    return measurer;
  }

  U8String toUtf8(const U16Char* u16) {
    if (u16 == nullptr) return "";
    U8String out;
    StrUtil::convertUTF16ToUTF8(U16String(u16), out);
    return out;
  }

  U8String getLineTextUtf8(intptr_t document_handle, size_t line) {
    const U16Char* u16 = get_document_line_text(document_handle, line);
    U8String out = toUtf8(u16);
    if (u16 != nullptr) {
      free_u16_string(reinterpret_cast<intptr_t>(u16));
    }
    return out;
  }

  struct ScrollMetricsData {
    float scale = 1.0f;
    float scroll_x = 0.0f;
    float scroll_y = 0.0f;
    float max_scroll_x = 0.0f;
    float max_scroll_y = 0.0f;
    float content_width = 0.0f;
    float content_height = 0.0f;
    float viewport_width = 0.0f;
    float viewport_height = 0.0f;
    float text_area_x = 0.0f;
    float text_area_width = 0.0f;
    int32_t can_scroll_x = 0;
    int32_t can_scroll_y = 0;
  };

  ScrollMetricsData parseScrollMetrics(const uint8_t* data, size_t size) {
    ScrollMetricsData metrics;
    if (data == nullptr || size < sizeof(float) * 11 + sizeof(int32_t) * 2) {
      return metrics;
    }
    size_t offset = 0;
    auto readFloat = [&](float& out) {
      std::memcpy(&out, data + offset, sizeof(float));
      offset += sizeof(float);
    };
    auto readI32 = [&](int32_t& out) {
      std::memcpy(&out, data + offset, sizeof(int32_t));
      offset += sizeof(int32_t);
    };
    readFloat(metrics.scale);
    readFloat(metrics.scroll_x);
    readFloat(metrics.scroll_y);
    readFloat(metrics.max_scroll_x);
    readFloat(metrics.max_scroll_y);
    readFloat(metrics.content_width);
    readFloat(metrics.content_height);
    readFloat(metrics.viewport_width);
    readFloat(metrics.viewport_height);
    readFloat(metrics.text_area_x);
    readFloat(metrics.text_area_width);
    readI32(metrics.can_scroll_x);
    readI32(metrics.can_scroll_y);
    return metrics;
  }

  struct LayoutMetricsData {
    float font_height = 0.0f;
    float font_ascent = 0.0f;
    float line_spacing_add = 0.0f;
    float line_spacing_mult = 1.0f;
    float line_number_margin = 0.0f;
    float line_number_width = 0.0f;
    int32_t max_gutter_icons = 0;
    float inlay_hint_padding = 0.0f;
    float inlay_hint_margin = 0.0f;
    int32_t fold_arrow_mode = 0;
    int32_t has_fold_regions = 0;
  };

  LayoutMetricsData parseLayoutMetrics(const uint8_t* data, size_t size) {
    LayoutMetricsData metrics;
    if (data == nullptr || size < sizeof(float) * 8 + sizeof(int32_t) * 3) {
      return metrics;
    }
    size_t offset = 0;
    auto readFloat = [&](float& out) {
      std::memcpy(&out, data + offset, sizeof(float));
      offset += sizeof(float);
    };
    auto readI32 = [&](int32_t& out) {
      std::memcpy(&out, data + offset, sizeof(int32_t));
      offset += sizeof(int32_t);
    };
    readFloat(metrics.font_height);
    readFloat(metrics.font_ascent);
    readFloat(metrics.line_spacing_add);
    readFloat(metrics.line_spacing_mult);
    readFloat(metrics.line_number_margin);
    readFloat(metrics.line_number_width);
    readI32(metrics.max_gutter_icons);
    readFloat(metrics.inlay_hint_padding);
    readFloat(metrics.inlay_hint_margin);
    readI32(metrics.fold_arrow_mode);
    readI32(metrics.has_fold_regions);
    return metrics;
  }

  struct GesturePayloadData {
    int32_t type = 0;
    float view_scale = 1.0f;
  };

  GesturePayloadData parseGesturePayload(const uint8_t* data, size_t size) {
    GesturePayloadData payload;
    if (data == nullptr || size < sizeof(int32_t)) {
      return payload;
    }
    size_t offset = 0;
    auto readI32 = [&](int32_t& out) -> bool {
      if (offset + sizeof(int32_t) > size) return false;
      std::memcpy(&out, data + offset, sizeof(int32_t));
      offset += sizeof(int32_t);
      return true;
    };
    auto readF32 = [&](float& out) -> bool {
      if (offset + sizeof(float) > size) return false;
      std::memcpy(&out, data + offset, sizeof(float));
      offset += sizeof(float);
      return true;
    };

    if (!readI32(payload.type)) return payload;
    // TAP / DOUBLE_TAP / LONG_PRESS / DRAG_SELECT / CONTEXT_MENU include an extra tap point
    if (payload.type == 1 || payload.type == 2 || payload.type == 3 || payload.type == 7 || payload.type == 8) {
      float ignore = 0;
      if (!readF32(ignore) || !readF32(ignore)) return payload;
    }
    // Skip cursor/selection/view_scroll
    int32_t ignore_i32 = 0;
    for (int i = 0; i < 7; i++) {
      if (!readI32(ignore_i32)) return payload;
    }
    float ignore_f32 = 0;
    if (!readF32(ignore_f32) || !readF32(ignore_f32)) return payload;
    readF32(payload.view_scale);
    return payload;
  }

  struct RenderModelHeaderData {
    float split_x = 0.0f;
    int32_t split_line_visible = 1;
    float scroll_x = 0.0f;
    float scroll_y = 0.0f;
    float viewport_width = 0.0f;
    float viewport_height = 0.0f;
    float current_line_x = 0.0f;
    float current_line_y = 0.0f;
    int32_t current_line_render_mode = 0;
    int32_t line_count = 0;
  };

  RenderModelHeaderData parseRenderModelHeader(const uint8_t* data, size_t size) {
    RenderModelHeaderData header;
    if (data == nullptr || size < sizeof(float) * 7 + sizeof(int32_t) * 3) {
      return header;
    }
    size_t offset = 0;
    auto readFloat = [&](float& out) {
      std::memcpy(&out, data + offset, sizeof(float));
      offset += sizeof(float);
    };
    auto readI32 = [&](int32_t& out) {
      std::memcpy(&out, data + offset, sizeof(int32_t));
      offset += sizeof(int32_t);
    };
    readFloat(header.split_x);
    readI32(header.split_line_visible);
    readFloat(header.scroll_x);
    readFloat(header.scroll_y);
    readFloat(header.viewport_width);
    readFloat(header.viewport_height);
    readFloat(header.current_line_x);
    readFloat(header.current_line_y);
    readI32(header.current_line_render_mode);
    readI32(header.line_count);
    return header;
  }
}

TEST_CASE("C API null handles return safe defaults") {
  CHECK(editor_can_undo(0) == 0);
  CHECK(editor_can_redo(0) == 0);
  CHECK(editor_is_composing(0) == 0);
  CHECK(editor_is_composition_enabled(0) == 0);
  CHECK(editor_is_line_visible(0, 0) == 1);

  size_t metrics_size = 0;
  const uint8_t* metrics_payload = editor_get_scroll_metrics(0, &metrics_size);
  REQUIRE(metrics_payload != nullptr);
  ScrollMetricsData metrics = parseScrollMetrics(metrics_payload, metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(metrics_payload));
  CHECK(metrics.scroll_x == 0.0f);
  CHECK(metrics.scroll_y == 0.0f);
  CHECK(metrics.max_scroll_x == 0.0f);
  CHECK(metrics.max_scroll_y == 0.0f);
  CHECK(metrics.can_scroll_x == 0);
  CHECK(metrics.can_scroll_y == 0);

  size_t no_change_size = 0;
  const uint8_t* no_change = editor_insert_text(0, "x", &no_change_size);
  CHECK(no_change == nullptr);
  CHECK(no_change_size == 0);

  editor_set_cursor_position(0, 0, 0);
  editor_set_selection(0, 0, 0, 0, 0);
  editor_composition_start(0);
  editor_composition_update(0, "a");
  editor_composition_cancel(0);
  editor_fold_all(0);
  editor_unfold_all(0);
  editor_set_scroll(0, 12.0f, 34.0f);
}

TEST_CASE("C API basic edit, composition and linked editing flow") {
  intptr_t document = create_document_from_utf16(CHAR16("abc"));
  REQUIRE(document != 0);
  REQUIRE(get_document_line_count(document) == 1);
  CHECK(getLineTextUtf8(document, 0) == "abc");

  intptr_t editor = create_editor(makeMeasurer(), nullptr, 0);
  REQUIRE(editor != 0);
  set_editor_document(editor, document);
  set_editor_viewport(editor, 100, 80);

  size_t scroll_metrics_size = 0;
  const uint8_t* scroll_metrics_payload = editor_get_scroll_metrics(editor, &scroll_metrics_size);
  REQUIRE(scroll_metrics_payload != nullptr);
  ScrollMetricsData scroll_metrics = parseScrollMetrics(scroll_metrics_payload, scroll_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(scroll_metrics_payload));
  CHECK(scroll_metrics.viewport_width == 100.0f);
  CHECK(scroll_metrics.viewport_height == 80.0f);
  CHECK(scroll_metrics.scroll_x == 0.0f);
  CHECK(scroll_metrics.scroll_y == 0.0f);

  size_t layout_metrics_size = 0;
  const uint8_t* layout_metrics_payload = get_layout_metrics(editor, &layout_metrics_size);
  REQUIRE(layout_metrics_payload != nullptr);
  CHECK(layout_metrics_size == sizeof(float) * 8 + sizeof(int32_t) * 3);
  LayoutMetricsData layout_metrics = parseLayoutMetrics(layout_metrics_payload, layout_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(layout_metrics_payload));
  CHECK(layout_metrics.font_height == Catch::Approx(10.0f));
  CHECK(layout_metrics.font_ascent == Catch::Approx(8.0f));
  CHECK(layout_metrics.line_spacing_add == Catch::Approx(0.0f));
  CHECK(layout_metrics.line_spacing_mult == Catch::Approx(1.0f));
  CHECK(layout_metrics.max_gutter_icons == 0);
  CHECK(layout_metrics.inlay_hint_padding == Catch::Approx(2.0f));
  CHECK(layout_metrics.inlay_hint_margin == Catch::Approx(1.0f));
  CHECK(layout_metrics.fold_arrow_mode == 0);
  CHECK(layout_metrics.has_fold_regions == 0);

  // Two-finger zoom: TOUCH_DOWN -> TOUCH_POINTER_DOWN -> TOUCH_MOVE (fingers move apart)
  float p0[2] = {100.0f, 100.0f};
  size_t gesture_size = 0;
  const uint8_t* gesture_payload = handle_editor_gesture_event(editor, 1, 1, p0, &gesture_size);
  REQUIRE(gesture_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));

  float p1[4] = {100.0f, 100.0f, 200.0f, 100.0f};
  gesture_payload = handle_editor_gesture_event(editor, 2, 2, p1, &gesture_size);
  REQUIRE(gesture_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));

  float p2[4] = {95.0f, 100.0f, 205.0f, 100.0f};
  gesture_payload = handle_editor_gesture_event(editor, 3, 2, p2, &gesture_size);
  REQUIRE(gesture_payload != nullptr);
  GesturePayloadData gesture = parseGesturePayload(gesture_payload, gesture_size);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));
  CHECK(gesture.type == 4); // SCALE
  CHECK(gesture.view_scale > 1.0f);

  size_t insert_size = 0;
  const uint8_t* insert_result = editor_insert_text(editor, "X", &insert_size);
  REQUIRE(insert_result != nullptr);
  CHECK(insert_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(insert_result));
  CHECK(getLineTextUtf8(document, 0) == "Xabc");

  editor_set_composition_enabled(editor, 1);
  editor_set_cursor_position(editor, 0, 4);
  editor_composition_start(editor);
  editor_composition_update(editor, "q");
  CHECK(editor_is_composing(editor) == 1);
  CHECK(getLineTextUtf8(document, 0) == "Xabcq");

  size_t comp_size = 0;
  const uint8_t* comp_result = editor_composition_end(editor, "z", &comp_size);
  REQUIRE(comp_result != nullptr);
  CHECK(comp_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(comp_result));
  CHECK(editor_is_composing(editor) == 0);
  CHECK(getLineTextUtf8(document, 0) == "Xabcz");

  editor_set_cursor_position(editor, 0, 5);
  size_t snippet_size = 0;
  const uint8_t* snippet_result = editor_insert_snippet(editor, "${1:a}-${1:a}-$0", &snippet_size);
  REQUIRE(snippet_result != nullptr);
  CHECK(snippet_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(snippet_result));
  CHECK(editor_is_in_linked_editing(editor) == 1);

  size_t linked_size = 0;
  const uint8_t* linked_change = editor_insert_text(editor, "bb", &linked_size);
  REQUIRE(linked_change != nullptr);
  CHECK(linked_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(linked_change));
  CHECK(getLineTextUtf8(document, 0) == "Xabczbb-bb-");

  editor_set_scroll(editor, 10000.0f, 10000.0f);
  scroll_metrics_payload = editor_get_scroll_metrics(editor, &scroll_metrics_size);
  REQUIRE(scroll_metrics_payload != nullptr);
  scroll_metrics = parseScrollMetrics(scroll_metrics_payload, scroll_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(scroll_metrics_payload));
  CHECK(scroll_metrics.scroll_x == scroll_metrics.max_scroll_x);
  CHECK(scroll_metrics.scroll_y == scroll_metrics.max_scroll_y);
  CHECK(scroll_metrics.can_scroll_x == 1);
  CHECK(scroll_metrics.can_scroll_y == 0);

  CHECK(editor_linked_editing_next(editor) == 1);
  CHECK(editor_linked_editing_next(editor) == 0);
  CHECK(editor_is_in_linked_editing(editor) == 0);

  size_t model_size = 0;
  const uint8_t* model_payload = build_editor_render_model(editor, &model_size);
  REQUIRE(model_payload != nullptr);
  CHECK(model_size >= sizeof(float) * 7 + sizeof(int32_t) * 3);
  RenderModelHeaderData model_header = parseRenderModelHeader(model_payload, model_size);
  free_binary_data(reinterpret_cast<intptr_t>(model_payload));
  CHECK(model_header.viewport_width == 100.0f);
  CHECK(model_header.viewport_height == 80.0f);
  CHECK(model_header.split_line_visible == 1);
  CHECK(model_header.current_line_render_mode == 0);
  CHECK(model_header.line_count >= 1);

  free_editor(editor);
  free_document(document);
}
