#ifndef SWEETEDITOR_PROTOCOL_CODEC_H
#define SWEETEDITOR_PROTOCOL_CODEC_H

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <utility>
#include <sweeteditor/protocol.h>

namespace NS_SWEETEDITOR {
namespace protocol {

class ProtocolReader final {
public:
  inline ProtocolReader(const uint8_t* data, size_t size)
    : cur_(data), end_(data + size) {
  }

  inline bool readU8(uint8_t& out) {
    if (!has(1)) return false;
    out = *cur_;
    cur_ += 1;
    return true;
  }

  inline bool readU16(uint16_t& out) {
    if (!has(2)) return false;
    out = static_cast<uint16_t>(cur_[0]) | static_cast<uint16_t>(cur_[1] << 8u);
    cur_ += 2;
    return true;
  }

  inline bool readU32(uint32_t& out) {
    if (!has(4)) return false;
    out = static_cast<uint32_t>(cur_[0]) |
      (static_cast<uint32_t>(cur_[1]) << 8u) |
      (static_cast<uint32_t>(cur_[2]) << 16u) |
      (static_cast<uint32_t>(cur_[3]) << 24u);
    cur_ += 4;
    return true;
  }

  inline bool readI32(int32_t& out) {
    uint32_t raw = 0;
    if (!readU32(raw)) return false;
    out = static_cast<int32_t>(raw);
    return true;
  }

  inline bool readU64(uint64_t& out) {
    uint32_t low = 0;
    uint32_t high = 0;
    if (!readU32(low) || !readU32(high)) return false;
    out = static_cast<uint64_t>(low) | (static_cast<uint64_t>(high) << 32u);
    return true;
  }

  inline bool readI64(int64_t& out) {
    uint64_t raw = 0;
    if (!readU64(raw)) return false;
    out = static_cast<int64_t>(raw);
    return true;
  }

  inline bool readF32(float& out) {
    uint32_t raw = 0;
    if (!readU32(raw)) return false;
    std::memcpy(&out, &raw, sizeof(out));
    return true;
  }

  inline bool readF64(double& out) {
    uint64_t raw = 0;
    if (!readU64(raw)) return false;
    std::memcpy(&out, &raw, sizeof(out));
    return true;
  }

  inline bool readBytes(const uint8_t*& out, size_t count) {
    if (!has(count)) return false;
    out = cur_;
    cur_ += count;
    return true;
  }

  inline bool readUtf8String(U8String& out) {
    uint32_t length = 0;
    if (!readU32(length)) return false;
    const uint8_t* bytes = nullptr;
    if (!readBytes(bytes, static_cast<size_t>(length))) return false;
    out.assign(reinterpret_cast<const char*>(bytes), static_cast<size_t>(length));
    return true;
  }

  inline bool done() const {
    return cur_ == end_;
  }

  inline size_t remaining() const {
    return static_cast<size_t>(end_ - cur_);
  }

  inline bool read(BracketGuide& out) {
    if (!read(out.parent)) return false;
    if (!read(out.end)) return false;
    if (!readList(out.children)) return false;
    return true;
  }

  inline bool read(CodeLensItem& out) {
    int32_t out_column_value{};
    if (!readI32(out_column_value)) return false;
    out.column = static_cast<int32_t>(out_column_value);
    int32_t out_command_id_value{};
    if (!readI32(out_command_id_value)) return false;
    out.command_id = static_cast<int32_t>(out_command_id_value);
    if (!readUtf8String(out.text)) return false;
    return true;
  }

  inline bool read(Diagnostic& out) {
    uint32_t out_column_value{};
    if (!readU32(out_column_value)) return false;
    out.column = static_cast<uint32_t>(out_column_value);
    uint32_t out_length_value{};
    if (!readU32(out_length_value)) return false;
    out.length = static_cast<uint32_t>(out_length_value);
    int32_t out_severity_value{};
    if (!readI32(out_severity_value)) return false;
    out.severity = static_cast<DiagnosticSeverity>(out_severity_value);
    return true;
  }

  inline bool read(FlowGuide& out) {
    if (!read(out.start)) return false;
    if (!read(out.end)) return false;
    return true;
  }

  inline bool read(FoldRegion& out) {
    uint32_t out_start_line_value{};
    if (!readU32(out_start_line_value)) return false;
    out.start_line = static_cast<size_t>(out_start_line_value);
    uint32_t out_end_line_value{};
    if (!readU32(out_end_line_value)) return false;
    out.end_line = static_cast<size_t>(out_end_line_value);
    uint8_t out_collapsed_value{};
    if (!readU8(out_collapsed_value)) return false;
    out.collapsed = out_collapsed_value != 0;
    return true;
  }

  inline bool read(GutterIcon& out) {
    int32_t out_icon_id_value{};
    if (!readI32(out_icon_id_value)) return false;
    out.icon_id = static_cast<int32_t>(out_icon_id_value);
    return true;
  }

  inline bool read(IndentGuide& out) {
    if (!read(out.start)) return false;
    if (!read(out.end)) return false;
    return true;
  }

  inline bool read(InlayHint& out) {
    int32_t out_type_value{};
    if (!readI32(out_type_value)) return false;
    out.type = static_cast<InlayType>(out_type_value);
    uint32_t out_column_value{};
    if (!readU32(out_column_value)) return false;
    out.column = static_cast<uint32_t>(out_column_value);
    int32_t out_int_value_value{};
    if (!readI32(out_int_value_value)) return false;
    out.int_value = static_cast<int32_t>(out_int_value_value);
    if (!readUtf8String(out.text)) return false;
    return true;
  }

  inline bool read(LinkSpan& out) {
    uint32_t out_column_value{};
    if (!readU32(out_column_value)) return false;
    out.column = static_cast<uint32_t>(out_column_value);
    uint32_t out_length_value{};
    if (!readU32(out_length_value)) return false;
    out.length = static_cast<uint32_t>(out_length_value);
    if (!readUtf8String(out.target)) return false;
    return true;
  }

  inline bool read(PhantomText& out) {
    uint32_t out_column_value{};
    if (!readU32(out_column_value)) return false;
    out.column = static_cast<uint32_t>(out_column_value);
    if (!readUtf8String(out.text)) return false;
    return true;
  }

  inline bool read(RegisterBatchTextStylesPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      uint32_t key{};
      TextStyle value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<uint32_t>(key_value);
      if (!read(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SeparatorGuide& out) {
    int32_t out_line_value{};
    if (!readI32(out_line_value)) return false;
    out.line = static_cast<int32_t>(out_line_value);
    int32_t out_style_value{};
    if (!readI32(out_style_value)) return false;
    out.style = static_cast<SeparatorStyle>(out_style_value);
    int32_t out_count_value{};
    if (!readI32(out_count_value)) return false;
    out.count = static_cast<int32_t>(out_count_value);
    uint32_t out_text_end_column_value{};
    if (!readU32(out_text_end_column_value)) return false;
    out.text_end_column = static_cast<uint32_t>(out_text_end_column_value);
    return true;
  }

  inline bool read(SetBatchLineCodeLensPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<CodeLensItem> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLineDiagnosticsPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<Diagnostic> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLineGutterIconsPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<GutterIcon> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLineInlayHintsPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<InlayHint> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLineLinksPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<LinkSpan> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLinePhantomTextsPayload& out) {
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<PhantomText> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBatchLineSpansPayload& out) {
    int32_t out_layer_value{};
    if (!readI32(out_layer_value)) return false;
    out.layer = static_cast<SpanLayer>(out_layer_value);
    uint32_t count{};
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.entries.clear();
    out.entries.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      size_t key{};
      Vector<StyleSpan> value{};
      uint32_t key_value{};
      if (!readU32(key_value)) return false;
      key = static_cast<size_t>(key_value);
      if (!readList(value)) return false;
      out.entries.emplace_back(std::move(key), std::move(value));
    }
    return true;
  }

  inline bool read(SetBracketGuidesPayload& out) {
    if (!readList(out.guides)) return false;
    return true;
  }

  inline bool read(SetFlowGuidesPayload& out) {
    if (!readList(out.guides)) return false;
    return true;
  }

  inline bool read(SetFoldRegionsPayload& out) {
    if (!readList(out.regions)) return false;
    return true;
  }

  inline bool read(SetIndentGuidesPayload& out) {
    if (!readList(out.guides)) return false;
    return true;
  }

  inline bool read(SetLineCodeLensPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.items)) return false;
    return true;
  }

