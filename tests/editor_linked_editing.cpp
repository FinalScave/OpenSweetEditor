#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore snippet linked editing mirrors placeholders and exits at tail") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  TextEditResult insert_result = editor.insertSnippet("${1:foo} + ${1:foo} -> $0");
  REQUIRE(insert_result.changed);
  REQUIRE(editor.isInLinkedEditing());
  CHECK(document->getU8Text() == "foo + foo -> ");
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 3}}));

  TextEditResult linked_edit = editor.insertText("bar");
  REQUIRE(linked_edit.changed);
  CHECK(document->getU8Text() == "bar + bar -> ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
  CHECK_FALSE(editor.hasSelection());

  REQUIRE(editor.linkedEditingNextTabStop());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
  CHECK(editor.isInLinkedEditing());

  CHECK_FALSE(editor.linkedEditingNextTabStop());
  CHECK_FALSE(editor.isInLinkedEditing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}

TEST_CASE("EditorCore linked editing supports prev navigation and explicit cancel") {
  EditorConfig config;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  TextEditResult insert_result = editor.insertSnippet("${1:a}-${2:b}-$0");
  REQUIRE(insert_result.changed);
  REQUIRE(editor.isInLinkedEditing());

  CHECK_FALSE(editor.linkedEditingPrevTabStop());
  CHECK(editor.isInLinkedEditing());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 1}}));

  REQUIRE(editor.linkedEditingNextTabStop());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 2}, {0, 3}}));

  REQUIRE(editor.linkedEditingPrevTabStop());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 1}}));

  editor.cancelLinkedEditing();
  CHECK_FALSE(editor.isInLinkedEditing());
}
