#include <catch2/catch_amalgamated.hpp>
#include <algorithm>
#include <functional>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {

  EditorActionResult replaceText(EditorCore& editor,
                                 const TextRange& range,
                                 const U8String& text,
                                 ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeTextReplacement replacement;
    replacement.range = range;
    replacement.text = text;
    replacement.script_class = script_class;
    return editor.replaceImeText(replacement);
  }

  EditorActionResult replaceDocumentText(EditorCore& editor,
                                         size_t start_offset,
                                         size_t end_offset,
                                         const U8String& text,
                                         int32_t cursor_offset,
                                         ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeDocumentTextReplacement replacement;
    replacement.start_offset = start_offset;
    replacement.end_offset = end_offset;
    replacement.text = text;
    replacement.cursor_offset = cursor_offset;
    replacement.script_class = script_class;
    return editor.replaceImeDocumentText(replacement);
  }

  EditorActionResult replaceInputContextText(EditorCore& editor,
                                             size_t start_offset,
                                             size_t end_offset,
                                             const U8String& text,
                                             int32_t cursor_offset,
                                             ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeInputContextTextReplacement replacement;
    replacement.start_offset = start_offset;
    replacement.end_offset = end_offset;
    replacement.text = text;
    replacement.cursor_offset = cursor_offset;
    replacement.script_class = script_class;
    return editor.replaceImeInputContextText(replacement);
  }

  EditorActionResult updateTextModelState(EditorCore& editor,
                                          ImeTextModelMode mode,
                                          uint64_t context_id,
                                          int32_t document_start_offset,
                                          const U8String& text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeTextModelState state;
    state.mode = mode;
    state.context_id = context_id;
    state.document_start_offset = document_start_offset;
    state.text = text;
    state.selection = {selection_start_offset, selection_end_offset};
    state.composition = {composing_start_offset, composing_end_offset};
    state.script_class = script_class;
    return editor.updateImeTextModelState(state);
  }

  EditorActionResult updateInputStateText(EditorCore& editor,
                                          uint64_t context_id,
                                          int32_t document_start_offset,
                                          const U8String& text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN) {
    return updateTextModelState(editor,
                                ImeTextModelMode::DOCUMENT_WINDOW,
                                context_id,
                                document_start_offset,
                                text,
                                selection_start_offset,
                                selection_end_offset,
                                composing_start_offset,
                                composing_end_offset,
                                script_class);
  }

  EditorActionResult updateTextModelDelta(EditorCore& editor,
                                          ImeTextModelMode mode,
                                          uint64_t context_id,
                                          int32_t document_start_offset,
                                          const U8String& old_text,
                                          int32_t delta_start_offset,
                                          int32_t delta_end_offset,
                                          const U8String& delta_text,
                                          int32_t selection_start_offset,
                                          int32_t selection_end_offset,
                                          int32_t composing_start_offset,
                                          int32_t composing_end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::LATIN) {
    ImeTextModelDelta delta;
    delta.mode = mode;
    delta.context_id = context_id;
    delta.document_start_offset = document_start_offset;
    delta.old_text = old_text;
    delta.delta = {delta_start_offset, delta_end_offset};
    delta.delta_text = delta_text;
    delta.selection = {selection_start_offset, selection_end_offset};
    delta.composition = {composing_start_offset, composing_end_offset};
    delta.script_class = script_class;
    return editor.updateImeTextModelDelta(delta);
  }

  EditorActionResult commitReplacementThroughTextModelDelta(EditorCore& editor,
                                                            const ImeInputContext& context,
                                                            int32_t start_offset,
                                                            int32_t end_offset,
                                                            const U8String& text,
                                                            int32_t cursor_offset,
                                                            ImeScriptClass script_class = ImeScriptClass::LATIN) {
    updateTextModelDelta(editor,
                         ImeTextModelMode::DOCUMENT_WINDOW,
                         context.id,
                         context.document_start_offset,
                         context.text,
                         -1,
                         -1,
                         "",
                         context.selection.end,
                         context.selection.end,
                         -1,
                         -1,
                         script_class);
    int32_t selection_offset = cursor_offset > 0
                               ? start_offset + static_cast<int32_t>(StrUtil::utf16Length(text)) + cursor_offset - 1
                               : start_offset + cursor_offset;
    selection_offset = std::max<int32_t>(0, selection_offset);
    return updateTextModelDelta(editor,
                                ImeTextModelMode::DOCUMENT_WINDOW,
                                context.id,
                                context.document_start_offset,
                                context.text,
                                start_offset,
                                end_offset,
                                text,
                                selection_offset,
                                selection_offset,
                                -1,
                                -1,
                                script_class);
  }

  class ImeReplayRunner {
  public:
    explicit ImeReplayRunner(EditorCore& editor) : m_editor(editor) {}

    EditorActionResult updatePreedit(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.updateImePreedit(text, script_class);
    }

    EditorActionResult commitText(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.commitImeText(text, script_class);
    }

    EditorActionResult finishPreedit() {
      return m_editor.finishImePreedit();
    }

    EditorActionResult markDocumentRange(const TextRange& range,
                                      ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.markImeDocumentRange(range, script_class);
    }

    EditorActionResult deleteBackward(size_t count = 1) {
      return m_editor.deleteImeBackward(count);
    }

    EditorActionResult deleteForward(size_t count = 1) {
      return m_editor.deleteImeForward(count);
    }

    EditorActionResult deleteSurrounding(size_t before_length, size_t after_length) {
      return m_editor.deleteImeSurrounding(before_length, after_length);
    }

    EditorActionResult selectionChanged(const TextRange& range) {
      return m_editor.notifyImeSelectionChanged(range);
    }

    EditorActionResult cursorChanged(const TextPosition& cursor) {
      return m_editor.notifyImeCursorChanged(cursor);
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
                               ImeScriptClass script_class = ImeScriptClass::LATIN) {
    return editor.updateImePreedit(text, script_class);
  }

  EditorActionResult commitText(EditorCore& editor,
                            const U8String& text,
                            ImeScriptClass script_class = ImeScriptClass::LATIN) {
    return editor.commitImeText(text, script_class);
  }

  EditorActionResult finishPreedit(EditorCore& editor) {
    return editor.finishImePreedit();
  }

  void cancelPreedit(EditorCore& editor) {
    editor.cancelImePreedit();
  }

  void markDocumentRange(EditorCore& editor,
                         const TextRange& range,
                         ImeScriptClass script_class = ImeScriptClass::LATIN) {
    editor.markImeDocumentRange(range, script_class);
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abx");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  updatePreedit(editor, "xy");
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  cancelPreedit(editor);
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abxy");

  EditorActionResult result = finishPreedit(editor);
  REQUIRE(result.content_changed);
  CHECK_FALSE(editor.isComposing());
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

  editor.commitImeText("X", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abXCD");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  editor.commitImeText("Y", 0, ImeScriptClass::LATIN);
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

  editor.setImeComposingText("xyz", 1, 2, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abxyz");
  REQUIRE(editor.isComposing());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 3}, {0, 4}}));

  editor.setImeComposingText("pq", 2, 2, ImeScriptClass::LATIN);
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

  ImeInputContext context = editor.getImeInputContext(2, 3);
  CHECK(context.document_start_offset == 3);
  CHECK(context.text == "34567");
  CHECK(context.selection.start == 2);
  CHECK(context.selection.end == 2);

  editor.markImeInputContextRange(1, 3, ImeScriptClass::LATIN);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 4}, {0, 6}}));

  replaceInputContextText(editor, 1, 3, "AB", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "0123AB6789");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME document offsets resolve inside core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("0123456789");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  editor.markImeDocumentRange(2, 5, ImeScriptClass::LATIN);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 5}}));

  replaceDocumentText(editor, 2, 5, "AB", 1, ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "01AB56789");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  editor.notifyImeDocumentSelectionChanged(1, 4);
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abx",
      3,
      3,
      2,
      3,
      ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abx");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));

  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abxy",
      4,
      4,
      2,
      4,
      ImeScriptClass::LATIN);
  CHECK(document->getU8Text() == "abxy");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 4}}));

  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abxy",
      4,
      4,
      -1,
      -1,
      ImeScriptClass::LATIN);
  CHECK_FALSE(editor.isComposing());
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  EditorActionResult insert_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abhow",
      5,
      5,
      2,
      5,
      ImeScriptClass::LATIN);
  REQUIRE(insert_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abhow");

  context = editor.getImeInputContext(8, 8);
  EditorActionResult first_delete_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abho",
      4,
      4,
      2,
      4,
      ImeScriptClass::LATIN);
  REQUIRE(first_delete_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abho");
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 4}}));

  context = editor.getImeInputContext(8, 8);
  EditorActionResult second_delete_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abh",
      3,
      3,
      2,
      3,
      ImeScriptClass::LATIN);
  REQUIRE(second_delete_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abh");
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 2}, {0, 3}}));

  context = editor.getImeInputContext(8, 8);
  EditorActionResult clear_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "ab",
      2,
      2,
      2,
      2,
      ImeScriptClass::LATIN);
  REQUIRE(clear_result.content_changed);
  CHECK_FALSE(editor.isComposing());
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abhow",
      5,
      5,
      2,
      5,
      ImeScriptClass::LATIN);
  REQUIRE(editor.isComposing());

  context = editor.getImeInputContext(8, 8);
  EditorActionResult commit_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "abhello",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.isComposing());
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  EditorActionResult mark_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "hello",
      5,
      5,
      0,
      5,
      ImeScriptClass::LATIN);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));

  context = editor.getImeInputContext(8, 8);
  EditorActionResult finish_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "hello",
      5,
      5,
      -1,
      -1,
      ImeScriptClass::LATIN);

  CHECK_FALSE(finish_result.content_changed);
  CHECK_FALSE(editor.isComposing());
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  EditorActionResult mark_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "enabled",
      7,
      7,
      0,
      7,
      ImeScriptClass::LATIN);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));

  context = editor.getImeInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextModelDelta(
      editor,
      context,
      0,
      7,
      "enable",
      1,
      ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(commit_result.ime_sync.clear_platform_preedit);
  CHECK(document->getU8Text() == "enable");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  context = editor.getImeInputContext(8, 8);
  CHECK_FALSE(context.has_composition);
}

