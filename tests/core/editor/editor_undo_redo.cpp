#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("Sequential single-char insertions are merged into one undo step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.insertText("a");
  editor.insertText("b");
  editor.insertText("c");
  REQUIRE(document->getU8Text() == "abc");
  REQUIRE(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(undo_result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(undo_result.text_change_kind == TextChangeKind::UNDO);
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK(editor.canRedo());

  EditorActionResult redo_result = editor.redo();
  REQUIRE(redo_result.content_changed);
  CHECK(redo_result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(redo_result.text_change_kind == TextChangeKind::REDO);
  CHECK(document->getU8Text() == "abc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("Move line down is undoable as one atomic operation") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  EditorActionResult move_result = editor.moveLineDown();
  REQUIRE(move_result.content_changed);
  CHECK(move_result.source == EditorActionSource::PROGRAMMATIC);
  CHECK(move_result.text_change_kind == TextChangeKind::MOVE);
  CHECK(document->getU8Text() == "b\na\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 0}));

  EditorActionResult undo_result = editor.undo();
  REQUIRE(undo_result.content_changed);
  CHECK(document->getU8Text() == "a\nb\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  EditorActionResult redo_result = editor.redo();
  REQUIRE(redo_result.content_changed);
  CHECK(document->getU8Text() == "b\na\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 0}));
}

TEST_CASE("Move line down preserves directional selection through undo and redo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{1, 1}, {0, 0}});

  REQUIRE(editor.moveLineDown().content_changed);
  CHECK(document->getU8Text() == "c\na\nb");
  CHECK(editor.getSelection() == (TextRange{{2, 1}, {1, 0}}));

  REQUIRE(editor.undo().content_changed);
  CHECK(document->getU8Text() == "a\nb\nc");
  CHECK(editor.getSelection() == (TextRange{{1, 1}, {0, 0}}));

  REQUIRE(editor.redo().content_changed);
  CHECK(document->getU8Text() == "c\na\nb");
  CHECK(editor.getSelection() == (TextRange{{2, 1}, {1, 0}}));
}

TEST_CASE("Sequential forward deletions are merged into one undo step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  REQUIRE(editor.deleteForward().content_changed);
  REQUIRE(editor.deleteForward().content_changed);
  REQUIRE(editor.deleteForward().content_changed);
  CHECK(document->getU8Text().empty());

  REQUIRE(editor.undo().content_changed);
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.canUndo());

  REQUIRE(editor.redo().content_changed);
  CHECK(document->getU8Text().empty());
}

TEST_CASE("Sequential backspaces are merged into one undo step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  REQUIRE(editor.backspace().content_changed);
  REQUIRE(editor.backspace().content_changed);
  REQUIRE(editor.backspace().content_changed);
  CHECK(document->getU8Text().empty());

  REQUIRE(editor.undo().content_changed);
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.canUndo());

  REQUIRE(editor.redo().content_changed);
  CHECK(document->getU8Text().empty());
}

TEST_CASE("New edit clears redo stack after undo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  editor.insertText("d");
  REQUIRE(document->getU8Text() == "abcd");

  REQUIRE(editor.undo().content_changed);
  CHECK(document->getU8Text() == "abc");
  REQUIRE(editor.canRedo());

  editor.insertText("Z");
  CHECK(document->getU8Text() == "abcZ");
  CHECK_FALSE(editor.canRedo());
}

TEST_CASE("Undo and redo restore directional selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghij");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 8}, {0, 2}});

  REQUIRE(editor.insertText("X").content_changed);
  REQUIRE(editor.undo().content_changed);
  CHECK(editor.getSelection() == (TextRange{{0, 8}, {0, 2}}));
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));

  REQUIRE(editor.redo().content_changed);
  CHECK_FALSE(editor.hasSelection());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("Undo and redo restore caret affinity") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdefghij");
  editor.loadDocument(document);
  editor.setViewport({90, 320});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  EditorRenderModel model;
  editor.buildRenderModel(model);
  editor.setCursorPosition({0, 5});
  editor.moveCursorRight();
  REQUIRE(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);

  REQUIRE(editor.insertText("X").content_changed);
  REQUIRE(editor.undo().content_changed);
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);

  REQUIRE(editor.redo().content_changed);
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::DOWNSTREAM);
}
