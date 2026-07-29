#include <catch2/catch_amalgamated.hpp>
#include <algorithm>
#include <functional>
#include <unordered_map>
#include <vector>
#include <sweeteditor/editor_core.h>
#include <sweeteditor/utility.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

namespace {

  size_t utf16OffsetForPosition(const U8String& text, const TextPosition& position, bool line_overflow_to_end) {
    U16String utf16;
    StrUtil::convertUTF8ToUTF16(text, utf16);

    size_t current_line = 0;
    size_t line_start = 0;
    for (size_t i = 0; i < utf16.size() && current_line < position.line; ++i) {
      if (utf16[i] == u'\n') {
        ++current_line;
        line_start = i + 1;
      }
    }

    if (current_line < position.line) {
      return line_overflow_to_end ? utf16.size() : line_start;
    }

    size_t line_end = line_start;
    while (line_end < utf16.size() && utf16[line_end] != u'\n') {
      ++line_end;
    }

    const size_t column = std::min<size_t>(position.column, line_end - line_start);
    return line_start + column;
  }

  EditorActionResult updateComposition(EditorCore& editor, const U8String& text);
  EditorActionResult setCompositionSelection(EditorCore& editor, const U8String& text, size_t selection_start_offset,
                                         size_t selection_end_offset);
  EditorActionResult commitText(EditorCore& editor, const U8String& text);
  EditorActionResult commitText(EditorCore& editor, const U8String& text, int cursor_offset);
  EditorActionResult finishActiveComposition(EditorCore& editor);
  EditorActionResult cancelActiveComposition(EditorCore& editor);
  EditorActionResult markDocumentRange(EditorCore& editor, const TextRange& range);
  EditorActionResult markDocumentRange(EditorCore& editor, size_t start_offset, size_t end_offset);
  EditorActionResult deleteBackward(EditorCore& editor, size_t count = 1,
                                    ImeTextUnit text_unit = ImeTextUnit::UNICODE_CODE_POINT);
  EditorActionResult deleteForward(EditorCore& editor, size_t count = 1,
                                   ImeTextUnit text_unit = ImeTextUnit::UNICODE_CODE_POINT);
  EditorActionResult deleteSurrounding(EditorCore& editor, size_t before_length, size_t after_length,
                                       ImeTextUnit text_unit = ImeTextUnit::UNICODE_CODE_POINT);
  EditorActionResult selectionChanged(EditorCore& editor, const TextRange& range);
  EditorActionResult cursorChanged(EditorCore& editor, const TextPosition& cursor);

  uint64_t commandSession(EditorCore& editor) {
    static std::unordered_map<EditorCore*, uint64_t> sessions;
    auto found = sessions.find(&editor);
    if (found != sessions.end() && editor.getImeState(found->second).result_code == ImeResultCode::OK) {
      return found->second;
    }
    ImeState state = editor.beginImeSession(ImeMutationModel::COMMAND);
    REQUIRE(state.result_code == ImeResultCode::OK);
    sessions[&editor] = state.session_id;
    return state.session_id;
  }

  EditorActionResult applyCommand(EditorCore& editor, ImeCommand command) {
    return editor.applyImeCommands({commandSession(editor), {std::move(command)}});
  }

  class ImeReplayRunner {
  public:
    explicit ImeReplayRunner(EditorCore& editor)
        : m_editor(editor) {
    }

    EditorActionResult updateComposition(const U8String& text) {
      return ::updateComposition(m_editor, text);
    }

    EditorActionResult commitText(const U8String& text) {
      return ::commitText(m_editor, text);
    }

    EditorActionResult finishActiveComposition() {
      return ::finishActiveComposition(m_editor);
    }

    EditorActionResult markDocumentRange(const TextRange& range) {
      return ::markDocumentRange(m_editor, range);
    }

    EditorActionResult selectionChanged(const TextRange& range) {
      return m_editor.setSelection(range);
    }

  private:
    EditorCore& m_editor;
  };

  EditorActionResult updateComposition(EditorCore& editor, const U8String& text) {
    ImeCommand command;
    command.kind = ImeCommandKind::UPDATE_COMPOSITION;
    command.text = text;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult commitText(EditorCore& editor, const U8String& text) {
    ImeCommand command;
    command.kind = ImeCommandKind::COMMIT_TEXT;
    command.text = text;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult commitText(EditorCore& editor, const U8String& text, int cursor_offset) {
    ImeState state = editor.getImeState(commandSession(editor));
    const int64_t start = state.composition_range.start_utf16 >= 0
                              ? state.composition_range.start_utf16
                              : std::min(state.selection.anchor_utf16, state.selection.active_utf16);
    const int64_t end = start + static_cast<int64_t>(StrUtil::utf16Length(text));
    const int64_t target = cursor_offset > 0 ? end + cursor_offset - 1 : start + cursor_offset;
    ImeCommand command;
    command.kind = ImeCommandKind::COMMIT_TEXT;
    command.text = text;
    command.selection_after = {ImeCoordinateSpace::DOCUMENT, target, target, CaretAffinity::DOWNSTREAM};
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult setCompositionSelection(EditorCore& editor, const U8String& text, size_t selection_start_offset,
                                         size_t selection_end_offset) {
    ImeCommand command;
    command.kind = ImeCommandKind::UPDATE_COMPOSITION;
    command.text = text;
    command.selection_after = {ImeCoordinateSpace::COMPOSITION, static_cast<int64_t>(selection_start_offset),
                               static_cast<int64_t>(selection_end_offset), CaretAffinity::DOWNSTREAM};
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult finishActiveComposition(EditorCore& editor) {
    ImeCommand command;
    command.kind = ImeCommandKind::FINISH_COMPOSITION;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult cancelActiveComposition(EditorCore& editor) {
    ImeCommand command;
    command.kind = ImeCommandKind::CANCEL_COMPOSITION;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult markDocumentRange(EditorCore& editor, const TextRange& range) {
    const uint64_t session_id = commandSession(editor);
    ImeTextContext context = editor.getImeContext(session_id, ImeTextSource::EDITING, 0, -1);
    ImeCommand command;
    command.kind = ImeCommandKind::BEGIN_COMPOSITION;
    command.target_range = {ImeCoordinateSpace::DOCUMENT,
                            static_cast<int64_t>(utf16OffsetForPosition(context.text, range.start, false)),
                            static_cast<int64_t>(utf16OffsetForPosition(context.text, range.end, true))};
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult markDocumentRange(EditorCore& editor, size_t start_offset, size_t end_offset) {
    return markDocumentRange(editor, {{0, start_offset}, {0, end_offset}});
  }

  EditorActionResult deleteBackward(EditorCore& editor, size_t count, ImeTextUnit text_unit) {
    ImeCommand command;
    command.kind = ImeCommandKind::DELETE_SURROUNDING;
    command.delete_before = static_cast<int64_t>(count);
    command.text_unit = text_unit;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult deleteForward(EditorCore& editor, size_t count, ImeTextUnit text_unit) {
    ImeCommand command;
    command.kind = ImeCommandKind::DELETE_SURROUNDING;
    command.delete_after = static_cast<int64_t>(count);
    command.text_unit = text_unit;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult deleteSurrounding(EditorCore& editor, size_t before_length, size_t after_length,
                                       ImeTextUnit text_unit) {
    ImeCommand command;
    command.kind = ImeCommandKind::DELETE_SURROUNDING;
    command.delete_before = static_cast<int64_t>(before_length);
    command.delete_after = static_cast<int64_t>(after_length);
    command.text_unit = text_unit;
    return applyCommand(editor, std::move(command));
  }

  EditorActionResult selectionChanged(EditorCore& editor, const TextRange& range) {
    return editor.setSelection(range);
  }

  EditorActionResult cursorChanged(EditorCore& editor, const TextPosition& cursor) {
    return editor.setCursorPosition(cursor);
  }

}

TEST_CASE("IME state value semantics cover canonical ranges and selections") {
  ImeOffsetRange range;
  CHECK(range == ImeOffsetRange{});
  range.end_utf16 = 0;
  CHECK(range != ImeOffsetRange{});

  ImeSelection selection;
  CHECK(selection == ImeSelection{});
  selection.affinity = CaretAffinity::UPSTREAM;
  CHECK(selection != ImeSelection{});
}

TEST_CASE("EditorCore composition update is transient and cancel restores original text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  updateComposition(editor, "x");
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abx");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  updateComposition(editor, "xy");
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  cancelActiveComposition(editor);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore composition end commits final text once and supports undo") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updateComposition(editor, "xy");
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abxy");

  EditorActionResult result = finishActiveComposition(editor);
  CHECK(result.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abxy");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE_FALSE(undo_result.text_changes.empty());
  CHECK(document->getU8Text() == "ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
}

TEST_CASE("EditorCore IME commit cursor offset is applied in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abCD");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  commitText(editor, "X", 1);
  CHECK(document->getU8Text() == "abXCD");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));

  commitText(editor, "Y", 0);
  CHECK(document->getU8Text() == "abXYCD");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
}

TEST_CASE("EditorCore IME composing selection offsets are applied in core") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  setCompositionSelection(editor, "xyz", 1, 2);
  CHECK(document->getU8Text() == "abxyz");
  REQUIRE(editor.hasComposition());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 3}, {0, 4}}));

  setCompositionSelection(editor, "pq", 2, 2);
  CHECK(document->getU8Text() == "abpq");
  CHECK_FALSE(editor.hasSelection());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore backspace during composition shrinks text step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updateComposition(editor, "how");
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abhow");

  EditorActionResult first_backspace = editor.backspace();
  REQUIRE_FALSE(first_backspace.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abho");

  editor.backspace();
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abh");

  editor.backspace();
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore moving cursor commits composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  updateComposition(editor, "x");
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "axbc");

  EditorActionResult move = editor.setCursorPosition({0, 4});
  CHECK(move.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "axbc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore set composing region preserves cursor at range end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));

  finishActiveComposition(editor);
  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
}

TEST_CASE("EditorCore composition end preserves cursor at existing composing range end") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasComposition());

  EditorActionResult result = finishActiveComposition(editor);
  CHECK(result.text_changes.empty());
  CHECK_FALSE(result.cursor_changed);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "word");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 4}));
  CHECK(result.text_changes.empty());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore IME empty commit replaces active composing text with empty text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  REQUIRE(editor.hasComposition());

  EditorActionResult result = commitText(editor, "");

  CHECK_FALSE(result.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text().empty());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
}

TEST_CASE("EditorCore document range composition commit is undoable without duplicate text change") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("word tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  markDocumentRange(editor, {{0, 0}, {0, 4}});
  updateComposition(editor, "how");
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "how tail");

  cancelActiveComposition(editor);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "word tail");
  CHECK_FALSE(editor.canUndo());

  editor.setCursorPosition({0, 4});
  markDocumentRange(editor, {{0, 0}, {0, 4}});
  EditorActionResult update = updateComposition(editor, "how");
  REQUIRE_FALSE(update.text_changes.empty());
  REQUIRE(update.text_changes.size() == 1);
  CHECK(update.text_changes[0].range == (TextRange{{0, 0}, {0, 4}}));
  CHECK(update.text_changes[0].old_text == "word");
  CHECK(update.text_changes[0].new_text == "how");
  EditorActionResult result = finishActiveComposition(editor);
  CHECK(result.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "how tail");
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE_FALSE(undo_result.text_changes.empty());
  CHECK(document->getU8Text() == "word tail");
}

TEST_CASE("EditorCore document range composition finish does not move inlay hints") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("static int[] colors = new int[0];");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 19});

  editor.setLineInlayHints(0, {InlayHint{InlayType::COLOR, 20, static_cast<int32_t>(0xFF112233u), ""}});

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  EditorActionResult first_finish = finishActiveComposition(editor);
  CHECK(first_finish.text_changes.empty());
  CHECK(document->getU8Text() == "static int[] colors = new int[0];");

  markDocumentRange(editor, {{0, 13}, {0, 19}});
  EditorActionResult second_finish = finishActiveComposition(editor);
  CHECK(second_finish.text_changes.empty());
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
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore repeated document composing region commits replacement once") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x, double y) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 12});

  TextRange point_range{{0, 7}, {0, 12}};
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);
  markDocumentRange(editor, point_range);

  EditorActionResult result = commitText(editor, "Points");
  REQUIRE_FALSE(result.text_changes.empty());
  REQUIRE(result.text_changes.size() == 1);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "record Points(double x, double y) {}");
  CHECK(result.text_changes[0].range == point_range);
  CHECK(result.text_changes[0].old_text == "Point");
  CHECK(result.text_changes[0].new_text == "Points");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}