TEST_CASE("EditorCore IME text model transient input defers composing text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  ImeInputContext context = editor.getImeTextModelInputContext(
      ImeTextModelMode::TRANSIENT_INPUT,
      8,
      8);
  EditorActionResult composing_result = updateTextModelState(editor,
      ImeTextModelMode::TRANSIENT_INPUT,
      context.id,
      context.document_start_offset,
      "nih",
      3,
      3,
      0,
      3,
      ImeScriptClass::CJK);

  CHECK(composing_result.handled);
  CHECK_FALSE(composing_result.content_changed);
  CHECK_FALSE(composing_result.needs_ime_sync);
  CHECK_FALSE(composing_result.ime_sync.clear_platform_preedit);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text().empty());

  context = editor.getImeTextModelInputContext(ImeTextModelMode::TRANSIENT_INPUT, 8, 8);
  CHECK(context.text == "nih");
  CHECK(context.has_composition);
  CHECK(context.composition.start == 0);
  CHECK(context.composition.end == 3);

  EditorActionResult commit_result = updateTextModelState(editor,
      ImeTextModelMode::TRANSIENT_INPUT,
      context.id,
      context.document_start_offset,
      "你好",
      2,
      2,
      -1,
      -1,
      ImeScriptClass::CJK);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.needs_ime_sync);
  CHECK(commit_result.ime_sync.clear_platform_preedit);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "你好");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));

  context = editor.getImeTextModelInputContext(ImeTextModelMode::TRANSIENT_INPUT, 8, 8);
  EditorActionResult second_composing_result = updateTextModelState(editor,
      ImeTextModelMode::TRANSIENT_INPUT,
      context.id,
      context.document_start_offset,
      "ni",
      2,
      2,
      0,
      2,
      ImeScriptClass::CJK);
  CHECK(second_composing_result.handled);
  CHECK_FALSE(second_composing_result.content_changed);
  CHECK_FALSE(second_composing_result.needs_ime_sync);
  CHECK_FALSE(second_composing_result.ime_sync.clear_platform_preedit);

  context = editor.getImeTextModelInputContext(ImeTextModelMode::TRANSIENT_INPUT, 8, 8);
  EditorActionResult stale_result = updateTextModelState(editor,
      ImeTextModelMode::TRANSIENT_INPUT,
      context.id + 1,
      context.document_start_offset,
      "nin",
      3,
      3,
      0,
      3,
      ImeScriptClass::CJK);
  CHECK(stale_result.handled);
  CHECK(stale_result.needs_ime_sync);
  CHECK(stale_result.ime_sync.clear_platform_preedit);

  EditorActionResult clear_result = updateTextModelState(editor,
      ImeTextModelMode::TRANSIENT_INPUT,
      context.id,
      context.document_start_offset,
      "",
      0,
      0,
      -1,
      -1,
      ImeScriptClass::CJK);
  CHECK(clear_result.handled);
  CHECK(clear_result.needs_ime_sync);
  CHECK(clear_result.ime_sync.clear_platform_preedit);
}

