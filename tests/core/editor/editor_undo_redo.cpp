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
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK(editor.canRedo());

  EditorActionResult redo_result = editor.redo();
  REQUIRE(redo_result.content_changed);
  CHECK(document->getU8Text() == "abc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("Move line down is undoable as one grouped operation") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  EditorActionResult move_result = editor.moveLineDown();
  REQUIRE(move_result.content_changed);
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
