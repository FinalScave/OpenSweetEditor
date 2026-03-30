//
// Created by Scave on 2025/12/2.
//
#include <stdexcept>
#include <algorithm>
#include <limits>
#include <simdutf/simdutf.h>
#include <utf8/utf8.h>
#include <document.h>
#include <utility.h>

namespace NS_SWEETEDITOR {
namespace {
  uint32_t clampToUint32(size_t value) {
    constexpr size_t kMaxUint32 = static_cast<size_t>(std::numeric_limits<uint32_t>::max());
    if (value > kMaxUint32) {
      return std::numeric_limits<uint32_t>::max();
    }
    return static_cast<uint32_t>(value);
  }
}

#pragma region [Class: PieceTableDocument]
  PieceTableDocument::PieceTableDocument(U8String&& original_string): m_original_buffer_(makeUPtr<U8StringBuffer>(std::move(original_string))) {
    rebuildBufferSegments();
  }

  PieceTableDocument::PieceTableDocument(const U8String& original_string): m_original_buffer_(makeUPtr<U8StringBuffer>(original_string)) {
    rebuildBufferSegments();
  }

  PieceTableDocument::PieceTableDocument(const U16String& original_string) {
    U8String utf8_text;
    StrUtil::convertUTF16ToUTF8(original_string, utf8_text);
    m_original_buffer_ = makeUPtr<U8StringBuffer>(std::move(utf8_text));
    rebuildBufferSegments();
  }

  PieceTableDocument::PieceTableDocument(UPtr<Buffer>&& original_buffer): m_original_buffer_(std::move(original_buffer)) {
    rebuildBufferSegments();
  }

  PieceTableDocument::~PieceTableDocument() = default;

  U8String PieceTableDocument::getU8Text() {
    return getU8Text(0, m_total_bytes_);
  }

  U16String PieceTableDocument::getU16Text() {
    U8String utf8_text = getU8Text(0, m_total_bytes_);
    U16String result;
    StrUtil::convertUTF8ToUTF16(utf8_text, result);
    return result;
  }

  size_t PieceTableDocument::getLineCount() const {
    return m_logical_lines_.size();
  }

  U16String PieceTableDocument::getLineU16Text(size_t line) const {
    if (line >= m_logical_lines_.size()) {
      throw std::out_of_range("PieceTableDocument::getLineU16Text line index out of range");
    }
    if (!m_logical_lines_[line].is_char_dirty) {
      return m_logical_lines_[line].cached_text;
    }
    const size_t byte_length = getByteLengthOfLine(line);
    U8String utf8_text = getU8Text(m_logical_lines_[line].start_byte, byte_length);
    U16String result;
    StrUtil::convertUTF8ToUTF16(utf8_text, result);
    return result;
  }

  uint32_t PieceTableDocument::getLineColumns(size_t line) {
    if (line >= m_logical_lines_.size()) {
      throw std::out_of_range("PieceTableDocument::getLineColumns line index out of range");
    }
    updateDirtyLine(line, m_logical_lines_[line]);
    return clampToUint32(m_logical_lines_[line].cached_text.size());
  }

  TextPosition PieceTableDocument::getPositionFromCharIndex(size_t char_index) const {
    if (m_logical_lines_.empty()) {
      return TextPosition{0, 0};
    }
    if (char_index == 0) {
      return TextPosition{0, 0};
    }
    const size_t target_line = getLineFromCharIndex(char_index);
    const LogicalLine& logical_line = m_logical_lines_[target_line];
    size_t column = char_index - logical_line.start_char;
    return TextPosition{target_line, column};
  }

  size_t PieceTableDocument::getCharIndexFromPosition(const TextPosition& position) {
    size_t line = position.line;
    size_t column = position.column;

    if (line >= m_logical_lines_.size()) {
      line = m_logical_lines_.size() - 1;
    }

    const LogicalLine& line_snapshot = m_logical_lines_[line];
    uint32_t line_chars = getLineColumns(line);
    if (column > line_chars) {
      column = line_chars;
    }
    return line_snapshot.start_char + column;
  }

  void PieceTableDocument::insertU8Text(const TextPosition& position, const U8String& text) {
    if (text.empty()) {
      return;
    }
    const size_t byte_offset = getByteOffsetFromPosition(position);
    insertU8Text(byte_offset, text);
  }

  void PieceTableDocument::deleteU8Text(const TextRange& range) {
    size_t start_byte = getByteOffsetFromPosition(range.start);
    size_t byte_length = getByteOffsetFromPosition(range.end) - start_byte;
    deleteU8Text(start_byte, byte_length);
  }

  void PieceTableDocument::replaceU8Text(const TextRange& range, const U8String& text) {
    deleteU8Text(range);
    insertU8Text(range.start, text);
  }

