#include <catch2/catch_amalgamated.hpp>
#include <algorithm>
#include <functional>
#include <vector>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {

  EditorActionResult replaceText(EditorCore& editor,
                                 const TextRange& range,
                                 const U8String& text,
                                 ImeScriptClass script_class = ImeScriptClass::LATIN) {
    editor.setSelection(range);
    ImeInputContext context = editor.getImeCommandInputContext(8, 8);
    ImeCommandMessage message;
    message.kind = ImeCommandKind::REPLACE_TEXT;
    message.context_id = context.id;
    message.context_revision = context.revision;
    message.document_start_offset = context.document_start_offset;
    message.range = context.selection;
    message.text = text;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult updateTextSnapshot(EditorCore& editor,
                                          ImeTextUpdateScope mode,
                                          uint64_t context_id,
                                          int32_t context_revision,
                                          const U8String& text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN,
                                          ImeMarkedRangeRole marked_range_role = ImeMarkedRangeRole::PREEDIT,
                                          int32_t document_start_offset = 0) {
    ImeTextUpdateMessage message;
    message.kind = ImeTextUpdateKind::SNAPSHOT;
    message.scope = mode;
    message.context_id = context_id;
    message.context_revision = context_revision;
    message.document_start_offset = document_start_offset;
    message.text = text;
    message.selection = {selection_start_offset, selection_end_offset};
    message.marked_range = {marked_range_role, {composing_start_offset, composing_end_offset}};
    message.script_class = script_class;
    return editor.handleImeTextUpdateMessage(message);
  }

  EditorActionResult applyDocumentWindowSnapshot(EditorCore& editor,
                                          uint64_t context_id,
                                          int32_t context_revision,
                                          const U8String& text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN,
                                          int32_t document_start_offset = 0) {
    return updateTextSnapshot(editor,
                                ImeTextUpdateScope::DOCUMENT_WINDOW,
                                context_id,
                                context_revision,
                                text,
                                selection_start_offset,
                                selection_end_offset,
                                composing_start_offset,
                                composing_end_offset,
                                script_class,
                                ImeMarkedRangeRole::PREEDIT,
                                document_start_offset);
  }

  EditorActionResult updateTextPatch(EditorCore& editor,
                                          ImeTextUpdateScope mode,
                                          uint64_t context_id,
                                          int32_t context_revision,
                                          const U8String& old_text,
                                          int32_t delta_start_offset,
                                          int32_t delta_end_offset,
                                          const U8String& delta_text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN,
                                          ImeMarkedRangeRole marked_range_role = ImeMarkedRangeRole::PREEDIT,
                                          int32_t document_start_offset = 0) {
    ImeTextUpdateMessage message;
    message.kind = ImeTextUpdateKind::PATCH;
    message.scope = mode;
    message.context_id = context_id;
    message.context_revision = context_revision;
    message.document_start_offset = document_start_offset;
    message.text = old_text;
    message.patch = {{delta_start_offset, delta_end_offset}, delta_text};
    message.selection = {selection_start_offset, selection_end_offset};
    message.marked_range = {marked_range_role, {composing_start_offset, composing_end_offset}};
    message.script_class = script_class;
    return editor.handleImeTextUpdateMessage(message);
  }

  EditorActionResult replaceContextText(EditorCore& editor,
                                           const ImeInputContext& context,
                                           size_t start_offset,
                                           size_t end_offset,
                                           const U8String& text,
                                           int32_t cursor_offset,
                                           ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::REPLACE_TEXT;
    message.context_id = context.id;
    message.context_revision = context.revision;
    message.document_start_offset = context.document_start_offset;
    message.range = {static_cast<int32_t>(start_offset), static_cast<int32_t>(end_offset)};
    message.text = text;
    message.cursor_offset = cursor_offset;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  size_t utf16OffsetForPosition(const U8String& text,
                                const TextPosition& position,
                                bool line_overflow_to_end) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);

    size_t current_line = 0;
    size_t line_start = 0;
    for (size_t i = 0; i < utf16.size() && current_line < position.line; ++i) {
      if (utf16[i] == u'\n') {
        ++current_line;
        line_start = i + 1;
      }
    }

    if (current_line < position.line) {
      return line_overflow_to_end ? utf16.size() : line_start;
    }

    size_t line_end = line_start;
    while (line_end < utf16.size() && utf16[line_end] != u'\n') {
      ++line_end;
    }

    const size_t column = std::min<size_t>(position.column, line_end - line_start);
    return line_start + column;
  }

  EditorActionResult handleCommand(EditorCore& editor,
                                   const ImeInputContext& context,
                                   ImeCommandKind kind,
                                   int32_t start_offset = -1,
                                   int32_t end_offset = -1,
                                   const U8String& text = "",
                                   int32_t cursor_offset = 1,
                                   int32_t delete_before = 0,
                                   int32_t delete_after = 0,
                                   ImeTextUnit text_unit = ImeTextUnit::GRAPHEME,
                                   ImeScriptClass script_class = ImeScriptClass::LATIN,
                                   ImeMarkedRangeRole marked_role = ImeMarkedRangeRole::NONE) {
    ImeCommandMessage message;
    message.kind = kind;
    message.context_id = context.id;
    message.context_revision = context.revision;
    message.document_start_offset = context.document_start_offset;
    message.range = {start_offset, end_offset};
    message.selection = {start_offset, end_offset};
    message.text = text;
    message.cursor_offset = cursor_offset;
    message.delete_before = delete_before;
    message.delete_after = delete_after;
    message.text_unit = text_unit;
    message.marked_role = marked_role;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult commitReplacementThroughTextPatch(EditorCore& editor,
                                                            const ImeInputContext& context,
                                                            int32_t start_offset,
                                                            int32_t end_offset,
                                                            const U8String& text,
                                                            int32_t cursor_offset,
                                                            ImeScriptClass script_class = ImeScriptClass::LATIN) {
    updateTextPatch(editor,
                         ImeTextUpdateScope::DOCUMENT_WINDOW,
                         context.id,
                         context.revision,
                         context.text,
                         -1,
                         -1,
                         "",
                         context.selection.end,
                         context.selection.end,
                         -1,
                         -1,
                         script_class,
                         ImeMarkedRangeRole::PREEDIT,
                         context.document_start_offset);
    int32_t selection_offset = cursor_offset > 0
                               ? start_offset + static_cast<int32_t>(StrUtil::utf16Length(text)) + cursor_offset - 1
                               : start_offset + cursor_offset;
    selection_offset = std::max<int32_t>(0, selection_offset);
    return updateTextPatch(editor,
                                ImeTextUpdateScope::DOCUMENT_WINDOW,
                                context.id,
                                context.revision,
                                context.text,
                                start_offset,
                                end_offset,
                                text,
                                selection_offset,
                                selection_offset,
                                -1,
                                -1,
                                script_class,
                                ImeMarkedRangeRole::PREEDIT,
                                context.document_start_offset);
  }

  EditorActionResult updatePreedit(EditorCore& editor,
                                   const U8String& text,
                                   ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult setPreeditSelection(EditorCore& editor,
                                         const U8String& text,
                                         size_t selection_start_offset,
                                         size_t selection_end_offset,
                                         ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult commitText(EditorCore& editor,
                                const U8String& text,
                                ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult commitText(EditorCore& editor,
                                const U8String& text,
                                int cursor_offset,
                                ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult finishPreedit(EditorCore& editor);
  void cancelPreedit(EditorCore& editor);
  EditorActionResult markDocumentRange(EditorCore& editor,
                                       const TextRange& range,
                                       ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult markDocumentRange(EditorCore& editor,
                                       size_t start_offset,
                                       size_t end_offset,
                                       ImeScriptClass script_class = ImeScriptClass::LATIN);
  EditorActionResult deleteBackward(EditorCore& editor,
                                    size_t count = 1,
                                    ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
  EditorActionResult deleteForward(EditorCore& editor,
                                   size_t count = 1,
                                   ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
  EditorActionResult deleteSurrounding(EditorCore& editor,
                                       size_t before_length,
                                       size_t after_length,
                                       ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
  EditorActionResult selectionChanged(EditorCore& editor, const TextRange& range);
  EditorActionResult cursorChanged(EditorCore& editor, const TextPosition& cursor);
  EditorActionResult setKeyboardScriptClass(EditorCore& editor, ImeScriptClass script_class);

  class ImeReplayRunner {
  public:
    explicit ImeReplayRunner(EditorCore& editor) : m_editor(editor) {}

    EditorActionResult updatePreedit(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return ::updatePreedit(m_editor, text, script_class);
    }

    EditorActionResult commitText(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return ::commitText(m_editor, text, script_class);
    }

    EditorActionResult finishPreedit() {
      return ::finishPreedit(m_editor);
    }

    EditorActionResult markDocumentRange(const TextRange& range,
                                      ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return ::markDocumentRange(m_editor, range, script_class);
    }

    EditorActionResult deleteBackward(size_t count = 1) {
      ImeCommandMessage message;
      message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
      message.delete_before = static_cast<int32_t>(count);
      return m_editor.handleImeCommandMessage(message);
    }

    EditorActionResult deleteForward(size_t count = 1) {
      ImeCommandMessage message;
      message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
      message.delete_after = static_cast<int32_t>(count);
      return m_editor.handleImeCommandMessage(message);
    }

    EditorActionResult deleteSurrounding(size_t before_length, size_t after_length) {
      ImeCommandMessage message;
      message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
      message.delete_before = static_cast<int32_t>(before_length);
      message.delete_after = static_cast<int32_t>(after_length);
      return m_editor.handleImeCommandMessage(message);
    }

    EditorActionResult selectionChanged(const TextRange& range) {
      return m_editor.setSelection(range);
    }

    EditorActionResult cursorChanged(const TextPosition& cursor) {
      return m_editor.setCursorPosition(cursor);
    }

    EditorActionResult replaceText(const TextRange& range,
                                const U8String& text,
                                ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return ::replaceText(m_editor, range, text, script_class);
    }

  private:
    EditorCore& m_editor;
  };

  EditorActionResult updatePreedit(EditorCore& editor,
                               const U8String& text,
                               ImeScriptClass script_class) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::SET_PREEDIT_TEXT;
    message.text = text;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult commitText(EditorCore& editor,
                            const U8String& text,
                            ImeScriptClass script_class) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::COMMIT_TEXT;
    message.text = text;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult commitText(EditorCore& editor,
                            const U8String& text,
                            int cursor_offset,
                            ImeScriptClass script_class) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::COMMIT_TEXT;
    message.text = text;
    message.cursor_offset = cursor_offset;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult setPreeditSelection(EditorCore& editor,
                                         const U8String& text,
                                         size_t selection_start_offset,
                                         size_t selection_end_offset,
                                         ImeScriptClass script_class) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::SET_PREEDIT_TEXT;
    message.text = text;
    message.selection = {
      static_cast<int32_t>(selection_start_offset),
      static_cast<int32_t>(selection_end_offset)
    };
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult finishPreedit(EditorCore& editor) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::FINISH_PREEDIT;
    return editor.handleImeCommandMessage(message);
  }

  void cancelPreedit(EditorCore& editor) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::CANCEL_PREEDIT;
    editor.handleImeCommandMessage(message);
  }

  EditorActionResult markDocumentRange(EditorCore& editor,
                                       const TextRange& range,
                                       ImeScriptClass script_class) {
    ImeInputContext context = editor.getImeTextUpdateInputContext(
        ImeTextUpdateScope::DOCUMENT_WINDOW,
        4096,
        4096);
    const size_t context_start = static_cast<size_t>(std::max<int32_t>(0, context.document_start_offset));
    const size_t document_start = utf16OffsetForPosition(context.text, range.start, false);
    const size_t document_end = utf16OffsetForPosition(context.text, range.end, true);
    ImeCommandMessage message;
    message.kind = ImeCommandKind::SET_MARKED_RANGE;
    message.context_id = context.id;
    message.context_revision = context.revision;
    message.range = {
      static_cast<int32_t>(document_start >= context_start ? document_start - context_start : 0),
      static_cast<int32_t>(document_end >= context_start ? document_end - context_start : 0)
    };
    message.marked_role = ImeMarkedRangeRole::PREEDIT;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult markDocumentRange(EditorCore& editor,
                                       size_t start_offset,
                                       size_t end_offset,
                                       ImeScriptClass script_class) {
    return markDocumentRange(editor,
                             {{0, start_offset}, {0, end_offset}},
                             script_class);
  }

  EditorActionResult deleteBackward(EditorCore& editor,
                                    size_t count,
                                    ImeTextUnit text_unit) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
    message.delete_before = static_cast<int32_t>(count);
    message.text_unit = text_unit;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult deleteForward(EditorCore& editor,
                                   size_t count,
                                   ImeTextUnit text_unit) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
    message.delete_after = static_cast<int32_t>(count);
    message.text_unit = text_unit;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult deleteSurrounding(EditorCore& editor,
                                       size_t before_length,
                                       size_t after_length,
                                       ImeTextUnit text_unit) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
    message.delete_before = static_cast<int32_t>(before_length);
    message.delete_after = static_cast<int32_t>(after_length);
    message.text_unit = text_unit;
    return editor.handleImeCommandMessage(message);
  }

  EditorActionResult selectionChanged(EditorCore& editor, const TextRange& range) {
    return editor.setSelection(range);
  }

  EditorActionResult cursorChanged(EditorCore& editor, const TextPosition& cursor) {
    return editor.setCursorPosition(cursor);
  }

  EditorActionResult setKeyboardScriptClass(EditorCore& editor, ImeScriptClass script_class) {
    ImeCommandMessage message;
    message.kind = ImeCommandKind::SET_KEYBOARD_SCRIPT;
    message.script_class = script_class;
    return editor.handleImeCommandMessage(message);
  }

}

TEST_CASE("EditorCore composition update is transient and cancel restores original text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  updatePreedit(editor, "x");
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abx");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  updatePreedit(editor, "xy");
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  cancelPreedit(editor);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore composition end commits final text once and supports undo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "xy");
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abxy");

  EditorActionResult result = finishPreedit(editor);
  REQUIRE(result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore IME commit cursor offset is applied in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abCD");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  commitText(editor, "X", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abXCD");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  commitText(editor, "Y", 0, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abXYCD");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME composing selection offsets are applied in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  setPreeditSelection(editor, "xyz", 1, 2, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abxyz");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 3}, {0, 4}}));

  setPreeditSelection(editor, "pq", 2, 2, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abpq");
  CHECK_FALSE(editor.hasSelection());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME input context offsets resolve inside core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("0123456789");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeCommandInputContext(2, 3);
  CHECK(context.document_start_offset == 3);
  CHECK(context.text == "34567");
  CHECK(context.selection.start == 2);
  CHECK(context.selection.end == 2);

  updateTextSnapshot(editor,
                       ImeTextUpdateScope::DOCUMENT_WINDOW,
                       context.id,
                       context.revision,
                       context.text,
                       context.selection.start,
                       context.selection.end,
                       1,
                       3,
                       ImeScriptClass::LATIN);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 4}, {0, 6}}));

  replaceContextText(editor, context, 1, 3, "AB", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "0123AB6789");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME selection context does not replace document text window") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("0123456789");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeCommandInputContext(2, 3);
  REQUIRE(context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  REQUIRE(context.id != 0);
  CHECK(context.document_start_offset == 3);

  ImeInputContext selection_context = editor.getImeCommandInputContext(0, 0);
  CHECK(selection_context.kind == ImeInputContextKind::NONE);
  CHECK(selection_context.id == 0);

  replaceContextText(editor, context, 1, 3, "AB", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "0123AB6789");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME document load invalidates stale input state context") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> first_document = makeShared<LineArrayDocument>("0123456789");
  editor.loadDocument(first_document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  ImeInputContext context = editor.getImeCommandInputContext(2, 2);
  REQUIRE(context.id != 0);

  SharedPtr<Document> second_document = makeShared<LineArrayDocument>("abcdef");
  EditorActionResult load_result = editor.loadDocument(second_document);
  CHECK(load_result.needs_ime_sync);
  CHECK(load_result.ime_sync.clear_system_mark);

  EditorActionResult result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "345X",
      4,
      4,
      -1,
      -1,
      ImeScriptClass::CJK);

  CHECK(result.handled);
  CHECK(result.needs_ime_sync);
  CHECK(result.ime_sync.clear_system_mark);
  CHECK_FALSE(result.content_changed);
  CHECK(second_document->getU8Text() == "abcdef");
}