TEST_CASE("EditorCore IME text model delta commits replacement after composing clear") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeInputContext context = editor.getImeTextModelInputContext(
      ImeTextModelMode::DOCUMENT_WINDOW,
      8,
      8);
  EditorActionResult mark_result = updateTextModelState(editor,
      ImeTextModelMode::DOCUMENT_WINDOW,
      context.id,
      context.document_start_offset,
      "enabled",
      7,
      7,
      0,
      7,
      ImeScriptClass::LATIN);
  REQUIRE(mark_result.handled);
  REQUIRE(editor.isComposing());

  context = editor.getImeTextModelInputContext(ImeTextModelMode::DOCUMENT_WINDOW, 8, 8);
  EditorActionResult clear_result = updateTextModelDelta(editor,
      ImeTextModelMode::DOCUMENT_WINDOW,
      context.id,
      context.document_start_offset,
      "enabled",
      -1,
      -1,
      "",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN);
  CHECK(clear_result.handled);
  CHECK_FALSE(clear_result.content_changed);
  REQUIRE(editor.isComposing());

  EditorActionResult commit_result = updateTextModelDelta(editor,
      ImeTextModelMode::DOCUMENT_WINDOW,
      context.id,
      context.document_start_offset,
      "enabled",
      0,
      7,
      "enables",
      7,
      7,
      -1,
      -1,
      ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.ime_sync.clear_platform_preedit);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "enables");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME input state replacement ignores mid-range plain edit heuristic") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 6});

  ImeInputContext context = editor.getImeInputContext(8, 8);
  EditorActionResult mark_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "enabled",
      6,
      6,
      0,
      7,
      ImeScriptClass::LATIN);

  CHECK_FALSE(mark_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().kind == CompositionKind::DOCUMENT_RANGE);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));

  context = editor.getImeInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextModelDelta(
      editor,
      context,
      0,
      7,
      "enables",
      1,
      ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(commit_result.ime_sync.clear_platform_preedit);
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  EditorActionResult preedit_result = updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "how",
      3,
      3,
      0,
      3,
      ImeScriptClass::LATIN);

  REQUIRE(preedit_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().kind == CompositionKind::PREEDIT_TEXT);
  CHECK(document->getU8Text() == "how");

  context = editor.getImeInputContext(8, 8);
  EditorActionResult commit_result = commitReplacementThroughTextModelDelta(
      editor,
      context,
      0,
      3,
      "ho",
      1,
      ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK(commit_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(commit_result.ime_sync.clear_platform_preedit);
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

  ImeInputContext context = editor.getImeInputContext(8, 8);
  updateInputStateText(editor,
      context.id,
      context.document_start_offset,
      "a你c",
      2,
      2,
      1,
      2,
      ImeScriptClass::CJK);

  CHECK(document->getU8Text() == "a你c");
  REQUIRE(editor.isComposing());
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abhow");

  editor.backspace();
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abho");

  editor.backspace();
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abh");

  editor.backspace();
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");

  editor.setCursorPosition({0, 4});
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());
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
  REQUIRE(editor.isComposing());

  EditorActionResult result = editor.finishImePreedit();
  CHECK_FALSE(result.content_changed);
  CHECK_FALSE(result.cursor_changed);
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(editor.isComposing());

  EditorActionResult result = editor.commitImeText("", ImeScriptClass::LATIN);

  CHECK(result.content_changed);
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "how tail");

  cancelPreedit(editor);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word tail");
  CHECK_FALSE(editor.canUndo());

  editor.setCursorPosition({0, 4});
  markDocumentRange(editor, {{0, 0}, {0, 4}});
  updatePreedit(editor, "how");
  EditorActionResult result = finishPreedit(editor);
  CHECK_FALSE(result.content_changed);
  CHECK(result.changes.empty());
  CHECK_FALSE(editor.isComposing());
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
  CHECK_FALSE(editor.isComposing());
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
  CHECK_FALSE(editor.isComposing());
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

  EditorActionResult result = editor.updateImePreedit("how");

  REQUIRE(result.handled);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abhow");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
  CHECK(result.ime_sync.has_composing_session);
  CHECK(result.ime_sync.has_visible_composition_range);
  CHECK(result.ime_sync.visible_composition_range == (TextRange{{0, 2}, {0, 5}}));
}

