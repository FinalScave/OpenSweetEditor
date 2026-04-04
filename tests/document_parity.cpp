#include <catch2/catch_amalgamated.hpp>
#include "document.h"
#include "utility.h"

using namespace NS_SWEETEDITOR;

namespace {
  void checkEquivalent(Document& left, Document& right) {
    CHECK(left.getU8Text() == right.getU8Text());
    REQUIRE(left.getLineCount() == right.getLineCount());

    for (size_t line = 0; line < left.getLineCount(); ++line) {
      const uint32_t left_cols = left.getLineColumns(line);
      const uint32_t right_cols = right.getLineColumns(line);
      CHECK(left_cols == right_cols);
      U8String left_u8;
      U8String right_u8;
      StrUtil::convertUTF16ToUTF8(left.getLineU16Text(line), left_u8);
      StrUtil::convertUTF16ToUTF8(right.getLineU16Text(line), right_u8);
      CHECK(left_u8 == right_u8);

      const U16String& left_ref = left.getLineU16TextRef(line);
      const U16String& right_ref = right.getLineU16TextRef(line);
      CHECK(left_ref == right_ref);

      const size_t mid_col = left_cols / 2;
      const size_t samples[] = {0, mid_col, static_cast<size_t>(left_cols)};
      for (size_t col : samples) {
        const TextPosition pos {line, col};
        size_t left_ci = left.getCharIndexFromPosition(pos);
        size_t right_ci = right.getCharIndexFromPosition(pos);
        CHECK(left_ci == right_ci);
        TextPosition left_pos = left.getPositionFromCharIndex(left_ci);
        TextPosition right_pos = right.getPositionFromCharIndex(right_ci);
        CHECK(left_pos.line == right_pos.line);
        CHECK(left_pos.column == right_pos.column);
      }
    }
  }
}

TEST_CASE("LineArrayDocument and PieceTableDocument stay equivalent after mixed edits") {
  LineArrayDocument line_doc("ab\ncd\nef");
  PieceTableDocument piece_doc("ab\ncd\nef");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({1, 1}, "\xE4\xB8\xAD");
  piece_doc.insertU8Text({1, 1}, "\xE4\xB8\xAD");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({2, 2}, "X\nY");
  piece_doc.insertU8Text({2, 2}, "X\nY");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 1}, {1, 2}}, "\xF0\x9F\x99\x82\nQ");
  piece_doc.replaceU8Text({{0, 1}, {1, 2}}, "\xF0\x9F\x99\x82\nQ");
  checkEquivalent(line_doc, piece_doc);

  line_doc.deleteU8Text({{1, 0}, {2, 1}});
  piece_doc.deleteU8Text({{1, 0}, {2, 1}});
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Replace: same-line partial replacement") {
  LineArrayDocument line_doc("hello world");
  PieceTableDocument piece_doc("hello world");

  line_doc.replaceU8Text({{0, 5}, {0, 11}}, " earth");
  piece_doc.replaceU8Text({{0, 5}, {0, 11}}, " earth");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 0}, {0, 5}}, "Hi");
  piece_doc.replaceU8Text({{0, 0}, {0, 5}}, "Hi");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Replace: single char to single char") {
  LineArrayDocument line_doc("abc");
  PieceTableDocument piece_doc("abc");

  line_doc.replaceU8Text({{0, 1}, {0, 2}}, "X");
  piece_doc.replaceU8Text({{0, 1}, {0, 2}}, "X");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "aXc");
}

TEST_CASE("Replace: cross-line collapse into single line") {
  LineArrayDocument line_doc("aaa\nbbb\nccc\nddd");
  PieceTableDocument piece_doc("aaa\nbbb\nccc\nddd");

  line_doc.replaceU8Text({{0, 2}, {2, 1}}, "X");
  piece_doc.replaceU8Text({{0, 2}, {2, 1}}, "X");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getLineCount() == 2);
}

