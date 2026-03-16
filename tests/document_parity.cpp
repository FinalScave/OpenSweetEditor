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

      const size_t mid_col = left_cols / 2;
      const size_t samples[] = {0, mid_col, static_cast<size_t>(left_cols)};
      for (size_t col : samples) {
        const TextPosition pos {line, col};
        CHECK(left.getCharIndexFromPosition(pos) == right.getCharIndexFromPosition(pos));
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
