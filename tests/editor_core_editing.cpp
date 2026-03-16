#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore normalizes selection before insert replacement") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 11}, {0, 6}});
  TextEditResult result = editor.insertText("X");

  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "hello X");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
  CHECK_FALSE(editor.hasSelection());
  REQUIRE(result.changes.size() == 1);
  CHECK(result.changes[0].old_text == "world");
  CHECK(result.changes[0].new_text == "X");
}

TEST_CASE("EditorCore Enter keeps current line indent by default") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("  foo");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  KeyEvent event;
  event.key_code = KeyCode::ENTER;
  KeyEventResult key_result = editor.handleKeyEvent(event);

  REQUIRE(key_result.handled);
  REQUIRE(key_result.content_changed);
  CHECK(document->getU8Text() == "  foo\n  ");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 2}));
}

TEST_CASE("EditorCore backspace removes one surrogate pair as a single glyph") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3}); // after 'A' (1) and emoji (2)

  TextEditResult result = editor.backspace();

  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "AB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}
