//
// Created by Scave on 2025/12/7.
//

#ifndef SWEETEDITOR_LOGGING_H
#define SWEETEDITOR_LOGGING_H

#if defined(_MSC_VER) && !defined(__FILE_NAME__)
#define __FILE_NAME__ (strrchr("\\" __FILE__, '\\') + 1)
#endif

#ifdef ENABLE_LOG
  #define LOG_TAG "SWEETEDITOR"
#include "buffer.h"
#if defined(ANDROID)
    #include "android_log.h"
  #elif defined(OHOS)
    #include "ohos_log.h"
  #elif defined(__APPLE__)
    #include <os/log.h>
    #include "utility.h"
    #define APPLE_LOG_FORMAT "[%{public}s][%{public}s] \"%{public}s\"-%{public}s:%d %{public}s"
    #define APPLE_LOG(level, type, ...) do { \
      auto _log_message_ = StrUtil::formatString(__VA_ARGS__); \
      os_log_with_type(OS_LOG_DEFAULT, type, APPLE_LOG_FORMAT, level, LOG_TAG, __FILE_NAME__, __FUNCTION__, __LINE__, _log_message_.c_str()); \
    } while(0)
    #define LOGD(...) APPLE_LOG("D", OS_LOG_TYPE_DEBUG, __VA_ARGS__)
    #define LOGI(...) APPLE_LOG("I", OS_LOG_TYPE_INFO, __VA_ARGS__)
    #define LOGW(...) APPLE_LOG("W", OS_LOG_TYPE_DEFAULT, __VA_ARGS__)
    #define LOGE(...) APPLE_LOG("E", OS_LOG_TYPE_ERROR, __VA_ARGS__)
  #elif defined(_WIN32) || defined(_WIN64)
    #include <debugapi.h>
    #include "utility.h"
    #define LOG_FMT "[%s][%s] \"%s\"-%s:%d %s"
    #define LOG(level, ...) OutputDebugString(StrUtil::formatString(LOG_FMT, level, LOG_TAG, __FILE_NAME__, __FUNCTION__, __LINE__, StrUtil::formatString(__VA_ARGS__)).c_str())
    #define LOGD(...) LOG("D", __VA_ARGS__)
    #define LOGI(...) LOG("I", __VA_ARGS__)
    #define LOGW(...) LOG("W", __VA_ARGS__)
    #define LOGE(...) LOG("E", __VA_ARGS__)
  #else
    #include <iostream>
    #include "utility.h"
    #define LOG(level, ...) std::cout << "[" << level << "][" << LOG_TAG << "] \"" << __FILE_NAME__ << "\"-" << __FUNCTION__ << ":" << __LINE__ << " " << StrUtil::formatString(__VA_ARGS__) << std::endl;
    #define LOGD(...) LOG("D", __VA_ARGS__)
    #define LOGI(...) LOG("I", __VA_ARGS__)
    #define LOGW(...) LOG("W", __VA_ARGS__)
    #define LOGE(...) LOG("E", __VA_ARGS__)
  #endif
#else
  #define LOGD(...)
  #define LOGI(...)
  #define LOGW(...)
  #define LOGE(...)
#endif


#ifdef ENABLE_PERF_LOG
  #include <chrono>
  #include <cstdio>

  #if defined(ANDROID)
    #include <android/log.h>
    #define PERF_LOG_PRINT(fmt, ...) __android_log_print(ANDROID_LOG_INFO, "SWEETEDITOR", fmt, ##__VA_ARGS__)
  #elif defined(__APPLE__)
    #include <os/log.h>
    inline void _perf_log_print(const char* fmt, ...) {
      char buf[512];
      va_list args;
      va_start(args, fmt);
      vsnprintf(buf, sizeof(buf), fmt, args);
      va_end(args);
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "%{public}s", buf);
    }
    #define PERF_LOG_PRINT(fmt, ...) _perf_log_print(fmt, ##__VA_ARGS__)
  #elif defined(_WIN32) || defined(_WIN64)
    #include <debugapi.h>
    inline void _perf_log_print(const char* fmt, ...) {
      char buf[512];
      va_list args;
      va_start(args, fmt);
      vsnprintf(buf, sizeof(buf), fmt, args);
      va_end(args);
      OutputDebugStringA(buf);
      OutputDebugStringA("\n");
    }
    #define PERF_LOG_PRINT(fmt, ...) _perf_log_print(fmt, ##__VA_ARGS__)
  #else
    #define PERF_LOG_PRINT(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)
  #endif

  class ScopedTimer {
  public:
    ScopedTimer(const char* label)
      : m_label_(label), m_start_(std::chrono::high_resolution_clock::now()) {}

    ~ScopedTimer() {
      auto end = std::chrono::high_resolution_clock::now();
      auto us = std::chrono::duration_cast<std::chrono::microseconds>(end - m_start_).count();
      if (us >= 1000) {
        PERF_LOG_PRINT("[PERF] %s: %.2f ms", m_label_, us / 1000.0);
      } else {
        PERF_LOG_PRINT("[PERF] %s: %lld us", m_label_, (long long)us);
      }
    }

    int64_t elapsedMicros() const {
      auto now = std::chrono::high_resolution_clock::now();
      return std::chrono::duration_cast<std::chrono::microseconds>(now - m_start_).count();
    }

  private:
    const char* m_label_;
    std::chrono::high_resolution_clock::time_point m_start_;
  };

  /// Insert timing log in current scope, auto-print at scope end
  #define PERF_TIMER(label) ScopedTimer _scoped_timer_##__LINE__(label)
  /// Start timing manually
  #define PERF_BEGIN(name) auto _perf_start_##name = std::chrono::high_resolution_clock::now()
  /// End timing manually and print
  #define PERF_END(name, label) do { \
    auto _perf_end_##name = std::chrono::high_resolution_clock::now(); \
    auto _perf_us_##name = std::chrono::duration_cast<std::chrono::microseconds>(_perf_end_##name - _perf_start_##name).count(); \
    if (_perf_us_##name >= 1000) { \
      PERF_LOG_PRINT("[PERF] %s: %.2f ms", label, _perf_us_##name / 1000.0); \
    } else { \
      PERF_LOG_PRINT("[PERF] %s: %lld us", label, (long long)_perf_us_##name); \
    } \
  } while(0)
#else
  #define PERF_TIMER(label)
  #define PERF_BEGIN(name)
  #define PERF_END(name, label)
#endif

#endif //SWEETEDITOR_LOGGING_H