TEST_CASE("Replace: single line expand into multiple lines") {
  LineArrayDocument line_doc("abcdef");
  PieceTableDocument piece_doc("abcdef");

  line_doc.replaceU8Text({{0, 2}, {0, 4}}, "X\nY\nZ");
  piece_doc.replaceU8Text({{0, 2}, {0, 4}}, "X\nY\nZ");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getLineCount() == 3);
}

TEST_CASE("Replace: cross-line with more lines in replacement") {
  LineArrayDocument line_doc("line1\nline2\nline3");
  PieceTableDocument piece_doc("line1\nline2\nline3");

  line_doc.replaceU8Text({{0, 3}, {2, 2}}, "A\nB\nC\nD");
  piece_doc.replaceU8Text({{0, 3}, {2, 2}}, "A\nB\nC\nD");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Replace: entire document content") {
  LineArrayDocument line_doc("old\ncontent\nhere");
  PieceTableDocument piece_doc("old\ncontent\nhere");

  line_doc.replaceU8Text({{0, 0}, {2, 4}}, "brand new");
  piece_doc.replaceU8Text({{0, 0}, {2, 4}}, "brand new");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getLineCount() == 1);
  CHECK(line_doc.getU8Text() == "brand new");
}

TEST_CASE("Replace: at document start") {
  LineArrayDocument line_doc("abc\ndef");
  PieceTableDocument piece_doc("abc\ndef");

  line_doc.replaceU8Text({{0, 0}, {0, 1}}, "ZZ\n");
  piece_doc.replaceU8Text({{0, 0}, {0, 1}}, "ZZ\n");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Replace: at document end") {
  LineArrayDocument line_doc("abc\ndef");
  PieceTableDocument piece_doc("abc\ndef");

  line_doc.replaceU8Text({{1, 2}, {1, 3}}, "GH\nIJ");
  piece_doc.replaceU8Text({{1, 2}, {1, 3}}, "GH\nIJ");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Edge case: empty document insert") {
  LineArrayDocument line_doc("");
  PieceTableDocument piece_doc("");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({0, 0}, "hello");
  piece_doc.insertU8Text({0, 0}, "hello");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Edge case: single character document operations") {
  LineArrayDocument line_doc("x");
  PieceTableDocument piece_doc("x");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 0}, {0, 1}}, "AB\nCD");
  piece_doc.replaceU8Text({{0, 0}, {0, 1}}, "AB\nCD");
  checkEquivalent(line_doc, piece_doc);

  line_doc.deleteU8Text({{0, 0}, {1, 2}});
  piece_doc.deleteU8Text({{0, 0}, {1, 2}});
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "");
}

TEST_CASE("Edge case: delete everything then insert") {
  LineArrayDocument line_doc("foo\nbar\nbaz");
  PieceTableDocument piece_doc("foo\nbar\nbaz");

  line_doc.deleteU8Text({{0, 0}, {2, 3}});
  piece_doc.deleteU8Text({{0, 0}, {2, 3}});
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({0, 0}, "new\ntext");
  piece_doc.insertU8Text({0, 0}, "new\ntext");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Edge case: insert at line boundary (between \\n and next char)") {
  LineArrayDocument line_doc("aa\nbb");
  PieceTableDocument piece_doc("aa\nbb");

  line_doc.insertU8Text({1, 0}, "CC");
  piece_doc.insertU8Text({1, 0}, "CC");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "aa\nCCbb");
}

