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
#include <utility.h>
#include <editor_core.h>
#include <document.h>
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

static void appendI32(std::vector<uint8_t>& buffer, int32_t value) {
  const auto* src = reinterpret_cast<const uint8_t*>(&value);
  buffer.insert(buffer.end(), src, src + sizeof(value));
}

static void appendF32(std::vector<uint8_t>& buffer, float value) {
  const auto* src = reinterpret_cast<const uint8_t*>(&value);
  buffer.insert(buffer.end(), src, src + sizeof(value));
}

static void appendBool(std::vector<uint8_t>& buffer, bool value) {
  appendI32(buffer, value ? 1 : 0);
}

static void appendU8String(std::vector<uint8_t>& buffer, const U8String& value) {
  appendI32(buffer, static_cast<int32_t>(value.size()));
  const auto* src = reinterpret_cast<const uint8_t*>(value.data());
  buffer.insert(buffer.end(), src, src + value.size());
}

static void appendU16AsU8String(std::vector<uint8_t>& buffer, const U16String& value) {
  U8String u8_text;
  if (!value.empty()) {
    StrUtil::convertUTF16ToUTF8(value, u8_text);
  }
  appendU8String(buffer, u8_text);
}

static void appendPoint(std::vector<uint8_t>& buffer, const PointF& point) {
  appendF32(buffer, point.x);
  appendF32(buffer, point.y);
}

static void appendTextPosition(std::vector<uint8_t>& buffer, const TextPosition& position) {
  appendI32(buffer, static_cast<int32_t>(position.line));
  appendI32(buffer, static_cast<int32_t>(position.column));
}

static void appendTextStyle(std::vector<uint8_t>& buffer, const TextStyle& style) {
  appendI32(buffer, style.color);
  appendI32(buffer, style.background_color);
  appendI32(buffer, style.font_style);
}

static void appendVisualRun(std::vector<uint8_t>& buffer, const VisualRun& run) {
  appendI32(buffer, static_cast<int32_t>(run.type));
  appendF32(buffer, run.x);
  appendF32(buffer, run.y);
  appendU16AsU8String(buffer, run.text);
  appendTextStyle(buffer, run.style);
  appendI32(buffer, run.icon_id);
  appendI32(buffer, run.color_value);
  appendF32(buffer, run.width);
  appendF32(buffer, run.padding);
  appendF32(buffer, run.margin);
}

static void appendVisualLine(std::vector<uint8_t>& buffer, const VisualLine& line) {
  appendI32(buffer, static_cast<int32_t>(line.logical_line));
  appendI32(buffer, static_cast<int32_t>(line.wrap_index));
  appendPoint(buffer, line.line_number_position);
  appendBool(buffer, line.is_phantom_line);
  appendI32(buffer, static_cast<int32_t>(line.fold_state));
  appendI32(buffer, static_cast<int32_t>(line.runs.size()));
  for (const auto& run : line.runs) {
    appendVisualRun(buffer, run);
  }
}

static void appendGutterIconRenderItem(std::vector<uint8_t>& buffer, const GutterIconRenderItem& item) {
  appendI32(buffer, static_cast<int32_t>(item.logical_line));
  appendI32(buffer, item.icon_id);
  appendPoint(buffer, item.origin);
  appendF32(buffer, item.width);
  appendF32(buffer, item.height);
}

static void appendFoldMarkerRenderItem(std::vector<uint8_t>& buffer, const FoldMarkerRenderItem& item) {
  appendI32(buffer, static_cast<int32_t>(item.logical_line));
  appendI32(buffer, static_cast<int32_t>(item.fold_state));
  appendPoint(buffer, item.origin);
  appendF32(buffer, item.width);
  appendF32(buffer, item.height);
}

static void appendCursor(std::vector<uint8_t>& buffer, const Cursor& cursor) {
  appendTextPosition(buffer, cursor.text_position);
  appendPoint(buffer, cursor.position);
  appendF32(buffer, cursor.height);
  appendBool(buffer, cursor.visible);
  appendBool(buffer, cursor.show_dragger);
}

static void appendSelectionRect(std::vector<uint8_t>& buffer, const SelectionRect& rect) {
  appendPoint(buffer, rect.origin);
  appendF32(buffer, rect.width);
  appendF32(buffer, rect.height);
}

static void appendSelectionHandle(std::vector<uint8_t>& buffer, const SelectionHandle& handle) {
  appendPoint(buffer, handle.position);
  appendF32(buffer, handle.height);
  appendBool(buffer, handle.visible);
}

static void appendCompositionDecoration(std::vector<uint8_t>& buffer, const CompositionDecoration& decoration) {
  appendBool(buffer, decoration.active);
  appendPoint(buffer, decoration.origin);
  appendF32(buffer, decoration.width);
  appendF32(buffer, decoration.height);
}

static void appendGuideSegment(std::vector<uint8_t>& buffer, const GuideSegment& segment) {
  appendI32(buffer, static_cast<int32_t>(segment.direction));
  appendI32(buffer, static_cast<int32_t>(segment.type));
  appendI32(buffer, static_cast<int32_t>(segment.style));
  appendPoint(buffer, segment.start);
  appendPoint(buffer, segment.end);
  appendBool(buffer, segment.arrow_end);
}