  inline bool read(SetLineDiagnosticsPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.diagnostics)) return false;
    return true;
  }

  inline bool read(SetLineGutterIconsPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.icons)) return false;
    return true;
  }

  inline bool read(SetLineInlayHintsPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.hints)) return false;
    return true;
  }

  inline bool read(SetLineLinksPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.links)) return false;
    return true;
  }

  inline bool read(SetLinePhantomTextsPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    if (!readList(out.phantoms)) return false;
    return true;
  }

  inline bool read(SetLineSpansPayload& out) {
    uint32_t out_line_value{};
    if (!readU32(out_line_value)) return false;
    out.line = static_cast<size_t>(out_line_value);
    int32_t out_layer_value{};
    if (!readI32(out_layer_value)) return false;
    out.layer = static_cast<SpanLayer>(out_layer_value);
    if (!readList(out.spans)) return false;
    return true;
  }

  inline bool read(SetSeparatorGuidesPayload& out) {
    if (!readList(out.guides)) return false;
    return true;
  }

  inline bool read(StyleSpan& out) {
    uint32_t out_column_value{};
    if (!readU32(out_column_value)) return false;
    out.column = static_cast<uint32_t>(out_column_value);
    uint32_t out_length_value{};
    if (!readU32(out_length_value)) return false;
    out.length = static_cast<uint32_t>(out_length_value);
    uint32_t out_style_id_value{};
    if (!readU32(out_style_id_value)) return false;
    out.style_id = static_cast<uint32_t>(out_style_id_value);
    return true;
  }

  inline bool read(TextStyle& out) {
    int32_t out_color_value{};
    if (!readI32(out_color_value)) return false;
    out.color = static_cast<int32_t>(out_color_value);
    int32_t out_background_color_value{};
    if (!readI32(out_background_color_value)) return false;
    out.background_color = static_cast<int32_t>(out_background_color_value);
    int32_t out_font_style_value{};
    if (!readI32(out_font_style_value)) return false;
    out.font_style = static_cast<int32_t>(out_font_style_value);
    return true;
  }

  inline bool read(EditorOptions& out) {
    float out_touch_slop_value{};
    if (!readF32(out_touch_slop_value)) return false;
    out.touch_slop = static_cast<float>(out_touch_slop_value);
    int64_t out_double_tap_timeout_value{};
    if (!readI64(out_double_tap_timeout_value)) return false;
    out.double_tap_timeout = static_cast<int64_t>(out_double_tap_timeout_value);
    int64_t out_long_press_ms_value{};
    if (!readI64(out_long_press_ms_value)) return false;
    out.long_press_ms = static_cast<int64_t>(out_long_press_ms_value);
    float out_fling_friction_value{};
    if (!readF32(out_fling_friction_value)) return false;
    out.fling_friction = static_cast<float>(out_fling_friction_value);
    float out_fling_min_velocity_value{};
    if (!readF32(out_fling_min_velocity_value)) return false;
    out.fling_min_velocity = static_cast<float>(out_fling_min_velocity_value);
    float out_fling_max_velocity_value{};
    if (!readF32(out_fling_max_velocity_value)) return false;
    out.fling_max_velocity = static_cast<float>(out_fling_max_velocity_value);
    uint64_t out_max_undo_stack_size_value{};
    if (!readU64(out_max_undo_stack_size_value)) return false;
    out.max_undo_stack_size = static_cast<size_t>(out_max_undo_stack_size_value);
    int64_t out_key_chord_timeout_ms_value{};
    if (!readI64(out_key_chord_timeout_ms_value)) return false;
    out.key_chord_timeout_ms = static_cast<int64_t>(out_key_chord_timeout_ms_value);
    uint8_t out_reveal_selection_end_on_select_all_value{};
    if (!readU8(out_reveal_selection_end_on_select_all_value)) return false;
    out.reveal_selection_end_on_select_all = out_reveal_selection_end_on_select_all_value != 0;
    return true;
  }

  inline bool read(EditorRangeEffectStyles& out) {
    if (!read(out.selection)) return false;
    if (!read(out.search_match)) return false;
    if (!read(out.search_current)) return false;
    if (!read(out.document_highlight_text)) return false;
    if (!read(out.document_highlight_read)) return false;
    if (!read(out.document_highlight_write)) return false;
    if (!read(out.linked_editing_active)) return false;
    if (!read(out.linked_editing_inactive)) return false;
    if (!read(out.ime_composition)) return false;
    if (!read(out.bracket_match)) return false;
    if (!read(out.diagnostic_error)) return false;
    if (!read(out.diagnostic_warning)) return false;
    if (!read(out.diagnostic_info)) return false;
    if (!read(out.diagnostic_hint)) return false;
    return true;
  }

  inline bool read(EditorRenderColors& out) {
    int32_t out_text_foreground_value{};
    if (!readI32(out_text_foreground_value)) return false;
    out.text_foreground = static_cast<int32_t>(out_text_foreground_value);
    int32_t out_link_foreground_value{};
    if (!readI32(out_link_foreground_value)) return false;
    out.link_foreground = static_cast<int32_t>(out_link_foreground_value);
    int32_t out_active_link_foreground_value{};
    if (!readI32(out_active_link_foreground_value)) return false;
    out.active_link_foreground = static_cast<int32_t>(out_active_link_foreground_value);
    int32_t out_codelens_foreground_value{};
    if (!readI32(out_codelens_foreground_value)) return false;
    out.codelens_foreground = static_cast<int32_t>(out_codelens_foreground_value);
    int32_t out_active_codelens_foreground_value{};
    if (!readI32(out_active_codelens_foreground_value)) return false;
    out.active_codelens_foreground = static_cast<int32_t>(out_active_codelens_foreground_value);
    return true;
  }

  inline bool read(HandleConfig& out) {
    if (!read(out.start_hit_offset)) return false;
    if (!read(out.end_hit_offset)) return false;
    return true;
  }

  inline bool read(RangeEffectStyle& out) {
    int32_t out_foreground_color_value{};
    if (!readI32(out_foreground_color_value)) return false;
    out.foreground_color = static_cast<int32_t>(out_foreground_color_value);
    int32_t out_background_color_value{};
    if (!readI32(out_background_color_value)) return false;
    out.background_color = static_cast<int32_t>(out_background_color_value);
    int32_t out_border_color_value{};
    if (!readI32(out_border_color_value)) return false;
    out.border_color = static_cast<int32_t>(out_border_color_value);
    int32_t out_underline_color_value{};
    if (!readI32(out_underline_color_value)) return false;
    out.underline_color = static_cast<int32_t>(out_underline_color_value);
    int32_t out_underline_style_value{};
    if (!readI32(out_underline_style_value)) return false;
    out.underline_style = static_cast<RangeEffectUnderlineStyle>(out_underline_style_value);
    return true;
  }

  inline bool read(ScrollbarConfig& out) {
    float out_thickness_value{};
    if (!readF32(out_thickness_value)) return false;
    out.thickness = static_cast<float>(out_thickness_value);
    float out_min_thumb_value{};
    if (!readF32(out_min_thumb_value)) return false;
    out.min_thumb = static_cast<float>(out_min_thumb_value);
    float out_thumb_hit_padding_value{};
    if (!readF32(out_thumb_hit_padding_value)) return false;
    out.thumb_hit_padding = static_cast<float>(out_thumb_hit_padding_value);
    int32_t out_mode_value{};
    if (!readI32(out_mode_value)) return false;
    out.mode = static_cast<ScrollbarMode>(out_mode_value);
    uint8_t out_thumb_draggable_value{};
    if (!readU8(out_thumb_draggable_value)) return false;
    out.thumb_draggable = out_thumb_draggable_value != 0;
    int32_t out_track_tap_mode_value{};
    if (!readI32(out_track_tap_mode_value)) return false;
    out.track_tap_mode = static_cast<ScrollbarTrackTapMode>(out_track_tap_mode_value);
    uint16_t out_fade_delay_ms_value{};
    if (!readU16(out_fade_delay_ms_value)) return false;
    out.fade_delay_ms = static_cast<uint16_t>(out_fade_delay_ms_value);
    uint16_t out_fade_duration_ms_value{};
    if (!readU16(out_fade_duration_ms_value)) return false;
    out.fade_duration_ms = static_cast<uint16_t>(out_fade_duration_ms_value);
    return true;
  }

  inline bool read(IntRange& out) {
    int32_t out_start_value{};
    if (!readI32(out_start_value)) return false;
    out.start = static_cast<int32_t>(out_start_value);
    int32_t out_end_value{};
    if (!readI32(out_end_value)) return false;
    out.end = static_cast<int32_t>(out_end_value);
    return true;
  }

  inline bool read(OffsetRect& out) {
    float out_left_value{};
    if (!readF32(out_left_value)) return false;
    out.left = static_cast<float>(out_left_value);
    float out_top_value{};
    if (!readF32(out_top_value)) return false;
    out.top = static_cast<float>(out_top_value);
    float out_right_value{};
    if (!readF32(out_right_value)) return false;
    out.right = static_cast<float>(out_right_value);
    float out_bottom_value{};
    if (!readF32(out_bottom_value)) return false;
    out.bottom = static_cast<float>(out_bottom_value);
    return true;
  }

  inline bool read(PointF& out) {
    float out_x_value{};
    if (!readF32(out_x_value)) return false;
    out.x = static_cast<float>(out_x_value);
    float out_y_value{};
    if (!readF32(out_y_value)) return false;
    out.y = static_cast<float>(out_y_value);
    return true;
  }

  inline bool read(Rect& out) {
    if (!read(out.origin)) return false;
    float out_width_value{};
    if (!readF32(out_width_value)) return false;
    out.width = static_cast<float>(out_width_value);
    float out_height_value{};
    if (!readF32(out_height_value)) return false;
    out.height = static_cast<float>(out_height_value);
    return true;
  }

  inline bool read(TextPosition& out) {
    int32_t out_line_value{};
    if (!readI32(out_line_value)) return false;
    if (out_line_value < 0) return false;
    out.line = static_cast<size_t>(out_line_value);
    int32_t out_column_value{};
    if (!readI32(out_column_value)) return false;
    if (out_column_value < 0) return false;
    out.column = static_cast<size_t>(out_column_value);
    return true;
  }

  inline bool read(TextRange& out) {
    if (!read(out.start)) return false;
    if (!read(out.end)) return false;
    return true;
  }

  inline bool read(ImeDocumentTextReplacement& out) {
    uint32_t out_start_offset_value{};
    if (!readU32(out_start_offset_value)) return false;
    out.start_offset = static_cast<size_t>(out_start_offset_value);
    uint32_t out_end_offset_value{};
    if (!readU32(out_end_offset_value)) return false;
    out.end_offset = static_cast<size_t>(out_end_offset_value);
    if (!readUtf8String(out.text)) return false;
    int32_t out_cursor_offset_value{};
    if (!readI32(out_cursor_offset_value)) return false;
    out.cursor_offset = static_cast<int32_t>(out_cursor_offset_value);
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(ImeInputContextTextReplacement& out) {
    uint32_t out_start_offset_value{};
    if (!readU32(out_start_offset_value)) return false;
    out.start_offset = static_cast<size_t>(out_start_offset_value);
    uint32_t out_end_offset_value{};
    if (!readU32(out_end_offset_value)) return false;
    out.end_offset = static_cast<size_t>(out_end_offset_value);
    if (!readUtf8String(out.text)) return false;
    int32_t out_cursor_offset_value{};
    if (!readI32(out_cursor_offset_value)) return false;
    out.cursor_offset = static_cast<int32_t>(out_cursor_offset_value);
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(ImeInputStateTextReplacement& out) {
    uint64_t out_context_id_value{};
    if (!readU64(out_context_id_value)) return false;
    out.context_id = static_cast<uint64_t>(out_context_id_value);
    int32_t out_document_start_offset_value{};
    if (!readI32(out_document_start_offset_value)) return false;
    out.document_start_offset = static_cast<int32_t>(out_document_start_offset_value);
    uint32_t out_start_offset_value{};
    if (!readU32(out_start_offset_value)) return false;
    out.start_offset = static_cast<size_t>(out_start_offset_value);
    uint32_t out_end_offset_value{};
    if (!readU32(out_end_offset_value)) return false;
    out.end_offset = static_cast<size_t>(out_end_offset_value);
    if (!readUtf8String(out.text)) return false;
    int32_t out_cursor_offset_value{};
    if (!readI32(out_cursor_offset_value)) return false;
    out.cursor_offset = static_cast<int32_t>(out_cursor_offset_value);
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(ImeTextModelDelta& out) {
    int32_t out_mode_value{};
    if (!readI32(out_mode_value)) return false;
    out.mode = static_cast<ImeTextModelMode>(out_mode_value);
    uint64_t out_context_id_value{};
    if (!readU64(out_context_id_value)) return false;
    out.context_id = static_cast<uint64_t>(out_context_id_value);
    int32_t out_document_start_offset_value{};
    if (!readI32(out_document_start_offset_value)) return false;
    out.document_start_offset = static_cast<int32_t>(out_document_start_offset_value);
    if (!readUtf8String(out.old_text)) return false;
    if (!read(out.delta)) return false;
    if (!readUtf8String(out.delta_text)) return false;
    if (!read(out.selection)) return false;
    if (!read(out.composition)) return false;
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(ImeTextModelState& out) {
    int32_t out_mode_value{};
    if (!readI32(out_mode_value)) return false;
    out.mode = static_cast<ImeTextModelMode>(out_mode_value);
    uint64_t out_context_id_value{};
    if (!readU64(out_context_id_value)) return false;
    out.context_id = static_cast<uint64_t>(out_context_id_value);
    int32_t out_document_start_offset_value{};
    if (!readI32(out_document_start_offset_value)) return false;
    out.document_start_offset = static_cast<int32_t>(out_document_start_offset_value);
    if (!readUtf8String(out.text)) return false;
    if (!read(out.selection)) return false;
    if (!read(out.composition)) return false;
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(ImeTextRange& out) {
    int32_t out_start_value{};
    if (!readI32(out_start_value)) return false;
    out.start = static_cast<int32_t>(out_start_value);
    int32_t out_end_value{};
    if (!readI32(out_end_value)) return false;
    out.end = static_cast<int32_t>(out_end_value);
    return true;
  }

  inline bool read(ImeTextReplacement& out) {
    if (!read(out.range)) return false;
    if (!readUtf8String(out.text)) return false;
    int32_t out_script_class_value{};
    if (!readI32(out_script_class_value)) return false;
    out.script_class = static_cast<ImeScriptClass>(out_script_class_value);
    return true;
  }

  inline bool read(GestureEvent& out) {
    int32_t out_type_value{};
    if (!readI32(out_type_value)) return false;
    out.type = static_cast<EventType>(out_type_value);
    if (!readList(out.points)) return false;
    int32_t out_modifiers_value{};
    if (!readI32(out_modifiers_value)) return false;
    out.modifiers = static_cast<KeyModifier>(out_modifiers_value);
    float out_wheel_delta_x_value{};
    if (!readF32(out_wheel_delta_x_value)) return false;
    out.wheel_delta_x = static_cast<float>(out_wheel_delta_x_value);
    float out_wheel_delta_y_value{};
    if (!readF32(out_wheel_delta_y_value)) return false;
    out.wheel_delta_y = static_cast<float>(out_wheel_delta_y_value);
    float out_direct_scale_value{};
    if (!readF32(out_direct_scale_value)) return false;
    out.direct_scale = static_cast<float>(out_direct_scale_value);
    return true;
  }

  inline bool read(KeyBinding& out) {
    if (!read(out.first)) return false;
    if (!read(out.second)) return false;
    uint32_t out_command_value{};
    if (!readU32(out_command_value)) return false;
    out.command = static_cast<EditorCommandId>(out_command_value);
    return true;
  }

  inline bool read(KeyChord& out) {
    uint8_t out_modifiers_value{};
    if (!readU8(out_modifiers_value)) return false;
    out.modifiers = static_cast<KeyModifier>(out_modifiers_value);
    uint16_t out_key_code_value{};
    if (!readU16(out_key_code_value)) return false;
    out.key_code = static_cast<KeyCode>(out_key_code_value);
    return true;
  }

  inline bool read(SetKeyMapPayload& out) {
    if (!readList(out.bindings)) return false;
    return true;
  }

  inline bool read(LinkedEditingModel& out) {
    if (!readList(out.groups)) return false;
    return true;
  }

  inline bool read(StartLinkedEditingPayload& out) {
    if (!read(out.model)) return false;
    return true;
  }

  inline bool read(TabStopGroup& out) {
    uint32_t out_index_value{};
    if (!readU32(out_index_value)) return false;
    out.index = static_cast<uint32_t>(out_index_value);
    if (!readList(out.ranges)) return false;
    if (!readUtf8String(out.default_text)) return false;
    return true;
  }

  inline bool read(SearchOptions& out) {
    int32_t out_case_sensitive_value{};
    if (!readI32(out_case_sensitive_value)) return false;
    out.case_sensitive = out_case_sensitive_value != 0;
    int32_t out_whole_word_value{};
    if (!readI32(out_whole_word_value)) return false;
    out.whole_word = out_whole_word_value != 0;
    int32_t out_use_regex_value{};
    if (!readI32(out_use_regex_value)) return false;
    out.use_regex = out_use_regex_value != 0;
    int32_t out_wrap_around_value{};
    if (!readI32(out_wrap_around_value)) return false;
    out.wrap_around = out_wrap_around_value != 0;
    uint32_t out_max_matches_value{};
    if (!readU32(out_max_matches_value)) return false;
    out.max_matches = static_cast<uint32_t>(out_max_matches_value);
    return true;
  }

  inline bool read(SearchReplaceRequest& out) {
    if (!readUtf8String(out.replacement)) return false;
    return true;
  }

  inline bool read(SearchRequest& out) {
    if (!readUtf8String(out.pattern)) return false;
    if (!read(out.options)) return false;
    return true;
  }

  inline bool read(CursorRect& out) {
    float out_x_value{};
    if (!readF32(out_x_value)) return false;
    out.x = static_cast<float>(out_x_value);
    float out_y_value{};
    if (!readF32(out_y_value)) return false;
    out.y = static_cast<float>(out_y_value);
    float out_height_value{};
    if (!readF32(out_height_value)) return false;
    out.height = static_cast<float>(out_height_value);
    return true;
  }

  template <typename T>
  bool readList(Vector<T>& out) {
    uint32_t count = 0;
    if (!readU32(count)) return false;
    if (count > remaining()) return false;
    out.clear();
    out.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
      T value{};
      if (!read(value)) return false;
      out.push_back(std::move(value));
    }
    return true;
  }

  template <typename T>
  static bool decode(const uint8_t* data, size_t size, T& out) {
    if (data == nullptr) return false;
    ProtocolReader reader(data, size);
    return reader.read(out) && reader.done();
  }

private:
  inline bool has(size_t count) const {
    return count <= remaining();
  }

  const uint8_t* cur_;
  const uint8_t* end_;
};

class ProtocolWriter final {
public:
  inline ProtocolWriter() = default;

  inline void reserve(size_t size) {
    buffer_.reserve(size);
  }

  inline const uint8_t* data() const {
    return buffer_.data();
  }

  inline size_t size() const {
    return buffer_.size();
  }

  inline bool writeU8(uint8_t value) {
    buffer_.push_back(value);
    return true;
  }

  inline bool writeU16(uint16_t value) {
    buffer_.push_back(static_cast<uint8_t>(value & 0xffu));
    buffer_.push_back(static_cast<uint8_t>((value >> 8u) & 0xffu));
    return true;
  }

  inline bool writeU32(uint32_t value) {
    buffer_.push_back(static_cast<uint8_t>(value & 0xffu));
    buffer_.push_back(static_cast<uint8_t>((value >> 8u) & 0xffu));
    buffer_.push_back(static_cast<uint8_t>((value >> 16u) & 0xffu));
    buffer_.push_back(static_cast<uint8_t>((value >> 24u) & 0xffu));
    return true;
  }

  inline bool writeI32(int32_t value) {
    return writeU32(static_cast<uint32_t>(value));
  }

  inline bool writeU64(uint64_t value) {
    return writeU32(static_cast<uint32_t>(value & 0xffffffffu)) &&
      writeU32(static_cast<uint32_t>((value >> 32u) & 0xffffffffu));
  }

  inline bool writeI64(int64_t value) {
    return writeU64(static_cast<uint64_t>(value));
  }

  inline bool writeF32(float value) {
    uint32_t raw = 0;
    std::memcpy(&raw, &value, sizeof(value));
    return writeU32(raw);
  }

  inline bool writeF64(double value) {
    uint64_t raw = 0;
    std::memcpy(&raw, &value, sizeof(value));
    return writeU64(raw);
  }

  inline bool writeBytes(const uint8_t* data, size_t size) {
    if (size == 0) return true;
    if (data == nullptr) return false;
    buffer_.insert(buffer_.end(), data, data + size);
    return true;
  }

  inline bool writeUtf8String(const U8String& value) {
    if (value.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.size()))) return false;
    return writeBytes(reinterpret_cast<const uint8_t*>(value.data()), value.size());
  }

  inline bool writeU16AsUtf8String(const U16String& value) {
    U8String utf8;
    if (!value.empty()) {
      StrUtil::convertUTF16ToUTF8(value, utf8);
    }
    return writeUtf8String(utf8);
  }

  inline bool write(const EditorActionResult& value) {
    if (!writeI32(value.handled ? 1 : 0)) return false;
    if (!writeI32(value.needs_redraw ? 1 : 0)) return false;
    if (!writeI32(static_cast<int32_t>(value.reason))) return false;
    if (!writeI32(value.content_changed ? 1 : 0)) return false;
    if (!writeI32(value.cursor_changed ? 1 : 0)) return false;
    if (!writeI32(value.selection_changed ? 1 : 0)) return false;
    if (!writeI32(value.scroll_changed ? 1 : 0)) return false;
    if (!writeI32(value.scale_changed ? 1 : 0)) return false;
    if (!writeI32(value.pointer_cursor_changed ? 1 : 0)) return false;
    if (!writeI32(value.composition_changed ? 1 : 0)) return false;
    if (!writeI32(value.decoration_changed ? 1 : 0)) return false;
    if (!writeI32(value.needs_ime_sync ? 1 : 0)) return false;
    if (!writeI32(value.needs_edge_scroll ? 1 : 0)) return false;
    if (!writeI32(value.needs_fling ? 1 : 0)) return false;
    if (!writeI32(value.needs_animation ? 1 : 0)) return false;
    if (!writeI32(value.is_handle_drag ? 1 : 0)) return false;
    if (!writeList(value.changes)) return false;
    if (!write(value.cursor_before)) return false;
    if (!write(value.cursor_after)) return false;
    if (!writeI32(value.has_selection_before ? 1 : 0)) return false;
    if (!writeI32(value.has_selection_after ? 1 : 0)) return false;
    if (!write(value.selection_before)) return false;
    if (!write(value.selection_after)) return false;
    if (!writeF32(static_cast<float>(value.scroll_x_before))) return false;
    if (!writeF32(static_cast<float>(value.scroll_y_before))) return false;
    if (!writeF32(static_cast<float>(value.scroll_x_after))) return false;
    if (!writeF32(static_cast<float>(value.scroll_y_after))) return false;
    if (!writeF32(static_cast<float>(value.scale_before))) return false;
    if (!writeF32(static_cast<float>(value.scale_after))) return false;
    if (!writeI32(static_cast<int32_t>(value.pointer_cursor_before))) return false;
    if (!writeI32(static_cast<int32_t>(value.pointer_cursor_after))) return false;
    if (!write(value.ime_sync)) return false;
    if (!writeI32(static_cast<int32_t>(value.gesture_type))) return false;
    if (!writeI32(static_cast<int32_t>(value.gesture_event_type))) return false;
    if (!write(value.tap_point)) return false;
    if (!write(value.hit_target)) return false;
    if (!writeI32(static_cast<int32_t>(value.modifiers))) return false;
    if (!writeI32(static_cast<int32_t>(value.command))) return false;
    return true;
  }

  inline bool write(const BracketGuide& value) {
    if (!write(value.parent)) return false;
    if (!write(value.end)) return false;
    if (!writeList(value.children)) return false;
    return true;
  }

  inline bool write(const CodeLensItem& value) {
    if (!writeI32(static_cast<int32_t>(value.column))) return false;
    if (!writeI32(static_cast<int32_t>(value.command_id))) return false;
    if (!writeUtf8String(value.text)) return false;
    return true;
  }

  inline bool write(const Diagnostic& value) {
    if (!writeU32(static_cast<uint32_t>(value.column))) return false;
    if (!writeU32(static_cast<uint32_t>(value.length))) return false;
    if (!writeI32(static_cast<int32_t>(value.severity))) return false;
    return true;
  }

  inline bool write(const FlowGuide& value) {
    if (!write(value.start)) return false;
    if (!write(value.end)) return false;
    return true;
  }

  inline bool write(const FoldRegion& value) {
    if (!writeU32(static_cast<uint32_t>(value.start_line))) return false;
    if (!writeU32(static_cast<uint32_t>(value.end_line))) return false;
    if (!writeU8(static_cast<uint8_t>(value.collapsed ? 1 : 0))) return false;
    return true;
  }

  inline bool write(const GutterIcon& value) {
    if (!writeI32(static_cast<int32_t>(value.icon_id))) return false;
    return true;
  }

  inline bool write(const IndentGuide& value) {
    if (!write(value.start)) return false;
    if (!write(value.end)) return false;
    return true;
  }

  inline bool write(const InlayHint& value) {
    if (!writeI32(static_cast<int32_t>(value.type))) return false;
    if (!writeU32(static_cast<uint32_t>(value.column))) return false;
    if (!writeI32(static_cast<int32_t>(value.int_value))) return false;
    if (!writeUtf8String(value.text)) return false;
    return true;
  }

  inline bool write(const LinkSpan& value) {
    if (!writeU32(static_cast<uint32_t>(value.column))) return false;
    if (!writeU32(static_cast<uint32_t>(value.length))) return false;
    if (!writeUtf8String(value.target)) return false;
    return true;
  }

  inline bool write(const PhantomText& value) {
    if (!writeU32(static_cast<uint32_t>(value.column))) return false;
    if (!writeUtf8String(value.text)) return false;
    return true;
  }

  inline bool write(const RegisterBatchTextStylesPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!write(value)) return false;
    }
    return true;
  }

  inline bool write(const SeparatorGuide& value) {
    if (!writeI32(static_cast<int32_t>(value.line))) return false;
    if (!writeI32(static_cast<int32_t>(value.style))) return false;
    if (!writeI32(static_cast<int32_t>(value.count))) return false;
    if (!writeU32(static_cast<uint32_t>(value.text_end_column))) return false;
    return true;
  }

  inline bool write(const SetBatchLineCodeLensPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLineDiagnosticsPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLineGutterIconsPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLineInlayHintsPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLineLinksPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLinePhantomTextsPayload& value) {
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBatchLineSpansPayload& value) {
    if (!writeI32(static_cast<int32_t>(value.layer))) return false;
    if (value.entries.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(value.entries.size()))) return false;
    for (const auto& entry : value.entries) {
      const auto& key = entry.first;
      const auto& value = entry.second;
      if (!writeU32(static_cast<uint32_t>(key))) return false;
      if (!writeList(value)) return false;
    }
    return true;
  }

  inline bool write(const SetBracketGuidesPayload& value) {
    if (!writeList(value.guides)) return false;
    return true;
  }

  inline bool write(const SetFlowGuidesPayload& value) {
    if (!writeList(value.guides)) return false;
    return true;
  }

  inline bool write(const SetFoldRegionsPayload& value) {
    if (!writeList(value.regions)) return false;
    return true;
  }

  inline bool write(const SetIndentGuidesPayload& value) {
    if (!writeList(value.guides)) return false;
    return true;
  }

  inline bool write(const SetLineCodeLensPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.items)) return false;
    return true;
  }

  inline bool write(const SetLineDiagnosticsPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.diagnostics)) return false;
    return true;
  }

  inline bool write(const SetLineGutterIconsPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.icons)) return false;
    return true;
  }

  inline bool write(const SetLineInlayHintsPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.hints)) return false;
    return true;
  }

  inline bool write(const SetLineLinksPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.links)) return false;
    return true;
  }

  inline bool write(const SetLinePhantomTextsPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeList(value.phantoms)) return false;
    return true;
  }

  inline bool write(const SetLineSpansPayload& value) {
    if (!writeU32(static_cast<uint32_t>(value.line))) return false;
    if (!writeI32(static_cast<int32_t>(value.layer))) return false;
    if (!writeList(value.spans)) return false;
    return true;
  }

  inline bool write(const SetSeparatorGuidesPayload& value) {
    if (!writeList(value.guides)) return false;
    return true;
  }

  inline bool write(const StyleSpan& value) {
    if (!writeU32(static_cast<uint32_t>(value.column))) return false;
    if (!writeU32(static_cast<uint32_t>(value.length))) return false;
    if (!writeU32(static_cast<uint32_t>(value.style_id))) return false;
    return true;
  }

  inline bool write(const TextStyle& value) {
    if (!writeI32(static_cast<int32_t>(value.color))) return false;
    if (!writeI32(static_cast<int32_t>(value.background_color))) return false;
    if (!writeI32(static_cast<int32_t>(value.font_style))) return false;
    return true;
  }

  inline bool write(const EditorOptions& value) {
    if (!writeF32(static_cast<float>(value.touch_slop))) return false;
    if (!writeI64(static_cast<int64_t>(value.double_tap_timeout))) return false;
    if (!writeI64(static_cast<int64_t>(value.long_press_ms))) return false;
    if (!writeF32(static_cast<float>(value.fling_friction))) return false;
    if (!writeF32(static_cast<float>(value.fling_min_velocity))) return false;
    if (!writeF32(static_cast<float>(value.fling_max_velocity))) return false;
    if (!writeU64(static_cast<uint64_t>(value.max_undo_stack_size))) return false;
    if (!writeI64(static_cast<int64_t>(value.key_chord_timeout_ms))) return false;
    if (!writeU8(static_cast<uint8_t>(value.reveal_selection_end_on_select_all ? 1 : 0))) return false;
    return true;
  }

  inline bool write(const EditorRangeEffectStyles& value) {
    if (!write(value.selection)) return false;
    if (!write(value.search_match)) return false;
    if (!write(value.search_current)) return false;
    if (!write(value.document_highlight_text)) return false;
    if (!write(value.document_highlight_read)) return false;
    if (!write(value.document_highlight_write)) return false;
    if (!write(value.linked_editing_active)) return false;
    if (!write(value.linked_editing_inactive)) return false;
    if (!write(value.ime_composition)) return false;
    if (!write(value.bracket_match)) return false;
    if (!write(value.diagnostic_error)) return false;
    if (!write(value.diagnostic_warning)) return false;
    if (!write(value.diagnostic_info)) return false;
    if (!write(value.diagnostic_hint)) return false;
    return true;
  }

  inline bool write(const EditorRenderColors& value) {
    if (!writeI32(static_cast<int32_t>(value.text_foreground))) return false;
    if (!writeI32(static_cast<int32_t>(value.link_foreground))) return false;
    if (!writeI32(static_cast<int32_t>(value.active_link_foreground))) return false;
    if (!writeI32(static_cast<int32_t>(value.codelens_foreground))) return false;
    if (!writeI32(static_cast<int32_t>(value.active_codelens_foreground))) return false;
    return true;
  }

  inline bool write(const HandleConfig& value) {
    if (!write(value.start_hit_offset)) return false;
    if (!write(value.end_hit_offset)) return false;
    return true;
  }

  inline bool write(const RangeEffectStyle& value) {
    if (!writeI32(static_cast<int32_t>(value.foreground_color))) return false;
    if (!writeI32(static_cast<int32_t>(value.background_color))) return false;
    if (!writeI32(static_cast<int32_t>(value.border_color))) return false;
    if (!writeI32(static_cast<int32_t>(value.underline_color))) return false;
    if (!writeI32(static_cast<int32_t>(value.underline_style))) return false;
    return true;
  }

  inline bool write(const ScrollbarConfig& value) {
    if (!writeF32(static_cast<float>(value.thickness))) return false;
    if (!writeF32(static_cast<float>(value.min_thumb))) return false;
    if (!writeF32(static_cast<float>(value.thumb_hit_padding))) return false;
    if (!writeI32(static_cast<int32_t>(value.mode))) return false;
    if (!writeU8(static_cast<uint8_t>(value.thumb_draggable ? 1 : 0))) return false;
    if (!writeI32(static_cast<int32_t>(value.track_tap_mode))) return false;
    if (!writeU16(static_cast<uint16_t>(value.fade_delay_ms))) return false;
    if (!writeU16(static_cast<uint16_t>(value.fade_duration_ms))) return false;
    return true;
  }

  inline bool write(const IntRange& value) {
    if (!writeI32(static_cast<int32_t>(value.start))) return false;
    if (!writeI32(static_cast<int32_t>(value.end))) return false;
    return true;
  }

  inline bool write(const OffsetRect& value) {
    if (!writeF32(static_cast<float>(value.left))) return false;
    if (!writeF32(static_cast<float>(value.top))) return false;
    if (!writeF32(static_cast<float>(value.right))) return false;
    if (!writeF32(static_cast<float>(value.bottom))) return false;
    return true;
  }

  inline bool write(const PointF& value) {
    if (!writeF32(static_cast<float>(value.x))) return false;
    if (!writeF32(static_cast<float>(value.y))) return false;
    return true;
  }

  inline bool write(const Rect& value) {
    if (!write(value.origin)) return false;
    if (!writeF32(static_cast<float>(value.width))) return false;
    if (!writeF32(static_cast<float>(value.height))) return false;
    return true;
  }

  inline bool write(const TextChange& value) {
    if (!write(value.range)) return false;
    if (!writeUtf8String(value.new_text)) return false;
    return true;
  }

  inline bool write(const TextPosition& value) {
    if (!writeI32(static_cast<int32_t>(value.line))) return false;
    if (!writeI32(static_cast<int32_t>(value.column))) return false;
    return true;
  }

  inline bool write(const TextRange& value) {
    if (!write(value.start)) return false;
    if (!write(value.end)) return false;
    return true;
  }

  inline bool write(const ImeDocumentTextReplacement& value) {
    if (!writeU32(static_cast<uint32_t>(value.start_offset))) return false;
    if (!writeU32(static_cast<uint32_t>(value.end_offset))) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!writeI32(static_cast<int32_t>(value.cursor_offset))) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const ImeInputContext& value) {
    if (!writeU64(static_cast<uint64_t>(value.id))) return false;
    if (!writeI32(static_cast<int32_t>(value.revision))) return false;
    if (!writeI32(static_cast<int32_t>(value.document_start_offset))) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!write(value.selection)) return false;
    if (!writeI32(value.has_composition ? 1 : 0)) return false;
    if (!write(value.composition)) return false;
    if (!writeI32(static_cast<int32_t>(value.kind))) return false;
    return true;
  }

  inline bool write(const ImeInputContextTextReplacement& value) {
    if (!writeU32(static_cast<uint32_t>(value.start_offset))) return false;
    if (!writeU32(static_cast<uint32_t>(value.end_offset))) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!writeI32(static_cast<int32_t>(value.cursor_offset))) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const ImeInputStateTextReplacement& value) {
    if (!writeU64(static_cast<uint64_t>(value.context_id))) return false;
    if (!writeI32(static_cast<int32_t>(value.document_start_offset))) return false;
    if (!writeU32(static_cast<uint32_t>(value.start_offset))) return false;
    if (!writeU32(static_cast<uint32_t>(value.end_offset))) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!writeI32(static_cast<int32_t>(value.cursor_offset))) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const ImeSyncSnapshot& value) {
    if (!write(value.cursor)) return false;
    if (!write(value.selection)) return false;
    if (!writeI32(value.has_selection ? 1 : 0)) return false;
    if (!writeI32(value.has_composing_session ? 1 : 0)) return false;
    if (!writeI32(value.has_visible_composition_range ? 1 : 0)) return false;
    if (!write(value.visible_composition_range)) return false;
    if (!writeI32(value.has_platform_marked_range ? 1 : 0)) return false;
    if (!write(value.platform_marked_range)) return false;
    if (!writeI32(static_cast<int32_t>(value.preedit_storage))) return false;
    if (!writeI32(static_cast<int32_t>(value.context_policy))) return false;
    if (!writeI32(value.clear_platform_preedit ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const ImeTextModelDelta& value) {
    if (!writeI32(static_cast<int32_t>(value.mode))) return false;
    if (!writeU64(static_cast<uint64_t>(value.context_id))) return false;
    if (!writeI32(static_cast<int32_t>(value.document_start_offset))) return false;
    if (!writeUtf8String(value.old_text)) return false;
    if (!write(value.delta)) return false;
    if (!writeUtf8String(value.delta_text)) return false;
    if (!write(value.selection)) return false;
    if (!write(value.composition)) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const ImeTextModelState& value) {
    if (!writeI32(static_cast<int32_t>(value.mode))) return false;
    if (!writeU64(static_cast<uint64_t>(value.context_id))) return false;
    if (!writeI32(static_cast<int32_t>(value.document_start_offset))) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!write(value.selection)) return false;
    if (!write(value.composition)) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const ImeTextRange& value) {
    if (!writeI32(static_cast<int32_t>(value.start))) return false;
    if (!writeI32(static_cast<int32_t>(value.end))) return false;
    return true;
  }

  inline bool write(const ImeTextReplacement& value) {
    if (!write(value.range)) return false;
    if (!writeUtf8String(value.text)) return false;
    if (!writeI32(static_cast<int32_t>(value.script_class))) return false;
    return true;
  }

  inline bool write(const GestureEvent& value) {
    if (!writeI32(static_cast<int32_t>(value.type))) return false;
    if (!writeList(value.points)) return false;
    if (!writeI32(static_cast<int32_t>(value.modifiers))) return false;
    if (!writeF32(static_cast<float>(value.wheel_delta_x))) return false;
    if (!writeF32(static_cast<float>(value.wheel_delta_y))) return false;
    if (!writeF32(static_cast<float>(value.direct_scale))) return false;
    return true;
  }

  inline bool write(const HitTarget& value) {
    if (!writeI32(static_cast<int32_t>(value.type))) return false;
    if (!writeI32(static_cast<int32_t>(value.line))) return false;
    if (!writeI32(static_cast<int32_t>(value.column))) return false;
    if (!writeI32(static_cast<int32_t>(value.icon_id))) return false;
    if (!writeI32(static_cast<int32_t>(value.color_value))) return false;
    return true;
  }

  inline bool write(const KeyBinding& value) {
    if (!write(value.first)) return false;
    if (!write(value.second)) return false;
    if (!writeU32(static_cast<uint32_t>(value.command))) return false;
    return true;
  }

  inline bool write(const KeyChord& value) {
    if (!writeU8(static_cast<uint8_t>(value.modifiers))) return false;
    if (!writeU16(static_cast<uint16_t>(value.key_code))) return false;
    return true;
  }

  inline bool write(const SetKeyMapPayload& value) {
    if (!writeList(value.bindings)) return false;
    return true;
  }

  inline bool write(const LinkedEditingModel& value) {
    if (!writeList(value.groups)) return false;
    return true;
  }

  inline bool write(const StartLinkedEditingPayload& value) {
    if (!write(value.model)) return false;
    return true;
  }

  inline bool write(const TabStopGroup& value) {
    if (!writeU32(static_cast<uint32_t>(value.index))) return false;
    if (!writeList(value.ranges)) return false;
    if (!writeUtf8String(value.default_text)) return false;
    return true;
  }

  inline bool write(const SearchOptions& value) {
    if (!writeI32(value.case_sensitive ? 1 : 0)) return false;
    if (!writeI32(value.whole_word ? 1 : 0)) return false;
    if (!writeI32(value.use_regex ? 1 : 0)) return false;
    if (!writeI32(value.wrap_around ? 1 : 0)) return false;
    if (!writeU32(static_cast<uint32_t>(value.max_matches))) return false;
    return true;
  }

  inline bool write(const SearchReplaceRequest& value) {
    if (!writeUtf8String(value.replacement)) return false;
    return true;
  }

  inline bool write(const SearchRequest& value) {
    if (!writeUtf8String(value.pattern)) return false;
    if (!write(value.options)) return false;
    return true;
  }

  inline bool write(const SearchState& value) {
    if (!writeI32(static_cast<int32_t>(value.status))) return false;
    if (!writeUtf8String(value.pattern)) return false;
    if (!write(value.options)) return false;
    if (!writeU64(static_cast<uint64_t>(value.generation))) return false;
    if (!writeU64(static_cast<uint64_t>(value.document_revision))) return false;
    if (!writeU32(static_cast<uint32_t>(value.match_count))) return false;
    if (!writeI32(static_cast<int32_t>(value.current_index))) return false;
    if (!writeI32(value.has_current_match ? 1 : 0)) return false;
    if (!write(value.current_range)) return false;
    if (!writeUtf8String(value.error_message)) return false;
    return true;
  }

  inline bool write(const Cursor& value) {
    if (!write(value.text_position)) return false;
    if (!write(value.position)) return false;
    if (!writeF32(static_cast<float>(value.height))) return false;
    if (!writeI32(value.visible ? 1 : 0)) return false;
    if (!writeI32(value.show_dragger ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const CursorRect& value) {
    if (!writeF32(static_cast<float>(value.x))) return false;
    if (!writeF32(static_cast<float>(value.y))) return false;
    if (!writeF32(static_cast<float>(value.height))) return false;
    return true;
  }

  inline bool write(const EditorRenderModel& value) {
    if (!writeF32(static_cast<float>(value.split_x))) return false;
    if (!writeI32(value.split_line_visible ? 1 : 0)) return false;
    if (!writeF32(static_cast<float>(value.scroll_x))) return false;
    if (!writeF32(static_cast<float>(value.scroll_y))) return false;
    if (!writeF32(static_cast<float>(value.viewport_width))) return false;
    if (!writeF32(static_cast<float>(value.viewport_height))) return false;
    if (!write(value.current_line)) return false;
    if (!writeI32(static_cast<int32_t>(value.current_line_render_mode))) return false;
    if (!writeList(value.lines)) return false;
    if (!write(value.cursor)) return false;
    if (!writeList(value.range_effects)) return false;
    if (!write(value.selection_start_handle)) return false;
    if (!write(value.selection_end_handle)) return false;
    if (!writeList(value.guide_segments)) return false;
    if (!writeU32(static_cast<uint32_t>(value.max_gutter_icons))) return false;
    if (!writeList(value.gutter_icons)) return false;
    if (!writeList(value.fold_markers)) return false;
    if (!write(value.vertical_scrollbar)) return false;
    if (!write(value.horizontal_scrollbar)) return false;
    if (!writeI32(value.gutter_sticky ? 1 : 0)) return false;
    if (!writeI32(value.gutter_visible ? 1 : 0)) return false;
    if (!writeI32(static_cast<int32_t>(value.pointer_cursor_type))) return false;
    return true;
  }

  inline bool write(const FoldMarkerRenderItem& value) {
    if (!writeI32(static_cast<int32_t>(value.logical_line))) return false;
    if (!writeI32(static_cast<int32_t>(value.fold_state))) return false;
    if (!write(value.rect)) return false;
    return true;
  }

  inline bool write(const GuideSegment& value) {
    if (!writeI32(static_cast<int32_t>(value.direction))) return false;
    if (!writeI32(static_cast<int32_t>(value.type))) return false;
    if (!writeI32(static_cast<int32_t>(value.style))) return false;
    if (!write(value.start)) return false;
    if (!write(value.end)) return false;
    if (!writeI32(value.arrow_end ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const GutterIconRenderItem& value) {
    if (!writeI32(static_cast<int32_t>(value.logical_line))) return false;
    if (!writeI32(static_cast<int32_t>(value.icon_id))) return false;
    if (!write(value.rect)) return false;
    return true;
  }

  inline bool write(const LayoutMetrics& value) {
    if (!writeF32(static_cast<float>(value.font_height))) return false;
    if (!writeF32(static_cast<float>(value.font_ascent))) return false;
    if (!writeF32(static_cast<float>(value.line_spacing_add))) return false;
    if (!writeF32(static_cast<float>(value.line_spacing_mult))) return false;
    if (!writeF32(static_cast<float>(value.line_number_margin))) return false;
    if (!writeF32(static_cast<float>(value.line_number_width))) return false;
    if (!writeF32(static_cast<float>(value.content_start_padding))) return false;
    if (!writeU32(static_cast<uint32_t>(value.max_gutter_icons))) return false;
    if (!writeF32(static_cast<float>(value.inlay_hint_padding))) return false;
    if (!writeF32(static_cast<float>(value.inlay_hint_margin))) return false;
    if (!writeI32(static_cast<int32_t>(value.fold_arrow_mode))) return false;
    if (!writeI32(value.has_fold_regions ? 1 : 0)) return false;
    if (!writeI32(value.gutter_sticky ? 1 : 0)) return false;
    if (!writeI32(value.gutter_visible ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const RangeEffectRenderItem& value) {
    if (!write(value.rect)) return false;
    if (!writeI32(static_cast<int32_t>(value.kind))) return false;
    if (!write(value.style)) return false;
    return true;
  }

  inline bool write(const ScrollMetrics& value) {
    if (!writeF32(static_cast<float>(value.scale))) return false;
    if (!writeF32(static_cast<float>(value.scroll_x))) return false;
    if (!writeF32(static_cast<float>(value.scroll_y))) return false;
    if (!writeF32(static_cast<float>(value.max_scroll_x))) return false;
    if (!writeF32(static_cast<float>(value.max_scroll_y))) return false;
    if (!writeF32(static_cast<float>(value.content_width))) return false;
    if (!writeF32(static_cast<float>(value.content_height))) return false;
    if (!writeF32(static_cast<float>(value.viewport_width))) return false;
    if (!writeF32(static_cast<float>(value.viewport_height))) return false;
    if (!writeF32(static_cast<float>(value.text_area_x))) return false;
    if (!writeF32(static_cast<float>(value.text_area_width))) return false;
    if (!writeI32(value.can_scroll_x ? 1 : 0)) return false;
    if (!writeI32(value.can_scroll_y ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const ScrollbarModel& value) {
    if (!writeI32(value.visible ? 1 : 0)) return false;
    if (!writeF32(static_cast<float>(value.alpha))) return false;
    if (!writeI32(value.thumb_active ? 1 : 0)) return false;
    if (!write(value.track)) return false;
    if (!write(value.thumb)) return false;
    return true;
  }

  inline bool write(const SelectionHandle& value) {
    if (!write(value.position)) return false;
    if (!writeF32(static_cast<float>(value.height))) return false;
    if (!writeI32(value.visible ? 1 : 0)) return false;
    return true;
  }

  inline bool write(const VisualLine& value) {
    if (!writeI32(static_cast<int32_t>(value.logical_line))) return false;
    if (!writeI32(static_cast<int32_t>(value.wrap_index))) return false;
    if (!write(value.line_number_position)) return false;
    if (!writeList(value.runs)) return false;
    if (!writeI32(static_cast<int32_t>(value.kind))) return false;
    if (!writeI32(value.owns_gutter_semantics ? 1 : 0)) return false;
    if (!writeI32(static_cast<int32_t>(value.fold_state))) return false;
    return true;
  }

  inline bool write(const VisualRun& value) {
    if (!writeI32(static_cast<int32_t>(value.type))) return false;
    if (!writeF32(static_cast<float>(value.x))) return false;
    if (!writeF32(static_cast<float>(value.y))) return false;
    if (!writeU16AsUtf8String(value.text)) return false;
    if (!write(value.style)) return false;
    if (!writeI32(static_cast<int32_t>(value.icon_id))) return false;
    if (!writeI32(static_cast<int32_t>(value.color_value))) return false;
    if (!writeF32(static_cast<float>(value.width))) return false;
    if (!writeF32(static_cast<float>(value.padding))) return false;
    if (!writeF32(static_cast<float>(value.margin))) return false;
    if (!writeI32(value.active ? 1 : 0)) return false;
    return true;
  }

  template <typename T>
  bool writeList(const Vector<T>& values) {
    if (values.size() > std::numeric_limits<uint32_t>::max()) return false;
    if (!writeU32(static_cast<uint32_t>(values.size()))) return false;
    for (const auto& value : values) {
      if (!write(value)) return false;
    }
    return true;
  }

  template <typename T>
  static Vector<uint8_t> encode(const T& value, size_t reserve_size = 0) {
    ProtocolWriter writer;
    writer.reserve(reserve_size);
    if (!writer.write(value)) return {};
    return std::move(writer.buffer_);
  }

private:
  Vector<uint8_t> buffer_;
};

} // namespace protocol
} // namespace NS_SWEETEDITOR

#endif // SWEETEDITOR_PROTOCOL_CODEC_H
