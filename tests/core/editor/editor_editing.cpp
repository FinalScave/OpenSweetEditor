#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore refreshes cached visual line numbers after line shifts") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  const auto content_line_numbers = [](const EditorRenderModel& model) {
    Vector<int32_t> numbers;
    for (const VisualLine& line : model.lines) {
      if (line.kind == VisualLineKind::CONTENT && line.wrap_index == 0) {
        numbers.push_back(line.line_number);
      }
    }
    return numbers;
  };

  EditorRenderModel initial_model;
  editor.buildRenderModel(initial_model);
  CHECK(content_line_numbers(initial_model) == Vector<int32_t>{1, 2, 3});

  editor.setCursorPosition({0, 0});
  REQUIRE(editor.insertText("x\n").handled);
  EditorRenderModel inserted_model;
  editor.buildRenderModel(inserted_model);
  CHECK(content_line_numbers(inserted_model) == Vector<int32_t>{1, 2, 3, 4});

  REQUIRE(editor.deleteText({{0, 0}, {1, 0}}).handled);
  EditorRenderModel deleted_model;
  editor.buildRenderModel(deleted_model);
  CHECK(content_line_numbers(deleted_model) == Vector<int32_t>{1, 2, 3});
}

TEST_CASE("EditorCore normalizes selection before insert replacement") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 11}, {0, 6}});
  EditorActionResult result = editor.insertText("X");

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(result.text_change_kind == TextChangeKind::REPLACEMENT);
  CHECK(document->getU8Text() == "hello X");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
  CHECK_FALSE(editor.hasSelection());
  REQUIRE(result.text_changes.size() == 1);
  CHECK(result.text_changes[0].old_text == "world");
  CHECK(result.text_changes[0].new_text == "X");
}

TEST_CASE("EditorCore insertText with empty string deletes selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 6}, {0, 11}});
  EditorActionResult result = editor.insertText("");

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(result.text_change_kind == TextChangeKind::DELETION);
  CHECK(document->getU8Text() == "hello ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK_FALSE(editor.hasSelection());
  REQUIRE(result.text_changes.size() == 1);
  CHECK(result.text_changes[0].old_text == "world");
  CHECK(result.text_changes[0].new_text == "");
}

TEST_CASE("EditorCore insertText with empty string and no selection is no-op") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 3});
  EditorActionResult result = editor.insertText("");

  CHECK(result.text_changes.empty());
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore applyTextEdits applies one atomic batch and keeps primary cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("fun call()");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 4}, {0, 8}}, "run"});
  edits.push_back({{{0, 0}, {0, 0}}, "import demo\n"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(result.text_change_kind == TextChangeKind::MIXED);
  CHECK(document->getU8Text() == "import demo\nfun run()");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 7}));
  REQUIRE(result.text_changes.size() == 2);
  CHECK(result.text_changes[0].range == (TextRange{{0, 4}, {0, 8}}));
  CHECK(result.text_changes[1].range == (TextRange{{0, 0}, {0, 0}}));

  EditorActionResult undo_result = editor.undo();
  REQUIRE_FALSE(undo_result.text_changes.empty());
  CHECK(undo_result.text_change_kind == TextChangeKind::UNDO);
  CHECK(document->getU8Text() == "fun call()");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  EditorActionResult redo_result = editor.redo();
  REQUIRE_FALSE(redo_result.text_changes.empty());
  CHECK(redo_result.text_change_kind == TextChangeKind::REDO);
  CHECK(document->getU8Text() == "import demo\nfun run()");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 7}));
}

TEST_CASE("EditorCore applyTextEdits allows insertion at replacement end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("call()");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 0}, {0, 4}}, "run"});
  edits.push_back({{{0, 4}, {0, 4}}, "Async"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "runAsync()");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "call()");

  REQUIRE_FALSE(editor.redo().text_changes.empty());
  CHECK(document->getU8Text() == "runAsync()");
}

