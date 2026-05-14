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

static void appendI64(std::vector<uint8_t>& buffer, int64_t value) {
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

static void appendTextRange(std::vector<uint8_t>& buffer, const TextRange& range) {
  appendTextPosition(buffer, range.start);
  appendTextPosition(buffer, range.end);
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
  appendBool(buffer, run.active);
}

static void appendVisualLine(std::vector<uint8_t>& buffer, const VisualLine& line) {
  appendI32(buffer, static_cast<int32_t>(line.logical_line));
  appendI32(buffer, static_cast<int32_t>(line.wrap_index));
  appendPoint(buffer, line.line_number_position);
  appendI32(buffer, static_cast<int32_t>(line.kind));
  appendBool(buffer, line.owns_gutter_semantics);
  appendI32(buffer, static_cast<int32_t>(line.fold_state));
  appendI32(buffer, static_cast<int32_t>(line.runs.size()));
  for (const auto& run : line.runs) {
    appendVisualRun(buffer, run);
  }
}

static void appendRect(std::vector<uint8_t>& buffer, const Rect& rect) {
  appendPoint(buffer, rect.origin);
  appendF32(buffer, rect.width);
  appendF32(buffer, rect.height);
}

static void appendGutterIconRenderItem(std::vector<uint8_t>& buffer, const GutterIconRenderItem& item) {
  appendI32(buffer, static_cast<int32_t>(item.logical_line));
  appendI32(buffer, item.icon_id);
  appendRect(buffer, item.rect);
}

static void appendFoldMarkerRenderItem(std::vector<uint8_t>& buffer, const FoldMarkerRenderItem& item) {
  appendI32(buffer, static_cast<int32_t>(item.logical_line));
  appendI32(buffer, static_cast<int32_t>(item.fold_state));
  appendRect(buffer, item.rect);
}

static void appendCursor(std::vector<uint8_t>& buffer, const Cursor& cursor) {
  appendTextPosition(buffer, cursor.text_position);
  appendPoint(buffer, cursor.position);
  appendF32(buffer, cursor.height);
  appendBool(buffer, cursor.visible);
  appendBool(buffer, cursor.show_dragger);
}

static void appendSelectionHandle(std::vector<uint8_t>& buffer, const SelectionHandle& handle) {
  appendPoint(buffer, handle.position);
  appendF32(buffer, handle.height);
  appendBool(buffer, handle.visible);
}

static void appendCompositionDecoration(std::vector<uint8_t>& buffer, const CompositionDecoration& decoration) {
  appendBool(buffer, decoration.active);
  appendRect(buffer, decoration.rect);
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
  appendRect(buffer, decoration.rect);
  appendI32(buffer, decoration.severity);
}

static void appendLinkedEditingRect(std::vector<uint8_t>& buffer, const LinkedEditingRect& rect) {
  appendRect(buffer, rect.rect);
  appendBool(buffer, rect.is_active);
}

static void appendScrollbarModel(std::vector<uint8_t>& buffer, const ScrollbarModel& scrollbar) {
  appendBool(buffer, scrollbar.visible);
  appendF32(buffer, scrollbar.alpha);
  appendBool(buffer, scrollbar.thumb_active);
  appendRect(buffer, scrollbar.track);
  appendRect(buffer, scrollbar.thumb);
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
    appendRect(buffer, rect);
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
    appendRect(buffer, rect);
  }

  // Optional payload tail (append-only): scrollbar render models.
  appendScrollbarModel(buffer, model.vertical_scrollbar);
  appendScrollbarModel(buffer, model.horizontal_scrollbar);

  appendBool(buffer, model.gutter_sticky);
  appendBool(buffer, model.gutter_visible);
  appendI32(buffer, static_cast<int32_t>(model.pointer_cursor_type));

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

static void appendImeSyncSnapshot(std::vector<uint8_t>& buffer, const ImeSyncSnapshot& snapshot) {
  appendTextPosition(buffer, snapshot.cursor);
  appendBool(buffer, snapshot.has_selection);
  appendTextRange(buffer, snapshot.selection);
  appendBool(buffer, snapshot.has_composing_session);
  appendBool(buffer, snapshot.has_visible_composition_range);
  appendTextRange(buffer, snapshot.visible_composition_range);
  appendBool(buffer, snapshot.has_platform_marked_range);
  appendTextRange(buffer, snapshot.platform_marked_range);
  appendU8String(buffer, snapshot.platform_text_window_text);
  appendI32(buffer, snapshot.platform_text_window_start_offset);
  appendI32(buffer, snapshot.platform_text_window_selection_start_offset);
  appendI32(buffer, snapshot.platform_text_window_selection_end_offset);
  appendI32(buffer, snapshot.platform_text_window_composing_start_offset);
  appendI32(buffer, snapshot.platform_text_window_composing_end_offset);
  appendI32(buffer, static_cast<int32_t>(snapshot.preedit_storage));
  appendI32(buffer, static_cast<int32_t>(snapshot.context_policy));
  appendBool(buffer, snapshot.clear_platform_preedit);
}

static const uint8_t* imeSyncSnapshotToBinary(const ImeSyncSnapshot& snapshot, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(int32_t) * 29 + snapshot.platform_text_window_text.size());
  appendImeSyncSnapshot(buffer, snapshot);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* imeInputContextToBinary(const ImeInputContext& context, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(int32_t) * 8 + sizeof(int64_t) + context.text.size());
  appendI64(buffer, static_cast<int64_t>(context.id));
  appendI32(buffer, context.revision);
  appendI32(buffer, context.document_start_offset);
  appendU8String(buffer, context.text);
  appendI32(buffer, context.selection.start);
  appendI32(buffer, context.selection.end);
  appendBool(buffer, context.has_composition);
  appendI32(buffer, context.composition.start);
  appendI32(buffer, context.composition.end);
  return allocBinaryPayload(buffer.data(), buffer.size(), out_size);
}

