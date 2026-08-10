#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/diff.h>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

namespace {
  U8String joinLines(const Vector<U8String>& lines) {
    U8String text;
    for (size_t index = 0; index < lines.size(); ++index) {
      if (index > 0) text.push_back('\n');
      text += lines[index];
    }
    return text;
  }

  size_t insertionDeletionDistance(const Vector<U8String>& left, const Vector<U8String>& right) {
    Vector<size_t> previous(right.size() + 1);
    Vector<size_t> current(right.size() + 1);
    for (size_t index = 0; index <= right.size(); ++index) previous[index] = index;
    for (size_t left_index = 1; left_index <= left.size(); ++left_index) {
      current[0] = left_index;
      for (size_t right_index = 1; right_index <= right.size(); ++right_index) {
        current[right_index] = left[left_index - 1] == right[right_index - 1]
                                   ? previous[right_index - 1]
                                   : std::min(previous[right_index], current[right_index - 1]) + 1;
      }
      previous.swap(current);
    }
    return previous.back();
  }

  Vector<Vector<U8String>> makeLineSequences(size_t max_length) {
    Vector<Vector<U8String>> sequences;
    for (size_t length = 1; length <= max_length; ++length) {
      const size_t combinations = size_t{1} << length;
      for (size_t bits = 0; bits < combinations; ++bits) {
        Vector<U8String> lines;
        for (size_t index = 0; index < length; ++index) {
          lines.push_back((bits & (size_t{1} << index)) != 0 ? "b" : "a");
        }
        sequences.push_back(std::move(lines));
      }
    }
    return sequences;
  }
}

TEST_CASE("Diff computes line additions removals replacements and line-ending changes") {
  SECTION("addition") {
    LineArrayDocument current("a\nb\nc");
    Diff diff;
    REQUIRE(diff.compute("a\nc", current));
    REQUIRE(diff.getChanges().size() == 1);
    const DiffChange& change = diff.getChanges().front();
    CHECK(change.current_start_line == 1);
    CHECK(change.current_line_count == 1);
    CHECK(change.original_start_line == 1);
    CHECK(change.removed_lines.empty());
  }

  SECTION("removal") {
    LineArrayDocument current("a\nc");
    Diff diff;
    REQUIRE(diff.compute("a\nb\nc", current));
    REQUIRE(diff.getChanges().size() == 1);
    const DiffChange& change = diff.getChanges().front();
    CHECK(change.current_start_line == 1);
    CHECK(change.current_line_count == 0);
    CHECK(change.original_start_line == 1);
    REQUIRE(change.removed_lines.size() == 1);
    CHECK(change.removed_lines.front() == "b");
  }

  SECTION("replacement") {
    LineArrayDocument current("a\nx\nc");
    Diff diff;
    REQUIRE(diff.compute("a\nb\nc", current));
    REQUIRE(diff.getChanges().size() == 1);
    const DiffChange& change = diff.getChanges().front();
    CHECK(change.current_start_line == 1);
    CHECK(change.current_line_count == 1);
    CHECK(change.original_start_line == 1);
    REQUIRE(change.removed_lines.size() == 1);
    CHECK(change.removed_lines.front() == "b");
  }

  SECTION("line ending") {
    LineArrayDocument current("a\nb");
    Diff diff;
    REQUIRE(diff.compute("a\r\nb", current));
    REQUIRE(diff.getChanges().size() == 1);
    const DiffChange& change = diff.getChanges().front();
    CHECK(change.current_start_line == 0);
    CHECK(change.current_line_count == 1);
    CHECK(change.original_start_line == 0);
    REQUIRE(change.removed_lines.size() == 1);
    CHECK(change.removed_lines.front() == "a");
  }
}

