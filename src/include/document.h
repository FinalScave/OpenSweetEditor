//
// Created by Scave on 2025/12/2.
//

#ifndef SWEETEDITOR_DOCUMENT_H
#define SWEETEDITOR_DOCUMENT_H

#include <cstdint>
#include <foundation.h>
#include <buffer.h>
#include <visual.h>

namespace NS_SWEETEDITOR {
  /// Line ending type
  enum struct LineEnding : uint8_t {
    /// No line ending (usually the last line)
    NONE = 0,
    /// Unix/macOS/Linux: \n (1 byte)
    LF = 1,
    /// Classic Mac OS: \r (1 byte)
    CR = 2,
    /// Windows: \r\n (2 bytes)
    CRLF = 3,
  };

  /// Get byte length of line ending
  inline size_t lineEndingBytes(LineEnding ending) {
    switch (ending) {
      case LineEnding::NONE: return 0;
      case LineEnding::LF:   return 1;
      case LineEnding::CR:   return 1;
      case LineEnding::CRLF: return 2;
    }
    return 0;
  }

  /// Snapshot of logical line data (refresh when marked dirty)
  struct LogicalLine {
    /// Start byte offset of this line in whole document, updated when text changes
    size_t start_byte {0};
    /// Start character offset of this line in whole document, updated when dirty
    size_t start_char {0};
    /// Cached text of this line (without line ending), updated when dirty
    U16String cached_text;
    /// Whether current line text data is marked dirty and needs refresh
    bool is_char_dirty {false};
    /// Line ending type of current line
    LineEnding line_ending {LineEnding::NONE};
    /// Start y coordinate of current line
    float start_y {-1};
    /// Render height of current line
    float height {-1};
    /// Visual line layout data
    Vector<VisualLine> visual_lines;
    /// Whether current line layout is marked dirty and needs rebuild
    bool is_layout_dirty {true};
    /// Whether this line is hidden by code folding (synced by fold manager)
    bool is_fold_hidden {false};
  };

  /// Abstract editor document interface; subclasses can implement different text models (Piece Table, line-based, etc.)
  class Document {
  public:
    virtual ~Document() = default;

    /// Get full document text (UTF-8)
    virtual U8String getU8Text() = 0;

    /// Get full document text (UTF-16)
    virtual U16String getU16Text() = 0;

    /// Get total line count of current document
    virtual size_t getLineCount() const = 0;

    /// Get UTF-16 text of specified line (without line ending)
    virtual U16String getLineU16Text(size_t line) const = 0;

    /// Get column count of specified line (UTF-16 character count, without line ending)
    virtual uint32_t getLineColumns(size_t line) = 0;

    /// Convert whole-document character offset to line/column position
    /// @param char_index Character offset from document start (UTF-16 character count)
    virtual TextPosition getPositionFromCharIndex(size_t char_index) const = 0;

    /// Convert line/column position to whole-document character offset
    virtual size_t getCharIndexFromPosition(const TextPosition& position) = 0;

    /// Insert UTF-8 text at specified position; following lines are reindexed automatically
    virtual void insertU8Text(const TextPosition& position, const U8String& text) = 0;

    /// Delete text in specified range (range.start to range.end, inclusive start and exclusive end)
    virtual void deleteU8Text(const TextRange& range) = 0;

    /// Replace text in specified range (equivalent to delete + insert, but atomic)
    virtual void replaceU8Text(const TextRange& range, const U8String& text) = 0;

    /// Get text in specified range (UTF-8, including line endings)
    virtual U8String getU8Text(const TextRange& range) = 0;

    /// Count UTF-16 characters in given byte range (used for byte-offset to column conversion)
    /// @param start_byte Start byte offset (relative to full UTF-8 buffer)
    /// @param byte_length Byte length of range
    virtual size_t countChars(size_t start_byte, size_t byte_length) const = 0;

    /// Get all logical line data
    virtual Vector<LogicalLine>& getLogicalLines() = 0;

    /// Refresh cached data for specified line (reload text from storage, update char offsets, etc.)
    /// @param index Line index
    /// @param logical_line Logical line to refresh (is_char_dirty flag will be cleared)
    virtual void updateDirtyLine(size_t index, LogicalLine& logical_line) = 0;
  };

  /// Text segment type
  enum struct SegmentType {
    ORIGINAL,
    EDITED
  };

