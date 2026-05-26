//
// Created by Scave on 2025/12/8.
//
#ifdef _WIN32
#include <Windows.h>
#include <DbgHelp.h>
#pragma comment(lib, "DbgHelp.lib")
#endif

#include <cstring>
#include <algorithm>
#include <limits>
#include <vector>
#include <sweeteditor/protocol_codec.h>
#include <sweeteditor/utility.h>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/document.h>
#include "c_wrapper.hpp"
#include "logging.h"

using namespace NS_SWEETEDITOR;

namespace {
class ByteCursor {
public:
  ByteCursor(const uint8_t* data, size_t size): cur_(data), end_(data + size) {
  }

  bool readU32(uint32_t& out) {
    if (!has(4)) return false;
    out = static_cast<uint32_t>(cur_[0]) |
      (static_cast<uint32_t>(cur_[1]) << 8u) |
      (static_cast<uint32_t>(cur_[2]) << 16u) |
      (static_cast<uint32_t>(cur_[3]) << 24u);
    cur_ += 4;
    return true;
  }

  bool readI32(int32_t& out) {
    uint32_t v = 0;
    if (!readU32(v)) return false;
    out = static_cast<int32_t>(v);
    return true;
  }

  bool readU8(uint8_t& out) {
    if (!has(1)) return false;
    out = *cur_;
    cur_ += 1;
    return true;
  }

  bool readBytes(const uint8_t*& out, size_t count) {
    if (!has(count)) return false;
    out = cur_;
    cur_ += count;
    return true;
  }

  bool has(size_t count) const {
    return count <= static_cast<size_t>(end_ - cur_);
  }

  size_t remaining() const {
    return static_cast<size_t>(end_ - cur_);
  }

private:
  const uint8_t* cur_;
  const uint8_t* end_;
};

static bool mulOverflow(size_t a, size_t b, size_t& out) {
  if (a == 0 || b == 0) {
    out = 0;
    return false;
  }
  if (a > std::numeric_limits<size_t>::max() / b) {
    return true;
  }
  out = a * b;
  return false;
}

static bool addOverflow(size_t a, size_t b, size_t& out) {
  if (a > std::numeric_limits<size_t>::max() - b) {
    return true;
  }
  out = a + b;
  return false;
}
}

static const uint8_t* allocBinaryPayload(const uint8_t* data, size_t size, size_t* out_size) {
  if (out_size != nullptr) {
    *out_size = size;
  }
  if (data == nullptr || size == 0) {
    return nullptr;
  }
  auto* result = new uint8_t[size];
  std::memcpy(result, data, size);
  return result;
}

static const uint8_t* nullBinaryPayload(size_t* out_size) {
  if (out_size != nullptr) {
    *out_size = 0;
  }
  return nullptr;
}

template <typename T>
static const uint8_t* protocolToBinary(const T& value, size_t* out_size, size_t reserve_size = 0) {
  Vector<uint8_t> buffer = protocol::ProtocolWriter::encode(value, reserve_size);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* editorRenderModelToBinary(const EditorRenderModel& model, size_t* out_size) {
  return protocolToBinary(model, out_size, 1024);
}

static const uint8_t* imeSyncSnapshotToBinary(const ImeSyncSnapshot& snapshot, size_t* out_size) {
  return protocolToBinary(snapshot, out_size, sizeof(int32_t) * 21);
}

static const uint8_t* imeInputContextToBinary(const ImeInputContext& context, size_t* out_size) {
  return protocolToBinary(context, out_size, sizeof(int32_t) * 9 + sizeof(int64_t) + context.text.size());
}

static const uint8_t* editorActionResultToBinary(const EditorActionResult& result, size_t* out_size) {
  return protocolToBinary(result, out_size, 256 + result.changes.size() * 32);
}

static const uint8_t* scrollMetricsToBinary(const ScrollMetrics& metrics, size_t* out_size) {
  return protocolToBinary(metrics, out_size, sizeof(float) * 11 + sizeof(int32_t) * 2);
}

static const uint8_t* layoutMetricsToBinary(const LayoutMetrics& metrics, size_t* out_size) {
  return protocolToBinary(metrics, out_size, sizeof(float) * 8 + sizeof(int32_t) * 3);
}

class CTextMeasurer : public TextMeasurer {
public:
  explicit CTextMeasurer(text_measurer_t measurer)
    : m_measurer_(measurer) {
  }

  float measureWidth(const U16String& text, int32_t font_style) override {
    if (m_measurer_.measure_text_width == nullptr) {
      return 0;
    }
    return m_measurer_.measure_text_width(text.c_str(), font_style);
  }

  float measureInlayHintWidth(const U16String& text) override {
    if (m_measurer_.measure_inlay_hint_width == nullptr) {
      return measureWidth(text, FONT_STYLE_ITALIC);
    }
    return m_measurer_.measure_inlay_hint_width(text.c_str());
  }

  float measureIconWidth(int32_t icon_id) override {
    if (m_measurer_.measure_icon_width == nullptr) {
      return 0;
    }
    return m_measurer_.measure_icon_width(icon_id);
  }

  FontMetrics getFontMetrics() override {
    if (m_measurer_.get_font_metrics == nullptr) {
      return {0, 0};
    }
    float arr[2];
    m_measurer_.get_font_metrics(arr, 2);
    return {arr[0], arr[1]};
  }

private:
  text_measurer_t m_measurer_;
};

extern "C" {

#pragma region [Core Lifecycle, View & Events]

intptr_t create_document_from_utf8(const char* text) {
  SharedPtr<Document> document = makeShared<LineArrayDocument>(text);
  return toIntPtr(document);
}

intptr_t create_document_from_utf16(const U16Char* text) {
  SharedPtr<Document> document = makeShared<LineArrayDocument>(text);
  return toIntPtr(document);
}

intptr_t create_document_from_file(const char* path) {
  if (path == nullptr) {
    return 0;
  }
  UniquePtr<Buffer> buffer = makeUnique<MappedFileBuffer>(path);
  SharedPtr<Document> document = makeShared<LineArrayDocument>(std::move(buffer));
  return toIntPtr(document);
}

void free_document(intptr_t document_handle) {
  deleteCPtrHolder<Document>(document_handle);
}

static char* allocU8Chars(const U8String& text) {
  char* result = new char[text.size() + 1];
  std::strcpy(result, text.c_str());
  return result;
}

char* get_document_utf8(intptr_t document_handle) {
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return nullptr;
  }
  return allocU8Chars(document->getU8Text());
}

U16Char* get_document_utf16(intptr_t document_handle) {
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return nullptr;
  }
  U16String u16_text = document->getU16Text();
  return StrUtil::allocU16Chars(u16_text);
}