TEST_CASE("Mixed line endings: CRLF and LF") {
  LineArrayDocument line_doc("aaa\r\nbbb\nccc\r\nddd");
  PieceTableDocument piece_doc("aaa\r\nbbb\nccc\r\nddd");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({1, 1}, "X");
  piece_doc.insertU8Text({1, 1}, "X");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 2}, {1, 2}}, "R\nS");
  piece_doc.replaceU8Text({{0, 2}, {1, 2}}, "R\nS");
  checkEquivalent(line_doc, piece_doc);

  line_doc.deleteU8Text({{1, 0}, {2, 1}});
  piece_doc.deleteU8Text({{1, 0}, {2, 1}});
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Mixed line endings: CR only") {
  LineArrayDocument line_doc("aa\rbb\rcc");
  PieceTableDocument piece_doc("aa\rbb\rcc");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 1}, {2, 0}}, "NEW\n");
  piece_doc.replaceU8Text({{0, 1}, {2, 0}}, "NEW\n");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Unicode: Chinese characters insert and replace") {
  // "\xe4\xb8\xad\xe6\x96\x87" = "中文", "\xe6\xb5\x8b\xe8\xaf\x95" = "测试"
  LineArrayDocument line_doc("\xe4\xb8\xad\xe6\x96\x87\n\xe6\xb5\x8b\xe8\xaf\x95");
  PieceTableDocument piece_doc("\xe4\xb8\xad\xe6\x96\x87\n\xe6\xb5\x8b\xe8\xaf\x95");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({0, 1}, "ABC");
  piece_doc.insertU8Text({0, 1}, "ABC");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 0}, {0, 2}}, "\xe5\xa5\xbd");  // "好"
  piece_doc.replaceU8Text({{0, 0}, {0, 2}}, "\xe5\xa5\xbd");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 0}, {1, 2}}, "\xe4\xb8\x80\n\xe4\xba\x8c\n\xe4\xb8\x89");  // "一\n二\n三"
  piece_doc.replaceU8Text({{0, 0}, {1, 2}}, "\xe4\xb8\x80\n\xe4\xba\x8c\n\xe4\xb8\x89");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Unicode: emoji (4-byte UTF-8 / surrogate pairs)") {
  // "\xf0\x9f\x98\x80" = 😀, "\xf0\x9f\x8e\x89" = 🎉
  LineArrayDocument line_doc("A\xf0\x9f\x98\x80" "B\nCD");
  PieceTableDocument piece_doc("A\xf0\x9f\x98\x80" "B\nCD");
  checkEquivalent(line_doc, piece_doc);

  // Emoji is 2 UTF-16 code units (surrogate pair), so column 1-3 covers the emoji
  line_doc.replaceU8Text({{0, 1}, {0, 3}}, "\xf0\x9f\x8e\x89\xf0\x9f\x8e\x89");
  piece_doc.replaceU8Text({{0, 1}, {0, 3}}, "\xf0\x9f\x8e\x89\xf0\x9f\x8e\x89");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Unicode: mixed ASCII, CJK, and emoji") {
  LineArrayDocument line_doc("Hi\xe4\xb8\x96\xe7\x95\x8c\xf0\x9f\x8c\x8d\nEnd");  // "Hi世界🌍\nEnd"
  PieceTableDocument piece_doc("Hi\xe4\xb8\x96\xe7\x95\x8c\xf0\x9f\x8c\x8d\nEnd");
  checkEquivalent(line_doc, piece_doc);

  line_doc.replaceU8Text({{0, 2}, {0, 4}}, "AB");
  piece_doc.replaceU8Text({{0, 2}, {0, 4}}, "AB");
  checkEquivalent(line_doc, piece_doc);

  line_doc.insertU8Text({1, 1}, "\xf0\x9f\x98\x8e");  // 😎
  piece_doc.insertU8Text({1, 1}, "\xf0\x9f\x98\x8e");
  checkEquivalent(line_doc, piece_doc);
}

TEST_CASE("Accumulated edits: many sequential operations") {
  LineArrayDocument line_doc("start\n");
  PieceTableDocument piece_doc("start\n");
  checkEquivalent(line_doc, piece_doc);

  for (int i = 0; i < 20; ++i) {
    U8String num = std::to_string(i);
    size_t lc = line_doc.getLineCount();
    line_doc.insertU8Text({lc - 1, 0}, num + "\n");
    piece_doc.insertU8Text({lc - 1, 0}, num + "\n");
  }
  checkEquivalent(line_doc, piece_doc);

  for (int i = 0; i < 10; ++i) {
    size_t lc = line_doc.getLineCount();
    if (lc < 3) break;
    line_doc.deleteU8Text({{1, 0}, {2, 0}});
    piece_doc.deleteU8Text({{1, 0}, {2, 0}});
  }
  checkEquivalent(line_doc, piece_doc);

  for (int i = 0; i < 5; ++i) {
    U8String replacement = "R" + std::to_string(i) + "\nS" + std::to_string(i);
    size_t lc = line_doc.getLineCount();
    if (lc < 2) break;
    size_t last = lc - 1;
    uint32_t cols = line_doc.getLineColumns(last);
    size_t end_col = cols > 0 ? 1 : 0;
    line_doc.replaceU8Text({{last, 0}, {last, end_col}}, replacement);
    piece_doc.replaceU8Text({{last, 0}, {last, end_col}}, replacement);
    checkEquivalent(line_doc, piece_doc);
  }
}

