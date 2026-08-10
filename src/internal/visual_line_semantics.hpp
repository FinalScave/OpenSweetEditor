#ifndef SWEETEDITOR_VISUAL_LINE_SEMANTICS_HPP
#define SWEETEDITOR_VISUAL_LINE_SEMANTICS_HPP

#include <sweeteditor/visual.h>

namespace NS_SWEETEDITOR {
  enum class VisualLinePositionPolicy : uint8_t {
    CONTENT = 0,
    OWNER_LINE_START = 1,
    OWNER_LINE_END = 2,
    PREVIOUS_VISIBLE_LINE_END = 3,
    INTERACTION_POSITION = 4,
  };

  struct VisualLineSemantics {
    VisualLinePositionPolicy pointer_position{VisualLinePositionPolicy::CONTENT};
    VisualLinePositionPolicy text_boundary_position{VisualLinePositionPolicy::CONTENT};
    bool participates_in_document_text{true};
  };

  constexpr VisualLineSemantics getVisualLineSemantics(VisualLineKind kind) {
    switch (kind) {
    case VisualLineKind::PHANTOM:
      return {VisualLinePositionPolicy::CONTENT, VisualLinePositionPolicy::OWNER_LINE_END, false};
    case VisualLineKind::CODELENS:
      return {VisualLinePositionPolicy::OWNER_LINE_START,
              VisualLinePositionPolicy::PREVIOUS_VISIBLE_LINE_END, false};
    case VisualLineKind::REMOVED:
      return {VisualLinePositionPolicy::INTERACTION_POSITION,
              VisualLinePositionPolicy::INTERACTION_POSITION, false};
    case VisualLineKind::CONTENT:
    default:
      return {};
    }
  }
}

#endif //SWEETEDITOR_VISUAL_LINE_SEMANTICS_HPP