TEST_CASE("EditorCore IME document window update without context requests resync") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  EditorActionResult result = applyDocumentWindowSnapshot(editor,
      0,
      0,
      "x",
      1,
      1,
      -1,
      -1,
      ImeScriptClass::CJK);

  CHECK(result.handled);
  CHECK(result.needs_ime_sync);
  CHECK(result.ime_sync.clear_system_mark);
  CHECK_FALSE(result.content_changed);
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
}

TEST_CASE("EditorCore IME text model document window owns zero-length context") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  ImeInputContext regular_context = editor.getImeCommandInputContext(0, 0);
  CHECK(regular_context.kind == ImeInputContextKind::NONE);
  CHECK(regular_context.id == 0);

  ImeInputContext text_model_context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      0,
      0);
  CHECK(text_model_context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  REQUIRE(text_model_context.id != 0);
  CHECK(text_model_context.text.empty());
  CHECK(text_model_context.selection.start == 0);
  CHECK(text_model_context.selection.end == 0);
}

TEST_CASE("EditorCore IME document offsets resolve inside core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("0123456789");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  markDocumentRange(editor, 2, 5, ImeScriptClass::LATIN);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 5}}));

  replaceText(editor, TextRange{{0, 2}, {0, 5}}, "AB", ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "01AB56789");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  selectionChanged(editor, TextRange{{0, 1}, {0, 4}});
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 1}, {0, 4}}));
}

