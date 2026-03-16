#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("Sequential single-char insertions are merged into one undo step") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.insertText("a");
  editor.insertText("b");
  editor.insertText("c");
  REQUIRE(document->getU8Text() == "abc");
  REQUIRE(editor.canUndo());

  TextEditResult undo_result = editor.undo();
  REQUIRE(undo_result.changed);
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK(editor.canRedo());

  TextEditResult redo_result = editor.redo();
  REQUIRE(redo_result.changed);
  CHECK(document->getU8Text() == "abc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("Move line down is undoable as one grouped operation") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  TextEditResult move_result = editor.moveLineDown();
  REQUIRE(move_result.changed);
  CHECK(document->getU8Text() == "b\na\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 0}));

  TextEditResult undo_result = editor.undo();
  REQUIRE(undo_result.changed);
  CHECK(document->getU8Text() == "a\nb\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  TextEditResult redo_result = editor.redo();
  REQUIRE(redo_result.changed);
  CHECK(document->getU8Text() == "b\na\nc");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 0}));
}

TEST_CASE("New edit clears redo stack after undo") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  editor.insertText("d");
  REQUIRE(document->getU8Text() == "abcd");

  REQUIRE(editor.undo().changed);
  CHECK(document->getU8Text() == "abc");
  REQUIRE(editor.canRedo());

  editor.insertText("Z");
  CHECK(document->getU8Text() == "abcZ");
  CHECK_FALSE(editor.canRedo());
}