TEST_CASE("EditorCore applyTextEdits allows insertion at replacement start") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("call()");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 0}, {0, 4}}, "run"});
  edits.push_back({{{0, 0}, {0, 0}}, "Async"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE(result.text_changes.size() == 2);
  CHECK(result.text_changes[0].range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(result.text_changes[1].range == (TextRange{{0, 0}, {0, 0}}));
  CHECK(document->getU8Text() == "Asyncrun()");

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "call()");
  REQUIRE_FALSE(editor.redo().text_changes.empty());
  CHECK(document->getU8Text() == "Asyncrun()");
}

TEST_CASE("EditorCore applyTextEdits preserves inverse coordinates across line changes") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("aa\nbb\ncc\ndd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 0}, {0, 2}}, "A\nX"});
  edits.push_back({{{2, 0}, {3, 0}}, ""});

  REQUIRE_FALSE(editor.applyTextEdits(std::move(edits)).text_changes.empty());
  CHECK(document->getU8Text() == "A\nX\nbb\ndd");

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "aa\nbb\ncc\ndd");

  REQUIRE_FALSE(editor.redo().text_changes.empty());
  CHECK(document->getU8Text() == "A\nX\nbb\ndd");
}

TEST_CASE("EditorCore applyTextEdits creates a history merge barrier") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 0}, {0, 0}}, "a"});
  REQUIRE_FALSE(editor.applyTextEdits(std::move(edits)).text_changes.empty());
  REQUIRE_FALSE(editor.insertText("b").text_changes.empty());
  CHECK(document->getU8Text() == "ab");

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "a");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore applyTextEdits ignores collapsed empty edits for content and undo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 2}, {0, 2}}, ""});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  CHECK_FALSE(result.handled);
  CHECK(result.text_changes.empty());
  CHECK_FALSE(result.cursor_changed);
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore applyTextEdits moves cursor for collapsed empty primary edit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 4}, {0, 4}}, ""});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE(result.handled);
  CHECK(result.text_changes.empty());
  CHECK(result.cursor_changed);
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore applyTextEdits transforms collapsed empty primary cursor through additional edits") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("fun call()");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 4}, {0, 4}}, ""});
  edits.push_back({{{0, 0}, {0, 0}}, "import demo\n"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "import demo\nfun call()");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 4}));
  REQUIRE(result.text_changes.size() == 1);
  CHECK(editor.canUndo());
}

TEST_CASE("EditorCore applyTextEdits ignores no-op edits during overlap validation") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 2}, {0, 2}}, ""});
  edits.push_back({{{0, 1}, {0, 3}}, "XX"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "aXXdef");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore applyTextEdits rejects overlapping real edits") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TextEdit> edits;
  edits.push_back({{{0, 1}, {0, 1}}, ""});
  edits.push_back({{{0, 1}, {0, 3}}, "XX"});
  edits.push_back({{{0, 2}, {0, 4}}, "YY"});

  EditorActionResult result = editor.applyTextEdits(std::move(edits));

  CHECK_FALSE(result.handled);
  CHECK(result.text_changes.empty());
  CHECK(document->getU8Text() == "abcdef");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore keeps collapsed fold when editing a projected tail") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("if {\n  body\n}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<FoldRegion> folds;
  folds.push_back({0, 2, true});
  editor.setFoldRegions(std::move(folds));

  editor.setCursorPosition({2, 1});
  CHECK(editor.getCursorPosition() == (TextPosition{2, 1}));

  EditorActionResult result = editor.insertText(";");
  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "if {\n  body\n};");
  CHECK_FALSE(editor.isLineVisible(2));
  CHECK(editor.getCursorPosition() == (TextPosition{2, 2}));
}

TEST_CASE("EditorCore unfolds folded region for multiline projected tail edits") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("if {\n  body\n}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<FoldRegion> folds;
  folds.push_back({0, 2, true});
  editor.setFoldRegions(std::move(folds));

  editor.setCursorPosition({2, 1});
  EditorActionResult result = editor.insertText("\n");

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(editor.isLineVisible(1));
  CHECK(editor.isLineVisible(2));
}

TEST_CASE("EditorCore Enter keeps current line indent by default") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("  foo");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  KeyEvent event;
  event.key_code = KeyCode::ENTER;
  EditorActionResult key_result = editor.handleKeyEvent(event);

  REQUIRE(key_result.handled);
  REQUIRE_FALSE(key_result.text_changes.empty());
  CHECK(key_result.source == EditorActionSource::KEYBOARD);
  CHECK(key_result.text_change_kind == TextChangeKind::INSERTION);
  CHECK(document->getU8Text() == "  foo\n  ");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 2}));
}

