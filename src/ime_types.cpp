#include <sweeteditor/ime_types.h>

namespace NS_SWEETEDITOR {

  bool ImeSyncSnapshot::requestsPlatformUpdate() const {
    return clear_system_mark
        || has_preedit_range
        || has_system_mark_range
        || context_policy != ImeContextPolicy::NONE;
  }

  bool CompositionState::operator==(const CompositionState& other) const {
    return kind == other.kind
        && start_position == other.start_position
        && anchor_range == other.anchor_range
        && original_text == other.original_text
        && preedit_text == other.preedit_text
        && preedit_columns == other.preedit_columns;
  }

  bool CompositionState::operator!=(const CompositionState& other) const {
    return !(*this == other);
  }

}
