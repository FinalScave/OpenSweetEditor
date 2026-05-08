#include <catch2/catch_amalgamated.hpp>
#include <functional>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {

  class ImeReplayRunner {
  public:
    explicit ImeReplayRunner(EditorCore& editor) : m_editor(editor) {}

    ImeActionResult updatePreedit(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.updateImePreedit(text, script_class);
    }

    ImeActionResult commitText(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.commitImeText(text, script_class);
    }

    ImeActionResult finishPreedit() {
      return m_editor.finishImePreedit();
    }

    ImeActionResult markDocumentRange(const TextRange& range,
                                      ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.markImeDocumentRange(range, script_class);
    }

    ImeActionResult markDocumentRange(const TextRange& range,
                                      ImeScriptClass script_class,
                                      ImeDocumentRangeRole role) {
      return m_editor.markImeDocumentRange(range, script_class, role);
    }

    ImeActionResult deleteBackward(size_t count = 1) {
      return m_editor.deleteImeBackward(count);
    }

    ImeActionResult deleteForward(size_t count = 1) {
      return m_editor.deleteImeForward(count);
    }

    ImeActionResult deleteSurrounding(size_t before_length, size_t after_length) {
      return m_editor.deleteImeSurrounding(before_length, after_length);
    }

    ImeActionResult selectionChanged(const TextRange& range) {
      return m_editor.notifyImeSelectionChanged(range);
    }

    ImeActionResult cursorChanged(const TextPosition& cursor) {
      return m_editor.notifyImeCursorChanged(cursor);
    }

    ImeActionResult replaceText(const TextRange& range,
                                const U8String& text,
                                ImeScriptClass script_class = ImeScriptClass::LATIN) {
      return m_editor.replaceImeText(range, text, script_class);
    }

  private:
    EditorCore& m_editor;
  };

  TextEditResult updatePreedit(EditorCore& editor,
                               const U8String& text,
                               ImeScriptClass script_class = ImeScriptClass::LATIN) {
    return editor.updateImePreedit(text, script_class).edit_result;
  }

  TextEditResult commitText(EditorCore& editor,
                            const U8String& text,
                            ImeScriptClass script_class = ImeScriptClass::LATIN) {
    return editor.commitImeText(text, script_class).edit_result;
  }

  TextEditResult finishPreedit(EditorCore& editor) {
    return editor.finishImePreedit().edit_result;
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
  editor.setCompositionEnabled(true);
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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "xy");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abxy");

  TextEditResult result = finishPreedit(editor);
  REQUIRE(result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(editor.canUndo());

  TextEditResult undo_result = editor.undo();
  REQUIRE(undo_result.changed);
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore composition disabled mode commits only on commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(false);
  editor.setCursorPosition({0, 2});

  updatePreedit(editor, "q");
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ab");

  TextEditResult result = commitText(editor, "z");
  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "abz");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore backspace during composition shrinks text step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 1});

  updatePreedit(editor, "x");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");

  editor.setCursorPosition({0, 4});
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
}

TEST_CASE("EditorCore set composing region preserves cursor at range end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.finishImePreedit();
  CHECK_FALSE(result.edit_result.changed);
  CHECK_FALSE(result.cursor_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));
  CHECK(result.edit_result.changes.empty());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore IME empty commit replaces active composing text with empty text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.commitImeText("", ImeScriptClass::LATIN);

  CHECK(result.content_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition {0, 0}));
}

TEST_CASE("EditorCore composing text after document range replaces only on commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
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
  TextEditResult result = finishPreedit(editor);
  REQUIRE(result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "how tail");
  CHECK(editor.canUndo());

  TextEditResult undo_result = editor.undo();
  REQUIRE(undo_result.changed);
  CHECK(document->getU8Text() == "word tail");
}

TEST_CASE("EditorCore document range composition finish does not move inlay hints") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("static int[] colors = new int[0];");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 19});

  editor.setLineInlayHints(0, {InlayHint{InlayType::COLOR, 20, "", 0, static_cast<int32_t>(0xFF112233u)}});

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  TextEditResult first_finish = finishPreedit(editor);
  CHECK_FALSE(first_finish.changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  TextEditResult second_finish = finishPreedit(editor);
  CHECK_FALSE(second_finish.changed);
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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 12});

  TextRange point_range {{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);

  TextEditResult result = commitText(editor, "Points");
  REQUIRE(result.changed);
  REQUIRE(result.changes.size() == 1);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
  CHECK(result.changes[0].range == point_range);
  CHECK(result.changes[0].old_text == "Point");
  CHECK(result.changes[0].new_text == "Points");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}