TEST_CASE("EditorCore IME input state text update inserts and finishes composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abx",
      3,
      3,
      2,
      3,
      ImeScriptClass::CJK);
  CHECK(document->getU8Text() == "abx");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));

  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abxy",
      4,
      4,
      2,
      4,
      ImeScriptClass::CJK);
  CHECK(document->getU8Text() == "abxy");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 4}}));

  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abxy",
      4,
      4,
      -1,
      -1,
      ImeScriptClass::CJK);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME input state composing text replaces previous composing span") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult insert_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abhow",
      5,
      5,
      2,
      5,
      ImeScriptClass::CJK);
  REQUIRE(insert_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abhow");

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult first_delete_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abho",
      4,
      4,
      2,
      4,
      ImeScriptClass::CJK);
  REQUIRE(first_delete_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abho");
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 4}}));

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult second_delete_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abh",
      3,
      3,
      2,
      3,
      ImeScriptClass::CJK);
  REQUIRE(second_delete_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abh");
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult clear_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "ab",
      2,
      2,
      2,
      2,
      ImeScriptClass::CJK);
  REQUIRE(clear_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore IME input state commit replaces previous composing span") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abhow",
      5,
      5,
      2,
      5,
      ImeScriptClass::CJK);
  REQUIRE(editor.hasPreedit());

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult commit_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "abhello",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abhello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME input state text update replaces document text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 4}});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "hXo",
      2,
      2,
      -1,
      -1,
      ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "hXo");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore IME input state mark-only composing stays document range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "hello",
      5,
      5,
      0,
      5,
      ImeScriptClass::CJK);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult finish_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "hello",
      5,
      5,
      -1,
      -1,
      ImeScriptClass::CJK);

  CHECK_FALSE(finish_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
}