TEST_CASE("EditorCore IME event update drives visible composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  EditorActionResult result = updateComposition(editor, "how");

  REQUIRE(result.handled);
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abhow");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
  CHECK(result.ime_state.composition_range == (ImeOffsetRange{ImeCoordinateSpace::DOCUMENT, 2, 5}));
}

TEST_CASE("EditorCore IME event commit text finishes active composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updateComposition(editor, "how");
  REQUIRE(editor.hasComposition());

  EditorActionResult result = commitText(editor, "how");

  REQUIRE(result.handled);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abhow");
  CHECK(result.ime_state.composition_range == ImeOffsetRange{});
}

TEST_CASE("EditorCore IME event backspace shrinks composition step-by-step") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updateComposition(editor, "how");

  deleteBackward(editor, 1);
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abho");

  deleteBackward(editor, 1);
  REQUIRE(editor.hasComposition());
  CHECK(document->getU8Text() == "abh");

  deleteBackward(editor, 1);
  CHECK(editor.hasComposition());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore IME finish clears composition range") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("record Point(double x) {}");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 12});

  markDocumentRange(editor, {{0, 7}, {0, 12}});
  REQUIRE(editor.hasComposition());

  EditorActionResult result = finishActiveComposition(editor);

  CHECK_FALSE(editor.hasComposition());
  CHECK(result.ime_state.composition_range == ImeOffsetRange{});
}

TEST_CASE("EditorCore IME event CJK composition stays visible until commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  EditorActionResult update_result = updateComposition(editor, "ni");

  REQUIRE(update_result.handled);
  CHECK(document->getU8Text() == "ni");
  CHECK(editor.hasComposition());
  CHECK(update_result.ime_state.composition_range != ImeOffsetRange{});

  EditorActionResult commit_result = commitText(editor, "\xE4\xBD\xA0");

  CHECK_FALSE(commit_result.text_changes.empty());
  CHECK(document->getU8Text() == "\xE4\xBD\xA0");
  CHECK_FALSE(editor.hasComposition());
  CHECK(commit_result.ime_state.composition_range == ImeOffsetRange{});
}

TEST_CASE("EditorCore visible composition does not affect document undo and renders decoration") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 5, 0, "hint"}});

  EditorActionResult update_result = updateComposition(editor, "ni");

  CHECK_FALSE(update_result.text_changes.empty());
  CHECK(document->getU8Text() == "valueni");
  CHECK_FALSE(editor.canUndo());
  CHECK(editor.hasComposition());
  CHECK(update_result.ime_state.composition_range != ImeOffsetRange{});

  EditorRenderModel model;
  EditorRangeEffectStyles styles;
  styles.ime_composition.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.ime_composition.underline_style = RangeEffectUnderlineStyle::SOLID;
  editor.setEditorRangeEffectStyles(styles);
  editor.buildRenderModel(model);
  bool has_composition_effect = false;
  for (const RangeEffectRenderItem& effect : model.range_effects) {
    if (effect.kind == RangeEffectKind::IME_COMPOSITION) {
      has_composition_effect = true;
      break;
    }
  }
  CHECK(has_composition_effect);

  const VisualRun* hint_run = nullptr;
  for (const auto& line : model.lines) {
    for (const auto& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT) {
        hint_run = &run;
      }
    }
  }

  REQUIRE(hint_run != nullptr);
  CHECK(hint_run->column == 5);
}

TEST_CASE("EditorCore IME composition updates become one undoable commit") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  updateComposition(editor, "h");
  updateComposition(editor, "ho");
  updateComposition(editor, "how");

  CHECK(document->getU8Text() == "how");
  CHECK_FALSE(editor.canUndo());

  EditorActionResult commit_result = commitText(editor, "how");

  CHECK(commit_result.text_changes.empty());
  CHECK(document->getU8Text() == "how");
  CHECK(editor.canUndo());

  EditorActionResult undo_result = editor.undo();
  REQUIRE_FALSE(undo_result.text_changes.empty());
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore IME surrounding delete preserves selection and removes its sides") {
  auto run_delete_case = [](const std::function<EditorActionResult(EditorCore&)>& delete_action,
                            const U8String& expected_text, const TextRange& expected_selection) {
    EditorOptions options;
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
    SharedPtr<Document> document = makeShared<LineArrayDocument>("xhello worldy");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    ImeReplayRunner ime(editor);

    ime.selectionChanged({{0, 1}, {0, 6}});
    REQUIRE(editor.hasSelection());

    EditorActionResult result = delete_action(editor);

    REQUIRE_FALSE(result.text_changes.empty());
    CHECK(document->getU8Text() == expected_text);
    CHECK(editor.hasSelection());
    CHECK(editor.getSelection() == expected_selection);
  };

  SECTION("delete backward") {
    run_delete_case(
        [](EditorCore& editor) {
          return deleteBackward(editor, 1);
        },
        "hello worldy", {{0, 0}, {0, 5}});
  }
  SECTION("delete forward") {
    run_delete_case(
        [](EditorCore& editor) {
          return deleteForward(editor, 1);
        },
        "xhelloworldy", {{0, 1}, {0, 6}});
  }
  SECTION("delete surrounding") {
    run_delete_case(
        [](EditorCore& editor) {
          return deleteSurrounding(editor, 1, 1);
        },
        "helloworldy", {{0, 0}, {0, 5}});
  }
}

TEST_CASE("EditorCore IME document range rejects overflowing line") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello\nworld");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({1, 5});

  ImeCommand command;
  command.kind = ImeCommandKind::BEGIN_COMPOSITION;
  command.target_range = {ImeCoordinateSpace::DOCUMENT, 7, 999};
  EditorActionResult result = applyCommand(editor, command);

  CHECK(result.handled);
  CHECK_FALSE(editor.hasComposition());
  CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
}

TEST_CASE("EditorCore IME unknown document range can start platform composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  EditorActionResult result = markDocumentRange(editor, {{0, 0}, {0, 5}});

  CHECK(result.handled);
  REQUIRE(editor.hasComposition());
  CHECK(editor.hasComposition());
  CHECK(result.ime_state.composition_range == (ImeOffsetRange{ImeCoordinateSpace::DOCUMENT, 0, 5}));

  EditorActionResult commit_result = commitText(editor, "helloWorld");

  CHECK_FALSE(commit_result.text_changes.empty());
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.hasComposition());
}

TEST_CASE("EditorCore IME document range commit replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("hello");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 5}});
  REQUIRE(mark_result.ime_state.composition_range != ImeOffsetRange{});

  EditorActionResult commit_result = ime.commitText("helloWorld");
  REQUIRE_FALSE(commit_result.text_changes.empty());
  CHECK(document->getU8Text() == "helloWorld");
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 10}));
}

TEST_CASE("EditorCore IME document range suffix commit replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("default");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 7}});
  REQUIRE(editor.hasComposition());

  EditorActionResult commit_result = ime.commitText("defaults");
  REQUIRE_FALSE(commit_result.text_changes.empty());
  CHECK(document->getU8Text() == "defaults");
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 8}));
}

TEST_CASE("EditorCore IME document range suffix composition replaces word from middle cursor") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 6}});
  REQUIRE(editor.hasComposition());

  EditorActionResult update_result = ime.updateComposition("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  REQUIRE(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));

  EditorActionResult finish_result = ime.finishActiveComposition();
  CHECK(finish_result.handled);
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "Strings");
}

TEST_CASE("EditorCore IME platform full word range uses marked composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("String");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});
  ImeReplayRunner ime(editor);

  EditorActionResult mark_result = ime.markDocumentRange({{0, 0}, {0, 6}});
  REQUIRE(mark_result.composition_changed);
  REQUIRE(editor.getCompositionState().has_value());
  CHECK(editor.getCompositionState()->current_range == (TextRange{{0, 0}, {0, 6}}));

  EditorActionResult update_result = ime.updateComposition("Strings");
  CHECK(update_result.handled);
  CHECK(document->getU8Text() == "Strings");
  CHECK(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
}

TEST_CASE("EditorCore composition resolution commits before selection and adjusts decorations once") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("value tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  ImeReplayRunner ime(editor);

  ime.markDocumentRange({{0, 0}, {0, 5}});
  EditorActionResult update_result = ime.updateComposition("valuex");
  CHECK_FALSE(update_result.text_changes.empty());
  REQUIRE(document->getU8Text() == "valuex tail");

  editor.setLineInlayHints(0, {InlayHint{InlayType::TEXT, 6, 0, "hint"}});

  EditorActionResult selection_result = ime.selectionChanged({{0, 11}, {0, 11}});
  CHECK(selection_result.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "valuex tail");
  CHECK(editor.canUndo());

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun* hint_run = nullptr;
  for (const auto& line : model.lines) {
    for (const auto& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT && run.text == CHAR16("hint")) {
        hint_run = &run;
      }
    }
  }

  REQUIRE(hint_run != nullptr);
  CHECK(hint_run->column == 6);

  EditorActionResult undo_result = editor.undo();
  REQUIRE_FALSE(undo_result.text_changes.empty());
  CHECK(document->getU8Text() == "value tail");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 5}));
}

TEST_CASE("EditorCore composition cancel restores mixed raw line endings and baseline selection") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\r\nB\rC\nD");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{3, 0}, {0, 1}});

  updateComposition(editor, "x\ny");
  REQUIRE(editor.hasComposition());
  CHECK_FALSE(editor.canUndo());
  CHECK(document->getU8Text() == "Ax\nyD");

  cancelActiveComposition(editor);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "A\r\nB\rC\nD");
  CHECK(editor.getSelection() == (TextRange{{3, 0}, {0, 1}}));
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore zero-net composition finish restores baseline line endings") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\r\nB tail");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 0}, {1, 1}});

  EditorActionResult update = updateComposition(editor, "A\nB");
  CHECK_FALSE(update.text_changes.empty());
  CHECK(document->getU8Text() == "A\nB tail");

  EditorActionResult finish = finishActiveComposition(editor);
  CHECK_FALSE(finish.text_changes.empty());
  REQUIRE(finish.text_changes.size() == 1);
  CHECK(finish.text_changes[0].old_text == "A\nB");
  CHECK(finish.text_changes[0].new_text == "A\r\nB");
  CHECK(document->getU8Text() == "A\r\nB tail");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore provisional composition invalidates search state") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("alpha beta alpha");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  SearchRequest request;
  request.pattern = "alpha";
  editor.search(request);
  const SearchState before = editor.getSearchState();
  REQUIRE(before.status == SearchStatus::READY);
  REQUIRE(before.has_current_match);
  editor.setCursorPosition({0, 0});

  EditorActionResult update = updateComposition(editor, "x");
  const SearchState after = editor.getSearchState();
  CHECK_FALSE(update.text_changes.empty());
  CHECK(after.generation > before.generation);
  CHECK(after.status == SearchStatus::STALE);
  CHECK_FALSE(after.has_current_match);
  CHECK_FALSE(editor.canUndo());

  cancelActiveComposition(editor);
  editor.setSelection({{0, 0}, {0, 5}});
  updateComposition(editor, "omega");
  const SearchState affected = editor.getSearchState();
  CHECK(affected.status == SearchStatus::STALE);
  CHECK_FALSE(affected.has_current_match);
}

TEST_CASE("EditorCore undo and redo cancel active composition before moving history") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertText("a").text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  REQUIRE(editor.canRedo());
  updateComposition(editor, "x");
  REQUIRE(editor.hasComposition());

  EditorActionResult first_redo = editor.redo();
  CHECK(first_redo.handled);
  CHECK_FALSE(first_redo.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text().empty());
  CHECK(editor.canRedo());

  REQUIRE_FALSE(editor.redo().text_changes.empty());
  CHECK(document->getU8Text() == "a");

  updateComposition(editor, "x");
  REQUIRE(editor.hasComposition());

  EditorActionResult first_undo = editor.undo();
  CHECK(first_undo.handled);
  CHECK_FALSE(first_undo.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "a");
  CHECK(editor.canUndo());

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore marked-only composition does not block undo and redo history") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  REQUIRE_FALSE(commitText(editor, "x").text_changes.empty());
  REQUIRE(document->getU8Text() == "enaxbled");
  const uint64_t undo_session = commandSession(editor);
  REQUIRE(markDocumentRange(editor, {{0, 0}, {0, 8}}).handled);
  REQUIRE(editor.hasComposition());

  EditorActionResult undo = editor.undo();
  CHECK(undo.handled);
  CHECK_FALSE(undo.text_changes.empty());
  CHECK(undo.text_change_kind == TextChangeKind::UNDO);
  CHECK(undo.ime_host_action == ImeHostAction::NONE);
  CHECK(undo.ime_state.session_id == undo_session);
  CHECK(undo.ime_state.composition_range.start_utf16 == -1);
  CHECK(undo.ime_state.composition_range.end_utf16 == -1);
  CHECK(editor.getImeState(undo_session).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "enabled");
  CHECK(editor.canRedo());

  const uint64_t redo_session = commandSession(editor);
  REQUIRE(markDocumentRange(editor, {{0, 0}, {0, 7}}).handled);
  REQUIRE(editor.hasComposition());

  EditorActionResult redo = editor.redo();
  CHECK(redo.handled);
  CHECK_FALSE(redo.text_changes.empty());
  CHECK(redo.text_change_kind == TextChangeKind::REDO);
  CHECK(redo.ime_host_action == ImeHostAction::NONE);
  CHECK(redo.ime_state.session_id == redo_session);
  CHECK(redo.ime_state.composition_range.start_utf16 == -1);
  CHECK(redo.ime_state.composition_range.end_utf16 == -1);
  CHECK(editor.getImeState(redo_session).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "enaxbled");
}