TEST_CASE("Diff computation produces minimal normalized hunks for repeated lines") {
  const Vector<Vector<U8String>> sequences = makeLineSequences(4);
  for (const Vector<U8String>& original : sequences) {
    for (const Vector<U8String>& current : sequences) {
      LineArrayDocument document(joinLines(current));
      Diff diff;
      REQUIRE(diff.compute(joinLines(original), document));

      size_t original_cursor = 0;
      size_t current_cursor = 0;
      size_t edit_cost = 0;
      for (const DiffChange& change : diff.getChanges()) {
        REQUIRE(change.current_start_line >= current_cursor);
        REQUIRE(change.original_start_line >= original_cursor);
        const size_t current_gap = change.current_start_line - current_cursor;
        const size_t original_gap = change.original_start_line - original_cursor;
        REQUIRE(current_gap == original_gap);
        for (size_t offset = 0; offset < current_gap; ++offset) {
          CHECK(current[current_cursor + offset] == original[original_cursor + offset]);
        }
        for (size_t offset = 0; offset < change.removed_lines.size(); ++offset) {
          REQUIRE(change.original_start_line + offset < original.size());
          CHECK(change.removed_lines[offset] == original[change.original_start_line + offset]);
        }
        edit_cost += change.current_line_count + change.removed_lines.size();
        current_cursor = change.current_start_line + change.current_line_count;
        original_cursor = change.original_start_line + change.removed_lines.size();
      }

      REQUIRE(current.size() - current_cursor == original.size() - original_cursor);
      while (current_cursor < current.size()) {
        CHECK(current[current_cursor++] == original[original_cursor++]);
      }
      CHECK(edit_cost == insertionDeletionDistance(original, current));
    }
  }
}

TEST_CASE("Diff validates and normalizes external changes atomically") {
  Diff diff;
  Vector<DiffChange> adjacent{
      {1, 1, 1, {"old one"}},
      {2, 1, 2, {"old two"}},
  };
  REQUIRE(diff.setChanges(std::move(adjacent), 4));
  REQUIRE(diff.getChanges().size() == 1);
  CHECK(diff.getChanges().front().current_line_count == 2);
  CHECK(diff.getChanges().front().removed_lines == Vector<U8String>{"old one", "old two"});
  CHECK(diff.getMaxRemovedLineEnd() == 3);

  Vector<DiffChange> invalid{{0, 2, 0, {"old"}}, {1, 1, 2, {"other"}}};
  CHECK_FALSE(diff.setChanges(std::move(invalid), 4));
  REQUIRE(diff.getChanges().size() == 1);
  CHECK(diff.getChanges().front().removed_lines.front() == "old one");
  CHECK(diff.getMaxRemovedLineEnd() == 3);

  Vector<DiffChange> incoherent{{1, 0, 1, {"first"}}, {1, 0, 3, {"second"}}};
  CHECK_FALSE(diff.setChanges(std::move(incoherent), 4));

  Vector<DiffChange> embedded_line_ending{{0, 0, 0, {"old\nline"}}};
  CHECK_FALSE(diff.setChanges(std::move(embedded_line_ending), 4));

  Vector<DiffChange> invalid_utf8{{0, 0, 0, {U8String(1, static_cast<char>(0xFF))}}};
  CHECK_FALSE(diff.setChanges(std::move(invalid_utf8), 4));

  diff.clear();
  CHECK(diff.getMaxRemovedLineEnd() == 0);
}

TEST_CASE("Diff keeps distinct line-ending and end-of-file changes") {
  SECTION("trailing newline") {
    LineArrayDocument current("a\n");
    Diff diff;
    REQUIRE(diff.compute("a", current));
    REQUIRE(diff.getChanges().size() == 1);
    CHECK(diff.getChanges().front().current_start_line == 1);
    CHECK(diff.getChanges().front().current_line_count == 1);
    CHECK(diff.getChanges().front().original_start_line == 1);
    CHECK(diff.getChanges().front().removed_lines.empty());
  }

  SECTION("removed final line") {
    LineArrayDocument current("a");
    Diff diff;
    REQUIRE(diff.compute("a\nb", current));
    REQUIRE(diff.getChanges().size() == 1);
    CHECK(diff.getChanges().front().current_start_line == 1);
    CHECK(diff.getChanges().front().current_line_count == 0);
    CHECK(diff.getChanges().front().original_start_line == 1);
    CHECK(diff.getChanges().front().removed_lines == Vector<U8String>{"b"});
  }
}