static const uint8_t* imeActionResultToBinary(const ImeActionResult& result, size_t* out_size) {
  std::vector<uint8_t> buffer;
  buffer.reserve(sizeof(int32_t) * 36 + result.sync.platform_text_window_text.size());
  appendBool(buffer, result.handled);
  appendBool(buffer, result.content_changed);
  appendBool(buffer, result.cursor_changed);
  appendBool(buffer, result.selection_changed);
  const bool has_edit = result.content_changed && result.edit_result.changed;
  appendBool(buffer, has_edit);
  if (has_edit) {
    appendTextEditChanges(buffer, result.edit_result.changes);
  }
  appendImeSyncSnapshot(buffer, result.sync);
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
  appendI32(buffer, static_cast<int32_t>(result.command));
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
  appendI32(buffer, result.needs_fling ? 1 : 0);
  appendI32(buffer, result.needs_animation ? 1 : 0);
  appendI32(buffer, result.is_handle_drag ? 1 : 0);
  appendI32(buffer, static_cast<int32_t>(result.pointer_cursor_type));
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

void set_editor_document(intptr_t editor_handle, intptr_t document_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  SharedPtr<Document> document = getCPtrHolderValue<Document>(document_handle);
  if (document == nullptr) {
    return;
  }
  editor_core->loadDocument(document);
}

void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setViewport({(float)width, (float)height});
}

void editor_on_font_metrics_changed(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->onFontMetricsChanged();
}

void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setFoldArrowMode(static_cast<FoldArrowMode>(mode));
}

void editor_set_wrap_mode(intptr_t editor_handle, int mode) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setWrapMode(static_cast<WrapMode>(mode));
}

void editor_set_tab_size(intptr_t editor_handle, int tab_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setTabSize(static_cast<uint32_t>(tab_size));
}

void editor_set_scale(intptr_t editor_handle, float scale) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setScale(scale);
}

void editor_set_line_spacing(intptr_t editor_handle, float add, float mult) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setLineSpacing(add, mult);
}