TEST_CASE("EditorCore IME commit keeps an active command session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  EditorActionResult provisional = editor.applyImeCommands({session.session_id, {update}});
  REQUIRE(provisional.handled);
  CHECK(provisional.ime_host_action == ImeHostAction::NONE);
  CHECK(provisional.ime_state.session_id == session.session_id);
  REQUIRE(editor.hasComposition());

  ImeCommand commit;
  commit.kind = ImeCommandKind::COMMIT_TEXT;
  commit.text = "x";
  EditorActionResult result = editor.applyImeCommands({session.session_id, {commit}});

  CHECK(result.handled);
  CHECK(result.text_changes.empty());
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(result.ime_state.session_id == session.session_id);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "x");
}

TEST_CASE("EditorCore external text input keeps an active command session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  REQUIRE(editor.applyImeCommands({session.session_id, {update}}).handled);
  REQUIRE(editor.hasComposition());

  KeyEvent event;
  event.text = "y";
  EditorActionResult result = editor.handleKeyEvent(event);

  CHECK(result.handled);
  CHECK(result.source == EditorActionSource::KEYBOARD);
  CHECK_FALSE(result.text_changes.empty());
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(result.ime_state.session_id == session.session_id);
  CHECK(result.ime_state.composition_range.start_utf16 == -1);
  CHECK(result.ime_state.composition_range.end_utf16 == -1);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "xy");
}

TEST_CASE("EditorCore pointer relocation keeps an active command session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("boolean enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  const uint64_t session = commandSession(editor);
  REQUIRE(markDocumentRange(editor, {{0, 0}, {0, 7}}).handled);
  REQUIRE(editor.hasComposition());
  const CursorRect target = editor.getPositionScreenRect({0, 11});
  const float point[2] = {target.x + 1.0f, target.y + target.height * 0.5f};

  EditorActionResult result = editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point));

  CHECK(result.handled);
  CHECK(result.source == EditorActionSource::GESTURE);
  CHECK(result.composition_changed);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(result.ime_state.session_id == session);
  CHECK(result.ime_state.composition_range.start_utf16 == -1);
  CHECK(result.ime_state.composition_range.end_utf16 == -1);
  CHECK(editor.getImeState(session).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 11}));
  CHECK(document->getU8Text() == "boolean enabled");
}

TEST_CASE("EditorCore pointer relocation synchronizes an active text update session once") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("boolean enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext context =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  ImeTextUpdateStep marked;
  marked.old_text = context.text;
  const int64_t caret = context.selection.active_utf16;
  marked.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, caret, caret};
  marked.replacement_text = "X";
  marked.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, caret + 1, caret + 1,
                            CaretAffinity::DOWNSTREAM};
  marked.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, caret, caret + 1};
  const EditorActionResult composing =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {marked}});
  REQUIRE(composing.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(editor.hasComposition());
  const CursorRect target = editor.getPositionScreenRect({0, 12});
  const float point[2] = {target.x + 1.0f, target.y + target.height * 0.5f};

  const EditorActionResult result =
      editor.handleGestureEvent(GestureEvent::create(EventType::MOUSE_DOWN, 1, point));

  CHECK(result.handled);
  CHECK(result.source == EditorActionSource::GESTURE);
  CHECK(result.composition_changed);
  CHECK(result.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK(result.ime_state.session_id == session.session_id);
  CHECK(result.ime_state.state_revision == composing.ime_state.state_revision + 1);
  CHECK(result.ime_state.composition_range.start_utf16 == -1);
  CHECK(result.ime_state.composition_range.end_utf16 == -1);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 12}));
  CHECK(document->getU8Text() == "booXlean enabled");
}

TEST_CASE("EditorCore linked composition updates secondary targets immediately") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo} -> $0").text_changes.empty());
  REQUIRE(editor.isInLinkedEditing());

  EditorActionResult update = updateComposition(editor, "bar");
  CHECK_FALSE(update.text_changes.empty());
  CHECK(document->getU8Text() == "bar + bar -> ");

  EditorActionResult finish = finishActiveComposition(editor);
  CHECK(finish.text_changes.empty());
  CHECK(document->getU8Text() == "bar + bar -> ");
  CHECK(editor.isInLinkedEditing());

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo + foo -> ");
}

TEST_CASE("EditorCore linked composition keeps current coordinates when a secondary precedes primary") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("foo foo");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 4}, {0, 7}}, {{0, 0}, {0, 3}}}, "foo"});
  editor.startLinkedEditing(std::move(groups));
  REQUIRE(editor.isInLinkedEditing());

  EditorActionResult update = updateComposition(editor, "longName");
  REQUIRE(update.text_changes.size() == 2);
  CHECK(update.text_changes[0].range == TextRange{{0, 4}, {0, 7}});
  CHECK(update.text_changes[1].range == TextRange{{0, 0}, {0, 3}});
  CHECK(document->getU8Text() == "longName longName");
  REQUIRE(editor.getCompositionState().has_value());
  CHECK(editor.getCompositionState()->current_range == TextRange{{0, 9}, {0, 17}});
  CHECK(editor.getCursorPosition() == (TextPosition{0, 17}));

  CHECK(finishActiveComposition(editor).text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo foo");
}

TEST_CASE("EditorCore linked composition cancel restores all targets") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo}").text_changes.empty());
  updateComposition(editor, "bar");
  REQUIRE(document->getU8Text() == "bar + bar");

  REQUIRE_FALSE(cancelActiveComposition(editor).text_changes.empty());
  CHECK(document->getU8Text() == "foo + foo");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text().empty());
}

TEST_CASE("EditorCore linked composition mirrors deletion inside the active owner") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo}-${1:foo}").text_changes.empty());
  REQUIRE_FALSE(updateComposition(editor, "bars").text_changes.empty());
  REQUIRE(document->getU8Text() == "bars-bars");

  EditorActionResult deletion = deleteBackward(editor);

  REQUIRE_FALSE(deletion.text_changes.empty());
  CHECK(deletion.text_changes.size() == 2);
  CHECK(document->getU8Text() == "bar-bar");
  REQUIRE(editor.hasComposition());
  CHECK(editor.getCompositionState()->current_range == TextRange{{0, 0}, {0, 3}});
  CHECK(editor.getCursorPosition() == TextPosition{0, 3});
  CHECK(finishActiveComposition(editor).text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo-foo");
}

TEST_CASE("EditorCore linked composition remaps baselines after an external deletion") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo}XX${1:foo}").text_changes.empty());
  REQUIRE_FALSE(updateComposition(editor, "bar").text_changes.empty());
  REQUIRE(document->getU8Text() == "barXXbar");

  EditorActionResult deletion = deleteForward(editor);

  REQUIRE_FALSE(deletion.text_changes.empty());
  CHECK(document->getU8Text() == "barXbar");
  REQUIRE(editor.hasComposition());
  REQUIRE(editor.isInLinkedEditing());
  CHECK(finishActiveComposition(editor).text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "fooXfoo");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "fooXXfoo");
}

TEST_CASE("EditorCore linked zero-net finish restores each target line ending") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("A\r\nB|A\rB");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 0}, {1, 1}}, {{1, 2}, {2, 1}}}, "A\nB"});
  REQUIRE(editor.startLinkedEditing(std::move(groups)).handled);
  REQUIRE_FALSE(updateComposition(editor, "A\nB").text_changes.empty());
  REQUIRE(document->getU8Text() == "A\nB|A\nB");

  EditorActionResult finish = finishActiveComposition(editor);

  REQUIRE_FALSE(finish.text_changes.empty());
  CHECK(document->getU8Text() == "A\r\nB|A\rB");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore resolves linked composition before ending the linked session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo}").text_changes.empty());
  REQUIRE_FALSE(updateComposition(editor, "bar").text_changes.empty());
  EditorActionResult result = editor.cancelLinkedEditing();

  CHECK(result.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.isInLinkedEditing());
  CHECK(document->getU8Text() == "bar + bar");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo + foo");
}

TEST_CASE("EditorCore escape cancels linked composition before linked editing") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo}").text_changes.empty());
  REQUIRE_FALSE(updateComposition(editor, "bar").text_changes.empty());
  KeyEvent escape;
  escape.key_code = KeyCode::ESCAPE;

  EditorActionResult first = editor.handleKeyEvent(escape);
  REQUIRE_FALSE(first.text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.isInLinkedEditing());
  CHECK(document->getU8Text() == "foo + foo");

  EditorActionResult second = editor.handleKeyEvent(escape);
  CHECK(second.handled);
  CHECK_FALSE(editor.isInLinkedEditing());
}

TEST_CASE("EditorCore linked composition survives insertion at collapsed targets") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}-${1:i}").text_changes.empty());
  REQUIRE_FALSE(commitText(editor, "").text_changes.empty());
  REQUIRE(document->getU8Text() == "--");
  REQUIRE(editor.isInLinkedEditing());

  REQUIRE_FALSE(commitText(editor, "a").text_changes.empty());
  REQUIRE(document->getU8Text() == "a-a-a");
  REQUIRE(editor.isInLinkedEditing());

  REQUIRE(markDocumentRange(editor, {{0, 0}, {0, 1}}).handled);
  REQUIRE_FALSE(updateComposition(editor, "ab").text_changes.empty());
  REQUIRE(document->getU8Text() == "ab-ab-ab");

  EditorActionResult finish = finishActiveComposition(editor);
  CHECK(finish.text_changes.empty());
  CHECK(document->getU8Text() == "ab-ab-ab");
  CHECK(editor.isInLinkedEditing());
}

TEST_CASE("EditorCore idle IME commit mirrors linked placeholders atomically") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}-${1:i}").text_changes.empty());
  EditorActionResult commit = commitText(editor, "z");

  REQUIRE_FALSE(commit.text_changes.empty());
  CHECK(commit.text_changes.size() == 3);
  CHECK(document->getU8Text() == "z-z-z");
  CHECK(editor.isInLinkedEditing());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "i-i-i");
}

TEST_CASE("EditorCore idle IME commit continues linked editing after composition finish") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  REQUIRE_FALSE(updateComposition(editor, "z").text_changes.empty());
  CHECK(finishActiveComposition(editor).text_changes.empty());
  REQUIRE(document->getU8Text() == "z-z");

  EditorActionResult commit = commitText(editor, " ");

  REQUIRE_FALSE(commit.text_changes.empty());
  CHECK(commit.text_changes.size() == 2);
  CHECK(document->getU8Text() == "z -z ");
  CHECK(editor.isInLinkedEditing());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "z-z");
}

TEST_CASE("EditorCore idle IME delete mirrors linked placeholders") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  REQUIRE_FALSE(commitText(editor, "z").text_changes.empty());
  EditorActionResult deletion = deleteBackward(editor);

  REQUIRE_FALSE(deletion.text_changes.empty());
  CHECK(deletion.text_changes.size() == 2);
  CHECK(document->getU8Text() == "-");
  CHECK(editor.isInLinkedEditing());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "z-z");
}

TEST_CASE("EditorCore idle IME delete preserves input when leaving a linked placeholder") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  EditorActionResult deletion = deleteForward(editor, 2);

  REQUIRE_FALSE(deletion.text_changes.empty());
  CHECK(document->getU8Text() == "i");
  CHECK_FALSE(editor.isInLinkedEditing());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "i-i");
}