TEST_CASE("EditorCore cursor move after hidden document composition opens new latin word") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x, double y) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 12});

  TextRange point_range {{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  REQUIRE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  TextEditResult finish_result = finishPreedit(editor);
  CHECK_FALSE(finish_result.changed);
  CHECK_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  editor.setCursorPosition({0, 0});
  REQUIRE(editor.isComposing());
  TextRange record_range {{0, 0}, {0, 6}};
  CHECK(editor.getCompositionState().anchor_range == record_range);

  TextEditResult commit_result = commitText(editor, "Points");
  REQUIRE(commit_result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "Points Point(double x, double y) {}");
  CHECK(commit_result.changes[0].range == record_range);
}

TEST_CASE("EditorCore set composing text consumes pending document range and suppresses duplicate commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x, double y) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 12});

  TextRange point_range {{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  finishPreedit(editor);
  REQUIRE_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  TextEditResult set_result = updatePreedit(editor, "Points");
  REQUIRE(set_result.changed);
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");

  TextEditResult duplicate_result = commitText(editor, "Points");
  CHECK_FALSE(duplicate_result.changed);
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
}

TEST_CASE("EditorCore pending document commit is discarded when anchor text changed") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x, double y) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 12});

  TextRange point_range {{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  finishPreedit(editor);
  editor.replaceText(point_range, "Value");

  TextEditResult stale_result = commitText(editor, "Points");
  CHECK_FALSE(stale_result.changed);
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "record Value(double x, double y) {}");
}

TEST_CASE("EditorCore IME event update preedit drives visible composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  ImeActionResult result = editor.updateImePreedit("how");

  REQUIRE(result.handled);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abhow");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
  CHECK(result.sync.has_composing_session);
  CHECK(result.sync.has_visible_composition_range);
  CHECK(result.sync.visible_composition_range == (TextRange{{0, 2}, {0, 5}}));
}

TEST_CASE("EditorCore IME event commit text finishes active preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  editor.updateImePreedit("how");
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.commitImeText("how");

  REQUIRE(result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "abhow");
  CHECK_FALSE(result.sync.has_composing_session);
  CHECK_FALSE(result.sync.has_visible_composition_range);
}

TEST_CASE("EditorCore IME event backspace shrinks preedit step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
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

TEST_CASE("EditorCore IME sync snapshot exposes hidden document session range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 12});

  editor.markImeDocumentRange({{0, 7}, {0, 12}}, ImeScriptClass::LATIN);
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.finishImePreedit();

  CHECK_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());
  CHECK(result.sync.has_composing_session);
  CHECK_FALSE(result.sync.has_visible_composition_range);
  CHECK_FALSE(result.sync.has_platform_marked_range);
  CHECK(result.sync.platform_text_window_text == "record Point(double x) {}");
  CHECK(result.sync.platform_text_window_start_offset == 0);
  CHECK(result.sync.platform_text_window_composing_start_offset == -1);
  CHECK(result.sync.platform_text_window_composing_end_offset == -1);
  CHECK(result.sync.preedit_storage == ImePreeditStorage::HIDDEN_AWAITING_COMMIT);
}

TEST_CASE("EditorCore IME event CJK preedit stays shadow until commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});

  ImeActionResult update_result = editor.updateImePreedit("ni", ImeScriptClass::CJK);

  REQUIRE(update_result.handled);
  CHECK(document->getU8Text().empty());
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(update_result.sync.has_composing_session);
  CHECK_FALSE(update_result.sync.has_visible_composition_range);
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);

  ImeActionResult commit_result = editor.commitImeText("\xE4\xBD\xA0", ImeScriptClass::CJK);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "\xE4\xBD\xA0");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK_FALSE(commit_result.sync.has_composing_session);
  CHECK(commit_result.sync.preedit_storage == ImePreeditStorage::NONE);
}

TEST_CASE("EditorCore IME event disabled composition keeps preedit shadow-only") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(false);
  editor.setCursorPosition({0, 0});

  ImeActionResult update_result = editor.updateImePreedit("how", ImeScriptClass::LATIN);

  CHECK(document->getU8Text().empty());
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(update_result.sync.has_composing_session);
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);
  CHECK(update_result.sync.context_policy == ImeContextPolicy::LIMITED_FOR_CANDIDATES);

  ImeActionResult commit_result = editor.commitImeText("how", ImeScriptClass::LATIN);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(commit_result.sync.has_composing_session);
}