size_t get_document_line_count(intptr_t document_handle) {
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return 0;
  }
  return document->getLineCount();
}

char* get_document_line_utf8(intptr_t document_handle, size_t line) {
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return nullptr;
  }
  U16String u16_text = document->getLineU16Text(line);
  U8String u8_text;
  if (!u16_text.empty()) {
    StrUtil::convertUTF16ToUTF8(u16_text, u8_text);
  }
  return allocU8Chars(u8_text);
}

U16Char* get_document_line_utf16(intptr_t document_handle, size_t line) {
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return nullptr;
  }
  U16String u16_text = document->getLineU16Text(line);
  return StrUtil::allocU16Chars(u16_text);
}

intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size) {
  SharedPtr<CTextMeasurer> c_measurer = makeShared<CTextMeasurer>(measurer);
  EditorOptions options;
  // Decode binary payload (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms,
  // f32 fling_friction, f32 fling_min_velocity, f32 fling_max_velocity, u64 max_undo_stack_size,
  // i64 key_chord_timeout_ms, u8 reveal_selection_end_on_select_all.
  if (options_data != nullptr) {
    size_t offset = 0;
    auto readF32 = [&](float& out) {
      if (offset + sizeof(float) <= options_size) { std::memcpy(&out, options_data + offset, sizeof(float)); offset += sizeof(float); }
    };
    auto readI64 = [&](int64_t& out) {
      if (offset + sizeof(int64_t) <= options_size) { std::memcpy(&out, options_data + offset, sizeof(int64_t)); offset += sizeof(int64_t); }
    };
    auto readU64 = [&](size_t& out) {
      if (offset + sizeof(uint64_t) <= options_size) { uint64_t v; std::memcpy(&v, options_data + offset, sizeof(uint64_t)); out = static_cast<size_t>(v); offset += sizeof(uint64_t); }
    };
    auto readBool = [&](bool& out) {
      if (offset + sizeof(uint8_t) <= options_size) {
        uint8_t v = 0;
        std::memcpy(&v, options_data + offset, sizeof(uint8_t));
        out = v != 0;
        offset += sizeof(uint8_t);
      }
    };
    readF32(options.touch_slop);
    readI64(options.double_tap_timeout);
    readI64(options.long_press_ms);
    readF32(options.fling_friction);
    readF32(options.fling_min_velocity);
    readF32(options.fling_max_velocity);
    readU64(options.max_undo_stack_size);
    readI64(options.key_chord_timeout_ms);
    readBool(options.reveal_selection_end_on_select_all);
  }
  SharedPtr<EditorCore> editor_core = makeShared<EditorCore>(c_measurer, options);
  return toIntPtr(editor_core);
}

void free_editor(intptr_t editor_handle) {
  deleteCPtrHolder<EditorCore>(editor_handle);
}

const uint8_t* set_editor_document(intptr_t editor_handle, intptr_t document_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->loadDocument(document), out_size);
}

const uint8_t* set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setViewport({(float)width, (float)height}), out_size);
}

const uint8_t* editor_on_font_metrics_changed(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->onFontMetricsChanged(), out_size);
}

const uint8_t* editor_set_fold_arrow_mode(intptr_t editor_handle, int mode, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setFoldArrowMode(static_cast<FoldArrowMode>(mode)), out_size);
}

const uint8_t* editor_set_wrap_mode(intptr_t editor_handle, int mode, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setWrapMode(static_cast<WrapMode>(mode)), out_size);
}

const uint8_t* editor_set_tab_size(intptr_t editor_handle, int tab_size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setTabSize(static_cast<uint32_t>(tab_size)), out_size);
}

const uint8_t* editor_set_scale(intptr_t editor_handle, float scale, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setScale(scale), out_size);
}

const uint8_t* editor_set_line_spacing(intptr_t editor_handle, float add, float mult, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setLineSpacing(add, mult), out_size);
}

const uint8_t* editor_set_content_start_padding(intptr_t editor_handle, float padding, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setContentStartPadding(padding), out_size);
}

const uint8_t* editor_set_show_split_line(intptr_t editor_handle, int show, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setShowSplitLine(show != 0), out_size);
}

const uint8_t* editor_set_current_line_render_mode(intptr_t editor_handle, int mode, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setCurrentLineRenderMode(static_cast<CurrentLineRenderMode>(mode)), out_size);
}

const uint8_t* editor_set_gutter_sticky(intptr_t editor_handle, int sticky, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setGutterSticky(sticky != 0), out_size);
}

const uint8_t* editor_set_gutter_visible(intptr_t editor_handle, int visible, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setGutterVisible(visible != 0), out_size);
}

const uint8_t* editor_set_handle_config(intptr_t editor_handle,
    float start_left, float start_top, float start_right, float start_bottom,
    float end_left, float end_top, float end_right, float end_bottom, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  HandleConfig config;
  config.start_hit_offset = {start_left, start_top, start_right, start_bottom};
  config.end_hit_offset = {end_left, end_top, end_right, end_bottom};
  return editorActionResultToBinary(editor_core->setHandleConfig(config), out_size);
}