  U8String PieceTableDocument::getU8Text(const TextRange& range) {
    TextPosition r_start = range.start;
    TextPosition r_end = range.end;
    if (r_end < r_start) std::swap(r_start, r_end);
    U8String result;
    for (size_t line = r_start.line; line <= r_end.line && line < getLineCount(); ++line) {
      U16String line_text = getLineU16Text(line);
      size_t col_start = (line == r_start.line) ? r_start.column : 0;
      size_t col_end = (line == r_end.line) ? r_end.column : line_text.length();
      col_start = std::min(col_start, line_text.length());
      col_end = std::min(col_end, line_text.length());
      if (col_start < col_end) {
        U16String sub = line_text.substr(col_start, col_end - col_start);
        U8String u8_sub;
        StrUtil::convertUTF16ToUTF8(sub, u8_sub);
        result += u8_sub;
      }
      if (line < r_end.line) {
        result += "\n";
      }
    }
    return result;
  }

  size_t PieceTableDocument::countChars(size_t start_byte, size_t byte_length) const {
    U8String text = getU8Text(start_byte, byte_length);
    return simdutf::count_utf8(text.data(), text.length());
  }

  Vector<LogicalLine>& PieceTableDocument::getLogicalLines() {
    return m_logical_lines_;
  }

  void PieceTableDocument::updateDirtyLine(size_t line, LogicalLine& logical_line) {
    if (logical_line.is_char_dirty) {
      const size_t byte_length = getByteLengthOfLine(line);
      U8String u8_text = getU8Text(logical_line.start_byte, byte_length);
      StrUtil::convertUTF8ToUTF16(u8_text, logical_line.cached_text);
      if (line > 0) {
        LogicalLine& prev_line = m_logical_lines_[line - 1];
        if (prev_line.is_char_dirty) {
          U8String prev_texts = getU8Text(0, prev_line.start_byte);
          const size_t prev_chars_count = simdutf::count_utf8(prev_texts.data(), prev_texts.length());
          prev_line.start_char = prev_chars_count;
        }
        const size_t prev_byte_length = getByteLengthOfLine(line - 1);
        U8String prev_line_text = getU8Text(prev_line.start_byte, prev_byte_length);
        logical_line.start_char = prev_line.start_char + simdutf::count_utf8(prev_line_text.data(), prev_line_text.length());
      } else {
        logical_line.start_char = 0;
      }
      logical_line.is_char_dirty = false;
    }
  }

  void PieceTableDocument::rebuildBufferSegments() {
    m_edit_buffer_ = makeUPtr<U8StringBuffer>();
    m_buffer_segments_.clear();
    m_buffer_segments_.push_back({SegmentType::ORIGINAL, 0, m_original_buffer_->size()});
    m_total_bytes_ = m_original_buffer_->size();
    rebuildLogicalLines();
  }

  void PieceTableDocument::rebuildLogicalLines() {
    m_logical_lines_.clear();
    m_logical_lines_.push_back({0, 0, {}, true});
    const char* data = m_original_buffer_->data();
    const size_t size = m_original_buffer_->size();
    for (size_t i = 0; i < size; ++i) {
      if (data[i] == '\r') {
        if (i + 1 < size && data[i + 1] == '\n') {
          // CRLF
          m_logical_lines_.back().line_ending = LineEnding::CRLF;
          m_logical_lines_.push_back({i + 2, 0, {}, true});
          ++i; // skip the '\n'
        } else {
          // CR
          m_logical_lines_.back().line_ending = LineEnding::CR;
          m_logical_lines_.push_back({i + 1, 0, {}, true});
        }
      } else if (data[i] == '\n') {
        // LF
        m_logical_lines_.back().line_ending = LineEnding::LF;
        m_logical_lines_.push_back({i + 1, 0, {}, true});
      }
    }
    // Keep the last line's line_ending as NONE
  }

  U8String PieceTableDocument::getU8Text(size_t start_byte, size_t byte_length) const {
    if (start_byte >= m_total_bytes_) {
      return "";
    }
    if (start_byte + byte_length > m_total_bytes_) {
      byte_length = m_total_bytes_ - start_byte;
    }
    U8String result;
    result.reserve(byte_length);
    size_t current_byte = 0;
    size_t req_end_byte = start_byte + byte_length;
    for (const BufferSegment& segment : m_buffer_segments_) {
      size_t seg_start = current_byte;
      size_t seg_end = current_byte + segment.byte_length;

      if (seg_end <= start_byte) {
        current_byte += segment.byte_length;
        continue;
      }

      if (seg_start >= req_end_byte) {
        break;
      }

      size_t copy_start = std::max(seg_start, start_byte);
      size_t copy_end = std::min(seg_end, req_end_byte);
      size_t copy_len = copy_end - copy_start;
      size_t seg_offset = copy_start - seg_start;
      const char* src_data = getSegmentData(segment);
      result.append(src_data + seg_offset, copy_len);
      current_byte += segment.byte_length;
    }
    return result;
  }

