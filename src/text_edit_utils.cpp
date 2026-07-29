#include "text_edit_utils.hpp"
#include <utf8/utf8.h>

namespace NS_SWEETEDITOR::TextEditUtils {

  TextPosition positionAfterText(const TextPosition& start, const U8String& text) {
    TextPosition position = start;
    auto it = text.begin();
    while (it != text.end()) {
      const char ch = *it;
      if (ch == '\n') {
        ++position.line;
        position.column = 0;
        ++it;
      } else if (ch == '\r') {
        ++position.line;
        position.column = 0;
        ++it;
        if (it != text.end() && *it == '\n') ++it;
      } else {
        const uint32_t code_point = utf8::next(it, text.end());
        position.column += code_point > 0xFFFF ? 2 : 1;
      }
    }
    return position;
  }

  TextPosition transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                 const TextPosition& position, PositionBias bias) {
    const TextRange range = old_range.normalized();
    if (position < range.start) {
      return position;
    }
    if (range.isCollapsed() && position == range.start) {
      return bias == PositionBias::BEFORE ? range.start : new_end;
    }
    if (position == range.start) {
      return bias == PositionBias::BEFORE ? range.start : new_end;
    }
    if (position < range.end) {
      return bias == PositionBias::BEFORE ? range.start : new_end;
    }
    if (position == range.end) {
      return new_end;
    }
    return range.transformPositionAfterEdit(position, new_end);
  }

}