TEST_CASE("Diff removed-line spans validate UTF-16 coordinates atomically") {
  Diff diff;
  REQUIRE(diff.setChanges({DiffChange{0, 0, 0, {"a\xF0\x9F\x98\x80z"}}}, 1));

  StyleSpan emoji;
  emoji.column = 1;
  emoji.length = 2;
  emoji.style_id = 7;
  REQUIRE(diff.setBatchLineSpans(SpanLayer::SYNTAX, {{0, {emoji}}}));
  REQUIRE(diff.getMergedLineSpans(0).size() == 1);
  REQUIRE(diff.setBatchLineSpans(SpanLayer::SYNTAX, {}));
  REQUIRE(diff.getMergedLineSpans(0).size() == 1);

  StyleSpan out_of_range = emoji;
  out_of_range.column = 3;
  out_of_range.length = 2;
  CHECK_FALSE(diff.setBatchLineSpans(SpanLayer::SYNTAX, {{0, {out_of_range}}}));
  REQUIRE(diff.getMergedLineSpans(0).size() == 1);
  CHECK(diff.getMergedLineSpans(0).front().style_id == 7);
}

TEST_CASE("Diff computation replaces the complete snapshot") {
  LineArrayDocument current("a\nc");
  Diff diff;
  REQUIRE(diff.compute("a\nb\nc", current));

  StyleSpan span{0, 1, 7};
  REQUIRE(diff.setBatchLineSpans(SpanLayer::SYNTAX, {{1, {span}}}));
  REQUIRE_FALSE(diff.getMergedLineSpans(1).empty());

  REQUIRE(diff.compute("a\nb\nc", current));
  CHECK(diff.getMergedLineSpans(1).empty());
}

TEST_CASE("EditorCore projects removed diff rows without giving them text semantics") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});

  EditorRenderColors colors;
  colors.diff_removed_line_background = static_cast<int32_t>(0x22112233u);
  colors.diff_removed_gutter_background = static_cast<int32_t>(0x33445566u);
  editor.setEditorRenderColors(colors);
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"b"}}}).handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  auto removed = std::find_if(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  });
  REQUIRE(removed != model.lines.end());
  CHECK(removed->logical_line == 1);
  CHECK(removed->line_number == 2);
  CHECK(removed->line_background_color == colors.diff_removed_line_background);
  CHECK(removed->gutter_background_color == colors.diff_removed_gutter_background);
  CHECK_FALSE(removed->owns_gutter_semantics);
  CHECK(collectVisualLineText(*removed) == "b");

  const U8String json = model.toJson();
  CHECK(json.find("\"kind\": \"REMOVED\"") != U8String::npos);
  CHECK(json.find("\"line_number\": 2") != U8String::npos);
  CHECK(json.find("\"line_background_color\"") != U8String::npos);
  CHECK(json.find("\"gutter_background_color\"") != U8String::npos);
}

TEST_CASE("TextLayout maps removed rows to adjacent document boundaries") {
  SharedPtr<TextMeasurer> measurer = makeShared<FixedWidthTextMeasurer>(10.0f);
  TextStyleRegistry text_styles;
  Diff diff;
  REQUIRE(diff.setChanges({DiffChange{1, 0, 1, {"removed"}}}, 2));
  TextLayout layout(measurer, text_styles, diff);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nc");
  layout.loadDocument(document);
  layout.setViewport({400, 200});
  layout.setViewState({1.0f, 0.0f, 0.0f});

  EditorRenderModel model;
  layout.layoutVisibleLines(model);
  const auto removed = std::find_if(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  });
  REQUIRE(removed != model.lines.end());
  const PointF point{removed->runs.front().x + 1.0f,
                     removed->line_number_position.y};

  const CaretHit pointer = layout.hitTestPointer(point);
  CHECK_FALSE(pointer.hits_document_text);
  CHECK(pointer.position == (TextPosition{1, 0}));
  CHECK(layout.hitTestTextBoundary(point).position == (TextPosition{1, 0}));
  CHECK(layout.hitTestVerticalNavigation(point, false).position == (TextPosition{0, 0}));
  CHECK(layout.hitTestVerticalNavigation(point, true).position == (TextPosition{1, 0}));
}

