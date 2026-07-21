#include <catch2/catch_amalgamated.hpp>
#include <cstring>
#include <sweeteditor/macro.h>
#ifndef __stdcall
#define __stdcall
#endif
#include <sweeteditor/c_api.h>
#include <sweeteditor/protocol_codec.h>
#include <sweeteditor/utility.h>

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
    const U16Char* u16 = get_document_line_utf16(document_handle, line);
    U8String out = toUtf8(u16);
    if (u16 != nullptr) {
      free_u16_string(reinterpret_cast<intptr_t>(u16));
    }
    return out;
  }

  const uint8_t* sendImeCommand(intptr_t editor_handle, uint64_t session_id,
                                ImeCommand command, size_t* out_size) {
    Vector<uint8_t> data = protocol::ProtocolWriter::encode(
        ImeCommandBatch {session_id, {std::move(command)}});
    return editor_ime_apply_commands(editor_handle, data.data(), data.size(), out_size);
  }

  ImeState beginCommandSession(intptr_t editor_handle) {
    size_t size = 0;
    const uint8_t* payload = editor_ime_begin_session(
        editor_handle,
        static_cast<int>(ImeMutationModel::COMMAND),
        &size);
    ImeState state;
    REQUIRE(payload != nullptr);
    protocol::ProtocolReader reader(payload, size);
    int32_t result_code = 0;
    REQUIRE(reader.readI32(result_code));
    state.result_code = static_cast<ImeResultCode>(result_code);
    REQUIRE(reader.readU64(state.session_id));
    REQUIRE(reader.readU64(state.state_revision));
    REQUIRE(reader.read(state.selection));
    REQUIRE(reader.read(state.composition_range));
    REQUIRE(reader.done());
    free_binary_data(reinterpret_cast<intptr_t>(payload));
    return state;
  }

  struct SizeData {
    float width = 0.0f;
    float height = 0.0f;
  };

  struct ScrollMetricsData {
    float scale = 1.0f;
    float scroll_x = 0.0f;
    float scroll_y = 0.0f;
    float max_scroll_x = 0.0f;
    float max_scroll_y = 0.0f;
    SizeData content_size;
    SizeData viewport_size;
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
    readFloat(metrics.content_size.width);
    readFloat(metrics.content_size.height);
    readFloat(metrics.viewport_size.width);
    readFloat(metrics.viewport_size.height);
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
    float content_start_padding = 0.0f;
    int32_t max_gutter_icons = 0;
    float inlay_hint_padding = 0.0f;
    float inlay_hint_margin = 0.0f;
    int32_t fold_arrow_mode = 0;
    int32_t has_fold_regions = 0;
    int32_t gutter_sticky = 0;
    int32_t gutter_visible = 0;
  };

  LayoutMetricsData parseLayoutMetrics(const uint8_t* data, size_t size) {
    LayoutMetricsData metrics;
    if (data == nullptr || size < sizeof(float) * 9 + sizeof(int32_t) * 5) {
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
    readFloat(metrics.content_start_padding);
    readI32(metrics.max_gutter_icons);
    readFloat(metrics.inlay_hint_padding);
    readFloat(metrics.inlay_hint_margin);
    readI32(metrics.fold_arrow_mode);
    readI32(metrics.has_fold_regions);
    readI32(metrics.gutter_sticky);
    readI32(metrics.gutter_visible);
    return metrics;
  }

  struct ActionPayloadData {
    int32_t handled = 0;
    int32_t source = 0;
    int32_t text_change_kind = 0;
    uint32_t animation_flags = 0;
    uint32_t next_animation_delay_ms = 0;
    int32_t gesture_type = 0;
    float view_scale = 1.0f;
  };

  ActionPayloadData parseActionPayload(const uint8_t* data, size_t size) {
    ActionPayloadData payload;
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
    auto readU32 = [&](uint32_t& out) -> bool {
      if (offset + sizeof(uint32_t) > size) return false;
      std::memcpy(&out, data + offset, sizeof(uint32_t));
      offset += sizeof(uint32_t);
      return true;
    };
    auto readF32 = [&](float& out) -> bool {
      if (offset + sizeof(float) > size) return false;
      std::memcpy(&out, data + offset, sizeof(float));
      offset += sizeof(float);
      return true;
    };

    int32_t ignore_i32 = 0;
    if (!readI32(payload.handled)) return payload;
    if (!readI32(ignore_i32)) return payload;
    if (!readI32(payload.source)) return payload;
    if (!readI32(payload.text_change_kind)) return payload;
    for (int i = 0; i < 8; ++i) {
      if (!readI32(ignore_i32)) return payload;
    }
    if (!readU32(payload.animation_flags)) return payload;
    if (!readU32(payload.next_animation_delay_ms)) return payload;
    if (!readI32(ignore_i32)) return payload;
    int32_t change_count = 0;
    if (!readI32(change_count)) return payload;
    for (int32_t i = 0; i < change_count; ++i) {
      for (int j = 0; j < 4; ++j) {
        if (!readI32(ignore_i32)) return payload;
      }
      int32_t text_len = 0;
      if (!readI32(text_len)) return payload;
      if (text_len < 0 || offset + static_cast<size_t>(text_len) > size) return payload;
      offset += static_cast<size_t>(text_len);
    }
    for (int i = 0; i < 14; ++i) {
      if (!readI32(ignore_i32)) return payload;
    }
    float ignore_f32 = 0;
    for (int i = 0; i < 5; ++i) {
      if (!readF32(ignore_f32)) return payload;
    }
    readF32(payload.view_scale);
    for (int i = 0; i < 19; ++i) {
      if (!readI32(ignore_i32)) return payload;
    }
    readI32(payload.gesture_type);
    return payload;
  }

  struct RenderModelHeaderData {
    float split_x = 0.0f;
    int32_t split_line_visible = 1;
    float scroll_x = 0.0f;
    float scroll_y = 0.0f;
    SizeData viewport_size;
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
    readFloat(header.viewport_size.width);
    readFloat(header.viewport_size.height);
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

  editor_set_cursor_position(0, 0, 0, &no_change_size);
  CHECK(no_change_size == 0);
  editor_set_selection(0, 0, 0, 0, 0, &no_change_size);
  CHECK(no_change_size == 0);
  size_t null_ime_size = 0;
  ImeCommand null_preedit;
  null_preedit.kind = ImeCommandKind::UPDATE_COMPOSITION;
  null_preedit.text = "a";
  const uint8_t* null_ime = sendImeCommand(0, 1, null_preedit, &null_ime_size);
  CHECK(null_ime == nullptr);
  CHECK(null_ime_size == 0);
  ImeCommand null_cancel;
  null_cancel.kind = ImeCommandKind::CANCEL_COMPOSITION;
  null_ime = sendImeCommand(0, 1, null_cancel, &null_ime_size);
  CHECK(null_ime == nullptr);
  CHECK(null_ime_size == 0);
  editor_fold_all(0, &no_change_size);
  CHECK(no_change_size == 0);
  editor_unfold_all(0, &no_change_size);
  CHECK(no_change_size == 0);
  editor_set_scroll(0, 12.0f, 34.0f, &no_change_size);
  CHECK(no_change_size == 0);
}

TEST_CASE("C API basic edit, composition and linked editing flow") {
  intptr_t document = create_document_from_utf16(CHAR16("abc"));
  REQUIRE(document != 0);
  REQUIRE(get_document_line_count(document) == 1);
  CHECK(getLineTextUtf8(document, 0) == "abc");

  intptr_t editor = create_editor(makeMeasurer(), nullptr, 0);
  REQUIRE(editor != 0);
  size_t action_size = 0;
  const uint8_t* action_payload = editor_set_document(editor, document, &action_size);
  REQUIRE(action_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
  action_payload = editor_set_viewport(editor, 100, 80, &action_size);
  REQUIRE(action_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));

  size_t scroll_metrics_size = 0;
  const uint8_t* scroll_metrics_payload = editor_get_scroll_metrics(editor, &scroll_metrics_size);
  REQUIRE(scroll_metrics_payload != nullptr);
  ScrollMetricsData scroll_metrics = parseScrollMetrics(scroll_metrics_payload, scroll_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(scroll_metrics_payload));
  CHECK(scroll_metrics.viewport_size.width == 100.0f);
  CHECK(scroll_metrics.viewport_size.height == 80.0f);
  CHECK(scroll_metrics.scroll_x == 0.0f);
  CHECK(scroll_metrics.scroll_y == 0.0f);

  size_t layout_metrics_size = 0;
  const uint8_t* layout_metrics_payload = editor_get_layout_metrics(editor, &layout_metrics_size);
  REQUIRE(layout_metrics_payload != nullptr);
  CHECK(layout_metrics_size == sizeof(float) * 9 + sizeof(int32_t) * 5);
  LayoutMetricsData layout_metrics = parseLayoutMetrics(layout_metrics_payload, layout_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(layout_metrics_payload));
  CHECK(layout_metrics.font_height == Catch::Approx(10.0f));
  CHECK(layout_metrics.font_ascent == Catch::Approx(8.0f));
  CHECK(layout_metrics.line_spacing_add == Catch::Approx(0.0f));
  CHECK(layout_metrics.line_spacing_mult == Catch::Approx(1.2f));
  CHECK(layout_metrics.content_start_padding == Catch::Approx(0.0f));
  CHECK(layout_metrics.max_gutter_icons == 0);
  CHECK(layout_metrics.inlay_hint_padding == Catch::Approx(2.0f));
  CHECK(layout_metrics.inlay_hint_margin == Catch::Approx(1.0f));
  CHECK(layout_metrics.fold_arrow_mode == 0);
  CHECK(layout_metrics.has_fold_regions == 0);
  CHECK(layout_metrics.gutter_sticky == 1);
  CHECK(layout_metrics.gutter_visible == 1);

  size_t gesture_size = 0;
  auto sendGesture = [&](EventType type, Vector<PointF> points) {
    GestureEvent event;
    event.type = type;
    event.points = std::move(points);
    event.direct_scale = 1.0f;
    Vector<uint8_t> data = protocol::ProtocolWriter::encode(event);
    return editor_handle_gesture_event(editor, data.data(), data.size(), &gesture_size);
  };

  // Two-finger zoom: TOUCH_DOWN -> TOUCH_POINTER_DOWN -> TOUCH_MOVE (fingers move apart)
  const uint8_t* gesture_payload = sendGesture(EventType::TOUCH_DOWN, {{100.0f, 100.0f}});
  REQUIRE(gesture_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));

  gesture_payload = sendGesture(EventType::TOUCH_POINTER_DOWN, {{100.0f, 100.0f}, {200.0f, 100.0f}});
  REQUIRE(gesture_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));

  gesture_payload = sendGesture(EventType::TOUCH_MOVE, {{95.0f, 100.0f}, {205.0f, 100.0f}});
  REQUIRE(gesture_payload != nullptr);
  ActionPayloadData gesture = parseActionPayload(gesture_payload, gesture_size);
  free_binary_data(reinterpret_cast<intptr_t>(gesture_payload));
  CHECK(gesture.source == static_cast<int32_t>(EditorActionSource::GESTURE));
  CHECK(gesture.text_change_kind == static_cast<int32_t>(TextChangeKind::NONE));
  CHECK(gesture.gesture_type == 4);
  CHECK(gesture.view_scale > 1.0f);

  size_t insert_size = 0;
  const uint8_t* insert_result = editor_insert_text(editor, "X", &insert_size);
  REQUIRE(insert_result != nullptr);
  CHECK(insert_size > 0);
  ActionPayloadData insert_action = parseActionPayload(insert_result, insert_size);
  CHECK(insert_action.source == static_cast<int32_t>(EditorActionSource::PROGRAMMATIC));
  CHECK(insert_action.text_change_kind == static_cast<int32_t>(TextChangeKind::INSERTION));
  free_binary_data(reinterpret_cast<intptr_t>(insert_result));
  CHECK(getLineTextUtf8(document, 0) == "Xabc");

  action_payload = editor_set_cursor_position(editor, 0, 4, &action_size);
  REQUIRE(action_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
  ImeState ime_state = beginCommandSession(editor);
  REQUIRE(ime_state.result_code == ImeResultCode::OK);
  size_t ime_size = 0;
  ImeCommand preedit_message;
  preedit_message.kind = ImeCommandKind::UPDATE_COMPOSITION;
  preedit_message.text = "q";
  const uint8_t* ime_result = sendImeCommand(
      editor, ime_state.session_id, preedit_message, &ime_size);
  REQUIRE(ime_result != nullptr);
  CHECK(ime_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(ime_result));
  CHECK(getLineTextUtf8(document, 0) == "Xabcq");

  size_t comp_size = 0;
  ImeCommand commit_message;
  commit_message.kind = ImeCommandKind::COMMIT_TEXT;
  commit_message.text = "z";
  const uint8_t* comp_result = sendImeCommand(
      editor, ime_state.session_id, commit_message, &comp_size);
  REQUIRE(comp_result != nullptr);
  CHECK(comp_size > 0);
  free_binary_data(reinterpret_cast<intptr_t>(comp_result));
  CHECK(getLineTextUtf8(document, 0) == "Xabcz");

  action_payload = editor_set_cursor_position(editor, 0, 5, &action_size);
  REQUIRE(action_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
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

  action_payload = editor_set_scroll(editor, 10000.0f, 10000.0f, &action_size);
  REQUIRE(action_payload != nullptr);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
  scroll_metrics_payload = editor_get_scroll_metrics(editor, &scroll_metrics_size);
  REQUIRE(scroll_metrics_payload != nullptr);
  scroll_metrics = parseScrollMetrics(scroll_metrics_payload, scroll_metrics_size);
  free_binary_data(reinterpret_cast<intptr_t>(scroll_metrics_payload));
  CHECK(scroll_metrics.scroll_x == scroll_metrics.max_scroll_x);
  CHECK(scroll_metrics.scroll_y == scroll_metrics.max_scroll_y);
  CHECK(scroll_metrics.can_scroll_x == 1);
  CHECK(scroll_metrics.can_scroll_y == 0);

  action_payload = editor_linked_editing_next(editor, &action_size);
  REQUIRE(action_payload != nullptr);
  ActionPayloadData linked_action = parseActionPayload(action_payload, action_size);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
  CHECK(linked_action.handled == 1);
  action_payload = editor_linked_editing_next(editor, &action_size);
  REQUIRE(action_payload != nullptr);
  linked_action = parseActionPayload(action_payload, action_size);
  free_binary_data(reinterpret_cast<intptr_t>(action_payload));
  CHECK(linked_action.handled == 0);
  CHECK(editor_is_in_linked_editing(editor) == 0);

  size_t model_size = 0;
  const uint8_t* model_payload = editor_build_render_model(editor, &model_size);
  REQUIRE(model_payload != nullptr);
  CHECK(model_size >= sizeof(float) * 7 + sizeof(int32_t) * 3);
  RenderModelHeaderData model_header = parseRenderModelHeader(model_payload, model_size);
  free_binary_data(reinterpret_cast<intptr_t>(model_payload));
  CHECK(model_header.viewport_size.width == 100.0f);
  CHECK(model_header.viewport_size.height == 80.0f);
  CHECK(model_header.split_line_visible == 1);
  CHECK(model_header.current_line_render_mode == 0);
  CHECK(model_header.line_count >= 1);

  free_editor(editor);
  free_document(document);
}