void editor_set_content_start_padding(intptr_t editor_handle, float padding) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setContentStartPadding(padding);
}

void editor_set_show_split_line(intptr_t editor_handle, int show) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setShowSplitLine(show != 0);
}

void editor_set_current_line_render_mode(intptr_t editor_handle, int mode) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setCurrentLineRenderMode(static_cast<CurrentLineRenderMode>(mode));
}

void editor_set_gutter_sticky(intptr_t editor_handle, int sticky) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setGutterSticky(sticky != 0);
}

void editor_set_gutter_visible(intptr_t editor_handle, int visible) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setGutterVisible(visible != 0);
}

void editor_set_handle_config(intptr_t editor_handle,
    float start_left, float start_top, float start_right, float start_bottom,
    float end_left, float end_top, float end_right, float end_bottom) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  HandleConfig config;
  config.start_hit_offset = {start_left, start_top, start_right, start_bottom};
  config.end_hit_offset = {end_left, end_top, end_right, end_bottom};
  editor_core->setHandleConfig(config);
}

void editor_set_scrollbar_config(intptr_t editor_handle,
    float thickness, float min_thumb, float thumb_hit_padding,
    int mode, int thumb_draggable, int track_tap_mode,
    int fade_delay_ms, int fade_duration_ms) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  GestureResult result = editor_core->handleGestureEvent(event);
  return gestureResultToBinary(result, out_size);
}

const uint8_t* editor_tick_edge_scroll(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureResult result = editor_core->tickEdgeScroll();
  return gestureResultToBinary(result, out_size);
}

const uint8_t* editor_tick_fling(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureResult result = editor_core->tickFling();
  return gestureResultToBinary(result, out_size);
}

const uint8_t* editor_tick_animations(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  GestureResult result = editor_core->tickAnimations();
  return gestureResultToBinary(result, out_size);
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
  KeyEventResult result = editor_core->handleKeyEvent(event);
  return keyEventResultToBinary(result, out_size);
}

void editor_set_keymap(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr || size < 4) return;

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
  if (count == 0) return;

  const size_t per_binding = 1 + 2 + 1 + 2 + 4; // u8+u16+u8+u16+u32 = 10 bytes
  if (size < 4 + count * per_binding) return;

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
  editor_core->setKeyMap(std::move(km));
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
  TextEditResult result = editor_core->insertText(text);
  return textEditResultToBinary(result, out_size);
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
  TextEditResult result = editor_core->replaceText(range, text);
  return textEditResultToBinary(result, out_size);
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
  TextEditResult result = editor_core->deleteText(range);
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->deleteForward();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  TextEditResult result = editor_core->insertLineBelow();
  return textEditResultToBinary(result, out_size);
}

const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canUndo() ? 1 : 0;
}

int editor_can_redo(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->canRedo() ? 1 : 0;
}

void editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->setCursorPosition({line, column});
}

void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  TextPosition pos = editor_core->getCursorPosition();
  if (out_line) *out_line = pos.line;
  if (out_column) *out_column = pos.column;
}

void editor_select_all(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->selectAll();
}

void editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setSelection({{start_line, start_column}, {end_line, end_column}});
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

void editor_move_cursor_left(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorLeft(extend_selection != 0);
}

void editor_move_cursor_right(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorRight(extend_selection != 0);
}

void editor_move_cursor_up(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorUp(extend_selection != 0);
}

void editor_move_cursor_down(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorDown(extend_selection != 0);
}

void editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorToLineStart(extend_selection != 0);
}

void editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->moveCursorToLineEnd(extend_selection != 0);
}

void editor_set_read_only(intptr_t editor_handle, int read_only) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setReadOnly(read_only != 0);
}

int editor_is_read_only(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->isReadOnly() ? 1 : 0;
}

void editor_set_auto_indent_mode(intptr_t editor_handle, int mode) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setAutoIndentMode(static_cast<AutoIndentMode>(mode));
}