static void appendDiagnosticDecoration(std::vector<uint8_t>& buffer, const DiagnosticDecoration& decoration) {
  appendPoint(buffer, decoration.origin);
  appendF32(buffer, decoration.width);
  appendF32(buffer, decoration.height);
  appendI32(buffer, decoration.severity);
  appendI32(buffer, decoration.color);
}

static void appendLinkedEditingRect(std::vector<uint8_t>& buffer, const LinkedEditingRect& rect) {
  appendPoint(buffer, rect.origin);
  appendF32(buffer, rect.width);
  appendF32(buffer, rect.height);
  appendBool(buffer, rect.is_active);
}

static void appendBracketHighlightRect(std::vector<uint8_t>& buffer, const BracketHighlightRect& rect) {
  appendPoint(buffer, rect.origin);
  appendF32(buffer, rect.width);
  appendF32(buffer, rect.height);
}

static void appendScrollbarRect(std::vector<uint8_t>& buffer, const ScrollbarRect& rect) {
  appendPoint(buffer, rect.origin);
  appendF32(buffer, rect.width);
  appendF32(buffer, rect.height);
}

static void appendScrollbarModel(std::vector<uint8_t>& buffer, const ScrollbarModel& scrollbar) {
  appendBool(buffer, scrollbar.visible);
  appendF32(buffer, scrollbar.alpha);
  appendScrollbarRect(buffer, scrollbar.track);
  appendScrollbarRect(buffer, scrollbar.thumb);
}