TEST_CASE("Replace: replace with identical text (no-op content)") {
  LineArrayDocument line_doc("abc\ndef");
  PieceTableDocument piece_doc("abc\ndef");

  line_doc.replaceU8Text({{0, 1}, {0, 2}}, "b");
  piece_doc.replaceU8Text({{0, 1}, {0, 2}}, "b");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "abc\ndef");
}

TEST_CASE("Replace: empty range (pure insert via replace)") {
  LineArrayDocument line_doc("abc");
  PieceTableDocument piece_doc("abc");

  line_doc.replaceU8Text({{0, 1}, {0, 1}}, "XY");
  piece_doc.replaceU8Text({{0, 1}, {0, 1}}, "XY");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "aXYbc");
}

TEST_CASE("Replace: non-empty range with empty text (pure delete via replace)") {
  LineArrayDocument line_doc("abcdef");
  PieceTableDocument piece_doc("abcdef");

  line_doc.replaceU8Text({{0, 2}, {0, 4}}, "");
  piece_doc.replaceU8Text({{0, 2}, {0, 4}}, "");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getU8Text() == "abef");
}

TEST_CASE("Replace: delete line ending to merge lines") {
  LineArrayDocument line_doc("abc\ndef\nghi");
  PieceTableDocument piece_doc("abc\ndef\nghi");

  line_doc.replaceU8Text({{0, 3}, {1, 0}}, "");
  piece_doc.replaceU8Text({{0, 3}, {1, 0}}, "");
  checkEquivalent(line_doc, piece_doc);
  CHECK(line_doc.getLineCount() == 2);
  CHECK(line_doc.getU8Text() == "abcdef\nghi");
}

TEST_CASE("Document range extraction honors UTF-16 surrogate boundaries") {
  LineArrayDocument line_doc("A\xf0\x9f\x98\x80" "B\n\xe4\xb8\xad\xf0\x9f\x98\x80x");
  PieceTableDocument piece_doc("A\xf0\x9f\x98\x80" "B\n\xe4\xb8\xad\xf0\x9f\x98\x80x");

  CHECK(line_doc.getU8Text({{0, 0}, {0, 1}}) == "A");
  CHECK(piece_doc.getU8Text({{0, 0}, {0, 1}}) == "A");
  CHECK(line_doc.getU8Text({{0, 1}, {0, 3}}) == "\xf0\x9f\x98\x80");
  CHECK(piece_doc.getU8Text({{0, 1}, {0, 3}}) == "\xf0\x9f\x98\x80");
  CHECK(line_doc.getU8Text({{0, 3}, {0, 4}}) == "B");
  CHECK(piece_doc.getU8Text({{0, 3}, {0, 4}}) == "B");

  CHECK(line_doc.getU8Text({{1, 0}, {1, 1}}) == "\xe4\xb8\xad");
  CHECK(piece_doc.getU8Text({{1, 0}, {1, 1}}) == "\xe4\xb8\xad");
  CHECK(line_doc.getU8Text({{1, 1}, {1, 3}}) == "\xf0\x9f\x98\x80");
  CHECK(piece_doc.getU8Text({{1, 1}, {1, 3}}) == "\xf0\x9f\x98\x80");
  CHECK(line_doc.getU8Text({{1, 3}, {1, 4}}) == "x");
  CHECK(piece_doc.getU8Text({{1, 3}, {1, 4}}) == "x");
}