int editor_get_auto_indent_mode(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return static_cast<int>(editor_core->getAutoIndentMode());
}

void editor_set_backspace_unindent(intptr_t editor_handle, int enabled) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setBackspaceUnindent(enabled != 0);
}

void editor_set_insert_spaces(intptr_t editor_handle, int enabled) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setInsertSpaces(enabled != 0);
}

#pragma endregion

#pragma region [Navigation, Styles & Decorations]

void editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->scrollToLine(line, static_cast<ScrollBehavior>(behavior));
}

void editor_goto_position(intptr_t editor_handle, size_t line, size_t column) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->gotoPosition(line, column);
}

void editor_ensure_cursor_visible(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->ensureCursorVisible();
}

void editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setScroll(scroll_x, scroll_y);
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

void editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->registerTextStyle(style_id, TextStyle{color, background_color, font_style});
}

void editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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

void editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<uint32_t, TextStyle>> entries;
  entries.reserve(entry_count);
  for (uint32_t i = 0; i < entry_count; ++i) {
    uint32_t style_id = 0;
    int32_t color = 0;
    int32_t background_color = 0;
    int32_t font_style = 0;
    if (!cursor.readU32(style_id) || !cursor.readI32(color) || !cursor.readI32(background_color) || !cursor.readI32(font_style)) {
      return;
    }
    entries.emplace_back(style_id, TextStyle{color, background_color, font_style});
  }

  editor_core->registerBatchTextStyles(std::move(entries));
}

void editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setLineSpans(line, static_cast<SpanLayer>(layer), {});
}

void editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearHighlights(static_cast<SpanLayer>(layer));
}

void editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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

void editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setMaxGutterIcons(count);
}

void editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t diag_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(diag_count)) {
    return;
  }

  size_t diagnostics_bytes = 0;
  if (mulOverflow(static_cast<size_t>(diag_count), sizeof(uint32_t) * 3, diagnostics_bytes) ||
      cursor.remaining() != diagnostics_bytes) {
    return;
  }

  Vector<DiagnosticSpan> diagnostics;
  diagnostics.reserve(diag_count);
  for (uint32_t i = 0; i < diag_count; ++i) {
    uint32_t column = 0;
    uint32_t length = 0;
    int32_t severity = 0;
    if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readI32(severity)) {
      return;
    }
    DiagnosticSpan ds;
    ds.column = column;
    ds.length = length;
    ds.severity = static_cast<DiagnosticSeverity>(severity);
    diagnostics.push_back(ds);
  }
  editor_core->setLineDiagnostics(static_cast<size_t>(line), std::move(diagnostics));
}

void editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
      if (!cursor.readU32(column) || !cursor.readU32(length) ||
          !cursor.readI32(severity)) return;
      DiagnosticSpan ds;
      ds.column = column;
      ds.length = length;
      ds.severity = static_cast<DiagnosticSeverity>(severity);
      diagnostics.push_back(ds);
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(diagnostics));
  }
  editor_core->setBatchLineDiagnostics(std::move(entries));
}

void editor_clear_diagnostics(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearDiagnostics();
}

void editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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

void editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || open_chars == nullptr || close_chars == nullptr) return;
  Vector<BracketPair> pairs;
  pairs.reserve(count);
  for (size_t i = 0; i < count; ++i) {
    pairs.push_back({static_cast<char32_t>(open_chars[i]), static_cast<char32_t>(close_chars[i])});
  }
  editor_core->setBracketPairs(std::move(pairs));
}

void editor_set_auto_closing_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  Vector<BracketPair> pairs;
  if (open_chars != nullptr && close_chars != nullptr) {
    pairs.reserve(count);
    for (size_t i = 0; i < count; ++i) {
      pairs.push_back({static_cast<char32_t>(open_chars[i]), static_cast<char32_t>(close_chars[i])});
    }
  }
  editor_core->setAutoClosingPairs(std::move(pairs));
}

void editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->setMatchedBrackets({open_line, open_col}, {close_line, close_col});
}

void editor_clear_matched_brackets(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearMatchedBrackets();
}

void editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->toggleFoldAt(line) ? 1 : 0;
}

int editor_fold_at(intptr_t editor_handle, size_t line) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->foldAt(line) ? 1 : 0;
}

int editor_unfold_at(intptr_t editor_handle, size_t line) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->unfoldAt(line) ? 1 : 0;
}

void editor_fold_all(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->foldAll();
}

void editor_unfold_all(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->unfoldAll();
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

void editor_clear_highlights(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearHighlights();
}

void editor_clear_inlay_hints(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearInlayHints();
}

void editor_clear_phantom_texts(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearPhantomTexts();
}

void editor_clear_gutter_icons(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearGutterIcons();
}

void editor_set_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t item_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(item_count)) return;

  Vector<CodeLensItem> items;
  items.reserve(item_count);
  for (uint32_t i = 0; i < item_count; ++i) {
    int32_t column = 0;
    int32_t command_id = 0;
    uint32_t text_len = 0;
    if (!cursor.readI32(column) || !cursor.readI32(command_id) || !cursor.readU32(text_len)) return;
    U8String text;
    if (text_len > 0) {
      const uint8_t* text_ptr = nullptr;
      if (!cursor.readBytes(text_ptr, text_len)) return;
      text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
    }
    CodeLensItem item;
    item.column = column;
    item.command_id = command_id;
    item.text = std::move(text);
    items.push_back(std::move(item));
  }
  editor_core->setLineCodeLens(static_cast<size_t>(line), std::move(items));
}

void editor_set_batch_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<CodeLensItem>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t item_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(item_count)) return;

    Vector<CodeLensItem> items;
    items.reserve(item_count);
    for (uint32_t i = 0; i < item_count; ++i) {
      int32_t column = 0;
      int32_t command_id = 0;
      uint32_t text_len = 0;
      if (!cursor.readI32(column) || !cursor.readI32(command_id) || !cursor.readU32(text_len)) return;
      U8String text;
      if (text_len > 0) {
        const uint8_t* text_ptr = nullptr;
        if (!cursor.readBytes(text_ptr, text_len)) return;
        text = U8String(reinterpret_cast<const char*>(text_ptr), text_len);
      }
      CodeLensItem item;
      item.column = column;
      item.command_id = command_id;
      item.text = std::move(text);
      items.push_back(std::move(item));
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(items));
  }
  editor_core->setBatchLineCodeLens(std::move(entries));
}

void editor_clear_codelens(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearCodeLens();
}

void editor_set_line_links(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t line = 0;
  uint32_t link_count = 0;
  if (!cursor.readU32(line) || !cursor.readU32(link_count)) return;

  Vector<LinkSpan> links;
  links.reserve(link_count);
  for (uint32_t i = 0; i < link_count; ++i) {
    uint32_t column = 0;
    uint32_t length = 0;
    uint32_t target_len = 0;
    if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readU32(target_len)) return;
    U8String target;
    if (target_len > 0) {
      const uint8_t* target_ptr = nullptr;
      if (!cursor.readBytes(target_ptr, target_len)) return;
      target = U8String(reinterpret_cast<const char*>(target_ptr), target_len);
    }
    links.push_back({column, length, std::move(target)});
  }
  editor_core->setLineLinks(static_cast<size_t>(line), std::move(links));
}

