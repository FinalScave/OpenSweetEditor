//
// Created by Scave on 2025/12/10.
//
#include <algorithm>
#include <cstring>
#include <decoration.h>

namespace NS_SWEETEDITOR {
  const Vector<StyleSpan> DecorationManager::kEmptySpans;
  const Vector<InlayHint> DecorationManager::kEmptyInlayHints;
  const Vector<PhantomText> DecorationManager::kEmptyPhantomTexts;
  const Vector<GutterIcon> DecorationManager::kEmptyGutterIcons;
  const Vector<DiagnosticSpan> DecorationManager::kEmptyDiagnostics;

#pragma region [Class: TextStyleRegistry]
  void TextStyleRegistry::registerTextStyle(uint32_t style_id, TextStyle&& style) {
    style_map_.insert_or_assign(style_id, std::move(style));
  }

  TextStyle& TextStyleRegistry::getStyle(uint32_t style_id) {
    auto it = style_map_.find(style_id);
    if (it != style_map_.end()) {
      return it->second;
    }
    // If not found, return the default style (auto-register one)
    style_map_.insert_or_assign(style_id, TextStyle{0, 0, FONT_STYLE_NORMAL});
    return style_map_[style_id];
  }
#pragma endregion

#pragma region [Class: DecorationManager]
  DecorationManager::DecorationManager() {
    m_text_style_reg_ = makePtr<TextStyleRegistry>();
  }

  Ptr<TextStyleRegistry> DecorationManager::getTextStyleRegistry() {
    return m_text_style_reg_;
  }

