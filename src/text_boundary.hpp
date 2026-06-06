//
// Created by Scave on 2026/6/6.
//
#ifndef SWEETEDITOR_TEXT_BOUNDARY_HPP
#define SWEETEDITOR_TEXT_BOUNDARY_HPP

#include <sweeteditor/foundation.h>

namespace NS_SWEETEDITOR {
  namespace TextBoundaryUtil {
    inline bool isWordChar(U16Char ch) {
      return (ch >= CHAR16('a') && ch <= CHAR16('z')) ||
             (ch >= CHAR16('A') && ch <= CHAR16('Z')) ||
             (ch >= CHAR16('0') && ch <= CHAR16('9')) ||
             ch == CHAR16('_') ||
             ch > 0x7F;
    }

    inline bool isWordWrapBreakChar(U16Char ch) {
      return ch == CHAR16(' ') || ch == CHAR16('\t') ||
             ch == CHAR16('-') || ch == CHAR16('/') ||
             ch == CHAR16('\\') || ch == CHAR16('.') ||
             ch == CHAR16(',') || ch == CHAR16(';') ||
             ch == CHAR16(':') || ch == CHAR16('!') ||
             ch == CHAR16('?') || ch == CHAR16(')') ||
             ch == CHAR16(']') || ch == CHAR16('}') ||
             ch == CHAR16('>');
    }
  }
}

#endif //SWEETEDITOR_TEXT_BOUNDARY_HPP