  void PieceTableDocument::insertU8Text(size_t start_byte, const U8String& text) {
    if (text.empty()) {
      return;
    }
    if (start_byte > m_total_bytes_) {
      start_byte = m_total_bytes_;
    }
    size_t edit_buffer_start = m_edit_buffer_->currentEnd();
    m_edit_buffer_->append(text);
    BufferSegment new_seg = {SegmentType::EDITED, edit_buffer_start, text.size()};
    bool is_inserted = false;
    size_t current_byte = 0;
    for (auto it = m_buffer_segments_.begin(); it != m_buffer_segments_.end(); ++it) {
      // Check whether the insertion point is inside the current segment
      // (inclusive at the start, exclusive at the end unless this is the last one)
      if (current_byte + it->byte_length > start_byte) {
        size_t offset_in_seg = start_byte - current_byte;
        // Insertion point is at the segment start (offset == 0)
        if (offset_in_seg == 0) {
          m_buffer_segments_.insert(it, new_seg);
          is_inserted = true;
          break;
        }
        // Insertion point is in the middle: split it (left + new + right)
        BufferSegment right = *it;
        right.start_byte += offset_in_seg;
        right.byte_length -= offset_in_seg;
        // Turn current segment into the left half
        it->byte_length = offset_in_seg;
        // Insert the new segment and the right half
        it = m_buffer_segments_.insert(it + 1, new_seg);
        m_buffer_segments_.insert(it + 1, right);
        is_inserted = true;
        break;
      }
      current_byte += it->byte_length;
    }
    // If not inserted in the middle, append to the end
    if (!is_inserted) {
      m_buffer_segments_.push_back(new_seg);
    }
    m_total_bytes_ += text.size();
    updateLogicalLinesByInsertText(start_byte, text);
  }

  void PieceTableDocument::deleteU8Text(size_t start_byte, size_t byte_length) {
    if (byte_length == 0) {
      return;
    }
    if (start_byte + byte_length > m_total_bytes_) {
      byte_length = m_total_bytes_ - start_byte;
    }
    size_t delete_end = start_byte + byte_length;
    size_t current_byte = 0;
    auto it = m_buffer_segments_.begin();
    while (it != m_buffer_segments_.end()) {
      size_t seg_len_original = it->byte_length;
      size_t seg_start = current_byte;
      size_t seg_end = current_byte + seg_len_original;
      // Compute overlap
      size_t intersect_start = std::max(seg_start, start_byte);
      size_t intersect_end = std::min(seg_end, delete_end);
      if (intersect_start < intersect_end) { // overlapping
        size_t delete_len_in_seg = intersect_end - intersect_start;
        if (intersect_start == seg_start && intersect_end == seg_end) {
          // Delete all
          it = m_buffer_segments_.erase(it);
        } else if (intersect_start == seg_start) {
          // Delete head
          it->start_byte += delete_len_in_seg;
          it->byte_length -= delete_len_in_seg;
          ++it;
        } else if (intersect_end == seg_end) {
          // Delete tail
          it->byte_length -= delete_len_in_seg;
          ++it;
        }
        else {
          // Delete middle
          size_t left_len = intersect_start - seg_start;
          BufferSegment right = *it;
          // Right half start offset = original start + left length + deleted length
          right.start_byte += (left_len + delete_len_in_seg);
          right.byte_length -= (left_len + delete_len_in_seg);
          it->byte_length = left_len;
          // Insert right half
          it = m_buffer_segments_.insert(it + 1, right);
          ++it;
        }
      } else {
        // No overlap
        ++it;
      }
      current_byte += seg_len_original;
      if (current_byte >= delete_end) {
        break;
      }
    }
    m_total_bytes_ -= byte_length;
    updateLogicalLinesByDeleteText(start_byte, byte_length);
  }