TEST_CASE("EditorCore vertical navigation stays put beyond virtual document boundaries") {
  EditorOptions options;

  SECTION("CodeLens above the first document row") {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>("abcd"));
    editor.setViewport({400, 200});
    REQUIRE(editor.setLineCodeLens(0, {{0, 1, "reference"}}).handled);
    REQUIRE(editor.setCursorPosition({0, 3}).handled);

    REQUIRE(editor.moveCursorUp(false).handled);
    CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
  }

  SECTION("removed rows after the final document row") {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>("abcd"));
    editor.setViewport({400, 200});
    REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"removed"}}}).handled);
    REQUIRE(editor.setCursorPosition({0, 1}).handled);

    REQUIRE(editor.moveCursorDown(false).handled);
    CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
  }
}

TEST_CASE("EditorCore double tap on a removed row does not select document text") {
  EditorOptions options;
  options.double_tap_timeout = 1000;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"removed"}}}).handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const auto removed = std::find_if(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  });
  REQUIRE(removed != model.lines.end());
  const float point[2] = {removed->runs.front().x + 1.0f,
                          removed->line_number_position.y + 1.0f};

  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, point));
  editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_DOWN, 1, point));
  const EditorActionResult result =
      editor.handleGestureEvent(GestureEvent::create(EventType::TOUCH_UP, 1, point));

  CHECK(result.gesture_type == GestureType::DOUBLE_TAP);
  CHECK_FALSE(editor.hasSelection());
  CHECK(editor.getCursorPosition() == (TextPosition{1, 0}));
}

TEST_CASE("EditorCore renders removals at the end boundary and wraps them without duplicate numbers") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a"));
  editor.setViewport({55, 200});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"long removed line"}}}).handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  Vector<const VisualLine*> removed_lines;
  for (const VisualLine& line : model.lines) {
    if (line.kind == VisualLineKind::REMOVED) removed_lines.push_back(&line);
  }
  REQUIRE(removed_lines.size() > 1);
  CHECK(removed_lines.front()->line_number == 2);
  for (size_t index = 1; index < removed_lines.size(); ++index) {
    CHECK(removed_lines[index]->line_number == -1);
  }
}

TEST_CASE("EditorCore renders removals both before the last current line and after EOF") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});
  REQUIRE(editor.computeDiff("a\nb\nc\nd").handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  Vector<U8String> removed_texts;
  for (const VisualLine& line : model.lines) {
    if (line.kind == VisualLineKind::REMOVED) removed_texts.push_back(collectVisualLineText(line));
  }
  CHECK(removed_texts == Vector<U8String>{"b", "d"});
}

TEST_CASE("EditorCore attaches EOF removals to the last visible folded line") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nb\nc\nd"));
  editor.setViewport({400, 200});
  editor.setFoldRegions({{1, 3, true}});
  REQUIRE(editor.computeDiff("a\nb\nc\nd\nremoved").handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const auto removed = std::find_if(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  });
  REQUIRE(removed != model.lines.end());
  CHECK(removed->logical_line == 1);
  CHECK(collectVisualLineText(*removed) == "removed");
}

TEST_CASE("EditorCore emits only removed rows intersecting the viewport") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("current");
  editor.loadDocument(document);
  editor.setViewport({400, 48});

  Vector<U8String> removed_lines(1000, "removed");
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, std::move(removed_lines)}}).handled);
  editor.setScroll(0.0f, 6000.0f);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE_FALSE(model.lines.empty());
  CHECK(model.lines.size() <= 6);
  CHECK(std::all_of(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));
}

TEST_CASE("EditorCore invalidates only diff owners for removed-line span updates") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nc\nd");
  editor.loadDocument(document);
  editor.setViewport({400, 200});
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"b"}}}).handled);

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const float unrelated_height = document->getLogicalLines()[2].height;
  REQUIRE(unrelated_height >= 0.0f);

  REQUIRE(editor.setBatchDiffLineSpans(SpanLayer::SYNTAX, {{1, {{0, 1, 7}}}}).handled);
  CHECK(document->getLogicalLines()[1].is_layout_dirty);
  CHECK(document->getLogicalLines()[2].height == unrelated_height);
}

