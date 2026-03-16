//
// Created by Scave on 2025/12/4.
//
#ifndef _WIN32
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif

#include <buffer.h>

namespace NS_SWEETEDITOR {
#pragma region [Class: U8StringBuffer]
	U8StringBuffer::U8StringBuffer(): m_string_buf_({}) {
	}

	U8StringBuffer::U8StringBuffer(U8String&& str): m_string_buf_(std::move(str)) {
	}

	U8StringBuffer::U8StringBuffer(const U8String& str): m_string_buf_(str) {
	}

	const char* U8StringBuffer::data() const {
		return m_string_buf_.c_str();
	}

	size_t U8StringBuffer::size() const {
		return m_string_buf_.size();
	}

	char U8StringBuffer::operator[](size_t index) const {
		return m_string_buf_[index];
	}

	void U8StringBuffer::append(const U8String& text) {
		m_string_buf_.append(text);
	}

	size_t U8StringBuffer::currentEnd() const {
		return m_string_buf_.size();
	}
#pragma endregion

#pragma region [Class: MappedFileBuffer]
	MappedFileBuffer::MappedFileBuffer(const U8String& path) {
#ifdef _WIN32
		m_file_handle_ = CreateFileA(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
		if (m_file_handle_ == INVALID_HANDLE_VALUE) {
			return;
		}
		m_size_ = GetFileSize(m_file_handle_, NULL);
		m_map_ = CreateFileMappingA(m_file_handle_, NULL, PAGE_READONLY, 0, 0, NULL);
		if (m_map_) {
			m_data_ = (char*)MapViewOfFile(m_map_, FILE_MAP_READ, 0, 0, 0);
		}
#else
		m_fd_ = open(path.c_str(), O_RDONLY);
		if (m_fd_ == -1) {
			return;
		}
		struct stat sb;
		if (fstat(m_fd_, &sb) != -1) {
			m_size_ = sb.st_size;
			m_data_ = (char*)mmap(nullptr, m_size_, PROT_READ, MAP_PRIVATE, m_fd_, 0);
			if (m_data_ == MAP_FAILED) {
				m_data_ = nullptr;
			}
		}
#endif
	}

	MappedFileBuffer::~MappedFileBuffer() {
#ifdef _WIN32
		if (m_data_) {
			UnmapViewOfFile(m_data_);
		}
		if (m_map_) {
			CloseHandle(m_map_);
		}
		if (m_file_handle_ != INVALID_HANDLE_VALUE) {
			CloseHandle(m_file_handle_);
		}
#else
		if (m_data_) {
			munmap(m_data_, m_size_);
		}
		if (m_fd_ != -1) {
			close(m_fd_);
		}
#endif
	}

	const char* MappedFileBuffer::data() const {
		return m_data_;
	}

	size_t MappedFileBuffer::size() const {
		return m_size_;
	}

	char MappedFileBuffer::operator[](size_t index) const {
		return m_data_ ? m_data_[index] : 0;
	}

	bool MappedFileBuffer::isValid() const {
		return m_data_ != nullptr;
	}
#pragma endregion
} // NS_SWEETEDITOR
