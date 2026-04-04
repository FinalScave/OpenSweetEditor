#ifndef SWEETEDITOR_NAPI_EDITOR_HPP
#define SWEETEDITOR_NAPI_EDITOR_HPP

#include <vector>
#include <cstring>
#include <editor_core.h>
#include <document.h>
#include "napi_helper.h"

using namespace NS_SWEETEDITOR;

class OhosTextMeasurer : public TextMeasurer {
public:
  OhosTextMeasurer(napi_env env, napi_value measurer_obj) : m_env_(env) {
    napi_create_reference(env, measurer_obj, 1, &m_measurer_ref_);

    napi_value fn;
    napi_get_named_property(env, measurer_obj, "measureWidth", &fn);
    napi_create_reference(env, fn, 1, &m_measure_width_ref_);

    napi_get_named_property(env, measurer_obj, "measureInlayHintWidth", &fn);
    napi_create_reference(env, fn, 1, &m_measure_inlay_hint_width_ref_);

    napi_get_named_property(env, measurer_obj, "measureIconWidth", &fn);
    napi_create_reference(env, fn, 1, &m_measure_icon_width_ref_);

    napi_get_named_property(env, measurer_obj, "getFontAscent", &fn);
    napi_create_reference(env, fn, 1, &m_get_font_ascent_ref_);

    napi_get_named_property(env, measurer_obj, "getFontDescent", &fn);
    napi_create_reference(env, fn, 1, &m_get_font_descent_ref_);
  }

  ~OhosTextMeasurer() override {
    if (m_env_ != nullptr) {
      napi_delete_reference(m_env_, m_measurer_ref_);
      napi_delete_reference(m_env_, m_measure_width_ref_);
      napi_delete_reference(m_env_, m_measure_inlay_hint_width_ref_);
      napi_delete_reference(m_env_, m_measure_icon_width_ref_);
      napi_delete_reference(m_env_, m_get_font_ascent_ref_);
      napi_delete_reference(m_env_, m_get_font_descent_ref_);
    }
  }

  float measureWidth(const U16String& text, int32_t font_style) override {
    napi_value measurer, fn, result = nullptr;
    napi_get_reference_value(m_env_, m_measurer_ref_, &measurer);
    napi_get_reference_value(m_env_, m_measure_width_ref_, &fn);

    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    napi_value args[2];
    napi_create_string_utf8(m_env_, u8_text.c_str(), u8_text.size(), &args[0]);
    napi_create_int32(m_env_, font_style, &args[1]);
    napi_status status = napi_call_function(m_env_, measurer, fn, 2, args, &result);

    double val = 0;
    if (status == napi_ok && result != nullptr) {
      napi_get_value_double(m_env_, result, &val);
    }
    return static_cast<float>(val);
  }

  float measureInlayHintWidth(const U16String& text) override {
    napi_value measurer, fn, result = nullptr;
    napi_get_reference_value(m_env_, m_measurer_ref_, &measurer);
    napi_get_reference_value(m_env_, m_measure_inlay_hint_width_ref_, &fn);

    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(text, u8_text);
    napi_value args[1];
    napi_create_string_utf8(m_env_, u8_text.c_str(), u8_text.size(), &args[0]);
    napi_status status = napi_call_function(m_env_, measurer, fn, 1, args, &result);

    double val = 0;
    if (status == napi_ok && result != nullptr) {
      napi_get_value_double(m_env_, result, &val);
    }
    return static_cast<float>(val);
  }

  float measureIconWidth(int32_t icon_id) override {
    napi_value measurer, fn, result = nullptr;
    napi_get_reference_value(m_env_, m_measurer_ref_, &measurer);
    napi_get_reference_value(m_env_, m_measure_icon_width_ref_, &fn);

    napi_value args[1];
    napi_create_int32(m_env_, icon_id, &args[0]);
    napi_status status = napi_call_function(m_env_, measurer, fn, 1, args, &result);

    double val = 0;
    if (status == napi_ok && result != nullptr) {
      napi_get_value_double(m_env_, result, &val);
    }
    return static_cast<float>(val);
  }