static const uint8_t* editorRenderModelToBinary(const EditorRenderModel& model, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(1024);
  appendF32(buffer, model.split_x);
  appendBool(buffer, model.split_line_visible);
  appendF32(buffer, model.scroll_x);
  appendF32(buffer, model.scroll_y);
  appendF32(buffer, model.viewport_width);
  appendF32(buffer, model.viewport_height);
  appendPoint(buffer, model.current_line);
  appendI32(buffer, static_cast<int32_t>(model.current_line_render_mode));

  appendI32(buffer, static_cast<int32_t>(model.lines.size()));
  for (const auto& line : model.lines) {
    appendVisualLine(buffer, line);
  }

  appendI32(buffer, static_cast<int32_t>(model.gutter_icons.size()));
  for (const auto& icon : model.gutter_icons) {
    appendGutterIconRenderItem(buffer, icon);
  }

  appendI32(buffer, static_cast<int32_t>(model.fold_markers.size()));
  for (const auto& marker : model.fold_markers) {
    appendFoldMarkerRenderItem(buffer, marker);
  }

  appendCursor(buffer, model.cursor);

  appendI32(buffer, static_cast<int32_t>(model.selection_rects.size()));
  for (const auto& rect : model.selection_rects) {
    appendSelectionRect(buffer, rect);
  }

  appendSelectionHandle(buffer, model.selection_start_handle);
  appendSelectionHandle(buffer, model.selection_end_handle);
  appendCompositionDecoration(buffer, model.composition_decoration);

  appendI32(buffer, static_cast<int32_t>(model.guide_segments.size()));
  for (const auto& segment : model.guide_segments) {
    appendGuideSegment(buffer, segment);
  }

  appendI32(buffer, static_cast<int32_t>(model.diagnostic_decorations.size()));
  for (const auto& decoration : model.diagnostic_decorations) {
    appendDiagnosticDecoration(buffer, decoration);
  }

  appendI32(buffer, static_cast<int32_t>(model.max_gutter_icons));

  appendI32(buffer, static_cast<int32_t>(model.linked_editing_rects.size()));
  for (const auto& rect : model.linked_editing_rects) {
    appendLinkedEditingRect(buffer, rect);
  }

  appendI32(buffer, static_cast<int32_t>(model.bracket_highlight_rects.size()));
  for (const auto& rect : model.bracket_highlight_rects) {
    appendBracketHighlightRect(buffer, rect);
  }

  // Optional payload tail (append-only): scrollbar render models.
  appendScrollbarModel(buffer, model.vertical_scrollbar);
  appendScrollbarModel(buffer, model.horizontal_scrollbar);

  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static void appendTextEditChanges(std::vector<uint8_t>& buffer, const std::vector<TextChange>& changes) {
  appendI32(buffer, static_cast<int32_t>(changes.size()));
  for (const auto& change : changes) {
    appendI32(buffer, static_cast<int32_t>(change.range.start.line));
    appendI32(buffer, static_cast<int32_t>(change.range.start.column));
    appendI32(buffer, static_cast<int32_t>(change.range.end.line));
    appendI32(buffer, static_cast<int32_t>(change.range.end.column));
    appendU8String(buffer, change.new_text);
  }
}

static const uint8_t* textEditResultToBinary(const TextEditResult& result, size_t* out_size) {
  if (!result.changed) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(int32_t) * 2 + result.changes.size() * (sizeof(int32_t) * 5));
  appendI32(buffer, 1);  // changed
  appendTextEditChanges(buffer, result.changes);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* keyEventResultToBinary(const KeyEventResult& result, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(int32_t) * 6);
  appendI32(buffer, result.handled ? 1 : 0);
  appendI32(buffer, result.content_changed ? 1 : 0);
  appendI32(buffer, result.cursor_changed ? 1 : 0);
  appendI32(buffer, result.selection_changed ? 1 : 0);

  const bool has_edit = result.content_changed && result.edit_result.changed;
  appendI32(buffer, has_edit ? 1 : 0);
  if (has_edit) {
    appendTextEditChanges(buffer, result.edit_result.changes);
  }
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static bool gestureTypeHasTapPoint(GestureType type) {
  return type == GestureType::TAP ||
    type == GestureType::DOUBLE_TAP ||
    type == GestureType::LONG_PRESS ||
    type == GestureType::DRAG_SELECT ||
    type == GestureType::CONTEXT_MENU;
}

static const uint8_t* gestureResultToBinary(const GestureResult& result, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(80);
  appendI32(buffer, static_cast<int32_t>(result.type));
  if (gestureTypeHasTapPoint(result.type)) {
    appendF32(buffer, result.tap_point.x);
    appendF32(buffer, result.tap_point.y);
  }

  appendI32(buffer, static_cast<int32_t>(result.cursor_position.line));
  appendI32(buffer, static_cast<int32_t>(result.cursor_position.column));
  appendI32(buffer, result.has_selection ? 1 : 0);
  appendI32(buffer, static_cast<int32_t>(result.selection.start.line));
  appendI32(buffer, static_cast<int32_t>(result.selection.start.column));
  appendI32(buffer, static_cast<int32_t>(result.selection.end.line));
  appendI32(buffer, static_cast<int32_t>(result.selection.end.column));
  appendF32(buffer, result.view_scroll_x);
  appendF32(buffer, result.view_scroll_y);
  appendF32(buffer, result.view_scale);
  appendI32(buffer, static_cast<int32_t>(static_cast<uint8_t>(result.hit_target.type)));
  appendI32(buffer, static_cast<int32_t>(result.hit_target.line));
  appendI32(buffer, static_cast<int32_t>(result.hit_target.column));
  appendI32(buffer, static_cast<int32_t>(result.hit_target.icon_id));
  appendI32(buffer, static_cast<int32_t>(result.hit_target.color_value));
  appendI32(buffer, result.needs_edge_scroll ? 1 : 0);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* scrollMetricsToBinary(const ScrollMetrics& metrics, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(float) * 11 + sizeof(int32_t) * 2);
  appendF32(buffer, metrics.scale);
  appendF32(buffer, metrics.scroll_x);
  appendF32(buffer, metrics.scroll_y);
  appendF32(buffer, metrics.max_scroll_x);
  appendF32(buffer, metrics.max_scroll_y);
  appendF32(buffer, metrics.content_width);
  appendF32(buffer, metrics.content_height);
  appendF32(buffer, metrics.viewport_width);
  appendF32(buffer, metrics.viewport_height);
  appendF32(buffer, metrics.text_area_x);
  appendF32(buffer, metrics.text_area_width);
  appendI32(buffer, metrics.can_scroll_x ? 1 : 0);
  appendI32(buffer, metrics.can_scroll_y ? 1 : 0);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* layoutMetricsToBinary(const LayoutMetrics& metrics, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(float) * 8 + sizeof(int32_t) * 3);
  appendF32(buffer, metrics.font_height);
  appendF32(buffer, metrics.font_ascent);
  appendF32(buffer, metrics.line_spacing_add);
  appendF32(buffer, metrics.line_spacing_mult);
  appendF32(buffer, metrics.line_number_margin);
  appendF32(buffer, metrics.line_number_width);
  appendI32(buffer, static_cast<int32_t>(metrics.max_gutter_icons));
  appendF32(buffer, metrics.inlay_hint_padding);
  appendF32(buffer, metrics.inlay_hint_margin);
  appendI32(buffer, static_cast<int32_t>(metrics.fold_arrow_mode));
  appendI32(buffer, metrics.has_fold_regions ? 1 : 0);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
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

#pragma region Document API

intptr_t create_document_from_utf16(const U16Char* text) {
  Ptr<Document> document = makePtr<LineArrayDocument>(text);
  return toIntPtr(document);
}

intptr_t create_document_from_file(const char* path) {
  UPtr<Buffer> buffer = makeUPtr<MappedFileBuffer>(path);
  Ptr<Document> document = makePtr<LineArrayDocument>(std::move(buffer));
  return toIntPtr(document);
}

void free_document(intptr_t document_handle) {
  deleteCPtrHolder<Document>(document_handle);
}

const char* get_document_text(intptr_t document_handle) {
  Ptr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return "";
  }
  U8String u8_text = document->getU8Text();
  char* result = new char[u8_text.size() + 1];
  std::strcpy(result, u8_text.c_str());
  return result;
}

size_t get_document_line_count(intptr_t document_handle) {
  Ptr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return 0;
  }
  return document->getLineCount();
}

const U16Char* get_document_line_text(intptr_t document_handle, size_t line) {
  Ptr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return CHAR16_NONE;
  }
  U16String u16_text = document->getLineU16Text(line);
  return StrUtil::allocU16Chars(u16_text);
}

#pragma endregion

#pragma region Construction/Initialization/Lifecycle

intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size) {
  Ptr<CTextMeasurer> c_measurer = makePtr<CTextMeasurer>(measurer);
  EditorOptions options;
  // Decode binary payload (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms, u64 max_undo_stack_size
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
    readF32(options.touch_slop);
    readI64(options.double_tap_timeout);
    readI64(options.long_press_ms);
    readU64(options.max_undo_stack_size);
  }
  Ptr<EditorCore> editor_core = makePtr<EditorCore>(c_measurer, options);
  return toIntPtr(editor_core);
}