  void DecorationManager::setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans) {
    size_t idx = static_cast<size_t>(layer);
    auto& storage = m_layer_spans_[idx];
    if (storage.size() <= line) {
      storage.resize(line + 1);
    }
    storage[line] = std::move(spans);
  }

  void DecorationManager::setLineInlayHints(size_t line, Vector<InlayHint>&& hints) {
    ensureLineCapacity_(line + 1);
    m_inlay_hints_[line] = std::move(hints);
  }

  void DecorationManager::setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms) {
    ensureLineCapacity_(line + 1);
    m_phantom_texts_[line] = std::move(phantoms);
  }

  void DecorationManager::setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons) {
    if (icons.empty()) {
      m_gutter_icons_.erase(line);
    } else {
      m_gutter_icons_[line] = std::move(icons);
    }
  }

  const Vector<StyleSpan>& DecorationManager::getLineSpans(size_t line, SpanLayer layer) const {
    size_t idx = static_cast<size_t>(layer);
    const auto& storage = m_layer_spans_[idx];
    if (line >= storage.size()) return kEmptySpans;
    return storage[line];
  }

  Vector<StyleSpan> DecorationManager::getMergedLineSpans(size_t line) const {
    // Collect all non-empty layers
    Vector<const Vector<StyleSpan>*> layers;
    for (size_t i = 0; i < kSpanLayerCount; ++i) {
      const auto& storage = m_layer_spans_[i];
      if (line < storage.size() && !storage[line].empty()) {
        layers.push_back(&storage[line]);
      }
    }
    if (layers.empty()) return {};
    if (layers.size() == 1) return *layers[0];

    // Merge multiple layers: higher layers override lower ones (zip-aligned by split points)
    // Collect all split points
    HashSet<uint32_t> split_set;
    for (const auto* layer : layers) {
      for (const auto& span : *layer) {
        split_set.insert(span.column);
        split_set.insert(span.column + span.length);
      }
    }
    Vector<uint32_t> splits(split_set.begin(), split_set.end());
    std::sort(splits.begin(), splits.end());

    // For each interval [splits[i], splits[i+1]), find the first covering span from top layer down
    Vector<StyleSpan> result;
    for (size_t i = 0; i + 1 < splits.size(); ++i) {
      uint32_t seg_start = splits[i];
      uint32_t seg_end = splits[i + 1];
      if (seg_start >= seg_end) continue;

      uint32_t found_style_id = 0;
      bool found = false;
      // Traverse from top layer to bottom layer
      for (int layer_idx = static_cast<int>(kSpanLayerCount) - 1; layer_idx >= 0; --layer_idx) {
        const auto& storage = m_layer_spans_[layer_idx];
        if (line >= storage.size()) continue;
        const auto& spans = storage[line];
        for (const auto& span : spans) {
          if (seg_start >= span.column && seg_start < span.column + span.length) {
            found_style_id = span.style_id;
            found = true;
            break;
          }
        }
        if (found) break;
      }
      if (!found) continue;

      // Try to merge with previous span (adjacent and same style_id)
      if (!result.empty() && result.back().style_id == found_style_id
          && result.back().column + result.back().length == seg_start) {
        result.back().length += (seg_end - seg_start);
      } else {
        result.push_back({seg_start, seg_end - seg_start, found_style_id});
      }
    }
    return result;
  }

  const Vector<InlayHint>& DecorationManager::getLineInlayHints(size_t line) const {
    if (line >= m_inlay_hints_.size()) return kEmptyInlayHints;
    return m_inlay_hints_[line];
  }

  const Vector<PhantomText>& DecorationManager::getLinePhantomTexts(size_t line) const {
    if (line >= m_phantom_texts_.size()) return kEmptyPhantomTexts;
    return m_phantom_texts_[line];
  }

  const Vector<GutterIcon>& DecorationManager::getLineGutterIcons(size_t line) const {
    auto it = m_gutter_icons_.find(line);
    if (it != m_gutter_icons_.end()) {
      return it->second;
    }
    return kEmptyGutterIcons;
  }

  void DecorationManager::setLineDiagnostics(size_t line, Vector<DiagnosticSpan>&& diagnostics) {
    if (m_diagnostics_.size() <= line) {
      m_diagnostics_.resize(line + 1);
    }
    m_diagnostics_[line] = std::move(diagnostics);
  }

  const Vector<DiagnosticSpan>& DecorationManager::getLineDiagnostics(size_t line) const {
    if (line >= m_diagnostics_.size()) return kEmptyDiagnostics;
    return m_diagnostics_[line];
  }

  void DecorationManager::clearDiagnostics() {
    m_diagnostics_.clear();
  }

  void DecorationManager::clearLine(size_t line) {
    for (size_t i = 0; i < kSpanLayerCount; ++i) {
      if (line < m_layer_spans_[i].size()) m_layer_spans_[i][line].clear();
    }
    if (line < m_inlay_hints_.size()) m_inlay_hints_[line].clear();
    if (line < m_phantom_texts_.size()) m_phantom_texts_[line].clear();
    if (line < m_diagnostics_.size()) m_diagnostics_[line].clear();
    m_gutter_icons_.erase(line);
  }

  void DecorationManager::clearHighlights(SpanLayer layer) {
    m_layer_spans_[static_cast<size_t>(layer)].clear();
  }

  void DecorationManager::clearHighlights() {
    for (size_t i = 0; i < kSpanLayerCount; ++i) {
      m_layer_spans_[i].clear();
    }
  }

  void DecorationManager::clearInlayHints() {
    m_inlay_hints_.clear();
  }

  void DecorationManager::clearPhantomTexts() {
    m_phantom_texts_.clear();
  }

  void DecorationManager::clearGutterIcons() {
    m_gutter_icons_.clear();
  }

  void DecorationManager::clearAll() {
    for (size_t i = 0; i < kSpanLayerCount; ++i) {
      m_layer_spans_[i].clear();
    }
    m_inlay_hints_.clear();
    m_phantom_texts_.clear();
    m_diagnostics_.clear();
    m_gutter_icons_.clear();
    m_indent_guides_.clear();
    m_bracket_guides_.clear();
    m_flow_guides_.clear();
    m_separator_guides_.clear();
    clearFoldRegions();
  }

  void DecorationManager::setIndentGuides(Vector<IndentGuide>&& guides) {
    m_indent_guides_ = std::move(guides);
  }

  void DecorationManager::setBracketGuides(Vector<BracketGuide>&& guides) {
    m_bracket_guides_ = std::move(guides);
  }

  void DecorationManager::setFlowGuides(Vector<FlowGuide>&& guides) {
    m_flow_guides_ = std::move(guides);
  }

  void DecorationManager::setSeparatorGuides(Vector<SeparatorGuide>&& guides) {
    m_separator_guides_ = std::move(guides);
  }

  void DecorationManager::clearGuides() {
    m_indent_guides_.clear();
    m_bracket_guides_.clear();
    m_flow_guides_.clear();
    m_separator_guides_.clear();
  }