const uint8_t* editor_set_scrollbar_config(intptr_t editor_handle,
    float thickness, float min_thumb, float thumb_hit_padding,
    int mode, int thumb_draggable, int track_tap_mode,
    int fade_delay_ms, int fade_duration_ms, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  ScrollbarConfig config;
  config.thickness = thickness;
  config.min_thumb = min_thumb;
  config.thumb_hit_padding = std::max(0.0f, thumb_hit_padding);

  if (mode <= static_cast<int>(ScrollbarMode::ALWAYS)) {
    config.mode = ScrollbarMode::ALWAYS;
  } else if (mode >= static_cast<int>(ScrollbarMode::NEVER)) {
    config.mode = ScrollbarMode::NEVER;
  } else {
    config.mode = static_cast<ScrollbarMode>(mode);
  }

  config.thumb_draggable = (thumb_draggable != 0);
  config.track_tap_mode = (track_tap_mode == static_cast<int>(ScrollbarTrackTapMode::DISABLED))
      ? ScrollbarTrackTapMode::DISABLED
      : ScrollbarTrackTapMode::JUMP;
  config.fade_delay_ms = static_cast<uint16_t>(std::max(0, std::min(65535, fade_delay_ms)));
  config.fade_duration_ms = static_cast<uint16_t>(std::max(0, std::min(65535, fade_duration_ms)));
  return editorActionResultToBinary(editor_core->setScrollbarConfig(config), out_size);
}

const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size) {
  PERF_TIMER("c_api::build_editor_render_model");
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorRenderModel model;
  editor_core->buildRenderModel(model);
  PERF_BEGIN(binary_serial);
  const uint8_t* payload = editorRenderModelToBinary(model, out_size);
  PERF_END(binary_serial, "renderModel::toBinary");
  return payload;
}

const uint8_t* get_layout_metrics(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return layoutMetricsToBinary(editor_core->getLayoutMetrics(), out_size);
}

const uint8_t* handle_editor_gesture_event(intptr_t editor_handle, uint8_t type, uint8_t pointer_count,
    float* points, size_t* out_size) {
  return handle_editor_gesture_event_ex(editor_handle, type, pointer_count, points, 0, 0, 0, 1, out_size);
}

const uint8_t* handle_editor_gesture_event_ex(intptr_t editor_handle, uint8_t type, uint8_t pointer_count,
    float* points, uint8_t modifiers, float wheel_delta_x, float wheel_delta_y, float direct_scale, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || (pointer_count > 0 && points == nullptr)) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureEvent event;
  event.type = static_cast<EventType>(type);
  event.modifiers = static_cast<KeyModifier>(modifiers);
  event.wheel_delta_x = wheel_delta_x;
  event.wheel_delta_y = wheel_delta_y;
  event.direct_scale = direct_scale;
  for (int i = 0; i < pointer_count; i++) {
    event.points.push_back({points[i * 2], points[i * 2 + 1]});
  }
  EditorActionResult result = editor_core->handleGestureEvent(event);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_update_pointer_modifiers(intptr_t editor_handle, uint8_t modifiers, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->updatePointerModifiers(static_cast<KeyModifier>(modifiers));
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_tick_edge_scroll(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->tickEdgeScroll();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_tick_fling(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->tickFling();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_tick_animations(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->tickAnimations();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* handle_editor_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  KeyEvent event;
  event.key_code = static_cast<KeyCode>(key_code);
  event.modifiers = static_cast<KeyModifier>(modifiers);
  if (text != nullptr) {
    event.text = text;
  }
  EditorActionResult result = editor_core->handleKeyEvent(event);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_set_keymap(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr || size < 4) return nullBinaryPayload(out_size);

  size_t offset = 0;
  auto readU32 = [&]() -> uint32_t {
    if (offset + 4 > size) return 0;
    uint32_t v;
    std::memcpy(&v, data + offset, 4);
    offset += 4;
    return v;
  };
  auto readU16 = [&]() -> uint16_t {
    if (offset + 2 > size) return 0;
    uint16_t v;
    std::memcpy(&v, data + offset, 2);
    offset += 2;
    return v;
  };
  auto readU8 = [&]() -> uint8_t {
    if (offset + 1 > size) return 0;
    uint8_t v = data[offset];
    offset += 1;
    return v;
  };

  uint32_t count = readU32();
  if (count == 0) return nullBinaryPayload(out_size);

  const size_t per_binding = 1 + 2 + 1 + 2 + 4; // u8+u16+u8+u16+u32 = 10 bytes
  if (size < 4 + count * per_binding) return nullBinaryPayload(out_size);

  Vector<KeyBinding> bindings;
  bindings.reserve(count);
  for (uint32_t i = 0; i < count; ++i) {
    KeyBinding b;
    b.first.modifiers = static_cast<KeyModifier>(readU8());
    b.first.key_code = static_cast<KeyCode>(readU16());
    b.second.modifiers = static_cast<KeyModifier>(readU8());
    b.second.key_code = static_cast<KeyCode>(readU16());
    b.command = static_cast<EditorCommand>(readU32());
    bindings.push_back(b);
  }

  KeyMap km;
  for (const auto& b : bindings) {
    km.addBinding(b);
  }
  return editorActionResultToBinary(editor_core->setKeyMap(std::move(km)), out_size);
}

#pragma endregion

#pragma region [Editing, Cursor & Interaction]

const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || text == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->insertText(text);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_replace_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || text == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextRange range = {{start_line, start_column}, {end_line, end_column}};
  EditorActionResult result = editor_core->replaceText(range, text);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_delete_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextRange range = {{start_line, start_column}, {end_line, end_column}};
  EditorActionResult result = editor_core->deleteText(range);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->backspace();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->deleteForward();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->moveLineUp();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->moveLineDown();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->copyLineUp();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->copyLineDown();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->deleteLine();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->insertLineAbove();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->insertLineBelow();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->undo();
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->redo();
  return editorActionResultToBinary(result, out_size);
}

int editor_can_undo(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canUndo() ? 1 : 0;
}

int editor_can_redo(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canRedo() ? 1 : 0;
}

const uint8_t* editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setCursorPosition({line, column}), out_size);
}