void free_editor(intptr_t editor_handle) {
  deleteCPtrHolder<EditorCore>(editor_handle);
}

void set_editor_document(intptr_t editor_handle, intptr_t document_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  Ptr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return;
  }
  editor_core->loadDocument(document);
}

#pragma endregion

#pragma region Viewport/Font/Appearance Settings

void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setViewport({(float)width, (float)height});
}

void reset_editor_text_measurer(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->resetMeasurer();
}

void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setFoldArrowMode(static_cast<FoldArrowMode>(mode));
}

void editor_set_wrap_mode(intptr_t editor_handle, int mode) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setWrapMode(static_cast<WrapMode>(mode));
}

void editor_set_scale(intptr_t editor_handle, float scale) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setScale(scale);
}

void editor_set_line_spacing(intptr_t editor_handle, float add, float mult) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setLineSpacing(add, mult);
}

void editor_set_content_start_padding(intptr_t editor_handle, float padding) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setContentStartPadding(padding);
}

void editor_set_show_split_line(intptr_t editor_handle, int show) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setShowSplitLine(show != 0);
}

void editor_set_current_line_render_mode(intptr_t editor_handle, int mode) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setCurrentLineRenderMode(static_cast<CurrentLineRenderMode>(mode));
}

#pragma endregion

#pragma region Rendering

const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size) {
  PERF_TIMER("c_api::build_editor_render_model");
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return layoutMetricsToBinary(editor_core->getLayoutMetrics(), out_size);
}

#pragma endregion

#pragma region Gesture/Keyboard Event Handling

const uint8_t* handle_editor_gesture_event(intptr_t editor_handle, uint8_t type, uint8_t pointer_count,
    float* points, size_t* out_size) {
  return handle_editor_gesture_event_ex(editor_handle, type, pointer_count, points, 0, 0, 0, 1, out_size);
}

const uint8_t* handle_editor_gesture_event_ex(intptr_t editor_handle, uint8_t type, uint8_t pointer_count,
    float* points, uint8_t modifiers, float wheel_delta_x, float wheel_delta_y, float direct_scale, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || (pointer_count > 0 && points == nullptr)) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureEvent event;
  event.type = static_cast<EventType>(type);
  event.modifiers = static_cast<Modifier>(modifiers);
  event.wheel_delta_x = wheel_delta_x;
  event.wheel_delta_y = wheel_delta_y;
  event.direct_scale = direct_scale;
  for (int i = 0; i < pointer_count; i++) {
    event.points.push_back({points[i * 2], points[i * 2 + 1]});
  }
  GestureResult result = editor_core->handleGestureEvent(event);
  return gestureResultToBinary(result, out_size);
}

const uint8_t* editor_tick_edge_scroll(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureResult result = editor_core->tickEdgeScroll();
  return gestureResultToBinary(result, out_size);
}

const uint8_t* handle_editor_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  KeyEvent event;
  event.key_code = static_cast<KeyCode>(key_code);
  event.modifiers = static_cast<Modifier>(modifiers);
  if (text != nullptr) {
    event.text = text;
  }
  KeyEventResult result = editor_core->handleKeyEvent(event);
  return keyEventResultToBinary(result, out_size);
}

#pragma endregion

#pragma region Text Editing

const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || text == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->insertText(text);
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_replace_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || text == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextRange range = {{start_line, start_column}, {end_line, end_column}};
  TextEditResult result = editor_core->replaceText(range, text);
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_delete_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextRange range = {{start_line, start_column}, {end_line, end_column}};
  TextEditResult result = editor_core->deleteText(range);
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->backspace();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->deleteForward();
  return textEditResultToBinary(result, out_size);
}

#pragma endregion

#pragma region Line Operations

const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->moveLineUp();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->moveLineDown();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->copyLineUp();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->copyLineDown();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->deleteLine();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->insertLineAbove();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->insertLineBelow();
  return textEditResultToBinary(result, out_size);
}

#pragma endregion

#pragma region Undo/Redo

const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->undo();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->redo();
  return textEditResultToBinary(result, out_size);
}

int editor_can_undo(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canUndo() ? 1 : 0;
}

int editor_can_redo(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canRedo() ? 1 : 0;
}

#pragma endregion

#pragma region Cursor/Selection Management

void editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->setCursorPosition({line, column});
}

void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  TextPosition pos = editor_core->getCursorPosition();
  if (out_line) *out_line = pos.line;
  if (out_column) *out_column = pos.column;
}

void editor_select_all(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->selectAll();
}

void editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setSelection({{start_line, start_column}, {end_line, end_column}});
}

int editor_get_selection(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return "";
  }
  U8String selected = editor_core->getSelectedText();
  char* result = new char[selected.size() + 1];
  std::strcpy(result, selected.c_str());
  return result;
}

void editor_get_word_range_at_cursor(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  TextRange range = editor_core->getWordRangeAtCursor();
  if (out_start_line) *out_start_line = range.start.line;
  if (out_start_column) *out_start_column = range.start.column;
  if (out_end_line) *out_end_line = range.end.line;
  if (out_end_column) *out_end_column = range.end.column;
}

const char* editor_get_word_at_cursor(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return "";
  U8String word = editor_core->getWordAtCursor();
  char* result = new char[word.size() + 1];
  std::strcpy(result, word.c_str());
  return result;
}

#pragma endregion

#pragma region Cursor Movement

