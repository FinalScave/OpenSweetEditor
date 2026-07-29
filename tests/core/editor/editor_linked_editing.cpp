#include <catch2/catch_amalgamated.hpp>
#include <sweeteditor/editor_core.h>
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore snippet linked editing mirrors placeholders and exits at tail") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  EditorActionResult insert_result = editor.insertSnippet("${1:foo} + ${1:foo} -> $0");
  REQUIRE_FALSE(insert_result.text_changes.empty());
  REQUIRE(editor.isInLinkedEditing());
  CHECK(document->getU8Text() == "foo + foo -> ");
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 3}}));

  EditorActionResult linked_edit = editor.insertText("bar");
  REQUIRE_FALSE(linked_edit.text_changes.empty());
  CHECK(document->getU8Text() == "bar + bar -> ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
  CHECK_FALSE(editor.hasSelection());

  REQUIRE(editor.linkedEditingNextTabStop().handled);
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
  CHECK(editor.isInLinkedEditing());

  CHECK_FALSE(editor.linkedEditingNextTabStop().handled);
  CHECK_FALSE(editor.isInLinkedEditing());
  CHECK(editor.getCursorPosition() == (TextPosition{0, 13}));
}

TEST_CASE("EditorCore linked editing is one atomic undo and redo entry") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:foo} + ${1:foo} -> $0").text_changes.empty());
  REQUIRE_FALSE(editor.insertText("bar").text_changes.empty());
  CHECK(document->getU8Text() == "bar + bar -> ");

  REQUIRE_FALSE(editor.undo().text_changes.empty());
  CHECK(document->getU8Text() == "foo + foo -> ");
  CHECK_FALSE(editor.isInLinkedEditing());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 3}}));

  REQUIRE_FALSE(editor.redo().text_changes.empty());
  CHECK(document->getU8Text() == "bar + bar -> ");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 3}));
  CHECK_FALSE(editor.isInLinkedEditing());
}

TEST_CASE("EditorCore linked editing applies ordinary edits at the active caret") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  REQUIRE_FALSE(editor.insertSnippet("${1:ab}-${1:ab}").text_changes.empty());
  editor.setCursorPosition({0, 1});
  REQUIRE_FALSE(editor.insertText("X").text_changes.empty());
  CHECK(document->getU8Text() == "aXb-aXb");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 2}));
  CHECK(editor.isInLinkedEditing());

  REQUIRE_FALSE(editor.backspace().text_changes.empty());
  CHECK(document->getU8Text() == "ab-ab");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
  CHECK(editor.isInLinkedEditing());

  REQUIRE_FALSE(editor.deleteForward().text_changes.empty());
  CHECK(document->getU8Text() == "a-a");
  CHECK(editor.getCursorPosition() == (TextPosition{0, 1}));
  CHECK(editor.isInLinkedEditing());
}

TEST_CASE("EditorCore structural line edits exit linked editing") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  SECTION("move line up") {
    REQUIRE_FALSE(editor.insertSnippet("top\n${1:a}-${1:a}").text_changes.empty());
    REQUIRE_FALSE(editor.moveLineUp().text_changes.empty());
  }

  SECTION("move line down") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.moveLineDown().text_changes.empty());
  }

  SECTION("copy line up") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.copyLineUp().text_changes.empty());
  }

  SECTION("copy line down") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.copyLineDown().text_changes.empty());
  }

  SECTION("delete line") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.deleteLine().text_changes.empty());
  }

  SECTION("insert line above") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.insertLineAbove().text_changes.empty());
  }

  SECTION("insert line below") {
    REQUIRE_FALSE(editor.insertSnippet("${1:a}-${1:a}\ntail").text_changes.empty());
    REQUIRE_FALSE(editor.insertLineBelow().text_changes.empty());
  }

  CHECK_FALSE(editor.isInLinkedEditing());
}