TEST_CASE("EditorCore shadow preedit does not affect document undo or render decorations") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 5});
  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 5, "hint", 0, 0}});

  ImeActionResult update_result = editor.updateImePreedit("ni", ImeScriptClass::CJK);

  CHECK_FALSE(update_result.content_changed);
  CHECK(document->getU8Text() == "value");
  CHECK_FALSE(editor.canUndo());
  CHECK_FALSE(editor.isComposing());
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  CHECK_FALSE(model.composition_decoration.active);

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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});

  editor.updateImePreedit("h", ImeScriptClass::LATIN);
  editor.updateImePreedit("ho", ImeScriptClass::LATIN);
  editor.updateImePreedit("how", ImeScriptClass::LATIN);

  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.canUndo());

  ImeActionResult commit_result = editor.commitImeText("how", ImeScriptClass::LATIN);

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK(editor.canUndo());

  TextEditResult undo_result = editor.undo();
  REQUIRE(undo_result.changed);
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore IME replay suppresses exact candidate range after commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});
  ImeReplayRunner ime(editor);

  ime.updatePreedit("how");
  ImeActionResult commit_result = ime.commitText("how");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.isComposing());

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
  CHECK(mark_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(mark_result.sync.has_visible_composition_range);
  CHECK(document->getU8Text() == "how");
}

TEST_CASE("EditorCore IME replay reopens committed prefix after delete") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});
  ImeReplayRunner ime(editor);

  ime.updatePreedit("how");
  ime.commitText("how");
  REQUIRE(document->getU8Text() == "how");

  ImeActionResult delete_result = ime.deleteBackward();
  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "ho");
  CHECK_FALSE(editor.isComposing());

  ImeActionResult reopen_result = ime.updatePreedit("ho");
  CHECK(reopen_result.handled);
  REQUIRE(editor.isComposing());
  CHECK_FALSE(reopen_result.content_changed);
  CHECK(document->getU8Text() == "ho");
  CHECK(reopen_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 2}}));
}

TEST_CASE("EditorCore IME replay suppresses stale prefix commits after candidate delete") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});
  ImeReplayRunner ime(editor);

  ime.updatePreedit("how");
  ime.commitText("how");
  REQUIRE(document->getU8Text() == "how");

  ime.deleteSurrounding(1, 0);
  REQUIRE(document->getU8Text() == "ho");
  ImeActionResult stale_commit = ime.commitText("h");
  CHECK_FALSE(stale_commit.content_changed);
  CHECK(document->getU8Text() == "ho");
  ImeActionResult stale_update = ime.updatePreedit("h");
  CHECK_FALSE(stale_update.content_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ho");

  ime.deleteSurrounding(1, 0);
  REQUIRE(document->getU8Text() == "h");
  ImeActionResult reopen_result = ime.updatePreedit("h");
  CHECK_FALSE(reopen_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "h");
  ImeActionResult confirm_result = ime.commitText("h");
  CHECK_FALSE(confirm_result.content_changed);
  CHECK(document->getU8Text() == "h");

  ime.deleteSurrounding(1, 0);
  REQUIRE(document->getU8Text().empty());
  ImeActionResult final_stale_commit = ime.commitText("h");
  CHECK_FALSE(final_stale_commit.content_changed);
  CHECK(document->getU8Text().empty());
  ImeActionResult final_stale_update = ime.updatePreedit("h");
  CHECK_FALSE(final_stale_update.content_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore IME replay replaces suppressed exact candidate with shorter preedit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 0});
  ImeReplayRunner ime(editor);

  ime.updatePreedit("how");
  ime.finishPreedit();
  REQUIRE(document->getU8Text() == "how");
  REQUIRE_FALSE(editor.isComposing());

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
  CHECK(mark_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "how");

  ImeActionResult reduce_result = ime.updatePreedit("ho");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "ho");
  CHECK(reduce_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 2}}));
}