void editor_move_cursor_left(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorLeft(extend_selection != 0);
}

void editor_move_cursor_right(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorRight(extend_selection != 0);
}

void editor_move_cursor_up(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorUp(extend_selection != 0);
}

void editor_move_cursor_down(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorDown(extend_selection != 0);
}

void editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorToLineStart(extend_selection != 0);
}

void editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorToLineEnd(extend_selection != 0);
}

#pragma endregion

#pragma region IME Composition Input

void editor_composition_start(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->compositionStart();
}

void editor_composition_update(intptr_t editor_handle, const char* text) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->compositionUpdate(text != nullptr ? text : "");
}

const uint8_t* editor_composition_end(intptr_t editor_handle, const char* committed_text, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->compositionEnd(committed_text != nullptr ? committed_text : "");
  return textEditResultToBinary(result, out_size);
}

void editor_composition_cancel(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->compositionCancel();
}

int editor_is_composing(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isComposing() ? 1 : 0;
}

void editor_set_composition_enabled(intptr_t editor_handle, int enabled) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setCompositionEnabled(enabled != 0);
}

int editor_is_composition_enabled(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isCompositionEnabled() ? 1 : 0;
}

#pragma endregion

#pragma region Read-Only Mode

void editor_set_read_only(intptr_t editor_handle, int read_only) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setReadOnly(read_only != 0);
}

int editor_is_read_only(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isReadOnly() ? 1 : 0;
}

#pragma endregion

#pragma region Auto Indent

void editor_set_auto_indent_mode(intptr_t editor_handle, int mode) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setAutoIndentMode(static_cast<AutoIndentMode>(mode));
}

int editor_get_auto_indent_mode(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return static_cast<int>(editor_core->getAutoIndentMode());
}

#pragma endregion

#pragma region Handle Config

void editor_set_handle_config(intptr_t editor_handle,
    float radius, float center_dist, float line_width,
    float touch_padding, float drag_y_offset) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  HandleConfig config;
  config.radius = radius;
  config.center_dist = center_dist;
  config.line_width = line_width;
  config.touch_padding = touch_padding;
  config.drag_y_offset = drag_y_offset;
  editor_core->setHandleConfig(config);
}

#pragma endregion

#pragma region Scrollbar Config

void editor_set_scrollbar_config(intptr_t editor_handle,
    float thickness, float min_thumb, float thumb_hit_padding,
    int mode, int thumb_draggable, int track_tap_mode,
    int fade_delay_ms, int fade_duration_ms) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
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
  editor_core->setScrollbarConfig(config);
}

#pragma endregion

#pragma region Position Coordinate Query

void editor_get_position_rect(intptr_t editor_handle,
    size_t line, size_t column,
    float* out_x, float* out_y, float* out_height) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  CursorRect rect = editor_core->getPositionScreenRect({line, column});
  if (out_x) *out_x = rect.x;
  if (out_y) *out_y = rect.y;
  if (out_height) *out_height = rect.height;
}

void editor_get_cursor_rect(intptr_t editor_handle,
    float* out_x, float* out_y, float* out_height) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  CursorRect rect = editor_core->getCursorScreenRect();
  if (out_x) *out_x = rect.x;
  if (out_y) *out_y = rect.y;
  if (out_height) *out_height = rect.height;
}

#pragma endregion

#pragma region Scrolling/Navigation

void editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->scrollToLine(line, static_cast<ScrollBehavior>(behavior));
}

void editor_goto_position(intptr_t editor_handle, size_t line, size_t column) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->gotoPosition(line, column);
}

void editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setScroll(scroll_x, scroll_y);
}

const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size) {
  ScrollMetrics metrics {};
  metrics.scale = 1.0f;
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core != nullptr) {
    metrics = editor_core->getScrollMetrics();
  }
  return scrollMetricsToBinary(metrics, out_size);
}

#pragma endregion

#pragma region Style Registration + Highlight Spans

void editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->registerTextStyle(style_id, TextStyle{color, background_color, font_style});
}

void editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) {
    return;
  }

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t layer = 0;
  uint32_t span_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(layer) || !cursor.readU32(span_count)) {
    return;
  }

  size_t spans_bytes = 0;
  if (mulOverflow(static_cast<size_t>(span_count), sizeof(uint32_t) * 3, spans_bytes) || cursor.remaining() != spans_bytes) {
    return;
  }

  Vector<StyleSpan> spans;
  spans.reserve(span_count);
  for (uint32_t i = 0; i < span_count; ++i) {
    uint32_t column = 0;
    uint32_t length = 0;
    uint32_t style_id = 0;
    if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readU32(style_id)) {
      return;
    }
    spans.push_back(StyleSpan{column, length, style_id});
  }
  editor_core->setLineSpans(static_cast<size_t>(line), static_cast<SpanLayer>(layer), std::move(spans));
}

void editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t layer = 0;
  uint32_t entry_count = 0;
  if (!cursor.readU32(layer) || !cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<StyleSpan>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t span_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(span_count)) return;

    Vector<StyleSpan> spans;
    spans.reserve(span_count);
    for (uint32_t i = 0; i < span_count; ++i) {
      uint32_t column = 0;
      uint32_t length = 0;
      uint32_t style_id = 0;
      if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readU32(style_id)) return;
      spans.push_back(StyleSpan{column, length, style_id});
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(spans));
  }
  editor_core->setBatchLineSpans(static_cast<SpanLayer>(layer), std::move(entries));
}

void editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setLineSpans(line, static_cast<SpanLayer>(layer), {});
}

void editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearHighlights(static_cast<SpanLayer>(layer));
}

#pragma endregion

#pragma region InlayHint / PhantomText

void editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) {
    return;
  }

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t hint_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(hint_count)) {
    return;
  }

  Vector<InlayHint> hints;
  hints.reserve(hint_count);
  for (uint32_t i = 0; i < hint_count; ++i) {
    uint32_t type_val = 0;
    uint32_t column = 0;
    int32_t int_value = 0;
    uint32_t text_len = 0;
    if (!cursor.readU32(type_val) || !cursor.readU32(column) ||
        !cursor.readI32(int_value) || !cursor.readU32(text_len)) {
      return;
    }
    U8String text;
    if (text_len > 0) {
      const uint8_t* text_ptr = nullptr;
      if (!cursor.readBytes(text_ptr, text_len)) {
        return;
      }
      text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
    }
    InlayHint hint;
    hint.type = static_cast<InlayType>(type_val);
    hint.column = column;
    hint.text = std::move(text);
    hint.icon_id = (hint.type == InlayType::ICON) ? int_value : 0;
    hint.color = (hint.type == InlayType::COLOR) ? int_value : 0;
    hints.push_back(std::move(hint));
  }

  editor_core->setLineInlayHints(static_cast<size_t>(line), std::move(hints));
}

void editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<InlayHint>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t hint_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(hint_count)) return;

    Vector<InlayHint> hints;
    hints.reserve(hint_count);
    for (uint32_t i = 0; i < hint_count; ++i) {
      uint32_t type_val = 0;
      uint32_t column = 0;
      int32_t int_value = 0;
      uint32_t text_len = 0;
      if (!cursor.readU32(type_val) || !cursor.readU32(column) ||
          !cursor.readI32(int_value) || !cursor.readU32(text_len)) return;
      U8String text;
      if (text_len > 0) {
        const uint8_t* text_ptr = nullptr;
        if (!cursor.readBytes(text_ptr, text_len)) return;
        text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
      }
      InlayHint hint;
      hint.type = static_cast<InlayType>(type_val);
      hint.column = column;
      hint.text = std::move(text);
      hint.icon_id = (hint.type == InlayType::ICON) ? int_value : 0;
      hint.color = (hint.type == InlayType::COLOR) ? int_value : 0;
      hints.push_back(std::move(hint));
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(hints));
  }
  editor_core->setBatchLineInlayHints(std::move(entries));
}

void editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t phantom_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(phantom_count)) {
    return;
  }

  Vector<PhantomText> phantoms;
  phantoms.reserve(phantom_count);
  for (uint32_t i = 0; i < phantom_count; ++i) {
    uint32_t column = 0;
    uint32_t text_len = 0;
    if (!cursor.readU32(column) || !cursor.readU32(text_len)) {
      return;
    }
    U8String text;
    if (text_len > 0) {
      const uint8_t* text_ptr = nullptr;
      if (!cursor.readBytes(text_ptr, text_len)) {
        return;
      }
      text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
    }
    phantoms.push_back(PhantomText{column, std::move(text)});
  }

  editor_core->setLinePhantomTexts(static_cast<size_t>(line), std::move(phantoms));
}

void editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<PhantomText>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t phantom_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(phantom_count)) return;

    Vector<PhantomText> phantoms;
    phantoms.reserve(phantom_count);
    for (uint32_t i = 0; i < phantom_count; ++i) {
      uint32_t column = 0;
      uint32_t text_len = 0;
      if (!cursor.readU32(column) || !cursor.readU32(text_len)) return;
      U8String text;
      if (text_len > 0) {
        const uint8_t* text_ptr = nullptr;
        if (!cursor.readBytes(text_ptr, text_len)) return;
        text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
      }
      phantoms.push_back(PhantomText{column, std::move(text)});
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(phantoms));
  }
  editor_core->setBatchLinePhantomTexts(std::move(entries));
}

#pragma endregion

#pragma region Gutter Icons

void editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t icon_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(icon_count)) {
    return;
  }

  size_t icons_bytes = 0;
  if (mulOverflow(static_cast<size_t>(icon_count), sizeof(int32_t), icons_bytes) ||
      cursor.remaining() != icons_bytes) {
    return;
  }

  Vector<GutterIcon> icons;
  icons.reserve(icon_count);
  for (uint32_t i = 0; i < icon_count; ++i) {
    int32_t icon_id = 0;
    if (!cursor.readI32(icon_id)) {
      return;
    }
    icons.push_back(GutterIcon{icon_id});
  }
  editor_core->setLineGutterIcons(static_cast<size_t>(line), std::move(icons));
}

void editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<GutterIcon>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t icon_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(icon_count)) return;

    Vector<GutterIcon> icons;
    icons.reserve(icon_count);
    for (uint32_t i = 0; i < icon_count; ++i) {
      int32_t icon_id = 0;
      if (!cursor.readI32(icon_id)) return;
      icons.push_back(GutterIcon{icon_id});
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(icons));
  }
  editor_core->setBatchLineGutterIcons(std::move(entries));
}

void editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setMaxGutterIcons(count);
}

#pragma endregion

#pragma region Diagnostic Decorations

void editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t diag_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(diag_count)) {
    return;
  }

  size_t diagnostics_bytes = 0;
  if (mulOverflow(static_cast<size_t>(diag_count), sizeof(uint32_t) * 4, diagnostics_bytes) ||
      cursor.remaining() != diagnostics_bytes) {
    return;
  }

  Vector<DiagnosticSpan> diagnostics;
  diagnostics.reserve(diag_count);
  for (uint32_t i = 0; i < diag_count; ++i) {
    uint32_t column = 0;
    uint32_t length = 0;
    int32_t severity = 0;
    int32_t color = 0;
    if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readI32(severity) || !cursor.readI32(color)) {
      return;
    }
    DiagnosticSpan ds;
    ds.column = column;
    ds.length = length;
    ds.severity = static_cast<DiagnosticSeverity>(severity);
    ds.color = color;
    diagnostics.push_back(ds);
  }
  editor_core->setLineDiagnostics(static_cast<size_t>(line), std::move(diagnostics));
}

void editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<DiagnosticSpan>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t diag_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(diag_count)) return;

    Vector<DiagnosticSpan> diagnostics;
    diagnostics.reserve(diag_count);
    for (uint32_t i = 0; i < diag_count; ++i) {
      uint32_t column = 0;
      uint32_t length = 0;
      int32_t severity = 0;
      int32_t color = 0;
      if (!cursor.readU32(column) || !cursor.readU32(length) ||
          !cursor.readI32(severity) || !cursor.readI32(color)) return;
      DiagnosticSpan ds;
      ds.column = column;
      ds.length = length;
      ds.severity = static_cast<DiagnosticSeverity>(severity);
      ds.color = color;
      diagnostics.push_back(ds);
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(diagnostics));
  }
  editor_core->setBatchLineDiagnostics(std::move(entries));
}

void editor_clear_diagnostics(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearDiagnostics();
}

#pragma endregion

#pragma region Guide (Code Structure Lines)

void editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t count = 0;
  if (!cursor.readU32(count)) return;

  size_t guide_bytes = 0;
  if (mulOverflow(static_cast<size_t>(count), sizeof(uint32_t) * 4, guide_bytes) ||
      cursor.remaining() != guide_bytes) {
    return;
  }

  Vector<IndentGuide> guides;
  guides.reserve(count);
  for (uint32_t i = 0; i < count; ++i) {
    uint32_t start_line = 0, start_column = 0, end_line = 0, end_column = 0;
    if (!cursor.readU32(start_line) || !cursor.readU32(start_column) ||
        !cursor.readU32(end_line) || !cursor.readU32(end_column)) {
      return;
    }
    guides.push_back(IndentGuide{{start_line, start_column}, {end_line, end_column}});
  }
  editor_core->setIndentGuides(std::move(guides));
}

void editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t count = 0;
  if (!cursor.readU32(count)) return;

  Vector<BracketGuide> guides;
  guides.reserve(count);
  for (uint32_t i = 0; i < count; ++i) {
    uint32_t parent_line = 0, parent_column = 0, end_line = 0, end_column = 0, child_count = 0;
    if (!cursor.readU32(parent_line) || !cursor.readU32(parent_column) ||
        !cursor.readU32(end_line) || !cursor.readU32(end_column) ||
        !cursor.readU32(child_count)) {
      return;
    }
    BracketGuide bg;
    bg.parent = {static_cast<size_t>(parent_line), static_cast<size_t>(parent_column)};
    bg.end = {static_cast<size_t>(end_line), static_cast<size_t>(end_column)};
    bg.children.reserve(child_count);
    for (uint32_t j = 0; j < child_count; ++j) {
      uint32_t child_line = 0, child_column = 0;
      if (!cursor.readU32(child_line) || !cursor.readU32(child_column)) {
        return;
      }
      bg.children.push_back({static_cast<size_t>(child_line), static_cast<size_t>(child_column)});
    }
    guides.push_back(std::move(bg));
  }
  editor_core->setBracketGuides(std::move(guides));
}

void editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t count = 0;
  if (!cursor.readU32(count)) return;

  size_t guide_bytes = 0;
  if (mulOverflow(static_cast<size_t>(count), sizeof(uint32_t) * 4, guide_bytes) ||
      cursor.remaining() != guide_bytes) {
    return;
  }

  Vector<FlowGuide> guides;
  guides.reserve(count);
  for (uint32_t i = 0; i < count; ++i) {
    uint32_t start_line = 0, start_column = 0, end_line = 0, end_column = 0;
    if (!cursor.readU32(start_line) || !cursor.readU32(start_column) ||
        !cursor.readU32(end_line) || !cursor.readU32(end_column)) {
      return;
    }
    guides.push_back(FlowGuide{{start_line, start_column}, {end_line, end_column}});
  }
  editor_core->setFlowGuides(std::move(guides));
}

void editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t count = 0;
  if (!cursor.readU32(count)) return;

  size_t guide_bytes = 0;
  if (mulOverflow(static_cast<size_t>(count), sizeof(uint32_t) * 4, guide_bytes) ||
      cursor.remaining() != guide_bytes) {
    return;
  }

  Vector<SeparatorGuide> guides;
  guides.reserve(count);
  for (uint32_t i = 0; i < count; ++i) {
    int32_t line = 0, style = 0, sym_count = 0;
    uint32_t text_end_column = 0;
    if (!cursor.readI32(line) || !cursor.readI32(style) ||
        !cursor.readI32(sym_count) || !cursor.readU32(text_end_column)) {
      return;
    }
    guides.push_back(SeparatorGuide{line, static_cast<SeparatorStyle>(style), sym_count, text_end_column});
  }
  editor_core->setSeparatorGuides(std::move(guides));
}

