#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {

  class ImeReplayRunner {
  public:
    explicit ImeReplayRunner(EditorCore& editor) : m_editor(editor) {}

    ImeEventResult updatePreedit(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      ImeEvent event;
      event.type = ImeEventType::UPDATE_PREEDIT;
      event.text = text;
      event.script_hint = script_class;
      return send(event);
    }

    ImeEventResult commitText(const U8String& text, ImeScriptClass script_class = ImeScriptClass::LATIN) {
      ImeEvent event;
      event.type = ImeEventType::COMMIT_TEXT;
      event.text = text;
      event.script_hint = script_class;
      return send(event);
    }

    ImeEventResult finishPreedit() {
      ImeEvent event;
      event.type = ImeEventType::FINISH_PREEDIT;
      return send(event);
    }

    ImeEventResult markDocumentRange(const TextRange& range) {
      ImeEvent event;
      event.type = ImeEventType::MARK_DOCUMENT_RANGE;
      event.has_range = true;
      event.range = range;
      return send(event);
    }

    ImeEventResult deleteBackward(size_t count = 1) {
      ImeEvent event;
      event.type = ImeEventType::DELETE_BACKWARD;
      event.before_length = count;
      return send(event);
    }

    ImeEventResult deleteForward(size_t count = 1) {
      ImeEvent event;
      event.type = ImeEventType::DELETE_FORWARD;
      event.after_length = count;
      return send(event);
    }

    ImeEventResult deleteSurrounding(size_t before_length, size_t after_length) {
      ImeEvent event;
      event.type = ImeEventType::DELETE_SURROUNDING;
      event.before_length = before_length;
      event.after_length = after_length;
      return send(event);
    }

    ImeEventResult selectionChanged(const TextRange& range) {
      ImeEvent event;
      event.type = ImeEventType::SELECTION_CHANGED;
      event.has_range = true;
      event.range = range;
      return send(event);
    }

  private:
    ImeEventResult send(const ImeEvent& event) {
      return m_editor.handleImeEvent(event);
    }

    EditorCore& m_editor;
  };

}

