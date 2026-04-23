#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore composition update is transient and cancel restores original text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  editor.compositionStart();
  editor.compositionUpdate("x");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abx");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  editor.compositionUpdate("xy");
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  editor.compositionCancel();
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

  editor.compositionStart();
  editor.compositionUpdate("xy");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "abxy");

  TextEditResult result = editor.compositionEnd("");
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

TEST_CASE("EditorCore composition disabled mode commits only on compositionEnd") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(false);
  editor.setCursorPosition({0, 2});

  editor.compositionUpdate("q");
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ab");

  TextEditResult result = editor.compositionEnd("z");
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

  editor.compositionUpdate("how");
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

  editor.compositionUpdate("x");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");

  editor.setCursorPosition({0, 4});
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "axbc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