void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  TextPosition pos = editor_core->getCursorPosition();
  if (out_line) *out_line = pos.line;
  if (out_column) *out_column = pos.column;
}

const uint8_t* editor_select_all(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->selectAll(), out_size);
}

const uint8_t* editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setSelection({{start_line, start_column}, {end_line, end_column}}), out_size);
}

int editor_get_selection(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || !editor_core->hasSelection()) {
    return 0;
  }
  TextRange range = editor_core->getSelection();
  if (out_start_line) *out_start_line = range.start.line;
  if (out_start_column) *out_start_column = range.start.column;
  if (out_end_line) *out_end_line = range.end.line;
  if (out_end_column) *out_end_column = range.end.column;
  return 1;
}

const char* editor_get_selected_text(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return "";
  }
  U8String selected = editor_core->getSelectedText();
  char* result = new char[selected.size() + 1];
  std::strcpy(result, selected.c_str());
  return result;
}

void editor_get_word_range_at_cursor(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  TextRange range = editor_core->getWordRangeAtCursor();
  if (out_start_line) *out_start_line = range.start.line;
  if (out_start_column) *out_start_column = range.start.column;
  if (out_end_line) *out_end_line = range.end.line;
  if (out_end_column) *out_end_column = range.end.column;
}

const char* editor_get_word_at_cursor(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return "";
  U8String word = editor_core->getWordAtCursor();
  char* result = new char[word.size() + 1];
  std::strcpy(result, word.c_str());
  return result;
}

const uint8_t* editor_move_cursor_left(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorLeft(extend_selection != 0), out_size);
}

const uint8_t* editor_move_cursor_right(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorRight(extend_selection != 0), out_size);
}

const uint8_t* editor_move_cursor_up(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorUp(extend_selection != 0), out_size);
}

const uint8_t* editor_move_cursor_down(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorDown(extend_selection != 0), out_size);
}

const uint8_t* editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorToLineStart(extend_selection != 0), out_size);
}

const uint8_t* editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->moveCursorToLineEnd(extend_selection != 0), out_size);
}

const uint8_t* editor_set_read_only(intptr_t editor_handle, int read_only, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setReadOnly(read_only != 0), out_size);
}

int editor_is_read_only(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isReadOnly() ? 1 : 0;
}

const uint8_t* editor_set_auto_indent_mode(intptr_t editor_handle, int mode, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setAutoIndentMode(static_cast<AutoIndentMode>(mode)), out_size);
}

int editor_get_auto_indent_mode(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return static_cast<int>(editor_core->getAutoIndentMode());
}

const uint8_t* editor_set_backspace_unindent(intptr_t editor_handle, int enabled, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setBackspaceUnindent(enabled != 0), out_size);
}

const uint8_t* editor_set_insert_spaces(intptr_t editor_handle, int enabled, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setInsertSpaces(enabled != 0), out_size);
}

#pragma endregion

#pragma region [Navigation, Styles & Decorations]

const uint8_t* editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->scrollToLine(line, static_cast<ScrollBehavior>(behavior)), out_size);
}

const uint8_t* editor_goto_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->gotoPosition(line, column), out_size);
}

const uint8_t* editor_ensure_cursor_visible(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->ensureCursorVisible(), out_size);
}

const uint8_t* editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setScroll(scroll_x, scroll_y), out_size);
}

const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size) {
  ScrollMetrics metrics {};
  metrics.scale = 1.0f;
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core != nullptr) {
    metrics = editor_core->getScrollMetrics();
  }
  return scrollMetricsToBinary(metrics, out_size);
}

void editor_get_position_rect(intptr_t editor_handle,
    size_t line, size_t column,
    float* out_x, float* out_y, float* out_height) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  CursorRect rect = editor_core->getPositionScreenRect({line, column});
  if (out_x) *out_x = rect.x;
  if (out_y) *out_y = rect.y;
  if (out_height) *out_height = rect.height;
}

void editor_get_cursor_rect(intptr_t editor_handle,
    float* out_x, float* out_y, float* out_height) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  CursorRect rect = editor_core->getCursorScreenRect();
  if (out_x) *out_x = rect.x;
  if (out_y) *out_y = rect.y;
  if (out_height) *out_height = rect.height;
}

const uint8_t* editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(
      editor_core->registerTextStyle(style_id, TextStyle{color, background_color, font_style}),
      out_size);
}

const uint8_t* editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineSpansPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineSpans(payload.line, payload.layer, std::move(payload.spans)),
      out_size);
}

const uint8_t* editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineSpansPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setBatchLineSpans(payload.layer, std::move(payload.entries)),
      out_size);
}

const uint8_t* editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::RegisterBatchTextStylesPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->registerBatchTextStyles(std::move(payload.entries)), out_size);
}

const uint8_t* editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setLineSpans(line, static_cast<SpanLayer>(layer), {}), out_size);
}

const uint8_t* editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearHighlights(static_cast<SpanLayer>(layer)), out_size);
}

const uint8_t* editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineInlayHintsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineInlayHints(payload.line, std::move(payload.hints)),
      out_size);
}

const uint8_t* editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineInlayHintsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineInlayHints(std::move(payload.entries)), out_size);
}

const uint8_t* editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLinePhantomTextsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLinePhantomTexts(payload.line, std::move(payload.phantoms)),
      out_size);
}

const uint8_t* editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLinePhantomTextsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLinePhantomTexts(std::move(payload.entries)), out_size);
}

const uint8_t* editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineGutterIconsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineGutterIcons(payload.line, std::move(payload.icons)),
      out_size);
}

const uint8_t* editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineGutterIconsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineGutterIcons(std::move(payload.entries)), out_size);
}

const uint8_t* editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setMaxGutterIcons(count), out_size);
}

const uint8_t* editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineDiagnosticsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineDiagnostics(payload.line, std::move(payload.diagnostics)),
      out_size);
}

