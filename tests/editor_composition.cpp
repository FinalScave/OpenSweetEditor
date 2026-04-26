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

TEST_CASE("EditorCore set composing region preserves cursor inside region") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  editor.setComposingRegion({{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));

  editor.setComposingRegion({{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore composition end preserves cursor inside existing composing text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  editor.setComposingRegion({{0, 0}, {0, 4}});
  REQUIRE(editor.isComposing());

  TextEditResult result = editor.compositionEnd("");
  CHECK_FALSE(result.changed);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
  CHECK(result.changes.empty());
  CHECK(result.cursor_before == (TextPosition{0, 2}));
  CHECK(result.cursor_after == (TextPosition{0, 2}));
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore composing text after document range replaces only on commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCompositionEnabled(true);
  editor.setCursorPosition({0, 2});

  editor.setComposingRegion({{0, 0}, {0, 4}});
  editor.compositionUpdate("how");
  REQUIRE(editor.isComposing());
  CHECK(document->getU8Text() == "how tail");

  editor.compositionCancel();
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "word tail");
  CHECK_FALSE(editor.canUndo());

  editor.setComposingRegion({{0, 0}, {0, 4}});
  editor.compositionUpdate("how");
  TextEditResult result = editor.compositionEnd("");
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
  editor.setCursorPosition({0, 15});

  editor.setLineInlayHints(0, {InlayHint{InlayType::COLOR, 20, "", 0, static_cast<int32_t>(0xFF112233u)}});

  editor.setComposingRegion({{0, 13}, {0, 19}});
  TextEditResult first_finish = editor.compositionEnd("");
  CHECK_FALSE(first_finish.changed);
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  editor.setComposingRegion({{0, 13}, {0, 19}});
  TextEditResult second_finish = editor.compositionEnd("");
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
  editor.setCursorPosition({0, 9});

  TextRange point_range {{0, 7}, {0, 12}};
  editor.setComposingRegion(point_range);
  editor.setComposingRegion(point_range);
  editor.setComposingRegion(point_range);

  TextEditResult result = editor.compositionEnd("Points");
  REQUIRE(result.changed);
  REQUIRE(result.changes.size() == 1);
  CHECK_FALSE(editor.isComposing());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
  CHECK(result.changes[0].range == point_range);
  CHECK(result.changes[0].old_text == "Point");
  CHECK(result.changes[0].new_text == "Points");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}

