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

  TextEditResult result = commitText(editor, "");
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
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
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

  ImeActionResult result = editor.commitImeText("", ImeScriptClass::LATIN);
  CHECK_FALSE(result.edit_result.changed);
  CHECK_FALSE(result.cursor_changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));
  CHECK(result.edit_result.changes.empty());
  CHECK_FALSE(editor.canUndo());
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
  TextEditResult result = commitText(editor, "");
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
  TextEditResult first_finish = commitText(editor, "");
  CHECK_FALSE(first_finish.changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  TextEditResult second_finish = commitText(editor, "");
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

TEST_CASE("EditorCore finish hides document composition but keeps anchored commit session") {
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
  TextEditResult commit_result = commitText(editor, "Points");
  REQUIRE(commit_result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
  CHECK(commit_result.changes[0].range == point_range);
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

  editor.markImeDocumentRange({{0, 7}, {0, 12}});
  REQUIRE(editor.isComposing());

  ImeActionResult result = editor.finishImePreedit();

  CHECK_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());
  CHECK(result.sync.has_composing_session);
  CHECK_FALSE(result.sync.has_visible_composition_range);
  CHECK(result.sync.has_platform_marked_range);
  CHECK(result.sync.platform_marked_range == (TextRange{{0, 7}, {0, 12}}));
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

TEST_CASE("EditorCore IME document range accepts cursor inside word by default") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);

  editor.setCursorPosition({0, 2});
  ImeActionResult middle_result = editor.markImeDocumentRange({{0, 0}, {0, 5}});
  CHECK(middle_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(middle_result.sync.has_visible_composition_range);
  CHECK(middle_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK_FALSE(middle_result.sync.has_platform_marked_range);

  cancelPreedit(editor);
  editor.setCursorPosition({0, 5});
  ImeActionResult end_result = editor.markImeDocumentRange({{0, 0}, {0, 5}});
  CHECK(end_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(end_result.sync.has_visible_composition_range);
  CHECK(end_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
  CHECK(end_result.sync.has_platform_marked_range);
  CHECK(end_result.sync.platform_marked_range == (TextRange{{0, 0}, {0, 5}}));
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

TEST_CASE("EditorCore IME document range appended edit commit inserts at middle cursor") {
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

  ImeActionResult commit_result = ime.commitText("hellox");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "hexllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
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

TEST_CASE("EditorCore IME plain latin input stays unlocked after middle preedit edit") {
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

  ImeActionResult remark_result = ime.markDocumentRange({{0, 0}, {0, 6}});
  CHECK_FALSE(remark_result.sync.has_visible_composition_range);
  CHECK_FALSE(editor.isComposing());

  ImeActionResult second_update = ime.updatePreedit("xy");
  REQUIRE(second_update.content_changed);
  CHECK(document->getU8Text() == "hexyllo");
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
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
  CHECK(document->getU8Text() == "varesultlue");
  CHECK_FALSE(editor.isComposing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 8}));
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