const uint8_t* editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineDiagnosticsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineDiagnostics(std::move(payload.entries)), out_size);
}

const uint8_t* editor_clear_diagnostics(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearDiagnostics(), out_size);
}

const uint8_t* editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetIndentGuidesPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setIndentGuides(std::move(payload.guides)), out_size);
}

const uint8_t* editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBracketGuidesPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBracketGuides(std::move(payload.guides)), out_size);
}

const uint8_t* editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetFlowGuidesPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setFlowGuides(std::move(payload.guides)), out_size);
}

const uint8_t* editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetSeparatorGuidesPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setSeparatorGuides(std::move(payload.guides)), out_size);
}

const uint8_t* editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || open_chars == nullptr || close_chars == nullptr) return nullBinaryPayload(out_size);
  Vector<BracketPair> pairs;
  pairs.reserve(count);
  for (size_t i = 0; i < count; ++i) {
    pairs.push_back({static_cast<char32_t>(open_chars[i]), static_cast<char32_t>(close_chars[i])});
  }
  return editorActionResultToBinary(editor_core->setBracketPairs(std::move(pairs)), out_size);
}

const uint8_t* editor_set_auto_closing_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  Vector<BracketPair> pairs;
  if (open_chars != nullptr && close_chars != nullptr) {
    pairs.reserve(count);
    for (size_t i = 0; i < count; ++i) {
      pairs.push_back({static_cast<char32_t>(open_chars[i]), static_cast<char32_t>(close_chars[i])});
    }
  }
  return editorActionResultToBinary(editor_core->setAutoClosingPairs(std::move(pairs)), out_size);
}

const uint8_t* editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setMatchedBrackets({open_line, open_col}, {close_line, close_col}),
      out_size);
}

const uint8_t* editor_clear_matched_brackets(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearMatchedBrackets(), out_size);
}

const uint8_t* editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return nullBinaryPayload(out_size);

  protocol::SetFoldRegionsPayload payload;
  if (protocol::ProtocolReader::decode(data, size, payload)) {
    return editorActionResultToBinary(editor_core->setFoldRegions(std::move(payload.regions)), out_size);
  }

  ByteCursor cursor(data, size);
  uint32_t fold_count = 0;
  if (!cursor.readU32(fold_count)) {
    return nullBinaryPayload(out_size);
  }

  size_t old_fold_bytes = 0;
  size_t new_fold_bytes = 0;
  if (mulOverflow(static_cast<size_t>(fold_count), sizeof(uint32_t) * 2, old_fold_bytes) ||
      mulOverflow(static_cast<size_t>(fold_count), sizeof(uint32_t) * 2 + sizeof(uint8_t), new_fold_bytes)) {
    return nullBinaryPayload(out_size);
  }
  bool has_collapsed = cursor.remaining() == new_fold_bytes;
  if (!has_collapsed && cursor.remaining() != old_fold_bytes) return nullBinaryPayload(out_size);

  Vector<FoldRegion> regions;
  regions.reserve(fold_count);
  for (uint32_t i = 0; i < fold_count; ++i) {
    uint32_t start_line = 0;
    uint32_t end_line = 0;
    uint8_t collapsed = 0;
    if (!cursor.readU32(start_line) || !cursor.readU32(end_line)) {
      return nullBinaryPayload(out_size);
    }
    if (has_collapsed && !cursor.readU8(collapsed)) return nullBinaryPayload(out_size);
    regions.push_back(FoldRegion{static_cast<size_t>(start_line), static_cast<size_t>(end_line), collapsed != 0});
  }
  return editorActionResultToBinary(editor_core->setFoldRegions(std::move(regions)), out_size);
}

const uint8_t* editor_toggle_fold(intptr_t editor_handle, size_t line, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->toggleFoldAt(line), out_size);
}

const uint8_t* editor_fold_at(intptr_t editor_handle, size_t line, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->foldAt(line), out_size);
}

const uint8_t* editor_unfold_at(intptr_t editor_handle, size_t line, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->unfoldAt(line), out_size);
}

const uint8_t* editor_fold_all(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->foldAll(), out_size);
}

const uint8_t* editor_unfold_all(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->unfoldAll(), out_size);
}

int editor_is_line_visible(intptr_t editor_handle, size_t line) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 1;
  return editor_core->isLineVisible(line) ? 1 : 0;
}

void editor_get_visible_line_range(intptr_t editor_handle, int32_t* out_start_line, int32_t* out_end_line) {
  if (out_start_line == nullptr || out_end_line == nullptr) return;
  *out_start_line = 0;
  *out_end_line = -1;
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  IntRange range = editor_core->getVisibleLineRange();
  *out_start_line = range.start;
  *out_end_line = range.end;
}

const uint8_t* editor_clear_highlights(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearHighlights(), out_size);
}

const uint8_t* editor_clear_inlay_hints(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearInlayHints(), out_size);
}

const uint8_t* editor_clear_phantom_texts(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearPhantomTexts(), out_size);
}

const uint8_t* editor_clear_gutter_icons(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearGutterIcons(), out_size);
}

const uint8_t* editor_set_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineCodeLensPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineCodeLens(payload.line, std::move(payload.items)),
      out_size);
}

const uint8_t* editor_set_batch_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineCodeLensPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineCodeLens(std::move(payload.entries)), out_size);
}

const uint8_t* editor_clear_codelens(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearCodeLens(), out_size);
}

const uint8_t* editor_set_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineLinksPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineLinks(payload.line, std::move(payload.links)),
      out_size);
}

const uint8_t* editor_set_batch_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineLinksPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineLinks(std::move(payload.entries)), out_size);
}

const uint8_t* editor_clear_links(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearLinks(), out_size);
}

const char* editor_get_link_target_at(intptr_t editor_handle, size_t line, size_t column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  U8String target;
  if (editor_core != nullptr) {
    target = editor_core->getLinkTargetAt(line, column);
  }
  char* result = new char[target.size() + 1];
  std::strcpy(result, target.c_str());
  return result;
}