TEST_CASE("EditorCore IME input state replacement commits matching document range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "enabled",
      7,
      7,
      0,
      7,
      ImeScriptClass::CJK);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextPatch(
      editor,
      context,
      0,
      7,
      "enable",
      1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK(document->getU8Text() == "enable");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  context = editor.getImeCommandInputContext(8, 8);
  CHECK_FALSE(context.has_preedit_range);
}

TEST_CASE("EditorCore IME text model transient input defers composing text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::TRANSIENT_INPUT,
      8,
      8);
  EditorActionResult composing_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::TRANSIENT_INPUT,
      context.id,
      context.revision,
      "nih",
      3,
      3,
      0,
      3,
      ImeScriptClass::CJK);

  CHECK(composing_result.handled);
  CHECK_FALSE(composing_result.content_changed);
  CHECK_FALSE(composing_result.needs_ime_sync);
  CHECK_FALSE(composing_result.ime_sync.clear_system_mark);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text().empty());

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::TRANSIENT_INPUT, 8, 8);
  CHECK(context.text == "nih");
  CHECK(context.has_preedit_range);
  CHECK(context.preedit_range.start == 0);
  CHECK(context.preedit_range.end == 3);

  EditorActionResult commit_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::TRANSIENT_INPUT,
      context.id,
      context.revision,
      "你好",
      2,
      2,
      -1,
      -1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.needs_ime_sync);
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "你好");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::TRANSIENT_INPUT, 8, 8);
  EditorActionResult second_composing_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::TRANSIENT_INPUT,
      context.id,
      context.revision,
      "ni",
      2,
      2,
      0,
      2,
      ImeScriptClass::CJK);
  CHECK(second_composing_result.handled);
  CHECK_FALSE(second_composing_result.content_changed);
  CHECK_FALSE(second_composing_result.needs_ime_sync);
  CHECK_FALSE(second_composing_result.ime_sync.clear_system_mark);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::TRANSIENT_INPUT, 8, 8);
  EditorActionResult stale_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::TRANSIENT_INPUT,
      context.id + 1,
      context.revision,
      "nin",
      3,
      3,
      0,
      3,
      ImeScriptClass::CJK);
  CHECK(stale_result.handled);
  CHECK(stale_result.needs_ime_sync);
  CHECK(stale_result.ime_sync.clear_system_mark);

  EditorActionResult clear_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::TRANSIENT_INPUT,
      context.id,
      context.revision,
      "",
      0,
      0,
      -1,
      -1,
      ImeScriptClass::CJK);
  CHECK(clear_result.handled);
  CHECK(clear_result.needs_ime_sync);
  CHECK(clear_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text model delta commits replacement after composing clear") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      7,
      7,
      0,
      7,
      ImeScriptClass::CJK);
  REQUIRE(mark_result.handled);
  REQUIRE(editor.hasPreedit());

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult clear_result = updateTextPatch(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      -1,
      -1,
      "",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::CJK);
  CHECK(clear_result.handled);
  CHECK_FALSE(clear_result.content_changed);
  REQUIRE(editor.hasPreedit());

  EditorActionResult commit_result = updateTextPatch(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      0,
      7,
      "enables",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "enables");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME text model text delta applies reported selection range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult result = updateTextPatch(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      context.text,
      0,
      5,
      "helloWorld",
      0,
      5,
      -1,
      -1,
      ImeScriptClass::LATIN);

  REQUIRE(result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  REQUIRE(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 5}}));
}

TEST_CASE("EditorCore IME text model latin composition stays platform marked only") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hello",
      5,
      5,
      0,
      5,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);

  CHECK(result.handled);
  CHECK_FALSE(result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(result.needs_ime_sync);
  CHECK(result.ime_sync.has_system_mark_range);
  CHECK(result.ime_sync.system_mark_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(result.ime_sync.has_preedit_range);
  CHECK_FALSE(result.ime_sync.clear_system_mark);

  ImeInputContext next_context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  CHECK_FALSE(next_context.has_preedit_range);
  REQUIRE(next_context.has_system_mark_range);
  CHECK(next_context.system_mark_range.start == 0);
  CHECK(next_context.system_mark_range.end == 5);
}

TEST_CASE("EditorCore IME text model latin replacement commits hidden marked range after composing clear") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      7,
      7,
      0,
      7,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult clear_result = updateTextPatch(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      -1,
      -1,
      "",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);
  CHECK(clear_result.handled);
  CHECK_FALSE(clear_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(clear_result.ime_sync.clear_system_mark);

  EditorActionResult commit_result = updateTextPatch(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled",
      0,
      7,
      "enables",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "enables");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME text model platform marked range does not replace later insertion") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hello world",
      5,
      5,
      0,
      5,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult insert_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "helloX world",
      6,
      6,
      5,
      6,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::PREEDIT);

  REQUIRE(insert_result.content_changed);
  CHECK(document->getU8Text() == "helloX world");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 5}, {0, 6}}));
}