#pragma region Fold (Code Folding)

  void DecorationManager::setFoldRegions(Vector<FoldRegion>&& regions) {
    Vector<FoldRegion> old_regions = std::move(m_fold_regions_);
    Vector<FoldRegion> normalized;
    normalized.reserve(regions.size());

    for (auto& region : regions) {
      if (region.end_line < region.start_line) {
        continue;
      }

      region.collapsed = false;
      bool matched = false;
      for (const auto& old_region : old_regions) {
        if (old_region.start_line == region.start_line &&
            old_region.end_line == region.end_line) {
          region.collapsed = old_region.collapsed;
          matched = true;
          break;
        }
      }

      if (!matched) {
        for (const auto& old_region : old_regions) {
          if (old_region.start_line == region.start_line) {
            region.collapsed = old_region.collapsed;
            break;
          }
        }
      }

      normalized.push_back(region);
    }

    std::sort(normalized.begin(), normalized.end(),
      [](const FoldRegion& a, const FoldRegion& b) {
        if (a.start_line != b.start_line) {
          return a.start_line < b.start_line;
        }
        return a.end_line < b.end_line;
      });

    m_fold_regions_.clear();
    m_fold_regions_.reserve(normalized.size());
    for (auto& region : normalized) {
      if (!m_fold_regions_.empty()) {
        FoldRegion& last = m_fold_regions_.back();
        if (last.start_line == region.start_line && last.end_line == region.end_line) {
          last.collapsed = last.collapsed || region.collapsed;
          continue;
        }
      }
      m_fold_regions_.push_back(region);
    }
  }

  bool DecorationManager::foldAt(size_t line) {
    // Prefer exact start_line match (fold header), supports nested folding
    for (auto& region : m_fold_regions_) {
      if (region.start_line == line) {
        if (!region.collapsed) {
          region.collapsed = true;
          return true;
        }
        return false;
      }
    }
    // Fallback: match the innermost region that contains this line
    FoldRegion* best = nullptr;
    for (auto& region : m_fold_regions_) {
      if (line >= region.start_line && line <= region.end_line) {
        if (best == nullptr || (region.end_line - region.start_line) < (best->end_line - best->start_line)) {
          best = &region;
        }
      }
    }
    if (best != nullptr && !best->collapsed) {
      best->collapsed = true;
      return true;
    }
    return false;
  }

  bool DecorationManager::unfoldAt(size_t line) {
    // Prefer exact start_line match (fold header), supports nested folding
    for (auto& region : m_fold_regions_) {
      if (region.start_line == line) {
        if (region.collapsed) {
          region.collapsed = false;
          return true;
        }
        return false;
      }
    }
    // Fallback: match the innermost region that contains this line
    FoldRegion* best = nullptr;
    for (auto& region : m_fold_regions_) {
      if (line >= region.start_line && line <= region.end_line) {
        if (best == nullptr || (region.end_line - region.start_line) < (best->end_line - best->start_line)) {
          best = &region;
        }
      }
    }
    if (best != nullptr && best->collapsed) {
      best->collapsed = false;
      return true;
    }
    return false;
  }

  bool DecorationManager::toggleFoldAt(size_t line) {
    // Prefer exact start_line match (fold header), supports nested folding
    for (auto& region : m_fold_regions_) {
      if (region.start_line == line) {
        region.collapsed = !region.collapsed;
        return true;
      }
    }
    // Fallback: match the innermost region that contains this line
    FoldRegion* best = nullptr;
    for (auto& region : m_fold_regions_) {
      if (line >= region.start_line && line <= region.end_line) {
        if (best == nullptr || (region.end_line - region.start_line) < (best->end_line - best->start_line)) {
          best = &region;
        }
      }
    }
    if (best != nullptr) {
      best->collapsed = !best->collapsed;
      return true;
    }
    return false;
  }

  void DecorationManager::foldAll() {
    for (auto& region : m_fold_regions_) {
      region.collapsed = true;
    }
  }

  void DecorationManager::unfoldAll() {
    for (auto& region : m_fold_regions_) {
      region.collapsed = false;
    }
  }

  bool DecorationManager::isLineHidden(size_t line) const {
    for (const auto& region : m_fold_regions_) {
      if (region.collapsed && line > region.start_line && line <= region.end_line) {
        return true;
      }
    }
    return false;
  }

  int DecorationManager::getFoldStateForLine(size_t line) const {
    // 0=NONE, 1=EXPANDED, 2=COLLAPSED
    for (const auto& region : m_fold_regions_) {
      if (region.start_line == line) {
        return region.collapsed ? 2 : 1;
      }
    }
    return 0;
  }

  const FoldRegion* DecorationManager::getFoldRegionForLine(size_t line) const {
    for (const auto& region : m_fold_regions_) {
      if (line >= region.start_line && line <= region.end_line) {
        return &region;
      }
    }
    return nullptr;
  }

  void DecorationManager::clearFoldRegions() {
    m_fold_regions_.clear();
  }