TEST_CASE("EditorCore text update syncs its buffer after mirroring linked placeholders") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  REQUIRE(context.text == "i-i");

  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
  step.replacement_text = "z";
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1, CaretAffinity::DOWNSTREAM};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  REQUIRE_FALSE(update.text_changes.empty());
  CHECK(update.text_changes.size() == 2);
  CHECK(update.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK(update.ime_state.session_id == session.session_id);
  CHECK(update.ime_state.state_revision == session.state_revision + 1);
  ImeTextContext synced =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synced.result_code == ImeResultCode::OK);
  CHECK(synced.text == "z-z");
  CHECK(document->getU8Text() == "z-z");
  CHECK(editor.isInLinkedEditing());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "i-i");
}

TEST_CASE("EditorCore text update keeps linked composition active while syncing its buffer") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);

  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
  step.replacement_text = "value";
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  step.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 5};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  REQUIRE(update.ime_state.result_code == ImeResultCode::OK);
  CHECK(update.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK(update.ime_state.session_id == session.session_id);
  CHECK(update.ime_state.composition_range.start_utf16 == 0);
  CHECK(update.ime_state.composition_range.end_utf16 == 5);
  CHECK(document->getU8Text() == "value-value");
  CHECK(editor.hasComposition());
  CHECK(editor.isInLinkedEditing());

  ImeTextContext synced =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synced.result_code == ImeResultCode::OK);
  CHECK(synced.text == "value-value");
  CHECK(synced.composition_range.start_utf16 == 0);
  CHECK(synced.composition_range.end_utf16 == 5);
}

TEST_CASE("EditorCore text update finishes linked composition with the final mirrored text") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}-${1:i}").text_changes.empty());
  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);

  ImeTextUpdateStep begin;
  begin.old_text = context.text;
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
  begin.replacement_text = "value";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 5};
  EditorActionResult update =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);

  ImeTextContext synced =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synced.result_code == ImeResultCode::OK);
  ImeTextUpdateStep finish;
  finish.old_text = synced.text;
  finish.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 5};
  finish.replacement_text = "final";
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {finish}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "final-final");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "i-i");
}

TEST_CASE("EditorCore text update remaps linked baselines around an external patch") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:i}XX${1:i}").text_changes.empty());
  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);

  ImeTextUpdateStep begin;
  begin.old_text = context.text;
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
  begin.replacement_text = "value";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 5};
  EditorActionResult update =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);

  ImeTextContext synced =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synced.result_code == ImeResultCode::OK);
  ImeTextUpdateStep external;
  external.old_text = synced.text;
  external.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 5, 6};
  external.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  external.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 5};
  EditorActionResult patched =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {external}});

  REQUIRE(patched.ime_state.result_code == ImeResultCode::OK);
  CHECK(document->getU8Text() == "valueXvalue");
  REQUIRE(editor.hasComposition());
  ImeTextUpdateStep finish;
  finish.old_text = "valueXvalue";
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, patched.ime_state.state_revision, {finish}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "iXi");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "iXXi");
}

TEST_CASE("EditorCore text update remaps a primary baseline after a preceding secondary") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("iXXi");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 3}, {0, 4}}, {{0, 0}, {0, 1}}}, "i"});
  REQUIRE(editor.startLinkedEditing(std::move(groups)).handled);
  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);

  ImeTextUpdateStep begin;
  begin.old_text = context.text;
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  begin.replacement_text = "value";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 8, 8, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 8};
  EditorActionResult update =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);

  ImeTextContext synced =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synced.result_code == ImeResultCode::OK);
  CHECK(synced.text == "valueXXvalue");
  CHECK(synced.composition_range.start_utf16 == 7);
  CHECK(synced.composition_range.end_utf16 == 12);

  ImeTextUpdateStep external;
  external.old_text = synced.text;
  external.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 5, 6};
  external.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 11, 11, CaretAffinity::DOWNSTREAM};
  external.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 6, 11};
  EditorActionResult patched =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {external}});
  REQUIRE(patched.ime_state.result_code == ImeResultCode::OK);
  CHECK(document->getU8Text() == "valueXvalue");

  ImeTextUpdateStep finish;
  finish.old_text = "valueXvalue";
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 11, 11, CaretAffinity::DOWNSTREAM};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, patched.ime_state.state_revision, {finish}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "iXi");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "iXXi");
}

TEST_CASE("EditorCore mixed surrounding delete keeps composition active and commits external changes") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abXYZcd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 2}, {0, 5}});

  updateComposition(editor, "pq");
  REQUIRE(document->getU8Text() == "abpqcd");

  EditorActionResult deletion = deleteSurrounding(editor, 3, 2);
  REQUIRE_FALSE(deletion.text_changes.empty());
  REQUIRE(deletion.text_changes.size() == 1);
  CHECK(deletion.text_changes[0].range == (TextRange{{0, 1}, {0, 6}}));
  CHECK(deletion.text_changes[0].old_text == "bpqcd");
  CHECK(editor.hasComposition());
  CHECK(document->getU8Text() == "a");

  EditorActionResult update = updateComposition(editor, "Q");
  CHECK_FALSE(update.text_changes.empty());
  CHECK(editor.hasComposition());
  CHECK(document->getU8Text() == "aQ");

  EditorActionResult finish = finishActiveComposition(editor);
  CHECK(finish.text_changes.empty());
  CHECK(document->getU8Text() == "aQ");

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "aXYZ");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abXYZcd");
}

TEST_CASE("EditorCore mixed surrounding delete cancel restores only composition-owned text") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abXYZcd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 2}, {0, 5}});

  updateComposition(editor, "pq");
  REQUIRE_FALSE(deleteSurrounding(editor, 3, 2).text_changes.empty());
  REQUIRE(editor.hasComposition());
  cancelActiveComposition(editor);

  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "aXYZ");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abXYZcd");
}

TEST_CASE("EditorCore mixed surrounding delete merges adjacent committed pieces") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  updateComposition(editor, "XY");
  EditorActionResult deletion = deleteSurrounding(editor, 3, 1);
  REQUIRE_FALSE(deletion.text_changes.empty());
  REQUIRE(deletion.text_changes.size() == 1);
  CHECK(deletion.text_changes[0].range == (TextRange{{0, 1}, {0, 5}}));
  CHECK(deletion.text_changes[0].old_text == "bXYc");
  CHECK(editor.hasComposition());
  CHECK(document->getU8Text() == "ad");

  updateComposition(editor, "Q");
  CHECK(finishActiveComposition(editor).text_changes.empty());
  CHECK(document->getU8Text() == "aQd");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "ad");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcd");
}

TEST_CASE("EditorCore rejects conflicting linked composition targets") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 0}, {0, 3}}, {{0, 2}, {0, 5}}}, "abc"});
  editor.startLinkedEditing(std::move(groups));
  CHECK_FALSE(editor.isInLinkedEditing());
  CHECK(document->getU8Text() == "abcdef");
}

TEST_CASE("EditorCore linked composition settles atomically when a committed edit hits a target") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo}").text_changes.empty());
  updateComposition(editor, "bar");
  REQUIRE_FALSE(deleteSurrounding(editor, 0, 4).text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.isInLinkedEditing());

  EditorActionResult finish = finishActiveComposition(editor);
  CHECK(finish.text_changes.empty());
  CHECK(document->getU8Text() == "barar");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo + foo");
}

TEST_CASE("EditorCore rejected active composition command leaves live state unchanged") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("alpha");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});
  REQUIRE_FALSE(editor.insertText("!").text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  REQUIRE(editor.canRedo());

  SearchRequest request;
  request.pattern = "alpha";
  editor.search(request);
  const SearchState search_before = editor.getSearchState();
  editor.setCursorPosition({0, 0});
  updateComposition(editor, "x");

  const U8String text_before = document->getU8Text();
  const TextPosition cursor_before = editor.getCursorPosition();
  const TextRange selection_before = editor.getSelection();
  const CaretAffinity affinity_before = editor.getCaretAffinity();
  const SearchState active_search_before = editor.getSearchState();

  EditorActionResult rejected = markDocumentRange(editor, {{0, 2}, {0, 3}});
  CHECK(rejected.handled);
  CHECK(document->getU8Text() == text_before);
  CHECK(editor.getCursorPosition() == cursor_before);
  CHECK(editor.getSelection() == selection_before);
  CHECK(editor.getCaretAffinity() == affinity_before);
  CHECK_FALSE(editor.getCompositionState().has_value());
  CHECK(editor.canUndo());
  CHECK_FALSE(editor.canRedo());
  const SearchState search_after = editor.getSearchState();
  CHECK(search_after.pattern == active_search_before.pattern);
  CHECK(search_after.generation == active_search_before.generation);
}

