//
// Created by Scave on 2026/6/6.
//
#ifndef SWEETEDITOR_TEXT_BOUNDARY_HPP
#define SWEETEDITOR_TEXT_BOUNDARY_HPP

#include <algorithm>
#include <sweeteditor/utility.h>

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

    inline bool isSourceWhitespace(U16Char ch) {
      return ch == CHAR16(' ') || ch == CHAR16('\t');
    }

    inline size_t leadingWhitespaceEndColumn(const U16String& text) {
      size_t column = 0;
      while (column < text.length() && isSourceWhitespace(text[column])) {
        ++column;
      }
      return column;
    }

    inline size_t trailingWhitespaceStartColumn(const U16String& text) {
      size_t column = text.length();
      while (column > 0 && isSourceWhitespace(text[column - 1])) {
        --column;
      }
      return column;
    }

    inline TextRange findWordRangeInLine(size_t line, const U16String& line_text, size_t anchor_column) {
      if (line_text.empty()) {
        return {{line, 0}, {line, 0}};
      }

      size_t anchor = std::min(anchor_column, line_text.length());
      if (anchor >= line_text.length()) {
        anchor = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, line_text.length());
      }

      const U16Char anchor_ch = line_text[anchor];
      const bool is_word = isWordChar(anchor_ch);

      size_t word_start = anchor;
      while (word_start > 0) {
        size_t previous = UnicodeUtil::prevGraphemeBoundaryColumn(line_text, word_start);
        if (previous == word_start) break;

        U16Char prev_ch = line_text[previous];
        if (is_word ? !isWordChar(prev_ch) : isWordChar(prev_ch)) break;
        if (!is_word && prev_ch != anchor_ch) break;
        word_start = previous;
      }

      size_t word_end = UnicodeUtil::nextGraphemeBoundaryColumn(line_text, anchor);
      while (word_end < line_text.length()) {
        U16Char next_ch = line_text[word_end];
        if (is_word ? !isWordChar(next_ch) : isWordChar(next_ch)) break;
        if (!is_word && next_ch != anchor_ch) break;

        size_t next_boundary = UnicodeUtil::nextGraphemeBoundaryColumn(line_text, word_end);
        if (next_boundary <= word_end) break;
        word_end = next_boundary;
      }

      return {{line, word_start}, {line, word_end}};
    }
  }
}

#endif //SWEETEDITOR_TEXT_BOUNDARY_HPP
