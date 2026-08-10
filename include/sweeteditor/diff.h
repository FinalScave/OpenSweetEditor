//
// Created by Scave on 2026/7/31.
//

#ifndef SWEETEDITOR_DIFF_H
#define SWEETEDITOR_DIFF_H

#include <array>
#include <sweeteditor/decoration.h>
#include <sweeteditor/document.h>

namespace NS_SWEETEDITOR {
  /// One normalized line-level difference between the current and original documents.
  struct SE_PROTOCOL_IN(adornment) DiffChange {
    /// Current-document line or insertion boundary where this change starts.
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t current_start_line{0};
    /// Number of current-document lines added or modified by this change.
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t current_line_count{0};
    /// First corresponding line in the original document.
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t original_start_line{0};
    /// Original line bodies removed or replaced by this change, without line endings.
    Vector<U8String> removed_lines;
  };

  /// Sparse diff state kept beside the editable Document.
  class Diff {
  public:
    bool empty() const;
    void clear();

    bool setChanges(Vector<DiffChange>&& changes, size_t current_line_count);
    bool compute(const U8String& original_text, Document& current_document);

    bool setBatchLineSpans(SpanLayer layer,
                           Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries);

    const Vector<DiffChange>& getChanges() const;
    /// Highest one-past-end original line represented by removed rows.
    size_t getMaxRemovedLineEnd() const;
    const DiffChange* getChangeAtBoundary(size_t current_line) const;
    const DiffChange* getChangeForCurrentLine(size_t current_line) const;
    const DiffChange* getChangeForOriginalLine(size_t original_line) const;
    const Vector<StyleSpan>& getMergedLineSpans(size_t original_line) const;

  private:
    bool calculateChanges(const U8String& original_text, Document& current_document,
                          Vector<DiffChange>& changes) const;
    void replaceChanges(Vector<DiffChange>&& changes);
    void rebuildMergedLineSpans(const HashSet<size_t>& lines);

    Vector<DiffChange> m_changes_;
    size_t m_max_removed_line_end_{0};
    std::array<HashMap<size_t, Vector<StyleSpan>>, kSpanLayerCount> m_line_spans_;
    HashMap<size_t, Vector<StyleSpan>> m_merged_line_spans_;
    static const Vector<StyleSpan> kEmptySpans;
  };
}

#endif //SWEETEDITOR_DIFF_H