TEST_CASE("EditorCore IME operation system marked range does not start composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      5);

  CHECK(result.handled);
  CHECK_FALSE(result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(result.needs_ime_sync);
  REQUIRE(result.ime_sync.has_system_mark_range);
  CHECK(result.ime_sync.system_mark_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(result.ime_sync.has_preedit_range);

  ImeInputContext next_context = editor.getImeCommandInputContext(8, 8);
  CHECK_FALSE(next_context.has_preedit_range);
  REQUIRE(next_context.has_system_mark_range);
  CHECK(next_context.system_mark_range.start == 0);
  CHECK(next_context.system_mark_range.end == 5);
}

TEST_CASE("EditorCore IME operation preedit after system marked range inserts at cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      5,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeCommandInputContext(8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult preedit_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_PREEDIT_TEXT,
      -1,
      -1,
      "x");

  REQUIRE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo world");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));
  CHECK_FALSE(preedit_result.ime_sync.has_system_mark_range);
  CHECK(preedit_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update preedit over system mark replaces marked word once") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hello world",
      5,
      5,
      0,
      5,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult preedit_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "helloX world",
      6,
      6,
      0,
      6,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::PREEDIT);

  REQUIRE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "helloX world");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
}

TEST_CASE("EditorCore IME text update preedit over system mark supports middle edit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hello",
      2,
      2,
      0,
      5,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult preedit_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hexllo",
      3,
      3,
      2,
      3,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::PREEDIT);

  REQUIRE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME text update commit over system mark replaces candidate range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled world",
      7,
      7,
      0,
      7,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult commit_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enables world",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "enables world");
  CHECK_FALSE(editor.hasPreedit());
  CHECK(commit_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update single character candidate replaces system mark") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "enabled world",
      7,
      7,
      0,
      7,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult commit_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "x world",
      1,
      1,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "x world");
  CHECK_FALSE(editor.hasPreedit());
  CHECK(commit_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME operation commit after system marked range inserts at selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      5);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeCommandInputContext(8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult commit_result = handleCommand(editor,
      context,
      ImeCommandKind::COMMIT_TEXT,
      -1,
      -1,
      "X");

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloX world");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(commit_result.ime_sync.has_system_mark_range);
  CHECK(commit_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME operation commit system marked role inserts at selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      7,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());

  context = editor.getImeCommandInputContext(8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult commit_result = handleCommand(editor,
      context,
      ImeCommandKind::COMMIT_TEXT,
      -1,
      -1,
      "x",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "enabledx world");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(commit_result.ime_sync.has_system_mark_range);
  CHECK(commit_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update clearing system mark keeps text and clears sync mark") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("h");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "h",
      1,
      1,
      0,
      1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult clear_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "h",
      1,
      1,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(clear_result.handled);
  CHECK_FALSE(clear_result.content_changed);
  CHECK(document->getU8Text() == "h");
  CHECK_FALSE(clear_result.ime_sync.has_system_mark_range);
  CHECK(clear_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update delete over system mark deletes at reported cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("h");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "h",
      1,
      1,
      0,
      1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult delete_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "",
      0,
      0,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK_FALSE(delete_result.ime_sync.has_system_mark_range);
  CHECK(delete_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update system mark shrink keeps deleting") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "hello",
      5,
      5,
      0,
      5,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  const std::vector<U8String> states {"hell", "hel", "he", "h"};
  for (const U8String& text : states) {
    context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
    REQUIRE(context.has_system_mark_range);
    const int32_t length = static_cast<int32_t>(StrUtil::utf16Length(text));
    EditorActionResult delete_result = updateTextSnapshot(editor,
        ImeTextUpdateScope::DOCUMENT_WINDOW,
        context.id,
        context.revision,
        text,
        length,
        length,
        0,
        length,
        ImeScriptClass::LATIN,
        ImeMarkedRangeRole::SYSTEM_MARK);

    REQUIRE(delete_result.content_changed);
    CHECK(document->getU8Text() == text);
    CHECK(editor.getCursorPosition() == (TextPosition{0, static_cast<size_t>(length)}));
    CHECK(delete_result.ime_sync.has_system_mark_range);
    CHECK_FALSE(delete_result.ime_sync.clear_system_mark);
  }

  context = editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult final_delete_result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      context.id,
      context.revision,
      "",
      0,
      0,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE);

  REQUIRE(final_delete_result.content_changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK_FALSE(final_delete_result.ime_sync.has_system_mark_range);
  CHECK(final_delete_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME operation selection over system marked range stays reported") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("h");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      1,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult selection_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_SELECTION,
      0,
      0,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(selection_result.handled);
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore IME operation delete clears system marked range and deletes at cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("h");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      1,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult delete_result = handleCommand(editor,
      context,
      ImeCommandKind::DELETE_SURROUNDING_TEXT,
      -1,
      -1,
      "",
      1,
      1,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);

  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK_FALSE(delete_result.ime_sync.has_system_mark_range);
  CHECK(delete_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME operation delete uses reported context selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("h");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      1,
      "",
      1,
      0,
      0,
      ImeTextUnit::GRAPHEME,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::SYSTEM_MARK);
  REQUIRE(mark_result.handled);
  REQUIRE(mark_result.ime_sync.has_system_mark_range);

  context = editor.getImeCommandInputContext(8, 8);
  editor.setCursorPosition({0, 0});

  ImeCommandMessage message;
  message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
  message.context_id = context.id;
  message.context_revision = context.revision;
  message.document_start_offset = context.document_start_offset;
  message.selection = {1, 1};
  message.delete_before = 1;
  message.text_unit = ImeTextUnit::GRAPHEME;
  message.marked_role = ImeMarkedRangeRole::SYSTEM_MARK;

  EditorActionResult delete_result = editor.handleImeCommandMessage(message);

  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK_FALSE(delete_result.ime_sync.has_system_mark_range);
  CHECK(delete_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME operation delete with stale context requests resync") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeInputContext stale_context = editor.getImeCommandInputContext(8, 8);
  editor.getImeCommandInputContext(8, 8);

  ImeCommandMessage message;
  message.kind = ImeCommandKind::DELETE_SURROUNDING_TEXT;
  message.context_id = stale_context.id;
  message.context_revision = stale_context.revision;
  message.document_start_offset = stale_context.document_start_offset;
  message.selection = stale_context.selection;
  message.delete_before = 1;
  message.text_unit = ImeTextUnit::GRAPHEME;

  EditorActionResult delete_result = editor.handleImeCommandMessage(message);

  REQUIRE(delete_result.handled);
  CHECK_FALSE(delete_result.content_changed);
  CHECK(document->getU8Text() == "ab");
  CHECK(delete_result.needs_ime_sync);
}

TEST_CASE("EditorCore IME operation replace local range consumes explicit candidate range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = handleCommand(editor,
      context,
      ImeCommandKind::SET_MARKED_RANGE,
      0,
      7);
  REQUIRE(mark_result.handled);

  context = editor.getImeCommandInputContext(8, 8);
  REQUIRE(context.has_system_mark_range);
  EditorActionResult replace_result = handleCommand(editor,
      context,
      ImeCommandKind::REPLACE_TEXT,
      0,
      7,
      "enables");

  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "enables");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(replace_result.ime_sync.has_system_mark_range);
  CHECK(replace_result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME text update stale local context deletes through window anchor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeInputContext stale_context = editor.getImeTextUpdateInputContext(
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      8,
      8);
  editor.getImeTextUpdateInputContext(ImeTextUpdateScope::DOCUMENT_WINDOW, 8, 8);

  EditorActionResult result = updateTextSnapshot(editor,
      ImeTextUpdateScope::DOCUMENT_WINDOW,
      stale_context.id,
      stale_context.revision,
      "hell",
      4,
      4,
      -1,
      -1,
      ImeScriptClass::LATIN,
      ImeMarkedRangeRole::NONE,
      stale_context.document_start_offset);

  REQUIRE(result.content_changed);
  CHECK(document->getU8Text() == "hell");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK_FALSE(result.ime_sync.has_system_mark_range);
}

TEST_CASE("EditorCore IME input state replacement ignores mid-range plain edit heuristic") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 6});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult mark_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "enabled",
      6,
      6,
      0,
      7,
      ImeScriptClass::CJK);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextPatch(
      editor,
      context,
      0,
      7,
      "enables",
      1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK(document->getU8Text() == "enables");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME text model replacement commits preedit fallback") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult preedit_result = applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "how",
      3,
      3,
      0,
      3,
      ImeScriptClass::CJK);

  REQUIRE(preedit_result.content_changed);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().kind == CompositionKind::PREEDIT_TEXT);
  CHECK(document->getU8Text() == "how");

  context = editor.getImeCommandInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextPatch(
      editor,
      context,
      0,
      3,
      "ho",
      1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(commit_result.ime_sync.clear_system_mark);
  CHECK(document->getU8Text() == "ho");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore IME input state composing replacement maps to previous range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 2}});

  ImeInputContext context = editor.getImeCommandInputContext(8, 8);
  applyDocumentWindowSnapshot(editor,
      context.id,
      context.revision,
      "a你c",
      2,
      2,
      1,
      2,
      ImeScriptClass::CJK);

  CHECK(document->getU8Text() == "a你c");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 1}, {0, 2}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}


