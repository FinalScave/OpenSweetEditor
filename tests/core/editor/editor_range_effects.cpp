#include <algorithm>
#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/document.h>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"
#include "test_render_helpers.h"

using namespace NS_SWEETEDITOR;

namespace {
  UniquePtr<EditorCore> makeEditor(const U8String& text, float width = 320.0f, float height = 120.0f) {
    auto editor = makeUnique<EditorCore>(makeShared<FixedWidthTextMeasurer>(10.0f), EditorOptions {});
    editor->loadDocument(makeShared<LineArrayDocument>(text));
    editor->setViewport({width, height});
    return editor;
  }

  void enableCharWrap(EditorCore& editor, float width = 60.0f, float height = 160.0f) {
    editor.setGutterVisible(false);
    editor.setViewport({width, height});
    editor.setWrapMode(WrapMode::CHAR_BREAK);
  }

  void checkWrappedRangeEffects(const EditorRenderModel& model, RangeEffectKind kind) {
    REQUIRE(model.lines.size() >= 2);
    auto effects = rangeEffectsOfKind(model, kind);
    CHECK(effects.size() == model.lines.size());
    CHECK(effects.front()->rect.origin.y != effects.back()->rect.origin.y);
  }

  const VisualRun& findProjectedTextRun(const EditorRenderModel& model, size_t source_line) {
    REQUIRE_FALSE(model.lines.empty());
    const auto run_it = std::find_if(model.lines.front().runs.begin(), model.lines.front().runs.end(), [source_line](const VisualRun& run) {
      return run.source_line == source_line && run.type == VisualRunType::TEXT;
    });
    REQUIRE(run_it != model.lines.front().runs.end());
    return *run_it;
  }

  const VisualRun& findProjectedTextRun(const EditorRenderModel& model, size_t source_line, size_t column) {
    REQUIRE_FALSE(model.lines.empty());
    const auto run_it = std::find_if(model.lines.front().runs.begin(), model.lines.front().runs.end(), [source_line, column](const VisualRun& run) {
      return run.source_line == source_line && run.column == column && run.type == VisualRunType::TEXT;
    });
    REQUIRE(run_it != model.lines.front().runs.end());
    return *run_it;
  }

  bool hasRangeEffectRectForRun(const EditorRenderModel& model, RangeEffectKind kind, const VisualRun& run) {
    for (const RangeEffectRenderItem* effect : rangeEffectsOfKind(model, kind)) {
      const Rect& rect = effect->rect;
      if (rect.origin.x == Catch::Approx(run.x) &&
          rect.width == Catch::Approx(run.width)) {
        return true;
      }
    }
    return false;
  }
}

