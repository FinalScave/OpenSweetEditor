#include <sweeteditor/ime_types.h>

namespace NS_SWEETEDITOR {

  bool ImeOffsetRange::operator==(const ImeOffsetRange& other) const {
    return coordinate_space == other.coordinate_space && start_utf16 == other.start_utf16
           && end_utf16 == other.end_utf16;
  }

  bool ImeOffsetRange::operator!=(const ImeOffsetRange& other) const {
    return !(*this == other);
  }

  bool ImeSelection::operator==(const ImeSelection& other) const {
    return coordinate_space == other.coordinate_space && anchor_utf16 == other.anchor_utf16
           && active_utf16 == other.active_utf16 && affinity == other.affinity;
  }

  bool ImeSelection::operator!=(const ImeSelection& other) const {
    return !(*this == other);
  }

  bool CompositionState::operator==(const CompositionState& other) const {
    return current_range == other.current_range && baseline_text_raw == other.baseline_text_raw
           && baseline_caret == other.baseline_caret;
  }

  bool CompositionState::operator!=(const CompositionState& other) const {
    return !(*this == other);
  }

}