  /// Text segment in a Buffer
  struct BufferSegment {
    /// Whether this segment belongs to original document text
    SegmentType type {SegmentType::ORIGINAL};
    /// Start byte position in buffer
    size_t start_byte {0};
    /// Byte length
    size_t byte_length {0};
  };

  /// Line-based document implementation: each line stores independent UTF-8 text, suitable for small/medium files and frequent line-level operations
  class LineArrayDocument : public Document {
  public:
    explicit LineArrayDocument(U8String&& original_string);
    explicit LineArrayDocument(const U8String& original_string);
    explicit LineArrayDocument(const U16String& original_string);
    explicit LineArrayDocument(UPtr<Buffer>&& original_buffer);

    ~LineArrayDocument() override;

    U8String getU8Text() override;
    U16String getU16Text() override;
    size_t getLineCount() const override;
    U16String getLineU16Text(size_t line) const override;
    uint32_t getLineColumns(size_t line) override;
    TextPosition getPositionFromCharIndex(size_t char_index) const override;
    size_t getCharIndexFromPosition(const TextPosition& position) override;
    void insertU8Text(const TextPosition& position, const U8String& text) override;
    void deleteU8Text(const TextRange& range) override;
    void replaceU8Text(const TextRange& range, const U8String& text) override;
    U8String getU8Text(const TextRange& range) override;
    size_t countChars(size_t start_byte, size_t byte_length) const override;
    Vector<LogicalLine>& getLogicalLines() override;
    void updateDirtyLine(size_t index, LogicalLine& logical_line) override;
  protected:
    /// UTF-8 text content for each line (without line ending)
    Vector<U8String> m_lines_;
    /// Logical line data
    Vector<LogicalLine> m_logical_lines_;
  private:
    void buildFromU8String(const U8String& text);
    void rebuildLogicalLines();
    void rebuildStartBytes(size_t from_line);
    size_t getByteOffsetOfLine(size_t line) const;
    size_t getColumnByteOffset(size_t line, size_t column) const;
  };

  /// Piece Table based document implementation
  class PieceTableDocument : public Document {
  public:
    explicit PieceTableDocument(U8String&& original_string);
    explicit PieceTableDocument(const U8String& original_string);
    explicit PieceTableDocument(const U16String& original_string);
    explicit PieceTableDocument(UPtr<Buffer>&& original_buffer);

    ~PieceTableDocument() override;

    U8String getU8Text() override;
    U16String getU16Text() override;
    size_t getLineCount() const override;
    U16String getLineU16Text(size_t line) const override;
    uint32_t getLineColumns(size_t line) override;
    TextPosition getPositionFromCharIndex(size_t char_index) const override;
    size_t getCharIndexFromPosition(const TextPosition& position) override;
    void insertU8Text(const TextPosition& position, const U8String& text) override;
    void deleteU8Text(const TextRange& range) override;
    void replaceU8Text(const TextRange& range, const U8String& text) override;
    U8String getU8Text(const TextRange& range) override;
    size_t countChars(size_t start_byte, size_t byte_length) const override;
    Vector<LogicalLine>& getLogicalLines() override;
    void updateDirtyLine(size_t index, LogicalLine& logical_line) override;
  protected:
    /// Buffer for original content (read-only)
    UPtr<Buffer> m_original_buffer_;
    /// Buffer for user edits, append-only
    UPtr<U8StringBuffer> m_edit_buffer_;
    /// All text segments
    Vector<BufferSegment> m_buffer_segments_;
    /// Logical line data
    Vector<LogicalLine> m_logical_lines_;
    /// Total byte length of full document
    size_t m_total_bytes_ {0};
  private:
    void rebuildBufferSegments();
    void rebuildLogicalLines();
    U8String getU8Text(size_t start_byte, size_t byte_length) const;
    void insertU8Text(size_t start_byte, const U8String& text);
    void deleteU8Text(size_t start_byte, size_t byte_length);
    void updateLogicalLinesByInsertText(size_t start_byte, const U8String& text);
    void updateLogicalLinesByDeleteText(size_t start_byte, size_t byte_length);
    size_t getByteOffsetFromPosition(const TextPosition& position) const;
    size_t getLineFromByteOffset(size_t byte_offset) const;
    size_t getLineFromCharIndex(size_t char_index) const;
    size_t getByteLengthOfLine(size_t line) const;
    const char* getSegmentData(const BufferSegment& segment) const;
  };
}

#endif //SWEETEDITOR_DOCUMENT_H