#pragma endregion

#pragma region Bracket Pair Highlight

void editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || open_chars == nullptr || close_chars == nullptr) return;
  Vector<BracketPair> pairs;
  pairs.reserve(count);
  for (size_t i = 0; i < count; ++i) {
    pairs.push_back({static_cast<char32_t>(open_chars[i]), static_cast<char32_t>(close_chars[i])});
  }
  editor_core->setBracketPairs(std::move(pairs));
}

void editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->setMatchedBrackets({open_line, open_col}, {close_line, close_col});
}

void editor_clear_matched_brackets(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearMatchedBrackets();
}

#pragma endregion

#pragma region Code Folding

void editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t fold_count = 0;
  if (!cursor.readU32(fold_count)) {
    return;
  }

  size_t fold_bytes = 0;
  if (mulOverflow(static_cast<size_t>(fold_count), sizeof(uint32_t) * 2, fold_bytes) || cursor.remaining() != fold_bytes) {
    return;
  }

  Vector<FoldRegion> regions;
  regions.reserve(fold_count);
  for (uint32_t i = 0; i < fold_count; ++i) {
    uint32_t start_line = 0;
    uint32_t end_line = 0;
    if (!cursor.readU32(start_line) || !cursor.readU32(end_line)) {
      return;
    }
    regions.push_back(FoldRegion{static_cast<size_t>(start_line), static_cast<size_t>(end_line)});
  }
  editor_core->setFoldRegions(std::move(regions));
}

int editor_toggle_fold(intptr_t editor_handle, size_t line) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->toggleFoldAt(line) ? 1 : 0;
}

int editor_fold_at(intptr_t editor_handle, size_t line) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->foldAt(line) ? 1 : 0;
}

int editor_unfold_at(intptr_t editor_handle, size_t line) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->unfoldAt(line) ? 1 : 0;
}

void editor_fold_all(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->foldAll();
}

void editor_unfold_all(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->unfoldAll();
}

int editor_is_line_visible(intptr_t editor_handle, size_t line) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 1;
  return editor_core->isLineVisible(line) ? 1 : 0;
}

#pragma endregion

#pragma region Clear Operations

void editor_clear_highlights(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearHighlights();
}

void editor_clear_inlay_hints(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearInlayHints();
}

void editor_clear_phantom_texts(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearPhantomTexts();
}

void editor_clear_gutter_icons(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearGutterIcons();
}

void editor_clear_guides(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearGuides();
}

void editor_clear_all_decorations(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearAllDecorations();
}

#pragma endregion

#pragma region Linked Editing (LinkedEditing)

const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || snippet_template == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->insertSnippet(snippet_template);
  return textEditResultToBinary(result, out_size);
}

void editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t group_count = 0;
  uint32_t range_count = 0;
  uint32_t string_blob_size = 0;
  if (!cursor.readU32(group_count) || !cursor.readU32(range_count) || !cursor.readU32(string_blob_size)) {
    return;
  }

  size_t group_bytes = 0;
  size_t range_bytes = 0;
  size_t expected_payload = 0;
  if (mulOverflow(static_cast<size_t>(group_count), sizeof(uint32_t) * 3, group_bytes) ||
      mulOverflow(static_cast<size_t>(range_count), sizeof(uint32_t) * 5, range_bytes) ||
      addOverflow(group_bytes, range_bytes, expected_payload) ||
      addOverflow(expected_payload, static_cast<size_t>(string_blob_size), expected_payload) ||
      cursor.remaining() != expected_payload) {
    return;
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
      return;
    }
    if (record.text_offset != kNullTextOffset) {
      size_t end = 0;
      if (addOverflow(static_cast<size_t>(record.text_offset), static_cast<size_t>(record.text_len), end) ||
          end > static_cast<size_t>(string_blob_size)) {
        return;
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
      return;
    }
    if (record.group_ordinal >= group_count) {
      return;
    }
    range_records.push_back(record);
  }

  const uint8_t* string_blob = nullptr;
  if (!cursor.readBytes(string_blob, static_cast<size_t>(string_blob_size)) || cursor.remaining() != 0) {
    return;
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
  editor_core->startLinkedEditing(std::move(model));
}

int editor_is_in_linked_editing(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->isInLinkedEditing() ? 1 : 0;
}

int editor_linked_editing_next(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->linkedEditingNextTabStop() ? 1 : 0;
}

int editor_linked_editing_prev(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->linkedEditingPrevTabStop() ? 1 : 0;
}

void editor_cancel_linked_editing(intptr_t editor_handle) {
  Ptr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->cancelLinkedEditing();
}

#pragma endregion

#pragma region Utilities/Memory Management

void free_u16_string(intptr_t string_ptr) {
  const U16Char* ptr = reinterpret_cast<const U16Char*>(string_ptr);
  delete[] ptr;
}

void free_binary_data(intptr_t data_ptr) {
  const uint8_t* ptr = reinterpret_cast<const uint8_t*>(data_ptr);
  delete[] ptr;
}

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

#pragma endregion

}