  FontMetrics getFontMetrics() override {
    napi_value measurer, fn_ascent, fn_descent, result = nullptr;
    napi_get_reference_value(m_env_, m_measurer_ref_, &measurer);

    napi_get_reference_value(m_env_, m_get_font_ascent_ref_, &fn_ascent);
    napi_status status = napi_call_function(m_env_, measurer, fn_ascent, 0, nullptr, &result);
    double ascent = 0;
    if (status == napi_ok && result != nullptr) {
      napi_get_value_double(m_env_, result, &ascent);
    }

    result = nullptr;
    napi_get_reference_value(m_env_, m_get_font_descent_ref_, &fn_descent);
    status = napi_call_function(m_env_, measurer, fn_descent, 0, nullptr, &result);
    double descent = 0;
    if (status == napi_ok && result != nullptr) {
      napi_get_value_double(m_env_, result, &descent);
    }

    return {static_cast<float>(ascent), static_cast<float>(descent)};
  }

private:
  napi_env m_env_;
  napi_ref m_measurer_ref_;
  napi_ref m_measure_width_ref_;
  napi_ref m_measure_inlay_hint_width_ref_;
  napi_ref m_measure_icon_width_ref_;
  napi_ref m_get_font_ascent_ref_;
  napi_ref m_get_font_descent_ref_;
};

class DocumentNapi {
public:
  static napi_value createFromString(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string text = napi_get_utf8_string(env, args[0]);
    Ptr<Document> document = makePtr<LineArrayDocument>(text.c_str());
    return napi_create_int64_value(env, toIntPtr(document));
  }

  static napi_value createFromFile(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string path = napi_get_utf8_string(env, args[0]);
    UPtr<Buffer> buffer = makeUPtr<MappedFileBuffer>(path.c_str());
    Ptr<Document> document = makePtr<LineArrayDocument>(std::move(buffer));
    return napi_create_int64_value(env, toIntPtr(document));
  }

