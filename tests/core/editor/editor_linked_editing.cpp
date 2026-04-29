#include <catch2/catch_amalgamated.hpp>
#include "editor_core.h"
#include "test_measurer.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("EditorCore snippet linked editing mirrors placeholders and exits at tail") {
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
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
  EditorOptions options;
  EditorCore editor(makeShared<FixedWidthTextMeasurer>(), options);

  SharedPtr<Document> document = makeShared<LineArrayDocument>("");
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

TEST_CASE("SnippetParser orders tab stops and computes absolute ranges") {
  const SnippetParseResult parsed = SnippetParser::parse("${2:bar} ${1:foo} ${1} $0", {3, 4});

  REQUIRE(parsed.text == "bar foo foo ");
  REQUIRE(parsed.model.groups.size() == 3);

  CHECK(parsed.model.groups[0].index == 1);
  CHECK(parsed.model.groups[1].index == 2);
  CHECK(parsed.model.groups[2].index == 0);

  const TabStopGroup& first_group = parsed.model.groups[0];
  REQUIRE(first_group.ranges.size() == 2);
  CHECK(first_group.default_text == "foo");
  CHECK(first_group.ranges[0] == (TextRange{{3, 8}, {3, 11}}));
  CHECK(first_group.ranges[1] == (TextRange{{3, 12}, {3, 15}}));

  const TabStopGroup& second_group = parsed.model.groups[1];
  REQUIRE(second_group.ranges.size() == 1);
  CHECK(second_group.default_text == "bar");
  CHECK(second_group.ranges[0] == (TextRange{{3, 4}, {3, 7}}));

  const TabStopGroup& final_group = parsed.model.groups[2];
  REQUIRE(final_group.ranges.size() == 1);
  CHECK(final_group.ranges[0] == (TextRange{{3, 16}, {3, 16}}));
}

TEST_CASE("SnippetParser handles escape sequences in plain text and placeholders") {
  const SnippetParseResult parsed = SnippetParser::parse(R"(\$${1:x}\})", {0, 0});

  REQUIRE(parsed.text == "$x}");
  REQUIRE(parsed.model.groups.size() == 1);
  CHECK(parsed.model.groups[0].index == 1);
  CHECK(parsed.model.groups[0].default_text == "x");
  CHECK(parsed.model.groups[0].ranges[0] == (TextRange{{0, 1}, {0, 2}}));
}

TEST_CASE("LinkedEditingSession computes edits in descending document order") {
  LinkedEditingModel model;
  model.groups.push_back(TabStopGroup {
      1,
      {
          {{0, 1}, {0, 2}},
          {{1, 0}, {1, 1}},
          {{0, 5}, {0, 6}},
      },
      ""
  });

  LinkedEditingSession session(std::move(model));
  const auto edits = session.computeLinkedEdits("zz");

  REQUIRE(edits.size() == 3);
  CHECK(edits[0].first == (TextRange{{1, 0}, {1, 1}}));
  CHECK(edits[1].first == (TextRange{{0, 5}, {0, 6}}));
  CHECK(edits[2].first == (TextRange{{0, 1}, {0, 2}}));
  CHECK(edits[0].second == "zz");
}

TEST_CASE("LinkedEditingSession adjusts ranges after edits") {
  auto makeSession = []() {
    LinkedEditingModel model;
    model.groups.push_back(TabStopGroup {
        1,
        {
            {{0, 0}, {0, 1}},
            {{0, 5}, {0, 7}},
            {{1, 2}, {1, 4}},
        },
        ""
    });
    return LinkedEditingSession(model);
  };

  SECTION("same-line replacement shifts later columns") {
    auto session = makeSession();
    session.adjustRangesForEdit({{0, 1}, {0, 3}}, {0, 6});

    const TabStopGroup* group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 0}, {0, 1}}));
    CHECK(group->ranges[1] == (TextRange{{0, 8}, {0, 10}}));
    CHECK(group->ranges[2] == (TextRange{{1, 2}, {1, 4}}));
  }

  SECTION("cross-line replacement shifts later lines and same-line trailing ranges") {
    auto session = makeSession();
    session.adjustRangesForEdit({{0, 1}, {0, 3}}, {1, 1});

    const TabStopGroup* group = session.currentGroup();
    REQUIRE(group != nullptr);
    CHECK(group->ranges[0] == (TextRange{{0, 0}, {0, 1}}));
    CHECK(group->ranges[1] == (TextRange{{1, 3}, {1, 5}}));
    CHECK(group->ranges[2] == (TextRange{{2, 2}, {2, 4}}));
  }
}
