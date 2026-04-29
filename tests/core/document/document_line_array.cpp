#include <catch2/catch_amalgamated.hpp>
#include "document.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("LineArrayDocument applies replace insert and delete deterministically") {
  LineArrayDocument document("alpha\nbeta\ngamma");

  // "alpha" -> replace [1,4) with "X" => "aXa"
  document.replaceU8Text({{0, 1}, {0, 4}}, "X");
  CHECK(document.getU8Text() == "aXa\nbeta\ngamma");

  // "beta" tail append
  document.insertU8Text({1, 4}, "-1");
  CHECK(document.getU8Text() == "aXa\nbeta-1\ngamma");

  // Cross-line delete: remove "a\nbe"
  document.deleteU8Text({{0, 2}, {1, 2}});
  CHECK(document.getU8Text() == "aXta-1\ngamma");
  CHECK(document.getLineCount() == 2);
  CHECK(document.getLineColumns(0) == 6);
  CHECK(document.getLineColumns(1) == 5);
}