  void PieceTableDocument::updateLogicalLinesByInsertText(size_t start_byte, const U8String& text) {
    const size_t line = getLineFromByteOffset(start_byte);
    // Inserted text may change the current line ending, mark it dirty first
    m_logical_lines_[line].is_char_dirty = true;
    m_logical_lines_[line].is_layout_dirty = true;

    Vector<LogicalLine> new_lines;
    for (size_t i = 0; i < text.size(); ++i) {
      if (text[i] == '\r') {
        if (i + 1 < text.size() && text[i + 1] == '\n') {
          // CRLF
          LogicalLine logical_line;
          logical_line.start_byte = start_byte + i + 2;
          logical_line.is_char_dirty = true;
          new_lines.push_back(logical_line);
           // Set the previous logical line's line_ending
          if (new_lines.size() == 1) {
            m_logical_lines_[line].line_ending = LineEnding::CRLF;
          } else {
            new_lines[new_lines.size() - 2].line_ending = LineEnding::CRLF;
          }
          ++i; // skip '\n'
        } else {
          // CR
          LogicalLine logical_line;
          logical_line.start_byte = start_byte + i + 1;
          logical_line.is_char_dirty = true;
          new_lines.push_back(logical_line);
          if (new_lines.size() == 1) {
            m_logical_lines_[line].line_ending = LineEnding::CR;
          } else {
            new_lines[new_lines.size() - 2].line_ending = LineEnding::CR;
          }
        }
      } else if (text[i] == '\n') {
        // LF
        LogicalLine logical_line;
        logical_line.start_byte = start_byte + i + 1;
        logical_line.is_char_dirty = true;
        new_lines.push_back(logical_line);
        if (new_lines.size() == 1) {
          m_logical_lines_[line].line_ending = LineEnding::LF;
        } else {
          new_lines[new_lines.size() - 2].line_ending = LineEnding::LF;
        }
      }
    }
    if (!new_lines.empty()) {
      // The last new line inherits the original line_ending
      // (because the original trailing newline now belongs to the last new line)
      // But if the inserted text does not end with a newline,
      // the last new line's line_ending should be decided by following content
      // Keep NONE here; the later dirty pass will recalculate it
      m_logical_lines_.insert(m_logical_lines_.begin() + line + 1, new_lines.begin(), new_lines.end());
    }
    // Update byte offsets for affected following lines
    size_t shift_amount = text.size();
    size_t start_shift_line = line + 1 + new_lines.size();
    for (size_t i = start_shift_line; i < m_logical_lines_.size(); ++i) {
      m_logical_lines_[i].start_byte += shift_amount;
      m_logical_lines_[i].is_char_dirty = true;
    }
  }

