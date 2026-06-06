#ifndef SWEETEDITOR_TEST_TEXT_HELPERS_H
#define SWEETEDITOR_TEST_TEXT_HELPERS_H

#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {

  inline U8String makeRepeatedLines(size_t line_count, const U8String& line_text) {
    U8String out;
    out.reserve((line_text.size() + 1) * line_count);
    for (size_t i = 0; i < line_count; ++i) {
      if (i > 0) out += "\n";
      out += line_text;
    }
    return out;
  }

}

#endif // SWEETEDITOR_TEST_TEXT_HELPERS_H