TEST_CASE("EditorCore adjusts persistent effects for an insertion composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  constexpr int32_t syntax_color = static_cast<int32_t>(0xFF123456u);
  editor.registerTextStyle(1, TextStyle{syntax_color, 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, {{0, 1, 1}, {4, 2, 1}});
  editor.setLineInlayHints(0, {{InlayType::TEXT, 2, 0, "hint"}});
  editor.setLinePhantomTexts(0, {{4, "ghost"}});
  editor.setLineLinks(0, {{4, 2, "doc://effect"}});
  editor.setLineDiagnostics(0, {{4, 2, DiagnosticSeverity::DIAG_ERROR}});
  editor.setLineDocumentHighlights(0, {{4, 2, DocumentHighlightKind::READ}});

  EditorRangeEffectStyles styles;
  styles.diagnostic_error.underline_color = static_cast<int32_t>(0xFFFF0000u);
  styles.diagnostic_error.underline_style = RangeEffectUnderlineStyle::WAVY;
  styles.document_highlight_read.background_color = static_cast<int32_t>(0x3300FF00u);
  editor.setEditorRangeEffectStyles(styles);

  editor.setCursorPosition({0, 2});
  updateComposition(editor, "XY");
  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun* inlay = nullptr;
  const VisualRun* phantom = nullptr;
  const VisualRun* link = nullptr;
  bool has_before_style = false;
  bool has_diagnostic = false;
  bool has_highlight = false;
  for (const VisualLine& line : model.lines) {
    for (const VisualRun& run : line.runs) {
      if (run.type == VisualRunType::INLAY_HINT) inlay = &run;
      if (run.type == VisualRunType::PHANTOM_TEXT) phantom = &run;
      if (run.type == VisualRunType::LINK) link = &run;
      has_before_style = has_before_style || (run.column == 0 && run.style.color == syntax_color);
    }
  }
  for (const RangeEffectRenderItem& effect : model.range_effects) {
    has_diagnostic = has_diagnostic || effect.kind == RangeEffectKind::DIAGNOSTIC_ERROR;
    has_highlight = has_highlight || effect.kind == RangeEffectKind::DOCUMENT_HIGHLIGHT_READ;
  }

  REQUIRE(inlay != nullptr);
  REQUIRE(phantom != nullptr);
  REQUIRE(link != nullptr);
  CHECK(inlay->column == 2);
  CHECK(phantom->column == 6);
  CHECK(link->column == 6);
  CHECK(link->style.color == syntax_color);
  CHECK(has_before_style);
  CHECK(editor.getLinkTargetAt(0, 6) == "doc://effect");
  CHECK(has_diagnostic);
  CHECK_FALSE(has_highlight);

  cancelActiveComposition(editor);
  model = {};
  editor.buildRenderModel(model);
  link = nullptr;
  for (const VisualLine& line : model.lines) {
    for (const VisualRun& run : line.runs) {
      if (run.type == VisualRunType::LINK) link = &run;
    }
  }
  REQUIRE(link != nullptr);
  CHECK(link->column == 4);
  CHECK(editor.getLinkTargetAt(0, 4) == "doc://effect");
}

TEST_CASE("EditorCore adjusts persistent effects intersecting composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({800, 600});

  editor.registerTextStyle(1, TextStyle{static_cast<int32_t>(0xFF123456u), 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, {{2, 2, 1}});
  editor.setLineInlayHints(0, {{InlayType::TEXT, 2, 0, "hint"}});
  editor.setLinePhantomTexts(0, {{2, "ghost"}});
  editor.setLineLinks(0, {{2, 2, "doc://hidden"}});
  editor.setLineDiagnostics(0, {{2, 2, DiagnosticSeverity::DIAG_ERROR}});
  editor.setLineDocumentHighlights(0, {{2, 2, DocumentHighlightKind::WRITE}});

  EditorRangeEffectStyles styles;
  styles.diagnostic_error.underline_color = static_cast<int32_t>(0xFFFF0000u);
  styles.diagnostic_error.underline_style = RangeEffectUnderlineStyle::WAVY;
  styles.document_highlight_write.background_color = static_cast<int32_t>(0x3300FF00u);
  editor.setEditorRangeEffectStyles(styles);

  editor.setSelection({{0, 2}, {0, 4}});
  markDocumentRange(editor, {{0, 2}, {0, 4}});
  REQUIRE(editor.getCompositionState().has_value());
  CHECK_FALSE(editor.getCompositionState()->text_change.has_value());
  EditorRenderModel marked_model;
  editor.buildRenderModel(marked_model);
  bool marked_link_visible = false;
  for (const VisualLine& line : marked_model.lines) {
    for (const VisualRun& run : line.runs) {
      marked_link_visible = marked_link_visible || run.type == VisualRunType::LINK;
    }
  }
  CHECK(marked_link_visible);
  CHECK(finishActiveComposition(editor).text_changes.empty());
  marked_model = {};
  editor.buildRenderModel(marked_model);
  bool zero_finish_restored_link = false;
  for (const VisualLine& line : marked_model.lines) {
    for (const VisualRun& run : line.runs) {
      zero_finish_restored_link = zero_finish_restored_link || run.type == VisualRunType::LINK;
    }
  }
  CHECK(zero_finish_restored_link);

  editor.setSelection({{0, 2}, {0, 4}});
  CHECK(updateComposition(editor, "cd").text_changes.empty());
  REQUIRE(editor.getCompositionState().has_value());
  REQUIRE(editor.getCompositionState()->text_change.has_value());
  marked_model = {};
  editor.buildRenderModel(marked_model);
  bool identity_owner_kept_link = false;
  for (const VisualLine& line : marked_model.lines) {
    for (const VisualRun& run : line.runs) {
      identity_owner_kept_link = identity_owner_kept_link || run.type == VisualRunType::LINK;
    }
  }
  CHECK(identity_owner_kept_link);
  CHECK(finishActiveComposition(editor).text_changes.empty());

  editor.setSelection({{0, 2}, {0, 4}});
  updateComposition(editor, "X");
  EditorRenderModel model;
  editor.buildRenderModel(model);

  for (const VisualLine& line : model.lines) {
    for (const VisualRun& run : line.runs) {
      CHECK(run.type != VisualRunType::LINK);
    }
  }
  for (const RangeEffectRenderItem& effect : model.range_effects) {
    CHECK(effect.kind != RangeEffectKind::DIAGNOSTIC_ERROR);
    CHECK(effect.kind != RangeEffectKind::DOCUMENT_HIGHLIGHT_WRITE);
  }
  CHECK(editor.getLinkTargetAt(0, 2).empty());

  cancelActiveComposition(editor);
  model = {};
  editor.buildRenderModel(model);
  bool restored_inlay = false;
  bool restored_phantom = false;
  bool restored_link = false;
  for (const VisualLine& line : model.lines) {
    for (const VisualRun& run : line.runs) {
      restored_inlay = restored_inlay || run.type == VisualRunType::INLAY_HINT;
      restored_phantom = restored_phantom || run.type == VisualRunType::PHANTOM_TEXT;
      restored_link = restored_link || run.type == VisualRunType::LINK;
    }
  }
  CHECK(restored_inlay);
  CHECK(restored_phantom);
  CHECK_FALSE(restored_link);
  CHECK(editor.getLinkTargetAt(0, 2).empty());
}

TEST_CASE("EditorCore adjusts persistent effects across provisional line changes") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("aa\nbb\ncc"));
  editor.setViewport({800, 600});
  editor.registerTextStyle(1, TextStyle{static_cast<int32_t>(0xFF123456u), 0, FONT_STYLE_NORMAL});
  editor.setLineSpans(2, SpanLayer::SEMANTIC, {{0, 2, 1}});
  editor.setLineInlayHints(2, {{InlayType::TEXT, 0, 0, "hint"}});
  editor.setLinePhantomTexts(2, {{0, "ghost"}});
  editor.setLineCodeLens(2, {{0, 42, "references"}});
  editor.setLineGutterIcons(2, {{7}});
  editor.setLineDiagnostics(2, {{0, 2, DiagnosticSeverity::DIAG_ERROR}});
  editor.setLineDocumentHighlights(2, {{0, 2, DocumentHighlightKind::READ}});

  EditorRangeEffectStyles styles;
  styles.diagnostic_error.underline_color = static_cast<int32_t>(0xFFFF0000u);
  styles.diagnostic_error.underline_style = RangeEffectUnderlineStyle::WAVY;
  styles.document_highlight_read.background_color = static_cast<int32_t>(0x3300FF00u);
  editor.setEditorRangeEffectStyles(styles);

  editor.setCursorPosition({0, 2});
  updateComposition(editor, "X\n");
  editor.setLineLinks(2, {{0, 2, "doc://multiline"}});
  EditorRenderModel model;
  editor.buildRenderModel(model);

  bool live_link = false;
  bool adjusted_inlay = false;
  bool adjusted_phantom = false;
  bool adjusted_codelens = false;
  bool adjusted_diagnostic = false;
  bool adjusted_highlight = false;
  for (const VisualLine& line : model.lines) {
    for (const VisualRun& run : line.runs) {
      live_link = live_link || (line.logical_line == 2 && run.type == VisualRunType::LINK && run.column == 0);
      adjusted_inlay =
          adjusted_inlay || (line.logical_line == 3 && run.type == VisualRunType::INLAY_HINT && run.column == 0);
      adjusted_phantom =
          adjusted_phantom || (line.logical_line == 3 && run.type == VisualRunType::PHANTOM_TEXT && run.column == 0);
      adjusted_codelens =
          adjusted_codelens || (line.logical_line == 3 && run.type == VisualRunType::CODELENS && run.icon_id == 42);
    }
  }
  for (const RangeEffectRenderItem& effect : model.range_effects) {
    adjusted_diagnostic = adjusted_diagnostic || effect.kind == RangeEffectKind::DIAGNOSTIC_ERROR;
    adjusted_highlight = adjusted_highlight || effect.kind == RangeEffectKind::DOCUMENT_HIGHLIGHT_READ;
  }
  const bool adjusted_gutter =
      std::any_of(model.gutter_icons.begin(), model.gutter_icons.end(), [](const GutterIconRenderItem& item) {
        return item.logical_line == 3 && item.icon_id == 7;
      });
  CHECK(live_link);
  CHECK(adjusted_inlay);
  CHECK(adjusted_phantom);
  CHECK(adjusted_codelens);
  CHECK(adjusted_gutter);
  CHECK(adjusted_diagnostic);
  CHECK_FALSE(adjusted_highlight);
  CHECK(editor.getLinkTargetAt(2, 0) == "doc://multiline");

  cancelActiveComposition(editor);
  CHECK(editor.getLinkTargetAt(1, 0) == "doc://multiline");
}

TEST_CASE("EditorCore keeps live guides during composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), options);
  editor.loadDocument(makeShared<LineArrayDocument>("a\nb\nc\nd"));
  editor.setViewport({800, 600});
  editor.setIndentGuides({{{0, 0}, {3, 0}}});

  EditorRenderModel model;
  editor.buildRenderModel(model);
  REQUIRE(model.guide_segments.size() == 1);

  editor.setSelection({{1, 0}, {1, 1}});
  updateComposition(editor, "X");
  model = {};
  editor.buildRenderModel(model);
  CHECK(model.guide_segments.size() == 1);

  cancelActiveComposition(editor);
  model = {};
  editor.buildRenderModel(model);
  CHECK(model.guide_segments.size() == 1);
}

TEST_CASE("EditorCore composition multiline edit adjusts persistent fold state") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a\nb\nc\nd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setFoldRegions({{1, 3, true}});
  REQUIRE_FALSE(editor.isLineVisible(2));
  editor.setCursorPosition({0, 1});

  updateComposition(editor, "x\n");
  CHECK(editor.hasComposition());
  const auto& updated_lines = document->getLogicalLines();
  REQUIRE(updated_lines.size() == 5);
  CHECK_FALSE(updated_lines[1].is_fold_hidden);
  CHECK_FALSE(updated_lines[2].is_fold_hidden);
  CHECK(updated_lines[3].is_fold_hidden);
  CHECK(updated_lines[4].is_fold_hidden);

  cancelActiveComposition(editor);
  const auto& restored_lines = document->getLogicalLines();
  REQUIRE(restored_lines.size() == 4);
  CHECK_FALSE(restored_lines[1].is_fold_hidden);
  CHECK(restored_lines[2].is_fold_hidden);
  CHECK(restored_lines[3].is_fold_hidden);
}

TEST_CASE("EditorCore read-only transition finishes active composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("a");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});
  const uint64_t session_id = commandSession(editor);
  updateComposition(editor, "x");

  EditorActionResult result = editor.setReadOnly(true);
  CHECK(result.text_changes.empty());
  CHECK(result.ime_host_action == ImeHostAction::CLOSE_SESSION);
  CHECK(result.ime_state.session_id == 0);
  CHECK_FALSE(editor.hasComposition());
  CHECK(editor.getImeState(session_id).result_code == ImeResultCode::SESSION_MISMATCH);
  CHECK(document->getU8Text() == "ax");
  CHECK(editor.canUndo());
}

TEST_CASE("EditorCore read-only transition closes an idle IME session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>("abc"));
  editor.setViewport({800, 600});
  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);

  const EditorActionResult result = editor.setReadOnly(true);

  CHECK(result.ime_host_action == ImeHostAction::CLOSE_SESSION);
  CHECK(result.ime_state.session_id == 0);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::SESSION_MISMATCH);
}

TEST_CASE("EditorCore IME selection remains independent from active composition") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});
  updateComposition(editor, "x");

  ImeCommand selection;
  selection.kind = ImeCommandKind::SET_SELECTION;
  selection.selection_after = {ImeCoordinateSpace::DOCUMENT, 0, 0, CaretAffinity::DOWNSTREAM};
  EditorActionResult result = applyCommand(editor, selection);

  CHECK(result.handled);
  CHECK(result.text_changes.empty());
  CHECK(editor.hasComposition());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 0}));
  CHECK(document->getU8Text() == "abx");
}

TEST_CASE("EditorCore composition cancel restores baseline caret affinity") {
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

  updateComposition(editor, "X");
  cancelActiveComposition(editor);

  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
  CHECK(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);
  CHECK(document->getU8Text() == "abcdefghij");
}

TEST_CASE("EditorCore command batch stages composition and commits one history entry") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 3}});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);

  ImeCommand begin;
  begin.kind = ImeCommandKind::BEGIN_COMPOSITION;
  begin.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 3};
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "XY";
  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;

  EditorActionResult result = editor.applyImeCommands({session.session_id, {begin, update, finish}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.text_changes.size() == 1);
  CHECK(document->getU8Text() == "aXYd");
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcd");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore document mark does not own provisional text") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcde");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 4}});

  REQUIRE(markDocumentRange(editor, 1, 4).handled);
  REQUIRE(editor.getCompositionState().has_value());
  CHECK_FALSE(editor.getCompositionState()->text_change.has_value());
  CHECK_FALSE(editor.canUndo());

  CHECK(finishActiveComposition(editor).text_changes.empty());
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abcde");
  CHECK_FALSE(editor.canUndo());

  REQUIRE(markDocumentRange(editor, 1, 4).handled);
  cancelActiveComposition(editor);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "abcde");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore document mark commit is one ordinary committed replacement") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcde");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 4}});

  REQUIRE(markDocumentRange(editor, 1, 4).handled);
  EditorActionResult result = commitText(editor, "123456", 1);

  REQUIRE_FALSE(result.text_changes.empty());
  REQUIRE(result.text_changes.size() == 1);
  CHECK(document->getU8Text() == "a123456e");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 7}));
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcde");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore can finish a document mark before a targeted commit") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcde");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);

  ImeCommand begin;
  begin.kind = ImeCommandKind::BEGIN_COMPOSITION;
  begin.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 4};
  REQUIRE(editor.applyImeCommands({session.session_id, {begin}}).handled);

  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  ImeCommand commit;
  commit.kind = ImeCommandKind::COMMIT_TEXT;
  commit.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 4};
  commit.text = "X";
  commit.selection_after = {ImeCoordinateSpace::DOCUMENT, 2, 2, CaretAffinity::DOWNSTREAM};
  EditorActionResult result = editor.applyImeCommands({session.session_id, {finish, commit}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "aXe");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
  CHECK_FALSE(editor.hasComposition());
}

