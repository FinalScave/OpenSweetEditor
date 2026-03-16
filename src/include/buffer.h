//
// Created by Scave on 2025/12/4.
//

#ifndef SWEETEDITOR_BUFFER_H
#define SWEETEDITOR_BUFFER_H

#ifdef _WIN32
#include <windows.h>
#endif
#include "macro.h"

namespace NS_SWEETEDITOR {
  /// Base data source class (for in-memory string, file mapping, etc.)
  class Buffer {
  public:
    virtual ~Buffer() = default;
    virtual const char* data() const = 0;
    virtual size_t size() const = 0;
    virtual char operator[](size_t index) const = 0;

    template<typename Func, typename = std::enable_if_t<kIsLambdaWithSignature<Func, void, const char&>>>
    void forEachByte(Func&& consumer) {
      const size_t byte_size = size();
      const char* byte_data = this->data();
      for (size_t i = 0; i < byte_size; ++i) {
        std::forward<Func>(consumer)(byte_data[i]);
      }
    }
  };

  /// UTF-8 string buffer (readable and writable)
  class U8StringBuffer : public Buffer {
  public:
    U8StringBuffer();
    U8StringBuffer(U8String&& str);
    U8StringBuffer(const U8String& str);
    const char* data() const override;
    size_t size() const override;
    char operator[](size_t index) const override;

    void append(const U8String& text);
    size_t currentEnd() const;
  private:
    U8String m_string_buf_;
  };

	/// File memory-mapped buffer implementation (read-only)
  class MappedFileBuffer : public Buffer {
  public:
    MappedFileBuffer(const U8String& path);
    ~MappedFileBuffer() override;

    const char* data() const override;
    size_t size() const override;
    char operator[](size_t index) const override;
    bool isValid() const;
  private:
    char* m_data_ = nullptr;
    size_t m_size_ = 0;
#ifdef _WIN32
    HANDLE m_file_handle_ = INVALID_HANDLE_VALUE;
    HANDLE m_map_ = NULL;
#else
    int m_fd_ = -1;
#endif
  };
}

#endif //SWEETEDITOR_BUFFER_H