#pragma endregion

  // Edit parameters passed to helper methods
  struct EditParams {
    size_t old_start_line, old_start_col, old_end_line, old_end_col;
    size_t new_end_line, new_end_col;
    size_t old_line_count, new_line_count;
    int64_t line_delta;
  };

  static uint32_t adjustColumn(uint32_t col, size_t edit_col, int64_t col_delta) {
    if (col <= edit_col) return col;
    int64_t new_col = static_cast<int64_t>(col) + col_delta;
    return static_cast<uint32_t>(std::max<int64_t>(new_col, static_cast<int64_t>(edit_col)));
  }

  // Line-level delete/insert (shared by three line-indexed containers)
  template<typename T>
  static void adjustLineStorage(Vector<Vector<T>>& storage, const EditParams& p) {
    if (storage.empty()) return;
    if (p.old_line_count > 0 || p.new_line_count > 0) {
      size_t sz = storage.size();
      if (p.old_line_count > 0 && p.old_start_line + 1 < sz) {
        size_t erase_begin = p.old_start_line + 1;
        size_t erase_end = std::min(p.old_end_line + 1, sz);
        if (erase_begin < erase_end) {
          storage.erase(storage.begin() + erase_begin, storage.begin() + erase_end);
        }
      }
      if (p.new_line_count > 0) {
        size_t insert_pos = std::min(p.old_start_line + 1, storage.size());
        storage.insert(storage.begin() + insert_pos, p.new_line_count, Vector<T>{});
      }
    }
  }

  // Adjust start line for point decorations (column only, no length)
  template<typename T>
  static void adjustPointDecoStartLine(Vector<T>& items, const Vector<Vector<T>>& storage,
                                        size_t storage_size, const EditParams& p,
                                        Vector<T>* out_moved_to_new_end = nullptr) {
    if (p.old_line_count == 0 && p.new_line_count == 0) {
      // Single-line edit: remove items inside the edit range, shift items after it
      int64_t col_delta = static_cast<int64_t>(p.new_end_col) - static_cast<int64_t>(p.old_end_col);
      for (auto it = items.begin(); it != items.end(); ) {
        if (it->column > p.old_start_col && it->column < p.old_end_col) {
          it = items.erase(it);
        } else {
          if (it->column >= p.old_end_col) {
            it->column = adjustColumn(it->column, p.old_end_col, col_delta);
          }
          ++it;
        }
      }
    } else {
      // Multi-line edit: keep only items at or before old_start_col on the start line
      // Collect items with column > old_start_col (may move to a new line)
      Vector<T> moved_items;
      for (auto it = items.begin(); it != items.end(); ) {
        if (it->column > p.old_start_col) {
          moved_items.push_back(std::move(*it));
          it = items.erase(it);
        } else {
          ++it;
        }
      }
      // Append content after the old_end_line split point to the new end of the start line
      if (p.old_end_line < storage_size && p.old_end_line != p.old_start_line) {
        auto& end_items = storage[p.old_end_line];
        for (auto& item : end_items) {
          if (item.column >= p.old_end_col) {
            auto moved = std::move(item);
            moved.column = static_cast<uint32_t>(p.new_end_col + (moved.column - p.old_end_col));
            items.push_back(std::move(moved));
          }
        }
      } else if (p.old_end_line == p.old_start_line && p.new_line_count > 0) {
        // Single-line to multi-line edit (e.g., Enter): moved items should go to the new last line
        // Adjust columns: original column is relative to old_start_line,
        // now it should be relative to new_end_line (new line):
        // column offset = column - old_end_col + new_end_col
        // For pure insert (old_start_col == old_end_col), new_end_col is the start column of the new line
        for (auto& item : moved_items) {
          if (item.column >= p.old_end_col) {
            item.column = static_cast<uint32_t>(p.new_end_col + (item.column - p.old_end_col));
          }
        }
        if (out_moved_to_new_end) {
          *out_moved_to_new_end = std::move(moved_items);
          moved_items.clear();
        }
      }
      // Discard remaining moved_items that are inside the edited range
    }
  }

  // Adjust start line for StyleSpan (range logic with column + length)
  static void adjustSpanStartLine(Vector<StyleSpan>& spans, size_t span_storage_size,
                                   const Vector<Vector<StyleSpan>>& storage, const EditParams& p) {
    if (p.old_line_count == 0 && p.new_line_count == 0) {
      int64_t col_delta = static_cast<int64_t>(p.new_end_col) - static_cast<int64_t>(p.old_end_col);
      for (auto it = spans.begin(); it != spans.end(); ) {
        uint32_t span_end = it->column + it->length;
        if (span_end <= p.old_start_col) {
          ++it;
        } else if (it->column >= p.old_end_col) {
          it->column = adjustColumn(it->column, p.old_end_col, col_delta);
          ++it;
        } else if (it->column >= p.old_start_col && span_end <= p.old_end_col) {
          it = spans.erase(it);
        } else if (it->column < p.old_start_col && span_end > p.old_end_col) {
          uint32_t deleted = static_cast<uint32_t>(p.old_end_col - p.old_start_col);
          uint32_t inserted = static_cast<uint32_t>(p.new_end_col - p.old_start_col);
          it->length = it->length - deleted + inserted;
          ++it;
        } else if (it->column < p.old_start_col) {
          it->length = static_cast<uint32_t>(p.old_start_col) - it->column;
          ++it;
        } else {
          uint32_t tail = span_end - static_cast<uint32_t>(p.old_end_col);
          it->column = static_cast<uint32_t>(p.new_end_col);
          it->length = tail;
          ++it;
        }
      }
    } else {
      // Multi-line edit: keep only spans before old_start_col on the start line
      for (auto it = spans.begin(); it != spans.end(); ) {
        uint32_t span_end = it->column + it->length;
        if (span_end <= p.old_start_col) {
          ++it;
        } else if (it->column < p.old_start_col) {
          it->length = static_cast<uint32_t>(p.old_start_col) - it->column;
          ++it;
        } else {
          it = spans.erase(it);
        }
      }
      if (p.old_end_line < span_storage_size && p.old_end_line != p.old_start_line) {
        auto& end_spans = storage[p.old_end_line];
        for (auto& span : end_spans) {
          if (span.column >= p.old_end_col) {
            StyleSpan s = span;
            s.column = static_cast<uint32_t>(p.new_end_col + (span.column - p.old_end_col));
            spans.push_back(s);
          } else if (span.column + span.length > p.old_end_col) {
            uint32_t tail = (span.column + span.length) - static_cast<uint32_t>(p.old_end_col);
            spans.push_back({static_cast<uint32_t>(p.new_end_col), tail, span.style_id});
          }
        }
      }
    }
  }

  // Adjust start line for DiagnosticSpan (same shape as StyleSpan: column + length)
  static void adjustDiagnosticStartLine(Vector<DiagnosticSpan>& spans, size_t span_storage_size,
                                         const Vector<Vector<DiagnosticSpan>>& storage, const EditParams& p) {
    if (p.old_line_count == 0 && p.new_line_count == 0) {
      int64_t col_delta = static_cast<int64_t>(p.new_end_col) - static_cast<int64_t>(p.old_end_col);
      for (auto it = spans.begin(); it != spans.end(); ) {
        uint32_t span_end = it->column + it->length;
        if (span_end <= p.old_start_col) {
          ++it;
        } else if (it->column >= p.old_end_col) {
          it->column = adjustColumn(it->column, p.old_end_col, col_delta);
          ++it;
        } else if (it->column >= p.old_start_col && span_end <= p.old_end_col) {
          it = spans.erase(it);
        } else if (it->column < p.old_start_col && span_end > p.old_end_col) {
          uint32_t deleted = static_cast<uint32_t>(p.old_end_col - p.old_start_col);
          uint32_t inserted = static_cast<uint32_t>(p.new_end_col - p.old_start_col);
          it->length = it->length - deleted + inserted;
          ++it;
        } else if (it->column < p.old_start_col) {
          it->length = static_cast<uint32_t>(p.old_start_col) - it->column;
          ++it;
        } else {
          uint32_t tail = span_end - static_cast<uint32_t>(p.old_end_col);
          it->column = static_cast<uint32_t>(p.new_end_col);
          it->length = tail;
          ++it;
        }
      }
    } else {
      for (auto it = spans.begin(); it != spans.end(); ) {
        uint32_t span_end = it->column + it->length;
        if (span_end <= p.old_start_col) {
          ++it;
        } else if (it->column < p.old_start_col) {
          it->length = static_cast<uint32_t>(p.old_start_col) - it->column;
          ++it;
        } else {
          it = spans.erase(it);
        }
      }
      if (p.old_end_line < span_storage_size && p.old_end_line != p.old_start_line) {
        auto& end_spans = storage[p.old_end_line];
        for (auto& span : end_spans) {
          if (span.column >= p.old_end_col) {
            DiagnosticSpan s = span;
            s.column = static_cast<uint32_t>(p.new_end_col + (span.column - p.old_end_col));
            spans.push_back(s);
          } else if (span.column + span.length > p.old_end_col) {
            uint32_t tail = (span.column + span.length) - static_cast<uint32_t>(p.old_end_col);
            spans.push_back({static_cast<uint32_t>(p.new_end_col), tail, span.severity, span.color});
          }
        }
      }
    }
  }

  void DecorationManager::adjustForEdit(const TextRange& old_range, const TextPosition& new_end) {
    EditParams p;
    p.old_start_line = old_range.start.line;
    p.old_start_col  = old_range.start.column;
    p.old_end_line   = old_range.end.line;
    p.old_end_col    = old_range.end.column;
    p.new_end_line   = new_end.line;
    p.new_end_col    = new_end.column;
    p.old_line_count = p.old_end_line - p.old_start_line;
    p.new_line_count = p.new_end_line - p.old_start_line;
    p.line_delta     = static_cast<int64_t>(p.new_end_line) - static_cast<int64_t>(p.old_end_line);

    // StyleSpan (all layers)
    for (size_t li = 0; li < kSpanLayerCount; ++li) {
      auto& spans_storage = m_layer_spans_[li];
      if (!spans_storage.empty() && p.old_start_line < spans_storage.size()) {
        adjustSpanStartLine(spans_storage[p.old_start_line], spans_storage.size(), spans_storage, p);
      }
      adjustLineStorage(spans_storage, p);
    }

    // InlayHint
    Vector<InlayHint> moved_hints;
    if (!m_inlay_hints_.empty() && p.old_start_line < m_inlay_hints_.size()) {
      adjustPointDecoStartLine(m_inlay_hints_[p.old_start_line], m_inlay_hints_, m_inlay_hints_.size(), p, &moved_hints);
    }
    adjustLineStorage(m_inlay_hints_, p);
    // Place InlayHints moved by Enter-like operations onto the new last line
    if (!moved_hints.empty() && p.new_end_line < m_inlay_hints_.size()) {
      auto& target = m_inlay_hints_[p.new_end_line];
      for (auto& h : moved_hints) {
        auto it = std::lower_bound(target.begin(), target.end(), h,
          [](const InlayHint& a, const InlayHint& b) { return a.column < b.column; });
        target.insert(it, std::move(h));
      }
    }

    // PhantomText
    Vector<PhantomText> moved_phantoms;
    if (!m_phantom_texts_.empty() && p.old_start_line < m_phantom_texts_.size()) {
      adjustPointDecoStartLine(m_phantom_texts_[p.old_start_line], m_phantom_texts_, m_phantom_texts_.size(), p, &moved_phantoms);
    }
    adjustLineStorage(m_phantom_texts_, p);
    // Place PhantomText moved by Enter-like operations onto the new last line
    if (!moved_phantoms.empty() && p.new_end_line < m_phantom_texts_.size()) {
      auto& target = m_phantom_texts_[p.new_end_line];
      for (auto& ph : moved_phantoms) {
        auto it = std::lower_bound(target.begin(), target.end(), ph,
          [](const PhantomText& a, const PhantomText& b) { return a.column < b.column; });
        target.insert(it, std::move(ph));
      }
    }

    // DiagnosticSpan (same shape as StyleSpan: column + length)
    if (!m_diagnostics_.empty() && p.old_start_line < m_diagnostics_.size()) {
      adjustDiagnosticStartLine(m_diagnostics_[p.old_start_line], m_diagnostics_.size(), m_diagnostics_, p);
    }
    adjustLineStorage(m_diagnostics_, p);

    // Guides: adjust by line/column offsets
    auto adjustPosition = [&](TextPosition& pos) {
      if (pos.line < p.old_start_line) return;
      if (pos.line > p.old_end_line) {
        pos.line = static_cast<size_t>(static_cast<int64_t>(pos.line) + p.line_delta);
        return;
      }
      if (pos.line == p.old_start_line && pos.column <= p.old_start_col) return;
      // Inside the edited range, map to new_end
      pos.line = p.new_end_line;
      pos.column = p.new_end_col;
    };

    for (auto& g : m_indent_guides_) {
      adjustPosition(g.start);
      adjustPosition(g.end);
    }
    for (auto& g : m_bracket_guides_) {
      adjustPosition(g.parent);
      adjustPosition(g.end);
      for (auto& child : g.children) {
        adjustPosition(child);
      }
    }
    for (auto& g : m_flow_guides_) {
      adjustPosition(g.start);
      adjustPosition(g.end);
    }
    for (auto& g : m_separator_guides_) {
      auto line = static_cast<size_t>(g.line);
      if (line > p.old_end_line) {
        g.line = static_cast<int32_t>(line + p.line_delta);
      } else if (line > p.old_start_line && line <= p.old_end_line) {
        g.line = static_cast<int32_t>(p.new_end_line);
      }
    }

    // GutterIcon
    if (p.line_delta != 0 && !m_gutter_icons_.empty()) {
      if (p.old_line_count > 0) {
        for (size_t l = p.old_start_line + 1; l <= p.old_end_line; ++l) {
          m_gutter_icons_.erase(l);
        }
      }
      HashMap<size_t, Vector<GutterIcon>> new_icons;
      for (auto& [line, icons] : m_gutter_icons_) {
        size_t target = (line <= p.old_start_line) ? line
          : static_cast<size_t>(static_cast<int64_t>(line) + p.line_delta);
        new_icons[target] = std::move(icons);
      }
      m_gutter_icons_ = std::move(new_icons);
    }

    // FoldRegion: adjust by line offsets and remove fully covered regions
    if (!m_fold_regions_.empty()) {
      for (auto it = m_fold_regions_.begin(); it != m_fold_regions_.end(); ) {
        auto& fr = *it;
        // Region is fully before the edit range, unaffected
        if (fr.end_line < p.old_start_line) { ++it; continue; }
        // Region is fully after the edit range, shift line numbers
        if (fr.start_line > p.old_end_line) {
          fr.start_line = static_cast<size_t>(static_cast<int64_t>(fr.start_line) + p.line_delta);
          fr.end_line = static_cast<size_t>(static_cast<int64_t>(fr.end_line) + p.line_delta);
          ++it; continue;
        }
        // Region is fully covered by the edit, remove it
        if (fr.start_line >= p.old_start_line && fr.end_line <= p.old_end_line) {
          it = m_fold_regions_.erase(it); continue;
        }
        // Partial overlap: adjust boundaries
        if (fr.start_line < p.old_start_line) {
          // Region starts before the edit, adjust the end
          if (fr.end_line <= p.old_end_line) {
            fr.end_line = p.old_start_line;
          } else {
            fr.end_line = static_cast<size_t>(static_cast<int64_t>(fr.end_line) + p.line_delta);
          }
        } else {
          // Region starts inside the edit range
          fr.start_line = p.new_end_line;
          fr.end_line = static_cast<size_t>(static_cast<int64_t>(fr.end_line) + p.line_delta);
        }
        // Remove invalid regions (start >= end)
        if (fr.start_line >= fr.end_line) {
          it = m_fold_regions_.erase(it);
        } else {
          ++it;
        }
      }
    }
  }

  void DecorationManager::ensureLineCapacity_(size_t line_count) {
    if (m_inlay_hints_.size() < line_count) {
      m_inlay_hints_.resize(line_count);
    }
    if (m_phantom_texts_.size() < line_count) {
      m_phantom_texts_.resize(line_count);
    }
    if (m_diagnostics_.size() < line_count) {
      m_diagnostics_.resize(line_count);
    }
  }
#pragma endregion
}