  static napi_value destroy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    deleteCPtrHolder<Document>(napi_get_handle(env, args[0]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getText(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    Ptr<Document> doc = getCPtrHolderValue<Document>(napi_get_handle(env, args[0]));
    if (doc == nullptr) return napi_create_string_value(env, "");
    return napi_create_string_value(env, doc->getU8Text().c_str());
  }

  static napi_value getLineCount(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    Ptr<Document> doc = getCPtrHolderValue<Document>(napi_get_handle(env, args[0]));
    if (doc == nullptr) return napi_create_int32_value(env, 0);
    return napi_create_int32_value(env, static_cast<int32_t>(doc->getLineCount()));
  }

  static napi_value getLineText(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    Ptr<Document> doc = getCPtrHolderValue<Document>(napi_get_handle(env, args[0]));
    if (doc == nullptr) return napi_create_string_value(env, "");

    int32_t line = napi_get_int32(env, args[1]);
    U16String u16_text = doc->getLineU16Text(line);
    U8String u8_text;
    StrUtil::convertUTF16ToUTF8(u16_text, u8_text);
    return napi_create_string_value(env, u8_text.c_str());
  }
};

class EditorCoreNapi {
public:
  static napi_value create(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    Ptr<TextMeasurer> measurer = makePtr<OhosTextMeasurer>(env, args[0]);
    EditorOptions options;

    if (argc > 1 && !napi_is_null_or_undefined(env, args[1])) {
      void* data = nullptr;
      size_t byte_length = 0;
      napi_get_arraybuffer_info(env, args[1], &data, &byte_length);
      if (data != nullptr && byte_length >= 40) {
        auto* ptr = reinterpret_cast<const uint8_t*>(data);
        size_t offset = 0;
        std::memcpy(&options.touch_slop, ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&options.double_tap_timeout, ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        std::memcpy(&options.long_press_ms, ptr + offset, sizeof(int64_t)); offset += sizeof(int64_t);
        std::memcpy(&options.fling_friction, ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&options.fling_min_velocity, ptr + offset, sizeof(float)); offset += sizeof(float);
        std::memcpy(&options.fling_max_velocity, ptr + offset, sizeof(float)); offset += sizeof(float);
        uint64_t max_undo = 0;
        std::memcpy(&max_undo, ptr + offset, sizeof(uint64_t));
        options.max_undo_stack_size = static_cast<size_t>(max_undo);
      }
    }

    auto handle = makeCPtrHolderToIntPtr<EditorCore>(measurer, options);
    return napi_create_int64_value(env, handle);
  }

  static napi_value destroy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    deleteCPtrHolder<EditorCore>(napi_get_handle(env, args[0]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setViewport(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    set_editor_viewport(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                        static_cast<int16_t>(napi_get_int32(env, args[1])),
                        static_cast<int16_t>(napi_get_int32(env, args[2])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value loadDocument(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    set_editor_document(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                        static_cast<intptr_t>(napi_get_handle(env, args[1])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value handleGestureEvent(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    int32_t type = napi_get_int32(env, args[1]);
    int32_t pointer_count = napi_get_int32(env, args[2]);

    std::vector<float> points_vec;
    if (pointer_count > 0 && !napi_is_null_or_undefined(env, args[3])) {
      uint32_t arr_len = 0;
      napi_get_array_length(env, args[3], &arr_len);
      points_vec.resize(arr_len);
      for (uint32_t i = 0; i < arr_len; i++) {
        napi_value elem;
        napi_get_element(env, args[3], i, &elem);
        points_vec[i] = napi_get_float(env, elem);
      }
    }

    size_t out_size = 0;
    const uint8_t* payload = handle_editor_gesture_event(
      static_cast<intptr_t>(handle),
      static_cast<uint8_t>(type),
      static_cast<uint8_t>(pointer_count),
      points_vec.empty() ? nullptr : points_vec.data(),
      &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value handleGestureEventEx(napi_env env, napi_callback_info info) {
    size_t argc = 8;
    napi_value args[8];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    int32_t type = napi_get_int32(env, args[1]);
    int32_t pointer_count = napi_get_int32(env, args[2]);

    std::vector<float> points_vec;
    if (pointer_count > 0 && !napi_is_null_or_undefined(env, args[3])) {
      uint32_t arr_len = 0;
      napi_get_array_length(env, args[3], &arr_len);
      points_vec.resize(arr_len);
      for (uint32_t i = 0; i < arr_len; i++) {
        napi_value elem;
        napi_get_element(env, args[3], i, &elem);
        points_vec[i] = napi_get_float(env, elem);
      }
    }

    int32_t modifiers = napi_get_int32(env, args[4]);
    float wheel_delta_x = napi_get_float(env, args[5]);
    float wheel_delta_y = napi_get_float(env, args[6]);
    float direct_scale = napi_get_float(env, args[7]);

    size_t out_size = 0;
    const uint8_t* payload = handle_editor_gesture_event_ex(
      static_cast<intptr_t>(handle),
      static_cast<uint8_t>(type),
      static_cast<uint8_t>(pointer_count),
      points_vec.empty() ? nullptr : points_vec.data(),
      static_cast<uint8_t>(modifiers),
      wheel_delta_x, wheel_delta_y, direct_scale,
      &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value onFontMetricsChanged(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_on_font_metrics_changed(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value tickEdgeScroll(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_edge_scroll(static_cast<intptr_t>(handle), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value tickFling(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_fling(static_cast<intptr_t>(handle), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value tickAnimations(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    const uint8_t* payload = editor_tick_animations(static_cast<intptr_t>(handle), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value buildRenderModel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    size_t out_size = 0;
    const uint8_t* payload = build_editor_render_model(
      static_cast<intptr_t>(napi_get_handle(env, args[0])), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value getLayoutMetrics(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    size_t out_size = 0;
    const uint8_t* payload = get_layout_metrics(
      static_cast<intptr_t>(napi_get_handle(env, args[0])), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value handleKeyEvent(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    int32_t key_code = napi_get_int32(env, args[1]);
    const char* text_str = nullptr;
    std::string text_buf;
    if (!napi_is_null_or_undefined(env, args[2])) {
      text_buf = napi_get_utf8_string(env, args[2]);
      text_str = text_buf.c_str();
    }
    int32_t modifiers = napi_get_int32(env, args[3]);

    size_t out_size = 0;
    const uint8_t* payload = handle_editor_key_event(
      static_cast<intptr_t>(handle),
      static_cast<uint16_t>(key_code),
      text_str,
      static_cast<uint8_t>(modifiers),
      &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value insertText(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    std::string text = napi_get_utf8_string(env, args[1]);
    size_t out_size = 0;
    const uint8_t* payload = editor_insert_text(static_cast<intptr_t>(handle), text.c_str(), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value replaceText(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value args[6];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    std::string text = napi_get_utf8_string(env, args[5]);
    size_t out_size = 0;
    const uint8_t* payload = editor_replace_text(
      static_cast<intptr_t>(handle),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])),
      static_cast<size_t>(napi_get_int32(env, args[3])),
      static_cast<size_t>(napi_get_int32(env, args[4])),
      text.c_str(), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value deleteText(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    size_t out_size = 0;
    const uint8_t* payload = editor_delete_text(
      static_cast<intptr_t>(handle),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])),
      static_cast<size_t>(napi_get_int32(env, args[3])),
      static_cast<size_t>(napi_get_int32(env, args[4])),
      &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value backspace(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    const uint8_t* payload = editor_backspace(static_cast<intptr_t>(handle), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value deleteForward(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    const uint8_t* payload = editor_delete_forward(static_cast<intptr_t>(handle), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value moveLineUp(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_move_line_up(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value moveLineDown(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_move_line_down(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value copyLineUp(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_copy_line_up(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value copyLineDown(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_copy_line_down(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value deleteLine(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_delete_line(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value insertLineAbove(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_insert_line_above(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value insertLineBelow(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_insert_line_below(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value getSelectedText(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    Ptr<EditorCore> editor = getCPtrHolderValue<EditorCore>(handle);
    if (editor == nullptr) return napi_create_string_value(env, "");
    U8String selected = editor->getSelectedText();
    return napi_create_string_value(env, selected.c_str());
  }

  static napi_value compositionStart(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_composition_start(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value compositionUpdate(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    const char* text_str = nullptr;
    std::string text_buf;
    if (!napi_is_null_or_undefined(env, args[1])) {
      text_buf = napi_get_utf8_string(env, args[1]);
      text_str = text_buf.c_str();
    }
    editor_composition_update(static_cast<intptr_t>(napi_get_handle(env, args[0])), text_str);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value compositionEnd(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    const char* text_str = nullptr;
    std::string text_buf;
    if (argc > 1 && !napi_is_null_or_undefined(env, args[1])) {
      text_buf = napi_get_utf8_string(env, args[1]);
      text_str = text_buf.c_str();
    }
    size_t out_size = 0;
    const uint8_t* payload = editor_composition_end(static_cast<intptr_t>(handle), text_str, &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value compositionCancel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_composition_cancel(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value isComposing(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_is_composing(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value setCompositionEnabled(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_composition_enabled(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                   napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value isCompositionEnabled(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_is_composition_enabled(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value setReadOnly(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_read_only(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                         napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value isReadOnly(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_is_read_only(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value setAutoIndentMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_auto_indent_mode(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getAutoIndentMode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_int32_value(env, editor_get_auto_indent_mode(static_cast<intptr_t>(napi_get_handle(env, args[0]))));
  }

  static napi_value setBackspaceUnindent(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_backspace_unindent(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                  napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setInsertSpaces(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_insert_spaces(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                             napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setHandleConfig(napi_env env, napi_callback_info info) {
    size_t argc = 9;
    napi_value args[9];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_handle_config(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      napi_get_float(env, args[1]), napi_get_float(env, args[2]),
      napi_get_float(env, args[3]), napi_get_float(env, args[4]),
      napi_get_float(env, args[5]), napi_get_float(env, args[6]),
      napi_get_float(env, args[7]), napi_get_float(env, args[8]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setScrollbarConfig(napi_env env, napi_callback_info info) {
    size_t argc = 9;
    napi_value args[9];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_scrollbar_config(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      napi_get_float(env, args[1]), napi_get_float(env, args[2]), napi_get_float(env, args[3]),
      napi_get_int32(env, args[4]),
      napi_get_bool(env, args[5]) ? 1 : 0,
      napi_get_int32(env, args[6]),
      napi_get_int32(env, args[7]),
      napi_get_int32(env, args[8]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getPositionRect(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    float x = 0, y = 0, height = 0;
    editor_get_position_rect(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])),
      &x, &y, &height);

    napi_value result;
    napi_create_array_with_length(env, 3, &result);
    napi_value v;
    napi_create_double(env, x, &v); napi_set_element(env, result, 0, v);
    napi_create_double(env, y, &v); napi_set_element(env, result, 1, v);
    napi_create_double(env, height, &v); napi_set_element(env, result, 2, v);
    return result;
  }

  static napi_value getCursorRect(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    float x = 0, y = 0, height = 0;
    editor_get_cursor_rect(static_cast<intptr_t>(napi_get_handle(env, args[0])), &x, &y, &height);

    napi_value result;
    napi_create_array_with_length(env, 3, &result);
    napi_value v;
    napi_create_double(env, x, &v); napi_set_element(env, result, 0, v);
    napi_create_double(env, y, &v); napi_set_element(env, result, 1, v);
    napi_create_double(env, height, &v); napi_set_element(env, result, 2, v);
    return result;
  }

  static napi_value registerTextStyle(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_register_text_style(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<uint32_t>(napi_get_int32(env, args[1])),
      napi_get_int32(env, args[2]),
      napi_get_int32(env, args[3]),
      napi_get_int32(env, args[4]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setBinaryData(napi_env env, napi_callback_info info,
      void (*c_api_fn)(intptr_t, const uint8_t*, size_t)) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    void* data = nullptr;
    size_t byte_length = 0;
    napi_get_arraybuffer_info(env, args[1], &data, &byte_length);
    int32_t size = napi_get_int32(env, args[2]);

    if (data != nullptr && size > 0) {
      c_api_fn(static_cast<intptr_t>(handle),
               reinterpret_cast<const uint8_t*>(data),
               static_cast<size_t>(size));
    }
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setLineSpans(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_line_spans);
  }

  static napi_value setBatchLineSpans(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_batch_line_spans);
  }

  static napi_value registerBatchTextStyles(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_register_batch_text_styles);
  }

  static napi_value setLineInlayHints(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_line_inlay_hints);
  }

  static napi_value setBatchLineInlayHints(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_batch_line_inlay_hints);
  }

  static napi_value setLinePhantomTexts(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_line_phantom_texts);
  }

  static napi_value setBatchLinePhantomTexts(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_batch_line_phantom_texts);
  }

  static napi_value setLineGutterIcons(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_line_gutter_icons);
  }

  static napi_value setBatchLineGutterIcons(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_batch_line_gutter_icons);
  }

  static napi_value setLineDiagnostics(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_line_diagnostics);
  }

  static napi_value setBatchLineDiagnostics(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_batch_line_diagnostics);
  }

  static napi_value setIndentGuides(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_indent_guides);
  }

  static napi_value setBracketGuides(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_bracket_guides);
  }

  static napi_value setFlowGuides(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_flow_guides);
  }

  static napi_value setSeparatorGuides(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_separator_guides);
  }

  static napi_value setFoldRegions(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_fold_regions);
  }

  static napi_value setKeyMap(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_set_keymap);
  }

  static napi_value startLinkedEditing(napi_env env, napi_callback_info info) {
    return setBinaryData(env, info, editor_start_linked_editing);
  }

  static napi_value clearHighlights(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_highlights(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearHighlightsLayer(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_highlights_layer(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                  static_cast<uint8_t>(napi_get_int32(env, args[1])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearLineSpans(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_line_spans(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                            static_cast<size_t>(napi_get_int32(env, args[1])),
                            static_cast<uint8_t>(napi_get_int32(env, args[2])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearInlayHints(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_inlay_hints(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearPhantomTexts(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_phantom_texts(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearGutterIcons(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_gutter_icons(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearGuides(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_guides(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearDiagnostics(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_diagnostics(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearAllDecorations(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_all_decorations(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setBracketPairs(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    uint32_t count = 0;
    napi_get_array_length(env, args[1], &count);

    std::vector<uint32_t> opens(count), closes(count);
    for (uint32_t i = 0; i < count; i++) {
      napi_value elem;
      napi_get_element(env, args[1], i, &elem);
      opens[i] = static_cast<uint32_t>(napi_get_int32(env, elem));
      napi_get_element(env, args[2], i, &elem);
      closes[i] = static_cast<uint32_t>(napi_get_int32(env, elem));
    }
    editor_set_bracket_pairs(static_cast<intptr_t>(handle), opens.data(), closes.data(), count);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setAutoClosingPairs(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    uint32_t count = 0;
    napi_get_array_length(env, args[1], &count);

    std::vector<uint32_t> opens(count), closes(count);
    for (uint32_t i = 0; i < count; i++) {
      napi_value elem;
      napi_get_element(env, args[1], i, &elem);
      opens[i] = static_cast<uint32_t>(napi_get_int32(env, elem));
      napi_get_element(env, args[2], i, &elem);
      closes[i] = static_cast<uint32_t>(napi_get_int32(env, elem));
    }
    editor_set_auto_closing_pairs(static_cast<intptr_t>(handle), opens.data(), closes.data(), count);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setMatchedBrackets(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_matched_brackets(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])),
      static_cast<size_t>(napi_get_int32(env, args[3])),
      static_cast<size_t>(napi_get_int32(env, args[4])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value clearMatchedBrackets(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_clear_matched_brackets(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value toggleFold(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int result = editor_toggle_fold(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                    static_cast<size_t>(napi_get_int32(env, args[1])));
    return napi_create_bool_value(env, result != 0);
  }

  static napi_value foldAt(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int result = editor_fold_at(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                static_cast<size_t>(napi_get_int32(env, args[1])));
    return napi_create_bool_value(env, result != 0);
  }

  static napi_value unfoldAt(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int result = editor_unfold_at(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                  static_cast<size_t>(napi_get_int32(env, args[1])));
    return napi_create_bool_value(env, result != 0);
  }

  static napi_value foldAll(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_fold_all(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value unfoldAll(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_unfold_all(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value isLineVisible(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int result = editor_is_line_visible(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                        static_cast<size_t>(napi_get_int32(env, args[1])));
    return napi_create_bool_value(env, result != 0);
  }

  static napi_value setMaxGutterIcons(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_max_gutter_icons(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                static_cast<uint32_t>(napi_get_int32(env, args[1])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setFoldArrowMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_fold_arrow_mode(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                               napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setWrapMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_wrap_mode(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                         napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setTabSize(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_tab_size(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                        napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setScale(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_scale(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                     napi_get_float(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setLineSpacing(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_line_spacing(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                            napi_get_float(env, args[1]),
                            napi_get_float(env, args[2]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setContentStartPadding(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_content_start_padding(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                     napi_get_float(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setShowSplitLine(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_show_split_line(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                               napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setGutterSticky(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_gutter_sticky(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                             napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setGutterVisible(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_gutter_visible(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                              napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setCurrentLineRenderMode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_current_line_render_mode(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                        napi_get_int32(env, args[1]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value undo(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_undo(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value redo(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_redo(static_cast<intptr_t>(handle), &out_size), out_size);
  }

  static napi_value canUndo(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_can_undo(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value canRedo(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_can_redo(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value setCursorPosition(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_cursor_position(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getCursorPosition(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t line = 0, column = 0;
    editor_get_cursor_position(static_cast<intptr_t>(napi_get_handle(env, args[0])), &line, &column);

    napi_value result;
    napi_create_array_with_length(env, 2, &result);
    napi_value v;
    napi_create_int32(env, static_cast<int32_t>(line), &v); napi_set_element(env, result, 0, v);
    napi_create_int32(env, static_cast<int32_t>(column), &v); napi_set_element(env, result, 1, v);
    return result;
  }

  static napi_value selectAll(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_select_all(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setSelection(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value args[5];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_selection(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])),
      static_cast<size_t>(napi_get_int32(env, args[3])),
      static_cast<size_t>(napi_get_int32(env, args[4])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getSelection(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t sl = 0, sc = 0, el = 0, ec = 0;
    int has = editor_get_selection(static_cast<intptr_t>(napi_get_handle(env, args[0])), &sl, &sc, &el, &ec);

    if (has == 0) {
      napi_value null_val;
      napi_get_null(env, &null_val);
      return null_val;
    }

    napi_value result;
    napi_create_array_with_length(env, 4, &result);
    napi_value v;
    napi_create_int32(env, static_cast<int32_t>(sl), &v); napi_set_element(env, result, 0, v);
    napi_create_int32(env, static_cast<int32_t>(sc), &v); napi_set_element(env, result, 1, v);
    napi_create_int32(env, static_cast<int32_t>(el), &v); napi_set_element(env, result, 2, v);
    napi_create_int32(env, static_cast<int32_t>(ec), &v); napi_set_element(env, result, 3, v);
    return result;
  }

  static napi_value getWordRangeAtCursor(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t sl = 0, sc = 0, el = 0, ec = 0;
    editor_get_word_range_at_cursor(static_cast<intptr_t>(napi_get_handle(env, args[0])), &sl, &sc, &el, &ec);

    napi_value result;
    napi_create_array_with_length(env, 4, &result);
    napi_value v;
    napi_create_int32(env, static_cast<int32_t>(sl), &v); napi_set_element(env, result, 0, v);
    napi_create_int32(env, static_cast<int32_t>(sc), &v); napi_set_element(env, result, 1, v);
    napi_create_int32(env, static_cast<int32_t>(el), &v); napi_set_element(env, result, 2, v);
    napi_create_int32(env, static_cast<int32_t>(ec), &v); napi_set_element(env, result, 3, v);
    return result;
  }

  static napi_value getWordAtCursor(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int64_t handle = napi_get_handle(env, args[0]);
    Ptr<EditorCore> editor = getCPtrHolderValue<EditorCore>(handle);
    if (editor == nullptr) return napi_create_string_value(env, "");
    U8String word = editor->getWordAtCursor();
    return napi_create_string_value(env, word.c_str());
  }

  static napi_value scrollToLine(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_scroll_to_line(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<uint8_t>(napi_get_int32(env, args[2])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value gotoPosition(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_goto_position(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      static_cast<size_t>(napi_get_int32(env, args[1])),
      static_cast<size_t>(napi_get_int32(env, args[2])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value ensureCursorVisible(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_ensure_cursor_visible(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value setScroll(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_set_scroll(static_cast<intptr_t>(napi_get_handle(env, args[0])),
      napi_get_float(env, args[1]),
      napi_get_float(env, args[2]));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value getScrollMetrics(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    size_t out_size = 0;
    return wrap_binary_payload(env, editor_get_scroll_metrics(
      static_cast<intptr_t>(napi_get_handle(env, args[0])), &out_size), out_size);
  }

  static napi_value moveCursorLeft(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_left(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                            napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value moveCursorRight(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_right(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                             napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value moveCursorUp(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_up(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                          napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value moveCursorDown(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_down(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                            napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value moveCursorToLineStart(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_to_line_start(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                     napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value moveCursorToLineEnd(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_move_cursor_to_line_end(static_cast<intptr_t>(napi_get_handle(env, args[0])),
                                   napi_get_bool(env, args[1]) ? 1 : 0);
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }

  static napi_value insertSnippet(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t handle = napi_get_handle(env, args[0]);
    if (handle == 0) { napi_value u; napi_get_undefined(env, &u); return u; }

    std::string tpl = napi_get_utf8_string(env, args[1]);
    size_t out_size = 0;
    const uint8_t* payload = editor_insert_snippet(static_cast<intptr_t>(handle), tpl.c_str(), &out_size);
    return wrap_binary_payload(env, payload, out_size);
  }

  static napi_value isInLinkedEditing(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_is_in_linked_editing(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value linkedEditingNext(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_linked_editing_next(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value linkedEditingPrev(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    return napi_create_bool_value(env, editor_linked_editing_prev(static_cast<intptr_t>(napi_get_handle(env, args[0]))) != 0);
  }

  static napi_value cancelLinkedEditing(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    editor_cancel_linked_editing(static_cast<intptr_t>(napi_get_handle(env, args[0])));
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
  }
};

#endif // SWEETEDITOR_NAPI_EDITOR_HPP