TEST_CASE("EditorCore linked editing supports prev navigation and explicit cancel") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  EditorActionResult insert_result = editor.insertSnippet("${1:a}-${2:b}-$0");
  REQUIRE_FALSE(insert_result.text_changes.empty());
  REQUIRE(editor.isInLinkedEditing());

  CHECK_FALSE(editor.linkedEditingPrevTabStop().handled);
  CHECK(editor.isInLinkedEditing());
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 1}}));

  REQUIRE(editor.linkedEditingNextTabStop().handled);
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 2}, {0, 3}}));

  REQUIRE(editor.linkedEditingPrevTabStop().handled);
  CHECK(editor.hasSelection());
  CHECK(editor.getSelection() == (TextRange{{0, 0}, {0, 1}}));

  editor.cancelLinkedEditing();
  CHECK_FALSE(editor.isInLinkedEditing());
}

TEST_CASE("SnippetParser orders tab stops and computes absolute ranges") {
  const SnippetParseResult parsed = SnippetParser::parse("${2:bar} ${1:foo} ${1} $0", {3, 4});

  REQUIRE(parsed.text == "bar foo foo ");
  REQUIRE(parsed.groups.size() == 3);

  CHECK(parsed.groups[0].index == 1);
  CHECK(parsed.groups[1].index == 2);
  CHECK(parsed.groups[2].index == 0);

  const TabStopGroup& first_group = parsed.groups[0];
  REQUIRE(first_group.ranges.size() == 2);
  CHECK(first_group.default_text == "foo");
  CHECK(first_group.ranges[0] == (TextRange{{3, 8}, {3, 11}}));
  CHECK(first_group.ranges[1] == (TextRange{{3, 12}, {3, 15}}));

  const TabStopGroup& second_group = parsed.groups[1];
  REQUIRE(second_group.ranges.size() == 1);
  CHECK(second_group.default_text == "bar");
  CHECK(second_group.ranges[0] == (TextRange{{3, 4}, {3, 7}}));

  const TabStopGroup& final_group = parsed.groups[2];
  REQUIRE(final_group.ranges.size() == 1);
  CHECK(final_group.ranges[0] == (TextRange{{3, 16}, {3, 16}}));
}

TEST_CASE("SnippetParser handles escape sequences in plain text and placeholders") {
  const SnippetParseResult parsed = SnippetParser::parse(R"(\$${1:x}\})", {0, 0});

  REQUIRE(parsed.text == "$x}");
  REQUIRE(parsed.groups.size() == 1);
  CHECK(parsed.groups[0].index == 1);
  CHECK(parsed.groups[0].default_text == "x");
  CHECK(parsed.groups[0].ranges[0] == (TextRange{{0, 1}, {0, 2}}));
}

TEST_CASE("LinkedEditingSession adjusts ranges after edits") {
  auto makeSession = []() {
    Vector<TabStopGroup> groups;
    groups.push_back(TabStopGroup{1,
                                  {
                                      {{0, 0}, {0, 1}},
                                      {{0, 5}, {0, 7}},
                                      {{1, 2}, {1, 4}},
                                  },
                                  ""});
    return LinkedEditingSession(std::move(groups));
  };

  SECTION("same-line replacement shifts later columns") {
    auto session = makeSession();
    REQUIRE(session.adjustRangesForEditBatch({{{{0, 1}, {0, 3}}, "12345"}}, {std::nullopt}));

    const TabStopGroup* group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 0}, {0, 1}}));
    CHECK(group->ranges[1] == (TextRange{{0, 8}, {0, 10}}));
    CHECK(group->ranges[2] == (TextRange{{1, 2}, {1, 4}}));
  }

  SECTION("cross-line replacement shifts later lines and same-line trailing ranges") {
    auto session = makeSession();
    REQUIRE(session.adjustRangesForEditBatch({{{{0, 1}, {0, 3}}, "\nX"}}, {std::nullopt}));

    const TabStopGroup* group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 0}, {0, 1}}));
    CHECK(group->ranges[1] == (TextRange{{1, 3}, {1, 5}}));
    CHECK(group->ranges[2] == (TextRange{{2, 2}, {2, 4}}));
  }

  SECTION("collapsed owner expands while other ranges move past the insertion") {
    Vector<TabStopGroup> groups;
    groups.push_back({1, {{{0, 1}, {0, 1}}, {{0, 5}, {0, 5}}}, ""});
    groups.push_back({0, {{{0, 1}, {0, 1}}}, ""});
    LinkedEditingSession session(std::move(groups));

    REQUIRE(session.adjustRangesForEditBatch({{{{0, 1}, {0, 1}}, "xx"}}, {0}));

    const TabStopGroup* group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 1}, {0, 3}}));
    CHECK(group->ranges[1] == (TextRange{{0, 7}, {0, 7}}));
    REQUIRE(session.nextTabStop());
    group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 3}, {0, 3}}));
  }
}