TEST_CASE("EditorCore backspace during composition shrinks text step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "how");
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abhow");

  editor.backspace();
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abho");

  editor.backspace();
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abh");

  editor.backspace();
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore moving cursor commits composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  updatePreedit(editor, "x");
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "axbc");

  editor.setCursorPosition({0, 4});
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "axbc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore set composing region preserves cursor at range end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));
}

TEST_CASE("EditorCore composition end preserves cursor at existing composing range end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasPreedit());

  EditorActionResult result = finishPreedit(editor);
  CHECK_FALSE(result.content_changed);
  CHECK_FALSE(result.cursor_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));
  CHECK(result.changes.empty());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore IME empty commit replaces active composing text with empty text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasPreedit());

  EditorActionResult result = commitText(editor, "", ImeScriptClass::LATIN);

  CHECK(result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition {0, 0}));
}

TEST_CASE("EditorCore document range preedit commit is undoable without duplicate text change") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  updatePreedit(editor, "how");
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "how tail");

  cancelPreedit(editor);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "word tail");
  CHECK_FALSE(editor.canUndo());

  editor.setCursorPosition({0, 4});
  markDocumentRange(editor, {{0, 0}, {0, 4}});
  updatePreedit(editor, "how");
  EditorActionResult result = finishPreedit(editor);
  CHECK_FALSE(result.content_changed);
  CHECK(result.changes.empty());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "how tail");
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(document->getU8Text() == "word tail");
}