TEST_CASE("EditorCore IME replay delete events remove selection once") {
  auto run_delete_case = [](const std::function<ImeActionResult(EditorCore&)>& delete_action) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
    SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCompositionEnabled(true);
    ImeReplayRunner ime(editor);

    ime.selectionChanged({{0, 0}, {0, 5}});
    REQUIRE(editor.hasSelection());

    ImeActionResult result = delete_action(editor);

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
  editor.setCompositionEnabled(true);

  editor.setCursorPosition({0, 2});
  ImeActionResult middle_result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(middle_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(middle_result.sync.has_visible_composition_range);
  CHECK(middle_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(middle_result.sync.has_platform_marked_range);
  CHECK(middle_result.sync.platform_text_window_text == "hello");
  CHECK(middle_result.sync.platform_text_window_selection_start_offset == 2);
  CHECK(middle_result.sync.platform_text_window_selection_end_offset == 2);
  CHECK(middle_result.sync.platform_text_window_composing_start_offset == -1);
  CHECK(middle_result.sync.platform_text_window_composing_end_offset == -1);

  cancelPreedit(editor);
  editor.setCursorPosition({0, 5});
  ImeActionResult end_result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::LATIN);
  CHECK(end_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(end_result.sync.has_visible_composition_range);
  CHECK(end_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(end_result.sync.has_platform_marked_range);
  CHECK(end_result.sync.platform_text_window_text == "hello");
  CHECK(end_result.sync.platform_text_window_selection_start_offset == 5);
  CHECK(end_result.sync.platform_text_window_selection_end_offset == 5);
  CHECK(end_result.sync.platform_text_window_composing_start_offset == -1);
  CHECK(end_result.sync.platform_text_window_composing_end_offset == -1);
}

TEST_CASE("EditorCore IME unknown document range can start platform composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  ImeActionResult result = editor.markImeDocumentRange({{0, 0}, {0, 5}});

  CHECK(result.handled);
  REQUIRE(editor.isComposing());
  CHECK(editor.hasComposingSession());
  CHECK(result.sync.has_visible_composition_range);
  CHECK(result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(result.sync.has_platform_marked_range);

  ImeActionResult commit_result = editor.commitImeText("helloWorld", ImeScriptClass::LATIN);

  CHECK(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.isComposing());
}

TEST_CASE("EditorCore IME non-latin document range does not start editor composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  ImeActionResult result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::CJK);

  CHECK(result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK_FALSE(result.sync.has_visible_composition_range);
  CHECK_FALSE(result.sync.has_platform_marked_range);
  CHECK(document->getU8Text() == "hello");
}

TEST_CASE("EditorCore IME non-latin document range ends existing editor composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.markImeDocumentRange({{0, 0}, {0, 5}}, ImeScriptClass::CJK);

  CHECK(result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK_FALSE(result.sync.has_visible_composition_range);
  CHECK_FALSE(result.sync.has_platform_marked_range);
  CHECK(document->getU8Text() == "hello");
}

TEST_CASE("EditorCore IME non-latin commit inserts without replacing editor composition") {
  auto run_case = [](const TextPosition& cursor, const U8String& expected_text, const TextPosition& expected_cursor) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

    SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCompositionEnabled(true);
    editor.setCursorPosition(cursor);
    ImeReplayRunner ime(editor);

    ime.markDocumentRange({{0, 0}, {0, 5}});
    REQUIRE(editor.isComposing());

    ImeActionResult result = ime.commitText("你好", ImeScriptClass::CJK);

    REQUIRE(result.content_changed);
    CHECK(document->getU8Text() == expected_text);
    CHECK_FALSE(editor.isComposing());
    CHECK_FALSE(editor.hasComposingSession());
    CHECK(editor.getCursorPosition() == expected_cursor);
  };

  SECTION("word middle") {
    run_case({0, 2}, "va你好lue", {0, 4});
  }

  SECTION("word end") {
    run_case({0, 5}, "value你好", {0, 7});
  }
}

TEST_CASE("EditorCore IME document range candidate replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(mark_result.sync.has_visible_composition_range);

  ImeActionResult commit_result = ime.commitText("helloWorld");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 10}));
}

TEST_CASE("EditorCore IME document range single character commit inserts at middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("x");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME document range full-word edit commit inserts at middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("hexllo");
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
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 4});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 7}});
  REQUIRE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("defaults");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "defaults");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 8}));
}

TEST_CASE("EditorCore IME document range local preedit edit cancels middle composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("hexllo");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME document range suffix preedit replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 6}});
  REQUIRE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  ImeActionResult finish_result = ime.finishPreedit();
  CHECK(finish_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "Strings");
}

TEST_CASE("EditorCore IME document range prefix preedit inserts at middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("colors");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 6}});
  REQUIRE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("cox");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "coxlors");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
  CHECK(update_result.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(update_result.sync.platform_text_window_text.empty());
}

