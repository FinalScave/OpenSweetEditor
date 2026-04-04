//
// Created by Scave on 2025/12/6.
//

#ifndef SWEETEDITOR_UTILITY_H
#define SWEETEDITOR_UTILITY_H

#include <cstdint>
#include <foundation.h>
#include <macro.h>

namespace NS_SWEETEDITOR {
  class TimeUtil {
  public:
    TimeUtil() = delete;
    TimeUtil(const TimeUtil&) = delete;
    TimeUtil& operator=(const TimeUtil&) = delete;

    /// Get current monotonic clock timestamp in milliseconds (steady_clock, not affected by system time changes)
    static int64_t milliTime();

    /// Get current monotonic clock timestamp in microseconds
    static int64_t microTime();

    /// Get current monotonic clock timestamp in nanoseconds
    static int64_t nanoTime();
  };

  class StrUtil {
  public:
    /// printf-style string formatting, returns UTF-8 string
    /// @param format printf format string
    /// @return Formatted output string
    static U8String formatString(const char* format, ...);

    /// Formatting variant that accepts va_list, used for internal variadic forwarding
    /// @param format printf format string
    /// @param args Variadic argument list
    /// @return Formatted output string
    static U8String vFormatString(const char* format, va_list args);

    /// Convert UTF-8 text to UTF-16 and write result into output reference
    static void convertUTF8ToUTF16(const U8String& utf8_str, U16String& result);

    /// Convert UTF-8 text to UTF-16, heap-allocate a null-terminated U16Char array
    /// @note Caller must release *result with delete[]
    static void convertUTF8ToUTF16(const U8String& utf8_str, U16Char** result);

    /// Convert UTF-16 text to UTF-8 and write result into output reference
    static void convertUTF16ToUTF8(const U16String& utf16_str, U8String& result);

    /// Heap-allocate a copy of a UTF-16 string for C-style APIs that need longer lifetime data
    /// @note Caller must release the returned pointer with delete[]
    static U16Char* allocU16Chars(const U16String& utf16_str);
  };

  class UnicodeUtil {
  public:
    /// Whether the UTF-16 code unit is a lead surrogate.
    static bool isLeadSurrogate(U16Char ch);

    /// Whether the UTF-16 code unit is a trail surrogate.
    static bool isTrailSurrogate(U16Char ch);

    /// Whether the given UTF-16 column is on a code-point boundary.
    static bool isCodePointBoundary(const U16String& text, size_t column);

    /// Clamp the column to a valid code-point boundary, preferring the left side.
    static size_t clampColumnToCodePointBoundary(const U16String& text, size_t column);

    /// Clamp the column to a valid code-point boundary on the left side.
    static size_t clampColumnToCodePointBoundaryLeft(const U16String& text, size_t column);

    /// Clamp the column to a valid code-point boundary on the right side.
    static size_t clampColumnToCodePointBoundaryRight(const U16String& text, size_t column);

    /// Move to the previous code-point boundary.
    static size_t prevCodePointColumn(const U16String& text, size_t column);

    /// Move to the next code-point boundary.
    static size_t nextCodePointColumn(const U16String& text, size_t column);

    /// Clamp the column to a valid grapheme boundary on the left side.
    static size_t clampColumnToGraphemeBoundaryLeft(const U16String& text, size_t column);

    /// Clamp the column to a valid grapheme boundary on the right side.
    static size_t clampColumnToGraphemeBoundaryRight(const U16String& text, size_t column);

    /// Move to the previous grapheme boundary.
    static size_t prevGraphemeBoundaryColumn(const U16String& text, size_t column);

    /// Move to the next grapheme boundary.
    static size_t nextGraphemeBoundaryColumn(const U16String& text, size_t column);

    /// Whether the text contains complex grapheme sequences that should avoid UTF-16-unit-based monospace shortcuts.
    static bool hasComplexGrapheme(const U16String& text);

    /// Clamp a same-line range to valid code-point boundaries.
    static TextRange clampRangeToCodePointBoundary(const U16String& text, const TextRange& range);
  };
}

#endif //SWEETEDITOR_UTILITY_H
