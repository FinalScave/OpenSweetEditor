//
// Created by Scave on 2025/12/8.
//
#ifdef _WIN32
#include <Windows.h>
#include <DbgHelp.h>
#pragma comment(lib, "DbgHelp.lib")
#endif

#include <cstring>
#include <vector>
#include <sweeteditor/protocol_codec.h>
#include <sweeteditor/utility.h>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/document.h>
#include "c_wrapper.hpp"
#include "logging.h"

using namespace NS_SWEETEDITOR;

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

static const uint8_t* editorActionResultToBinary(const EditorActionResult& result, size_t* out_size) {
  return protocolToBinary(result, out_size, 256 + result.changes.size() * 32);
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
  if (options_data != nullptr) {
    EditorOptions decoded_options;
    if (protocol::ProtocolReader::decode(options_data, options_size, decoded_options)) {
      options = decoded_options;
    }
  }
  SharedPtr<EditorCore> editor_core = makeShared<EditorCore>(c_measurer, options);
  return toIntPtr(editor_core);
}

void free_editor(intptr_t editor_handle) {
  deleteCPtrHolder<EditorCore>(editor_handle);
}

const uint8_t* editor_set_document(intptr_t editor_handle, intptr_t document_handle, size_t* out_size) {
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

const uint8_t* editor_set_viewport(intptr_t editor_handle, int32_t width, int32_t height, size_t* out_size) {
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

const uint8_t* editor_set_render_whitespace(intptr_t editor_handle, int mode, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setRenderWhitespace(static_cast<WhitespaceRenderMode>(mode)), out_size);
}

const uint8_t* editor_set_render_line_breaks(intptr_t editor_handle, int enabled, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setRenderLineBreaks(enabled != 0), out_size);
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

const uint8_t* editor_set_handle_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  HandleConfig config;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, config)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setHandleConfig(config), out_size);
}

const uint8_t* editor_set_scrollbar_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  ScrollbarConfig config;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, config)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setScrollbarConfig(config), out_size);
}

const uint8_t* editor_set_editor_render_colors(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  EditorRenderColors colors;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, colors)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setEditorRenderColors(colors), out_size);
}

const uint8_t* editor_set_editor_range_effect_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  EditorRangeEffectStyles styles;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, styles)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->setEditorRangeEffectStyles(styles), out_size);
}

const uint8_t* editor_build_render_model(intptr_t editor_handle, size_t* out_size) {
  PERF_TIMER("c_api::editor_build_render_model");
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
  const uint8_t* payload = protocolToBinary(model, out_size, 1024);
  PERF_END(binary_serial, "renderModel::toBinary");
  return payload;
}

const uint8_t* editor_get_layout_metrics(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return protocolToBinary(editor_core->getLayoutMetrics(), out_size, sizeof(float) * 9 + sizeof(int32_t) * 5);
}

const uint8_t* editor_handle_gesture_event(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  GestureEvent event;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, event)) {
    return nullBinaryPayload(out_size);
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

const uint8_t* editor_handle_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size) {
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
  protocol::SetKeyMapPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) {
    return nullBinaryPayload(out_size);
  }

  KeyMap km;
  for (const auto& binding : payload.bindings) {
    km.addBinding(binding);
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

const uint8_t* editor_apply_text_edits(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::ApplyTextEditsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->applyTextEdits(std::move(payload.edits)), out_size);
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

const uint8_t* editor_search(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  SearchRequest request;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, request)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->search(request), out_size);
}

const uint8_t* editor_find_next_search_match(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->findNextSearchMatch(), out_size);
}

const uint8_t* editor_find_previous_search_match(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->findPreviousSearchMatch(), out_size);
}

const uint8_t* editor_replace_current_search_match(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  U8String replacement;
  protocol::ProtocolReader reader(data, size);
  if (editor_core == nullptr || !reader.readUtf8String(replacement) || !reader.done()) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->replaceCurrentSearchMatch(replacement), out_size);
}