TEST_CASE("EditorCore IME platform prefix range updates only cursor prefix") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 2}},
                                                      ImeScriptClass::LATIN,
                                                      ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);
  REQUIRE(mark_result.sync.has_visible_composition_range);
  CHECK(mark_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 2}}));

  ImeActionResult first_update = ime.updatePreedit("vax");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "vaxlue");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 3}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  ImeActionResult second_update = ime.updatePreedit("vaxy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "vaxylue");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME platform full word range promotes to word target") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}},
                                                      ImeScriptClass::UNKNOWN,
                                                      ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);
  REQUIRE(mark_result.sync.has_visible_composition_range);
  CHECK(mark_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 6}}));

  ImeActionResult update_result = ime.updatePreedit("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME platform full word range does not promote in CJK mode") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::CJK);
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}},
                                                      ImeScriptClass::UNKNOWN,
                                                      ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);
  CHECK_FALSE(mark_result.sync.has_visible_composition_range);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "String");
}

TEST_CASE("EditorCore IME platform full word range keeps word-end full payload incremental") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}},
                        ImeScriptClass::UNKNOWN,
                        ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);
  REQUIRE(editor.isComposing());

  ImeActionResult first_update = ime.updatePreedit("valuex");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "valuex");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  ime.finishPreedit();
  CHECK_FALSE(editor.isComposing());
  ime.markDocumentRange({{0, 0}, {0, 6}},
                        ImeScriptClass::UNKNOWN,
                        ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);
  REQUIRE(editor.isComposing());

  ImeActionResult second_update = ime.updatePreedit("valuexy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "valuexy");
  CHECK(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME middle preedit suppresses matching commit after plain edit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 2});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult update_result = ime.updatePreedit("hexllo");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("hexllo");
  CHECK_FALSE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
}

TEST_CASE("EditorCore IME document range single character preedit inserts at middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME plain latin input lock suppresses marked ranges and context") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult first_update = ime.updatePreedit("x");
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK(first_update.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(first_update.sync.platform_text_window_text.empty());

  ImeActionResult remark_result = ime.markDocumentRange({{0, 0}, {0, 6}});
  CHECK_FALSE(remark_result.sync.has_visible_composition_range);
  CHECK(remark_result.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(remark_result.sync.platform_text_window_text.empty());
  CHECK_FALSE(editor.isComposing());

  ImeActionResult second_update = ime.updatePreedit("xy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "hexyllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(second_update.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(second_update.sync.platform_text_window_text.empty());
}

TEST_CASE("EditorCore IME plain latin input suppresses duplicate commit after middle preedit edit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");

  ImeActionResult commit_result = ime.commitText("x");
  CHECK_FALSE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME delete from middle document range keeps later latin input plain") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult delete_result = ime.deleteBackward();
  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "hllo");
  CHECK_FALSE(editor.isComposing());

  ime.markDocumentRange({{0, 0}, {0, 4}});
  CHECK_FALSE(editor.isComposing());

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hxllo");
  CHECK_FALSE(editor.hasComposingSession());
}

TEST_CASE("EditorCore IME plain latin lock keeps unrelated multi-character preedit shadow-only") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult first_update = ime.updatePreedit("x", ImeScriptClass::UNKNOWN);
  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());

  ImeActionResult pinyin_update = ime.updatePreedit("ni", ImeScriptClass::UNKNOWN);
  CHECK_FALSE(pinyin_update.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(pinyin_update.sync.has_composing_session);
  CHECK(pinyin_update.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);
  CHECK(pinyin_update.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(pinyin_update.sync.platform_text_window_text.empty());
}

TEST_CASE("EditorCore IME plain latin lock shadows multi-character preedit after delete") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(editor.isComposing());

  ImeActionResult delete_result = ime.deleteBackward();
  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "hllo");
  CHECK_FALSE(editor.isComposing());

  ImeActionResult pinyin_update = ime.updatePreedit("ni", ImeScriptClass::UNKNOWN);
  CHECK_FALSE(pinyin_update.content_changed);
  CHECK(document->getU8Text() == "hllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(pinyin_update.sync.has_composing_session);
  CHECK(pinyin_update.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);
  CHECK(pinyin_update.sync.context_policy == ImeContextPolicy::NONE);
  CHECK(pinyin_update.sync.platform_text_window_text.empty());
}