TEST_CASE("EditorCore surrounding delete transforms an active document mark") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcde");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 4});

  REQUIRE(markDocumentRange(editor, 1, 4).handled);
  EditorActionResult deletion = deleteBackward(editor);

  REQUIRE_FALSE(deletion.text_changes.empty());
  CHECK(document->getU8Text() == "abce");
  REQUIRE(editor.getCompositionState().has_value());
  CHECK(editor.getCompositionState()->current_range == (TextRange{{0, 1}, {0, 3}}));
  CHECK_FALSE(editor.getCompositionState()->text_change.has_value());
  CHECK(finishActiveComposition(editor).text_changes.empty());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcde");
}

TEST_CASE("EditorCore idle composition update accepts a document target") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 3};
  update.text = "X";
  EditorActionResult result = editor.applyImeCommands({session.session_id, {update}});

  CHECK_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "aXd");
  REQUIRE(editor.hasComposition());
  REQUIRE(editor.getCompositionState()->text_change.has_value());
  CHECK(editor.getCompositionState()->text_change->old_text == "bc");
  ImeCommand cancel;
  cancel.kind = ImeCommandKind::CANCEL_COMPOSITION;
  editor.applyImeCommands({session.session_id, {cancel}});
  CHECK(document->getU8Text() == "abcd");
}

TEST_CASE("EditorCore reports same-range provisional composition text changes") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  REQUIRE(editor.applyImeCommands({session.session_id, {update}}).composition_changed);

  update.text = "y";
  EditorActionResult result = editor.applyImeCommands({session.session_id, {update}});

  CHECK_FALSE(result.text_changes.empty());
  CHECK_FALSE(result.composition_changed);
  CHECK(result.needs_redraw);
  CHECK(document->getU8Text() == "aby");
}

TEST_CASE("EditorCore command batch merges composition finish and idle commit") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab cd");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "X";
  REQUIRE_FALSE(editor.applyImeCommands({session.session_id, {update}}).text_changes.empty());

  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  ImeCommand commit;
  commit.kind = ImeCommandKind::COMMIT_TEXT;
  commit.target_range = {ImeCoordinateSpace::DOCUMENT, 4, 6};
  commit.text = "Y";
  EditorActionResult result = editor.applyImeCommands({session.session_id, {finish, commit}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.text_changes.size() == 1);
  CHECK(document->getU8Text() == "abX Y");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "ab cd");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore idle commit resolves selection against its post-state") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "hello";
  REQUIRE(editor.applyImeCommands({session.session_id, {update}}).handled);

  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  REQUIRE(editor.applyImeCommands({session.session_id, {finish}}).handled);
  REQUIRE_FALSE(editor.hasComposition());

  ImeCommand commit;
  commit.kind = ImeCommandKind::COMMIT_TEXT;
  commit.text = " ";
  commit.selection_after = {ImeCoordinateSpace::DOCUMENT, 6, 6, CaretAffinity::DOWNSTREAM};
  EditorActionResult result = editor.applyImeCommands({session.session_id, {commit}});

  REQUIRE(result.handled);
  CHECK(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getU8Text() == "hello ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 6}));
}

TEST_CASE("EditorCore idle commit maps selection through a multiline replacement") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand commit;
  commit.kind = ImeCommandKind::COMMIT_TEXT;
  commit.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 3};
  commit.text = "X\nYZ";
  commit.selection_after = {ImeCoordinateSpace::DOCUMENT, 6, 6, CaretAffinity::DOWNSTREAM};
  EditorActionResult result = editor.applyImeCommands({session.session_id, {commit}});

  REQUIRE(result.handled);
  CHECK(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getU8Text() == "aX\nYZdef");
  CHECK(editor.getCursorPosition() == (TextPosition{1, 3}));
}

TEST_CASE("EditorCore command batch merges mixed deletion and composition finish") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("012345");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 2}, {0, 4}});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "XY";
  REQUIRE_FALSE(editor.applyImeCommands({session.session_id, {update}}).text_changes.empty());

  ImeCommand deletion;
  deletion.kind = ImeCommandKind::DELETE_SURROUNDING;
  deletion.delete_before = 3;
  deletion.text_unit = ImeTextUnit::UNICODE_CODE_POINT;
  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  EditorActionResult result = editor.applyImeCommands({session.session_id, {deletion, finish}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.text_changes.size() == 1);
  CHECK(result.text_changes[0].old_text == "1XY");
  CHECK(document->getU8Text() == "045");
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "012345");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore rejected command batch leaves payload state unchanged") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "X";
  ImeCommand invalid_begin;
  invalid_begin.kind = ImeCommandKind::BEGIN_COMPOSITION;
  invalid_begin.target_range = {ImeCoordinateSpace::DOCUMENT, 0, 1};

  EditorActionResult result = editor.applyImeCommands({session.session_id, {update, invalid_begin}});

  CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == "abc");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore validates a single command before applying its text") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand accepted;
  accepted.kind = ImeCommandKind::UPDATE_COMPOSITION;
  accepted.text = "X";
  REQUIRE_FALSE(editor.applyImeCommands({session.session_id, {accepted}}).text_changes.empty());
  CHECK(document->getU8Text() == "abcX");

  ImeCommand rejected = accepted;
  rejected.text = "Y";
  rejected.selection_after = {ImeCoordinateSpace::DOCUMENT, 99, 99, CaretAffinity::DOWNSTREAM};
  EditorActionResult result = editor.applyImeCommands({session.session_id, {rejected}});

  CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == "abcX");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abc");
}

TEST_CASE("EditorCore text update session validates revision old text and contexts") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  REQUIRE(session.state_revision == 1);
  ImeTextContext initial = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(initial.result_code == ImeResultCode::OK);
  CHECK(initial.text == "ab");

  ImeTextUpdateStep step;
  step.old_text = "ab";
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 2, 2};
  step.replacement_text = "x";
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3, CaretAffinity::DOWNSTREAM};
  step.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 2, 3};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  CHECK_FALSE(update.text_changes.empty());
  CHECK(document->getU8Text() == "abx");
  REQUIRE(editor.hasComposition());
  CHECK(update.ime_state.state_revision == 2);
  CHECK(editor.getImeContext(session.session_id, ImeTextSource::EDITING, 0, -1).text == "abx");
  CHECK(editor.getImeContext(session.session_id, ImeTextSource::COMMITTED, 0, -1).text == "ab");

  ImeTextUpdateStep invalid = step;
  invalid.old_text = "stale";
  EditorActionResult rejected = editor.applyImeTextUpdates({session.session_id, 2, {invalid}});
  CHECK(rejected.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(rejected.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == "abx");
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore text update buffer prefers the current line") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  const U8String previous_line(300, 'p');
  const U8String current_line(100, 'c');
  const U8String next_line(300, 'n');
  editor.loadDocument(makeShared<LineArrayDocument>(previous_line + "\n" + current_line + "\n" + next_line));
  editor.setViewport({800, 600});
  editor.setCursorPosition({1, 50});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);

  REQUIRE(context.result_code == ImeResultCode::OK);
  CHECK(StrUtil::utf16Length(context.text) == 356);
  CHECK(context.selection.anchor_utf16 == 178);
  CHECK(context.selection.active_utf16 == 178);
}

TEST_CASE("EditorCore text update buffer caps long line context") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>(U8String(2000, 'a')));
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1000});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);

  REQUIRE(context.result_code == ImeResultCode::OK);
  CHECK(StrUtil::utf16Length(context.text) == 768);
  CHECK(context.selection.anchor_utf16 == 537);
  CHECK(context.selection.active_utf16 == 537);
}

TEST_CASE("EditorCore text update session synchronizes a Core selection change in place") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>(U8String(1000, 'a') + U8String(1000, 'b')));
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 100});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext before =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(before.result_code == ImeResultCode::OK);
  CHECK(before.text.find('b') == U8String::npos);

  const EditorActionResult moved = editor.setCursorPosition({0, 1900});

  CHECK(moved.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK(moved.ime_state.session_id == session.session_id);
  CHECK(moved.ime_state.state_revision == session.state_revision + 1);
  const ImeTextContext after =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(after.result_code == ImeResultCode::OK);
  CHECK(after.text.find('a') == U8String::npos);
  CHECK(after.selection.anchor_utf16 == after.selection.active_utf16);

  const EditorActionResult unchanged = editor.setCursorPosition({0, 1900});
  CHECK(unchanged.ime_host_action == ImeHostAction::NONE);
  CHECK(unchanged.ime_state.session_id == session.session_id);
  CHECK(unchanged.ime_state.state_revision == moved.ime_state.state_revision);
}

TEST_CASE("EditorCore text update session ignores an external edit outside its visible buffer") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>(U8String(2000, 'a'));
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 100});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext before =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(before.result_code == ImeResultCode::OK);

  Vector<TextEdit> edits;
  edits.push_back({{{0, 100}, {0, 100}}, ""});
  edits.push_back({{{0, 1500}, {0, 1501}}, "b"});
  const EditorActionResult changed = editor.applyTextEdits(std::move(edits));

  CHECK(changed.ime_host_action == ImeHostAction::NONE);
  CHECK(changed.ime_state.session_id == session.session_id);
  CHECK(changed.ime_state.state_revision == session.state_revision);
  const ImeTextContext after =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(after.result_code == ImeResultCode::OK);
  CHECK(after.text == before.text);
  CHECK(after.selection == before.selection);
  CHECK(after.composition_range == before.composition_range);
  CHECK(document->getU8Text()[1500] == 'b');
}

TEST_CASE("EditorCore text update session finishes composition and synchronizes a Core selection change") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext context =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  const int64_t caret = context.selection.active_utf16;
  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, caret, caret};
  step.replacement_text = "X";
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, caret + 1, caret + 1,
                          CaretAffinity::DOWNSTREAM};
  step.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, caret, caret + 1};
  const EditorActionResult composing =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});
  REQUIRE(composing.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(editor.hasComposition());

  const EditorActionResult moved = editor.setCursorPosition({0, 0});

  CHECK(moved.ime_host_action == ImeHostAction::SYNC_EDITING_STATE);
  CHECK(moved.ime_state.session_id == session.session_id);
  CHECK(moved.ime_state.state_revision == composing.ime_state.state_revision + 1);
  CHECK(moved.ime_state.composition_range.start_utf16 == -1);
  CHECK(moved.ime_state.composition_range.end_utf16 == -1);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "aXbc");
  const ImeTextContext synchronized =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(synchronized.result_code == ImeResultCode::OK);
  CHECK(synchronized.text == "aXbc");
  CHECK(synchronized.selection.anchor_utf16 == 0);
  CHECK(synchronized.selection.active_utf16 == 0);
  CHECK(synchronized.composition_range.start_utf16 == -1);
  CHECK(synchronized.composition_range.end_utf16 == -1);
}

TEST_CASE("EditorCore command session keeps its selection synchronization behavior") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  const ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "X";
  const EditorActionResult composing = editor.applyImeCommands({session.session_id, {update}});
  REQUIRE(composing.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(editor.hasComposition());

  const EditorActionResult moved = editor.setCursorPosition({0, 0});

  CHECK(moved.ime_host_action == ImeHostAction::NONE);
  CHECK(moved.ime_state.session_id == session.session_id);
  CHECK(moved.ime_state.state_revision == 0);
  CHECK(moved.ime_state.composition_range.start_utf16 == -1);
  CHECK(moved.ime_state.composition_range.end_utf16 == -1);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "aXbc");
}

TEST_CASE("EditorCore text update buffer supports deletion across a line boundary") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  const U8String previous_line(300, 'p');
  const U8String current_line(100, 'c');
  const U8String next_line(300, 'n');
  SharedPtr<Document> document =
      makeShared<LineArrayDocument>(previous_line + "\n" + current_line + "\n" + next_line);
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({1, 0});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  REQUIRE(context.selection.active_utf16 > 0);

  const int64_t caret = context.selection.active_utf16;
  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, caret - 1, caret};
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, caret - 1, caret - 1,
                          CaretAffinity::DOWNSTREAM};
  EditorActionResult result = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getLineCount() == 2);
  CHECK(document->getLineColumns(0) == 400);
}