const uint8_t* editor_clear_guides(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearGuides(), out_size);
}

const uint8_t* editor_clear_all_decorations(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearAllDecorations(), out_size);
}

#pragma endregion

#pragma region [Linked Editing & Utilities]

const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || snippet_template == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  EditorActionResult result = editor_core->insertSnippet(snippet_template);
  return editorActionResultToBinary(result, out_size);
}

const uint8_t* editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return nullBinaryPayload(out_size);

  ByteCursor cursor(data, size);
  uint32_t group_count = 0;
  uint32_t range_count = 0;
  uint32_t string_blob_size = 0;
  if (!cursor.readU32(group_count) || !cursor.readU32(range_count) || !cursor.readU32(string_blob_size)) {
    return nullBinaryPayload(out_size);
  }

  size_t group_bytes = 0;
  size_t range_bytes = 0;
  size_t expected_payload = 0;
  if (mulOverflow(static_cast<size_t>(group_count), sizeof(uint32_t) * 3, group_bytes) ||
      mulOverflow(static_cast<size_t>(range_count), sizeof(uint32_t) * 5, range_bytes) ||
      addOverflow(group_bytes, range_bytes, expected_payload) ||
      addOverflow(expected_payload, static_cast<size_t>(string_blob_size), expected_payload) ||
      cursor.remaining() != expected_payload) {
    return nullBinaryPayload(out_size);
  }

  struct GroupRecord {
    uint32_t index;
    uint32_t text_offset;
    uint32_t text_len;
  };
  struct RangeRecord {
    uint32_t group_ordinal;
    uint32_t start_line;
    uint32_t start_column;
    uint32_t end_line;
    uint32_t end_column;
  };

  constexpr uint32_t kNullTextOffset = 0xFFFFFFFFu;
  Vector<GroupRecord> group_records;
  group_records.reserve(group_count);
  for (uint32_t i = 0; i < group_count; ++i) {
    GroupRecord record{};
    if (!cursor.readU32(record.index) || !cursor.readU32(record.text_offset) || !cursor.readU32(record.text_len)) {
      return nullBinaryPayload(out_size);
    }
    if (record.text_offset != kNullTextOffset) {
      size_t end = 0;
      if (addOverflow(static_cast<size_t>(record.text_offset), static_cast<size_t>(record.text_len), end) ||
          end > static_cast<size_t>(string_blob_size)) {
        return nullBinaryPayload(out_size);
      }
    }
    group_records.push_back(record);
  }

  Vector<RangeRecord> range_records;
  range_records.reserve(range_count);
  for (uint32_t i = 0; i < range_count; ++i) {
    RangeRecord record{};
    if (!cursor.readU32(record.group_ordinal) ||
        !cursor.readU32(record.start_line) ||
        !cursor.readU32(record.start_column) ||
        !cursor.readU32(record.end_line) ||
        !cursor.readU32(record.end_column)) {
      return nullBinaryPayload(out_size);
    }
    if (record.group_ordinal >= group_count) {
      return nullBinaryPayload(out_size);
    }
    range_records.push_back(record);
  }

  const uint8_t* string_blob = nullptr;
  if (!cursor.readBytes(string_blob, static_cast<size_t>(string_blob_size)) || cursor.remaining() != 0) {
    return nullBinaryPayload(out_size);
  }

  LinkedEditingModel model;
  model.groups.resize(group_count);
  for (uint32_t i = 0; i < group_count; ++i) {
    const GroupRecord& record = group_records[i];
    TabStopGroup group;
    group.index = record.index;
    if (record.text_offset != kNullTextOffset && record.text_len > 0) {
      const char* text_ptr = reinterpret_cast<const char*>(string_blob + record.text_offset);
      group.default_text = U8String(text_ptr, text_ptr + record.text_len);
    }
    model.groups[i] = std::move(group);
  }

  for (const RangeRecord& record : range_records) {
    model.groups[record.group_ordinal].ranges.push_back({
      {static_cast<size_t>(record.start_line), static_cast<size_t>(record.start_column)},
      {static_cast<size_t>(record.end_line), static_cast<size_t>(record.end_column)}
    });
  }
  return editorActionResultToBinary(editor_core->startLinkedEditing(std::move(model)), out_size);
}

int editor_is_in_linked_editing(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->isInLinkedEditing() ? 1 : 0;
}

const uint8_t* editor_linked_editing_next(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->linkedEditingNextTabStop(), out_size);
}

const uint8_t* editor_linked_editing_prev(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->linkedEditingPrevTabStop(), out_size);
}

const uint8_t* editor_cancel_linked_editing(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->cancelLinkedEditing(), out_size);
}

void free_u16_string(intptr_t string_ptr) {
  U16Char* ptr = reinterpret_cast<U16Char*>(string_ptr);
  delete[] ptr;
}

void free_u8_string(intptr_t string_ptr) {
  char* ptr = reinterpret_cast<char*>(string_ptr);
  delete[] ptr;
}

void free_binary_data(intptr_t data_ptr) {
  const uint8_t* ptr = reinterpret_cast<const uint8_t*>(data_ptr);
  delete[] ptr;
}

#pragma endregion

#pragma region [IME]

int editor_is_composing(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isComposing() ? 1 : 0;
}

void editor_get_composing_range(intptr_t editor_handle,
                                int32_t* out_start_line,
                                int32_t* out_start_column,
                                int32_t* out_end_line,
                                int32_t* out_end_column) {
  if (out_start_line) *out_start_line = -1;
  if (out_start_column) *out_start_column = -1;
  if (out_end_line) *out_end_line = -1;
  if (out_end_column) *out_end_column = -1;

  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || !editor_core->isComposing()) {
    return;
  }

  const CompositionState& state = editor_core->getCompositionState();
  if (!state.is_composing || !state.visible) {
    return;
  }

  TextRange range = state.anchor_range.start == state.anchor_range.end
      ? TextRange {state.start_position, {state.start_position.line, state.start_position.column + state.composing_columns}}
      : state.anchor_range;
  if (out_start_line) *out_start_line = static_cast<int32_t>(range.start.line);
  if (out_start_column) *out_start_column = static_cast<int32_t>(range.start.column);
  if (out_end_line) *out_end_line = static_cast<int32_t>(range.end.line);
  if (out_end_column) *out_end_column = static_cast<int32_t>(range.end.column);
}