TEST_CASE("LinkedEditingSession adjusts one shared-pre-state owned batch") {
  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 0}, {0, 2}}, {{0, 4}, {0, 6}}}, ""});
  groups.push_back({0, {{{0, 6}, {0, 6}}}, ""});
  LinkedEditingSession session(std::move(groups));

  const Vector<TextEdit> edits{
      {{{0, 0}, {0, 2}}, "value"},
      {{{0, 4}, {0, 6}}, "value"},
  };
  const Vector<std::optional<size_t>> owners{0, 1};

  REQUIRE(session.adjustRangesForEditBatch(edits, owners));
  const TabStopGroup* group = session.currentGroup();
  REQUIRE(group != nullptr);
  CHECK(group->ranges[0] == (TextRange{{0, 0}, {0, 5}}));
  CHECK(group->ranges[1] == (TextRange{{0, 7}, {0, 12}}));

  REQUIRE(session.nextTabStop());
  group = session.currentGroup();
  REQUIRE(group != nullptr);
  CHECK(group->ranges[0] == (TextRange{{0, 12}, {0, 12}}));
}

TEST_CASE("LinkedEditingSession keeps collapsed owner before an adjacent replacement") {
  Vector<TabStopGroup> groups;
  groups.push_back({1, {{{0, 1}, {0, 1}}, {{0, 1}, {0, 3}}}, ""});
  LinkedEditingSession session(std::move(groups));

  const Vector<TextEdit> edits{
      {{{0, 1}, {0, 1}}, "x"},
      {{{0, 1}, {0, 3}}, "x"},
  };
  const Vector<std::optional<size_t>> owners{0, 1};

  REQUIRE(session.adjustRangesForEditBatch(edits, owners));
  const TabStopGroup* group = session.currentGroup();
  REQUIRE(group != nullptr);
  CHECK(group->ranges[0] == (TextRange{{0, 1}, {0, 2}}));
  CHECK(group->ranges[1] == (TextRange{{0, 2}, {0, 3}}));
}

TEST_CASE("EditorCore rejects invalid linked groups without replacing an active session") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);
  SharedPtr<Document> document = makeShared<LineArrayDocument>("abcdef");
  editor.loadDocument(document);
  editor.setViewport({800, 600});

  Vector<TabStopGroup> valid{{1, {{{0, 0}, {0, 1}}, {{0, 2}, {0, 3}}}, ""}};
  REQUIRE(editor.startLinkedEditing(std::move(valid)).handled);
  REQUIRE(editor.isInLinkedEditing());

  Vector<TabStopGroup> overlapping{{2, {{{0, 1}, {0, 4}}, {{0, 3}, {0, 5}}}, ""}};
  CHECK_FALSE(editor.startLinkedEditing(std::move(overlapping)).handled);
  CHECK(editor.isInLinkedEditing());

  Vector<TabStopGroup> duplicate_indices{
      {2, {{{0, 0}, {0, 1}}}, ""},
      {2, {{{0, 4}, {0, 5}}}, ""},
  };
  CHECK_FALSE(editor.startLinkedEditing(std::move(duplicate_indices)).handled);
  CHECK(editor.isInLinkedEditing());
}
