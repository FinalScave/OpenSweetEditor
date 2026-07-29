#ifndef SWEETEDITOR_TEXT_EDIT_UTILS_HPP
#define SWEETEDITOR_TEXT_EDIT_UTILS_HPP

#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR::TextEditUtils {

  enum class PositionBias {
    BEFORE,
    AFTER,
  };

  TextPosition positionAfterText(const TextPosition& start, const U8String& text);

  TextPosition transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                 const TextPosition& position, PositionBias bias);

}

#endif // SWEETEDITOR_TEXT_EDIT_UTILS_HPP
