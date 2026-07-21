#include <algorithm>
#include <utf8/utf8.h>
#include <sweeteditor/document.h>
#include "ime_projection.hpp"

namespace NS_SWEETEDITOR {

  namespace {
    TextPosition positionAfterText(const TextPosition& start, const U8String& text) {
      TextPosition position = start;
      auto it = text.begin();
      while (it != text.end()) {
        const char ch = *it;
        if (ch == '\n') {
          ++position.line;
          position.column = 0;
          ++it;
        } else if (ch == '\r') {
          ++position.line;
          position.column = 0;
          ++it;
          if (it != text.end() && *it == '\n') {
            ++it;
          }
        } else {
          const uint32_t code_point = utf8::next(it, text.end());
          position.column += code_point > 0xFFFF ? 2 : 1;
        }
      }
      return position;
    }
  }

  TextPosition EditingProjection::transformPosition(const TextRange& source_range, const TextPosition& target_end,
                                                    const TextPosition& position, EndpointBias bias) {
    const TextRange range = source_range.normalized();
    if (position < range.start) {
      return position;
    }
    if (position <= range.end) {
      return bias == EndpointBias::BEFORE ? range.start : target_end;
    }
    return range.transformPositionAfterEdit(position, target_end);
  }

  std::optional<TextRange> EditingProjection::projectRange(const TextRange& source_range, const TextRange& target_range,
                                                           const TextRange& range) {
    const TextRange source = source_range.normalized();
    const TextRange target = target_range.normalized();
    const TextRange normalized = range.normalized();
    const bool affected = source.isCollapsed() ? normalized.start < source.start && source.start < normalized.end
                                               : normalized.overlaps(source);
    if (affected) {
      return std::nullopt;
    }

    TextRange projected{transformPosition(source, target.end, normalized.start, EndpointBias::AFTER),
                        transformPosition(source, target.end, normalized.end, EndpointBias::BEFORE)};
    if (projected.end < projected.start) {
      projected.end = projected.start;
    }
    return projected;
  }

  std::optional<TextPosition> EditingProjection::projectAnchor(const TextRange& source_range,
                                                               const TextRange& target_range,
                                                               const TextPosition& position, EndpointBias bias) {
    const TextRange source = source_range.normalized();
    const TextRange target = target_range.normalized();
    if (!source.isCollapsed() && source.start <= position && position < source.end) {
      return std::nullopt;
    }
    return transformPosition(source, target.end, position, bias);
  }

  Vector<size_t> EditingProjection::sourceLinesForEditingLine(const TextRange& source_range,
                                                              const TextRange& target_range, size_t editing_line) {
    const TextRange source = source_range.normalized();
    const TextRange target = target_range.normalized();
    Vector<size_t> lines;
    const auto append_unique = [&lines](size_t line) {
      if (std::find(lines.begin(), lines.end(), line) == lines.end()) {
        lines.push_back(line);
      }
    };

    if (editing_line < target.start.line) {
      append_unique(editing_line);
    } else if (editing_line > target.end.line) {
      const int64_t line_delta = static_cast<int64_t>(target.end.line) - static_cast<int64_t>(source.end.line);
      append_unique(TextPosition{editing_line, 0}.withLineDelta(-line_delta).line);
    } else {
      if (editing_line == target.start.line) {
        append_unique(source.start.line);
      }
      if (editing_line == target.end.line) {
        append_unique(source.end.line);
      }
    }
    return lines;
  }

  U8String ImeProjection::logicalizeLineEndings(const U8String& text) {
    U8String logical;
    logical.reserve(text.size());
    for (size_t index = 0; index < text.size(); ++index) {
      if (text[index] == '\r') {
        if (index + 1 < text.size() && text[index + 1] == '\n') {
          ++index;
        }
        logical.push_back('\n');
      } else {
        logical.push_back(text[index]);
      }
    }
    return logical;
  }

  TextPosition ImeProjection::transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                                const TextPosition& position, EndpointBias bias) {
    return EditingProjection::transformPosition(old_range, new_end, position, bias);
  }

  bool ImeProjection::ownsCompositionText(const CompositionState& state) {
    return state.baseline_text_raw.has_value();
  }

  TextRange ImeProjection::baselineRange(const CompositionState& state) {
    if (!ownsCompositionText(state)) {
      return state.current_range;
    }
    return {state.current_range.start,
            positionAfterText(state.current_range.start, logicalizeLineEndings(*state.baseline_text_raw))};
  }

  bool ImeProjection::hasNonIdentityProjection(Document& document, const CompositionState& state) {
    return ownsCompositionText(state)
           && logicalizeLineEndings(document.getU8Text(state.current_range))
                  != logicalizeLineEndings(*state.baseline_text_raw);
  }

  std::optional<TextRange> ImeProjection::projectCommittedRange(Document& document,
                                                                const std::optional<CompositionState>& composition,
                                                                const TextRange& range) {
    if (!composition.has_value() || !hasNonIdentityProjection(document, *composition)) {
      return range;
    }

    return EditingProjection::projectRange(baselineRange(*composition), composition->current_range, range);
  }

  std::optional<TextPosition> ImeProjection::projectCommittedAnchor(Document& document,
                                                                    const std::optional<CompositionState>& composition,
                                                                    const TextPosition& position, EndpointBias bias) {
    if (!composition.has_value() || !hasNonIdentityProjection(document, *composition)) {
      return position;
    }
    return EditingProjection::projectAnchor(baselineRange(*composition), composition->current_range, position, bias);
  }

  Vector<size_t> ImeProjection::committedSourceLinesForEditingLine(Document& document,
                                                                   const std::optional<CompositionState>& composition,
                                                                   size_t editing_line) {
    if (!composition.has_value() || !hasNonIdentityProjection(document, *composition)) {
      return {editing_line};
    }
    return EditingProjection::sourceLinesForEditingLine(baselineRange(*composition), composition->current_range,
                                                        editing_line);
  }

}