TEST_CASE("EditorCore composition update is transient and cancel restores original text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 4});

  editor.setComposingText("x");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abx");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  editor.setComposingText("xy");
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  editor.cancelComposing();
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

  editor.setComposingText("xy");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abxy");

  TextEditResult result = editor.commitComposingText("");
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

  editor.setComposingText("q");
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ab");

  TextEditResult result = editor.commitComposingText("z");
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

  editor.setComposingText("how");
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

  editor.setComposingText("x");
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

  editor.setComposingRange({{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));

  editor.setComposingRange({{0, 0}, {0, 4}});
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

  editor.setComposingRange({{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());

  TextEditResult result = editor.commitComposingText("");
  CHECK_FALSE(result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition {0, 4}));
  CHECK(result.changes.empty());
  CHECK(result.cursor_before == (TextPosition {0, 4}));
  CHECK(result.cursor_after == (TextPosition {0, 4}));
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

  editor.setComposingRange({{0, 0}, {0, 4}});
  editor.setComposingText("how");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "how tail");

  editor.cancelComposing();
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word tail");
  CHECK_FALSE(editor.canUndo());

  editor.setCursorPosition({0, 4});
  editor.setComposingRange({{0, 0}, {0, 4}});
  editor.setComposingText("how");
  TextEditResult result = editor.commitComposingText("");
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

  editor.setComposingRange({{0, 13}, {0, 19}});
  TextEditResult first_finish = editor.commitComposingText("");
  CHECK_FALSE(first_finish.changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  editor.setComposingRange({{0, 13}, {0, 19}});
  TextEditResult second_finish = editor.commitComposingText("");
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
  editor.setComposingRange(point_range);
  editor.setComposingRange(point_range);
  editor.setComposingRange(point_range);

  TextEditResult result = editor.commitComposingText("Points");
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
  editor.setComposingRange(point_range);
  REQUIRE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  TextEditResult finish_result = editor.finishComposing();
  CHECK_FALSE(finish_result.changed);
  CHECK_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  editor.setCursorPosition({0, 0});
  TextEditResult commit_result = editor.commitComposingText("Points");
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
  editor.setComposingRange(point_range);
  editor.finishComposing();
  REQUIRE_FALSE(editor.isComposing());
  REQUIRE(editor.hasComposingSession());

  TextEditResult set_result = editor.setComposingText("Points");
  REQUIRE(set_result.changed);
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");

  TextEditResult duplicate_result = editor.commitComposingText("Points");
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
  editor.setComposingRange(point_range);
  editor.finishComposing();
  editor.replaceText(point_range, "Value");

  TextEditResult stale_result = editor.commitComposingText("Points");
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

  ImeEvent event;
  event.type = ImeEventType::UPDATE_PREEDIT;
  event.text = "how";
  ImeEventResult result = editor.handleImeEvent(event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.text = "how";
  editor.handleImeEvent(update_event);
  REQUIRE(editor.isComposing());

  ImeEvent commit_event;
  commit_event.type = ImeEventType::COMMIT_TEXT;
  commit_event.text = "how";
  ImeEventResult result = editor.handleImeEvent(commit_event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.text = "how";
  editor.handleImeEvent(update_event);

  ImeEvent delete_event;
  delete_event.type = ImeEventType::DELETE_BACKWARD;
  delete_event.before_length = 1;
  editor.handleImeEvent(delete_event);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abho");

  editor.handleImeEvent(delete_event);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abh");

  editor.handleImeEvent(delete_event);
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

  ImeEvent mark_event;
  mark_event.type = ImeEventType::MARK_DOCUMENT_RANGE;
  mark_event.has_range = true;
  mark_event.range = {{0, 7}, {0, 12}};
  editor.handleImeEvent(mark_event);
  REQUIRE(editor.isComposing());

  ImeEvent finish_event;
  finish_event.type = ImeEventType::FINISH_PREEDIT;
  ImeEventResult result = editor.handleImeEvent(finish_event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.text = "ni";
  update_event.script_hint = ImeScriptClass::CJK;
  ImeEventResult update_result = editor.handleImeEvent(update_event);

  REQUIRE(update_result.handled);
  CHECK(document->getU8Text().empty());
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(update_result.sync.has_composing_session);
  CHECK_FALSE(update_result.sync.has_visible_composition_range);
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);

  ImeEvent commit_event;
  commit_event.type = ImeEventType::COMMIT_TEXT;
  commit_event.text = "\xE4\xBD\xA0";
  commit_event.script_hint = ImeScriptClass::CJK;
  ImeEventResult commit_result = editor.handleImeEvent(commit_event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.text = "how";
  update_event.script_hint = ImeScriptClass::LATIN;
  ImeEventResult update_result = editor.handleImeEvent(update_event);

  CHECK(document->getU8Text().empty());
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(editor.hasComposingSession());
  CHECK(update_result.sync.has_composing_session);
  CHECK(update_result.sync.preedit_storage == ImePreeditStorage::SHADOW_ONLY);
  CHECK(update_result.sync.context_policy == ImeContextPolicy::LIMITED_FOR_CANDIDATES);

  ImeEvent commit_event;
  commit_event.type = ImeEventType::COMMIT_TEXT;
  commit_event.text = "how";
  commit_event.script_hint = ImeScriptClass::LATIN;
  ImeEventResult commit_result = editor.handleImeEvent(commit_event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.text = "ni";
  update_event.script_hint = ImeScriptClass::CJK;
  ImeEventResult update_result = editor.handleImeEvent(update_event);

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

  ImeEvent update_event;
  update_event.type = ImeEventType::UPDATE_PREEDIT;
  update_event.script_hint = ImeScriptClass::LATIN;

  update_event.text = "h";
  editor.handleImeEvent(update_event);
  update_event.text = "ho";
  editor.handleImeEvent(update_event);
  update_event.text = "how";
  editor.handleImeEvent(update_event);

  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.canUndo());

  ImeEvent commit_event;
  commit_event.type = ImeEventType::COMMIT_TEXT;
  commit_event.text = "how";
  commit_event.script_hint = ImeScriptClass::LATIN;
  ImeEventResult commit_result = editor.handleImeEvent(commit_event);

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
  ImeEventResult commit_result = ime.commitText("how");
  REQUIRE(commit_result.content_changed);
  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.isComposing());

  ImeEventResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
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

  ImeEventResult delete_result = ime.deleteBackward();
  REQUIRE(delete_result.content_changed);
  CHECK(document->getU8Text() == "ho");
  CHECK_FALSE(editor.isComposing());

  ImeEventResult reopen_result = ime.updatePreedit("ho");
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
  ImeEventResult stale_commit = ime.commitText("h");
  CHECK_FALSE(stale_commit.content_changed);
  CHECK(document->getU8Text() == "ho");

  ime.deleteSurrounding(1, 0);
  REQUIRE(document->getU8Text() == "h");
  ImeEventResult reopen_result = ime.updatePreedit("h");
  CHECK_FALSE(reopen_result.content_changed);
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "h");
  ImeEventResult confirm_result = ime.commitText("h");
  CHECK_FALSE(confirm_result.content_changed);
  CHECK(document->getU8Text() == "h");

  ime.deleteSurrounding(1, 0);
  REQUIRE(document->getU8Text().empty());
  ImeEventResult final_stale_commit = ime.commitText("h");
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

  ImeEventResult mark_result = ime.markDocumentRange({{0, 0}, {0, 3}});
  CHECK(mark_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "how");

  ImeEventResult reduce_result = ime.updatePreedit("ho");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "ho");
  CHECK(reduce_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 2}}));
}