  void PieceTableDocument::updateLogicalLinesByDeleteText(size_t start_byte, size_t byte_length) {
    size_t end_byte = start_byte + byte_length;
    // First line with line.start_byte > start_byte
    size_t low = 0;
    size_t high = m_logical_lines_.size();
    while (low < high) {
      size_t mid = low + (high - low) / 2;
      if (m_logical_lines_[mid].start_byte <= start_byte) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    size_t line_to_remove = low;
    // Mark the line at deletion start as dirty
    // (its content changed and needs relayout)
    if (line_to_remove > 0) {
      m_logical_lines_[line_to_remove - 1].is_char_dirty = true;
      m_logical_lines_[line_to_remove - 1].is_layout_dirty = true;
      m_logical_lines_[line_to_remove - 1].height = -1;
    }
    // First line with line.start_byte > end_byte
    low = line_to_remove;
    high = m_logical_lines_.size();
    while (low < high) {
      size_t mid = low + (high - low) / 2;
      if (m_logical_lines_[mid].start_byte <= end_byte) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    size_t line_to_keep = low;
    if (line_to_remove < line_to_keep) {
      m_logical_lines_.erase(m_logical_lines_.begin() + line_to_remove, m_logical_lines_.begin() + line_to_keep);
    }
    // Shift following lines: all lines after deleted range subtract length from offset
    for (size_t i = line_to_remove; i < m_logical_lines_.size(); ++i) {
      m_logical_lines_[i].start_byte -= byte_length;
      m_logical_lines_[i].is_char_dirty = true;
    }
  }

  size_t PieceTableDocument::getByteOffsetFromPosition(const TextPosition& position) const {
    if (position.line >= m_logical_lines_.size()) {
      throw std::out_of_range("PieceTableDocument::getPositionByteOffset line index out of range");
    }
    size_t line_start_byte = m_logical_lines_[position.line].start_byte;
    // Line text end = next line start - current line ending bytes (excluding line ending)
    size_t line_end_byte;
    if (position.line + 1 < m_logical_lines_.size()) {
      line_end_byte = m_logical_lines_[position.line + 1].start_byte
                    - lineEndingBytes(m_logical_lines_[position.line].line_ending);
    } else {
      line_end_byte = m_total_bytes_;
    }
    size_t current_byte = 0;
    size_t scanned_u16_count = 0;
    size_t result = line_start_byte;

    auto it = m_buffer_segments_.begin();
    while (it != m_buffer_segments_.end()) {
        size_t seg_end = current_byte + it->byte_length;
        // Segment intersects this line's range
        if (seg_end > line_start_byte && current_byte < line_end_byte) {
            // Segment scan start position
            size_t intersect_start = std::max(current_byte, line_start_byte);
            // Segment scan end position
            size_t intersect_end = std::min(seg_end, line_end_byte);
            const char* seg_data = getSegmentData(*it);
            // Local read start inside segment
            size_t local_start = intersect_start - current_byte;
            size_t local_end = intersect_end - intersect_start;
            size_t i = 0;
            while (i < local_end && scanned_u16_count < position.column) {
                unsigned char c = static_cast<unsigned char>(seg_data[local_start + i]);

                size_t step = 1;
                size_t u16_count = 1;

                if (c < 0x80) { //ASCII
                  step = 1;
                  u16_count = 1;
                } else if ((c & 0xE0) == 0xC0) { // Latin/Greek
                  step = 2;
                  u16_count = 1;
                } else if ((c & 0xF0) == 0xE0) { // Common CJK
                  step = 3;
                  u16_count = 1;
                } else if ((c & 0xF8) == 0xF0) { // emoji
                  step = 4;
                  u16_count = 2;
                } else {  // invalid
                  step = 1;
                  u16_count = 1;
                }
                scanned_u16_count += u16_count;
                i += step;
            }
            result += i;
            if (scanned_u16_count >= position.column) {
                return result;
            }
        }

        current_byte += it->byte_length;
        ++it;

        // Already past this line
        if (current_byte >= line_end_byte) {
          break;
        }
    }
    return result;
  }

  size_t PieceTableDocument::getLineFromByteOffset(size_t byte_offset) const {
    size_t low = 0;
    size_t high = m_logical_lines_.size();
    while (low < high) {
      size_t mid = low + (high - low) / 2;
      if (m_logical_lines_[mid].start_byte <= byte_offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }

  size_t PieceTableDocument::getLineFromCharIndex(size_t char_index) const {
    size_t left = 0;
    size_t right = m_logical_lines_.size() - 1;
    size_t target_line = 0;
    while (left <= right) {
      size_t mid = left + (right - left) / 2;
      const LogicalLine& logical_line = m_logical_lines_[mid];
      if (mid + 1 < m_logical_lines_.size() && m_logical_lines_[mid + 1].start_char <= char_index) {
        // If the next line's starting char index <= char_index,
        // the target line is after the current line
        left = mid + 1;
      } else if (logical_line.start_char > char_index) {
        // If the current line's starting char index > char_index,
        // the target line is before the current line
        if (mid == 0) {
          break;
        }
        right = mid - 1;
      } else {
        target_line = mid;
        break;
      }
    }
    // Boundary handling
    if (left < m_logical_lines_.size()) {
      target_line = left;
    }
    if (target_line >= m_logical_lines_.size()) {
      target_line = m_logical_lines_.size() - 1;
    }
    return target_line;
  }

  size_t PieceTableDocument::getByteLengthOfLine(size_t line) const {
    const size_t size = m_logical_lines_.size();
    if (line >= size) {
      throw std::out_of_range("PieceTableDocument::getLineByteLength line index out of range");
    }
    size_t raw_length;
    if (line == size - 1) {
      raw_length = m_total_bytes_ - m_logical_lines_[size - 1].start_byte;
    } else {
      raw_length = m_logical_lines_[line + 1].start_byte - m_logical_lines_[line].start_byte;
    }
    // Subtract line-ending bytes; line text does not include line ending
    return raw_length - lineEndingBytes(m_logical_lines_[line].line_ending);
  }

  inline const char* PieceTableDocument::getSegmentData(const BufferSegment& segment) const {
    return (segment.type == SegmentType::ORIGINAL)
             ? m_original_buffer_->data() + segment.start_byte
             : m_edit_buffer_->data() + segment.start_byte;
  }

#pragma endregion

#pragma region [Class: LineArrayDocument]
  LineArrayDocument::LineArrayDocument(U8String&& original_string) {
    buildFromU8String(original_string);
  }

  LineArrayDocument::LineArrayDocument(const U8String& original_string) {
    buildFromU8String(original_string);
  }

  LineArrayDocument::LineArrayDocument(const U16String& original_string) {
    U8String utf8_text;
    StrUtil::convertUTF16ToUTF8(original_string, utf8_text);
    buildFromU8String(utf8_text);
  }

  LineArrayDocument::LineArrayDocument(UPtr<Buffer>&& original_buffer) {
    U8String text(original_buffer->data(), original_buffer->size());
    buildFromU8String(text);
  }

  LineArrayDocument::~LineArrayDocument() = default;

  U8String LineArrayDocument::getU8Text() {
    U8String result;
    size_t total = 0;
    for (size_t i = 0; i < m_lines_.size(); ++i) {
      total += m_lines_[i].size() + lineEndingBytes(m_logical_lines_[i].line_ending);
    }
    result.reserve(total);
    for (size_t i = 0; i < m_lines_.size(); ++i) {
      result.append(m_lines_[i]);
      switch (m_logical_lines_[i].line_ending) {
        case LineEnding::LF:   result.push_back('\n'); break;
        case LineEnding::CR:   result.push_back('\r'); break;
        case LineEnding::CRLF: result.append("\r\n");  break;
        case LineEnding::NONE: break;
      }
    }
    return result;
  }

  U16String LineArrayDocument::getU16Text() {
    U8String utf8_text = getU8Text();
    U16String result;
    StrUtil::convertUTF8ToUTF16(utf8_text, result);
    return result;
  }

  size_t LineArrayDocument::getLineCount() const {
    return m_logical_lines_.size();
  }

  U16String LineArrayDocument::getLineU16Text(size_t line) const {
    if (line >= m_logical_lines_.size()) {
      throw std::out_of_range("LineArrayDocument::getLineU16Text line index out of range");
    }
    if (!m_logical_lines_[line].is_char_dirty) {
      return m_logical_lines_[line].cached_text;
    }
    U16String result;
    StrUtil::convertUTF8ToUTF16(m_lines_[line], result);
    return result;
  }

  uint32_t LineArrayDocument::getLineColumns(size_t line) {
    if (line >= m_logical_lines_.size()) {
      throw std::out_of_range("LineArrayDocument::getLineColumns line index out of range");
    }
    updateDirtyLine(line, m_logical_lines_[line]);
    return clampToUint32(m_logical_lines_[line].cached_text.size());
  }

  TextPosition LineArrayDocument::getPositionFromCharIndex(size_t char_index) const {
    if (m_logical_lines_.empty()) {
      return TextPosition{0, 0};
    }
    if (char_index == 0) {
      return TextPosition{0, 0};
    }
    size_t accumulated_chars = 0;
    for (size_t i = 0; i < m_lines_.size(); ++i) {
      size_t line_chars = simdutf::count_utf8(m_lines_[i].data(), m_lines_[i].size());
      if (accumulated_chars + line_chars >= char_index) {
        return TextPosition{i, char_index - accumulated_chars};
      }
      size_t eol_chars = (m_logical_lines_[i].line_ending != LineEnding::NONE) ? 1 : 0;
      accumulated_chars += line_chars + eol_chars;
    }
    size_t last = m_lines_.size() - 1;
    size_t last_chars = simdutf::count_utf8(m_lines_[last].data(), m_lines_[last].size());
    return TextPosition{last, last_chars};
  }

  size_t LineArrayDocument::getCharIndexFromPosition(const TextPosition& position) {
    size_t line = position.line;
    size_t column = position.column;

    if (line >= m_logical_lines_.size()) {
      line = m_logical_lines_.size() - 1;
    }

    size_t accumulated_chars = 0;
    for (size_t i = 0; i < line; ++i) {
      accumulated_chars += simdutf::count_utf8(m_lines_[i].data(), m_lines_[i].size());
      if (m_logical_lines_[i].line_ending != LineEnding::NONE) {
        accumulated_chars += 1;
      }
    }

    uint32_t line_chars = getLineColumns(line);
    if (column > line_chars) {
      column = line_chars;
    }
    return accumulated_chars + column;
  }

  void LineArrayDocument::insertU8Text(const TextPosition& position, const U8String& text) {
    if (text.empty()) {
      return;
    }

    size_t line = position.line;
    if (line >= m_lines_.size()) {
      line = m_lines_.size() - 1;
    }
    size_t byte_col = getColumnByteOffset(line, position.column);

    const U8String& current_line = m_lines_[line];
    U8String before = current_line.substr(0, byte_col);
    U8String after = current_line.substr(byte_col);
    LineEnding original_ending = m_logical_lines_[line].line_ending;

    // Parse inserted text and split by line endings
    Vector<U8String> new_parts;
    Vector<LineEnding> new_endings;
    size_t start = 0;
    for (size_t i = 0; i < text.size(); ++i) {
      if (text[i] == '\r') {
        new_parts.push_back(text.substr(start, i - start));
        if (i + 1 < text.size() && text[i + 1] == '\n') {
          new_endings.push_back(LineEnding::CRLF);
          ++i;
        } else {
          new_endings.push_back(LineEnding::CR);
        }
        start = i + 1;
      } else if (text[i] == '\n') {
        new_parts.push_back(text.substr(start, i - start));
        new_endings.push_back(LineEnding::LF);
        start = i + 1;
      }
    }
    new_parts.push_back(text.substr(start));

    if (new_parts.size() == 1) {
      // No line ending: concatenate directly
      m_lines_[line] = before + new_parts[0] + after;
      m_logical_lines_[line].is_char_dirty = true;
      m_logical_lines_[line].is_layout_dirty = true;
    } else {
      // Concatenate the first part with `before`, using the first line ending
      m_lines_[line] = before + new_parts[0];
      m_logical_lines_[line].line_ending = new_endings[0];
      m_logical_lines_[line].is_char_dirty = true;
      m_logical_lines_[line].is_layout_dirty = true;

      // Middle lines and last line
      Vector<U8String> insert_lines;
      Vector<LogicalLine> new_logical;
      for (size_t i = 1; i < new_parts.size() - 1; ++i) {
        insert_lines.push_back(new_parts[i]);
        LogicalLine ll;
        ll.line_ending = new_endings[i];
        ll.is_char_dirty = true;
        ll.is_layout_dirty = true;
        new_logical.push_back(ll);
      }
      // Concatenate the last part with `after`, inheriting original line_ending
      insert_lines.push_back(new_parts.back() + after);
      LogicalLine last_ll;
      last_ll.line_ending = original_ending;
      last_ll.is_char_dirty = true;
      last_ll.is_layout_dirty = true;
      new_logical.push_back(last_ll);

      m_lines_.insert(m_lines_.begin() + line + 1, insert_lines.begin(), insert_lines.end());
      m_logical_lines_.insert(m_logical_lines_.begin() + line + 1, new_logical.begin(), new_logical.end());
    }

    rebuildStartBytes(line);
  }

  void LineArrayDocument::deleteU8Text(const TextRange& range) {
    size_t start_line = range.start.line;
    size_t end_line = range.end.line;

    if (start_line >= m_lines_.size()) return;
    if (end_line >= m_lines_.size()) {
      end_line = m_lines_.size() - 1;
    }

    size_t start_byte_col = getColumnByteOffset(start_line, range.start.column);
    size_t end_byte_col = getColumnByteOffset(end_line, range.end.column);

    if (start_line == end_line) {
      U8String& line_text = m_lines_[start_line];
      line_text = line_text.substr(0, start_byte_col) + line_text.substr(end_byte_col);
      m_logical_lines_[start_line].is_char_dirty = true;
      m_logical_lines_[start_line].is_layout_dirty = true;
    } else {
      // Multi-line delete: first-line prefix + last-line suffix,
      // inherit the last line's line_ending
      U8String merged = m_lines_[start_line].substr(0, start_byte_col)
                      + m_lines_[end_line].substr(end_byte_col);
      m_lines_[start_line] = merged;
      m_logical_lines_[start_line].line_ending = m_logical_lines_[end_line].line_ending;
      m_logical_lines_[start_line].is_char_dirty = true;
      m_logical_lines_[start_line].is_layout_dirty = true;

      m_lines_.erase(m_lines_.begin() + start_line + 1, m_lines_.begin() + end_line + 1);
      m_logical_lines_.erase(m_logical_lines_.begin() + start_line + 1, m_logical_lines_.begin() + end_line + 1);
    }

    rebuildStartBytes(start_line);
  }

  void LineArrayDocument::replaceU8Text(const TextRange& range, const U8String& text) {
    deleteU8Text(range);
    insertU8Text(range.start, text);
  }

  U8String LineArrayDocument::getU8Text(const TextRange& range) {
    TextPosition r_start = range.start;
    TextPosition r_end = range.end;
    if (r_end < r_start) std::swap(r_start, r_end);
    U8String result;
    for (size_t line = r_start.line; line <= r_end.line && line < getLineCount(); ++line) {
      U16String line_text = getLineU16Text(line);
      size_t col_start = (line == r_start.line) ? r_start.column : 0;
      size_t col_end = (line == r_end.line) ? r_end.column : line_text.length();
      col_start = std::min(col_start, line_text.length());
      col_end = std::min(col_end, line_text.length());
      if (col_start < col_end) {
        U16String sub = line_text.substr(col_start, col_end - col_start);
        U8String u8_sub;
        StrUtil::convertUTF16ToUTF8(sub, u8_sub);
        result += u8_sub;
      }
      if (line < r_end.line) {
        result += "\n";
      }
    }
    return result;
  }

  size_t LineArrayDocument::countChars(size_t start_byte, size_t byte_length) const {
    size_t total_chars = 0;

    for (size_t i = 0; i < m_lines_.size(); ++i) {
      size_t line_start = m_logical_lines_[i].start_byte;
      size_t eol_bytes = lineEndingBytes(m_logical_lines_[i].line_ending);
      size_t line_byte_len = m_lines_[i].size();
      size_t line_total = line_byte_len + eol_bytes;
      size_t line_end = line_start + line_total;

      if (line_end <= start_byte) {
        continue;
      }
      if (line_start >= start_byte + byte_length) {
        break;
      }

      size_t intersect_start = std::max(line_start, start_byte);
      size_t intersect_end = std::min(line_end, start_byte + byte_length);
      if (intersect_start >= intersect_end) {
        continue;
      }

      size_t local_start = intersect_start - line_start;
      size_t local_len = intersect_end - intersect_start;

      // Text part inside the line
      if (local_start < line_byte_len) {
        size_t text_count_len = std::min(local_len, line_byte_len - local_start);
        total_chars += simdutf::count_utf8(m_lines_[i].data() + local_start, text_count_len);
        local_len -= text_count_len;
      }
      // Line ending part (CR/LF/CRLF each counts as one character)
      if (local_len > 0 && eol_bytes > 0) {
        total_chars += 1;
      }
    }
    return total_chars;
  }

  Vector<LogicalLine>& LineArrayDocument::getLogicalLines() {
    return m_logical_lines_;
  }

  void LineArrayDocument::updateDirtyLine(size_t line, LogicalLine& logical_line) {
    if (logical_line.is_char_dirty) {
      StrUtil::convertUTF8ToUTF16(m_lines_[line], logical_line.cached_text);

      size_t char_offset = 0;
      for (size_t i = 0; i < line; ++i) {
        char_offset += simdutf::count_utf8(m_lines_[i].data(), m_lines_[i].size());
        if (m_logical_lines_[i].line_ending != LineEnding::NONE) {
          char_offset += 1;
        }
      }
      logical_line.start_char = char_offset;
      logical_line.is_char_dirty = false;
    }
  }

  void LineArrayDocument::buildFromU8String(const U8String& text) {
    m_lines_.clear();
    m_logical_lines_.clear();
    size_t start = 0;
    for (size_t i = 0; i < text.size(); ++i) {
      if (text[i] == '\r') {
        m_lines_.push_back(text.substr(start, i - start));
        LogicalLine ll;
        ll.is_char_dirty = true;
        ll.is_layout_dirty = true;
        if (i + 1 < text.size() && text[i + 1] == '\n') {
          ll.line_ending = LineEnding::CRLF;
          m_logical_lines_.push_back(ll);
          ++i; // skip '\n'
        } else {
          ll.line_ending = LineEnding::CR;
          m_logical_lines_.push_back(ll);
        }
        start = i + 1;
      } else if (text[i] == '\n') {
        m_lines_.push_back(text.substr(start, i - start));
        LogicalLine ll;
        ll.is_char_dirty = true;
        ll.is_layout_dirty = true;
        ll.line_ending = LineEnding::LF;
        m_logical_lines_.push_back(ll);
        start = i + 1;
      }
    }
    // Last line (or the only line)
    m_lines_.push_back(text.substr(start));
    LogicalLine last_ll;
    last_ll.is_char_dirty = true;
    last_ll.is_layout_dirty = true;
    last_ll.line_ending = LineEnding::NONE;
    m_logical_lines_.push_back(last_ll);
    rebuildLogicalLines();
  }

  void LineArrayDocument::rebuildLogicalLines() {
    size_t byte_offset = 0;
    for (size_t i = 0; i < m_lines_.size(); ++i) {
      m_logical_lines_[i].start_byte = byte_offset;
      byte_offset += m_lines_[i].size() + lineEndingBytes(m_logical_lines_[i].line_ending);
    }
  }

  void LineArrayDocument::rebuildStartBytes(size_t from_line) {
    if (from_line == 0) {
      m_logical_lines_[0].start_byte = 0;
      from_line = 1;
    }
    for (size_t i = from_line; i < m_lines_.size(); ++i) {
      m_logical_lines_[i].start_byte = m_logical_lines_[i - 1].start_byte
                                     + m_lines_[i - 1].size()
                                     + lineEndingBytes(m_logical_lines_[i - 1].line_ending);
      m_logical_lines_[i].is_char_dirty = true;
    }
    // Mark from_line itself as dirty too
    if (from_line > 0) {
      m_logical_lines_[from_line - 1].is_char_dirty = true;
    }
  }

  size_t LineArrayDocument::getByteOffsetOfLine(size_t line) const {
    if (line < m_logical_lines_.size()) {
      return m_logical_lines_[line].start_byte;
    }
    // Out of range, compute up to the end
    size_t offset = 0;
    for (size_t i = 0; i < m_lines_.size(); ++i) {
      offset += m_lines_[i].size() + lineEndingBytes(m_logical_lines_[i].line_ending);
    }
    return offset;
  }

  size_t LineArrayDocument::getColumnByteOffset(size_t line, size_t column) const {
    if (line >= m_lines_.size()) {
      return 0;
    }
    const U8String& line_text = m_lines_[line];
    size_t u16_count = 0;
    auto it = line_text.begin();
    while (it != line_text.end() && u16_count < column) {
      uint32_t cp = utf8::next(it, line_text.end());
      u16_count += (cp > 0xFFFF) ? 2 : 1;
    }
    return static_cast<size_t>(it - line_text.begin());
  }
#pragma endregion
}