TEST_CASE("EditorCore text update buffer limits exceptional selections") {
  const U8String text(10000, 'a');

  EditorCore accepted(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  accepted.loadDocument(makeShared<LineArrayDocument>(text));
  accepted.setViewport({800, 600});
  accepted.setSelection({{0, 0}, {0, 8128}});
  ImeState accepted_session = accepted.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(accepted_session.result_code == ImeResultCode::OK);
  ImeTextContext accepted_context =
      accepted.getImeContext(accepted_session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(accepted_context.result_code == ImeResultCode::OK);
  CHECK(StrUtil::utf16Length(accepted_context.text) == 8192);

  EditorCore rejected(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  rejected.loadDocument(makeShared<LineArrayDocument>(text));
  rejected.setViewport({800, 600});
  rejected.setSelection({{0, 0}, {0, 8129}});
  CHECK(rejected.beginImeSession(ImeMutationModel::TEXT_UPDATE).result_code == ImeResultCode::REJECTED);
}

TEST_CASE("EditorCore text update session restarts when a Core selection cannot fit a new buffer") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>(U8String(10000, 'a')));
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 100});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);

  const EditorActionResult selected = editor.setSelection({{0, 0}, {0, 9000}});

  CHECK(selected.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(selected.ime_state.result_code == ImeResultCode::OK);
  CHECK(selected.ime_state.session_id == 0);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::SESSION_MISMATCH);
}

TEST_CASE("EditorCore text update buffer keeps the line context threshold exact") {
  const auto buffer_length = [](size_t selection_length) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    editor.loadDocument(makeShared<LineArrayDocument>(U8String(3000, 'a')));
    editor.setViewport({800, 600});
    editor.setSelection({{0, 800}, {0, static_cast<uint32_t>(800 + selection_length)}});
    const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    const ImeTextContext context =
        editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
    REQUIRE(context.result_code == ImeResultCode::OK);
    return StrUtil::utf16Length(context.text);
  };

  CHECK(buffer_length(511) == 768);
  CHECK(buffer_length(512) == 768);
  CHECK(buffer_length(513) == 769);
}

TEST_CASE("EditorCore text update buffer handles short and empty lines at document boundaries") {
  const auto buffer_length = [](const U8String& text, const TextPosition& caret) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    editor.loadDocument(makeShared<LineArrayDocument>(text));
    editor.setViewport({800, 600});
    editor.setCursorPosition(caret);
    const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    const ImeTextContext context =
        editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
    REQUIRE(context.result_code == ImeResultCode::OK);
    return StrUtil::utf16Length(context.text);
  };

  CHECK(buffer_length("short\n" + U8String(300, 'n'), {0, 2}) == 133);
  CHECK(buffer_length(U8String(300, 'p') + "\nshort", {1, 2}) == 133);
  CHECK(buffer_length(U8String(300, 'p') + "\n\n" + U8String(300, 'n'), {1, 0}) == 256);
}

TEST_CASE("EditorCore text update buffer deletes a CRLF line ending forward") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc\r\ndef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext context =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  CHECK(context.text == "abc\ndef");
  REQUIRE(context.selection.active_utf16 == 3);

  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3, CaretAffinity::DOWNSTREAM};
  const EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getU8Text() == "abcdef");
}

TEST_CASE("EditorCore text update buffer keeps scalar boundaries for both document implementations") {
  U16String text(2000, u'a');
  text[462] = static_cast<char16_t>(0xD83D);
  text[463] = static_cast<char16_t>(0xDE00);
  text[1230] = static_cast<char16_t>(0xD83D);
  text[1231] = static_cast<char16_t>(0xDE00);

  const auto verify = [](const SharedPtr<Document>& document) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCursorPosition({0, 1000});
    const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    const ImeTextContext context =
        editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
    REQUIRE(context.result_code == ImeResultCode::OK);
    CHECK(StrUtil::utf16Length(context.text) == 766);
    CHECK(context.selection.anchor_utf16 == 536);
    CHECK(context.selection.active_utf16 == 536);
  };

  SECTION("LineArrayDocument") {
    verify(makeShared<LineArrayDocument>(text));
  }
  SECTION("PieceTableDocument") {
    verify(makeShared<PieceTableDocument>(text));
  }
}

TEST_CASE("EditorCore text update buffer limits selections with hidden text on both sides") {
  const U8String text(10000, 'a');

  EditorCore accepted(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  accepted.loadDocument(makeShared<LineArrayDocument>(text));
  accepted.setViewport({800, 600});
  accepted.setSelection({{0, 1000}, {0, 9064}});
  const ImeState accepted_session = accepted.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(accepted_session.result_code == ImeResultCode::OK);
  const ImeTextContext accepted_context =
      accepted.getImeContext(accepted_session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(accepted_context.result_code == ImeResultCode::OK);
  CHECK(StrUtil::utf16Length(accepted_context.text) == 8192);

  EditorCore rejected(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  rejected.loadDocument(makeShared<LineArrayDocument>(text));
  rejected.setViewport({800, 600});
  rejected.setSelection({{0, 1000}, {0, 9065}});
  CHECK(rejected.beginImeSession(ImeMutationModel::TEXT_UPDATE).result_code == ImeResultCode::REJECTED);
}

TEST_CASE("EditorCore text update guard checks patch selection and composition thresholds") {
  const auto apply = [](int64_t patch_offset, int64_t selection_offset, ImeOffsetRange composition) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    editor.loadDocument(makeShared<LineArrayDocument>(U8String(2000, 'a')));
    editor.setViewport({800, 600});
    editor.setCursorPosition({0, 1000});
    const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    const ImeTextContext context =
        editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
    REQUIRE(context.result_code == ImeResultCode::OK);

    ImeTextUpdateStep step;
    step.old_text = context.text;
    if (patch_offset >= 0) {
      step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, patch_offset, patch_offset};
      step.replacement_text = "x";
    }
    step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, selection_offset, selection_offset,
                            CaretAffinity::DOWNSTREAM};
    step.composition_after = composition;
    return editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}}).ime_host_action;
  };

  const ImeOffsetRange none;
  CHECK(apply(63, 64, none) == ImeHostAction::RESTART_SESSION);
  CHECK(apply(64, 65, none) == ImeHostAction::RESTART_SESSION);
  CHECK(apply(65, 66, none) == ImeHostAction::NONE);
  CHECK(apply(703, 704, none) == ImeHostAction::NONE);
  CHECK(apply(704, 705, none) == ImeHostAction::RESTART_SESSION);
  CHECK(apply(705, 706, none) == ImeHostAction::RESTART_SESSION);

  CHECK(apply(-1, 64, none) == ImeHostAction::RESTART_SESSION);
  CHECK(apply(-1, 65, none) == ImeHostAction::NONE);
  CHECK(apply(-1, 703, none) == ImeHostAction::NONE);
  CHECK(apply(-1, 704, none) == ImeHostAction::RESTART_SESSION);

  const ImeSelection untouched{ImeCoordinateSpace::EDITING_BUFFER, 537, 537, CaretAffinity::DOWNSTREAM};
  CHECK(apply(-1, untouched.active_utf16, {ImeCoordinateSpace::EDITING_BUFFER, 64, 65})
        == ImeHostAction::RESTART_SESSION);
  CHECK(apply(-1, untouched.active_utf16, {ImeCoordinateSpace::EDITING_BUFFER, 65, 66})
        == ImeHostAction::NONE);
  CHECK(apply(-1, untouched.active_utf16, {ImeCoordinateSpace::EDITING_BUFFER, 702, 703})
        == ImeHostAction::NONE);
  CHECK(apply(-1, untouched.active_utf16, {ImeCoordinateSpace::EDITING_BUFFER, 703, 704})
        == ImeHostAction::RESTART_SESSION);
}

TEST_CASE("EditorCore text update rejects post-state offsets inside a surrogate pair") {
  const U8String text = "A\xF0\x9F\x98\x80"
                        "B";
  const auto apply = [&](bool invalid_selection) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    SharedPtr<Document> document = makeShared<LineArrayDocument>(text);
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCursorPosition({0, 4});
    const ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    const ImeTextContext context =
        editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
    REQUIRE(context.result_code == ImeResultCode::OK);

    ImeTextUpdateStep step;
    step.old_text = context.text;
    step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
    step.replacement_text = "Z";
    step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, invalid_selection ? 2 : 4,
                            invalid_selection ? 2 : 4, CaretAffinity::DOWNSTREAM};
    if (!invalid_selection) {
      step.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 2};
    }
    const EditorActionResult result =
        editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});
    CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
    CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
    CHECK(result.text_changes.empty());
    CHECK(document->getU8Text() == text);
  };

  SECTION("selection") {
    apply(true);
  }
  SECTION("composition") {
    apply(false);
  }
}

TEST_CASE("EditorCore committed context maps text after a changed composition length") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>("abcdef"));
  editor.setViewport({800, 600});
  editor.setSelection({{0, 1}, {0, 3}});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand begin;
  begin.kind = ImeCommandKind::BEGIN_COMPOSITION;
  begin.target_range = {ImeCoordinateSpace::DOCUMENT, 1, 3};
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "XYZ";
  REQUIRE_FALSE(editor.applyImeCommands({session.session_id, {begin, update}}).text_changes.empty());

  ImeTextContext full = editor.getImeContext(session.session_id, ImeTextSource::COMMITTED, 0, -1);
  REQUIRE(full.result_code == ImeResultCode::OK);
  CHECK(full.text == "adef");
  CHECK(full.composition_range.start_utf16 == -1);
  CHECK(full.composition_range.end_utf16 == -1);
  ImeTextContext suffix = editor.getImeContext(session.session_id, ImeTextSource::COMMITTED, 1, 3);
  REQUIRE(suffix.result_code == ImeResultCode::OK);
  CHECK(suffix.text == "def");
}

TEST_CASE("EditorCore editing context reports selection relative to a nonzero slice") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>(U8String(10000, 'a')));
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7000});

  const ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  const ImeTextContext context =
      editor.getImeContext(session.session_id, ImeTextSource::EDITING, 6500, 1000);

  REQUIRE(context.result_code == ImeResultCode::OK);
  CHECK(context.slice_start_utf16 == 6500);
  CHECK(context.text.size() == 1000);
  CHECK(context.selection.coordinate_space == ImeCoordinateSpace::CONTEXT_SLICE);
  CHECK(context.selection.anchor_utf16 == 500);
  CHECK(context.selection.active_utf16 == 500);
}

TEST_CASE("EditorCore text update batch commits chained steps atomically") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep first;
  first.old_text = "abc";
  first.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
  first.replacement_text = "x";
  first.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep second;
  second.old_text = "abcx";
  second.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4};
  second.replacement_text = "y";
  second.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};

  EditorActionResult result = editor.applyImeTextUpdates({session.session_id, session.state_revision, {first, second}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(result.text_changes.size() == 1);
  CHECK(result.ime_state.state_revision == 2);
  CHECK(document->getU8Text() == "abcxy");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore text update finishes a composition after a subrange patch") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep begin;
  begin.old_text = "abc";
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
  begin.replacement_text = "xy";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 5};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep finish;
  finish.old_text = "abcxy";
  finish.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 4, 5};
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {finish}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "abcx");
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore text update deletes an entire composition and finishes without restart") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep begin;
  begin.old_text = "abc";
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
  begin.replacement_text = "x";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep finish;
  finish.old_text = "abcx";
  finish.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3, CaretAffinity::DOWNSTREAM};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {finish}});

  CHECK(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(result.ime_state.session_id == session.session_id);
  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.hasComposition());
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore text update keeps external committed edits outside composition") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep begin;
  begin.old_text = "abcdef";
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
  begin.replacement_text = "X";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep external;
  external.old_text = "abcXdef";
  external.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7};
  external.replacement_text = "Y";
  external.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  external.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {external}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "abcXdefY");
  CHECK(editor.hasComposition());
  CHECK(editor.canUndo());
  CHECK_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcdefY");
  CHECK(editor.canUndo());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abcdef");
}

TEST_CASE("EditorCore text update uses after composition to own a boundary insertion") {
  const auto run_case = [](bool include_in_composition) {
    EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
    SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
    editor.loadDocument(document);
    editor.setViewport({800, 600});
    editor.setCursorPosition({0, 3});

    ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
    REQUIRE(session.result_code == ImeResultCode::OK);
    ImeTextUpdateStep begin;
    begin.old_text = "abcdef";
    begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
    begin.replacement_text = "X";
    begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
    begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
    EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
    REQUIRE(update.ime_state.state_revision == 2);

    ImeTextUpdateStep boundary;
    boundary.old_text = "abcXdef";
    boundary.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4};
    boundary.replacement_text = "Y";
    boundary.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 5, 5, CaretAffinity::DOWNSTREAM};
    boundary.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, include_in_composition ? 5 : 4};
    EditorActionResult result =
        editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {boundary}});

    CHECK(document->getU8Text() == "abcXYdef");
    CHECK_FALSE(result.text_changes.empty());
    CHECK_FALSE(editor.undo().text_changes.empty());
    CHECK(document->getU8Text() == (include_in_composition ? "abcdef" : "abcYdef"));
    if (!include_in_composition) {
      REQUIRE_FALSE(editor.undo().text_changes.empty());
      CHECK(document->getU8Text() == "abcdef");
    }
  };

  run_case(false);
  run_case(true);
}

