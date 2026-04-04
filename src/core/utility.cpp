//
// Created by Scave on 2025/12/6.
//
#include <chrono>
#include <cstdarg>
#include <cstring>
#include <algorithm>
#include <simdutf/simdutf.h>
#include <utf8/utf8.h>
#include <utility.h>

namespace NS_SWEETEDITOR {
#pragma region [Class: TimeUtil]
  int64_t TimeUtil::milliTime() {
    auto now = std::chrono::high_resolution_clock::now();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
  }

  int64_t TimeUtil::microTime() {
    auto now = std::chrono::high_resolution_clock::now();
    return std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch()).count();
  }

  int64_t TimeUtil::nanoTime() {
    auto now = std::chrono::high_resolution_clock::now();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
  }

#pragma endregion

#pragma region [Class: StrUtil]
  U8String StrUtil::formatString(const char* format, ...) {
    va_list args;
    va_start(args, format);
    U8String result = vFormatString(format, args);
    va_end(args);
    return result;
  }

  U8String StrUtil::vFormatString(const char* format, va_list args) {
    va_list args_copy;
    va_copy(args_copy, args);
    int size = std::vsnprintf(nullptr, 0, format, args_copy);
    va_end(args_copy);

    if (size < 0) return "";
    U8String result(size + 1, '\0');
    std::vsnprintf(result.data(), size + 1, format, args);
    result.resize(size);
    return result;
  }

  void StrUtil::convertUTF8ToUTF16(const U8String& utf8_str, U16String& result) {
    size_t utf16_len = simdutf::utf16_length_from_utf8(utf8_str.c_str(), utf8_str.length());
    result.resize(utf16_len);
    const size_t written =
        simdutf::convert_utf8_to_utf16(utf8_str.c_str(), utf8_str.length(), CHAR16_PTR(result.data()));
    (void)written;
  }

  void StrUtil::convertUTF8ToUTF16(const U8String& utf8_str, U16Char** result) {
    size_t utf16_len = simdutf::utf16_length_from_utf8(utf8_str.c_str(), utf8_str.length());
    *result = new U16Char[utf16_len + 1];
    const size_t written =
        simdutf::convert_utf8_to_utf16(utf8_str.c_str(), utf8_str.length(), CHAR16_PTR(*result));
    (void)written;
    (*result)[utf16_len] = 0;
  }

  void StrUtil::convertUTF16ToUTF8(const U16String& utf16_str, U8String& result) {
    size_t utf8_len = simdutf::utf8_length_from_utf16(CHAR16_PTR(utf16_str.c_str()), utf16_str.length());
    result.resize(utf8_len);
    const size_t written =
        simdutf::convert_utf16_to_utf8(CHAR16_PTR(utf16_str.c_str()), utf16_str.length(), result.data());
    (void)written;
  }

  U16Char* StrUtil::allocU16Chars(const U16String& utf16_str) {
    size_t length = utf16_str.length();
    U16Char* result = new U16Char[length + 1];
    std::memcpy(result, utf16_str.c_str(), length * sizeof(U16Char));
    result[length] = 0;
    return result;
  }
#pragma endregion