TEST_CASE("EditorCore IME replay delete events remove selection once") {
  auto run_delete_case = [](ImeEventType type) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
    SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCompositionEnabled(true);
    ImeReplayRunner ime(editor);

    ime.selectionChanged({{0, 0}, {0, 5}});
    REQUIRE(editor.hasSelection());

    ImeEvent event;
    event.type = type;
    event.before_length = 1;
    event.after_length = 1;
    ImeEventResult result = editor.handleImeEvent(event);

    REQUIRE(result.content_changed);
    CHECK(document->getU8Text() == " world");
    CHECK_FALSE(editor.hasSelection());
    CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  };

  SECTION("delete backward") {
    run_delete_case(ImeEventType::DELETE_BACKWARD);
  }
  SECTION("delete forward") {
    run_delete_case(ImeEventType::DELETE_FORWARD);
  }
  SECTION("delete surrounding") {
    run_delete_case(ImeEventType::DELETE_SURROUNDING);
  }
}

TEST_CASE("EditorCore IME document range requires word-end cursor by default") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);

  ImeEvent mark_event;
  mark_event.type = ImeEventType::MARK_DOCUMENT_RANGE;
  mark_event.has_range = true;
  mark_event.range = {{0, 0}, {0, 5}};

  editor.setCursorPosition({0, 4});
  ImeEventResult middle_result = editor.handleImeEvent(mark_event);
  CHECK(middle_result.handled);
  CHECK_FALSE(editor.isComposing());
  CHECK_FALSE(middle_result.sync.has_visible_composition_range);

  editor.setCursorPosition({0, 5});
  ImeEventResult end_result = editor.handleImeEvent(mark_event);
  CHECK(end_result.handled);
  REQUIRE(editor.isComposing());
  CHECK(end_result.sync.has_visible_composition_range);
  CHECK(end_result.sync.visible_composition_range == (TextRange{{0, 0}, {0, 5}}));
}