TEST_CASE("EditorCore Tab inserts spaces to the next tab stop when insertSpaces is enabled") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("  foo");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setTabSize(4);
  editor.setInsertSpaces(true);
  editor.setCursorPosition({0, 2});

  KeyEvent event;
  event.key_code = KeyCode::TAB;
  EditorActionResult key_result = editor.handleKeyEvent(event);

  REQUIRE(key_result.handled);
  REQUIRE_FALSE(key_result.text_changes.empty());
  CHECK(document->getU8Text() == "    foo");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore backspace removes one surrogate pair as a single glyph") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3}); // after 'A' (1) and emoji (2)

  EditorActionResult result = editor.backspace();

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(result.text_change_kind == TextChangeKind::DELETION);
  CHECK(document->getU8Text() == "AB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore clamps cursor positions away from surrogate middles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));

  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore traverses both visual sides of a soft wrap boundary") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdefghij"));
  editor.setViewport({90, 320});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  EditorRenderModel model;
  editor.buildRenderModel(model);
  editor.setCursorPosition({0, 5});

  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);

  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::DOWNSTREAM);

  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::DOWNSTREAM);

  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);

  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
}

TEST_CASE("EditorCore vertical movement keeps preferred x across wrapped lines") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  editor.loadDocument(makeShared<LineArrayDocument>("abcdefghijklmnopqr"));
  editor.setViewport({90, 320});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  EditorRenderModel model;
  editor.buildRenderModel(model);
  editor.setCursorPosition({0, 5});

  editor.moveCursorDown();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 11}));
  editor.moveCursorDown();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 17}));
  editor.moveCursorUp();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 11}));
  editor.moveCursorUp();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
}

TEST_CASE("EditorCore keeps zero-length selection collapsed when clamped around a surrogate pair") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 2}, {0, 2}});

  CHECK(editor.getSelection() == (TextRange{{0, 1}, {0, 1}}));
  CHECK_FALSE(editor.hasSelection());
}

TEST_CASE("EditorCore deleteForward removes one surrogate pair as a single glyph") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  EditorActionResult result = editor.deleteForward();

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "AB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore treats emoji modifier grapheme clusters as one editing unit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2}); // between base emoji and skin-tone modifier
  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  editor.setCursorPosition({0, 2});
  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  editor.setCursorPosition({0, 4});
  EditorActionResult backspace_result = editor.backspace();
  REQUIRE_FALSE(backspace_result.text_changes.empty());
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});
  EditorActionResult delete_result = editor.deleteForward();
  REQUIRE_FALSE(delete_result.text_changes.empty());
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore clamps direct cursor and range APIs to grapheme boundaries") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  editor.setSelection({{0, 2}, {0, 2}});
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 0}}));
  CHECK_FALSE(editor.hasSelection());

  EditorActionResult replace_result = editor.replaceText({{0, 2}, {0, 2}}, "X");
  REQUIRE_FALSE(replace_result.text_changes.empty());
  CHECK(replace_result.text_change_kind == TextChangeKind::INSERTION);
  CHECK(document->getU8Text() == "X\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));

  document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  EditorActionResult delete_result = editor.deleteText({{0, 2}, {0, 4}});
  REQUIRE_FALSE(delete_result.text_changes.empty());
  CHECK(delete_result.text_change_kind == TextChangeKind::DELETION);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore treats ZWJ emoji families as one editing unit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(
      "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 0});
  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 11}));

  EditorActionResult backspace_result = editor.backspace();
  REQUIRE_FALSE(backspace_result.text_changes.empty());
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore expands ZWJ family ranges to full grapheme boundaries") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>(
      "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 2}, {0, 2}});
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 0}}));
  CHECK_FALSE(editor.hasSelection());

  EditorActionResult delete_result = editor.deleteText({{0, 2}, {0, 4}});
  REQUIRE_FALSE(delete_result.text_changes.empty());
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore getWordRangeAtCursor keeps combining graphemes intact") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\xCC\x81"
                                                               "bc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});

  CHECK(editor.getWordRangeAtCursor() == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getWordAtCursor()
        == "a\xCC\x81"
           "bc");
}