#pragma region [Class: UnicodeUtil]
  static utf8::utfchar32_t toUtf16CodeUnit(U16Char ch) {
    return static_cast<utf8::utfchar32_t>(utf8::internal::mask16(ch));
  }

  struct CodePointSpan {
    uint32_t cp {0};
    size_t start {0};
    size_t end {0};
  };

  static uint32_t decodeCodePoint(const U16String& text, size_t start, size_t end) {
    if (start >= text.length() || end <= start) return 0;
    const uint32_t first = static_cast<uint32_t>(toUtf16CodeUnit(text[start]));
    if (end - start == 2 && start + 1 < text.length()) {
      const uint32_t second = static_cast<uint32_t>(toUtf16CodeUnit(text[start + 1]));
      if (UnicodeUtil::isLeadSurrogate(text[start]) && UnicodeUtil::isTrailSurrogate(text[start + 1])) {
        return ((first - 0xD800u) << 10) + (second - 0xDC00u) + 0x10000u;
      }
    }
    return first;
  }

  static bool readCodePointAt(const U16String& text, size_t column, CodePointSpan& out) {
    size_t start = UnicodeUtil::clampColumnToCodePointBoundaryLeft(text, column);
    if (start >= text.length()) return false;
    size_t end = UnicodeUtil::nextCodePointColumn(text, start);
    if (end <= start) return false;
    out.start = start;
    out.end = end;
    out.cp = decodeCodePoint(text, start, end);
    return true;
  }

  static bool isVariationSelector(uint32_t cp) {
    return (cp >= 0xFE00u && cp <= 0xFE0Fu) || (cp >= 0xE0100u && cp <= 0xE01EFu);
  }

  static bool isCombiningMark(uint32_t cp) {
    return (cp >= 0x0300u && cp <= 0x036Fu) ||
           (cp >= 0x1AB0u && cp <= 0x1AFFu) ||
           (cp >= 0x1DC0u && cp <= 0x1DFFu) ||
           (cp >= 0x20D0u && cp <= 0x20FFu) ||
           (cp >= 0xFE20u && cp <= 0xFE2Fu);
  }

  static bool isEmojiModifier(uint32_t cp) {
    return cp >= 0x1F3FBu && cp <= 0x1F3FFu;
  }

  static bool isRegionalIndicator(uint32_t cp) {
    return cp >= 0x1F1E6u && cp <= 0x1F1FFu;
  }

  static bool isZeroWidthJoiner(uint32_t cp) {
    return cp == 0x200Du;
  }

  static bool isGraphemeExtendLike(uint32_t cp) {
    return isCombiningMark(cp) || isVariationSelector(cp) || isEmojiModifier(cp);
  }

  static size_t consumeTrailingGraphemeExtend(const U16String& text, size_t column) {
    size_t cursor = column;
    CodePointSpan span;
    while (readCodePointAt(text, cursor, span) && isGraphemeExtendLike(span.cp)) {
      cursor = span.end;
    }
    return cursor;
  }

  bool UnicodeUtil::isLeadSurrogate(U16Char ch) {
    return utf8::internal::is_lead_surrogate(toUtf16CodeUnit(ch));
  }

  bool UnicodeUtil::isTrailSurrogate(U16Char ch) {
    return utf8::internal::is_trail_surrogate(toUtf16CodeUnit(ch));
  }

  bool UnicodeUtil::isCodePointBoundary(const U16String& text, size_t column) {
    if (column > text.length()) return false;
    if (column == 0 || column == text.length()) return true;
    return !(isTrailSurrogate(text[column]) && isLeadSurrogate(text[column - 1]));
  }

  size_t UnicodeUtil::clampColumnToCodePointBoundary(const U16String& text, size_t column) {
    return clampColumnToCodePointBoundaryLeft(text, column);
  }

  size_t UnicodeUtil::clampColumnToCodePointBoundaryLeft(const U16String& text, size_t column) {
    column = std::min(column, text.length());
    if (column > 0 && column < text.length()
        && isTrailSurrogate(text[column])
        && isLeadSurrogate(text[column - 1])) {
      return column - 1;
    }
    return column;
  }

  size_t UnicodeUtil::clampColumnToCodePointBoundaryRight(const U16String& text, size_t column) {
    column = std::min(column, text.length());
    if (column > 0 && column < text.length()
        && isTrailSurrogate(text[column])
        && isLeadSurrogate(text[column - 1])) {
      return column + 1;
    }
    return column;
  }

  size_t UnicodeUtil::prevCodePointColumn(const U16String& text, size_t column) {
    size_t safe_column = clampColumnToCodePointBoundaryLeft(text, column);
    if (safe_column == 0) return 0;
    if (safe_column >= 2
        && isTrailSurrogate(text[safe_column - 1])
        && isLeadSurrogate(text[safe_column - 2])) {
      return safe_column - 2;
    }
    return safe_column - 1;
  }

  size_t UnicodeUtil::nextCodePointColumn(const U16String& text, size_t column) {
    size_t safe_column = clampColumnToCodePointBoundaryRight(text, column);
    if (safe_column >= text.length()) return text.length();
    if (safe_column + 1 < text.length()
        && isLeadSurrogate(text[safe_column])
        && isTrailSurrogate(text[safe_column + 1])) {
      return safe_column + 2;
    }
    return safe_column + 1;
  }

  size_t UnicodeUtil::nextGraphemeBoundaryColumn(const U16String& text, size_t column) {
    size_t cursor = clampColumnToCodePointBoundaryRight(text, column);
    if (cursor >= text.length()) return text.length();

    CodePointSpan current;
    if (!readCodePointAt(text, cursor, current)) return text.length();

    cursor = current.end;

    if (isRegionalIndicator(current.cp)) {
      CodePointSpan next;
      if (readCodePointAt(text, cursor, next) && isRegionalIndicator(next.cp)) {
        return next.end;
      }
      return cursor;
    }

    cursor = consumeTrailingGraphemeExtend(text, cursor);

    while (true) {
      CodePointSpan zwj;
      if (!readCodePointAt(text, cursor, zwj) || !isZeroWidthJoiner(zwj.cp)) {
        break;
      }

      CodePointSpan next;
      if (!readCodePointAt(text, zwj.end, next)) {
        break;
      }

      cursor = next.end;
      cursor = consumeTrailingGraphemeExtend(text, cursor);
    }

    return cursor;
  }

  size_t UnicodeUtil::clampColumnToGraphemeBoundaryLeft(const U16String& text, size_t column) {
    const size_t target = std::min(text.length(), column);
    size_t previous = 0;
    size_t current = 0;
    while (current < target) {
      previous = current;
      current = nextGraphemeBoundaryColumn(text, current);
      if (current <= previous) break;
    }
    return (current == target) ? current : previous;
  }

  size_t UnicodeUtil::clampColumnToGraphemeBoundaryRight(const U16String& text, size_t column) {
    const size_t target = std::min(text.length(), column);
    size_t current = 0;
    while (current < target) {
      size_t next = nextGraphemeBoundaryColumn(text, current);
      if (next <= current) break;
      current = next;
    }
    return current;
  }

  size_t UnicodeUtil::prevGraphemeBoundaryColumn(const U16String& text, size_t column) {
    const size_t target = clampColumnToCodePointBoundaryLeft(text, column);
    size_t previous = 0;
    size_t current = 0;
    while (current < target) {
      previous = current;
      current = nextGraphemeBoundaryColumn(text, current);
      if (current <= previous) break;
    }
    return previous;
  }

  bool UnicodeUtil::hasComplexGrapheme(const U16String& text) {
    CodePointSpan span;
    size_t cursor = 0;
    while (readCodePointAt(text, cursor, span)) {
      if (span.end - span.start > 1
          || isCombiningMark(span.cp)
          || isVariationSelector(span.cp)
          || isEmojiModifier(span.cp)
          || isRegionalIndicator(span.cp)
          || isZeroWidthJoiner(span.cp)) {
        return true;
      }
      cursor = span.end;
    }
    return false;
  }

  TextRange UnicodeUtil::clampRangeToCodePointBoundary(const U16String& text, const TextRange& range) {
    TextRange safe_range = range;
    safe_range.start.column = clampColumnToCodePointBoundaryLeft(text, safe_range.start.column);
    safe_range.end.column = clampColumnToCodePointBoundaryRight(text, safe_range.end.column);
    return safe_range;
  }
#pragma endregion
}