TEST_CASE("EditorCore IME event commit text finishes active preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  editor.updateImePreedit("how");
  REQUIRE(editor.isComposing());

  EditorActionResult result = editor.commitImeText("how");

  REQUIRE(result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "abhow");
  CHECK_FALSE(result.ime_sync.has_composing_session);
  CHECK_FALSE(result.ime_sync.has_visible_composition_range);
}

TEST_CASE("EditorCore IME event backspace shrinks preedit step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  editor.updateImePreedit("how");

  editor.deleteImeBackward(1);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abho");

  editor.deleteImeBackward(1);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abh");

  editor.deleteImeBackward(1);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore IME finish clears platform document range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 12});

  editor.markImeDocumentRange({{0, 7}, {0, 12}}, ImeScriptClass::LATIN);
  REQUIRE(editor.isComposing());

  EditorActionResult result = editor.finishImePreedit();

  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK_FALSE(result.ime_sync.has_composing_session);
  CHECK_FALSE(result.ime_sync.has_visible_composition_range);
  CHECK_FALSE(result.ime_sync.has_platform_marked_range);
  CHECK(result.ime_sync.preedit_storage == ImePreeditStorage::NONE);
  CHECK(result.ime_sync.clear_platform_preedit);
}

TEST_CASE("EditorCore IME event CJK preedit stays visible until commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  EditorActionResult update_result = editor.updateImePreedit("ni", ImeScriptClass::CJK);

  REQUIRE(update_result.handled);
  CHECK(document->getU8Text() == "ni");
  CHECK(editor.isComposing());
  CHECK(editor.hasComposingSession());
  CHECK(update_result.ime_sync.has_composing_session);
  CHECK(update_result.ime_sync.has_visible_composition_range);
  CHECK(update_result.ime_sync.preedit_storage == ImePreeditStorage::VISIBLE_DOCUMENT_COMPOSITION);

  EditorActionResult commit_result = editor.commitImeText("\xE4\xBD\xA0", ImeScriptClass::CJK);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "\xE4\xBD\xA0");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK_FALSE(commit_result.ime_sync.has_composing_session);
  CHECK(commit_result.ime_sync.preedit_storage == ImePreeditStorage::NONE);
}


