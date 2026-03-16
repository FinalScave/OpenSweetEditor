#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore composition update is transient and cancel restores original text") {
  EditorConfig config;
  config.enable_composition = true;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
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
  EditorConfig config;
  config.enable_composition = true;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
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
  EditorConfig config;
  config.enable_composition = false;
  EditorCore editor(config, makePtr<FixedWidthTextMeasurer>());

  Ptr<Document> document = makePtr<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  editor.compositionUpdate("q");
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "ab");

  TextEditResult result = editor.compositionEnd("z");
  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "abz");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}
