#ifndef SWEETEDITOR_STYLE_SPAN_UTIL_HPP
#define SWEETEDITOR_STYLE_SPAN_UTIL_HPP

#include <algorithm>
#include <array>
#include <sweeteditor/decoration.h>

namespace NS_SWEETEDITOR {
namespace detail {
  inline Vector<StyleSpan> mergeStyleSpanLayers(
      const std::array<const Vector<StyleSpan>*, kSpanLayerCount>& layers) {
    HashSet<uint32_t> split_set;
    size_t non_empty_layers = 0;
    const Vector<StyleSpan>* only_layer = nullptr;
    for (const Vector<StyleSpan>* layer : layers) {
      if (layer == nullptr || layer->empty()) continue;
      ++non_empty_layers;
      only_layer = layer;
      for (const StyleSpan& span : *layer) {
        split_set.insert(span.column);
        split_set.insert(span.column + span.length);
      }
    }
    if (non_empty_layers == 0) return {};
    if (non_empty_layers == 1) return *only_layer;

    Vector<uint32_t> splits(split_set.begin(), split_set.end());
    std::sort(splits.begin(), splits.end());

    Vector<StyleSpan> result;
    for (size_t i = 0; i + 1 < splits.size(); ++i) {
      const uint32_t segment_start = splits[i];
      const uint32_t segment_end = splits[i + 1];
      if (segment_start >= segment_end) continue;

      const StyleSpan* winner = nullptr;
      for (size_t layer_index = kSpanLayerCount; layer_index > 0 && winner == nullptr; --layer_index) {
        const Vector<StyleSpan>* layer = layers[layer_index - 1];
        if (layer == nullptr) continue;
        for (const StyleSpan& span : *layer) {
          if (segment_start >= span.column && segment_start < span.column + span.length) {
            winner = &span;
            break;
          }
        }
      }
      if (winner == nullptr) continue;

      if (!result.empty() && result.back().style_id == winner->style_id
          && result.back().column + result.back().length == segment_start) {
        result.back().length += segment_end - segment_start;
      } else {
        result.push_back({segment_start, segment_end - segment_start, winner->style_id});
      }
    }
    return result;
  }
}
}

#endif //SWEETEDITOR_STYLE_SPAN_UTIL_HPP
