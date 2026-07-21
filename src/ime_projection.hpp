#ifndef SWEETEDITOR_IME_PROJECTION_HPP
#define SWEETEDITOR_IME_PROJECTION_HPP

#include <optional>
#include <sweeteditor/ime_types.h>

namespace NS_SWEETEDITOR {

  class Document;

  namespace EditingProjection {

    enum class EndpointBias {
      BEFORE,
      AFTER,
    };

    TextPosition transformPosition(const TextRange& source_range, const TextPosition& target_end,
                                   const TextPosition& position, EndpointBias bias);
    std::optional<TextRange> projectRange(const TextRange& source_range, const TextRange& target_range,
                                          const TextRange& range);
    std::optional<TextPosition> projectAnchor(const TextRange& source_range, const TextRange& target_range,
                                              const TextPosition& position, EndpointBias bias);
    Vector<size_t> sourceLinesForEditingLine(const TextRange& source_range, const TextRange& target_range,
                                             size_t editing_line);

  }

  namespace ImeProjection {

    using EndpointBias = EditingProjection::EndpointBias;

    U8String logicalizeLineEndings(const U8String& text);
    TextPosition transformPosition(const TextRange& old_range, const TextPosition& new_end,
                                   const TextPosition& position, EndpointBias bias);
    bool ownsCompositionText(const CompositionState& state);
    TextRange baselineRange(const CompositionState& state);
    bool hasNonIdentityProjection(Document& document, const CompositionState& state);
    std::optional<TextRange> projectCommittedRange(Document& document,
                                                   const std::optional<CompositionState>& composition,
                                                   const TextRange& range);
    std::optional<TextPosition> projectCommittedAnchor(Document& document,
                                                       const std::optional<CompositionState>& composition,
                                                       const TextPosition& position, EndpointBias bias);
    Vector<size_t> committedSourceLinesForEditingLine(Document& document,
                                                      const std::optional<CompositionState>& composition,
                                                      size_t editing_line);

  }

}

#endif // SWEETEDITOR_IME_PROJECTION_HPP
