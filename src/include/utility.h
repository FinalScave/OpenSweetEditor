//
// Created by Scave on 2025/12/6.
//

#ifndef SWEETEDITOR_UTILITY_H
#define SWEETEDITOR_UTILITY_H

#include <cstdint>
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
}

#endif //SWEETEDITOR_UTILITY_H