TEST_CASE("EditorCore text update rollover finishes the old owner and starts the new one") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("ab");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep first;
  first.old_text = "ab";
  first.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1};
  first.replacement_text = "X";
  first.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 2, 2, CaretAffinity::DOWNSTREAM};
  first.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 2};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {first}});
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep rollover;
  rollover.old_text = "aXb";
  rollover.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3};
  rollover.replacement_text = "Y";
  rollover.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  rollover.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 4};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {rollover}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "aXbY");
  REQUIRE(editor.hasComposition());
  REQUIRE(editor.getCompositionState()->text_change.has_value());
  CHECK(editor.getCompositionState()->text_change->old_text.empty());
  CHECK_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "aXb");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "ab");
}

TEST_CASE("EditorCore text update accepts marked-only candidate reacquire batch") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep mark;
  mark.old_text = "enabled";
  mark.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3, CaretAffinity::DOWNSTREAM};
  mark.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult marked =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {mark}});
  REQUIRE(marked.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(editor.hasComposition());
  CHECK_FALSE(editor.getCompositionState()->text_change.has_value());

  ImeTextUpdateStep clear_and_select;
  clear_and_select.old_text = "enabled";
  clear_and_select.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 5, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep clear_and_collapse;
  clear_and_collapse.old_text = "enabled";
  clear_and_collapse.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep replace_and_reacquire;
  replace_and_reacquire.old_text = "enabled";
  replace_and_reacquire.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  replace_and_reacquire.replacement_text = "enables";
  replace_and_reacquire.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  replace_and_reacquire.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult replaced =
      editor.applyImeTextUpdates({session.session_id, marked.ime_state.state_revision,
                                  {clear_and_select, clear_and_collapse, replace_and_reacquire}});

  REQUIRE(replaced.ime_state.result_code == ImeResultCode::OK);
  CHECK(replaced.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getU8Text() == "enables");
  REQUIRE(editor.hasComposition());
  REQUIRE(editor.getCompositionState()->text_change.has_value());
  CHECK(editor.getCompositionState()->text_change->old_text == "enabled");

  ImeTextUpdateStep deletion;
  deletion.old_text = "enables";
  deletion.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 6, 7};
  deletion.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 6, 6, CaretAffinity::DOWNSTREAM};
  deletion.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 6};
  EditorActionResult deleted =
      editor.applyImeTextUpdates({session.session_id, replaced.ime_state.state_revision, {deletion}});

  REQUIRE(deleted.ime_state.result_code == ImeResultCode::OK);
  CHECK(document->getU8Text() == "enable");
  REQUIRE(editor.hasComposition());
  CHECK(editor.getCompositionState()->current_range == TextRange{{0, 0}, {0, 6}});
}

TEST_CASE("EditorCore text update commits a deletion before marking surviving document text") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc x");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 5});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep deletion;
  deletion.old_text = "abc x";
  deletion.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 4, 5};
  deletion.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep mark;
  mark.old_text = "abc ";
  mark.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  mark.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 3};

  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {deletion, mark}});

  REQUIRE(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::NONE);
  CHECK(document->getU8Text() == "abc ");
  REQUIRE(editor.hasComposition());
  CHECK(editor.getCompositionState()->current_range == TextRange{{0, 0}, {0, 3}});
  CHECK_FALSE(editor.getCompositionState()->text_change.has_value());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abc x");
  CHECK_FALSE(editor.hasComposition());
}

TEST_CASE("EditorCore text update acquires an entire document mark from a minimal replacement") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 3});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep mark;
  mark.old_text = "enabled";
  mark.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 3, 3, CaretAffinity::DOWNSTREAM};
  mark.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult marked =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {mark}});
  REQUIRE(marked.ime_state.result_code == ImeResultCode::OK);

  ImeTextUpdateStep replacement;
  replacement.old_text = "enabled";
  replacement.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 6, 7};
  replacement.replacement_text = "s";
  replacement.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  replacement.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult replaced =
      editor.applyImeTextUpdates({session.session_id, marked.ime_state.state_revision, {replacement}});

  REQUIRE(replaced.ime_state.result_code == ImeResultCode::OK);
  CHECK(document->getU8Text() == "enables");
  REQUIRE(editor.getCompositionState()->text_change.has_value());
  CHECK(editor.getCompositionState()->text_change->range == TextRange{{0, 0}, {0, 7}});
  CHECK(editor.getCompositionState()->text_change->old_text == "enabled");
  CHECK(editor.getCompositionState()->text_change->new_text == "enables");

  ImeTextUpdateStep finish;
  finish.old_text = "enables";
  finish.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  EditorActionResult committed =
      editor.applyImeTextUpdates({session.session_id, replaced.ime_state.state_revision, {finish}});

  REQUIRE(committed.ime_state.result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
  CHECK(document->getU8Text() == "enables");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "enabled");
}

TEST_CASE("EditorCore text update rejects candidate reacquire for an owned composition") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("enabled");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 7});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep begin;
  begin.old_text = "enabled";
  begin.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  begin.replacement_text = "enables";
  begin.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  begin.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult update =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {begin}});
  REQUIRE(update.ime_state.result_code == ImeResultCode::OK);
  REQUIRE(editor.getCompositionState()->text_change.has_value());

  ImeTextUpdateStep clear;
  clear.old_text = "enables";
  clear.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep remain_idle = clear;
  ImeTextUpdateStep reacquire;
  reacquire.old_text = "enables";
  reacquire.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  reacquire.replacement_text = "enabled";
  reacquire.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 7, 7, CaretAffinity::DOWNSTREAM};
  reacquire.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 7};
  EditorActionResult rejected =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision,
                                  {clear, remain_idle, reacquire}});

  CHECK(rejected.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(rejected.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == "enables");
  CHECK_FALSE(editor.hasComposition());
}

TEST_CASE("EditorCore text update rejects ambiguous composition ownership") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 1});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep first;
  first.old_text = "abc";
  first.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1};
  first.replacement_text = "X";
  first.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 2, 2, CaretAffinity::DOWNSTREAM};
  first.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 2};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {first}});
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep ambiguous;
  ambiguous.old_text = "aXbc";
  ambiguous.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 2, 2, CaretAffinity::DOWNSTREAM};
  ambiguous.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 3};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {ambiguous}});

  CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == "aXbc");
  CHECK_FALSE(editor.hasComposition());
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "abc");
}

TEST_CASE("EditorCore text update splits a cross-boundary deletion") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("012345");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setSelection({{0, 2}, {0, 4}});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep first;
  first.old_text = "012345";
  first.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 2, 4};
  first.replacement_text = "XY";
  first.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 4, 4, CaretAffinity::DOWNSTREAM};
  first.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 2, 4};
  EditorActionResult update = editor.applyImeTextUpdates({session.session_id, session.state_revision, {first}});
  REQUIRE(update.ime_state.state_revision == 2);

  ImeTextUpdateStep deletion;
  deletion.old_text = "01XY45";
  deletion.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 1, 3};
  deletion.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1, CaretAffinity::DOWNSTREAM};
  deletion.composition_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 2};
  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, update.ime_state.state_revision, {deletion}});

  REQUIRE_FALSE(result.text_changes.empty());
  CHECK(document->getU8Text() == "0Y45");
  REQUIRE(editor.hasComposition());
  CHECK_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "02345");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "012345");
}

TEST_CASE("EditorCore text update preserves patch identity for repeated text") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("aa");
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 0});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextUpdateStep step;
  step.old_text = "aa";
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 1};
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 0, 0, CaretAffinity::DOWNSTREAM};

  EditorActionResult result = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  REQUIRE_FALSE(result.text_changes.empty());
  REQUIRE(result.text_changes.size() == 1);
  CHECK(result.text_changes[0].range == (TextRange{{0, 0}, {0, 1}}));
  CHECK(document->getU8Text() == "a");
  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "aa");
}

TEST_CASE("EditorCore text update guard remains atomic after a later invalid step") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  const U8String original(4000, 'a');
  SharedPtr<Document> document = makeShared<LineArrayDocument>(original);
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2000});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  ImeTextUpdateStep first;
  first.old_text = context.text;
  first.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 0};
  first.replacement_text = "x";
  first.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1, CaretAffinity::DOWNSTREAM};
  ImeTextUpdateStep invalid = first;
  invalid.old_text = "invalid";

  EditorActionResult result =
      editor.applyImeTextUpdates({session.session_id, session.state_revision, {first, invalid}});

  CHECK(result.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(document->getU8Text() == original);
  CHECK_FALSE(editor.canUndo());
}

TEST_CASE("EditorCore accepts a guard update before restarting the session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  const U8String original(4000, 'a');
  SharedPtr<Document> document = makeShared<LineArrayDocument>(original);
  editor.loadDocument(document);
  editor.setViewport({800, 600});
  editor.setCursorPosition({0, 2000});

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.patch_range = {ImeCoordinateSpace::EDITING_BUFFER, 0, 0};
  step.replacement_text = "x";
  step.selection_after = {ImeCoordinateSpace::EDITING_BUFFER, 1, 1, CaretAffinity::DOWNSTREAM};

  EditorActionResult result = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  CHECK_FALSE(result.text_changes.empty());
  CHECK(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(result.ime_state.session_id == 0);
  CHECK(document->getU8Text().size() == original.size() + 1);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::SESSION_MISMATCH);
}

TEST_CASE("EditorCore text update ignores affinity-only host echo") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(10.0f), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>("abcdefghij"));
  editor.setViewport({90, 320});
  editor.setWrapMode(WrapMode::CHAR_BREAK);
  EditorRenderModel model;
  editor.buildRenderModel(model);
  editor.setCursorPosition({0, 5});
  editor.moveCursorRight();
  REQUIRE(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);

  ImeState session = editor.beginImeSession(ImeMutationModel::TEXT_UPDATE);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeTextContext context = editor.getImeContext(session.session_id, ImeTextSource::EDITING_BUFFER, 0, -1);
  REQUIRE(context.result_code == ImeResultCode::OK);
  ImeTextUpdateStep step;
  step.old_text = context.text;
  step.selection_after = context.selection;
  step.selection_after.coordinate_space = ImeCoordinateSpace::EDITING_BUFFER;
  step.selection_after.affinity = CaretAffinity::DOWNSTREAM;

  EditorActionResult result = editor.applyImeTextUpdates({session.session_id, session.state_revision, {step}});

  CHECK(result.ime_state.state_revision == session.state_revision);
  CHECK(editor.getCaretAffinity() == CaretAffinity::UPSTREAM);
}

TEST_CASE("EditorCore stale session cannot disturb current IME generation") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>("abc"));
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand update;
  update.kind = ImeCommandKind::UPDATE_COMPOSITION;
  update.text = "x";
  EditorActionResult stale = editor.applyImeCommands({session.session_id + 1, {update}});

  CHECK(stale.ime_state.result_code == ImeResultCode::SESSION_MISMATCH);
  CHECK(stale.ime_host_action == ImeHostAction::NONE);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::OK);
  CHECK_FALSE(editor.hasComposition());
}

TEST_CASE("EditorCore document load restarts an active IME session") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  editor.loadDocument(makeShared<LineArrayDocument>("old"));
  editor.setViewport({800, 600});

  const ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("new");
  const EditorActionResult result = editor.loadDocument(document);

  CHECK(result.ime_host_action == ImeHostAction::RESTART_SESSION);
  CHECK(result.ime_state.result_code == ImeResultCode::OK);
  CHECK(result.ime_state.session_id == 0);
  CHECK(editor.getImeState(session.session_id).result_code == ImeResultCode::SESSION_MISMATCH);
  CHECK(document->getU8Text() == "new");
}

TEST_CASE("EditorCore command canonical fields reject before live mutation") {
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), EditorOptions{});
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abc");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  ImeState session = editor.beginImeSession(ImeMutationModel::COMMAND);
  REQUIRE(session.result_code == ImeResultCode::OK);
  ImeCommand finish;
  finish.kind = ImeCommandKind::FINISH_COMPOSITION;
  finish.text = "unused";
  EditorActionResult rejected = editor.applyImeCommands({session.session_id, {finish}});

  CHECK(rejected.ime_state.result_code == ImeResultCode::REJECTED);
  CHECK(document->getU8Text() == "abc");
  CHECK_FALSE(editor.canUndo());
}