TEST_CASE("EditorCore edits without diff preserve unrelated layout caches") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc");
  editor.loadDocument(document);
  editor.setViewport({400, 200});

  EditorRenderModel model;
  editor.buildRenderModel(model);
  const float unrelated_height = document->getLogicalLines()[2].height;
  REQUIRE(unrelated_height >= 0.0f);

  REQUIRE(editor.insertText("x").handled);
  CHECK(document->getLogicalLines()[2].height == unrelated_height);
}

TEST_CASE("EditorCore clears every diff snapshot after committed edits") {
  EditorOptions options;

  SECTION("computed") {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>("a\nb"));
    EditorRenderColors colors;
    colors.diff_added_line_background = static_cast<int32_t>(0x22112233u);
    editor.setEditorRenderColors(colors);
    REQUIRE(editor.computeDiff("a\nb").handled);
    REQUIRE(editor.insertText("c").handled);

    EditorRenderModel model;
    editor.setViewport({400, 200});
    editor.buildRenderModel(model);
    CHECK(std::none_of(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
      return line.kind == VisualLineKind::REMOVED || line.line_background_color != 0;
    }));
  }

  SECTION("external") {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
    editor.loadDocument(makeShared<LineArrayDocument>("a\nb"));
    EditorRenderColors colors;
    colors.diff_added_line_background = static_cast<int32_t>(0x22112233u);
    editor.setEditorRenderColors(colors);
    REQUIRE(editor.setDiffChanges({DiffChange{0, 1, 0, {}}}).handled);
    REQUIRE(editor.insertText("c").handled);

    EditorRenderModel model;
    editor.setViewport({400, 200});
    editor.buildRenderModel(model);
    CHECK(std::none_of(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
      return line.kind == VisualLineKind::REMOVED || line.line_background_color != 0;
    }));
  }
}

TEST_CASE("EditorCore clears diff snapshots after undo and redo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});
  editor.setCursorPosition({0, 1});
  REQUIRE(editor.insertText("x").handled);

  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"b"}}}).handled);
  REQUIRE(editor.undo().handled);
  EditorRenderModel undo_model;
  editor.buildRenderModel(undo_model);
  CHECK(std::none_of(undo_model.lines.begin(), undo_model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));

  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"b"}}}).handled);
  REQUIRE(editor.redo().handled);
  EditorRenderModel redo_model;
  editor.buildRenderModel(redo_model);
  CHECK(std::none_of(redo_model.lines.begin(), redo_model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));
}

TEST_CASE("EditorCore hides diff rows during composition and clears them after commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});
  REQUIRE(editor.computeDiff("a\nb\nc").handled);

  const ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  REQUIRE(editor.applyImeCommands({session.session_id, {update}}).handled);
  REQUIRE(editor.hasComposition());

  EditorRenderModel composing_model;
  editor.buildRenderModel(composing_model);
  CHECK(std::none_of(composing_model.lines.begin(), composing_model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));

  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  REQUIRE(editor.applyImeCommands({session.session_id, {finish}}).handled);
  CHECK_FALSE(editor.hasComposition());

  EditorRenderModel committed_model;
  editor.buildRenderModel(committed_model);
  CHECK(std::none_of(committed_model.lines.begin(), committed_model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));
}

TEST_CASE("EditorCore restores externally supplied diff rows after composition cancellation") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nc"));
  editor.setViewport({400, 200});
  REQUIRE(editor.setDiffChanges({DiffChange{1, 0, 1, {"b"}}}).handled);

  const ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  REQUIRE(editor.applyImeCommands({session.session_id, {update}}).handled);

  ImeCommand cancel;
  cancel.kind = ImeCommandKind::CANCEL_COMPOSITION;
  REQUIRE(editor.applyImeCommands({session.session_id, {cancel}}).handled);
  CHECK_FALSE(editor.hasComposition());

  EditorRenderModel model;
  editor.buildRenderModel(model);
  CHECK(std::any_of(model.lines.begin(), model.lines.end(), [](const VisualLine& line) {
    return line.kind == VisualLineKind::REMOVED;
  }));
}
