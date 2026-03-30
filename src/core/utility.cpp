//
// Created by Scave on 2025/12/6.
//
#include <chrono>
#include <cstdarg>
#include <cstring>
#include <simdutf/simdutf.h>
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
    if (utf8_str.empty()) {
      result.clear();
      return;
    }

    if (!simdutf::validate_utf8(utf8_str.c_str(), utf8_str.length())) {
      result.clear();
      return;
    }

    size_t utf16_len = simdutf::utf16_length_from_utf8(utf8_str.c_str(), utf8_str.length());
    result.resize(utf16_len);
    size_t written = simdutf::convert_utf8_to_utf16(
      utf8_str.c_str(),
      utf8_str.length(),
      CHAR16_PTR(result.data())
    );
    if (written < utf16_len) {
      result.resize(written);
    }
  }

  void StrUtil::convertUTF8ToUTF16(const U8String& utf8_str, U16Char** result) {
    if (result == nullptr) {
      return;
    }

    if (utf8_str.empty()) {
      *result = new U16Char[1];
      (*result)[0] = 0;
      return;
    }

    if (!simdutf::validate_utf8(utf8_str.c_str(), utf8_str.length())) {
      *result = new U16Char[1];
      (*result)[0] = 0;
      return;
    }

    size_t utf16_len = simdutf::utf16_length_from_utf8(utf8_str.c_str(), utf8_str.length());
    *result = new U16Char[utf16_len + 1];
    size_t written = simdutf::convert_utf8_to_utf16(
      utf8_str.c_str(),
      utf8_str.length(),
      CHAR16_PTR(*result)
    );
    if (written > utf16_len) {
      written = utf16_len;
    }
    (*result)[written] = 0;
  }

  void StrUtil::convertUTF16ToUTF8(const U16String& utf16_str, U8String& result) {
    if (utf16_str.empty()) {
      result.clear();
      return;
    }

    if (!simdutf::validate_utf16(CHAR16_PTR(utf16_str.c_str()), utf16_str.length())) {
      result.clear();
      return;
    }

    size_t utf8_len = simdutf::utf8_length_from_utf16(CHAR16_PTR(utf16_str.c_str()), utf16_str.length());
    result.resize(utf8_len);
    size_t written = simdutf::convert_utf16_to_utf8(
      CHAR16_PTR(utf16_str.c_str()),
      utf16_str.length(),
      result.data()
    );
    if (written < utf8_len) {
      result.resize(written);
    }
  }

  U16Char* StrUtil::allocU16Chars(const U16String& utf16_str) {
    size_t length = utf16_str.length();
    U16Char* result = new U16Char[length + 1];
    std::memcpy(result, utf16_str.c_str(), length * sizeof(U16Char));
    result[length] = 0;
    return result;
  }
#pragma endregion
}