void editor_set_batch_line_links(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr || data == nullptr) return;

  ByteCursor cursor(data, size);
  uint32_t entry_count = 0;
  if (!cursor.readU32(entry_count)) return;

  Vector<std::pair<size_t, Vector<LinkSpan>>> entries;
  entries.reserve(entry_count);
  for (uint32_t e = 0; e < entry_count; ++e) {
    uint32_t line = 0;
    uint32_t link_count = 0;
    if (!cursor.readU32(line) || !cursor.readU32(link_count)) return;

    Vector<LinkSpan> links;
    links.reserve(link_count);
    for (uint32_t i = 0; i < link_count; ++i) {
      uint32_t column = 0;
      uint32_t length = 0;
      uint32_t target_len = 0;
      if (!cursor.readU32(column) || !cursor.readU32(length) || !cursor.readU32(target_len)) return;
      U8String target;
      if (target_len > 0) {
        const uint8_t* target_ptr = nullptr;
        if (!cursor.readBytes(target_ptr, target_len)) return;
        target = U8String(reinterpret_cast<const char*>(target_ptr), target_len);
      }
      links.push_back({column, length, std::move(target)});
    }
    entries.emplace_back(static_cast<size_t>(line), std::move(links));
  }
  editor_core->setBatchLineLinks(std::move(entries));
}

void editor_clear_links(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearLinks();
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

void editor_clear_guides(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearGuides();
}

void editor_clear_all_decorations(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->clearAllDecorations();
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
  TextEditResult result = editor_core->insertSnippet(snippet_template);
  return textEditResultToBinary(result, out_size);
}

void editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
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
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->isInLinkedEditing() ? 1 : 0;
}

int editor_linked_editing_next(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->linkedEditingNextTabStop() ? 1 : 0;
}

int editor_linked_editing_prev(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return 0;
  return editor_core->linkedEditingPrevTabStop() ? 1 : 0;
}

void editor_cancel_linked_editing(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return;
  editor_core->cancelLinkedEditing();
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

  return imeActionResultToBinary(editor_core->updateImePreedit(
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

  return imeActionResultToBinary(editor_core->setImeComposingText(
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

  return imeActionResultToBinary(editor_core->setImeComposingText(
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

  return imeActionResultToBinary(editor_core->commitImeText(
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

  return imeActionResultToBinary(editor_core->commitImeText(
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

  return imeActionResultToBinary(editor_core->finishImePreedit(), out_size);
}

const uint8_t* editor_ime_cancel_preedit(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }

  return imeActionResultToBinary(editor_core->cancelImePreedit(), out_size);
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

  return imeActionResultToBinary(editor_core->markImeDocumentRange(
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

  return imeActionResultToBinary(editor_core->markImeDocumentRange(
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

  return imeActionResultToBinary(editor_core->replaceImeText(
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

  return imeActionResultToBinary(editor_core->replaceImeDocumentText(
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

  return imeActionResultToBinary(editor_core->replaceImeInputContextText(
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

  return imeActionResultToBinary(editor_core->markImeInputContextRange(
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

  return imeActionResultToBinary(editor_core->notifyImeDocumentSelectionChanged(
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

  return imeActionResultToBinary(editor_core->notifyImeInputContextSelectionChanged(
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

  return imeActionResultToBinary(editor_core->updateImeInputStateText(
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

  return imeActionResultToBinary(editor_core->updateImeTextModelState(
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

  return imeActionResultToBinary(editor_core->updateImeTextModelDelta(
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

  return imeActionResultToBinary(editor_core->updateImeInputStateSelection(
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

  return imeActionResultToBinary(editor_core->replaceImeInputStateText(
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

  return imeActionResultToBinary(editor_core->commitImeInputStateTextReplacement(
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

  return imeActionResultToBinary(editor_core->deleteImeBackward(
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

  return imeActionResultToBinary(editor_core->deleteImeForward(
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

  return imeActionResultToBinary(editor_core->deleteImeSurrounding(
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

  return imeActionResultToBinary(editor_core->notifyImeSelectionChanged(
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

  return imeActionResultToBinary(editor_core->notifyImeCursorChanged(
      {cursor_line, cursor_column}), out_size);
}

void editor_ime_set_keyboard_script_class(intptr_t editor_handle, int script_class) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return;
  }
  editor_core->setImeKeyboardScriptClass(static_cast<ImeScriptClass>(script_class));
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