TEST_CASE("EditorCore IME explicit replace text inserts without composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(false);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ImeActionResult replace_result = ime.replaceText({{0, 0}, {0, 5}}, "result");
  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "result");
  CHECK_FALSE(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME explicit replace text replaces editor composition range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(mark_result.sync.has_visible_composition_range);
  CHECK_FALSE(mark_result.sync.has_platform_marked_range);

  ImeActionResult replace_result = ime.replaceText({{0, 2}, {0, 3}}, "helloWorld");
  REQUIRE(replace_result.content_changed);
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 10}));
}

TEST_CASE("EditorCore IME latin keyboard refresh opens word composition at cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("say hello now");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);

  editor.setCursorPosition({0, 6});

  REQUIRE(editor.isComposing());
  CHECK(editor.getImeKeyboardScriptClass() == ImeScriptClass::LATIN);
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 4}, {0, 9}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME non-latin keyboard refresh cancels word composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());

  ImeActionResult refresh_result = editor.refreshImeCompositionAtCursor(ImeScriptClass::CJK);

  CHECK(refresh_result.handled);
  CHECK(editor.getImeKeyboardScriptClass() == ImeScriptClass::CJK);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "hello");
}

TEST_CASE("EditorCore IME composition disabled prevents latin cursor word composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(false);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);

  editor.setCursorPosition({0, 5});
  ImeActionResult refresh_result = editor.refreshImeCompositionAtCursor();

  CHECK(refresh_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "hello");
}

TEST_CASE("EditorCore IME delete at latin word end keeps document range composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult delete_result = ime.deleteBackward();

  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "hell");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore backspace at latin word end keeps document range composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());

  TextEditResult delete_result = editor.backspace();

  REQUIRE(delete_result.changed);
  CHECK(document->getU8Text() == "hell");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore IME preedit at latin word end inserts and extends composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult first_update = ime.updatePreedit("x");

  REQUIRE(first_update.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(first_update.sync.has_visible_composition_range);
  CHECK(first_update.sync.visible_composition_range == (TextRange{{0, 0}, {0, 6}}));

  ImeActionResult second_update = ime.updatePreedit("helloxy");

  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "helloxy");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  ImeActionResult third_update = ime.updatePreedit("hellox");

  REQUIRE(third_update.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));

  ImeActionResult fourth_update = ime.updatePreedit("xy");

  REQUIRE(fourth_update.content_changed);
  CHECK(document->getU8Text() == "helloxy");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME word end preedit suppresses matching commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("x");
  CHECK_FALSE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore IME word end commit updates pending preedit suffix") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());

  ImeActionResult commit_result = ime.commitText("xy");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "helloxy");
  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 7}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore IME single character commit at latin word end inserts and keeps composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 5});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult commit_result = ime.commitText("x");

  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hellox");
  REQUIRE(editor.isComposing());
  CHECK(editor.hasComposingSession());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(commit_result.sync.has_visible_composition_range);
  CHECK(commit_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 6}}));
}

TEST_CASE("EditorCore IME cursor relocation clears plain latin lock and reopens latin word") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 2});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ImeActionResult update_result = ime.updatePreedit("x");
  REQUIRE(update_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK(update_result.sync.context_policy == ImeContextPolicy::NONE);

  editor.setCursorPosition({0, 6});

  REQUIRE(editor.isComposing());
  CHECK(editor.getCompositionState().anchor_range == (TextRange{{0, 0}, {0, 6}}));
  CHECK(editor.getImeSyncSnapshot().context_policy == ImeContextPolicy::LIMITED_FOR_CANDIDATES);
}

TEST_CASE("EditorCore IME non-latin mark clears plain latin lock without replacing word") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setImeKeyboardScriptClass(ImeScriptClass::LATIN);
  editor.setCursorPosition({0, 2});
  REQUIRE(editor.isComposing());
  ImeReplayRunner ime(editor);

  ime.updatePreedit("x");
  REQUIRE(document->getU8Text() == "hexllo");

  ImeActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}}, ImeScriptClass::CJK);
  ImeActionResult update_result = ime.updatePreedit("ni", ImeScriptClass::CJK);

  CHECK_FALSE(mark_result.sync.has_visible_composition_range);
  CHECK_FALSE(update_result.content_changed);
  CHECK(update_result.sync.context_policy == ImeContextPolicy::LIMITED_FOR_CANDIDATES);
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);
  CHECK(document->getU8Text() == "hexllo");
}
