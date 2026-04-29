#include <catch2/catch_amalgamated.hpp>
#include "document.h"

using namespace NS_SWEETEDITOR;

TEST_CASE("LineArrayDocument replace benchmark") {
  static const char* text = "line1\nline2\nline3";
  BENCHMARK("Replace Performance") {
    LineArrayDocument document(text);
    TextRange range = {{1, 0}, {1, 1}};
    document.replaceU8Text(range, "H");
  };
}