TEST_CASE("EditorCore replaceText normalizes insert positions away from surrogate middles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  EditorActionResult result = editor.replaceText({{0, 2}, {0, 2}}, "X");

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text()
        == "AX\xF0\x9F\x98\x80"
           "B");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore deleteText expands surrogate-spanning ranges to full code-point boundaries") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80"
                                                               "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  EditorActionResult result = editor.deleteText({{0, 2}, {0, 3}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "AB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore rebuilds text run styles after style re-registration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  constexpr uint32_t style_id = 1;
  constexpr int32_t original_color = static_cast<int32_t>(0xFF112233u);
  constexpr int32_t updated_color = static_cast<int32_t>(0xFF445566u);

  editor.registerTextStyle(style_id, TextStyle{original_color, 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, Vector<StyleSpan>{{0, 5, style_id}});

  EditorRenderModel initial_model;
  editor.buildRenderModel(initial_model);

  REQUIRE(initial_model.lines.size() == 1);
  REQUIRE(initial_model.lines[0].runs.size() == 1);
  CHECK(initial_model.lines[0].runs[0].style.color == original_color);

  editor.registerTextStyle(style_id, TextStyle{updated_color, 0, FONT_STYLE_NORMAL});

  EditorRenderModel updated_model;
  editor.buildRenderModel(updated_model);

  REQUIRE(updated_model.lines.size() == 1);
  REQUIRE(updated_model.lines[0].runs.size() == 1);
  CHECK(updated_model.lines[0].runs[0].style.color == updated_color);
}

TEST_CASE("EditorCore rebuilds text run styles after batch style re-registration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  constexpr uint32_t style_id = 1;
  constexpr int32_t original_color = static_cast<int32_t>(0xFF112233u);
  constexpr int32_t updated_color = static_cast<int32_t>(0xFF445566u);

  editor.registerTextStyle(style_id, TextStyle{original_color, 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, Vector<StyleSpan>{{0, 5, style_id}});

  EditorRenderModel initial_model;
  editor.buildRenderModel(initial_model);

  REQUIRE(initial_model.lines.size() == 1);
  REQUIRE(initial_model.lines[0].runs.size() == 1);
  CHECK(initial_model.lines[0].runs[0].style.color == original_color);

  Vector<std::pair<uint32_t, TextStyle>> styles;
  styles.emplace_back(style_id, TextStyle{updated_color, 0, FONT_STYLE_NORMAL});
  editor.registerBatchTextStyles(std::move(styles));

  EditorRenderModel updated_model;
  editor.buildRenderModel(updated_model);

  REQUIRE(updated_model.lines.size() == 1);
  REQUIRE(updated_model.lines[0].runs.size() == 1);
  CHECK(updated_model.lines[0].runs[0].style.color == updated_color);
}

TEST_CASE("EditorCore adjusts only the active document decorations for edits") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> line_array_document = makeShared<LineArrayDocument>("abc");
  SharedPtr<Document> piece_table_document = makeShared<PieceTableDocument>("xyz");

  line_array_document->getDecorations().setLineDiagnostics(0, {{1, 1, DiagnosticSeverity::DIAG_WARNING}});
  piece_table_document->getDecorations().setLineDiagnostics(0, {{1, 1, DiagnosticSeverity::DIAG_ERROR}});

  editor.loadDocument(line_array_document);
  editor.setCursorPosition({0, 0});
  editor.insertText("Q");

  REQUIRE(line_array_document->getDecorations().getLineDiagnostics(0).size() == 1);
  REQUIRE(piece_table_document->getDecorations().getLineDiagnostics(0).size() == 1);
  CHECK(line_array_document->getDecorations().getLineDiagnostics(0)[0].column == 2);
  CHECK(piece_table_document->getDecorations().getLineDiagnostics(0)[0].column == 1);

  editor.loadDocument(piece_table_document);
  editor.setCursorPosition({0, 0});
  editor.insertText("R");

  REQUIRE(piece_table_document->getDecorations().getLineDiagnostics(0).size() == 1);
  CHECK(piece_table_document->getDecorations().getLineDiagnostics(0)[0].column == 2);
  CHECK(line_array_document->getDecorations().getLineDiagnostics(0)[0].column == 2);
}