TEST_CASE("EditorCore buildRenderModel exposes normalized selection handles") {
  auto editor_holder = makeEditor("abcdef");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.selection.background_color = static_cast<int32_t>(0x66336699u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setSelection({{0, 5}, {0, 2}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const RangeEffectRenderItem& effect = requireSingleRangeEffectOfKind(model, RangeEffectKind::SELECTION);
  CHECK(effect.style == styles.selection);
  CHECK_FALSE(model.cursor.visible);
  CHECK(model.selection_start_handle.visible);
  CHECK(model.selection_end_handle.visible);
  CHECK(model.selection_start_handle.position.x <= model.selection_end_handle.position.x);
}

TEST_CASE("EditorCore buildRenderModel skips selection range effects without paint") {
  auto editor_holder = makeEditor("abcdef");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.selection.foreground_color = static_cast<int32_t>(0xFFFFFFFFu);
  editor.setEditorRangeEffectStyles(styles);
  editor.setSelection({{0, 1}, {0, 4}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  CHECK(rangeEffectsOfKind(model, RangeEffectKind::SELECTION).empty());
  CHECK(model.selection_start_handle.visible);
  CHECK(model.selection_end_handle.visible);
}

TEST_CASE("EditorCore buildRenderModel includes folded tail selection inside broader ranges") {
  auto editor_holder = makeEditor("if {\n  body\n}");
  EditorCore& editor = *editor_holder;

  editor.setFoldRegions({{0, 2, true}});
  EditorRangeEffectStyles styles;
  styles.selection.background_color = static_cast<int32_t>(0x66336699u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setSelection({{0, 0}, {2, 1}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun& tail_run = findProjectedTextRun(model, 2);
  CHECK(hasRangeEffectRectForRun(model, RangeEffectKind::SELECTION, tail_run));
}

TEST_CASE("EditorCore buildRenderModel applies selection foreground by splitting source runs") {
  auto editor_holder = makeEditor("abcdef");
  EditorCore& editor = *editor_holder;

  constexpr int32_t style_color = static_cast<int32_t>(0xFF010203u);
  constexpr int32_t style_background = static_cast<int32_t>(0x33445566u);
  constexpr int32_t selection_foreground = static_cast<int32_t>(0xFFFFFFFFu);

  EditorRenderColors colors;
  colors.text_foreground = static_cast<int32_t>(0xFF202020u);
  editor.setEditorRenderColors(colors);
  EditorRangeEffectStyles styles;
  styles.selection.foreground_color = selection_foreground;
  editor.setEditorRangeEffectStyles(styles);

  editor.registerTextStyle(1, TextStyle{style_color, style_background, FONT_STYLE_NORMAL});
  editor.setLineSpans(0, SpanLayer::SYNTAX, Vector<StyleSpan>{{0, 6, 1}});
  editor.setSelection({{0, 2}, {0, 5}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE(model.lines.size() == 1);
  const VisualLine& line = model.lines.front();
  REQUIRE(line.runs.size() == 3);
  CHECK(visualRunText(line.runs[0]) == "ab");
  CHECK(visualRunText(line.runs[1]) == "cde");
  CHECK(visualRunText(line.runs[2]) == "f");
  CHECK(line.runs[0].style.color == style_color);
  CHECK(line.runs[0].style.background_color == style_background);
  CHECK(line.runs[1].style.color == selection_foreground);
  CHECK(line.runs[1].style.background_color == 0);
  CHECK(line.runs[2].style.color == style_color);
  CHECK(line.runs[2].style.background_color == style_background);
}

TEST_CASE("EditorCore buildRenderModel applies selection foreground after horizontal crop") {
  auto editor_holder = makeEditor("abcdefghijklmnopqrstuvwxyz", 80, 120);
  EditorCore& editor = *editor_holder;
  editor.setGutterVisible(false);

  EditorRenderModel warmup_model;
  editor.buildRenderModel(warmup_model);
  editor.setScroll(50, 0);

  constexpr int32_t text_foreground = static_cast<int32_t>(0xFF202020u);
  constexpr int32_t selection_foreground = static_cast<int32_t>(0xFFFFFFFFu);

  EditorRenderColors colors;
  colors.text_foreground = text_foreground;
  editor.setEditorRenderColors(colors);
  EditorRangeEffectStyles styles;
  styles.selection.foreground_color = selection_foreground;
  editor.setEditorRangeEffectStyles(styles);
  editor.setSelection({{0, 7}, {0, 9}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  REQUIRE(model.lines.size() == 1);
  const VisualLine& line = model.lines.front();
  REQUIRE(line.runs.size() == 3);
  CHECK(visualRunText(line.runs[0]) == "fg");
  CHECK(visualRunText(line.runs[1]) == "hi");
  CHECK(visualRunText(line.runs[2]) == "jklm");
  CHECK(line.runs[0].style.color == text_foreground);
  CHECK(line.runs[1].style.color == selection_foreground);
  CHECK(line.runs[2].style.color == text_foreground);
}

TEST_CASE("EditorCore buildRenderModel maps document highlights to range and text effects") {
  auto editor_holder = makeEditor("alpha beta");
  EditorCore& editor = *editor_holder;

  constexpr int32_t foreground = static_cast<int32_t>(0xFF102030u);
  EditorRangeEffectStyles styles;
  styles.document_highlight_write.foreground_color = foreground;
  styles.document_highlight_write.background_color = static_cast<int32_t>(0x22102030u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setLineDocumentHighlights(0, {{6, 4, DocumentHighlightKind::WRITE}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const RangeEffectRenderItem& effect =
      requireSingleRangeEffectOfKind(model, RangeEffectKind::DOCUMENT_HIGHLIGHT_WRITE);
  CHECK(effect.style == styles.document_highlight_write);

  REQUIRE(model.lines.size() == 1);
  const VisualLine& line = model.lines.front();
  REQUIRE(line.runs.size() == 2);
  CHECK(visualRunText(line.runs[0]) == "alpha ");
  CHECK(visualRunText(line.runs[1]) == "beta");
  CHECK(line.runs[1].style.color == foreground);

  editor.insertText("!");
  model = {};
  editor.buildRenderModel(model);

  CHECK(rangeEffectsOfKind(model, RangeEffectKind::DOCUMENT_HIGHLIGHT_WRITE).empty());
}

TEST_CASE("EditorCore buildRenderModel applies foreground-only document highlights without range effects") {
  auto editor_holder = makeEditor("alpha beta");
  EditorCore& editor = *editor_holder;

  constexpr int32_t foreground = static_cast<int32_t>(0xFF445566u);
  EditorRangeEffectStyles styles;
  styles.document_highlight_text.foreground_color = foreground;
  editor.setEditorRangeEffectStyles(styles);
  editor.setLineDocumentHighlights(0, {{6, 4, DocumentHighlightKind::TEXT}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  CHECK(rangeEffectsOfKind(model, RangeEffectKind::DOCUMENT_HIGHLIGHT_TEXT).empty());
  REQUIRE(model.lines.size() == 1);
  const VisualLine& line = model.lines.front();
  REQUIRE(line.runs.size() == 2);
  CHECK(visualRunText(line.runs[0]) == "alpha ");
  CHECK(visualRunText(line.runs[1]) == "beta");
  CHECK(line.runs[1].style.color == foreground);
}

TEST_CASE("EditorCore buildRenderModel renders document highlights projected into folded tail") {
  auto editor_holder = makeEditor("head {\ninside\n} tail");
  EditorCore& editor = *editor_holder;
  editor.setFoldRegions({{0, 2, true}});

  EditorRangeEffectStyles styles;
  styles.document_highlight_read.background_color = static_cast<int32_t>(0x22102030u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setLineDocumentHighlights(2, {{2, 4, DocumentHighlightKind::READ}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const VisualRun& tail_run = findProjectedTextRun(model, 2, 2);
  CHECK(hasRangeEffectRectForRun(model, RangeEffectKind::DOCUMENT_HIGHLIGHT_READ, tail_run));
}

TEST_CASE("EditorCore buildRenderModel splits wrapped document highlight range effects") {
  auto editor_holder = makeEditor("abcdefghijkl");
  EditorCore& editor = *editor_holder;
  enableCharWrap(editor);

  EditorRangeEffectStyles styles;
  styles.document_highlight_read.background_color = static_cast<int32_t>(0x22102030u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setLineDocumentHighlights(0, {{0, 12, DocumentHighlightKind::READ}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  checkWrappedRangeEffects(model, RangeEffectKind::DOCUMENT_HIGHLIGHT_READ);
}

TEST_CASE("EditorCore buildRenderModel exposes active IME composition range effect") {
  auto editor_holder = makeEditor("ab");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.ime_composition.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.ime_composition.underline_style = RangeEffectUnderlineStyle::SOLID;
  editor.setEditorRangeEffectStyles(styles);
  editor.setCursorPosition({0, 1});
  editor.updateImePreedit("xy", ImeScriptClass::LATIN);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  const RangeEffectRenderItem& effect = requireSingleRangeEffectOfKind(model, RangeEffectKind::IME_COMPOSITION);
  CHECK(effect.style == styles.ime_composition);
  CHECK(effect.rect.width > 0.0f);
  CHECK(effect.rect.height > 0.0f);
  CHECK(effect.rect.origin.x == Catch::Approx(editor.getPositionScreenRect({0, 1}).x));
}

TEST_CASE("EditorCore buildRenderModel splits wrapped IME composition range effects") {
  auto editor_holder = makeEditor("", 80, 160);
  EditorCore& editor = *editor_holder;
  editor.setWrapMode(WrapMode::CHAR_BREAK);

  EditorRangeEffectStyles styles;
  styles.ime_composition.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.ime_composition.underline_style = RangeEffectUnderlineStyle::SOLID;
  editor.setEditorRangeEffectStyles(styles);

  editor.setCursorPosition({0, 0});
  editor.updateImePreedit("abcdefghijkl", ImeScriptClass::LATIN);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  auto effects = rangeEffectsOfKind(model, RangeEffectKind::IME_COMPOSITION);
  REQUIRE(effects.size() >= 2);
  CHECK(effects.front()->rect.origin.y != effects.back()->rect.origin.y);
}

TEST_CASE("EditorCore buildRenderModel emits linked editing rectangles for snippet tab stops") {
  auto editor_holder = makeEditor("");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.linked_editing_active.border_color = static_cast<int32_t>(0xFF6699CCu);
  styles.linked_editing_inactive.border_color = static_cast<int32_t>(0x806699CCu);
  editor.setEditorRangeEffectStyles(styles);
  REQUIRE(editor.insertSnippet("${1:foo}-${2:bar}-$0").content_changed);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  auto active_effects = rangeEffectsOfKind(model, RangeEffectKind::LINKED_EDITING_ACTIVE);
  auto inactive_effects = rangeEffectsOfKind(model, RangeEffectKind::LINKED_EDITING_INACTIVE);
  REQUIRE(active_effects.size() == 1);
  REQUIRE(inactive_effects.size() == 1);
  CHECK(active_effects.front()->style == styles.linked_editing_active);
  CHECK(inactive_effects.front()->style == styles.linked_editing_inactive);
  for (const RangeEffectRenderItem* effect : active_effects) {
    CHECK(effect->rect.width > 0.0f);
    CHECK(effect->rect.height > 0.0f);
  }
  for (const RangeEffectRenderItem* effect : inactive_effects) {
    CHECK(effect->rect.width > 0.0f);
    CHECK(effect->rect.height > 0.0f);
  }
}

TEST_CASE("EditorCore buildRenderModel uses external bracket match positions when provided") {
  auto editor_holder = makeEditor("a(b)c");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.bracket_match.background_color = static_cast<int32_t>(0x33999900u);
  styles.bracket_match.border_color = static_cast<int32_t>(0xCC999900u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setMatchedBrackets({0, 1}, {0, 3});

  EditorRenderModel matched_model;
  editor.buildRenderModel(matched_model);

  auto matched_effects = rangeEffectsOfKind(matched_model, RangeEffectKind::BRACKET_MATCH);
  REQUIRE(matched_effects.size() == 2);
  for (const RangeEffectRenderItem* effect : matched_effects) {
    CHECK(effect->style == styles.bracket_match);
    CHECK(effect->rect.width > 0.0f);
    CHECK(effect->rect.height > 0.0f);
  }

  editor.clearMatchedBrackets();
  EditorRenderModel cleared_model;
  editor.buildRenderModel(cleared_model);
  CHECK(rangeEffectsOfKind(cleared_model, RangeEffectKind::BRACKET_MATCH).empty());
}

TEST_CASE("EditorCore buildRenderModel maps diagnostic range effects to severity styles") {
  auto editor_holder = makeEditor("abcd");
  EditorCore& editor = *editor_holder;

  EditorRangeEffectStyles styles;
  styles.diagnostic_error.underline_color = static_cast<int32_t>(0xFFFF0000u);
  styles.diagnostic_error.underline_style = RangeEffectUnderlineStyle::WAVY;
  styles.diagnostic_warning.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.diagnostic_warning.underline_style = RangeEffectUnderlineStyle::WAVY;
  styles.diagnostic_info.underline_color = static_cast<int32_t>(0xFF3399FFu);
  styles.diagnostic_info.underline_style = RangeEffectUnderlineStyle::SOLID;
  styles.diagnostic_hint.underline_color = static_cast<int32_t>(0xFF888888u);
  styles.diagnostic_hint.underline_style = RangeEffectUnderlineStyle::DASHED;
  editor.setEditorRangeEffectStyles(styles);

  Vector<Diagnostic> diagnostics;
  diagnostics.push_back({0, 1, DiagnosticSeverity::DIAG_ERROR});
  diagnostics.push_back({1, 1, DiagnosticSeverity::DIAG_WARNING});
  diagnostics.push_back({2, 1, DiagnosticSeverity::DIAG_INFO});
  diagnostics.push_back({3, 1, DiagnosticSeverity::DIAG_HINT});
  editor.setLineDiagnostics(0, std::move(diagnostics));

  EditorRenderModel model;
  editor.buildRenderModel(model);

  CHECK(requireSingleRangeEffectOfKind(model, RangeEffectKind::DIAGNOSTIC_ERROR).style == styles.diagnostic_error);
  CHECK(requireSingleRangeEffectOfKind(model, RangeEffectKind::DIAGNOSTIC_WARNING).style == styles.diagnostic_warning);
  CHECK(requireSingleRangeEffectOfKind(model, RangeEffectKind::DIAGNOSTIC_INFO).style == styles.diagnostic_info);
  CHECK(requireSingleRangeEffectOfKind(model, RangeEffectKind::DIAGNOSTIC_HINT).style == styles.diagnostic_hint);
}

TEST_CASE("EditorCore buildRenderModel emits wrapped diagnostic range effects once per rect") {
  auto editor_holder = makeEditor("abcdefghijkl");
  EditorCore& editor = *editor_holder;
  enableCharWrap(editor);

  EditorRangeEffectStyles styles;
  styles.diagnostic_warning.underline_color = static_cast<int32_t>(0xFFFFCC00u);
  styles.diagnostic_warning.underline_style = RangeEffectUnderlineStyle::WAVY;
  editor.setEditorRangeEffectStyles(styles);
  editor.setLineDiagnostics(0, {{0, 12, DiagnosticSeverity::DIAG_WARNING}});

  EditorRenderModel model;
  editor.buildRenderModel(model);

  checkWrappedRangeEffects(model, RangeEffectKind::DIAGNOSTIC_WARNING);
}

TEST_CASE("EditorCore search renders matches projected into folded tail") {
  auto editor_holder = makeEditor("head {\ninside\n} tail", 500, 240);
  EditorCore& editor = *editor_holder;
  EditorRangeEffectStyles styles;
  styles.search_current.background_color = static_cast<int32_t>(0x55FFAA00u);
  editor.setEditorRangeEffectStyles(styles);
  editor.setFoldRegions({{0, 2, true}});

  SearchRequest request;
  request.pattern = "tail";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  REQUIRE(state.match_count == 1);
  CHECK(state.current_range == (TextRange{{2, 2}, {2, 6}}));

  EditorRenderModel model;
  editor.buildRenderModel(model);
  CHECK_FALSE(rangeEffectsOfKind(model, RangeEffectKind::SEARCH_CURRENT).empty());
}

TEST_CASE("EditorCore search renders current and non-current range effects separately") {
  auto editor_holder = makeEditor("foo foo foo", 500, 240);
  EditorCore& editor = *editor_holder;
  EditorRangeEffectStyles styles;
  styles.search_match.background_color = static_cast<int32_t>(0x2200AAFFu);
  styles.search_current.background_color = static_cast<int32_t>(0x55FFAA00u);
  styles.search_current.border_color = static_cast<int32_t>(0xCCFFAA00u);
  editor.setEditorRangeEffectStyles(styles);

  SearchRequest request;
  request.pattern = "foo";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  REQUIRE(state.match_count == 3);
  REQUIRE(state.current_index == 0);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  auto current_effects = rangeEffectsOfKind(model, RangeEffectKind::SEARCH_CURRENT);
  auto match_effects = rangeEffectsOfKind(model, RangeEffectKind::SEARCH_MATCH);
  REQUIRE(current_effects.size() == 1);
  REQUIRE(match_effects.size() == 2);
  CHECK(current_effects.front()->style == styles.search_current);
  for (const RangeEffectRenderItem* effect : match_effects) {
    CHECK(effect->style == styles.search_match);
  }
}

TEST_CASE("EditorCore search splits wrapped current match range effects") {
  auto editor_holder = makeEditor("abcdefghijkl");
  EditorCore& editor = *editor_holder;
  enableCharWrap(editor);

  EditorRangeEffectStyles styles;
  styles.search_current.background_color = static_cast<int32_t>(0x55FFAA00u);
  editor.setEditorRangeEffectStyles(styles);

  SearchRequest request;
  request.pattern = "abcdefghijkl";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  REQUIRE(state.match_count == 1);

  EditorRenderModel model;
  editor.buildRenderModel(model);

  checkWrappedRangeEffects(model, RangeEffectKind::SEARCH_CURRENT);
}

TEST_CASE("EditorCore search applies foreground-only styles without range effects") {
  auto editor_holder = makeEditor("alpha beta", 500, 240);
  EditorCore& editor = *editor_holder;
  constexpr int32_t foreground = static_cast<int32_t>(0xFF446688u);
  EditorRangeEffectStyles styles;
  styles.search_current.foreground_color = foreground;
  editor.setEditorRangeEffectStyles(styles);

  SearchRequest request;
  request.pattern = "beta";
  editor.search(request);

  SearchState state = editor.getSearchState();
  REQUIRE(state.status == SearchStatus::READY);
  REQUIRE(state.current_range == (TextRange{{0, 6}, {0, 10}}));

  EditorRenderModel model;
  editor.buildRenderModel(model);

  CHECK(rangeEffectsOfKind(model, RangeEffectKind::SEARCH_CURRENT).empty());
  REQUIRE(model.lines.size() == 1);
  const VisualLine& line = model.lines.front();
  REQUIRE(line.runs.size() == 2);
  CHECK(visualRunText(line.runs[0]) == "alpha ");
  CHECK(visualRunText(line.runs[1]) == "beta");
  CHECK(line.runs[1].style.color == foreground);
}