void editor_get_composing_session_range(intptr_t editor_handle,
                                        int32_t* out_start_line,
                                        int32_t* out_start_column,
                                        int32_t* out_end_line,
                                        int32_t* out_end_column) {
  if (out_start_line) *out_start_line = -1;
  if (out_start_column) *out_start_column = -1;
  if (out_end_line) *out_end_line = -1;
  if (out_end_column) *out_end_column = -1;

  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || !editor_core->hasComposingSession()) {
    return;
  }

  const CompositionState& state = editor_core->getCompositionState();
  if (!state.has_session) {
    return;
  }

  TextRange range = state.anchor_range.start == state.anchor_range.end
      ? TextRange {state.start_position, {state.start_position.line, state.start_position.column + state.composing_columns}}
      : state.anchor_range;
  if (out_start_line) *out_start_line = static_cast<int32_t>(range.start.line);
  if (out_start_column) *out_start_column = static_cast<int32_t>(range.start.column);
  if (out_end_line) *out_end_line = static_cast<int32_t>(range.end.line);
  if (out_end_column) *out_end_column = static_cast<int32_t>(range.end.column);
}

const uint8_t* editor_ime_update_preedit(intptr_t editor_handle,
                                         const char* text,
                                         int script_hint,
                                         size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->updateImePreedit(
      text != nullptr ? text : "",
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_set_composing_text(intptr_t editor_handle,
                                             const char* text,
                                             int cursor_offset,
                                             int script_hint,
                                             size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->setImeComposingText(
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_set_composing_text_selection(intptr_t editor_handle,
                                                       const char* text,
                                                       size_t selection_start_offset,
                                                       size_t selection_end_offset,
                                                       int script_hint,
                                                       size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->setImeComposingText(
      text != nullptr ? text : "",
      selection_start_offset,
      selection_end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_commit_text(intptr_t editor_handle,
                                      const char* text,
                                      int script_hint,
                                      size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->commitImeText(
      text != nullptr ? text : "",
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_commit_text_with_cursor(intptr_t editor_handle,
                                                  const char* text,
                                                  int cursor_offset,
                                                  int script_hint,
                                                  size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->commitImeText(
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_finish_preedit(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->finishImePreedit(), out_size);
}

const uint8_t* editor_ime_cancel_preedit(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->cancelImePreedit(), out_size);
}

const uint8_t* editor_ime_mark_document_range(intptr_t editor_handle,
                                              size_t start_line,
                                              size_t start_column,
                                              size_t end_line,
                                              size_t end_column,
                                              int script_hint,
                                              size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->markImeDocumentRange(
      {{start_line, start_column}, {end_line, end_column}},
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_mark_document_range_by_offset(intptr_t editor_handle,
                                                        size_t start_offset,
                                                        size_t end_offset,
                                                        int script_hint,
                                                        size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->markImeDocumentRange(
      start_offset,
      end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_replace_text(intptr_t editor_handle,
                                       size_t start_line,
                                       size_t start_column,
                                       size_t end_line,
                                       size_t end_column,
                                       const char* text,
                                       int script_hint,
                                       size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->replaceImeText(
      {{start_line, start_column}, {end_line, end_column}},
      text != nullptr ? text : "",
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_replace_document_text(intptr_t editor_handle,
                                                size_t start_offset,
                                                size_t end_offset,
                                                const char* text,
                                                int cursor_offset,
                                                int script_hint,
                                                size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->replaceImeDocumentText(
      start_offset,
      end_offset,
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_replace_input_context_text(intptr_t editor_handle,
                                                     size_t start_offset,
                                                     size_t end_offset,
                                                     const char* text,
                                                     int cursor_offset,
                                                     int script_hint,
                                                     size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->replaceImeInputContextText(
      start_offset,
      end_offset,
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_mark_input_context_range(intptr_t editor_handle,
                                                   size_t start_offset,
                                                   size_t end_offset,
                                                   int script_hint,
                                                   size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->markImeInputContextRange(
      start_offset,
      end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_notify_document_selection_changed(intptr_t editor_handle,
                                                            size_t start_offset,
                                                            size_t end_offset,
                                                            size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->notifyImeDocumentSelectionChanged(
      start_offset,
      end_offset), out_size);
}

const uint8_t* editor_ime_notify_input_context_selection_changed(intptr_t editor_handle,
                                                                 size_t start_offset,
                                                                 size_t end_offset,
                                                                 size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->notifyImeInputContextSelectionChanged(
      start_offset,
      end_offset), out_size);
}

const uint8_t* editor_ime_update_input_state_text(intptr_t editor_handle,
                                                  uint64_t context_id,
                                                  int32_t document_start_offset,
                                                  const char* text,
                                                  int32_t selection_start_offset,
                                                  int32_t selection_end_offset,
                                                  int32_t composing_start_offset,
                                                  int32_t composing_end_offset,
                                                  int script_hint,
                                                  size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->updateImeInputStateText(
      context_id,
      document_start_offset,
      text != nullptr ? text : "",
      selection_start_offset,
      selection_end_offset,
      composing_start_offset,
      composing_end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_update_text_model_state(intptr_t editor_handle,
                                                  int mode,
                                                  uint64_t context_id,
                                                  int32_t document_start_offset,
                                                  const char* text,
                                                  int32_t selection_start_offset,
                                                  int32_t selection_end_offset,
                                                  int32_t composing_start_offset,
                                                  int32_t composing_end_offset,
                                                  int script_hint,
                                                  size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->updateImeTextModelState(
      static_cast<ImeTextModelMode>(mode),
      context_id,
      document_start_offset,
      text != nullptr ? text : "",
      selection_start_offset,
      selection_end_offset,
      composing_start_offset,
      composing_end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_update_text_model_delta(intptr_t editor_handle,
                                                  int mode,
                                                  uint64_t context_id,
                                                  int32_t document_start_offset,
                                                  const char* old_text,
                                                  int32_t delta_start_offset,
                                                  int32_t delta_end_offset,
                                                  const char* delta_text,
                                                  int32_t selection_start_offset,
                                                  int32_t selection_end_offset,
                                                  int32_t composing_start_offset,
                                                  int32_t composing_end_offset,
                                                  int script_hint,
                                                  size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->updateImeTextModelDelta(
      static_cast<ImeTextModelMode>(mode),
      context_id,
      document_start_offset,
      old_text != nullptr ? old_text : "",
      delta_start_offset,
      delta_end_offset,
      delta_text != nullptr ? delta_text : "",
      selection_start_offset,
      selection_end_offset,
      composing_start_offset,
      composing_end_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_update_input_state_selection(intptr_t editor_handle,
                                                       uint64_t context_id,
                                                       int32_t document_start_offset,
                                                       int32_t selection_start_offset,
                                                       int32_t selection_end_offset,
                                                       size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->updateImeInputStateSelection(
      context_id,
      document_start_offset,
      selection_start_offset,
      selection_end_offset), out_size);
}

const uint8_t* editor_ime_replace_input_state_text(intptr_t editor_handle,
                                                   uint64_t context_id,
                                                   int32_t document_start_offset,
                                                   size_t start_offset,
                                                   size_t end_offset,
                                                   const char* text,
                                                   int cursor_offset,
                                                   int script_hint,
                                                   size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->replaceImeInputStateText(
      context_id,
      document_start_offset,
      start_offset,
      end_offset,
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_commit_input_state_text_replacement(intptr_t editor_handle,
                                                              uint64_t context_id,
                                                              int32_t document_start_offset,
                                                              size_t start_offset,
                                                              size_t end_offset,
                                                              const char* text,
                                                              int cursor_offset,
                                                              int script_hint,
                                                              size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->commitImeInputStateTextReplacement(
      context_id,
      document_start_offset,
      start_offset,
      end_offset,
      text != nullptr ? text : "",
      cursor_offset,
      static_cast<ImeScriptClass>(script_hint)), out_size);
}

const uint8_t* editor_ime_delete_backward(intptr_t editor_handle,
                                          size_t before_length,
                                          int text_unit,
                                          size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->deleteImeBackward(
      before_length,
      static_cast<ImeTextUnit>(text_unit)), out_size);
}

const uint8_t* editor_ime_delete_forward(intptr_t editor_handle,
                                         size_t after_length,
                                         int text_unit,
                                         size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->deleteImeForward(
      after_length,
      static_cast<ImeTextUnit>(text_unit)), out_size);
}

const uint8_t* editor_ime_delete_surrounding(intptr_t editor_handle,
                                             size_t before_length,
                                             size_t after_length,
                                             int text_unit,
                                             size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->deleteImeSurrounding(
      before_length,
      after_length,
      static_cast<ImeTextUnit>(text_unit)), out_size);
}

const uint8_t* editor_ime_notify_selection_changed(intptr_t editor_handle,
                                                   size_t start_line,
                                                   size_t start_column,
                                                   size_t end_line,
                                                   size_t end_column,
                                                   size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->notifyImeSelectionChanged(
      {{start_line, start_column}, {end_line, end_column}}), out_size);
}

const uint8_t* editor_ime_notify_cursor_changed(intptr_t editor_handle,
                                                size_t cursor_line,
                                                size_t cursor_column,
                                                size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return editorActionResultToBinary(editor_core->notifyImeCursorChanged(
      {cursor_line, cursor_column}), out_size);
}

const uint8_t* editor_ime_set_keyboard_script_class(intptr_t editor_handle, int script_class, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(
      editor_core->setImeKeyboardScriptClass(static_cast<ImeScriptClass>(script_class)),
      out_size);
}

int editor_ime_get_keyboard_script_class(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return static_cast<int>(ImeScriptClass::UNKNOWN);
  }
  return static_cast<int>(editor_core->getImeKeyboardScriptClass());
}

const uint8_t* editor_get_ime_sync_snapshot(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return imeSyncSnapshotToBinary(editor_core->getImeSyncSnapshot(), out_size);
}

const uint8_t* editor_get_ime_input_context(intptr_t editor_handle,
                                            size_t before_length,
                                            size_t after_length,
                                            size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return imeInputContextToBinary(editor_core->getImeInputContext(before_length, after_length), out_size);
}

const uint8_t* editor_get_ime_text_model_input_context(intptr_t editor_handle,
                                                       int mode,
                                                       size_t before_length,
                                                       size_t after_length,
                                                       size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return imeInputContextToBinary(editor_core->getImeTextModelInputContext(
      static_cast<ImeTextModelMode>(mode),
      before_length,
      after_length), out_size);
}

#pragma endregion

#ifdef _WIN32
LONG WINAPI MyUnhandledExceptionFilter(PEXCEPTION_POINTERS pExceptionInfo) {
  HANDLE hFile = CreateFileW(L"SweetEditor_Crash.dmp",
                            GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, NULL);
  if (hFile != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION dumpInfo;
    dumpInfo.ThreadId = GetCurrentThreadId();
    dumpInfo.ExceptionPointers = pExceptionInfo;
    dumpInfo.ClientPointers = FALSE;
    MiniDumpWriteDump(GetCurrentProcess(),
                     GetCurrentProcessId(),
                     hFile,
                     MiniDumpNormal,
                     &dumpInfo,
                     NULL,
                     NULL);
    CloseHandle(hFile);
  }
  return EXCEPTION_EXECUTE_HANDLER;
}

void init_unhandled_exception_handler() {
  SetUnhandledExceptionFilter(MyUnhandledExceptionFilter);
}
#endif

}
