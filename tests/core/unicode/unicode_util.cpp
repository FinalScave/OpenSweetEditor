#include <catch2/catch_amalgamated.hpp>
#include "macro.h"
#include "utility.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("UnicodeUtil clamps UTF-16 columns to code-point boundaries") {
  const U16String text(CHAR16("A\U0001F600B"));

  CHECK(UnicodeUtil::isCodePointBoundary(text, 0));
  CHECK(UnicodeUtil::isCodePointBoundary(text, 1));
  CHECK_FALSE(UnicodeUtil::isCodePointBoundary(text, 2));
  CHECK(UnicodeUtil::isCodePointBoundary(text, 3));
  CHECK(UnicodeUtil::isCodePointBoundary(text, 4));

  CHECK(UnicodeUtil::clampColumnToCodePointBoundaryLeft(text, 2) == 1);
  CHECK(UnicodeUtil::clampColumnToCodePointBoundaryRight(text, 2) == 3);
  CHECK(UnicodeUtil::clampColumnToCodePointBoundary(text, 2) == 1);
}

TEST_CASE("UnicodeUtil steps across surrogate pairs as one code point") {
  const U16String text(CHAR16("A\U0001F600B"));

  CHECK(UnicodeUtil::prevCodePointColumn(text, 1) == 0);
  CHECK(UnicodeUtil::nextCodePointColumn(text, 1) == 3);
  CHECK(UnicodeUtil::prevCodePointColumn(text, 3) == 1);
  CHECK(UnicodeUtil::nextCodePointColumn(text, 3) == 4);
}

TEST_CASE("UnicodeUtil clamps same-line ranges to code-point boundaries") {
  const U16String text(CHAR16("A\U0001F600B"));
  const TextRange clamped = UnicodeUtil::clampRangeToCodePointBoundary(text, {{0, 2}, {0, 2}});
  const TextRange expanded = UnicodeUtil::clampRangeToCodePointBoundary(text, {{0, 2}, {0, 3}});

  CHECK(clamped == (TextRange{{0, 1}, {0, 3}}));
  CHECK(expanded == (TextRange{{0, 1}, {0, 3}}));
}

TEST_CASE("UnicodeUtil steps across grapheme clusters for common emoji sequences") {
  const U16String thumbs(CHAR16("\U0001F44D\U0001F3FB"));
  const U16String victory(CHAR16("\u270C\U0001F3FB\uFE0F"));
  const U16String combining(CHAR16("a\u0301"));
  const U16String flag(CHAR16("\U0001F1E8\U0001F1F3"));
  const U16String family(CHAR16("\U0001F468\u200D\U0001F469\u200D\U0001F467\u200D\U0001F466"));

  CHECK(UnicodeUtil::clampColumnToGraphemeBoundaryLeft(thumbs, 2) == 0);
  CHECK(UnicodeUtil::clampColumnToGraphemeBoundaryRight(thumbs, 2) == thumbs.length());
  CHECK(UnicodeUtil::nextGraphemeBoundaryColumn(thumbs, 0) == thumbs.length());
  CHECK(UnicodeUtil::prevGraphemeBoundaryColumn(thumbs, thumbs.length()) == 0);

  CHECK(UnicodeUtil::nextGraphemeBoundaryColumn(victory, 0) == victory.length());
  CHECK(UnicodeUtil::nextGraphemeBoundaryColumn(combining, 0) == combining.length());
  CHECK(UnicodeUtil::nextGraphemeBoundaryColumn(flag, 0) == flag.length());
  CHECK(UnicodeUtil::nextGraphemeBoundaryColumn(family, 0) == family.length());
  CHECK(UnicodeUtil::prevGraphemeBoundaryColumn(family, family.length()) == 0);
}