TEST_CASE("EditorCore document range composition finish does not move inlay hints") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("static int[] colors = new int[0];");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 19});

  editor.setLineInlayHints(0, {InlayHint{InlayType::COLOR, 20, static_cast<int32_t>(0xFF112233u), ""}});

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  EditorActionResult first_finish = finishPreedit(editor);
  CHECK_FALSE(first_finish.content_changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  EditorActionResult second_finish = finishPreedit(editor);
  CHECK_FALSE(second_finish.content_changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun* color_run = nullptr;
  for (const auto& line : model.lines) {
    for (const auto& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT && run.color_value == static_cast<int32_t>(0xFF112233u)) {
        color_run = &run;
      }
    }
  }

  REQUIRE(color_run != nullptr);
  CHECK(color_run->column == 20);
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore repeated document composing region commits replacement once") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x, double y) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 12});

  TextRange point_range {{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);

  EditorActionResult result = commitText(editor, "Points");
  REQUIRE(result.content_changed);
  REQUIRE(result.changes.size() == 1);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
  CHECK(result.changes[0].range == point_range);
  CHECK(result.changes[0].old_text == "Point");
  CHECK(result.changes[0].new_text == "Points");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}




TEST_CASE("EditorCore IME event update preedit drives visible composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  EditorActionResult result = updatePreedit(editor, "how");

  REQUIRE(result.handled);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abhow");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
  CHECK(result.ime_sync.has_preedit_range);
  CHECK(result.ime_sync.preedit_range == (TextRange{{0, 2}, {0, 5}}));
}

TEST_CASE("EditorCore IME event commit text finishes active preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "how");
  REQUIRE(editor.hasPreedit());

  EditorActionResult result = commitText(editor, "how");

  REQUIRE(result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abhow");
  CHECK_FALSE(result.ime_sync.has_preedit_range);
}

TEST_CASE("EditorCore IME event backspace shrinks preedit step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "how");

  deleteBackward(editor, 1);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abho");

  deleteBackward(editor, 1);
  REQUIRE(editor.hasPreedit());
  CHECK(document->getU8Text() == "abh");

  deleteBackward(editor, 1);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore IME finish clears platform document range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 12});

  markDocumentRange(editor, {{0, 7}, {0, 12}}, ImeScriptClass::LATIN);
  REQUIRE(editor.hasPreedit());

  EditorActionResult result = finishPreedit(editor);

  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(result.ime_sync.has_preedit_range);
  CHECK_FALSE(result.ime_sync.has_system_mark_range);
  CHECK(result.ime_sync.clear_system_mark);
}

TEST_CASE("EditorCore IME event CJK preedit stays visible until commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  EditorActionResult update_result = updatePreedit(editor, "ni", ImeScriptClass::CJK);

  REQUIRE(update_result.handled);
  CHECK(document->getU8Text() == "ni");
  CHECK(editor.hasPreedit());
  CHECK(update_result.ime_sync.has_preedit_range);

  EditorActionResult commit_result = commitText(editor, "\xE4\xBD\xA0", ImeScriptClass::CJK);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "\xE4\xBD\xA0");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(commit_result.ime_sync.has_preedit_range);
}


TEST_CASE("EditorCore visible preedit does not affect document undo and renders decoration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 5, 0, "hint"}});

  EditorActionResult update_result = updatePreedit(editor, "ni", ImeScriptClass::CJK);

  CHECK(update_result.content_changed);
  CHECK(document->getU8Text() == "valueni");
  CHECK_FALSE(editor.canUndo());
  CHECK(editor.hasPreedit());
  CHECK(update_result.ime_sync.has_preedit_range);

  EditorRenderModel model;
  EditorRangeEffectStyles styles;
  styles.ime_composition.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.ime_composition.underline_style = RangeEffectUnderlineStyle::SOLID;
  editor.setEditorRangeEffectStyles(styles);
  editor.buildRenderModel(model);
  bool has_composition_effect = false;
  for (const RangeEffectRenderItem& effect : model.range_effects) {
    if (effect.kind == RangeEffectKind::IME_COMPOSITION) {
      has_composition_effect = true;
      break;
    }
  }
  CHECK(has_composition_effect);

  const VisualRun* hint_run = nullptr;
  for (const auto& line : model.lines) {
    for (const auto& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT) {
        hint_run = &run;
      }
    }
  }

  REQUIRE(hint_run != nullptr);
  CHECK(hint_run->column == 5);
}

TEST_CASE("EditorCore IME preedit updates become one undoable commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  updatePreedit(editor, "h", ImeScriptClass::LATIN);
  updatePreedit(editor, "ho", ImeScriptClass::LATIN);
  updatePreedit(editor, "how", ImeScriptClass::LATIN);

  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.canUndo());

  EditorActionResult commit_result = commitText(editor, "how", ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(document->getU8Text().empty());
}





TEST_CASE("EditorCore IME replay delete events remove selection once") {
  auto run_delete_case = [](const std::function<EditorActionResult(EditorCore&)>& delete_action) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
    SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    ImeReplayRunner ime(editor);

    ime.selectionChanged({{0, 0}, {0, 5}});
    REQUIRE(editor.hasSelection());

    EditorActionResult result = delete_action(editor);

    REQUIRE(result.content_changed);
    CHECK(document->getU8Text() == " world");
    CHECK_FALSE(editor.hasSelection());
    CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  };

  SECTION("delete backward") {
    run_delete_case([](EditorCore& editor) { return deleteBackward(editor, 1); });
  }
  SECTION("delete forward") {
    run_delete_case([](EditorCore& editor) { return deleteForward(editor, 1); });
  }
  SECTION("delete surrounding") {
    run_delete_case([](EditorCore& editor) { return deleteSurrounding(editor, 1, 1); });
  }
}

