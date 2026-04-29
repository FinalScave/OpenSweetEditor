#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore normalizes selection before insert replacement") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
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

TEST_CASE("EditorCore insertText with empty string deletes selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello world");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 6}, {0, 11}});
  TextEditResult result = editor.insertText("");

  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "hello ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK_FALSE(editor.hasSelection());
  REQUIRE(result.changes.size() == 1);
  CHECK(result.changes[0].old_text == "world");
  CHECK(result.changes[0].new_text == "");
}

TEST_CASE("EditorCore insertText with empty string and no selection is no-op") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 3});
  TextEditResult result = editor.insertText("");

  CHECK_FALSE(result.changed);
  CHECK(document->getU8Text() == "hello");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
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
  KeyEventResult key_result = editor.handleKeyEvent(event);

  REQUIRE(key_result.handled);
  REQUIRE(key_result.content_changed);
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
  KeyEventResult key_result = editor.handleKeyEvent(event);

  REQUIRE(key_result.handled);
  REQUIRE(key_result.content_changed);
  CHECK(document->getU8Text() == "    foo");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore backspace removes one surrogate pair as a single glyph") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3}); // after 'A' (1) and emoji (2)

  TextEditResult result = editor.backspace();

  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "AB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore clamps cursor positions away from surrogate middles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));

  editor.moveCursorRight();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  editor.moveCursorLeft();
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
}

TEST_CASE("EditorCore keeps zero-length selection collapsed when clamped around a surrogate pair") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setSelection({{0, 2}, {0, 2}});

  CHECK(editor.getSelection() == (TextRange{{0, 1}, {0, 1}}));
  CHECK_FALSE(editor.hasSelection());
}

TEST_CASE("EditorCore deleteForward removes one surrogate pair as a single glyph") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  TextEditResult result = editor.deleteForward();

  REQUIRE(result.changed);
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
  TextEditResult backspace_result = editor.backspace();
  REQUIRE(backspace_result.changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));

  document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});
  TextEditResult delete_result = editor.deleteForward();
  REQUIRE(delete_result.changed);
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

  TextEditResult replace_result = editor.replaceText({{0, 2}, {0, 2}}, "X");
  REQUIRE(replace_result.changed);
  CHECK(document->getU8Text() == "X\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));

  document = makeShared<LineArrayDocument>("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  TextEditResult delete_result = editor.deleteText({{0, 2}, {0, 4}});
  REQUIRE(delete_result.changed);
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

  TextEditResult backspace_result = editor.backspace();
  REQUIRE(backspace_result.changed);
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

  TextEditResult delete_result = editor.deleteText({{0, 2}, {0, 4}});
  REQUIRE(delete_result.changed);
  CHECK(document->getU8Text() == "");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore getWordRangeAtCursor keeps combining graphemes intact") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\xCC\x81" "bc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  editor.setCursorPosition({0, 2});

  CHECK(editor.getWordRangeAtCursor() == (TextRange{{0, 0}, {0, 4}}));
  CHECK(editor.getWordAtCursor() == "a\xCC\x81" "bc");
}

TEST_CASE("EditorCore replaceText normalizes insert positions away from surrogate middles") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  TextEditResult result = editor.replaceText({{0, 2}, {0, 2}}, "X");

  REQUIRE(result.changed);
  CHECK(document->getU8Text() == "AX\xF0\x9F\x98\x80" "B");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore deleteText expands surrogate-spanning ranges to full code-point boundaries") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\xF0\x9F\x98\x80" "B");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  TextEditResult result = editor.deleteText({{0, 2}, {0, 3}});

  REQUIRE(result.changed);
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