TEST_CASE("EditorCore visible preedit does not affect document undo and renders decoration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 5, 0, "hint"}});

  EditorActionResult update_result = editor.updateImePreedit("ni", ImeScriptClass::CJK);

  CHECK(update_result.content_changed);
  CHECK(document->getU8Text() == "valueni");
  CHECK_FALSE(editor.canUndo());
  CHECK(editor.isComposing());
  CHECK(update_result.ime_sync.preedit_storage == ImePreeditStorage::VISIBLE_DOCUMENT_COMPOSITION);

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

  editor.updateImePreedit("h", ImeScriptClass::LATIN);
  editor.updateImePreedit("ho", ImeScriptClass::LATIN);
  editor.updateImePreedit("how", ImeScriptClass::LATIN);

  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.canUndo());

  EditorActionResult commit_result = editor.commitImeText("how", ImeScriptClass::LATIN);

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
    run_delete_case([](EditorCore& editor) { return editor.deleteImeBackward(1); });
  }
  SECTION("delete forward") {
    run_delete_case([](EditorCore& editor) { return editor.deleteImeForward(1); });
  }
  SECTION("delete surrounding") {
    run_delete_case([](EditorCore& editor) { return editor.deleteImeSurrounding(1, 1); });
  }
}

TEST_CASE("EditorCore IME document range accepts cursor inside word for latin script") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});
  EditorActionResult middle_result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(middle_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(middle_result.ime_sync.has_visible_composition_range);
  CHECK(middle_result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(middle_result.ime_sync.has_platform_marked_range);
  ImeInputContext middle_context = editor.getImeInputContext(5, 5);
  CHECK(middle_context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  CHECK(middle_context.text == "hello");
  CHECK(middle_context.selection.start == 2);
  CHECK(middle_context.selection.end == 2);
  CHECK(middle_context.has_composition);
  CHECK(middle_context.composition.start == 0);
  CHECK(middle_context.composition.end == 5);

  cancelPreedit(editor);
  editor.setCursorPosition({0, 5});
  EditorActionResult end_result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(end_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(end_result.ime_sync.has_visible_composition_range);
  CHECK(end_result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(end_result.ime_sync.has_platform_marked_range);
  ImeInputContext end_context = editor.getImeInputContext(5, 5);
  CHECK(end_context.kind == ImeInputContextKind::DOCUMENT_WINDOW);
  CHECK(end_context.text == "hello");
  CHECK(end_context.selection.start == 5);
  CHECK(end_context.selection.end == 5);
  CHECK(end_context.has_composition);
  CHECK(end_context.composition.start == 0);
  CHECK(end_context.composition.end == 5);
}

TEST_CASE("EditorCore IME document range clamps overflowing line to document end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello\nworld");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({1, 5});

  EditorActionResult result = editor.markImeDocumentRange({{1, 1}, {99, 0}}, ImeScriptClass::LATIN);

  CHECK(result.handled);
  REQUIRE(editor.isComposing());
  CHECK(result.ime_sync.has_visible_composition_range);
  CHECK(result.ime_sync.visible_composition_range == (TextRange{{1, 1}, {1, 5}}));
  CHECK(result.ime_sync.has_platform_marked_range);
  CHECK(result.ime_sync.platform_marked_range == (TextRange{{1, 1}, {1, 5}}));
}

TEST_CASE("EditorCore IME unknown document range can start platform composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  EditorActionResult result = editor.markImeDocumentRange({{0, 0}, {0, 5}});

  CHECK(result.handled);
  REQUIRE(editor.isComposing());
  CHECK(editor.hasComposingSession());
  CHECK(result.ime_sync.has_visible_composition_range);
  CHECK(result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(result.ime_sync.has_platform_marked_range);

  EditorActionResult commit_result = editor.commitImeText("helloWorld", ImeScriptClass::LATIN);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(mark_result.ime_sync.has_visible_composition_range);

  EditorActionResult commit_result = ime.commitText("helloWorld");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
  CHECK(mark_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());

  EditorActionResult preedit_result = ime.updatePreedit("how");
  CHECK(preedit_result.handled);
  CHECK_FALSE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(mark_result.ime_sync.has_visible_composition_range);
  CHECK(mark_result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 7}}));

  EditorActionResult commit_result = ime.commitText("enable");
  REQUIRE(commit_result.handled);
  CHECK(document->getU8Text() == "enable");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());

  EditorActionResult remark_result = ime.markDocumentRange({{0, 0}, {0, 6}});
  CHECK(remark_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());

  EditorActionResult preedit_result = ime.updatePreedit("enable");
  CHECK(preedit_result.handled);
  CHECK_FALSE(preedit_result.content_changed);
  CHECK(document->getU8Text() == "enable");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(editor.isComposing());

  EditorActionResult commit_result = ime.commitText("hexllo");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(editor.isComposing());

  EditorActionResult commit_result = ime.commitText("defaults");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "defaults");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(editor.isComposing());

  EditorActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  EditorActionResult finish_result = ime.finishPreedit();
  CHECK(finish_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
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
  REQUIRE(mark_result.ime_sync.has_visible_composition_range);
  CHECK(mark_result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 2}}));

  EditorActionResult first_update = ime.updatePreedit("vax");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "vaxlue");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 3}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  EditorActionResult second_update = ime.updatePreedit("vaxy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "vaxylue");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME platform full word range uses marked range preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}},
                                                      ImeScriptClass::UNKNOWN);
  REQUIRE(mark_result.ime_sync.has_visible_composition_range);
  CHECK(mark_result.ime_sync.visible_composition_range == (TextRange{{0, 0}, {0, 6}}));

  EditorActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}


TEST_CASE("EditorCore IME platform full word range keeps word-end full payload incremental") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}},
                        ImeScriptClass::UNKNOWN);
  REQUIRE(editor.isComposing());

  EditorActionResult first_update = ime.updatePreedit("valuex");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "valuex");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  EditorActionResult finish_result = ime.finishPreedit();
  CHECK_FALSE(finish_result.content_changed);
  CHECK(finish_result.changes.empty());
  CHECK_FALSE(editor.isComposing());
  CHECK(editor.canUndo());
  ime.markDocumentRange({{0, 0}, {0, 6}},
                        ImeScriptClass::UNKNOWN);
  REQUIRE(editor.isComposing());

  EditorActionResult second_update = ime.updatePreedit("valuexy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "valuexy");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore full word preedit selection commit keeps provider decorations stable") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
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
  CHECK_FALSE(editor.isComposing());
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
  CHECK_FALSE(editor.isComposing());
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
  REQUIRE(mark_result.ime_sync.has_visible_composition_range);
  CHECK(mark_result.ime_sync.has_platform_marked_range);

  EditorActionResult replace_result = ime.replaceText({{0, 2}, {0, 3}}, "helloWorld");
  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "hehelloWorldlo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 12}));
}