TEST_CASE("EditorCore IME document range accepts cursor inside word for latin script") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});
  EditorActionResult middle_result = markDocumentRange(editor, {{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(middle_result.handled);
  REQUIRE(editor.hasPreedit());
  CHECK(middle_result.ime_sync.has_preedit_range);
  CHECK(middle_result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(middle_result.ime_sync.has_system_mark_range);
  ImeInputContext middle_context = editor.getImeCommandInputContext(5, 5);
  CHECK(middle_context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  CHECK(middle_context.text == "hello");
  CHECK(middle_context.selection.start == 2);
  CHECK(middle_context.selection.end == 2);
  CHECK(middle_context.has_preedit_range);
  CHECK(middle_context.preedit_range.start == 0);
  CHECK(middle_context.preedit_range.end == 5);

  cancelPreedit(editor);
  editor.setCursorPosition({0, 5});
  EditorActionResult end_result = markDocumentRange(editor, {{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(end_result.handled);
  REQUIRE(editor.hasPreedit());
  CHECK(end_result.ime_sync.has_preedit_range);
  CHECK(end_result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(end_result.ime_sync.has_system_mark_range);
  ImeInputContext end_context = editor.getImeCommandInputContext(5, 5);
  CHECK(end_context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  CHECK(end_context.text == "hello");
  CHECK(end_context.selection.start == 5);
  CHECK(end_context.selection.end == 5);
  CHECK(end_context.has_preedit_range);
  CHECK(end_context.preedit_range.start == 0);
  CHECK(end_context.preedit_range.end == 5);
}

TEST_CASE("EditorCore IME document range clamps overflowing line to document end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello\nworld");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({1, 5});

  EditorActionResult result = markDocumentRange(editor, {{1, 1}, {99, 0}}, ImeScriptClass::LATIN);

  CHECK(result.handled);
  REQUIRE(editor.hasPreedit());
  CHECK(result.ime_sync.has_preedit_range);
  CHECK(result.ime_sync.preedit_range == (TextRange{{1, 1}, {1, 5}}));
  CHECK_FALSE(result.ime_sync.has_system_mark_range);
}

TEST_CASE("EditorCore IME unknown document range can start platform composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  EditorActionResult result = markDocumentRange(editor, {{0, 0}, {0, 5}});

  CHECK(result.handled);
  REQUIRE(editor.hasPreedit());
  CHECK(editor.hasPreedit());
  CHECK(result.ime_sync.has_preedit_range);
  CHECK(result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(result.ime_sync.has_system_mark_range);

  EditorActionResult commit_result = commitText(editor, "helloWorld", ImeScriptClass::LATIN);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.hasPreedit());
}




TEST_CASE("EditorCore IME document range candidate replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(mark_result.ime_sync.has_preedit_range);

  EditorActionResult commit_result = ime.commitText("helloWorld");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 10}));
}

TEST_CASE("EditorCore suppresses candidate exact re-mark after commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});
  ImeReplayRunner ime(editor);

  ime.updatePreedit("how");
  EditorActionResult commit_result = ime.commitText("how");
  REQUIRE(commit_result.handled);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
  CHECK(mark_result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());

  EditorActionResult preedit_result = ime.updatePreedit("how");
  CHECK(preedit_result.handled);
  CHECK_FALSE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
}

TEST_CASE("EditorCore suppresses document range candidate exact re-mark after commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 7}});
  REQUIRE(mark_result.ime_sync.has_preedit_range);
  CHECK(mark_result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 7}}));

  EditorActionResult commit_result = ime.commitText("enable");
  REQUIRE(commit_result.handled);
  CHECK(document->getU8Text() == "enable");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());

  EditorActionResult remark_result = ime.markDocumentRange({{0, 0}, {0, 6}});
  CHECK(remark_result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());

  EditorActionResult preedit_result = ime.updatePreedit("enable");
  CHECK(preedit_result.handled);
  CHECK_FALSE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "enable");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
}


TEST_CASE("EditorCore IME document range full-word edit commit inserts at middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.hasPreedit());

  EditorActionResult commit_result = ime.commitText("hexllo");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME document range suffix candidate commit replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("default");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 7}});
  REQUIRE(editor.hasPreedit());

  EditorActionResult commit_result = ime.commitText("defaults");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "defaults");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 8}));
}


TEST_CASE("EditorCore IME document range suffix preedit replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 6}});
  REQUIRE(editor.hasPreedit());

  EditorActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  EditorActionResult finish_result = ime.finishPreedit();
  CHECK(finish_result.handled);
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "Strings");
}


TEST_CASE("EditorCore IME platform prefix range updates only cursor prefix") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 2}},
                                                      ImeScriptClass::LATIN);
  REQUIRE(mark_result.ime_sync.has_preedit_range);
  CHECK(mark_result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 2}}));

  EditorActionResult first_update = ime.updatePreedit("vax");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "vaxlue");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 3}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  EditorActionResult second_update = ime.updatePreedit("vaxy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "vaxylue");
  REQUIRE(editor.hasPreedit());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME platform full word range uses marked range preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  setKeyboardScriptClass(editor, ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}},
                                                      ImeScriptClass::UNKNOWN);
  REQUIRE(mark_result.ime_sync.has_preedit_range);
  CHECK(mark_result.ime_sync.preedit_range == (TextRange{{0, 0}, {0, 6}}));

  EditorActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  CHECK(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}


TEST_CASE("EditorCore IME platform full word range keeps word-end full payload incremental") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  setKeyboardScriptClass(editor, ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}},
                        ImeScriptClass::UNKNOWN);
  REQUIRE(editor.hasPreedit());

  EditorActionResult first_update = ime.updatePreedit("valuex");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "valuex");
  CHECK(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  EditorActionResult finish_result = ime.finishPreedit();
  CHECK_FALSE(finish_result.content_changed);
  CHECK(finish_result.changes.empty());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.canUndo());
  ime.markDocumentRange({{0, 0}, {0, 6}},
                        ImeScriptClass::UNKNOWN);
  REQUIRE(editor.hasPreedit());

  EditorActionResult second_update = ime.updatePreedit("valuexy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "valuexy");
  CHECK(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore full word preedit selection commit keeps provider decorations stable") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  setKeyboardScriptClass(editor, ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}},
                        ImeScriptClass::UNKNOWN);
  EditorActionResult update_result = ime.updatePreedit("valuex");
  REQUIRE(update_result.content_changed);
  REQUIRE(document->getU8Text() == "valuex tail");

  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 6, 0, "hint"}});

  EditorActionResult selection_result = ime.selectionChanged({{0, 11}, {0, 11}});
  CHECK_FALSE(selection_result.content_changed);
  CHECK_FALSE(editor.hasPreedit());
  CHECK(document->getU8Text() == "valuex tail");
  CHECK(editor.canUndo());

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun* hint_run = nullptr;
  for (const auto& line : model.lines) {
    for (const auto& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT && run.text == CHAR16("hint")) {
        hint_run = &run;
      }
    }
  }

  REQUIRE(hint_run != nullptr);
  CHECK(hint_run->column == 6);

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(document->getU8Text() == "value tail");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}








TEST_CASE("EditorCore IME explicit replace text inserts without composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  EditorActionResult replace_result = ime.replaceText({{0, 0}, {0, 5}}, "result");
  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "result");
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME explicit replace text replaces requested range inside composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(mark_result.ime_sync.has_preedit_range);
  CHECK_FALSE(mark_result.ime_sync.has_system_mark_range);

  EditorActionResult replace_result = ime.replaceText({{0, 2}, {0, 3}}, "helloWorld");
  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "hehelloWorldlo");
  CHECK_FALSE(editor.hasPreedit());
  CHECK_FALSE(editor.hasPreedit());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 12}));
}