const uint8_t* editor_replace_all_search_matches(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  U8String replacement;
  protocol::ProtocolReader reader(data, size);
  if (editor_core == nullptr || !reader.readUtf8String(replacement) || !reader.done()) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->replaceAllSearchMatches(replacement), out_size);
}

const uint8_t* editor_clear_search(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearSearch(), out_size);
}

const uint8_t* editor_get_search_state(intptr_t editor_handle, size_t* out_size) {
  SearchState state;
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core != nullptr) {
    state = editor_core->getSearchState();
  }
  return protocolToBinary(state, out_size, 128);
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
  return protocolToBinary(metrics, out_size, sizeof(float) * 11 + sizeof(int32_t) * 2);
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

const uint8_t* editor_set_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetLineDocumentHighlightsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(
      editor_core->setLineDocumentHighlights(payload.line, std::move(payload.highlights)),
      out_size);
}

const uint8_t* editor_set_batch_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  protocol::SetBatchLineDocumentHighlightsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setBatchLineDocumentHighlights(std::move(payload.entries)), out_size);
}

const uint8_t* editor_clear_document_highlights(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->clearDocumentHighlights(), out_size);
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
  protocol::SetFoldRegionsPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) return nullBinaryPayload(out_size);
  return editorActionResultToBinary(editor_core->setFoldRegions(std::move(payload.regions)), out_size);
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
  protocol::StartLinkedEditingPayload payload;
  if (editor_core == nullptr || !protocol::ProtocolReader::decode(data, size, payload)) {
    return nullBinaryPayload(out_size);
  }

  return editorActionResultToBinary(editor_core->startLinkedEditing(std::move(payload.model)), out_size);
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

int editor_ime_has_preedit(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return 0;
  }
  return editor_core->hasPreedit() ? 1 : 0;
}

const uint8_t* editor_ime_handle_command_message(intptr_t editor_handle,
                                                 const uint8_t* data,
                                                 size_t size,
                                                 size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  ImeCommandMessage payload;
  if (!protocol::ProtocolReader::decode(data, size, payload)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->handleImeCommandMessage(payload), out_size);
}

const uint8_t* editor_ime_handle_text_update_message(intptr_t editor_handle,
                                                     const uint8_t* data,
                                                     size_t size,
                                                     size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return nullBinaryPayload(out_size);
  }
  ImeTextUpdateMessage payload;
  if (!protocol::ProtocolReader::decode(data, size, payload)) {
    return nullBinaryPayload(out_size);
  }
  return editorActionResultToBinary(editor_core->handleImeTextUpdateMessage(payload), out_size);
}

int editor_ime_get_keyboard_script_class(intptr_t editor_handle) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    return static_cast<int>(ImeScriptClass::UNKNOWN);
  }
  return static_cast<int>(editor_core->getImeKeyboardScriptClass());
}

const uint8_t* editor_ime_get_sync_snapshot(intptr_t editor_handle, size_t* out_size) {
  SharedPtr<EditorCore> editor_core = getCPtrHolderValue<EditorCore>(editor_handle);
  if (editor_core == nullptr) {
    if (out_size != nullptr) {
      *out_size = 0;
    }
    return nullptr;
  }
  return protocolToBinary(editor_core->getImeSyncSnapshot(), out_size, sizeof(int32_t) * 21);
}

const uint8_t* editor_ime_get_command_input_context(intptr_t editor_handle,
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
  ImeInputContext context = editor_core->getImeCommandInputContext(before_length, after_length);
  return protocolToBinary(context, out_size, sizeof(int32_t) * 9 + sizeof(int64_t) + context.text.size());
}

const uint8_t* editor_ime_get_text_update_input_context(intptr_t editor_handle,
                                                        int scope,
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
  ImeInputContext context = editor_core->getImeTextUpdateInputContext(
      static_cast<ImeTextUpdateScope>(scope),
      before_length,
      after_length);
  return protocolToBinary(context, out_size, sizeof(int32_t) * 9 + sizeof(int64_t) + context.text.size());
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
