#include <sweeteditor/keymap.h>
#include <sweeteditor/utility.h>

namespace NS_SWEETEDITOR {

  bool KeyChord::operator==(const KeyChord& other) const {
    return key_code == other.key_code && modifiers == other.modifiers;
  }

  bool KeyChord::operator!=(const KeyChord& other) const {
    return !(*this == other);
  }

  void KeyMap::addBinding(const KeyBinding& binding) {
    if (binding.first.empty()) return;
    if (binding.second.empty()) {
      m_entries_[binding.first] = binding.command;
    } else {
      auto it = m_entries_.find(binding.first);
      if (it == m_entries_.end()) {
        HashMap<KeyChord, EditorCommand, KeyChordHash> sub;
        sub[binding.second] = binding.command;
        m_entries_[binding.first] = std::move(sub);
      } else if (auto* sub = std::get_if<HashMap<KeyChord, EditorCommand, KeyChordHash>>(&it->second)) {
        (*sub)[binding.second] = binding.command;
      } else {
        // Overwrite a single-chord entry with a sub-map
        HashMap<KeyChord, EditorCommand, KeyChordHash> sub_map;
        sub_map[binding.second] = binding.command;
        it->second = std::move(sub_map);
      }
    }
  }

  const KeyMapEntry* KeyMap::lookup(const KeyChord& chord) const {
    auto it = m_entries_.find(chord);
    if (it == m_entries_.end()) return nullptr;
    return &it->second;
  }

  KeyMap KeyMap::createDefault() {
    KeyMap km;
    const auto addCmd = [&km](KeyModifier mods, KeyCode key, EditorCommand cmd) {
      km.addBinding({{mods, key}, {}, cmd});
    };

    // Cursor movement
    addCmd(KeyModifier::NONE,  KeyCode::LEFT,  EditorCommand::CURSOR_LEFT);
    addCmd(KeyModifier::NONE,  KeyCode::RIGHT, EditorCommand::CURSOR_RIGHT);
    addCmd(KeyModifier::NONE,  KeyCode::UP,    EditorCommand::CURSOR_UP);
    addCmd(KeyModifier::NONE,  KeyCode::DOWN,  EditorCommand::CURSOR_DOWN);
    addCmd(KeyModifier::NONE,  KeyCode::HOME,  EditorCommand::CURSOR_LINE_START);
    addCmd(KeyModifier::NONE,  KeyCode::END,   EditorCommand::CURSOR_LINE_END);
    addCmd(KeyModifier::NONE, KeyCode::PAGE_UP,   EditorCommand::CURSOR_PAGE_UP);
    addCmd(KeyModifier::NONE, KeyCode::PAGE_DOWN, EditorCommand::CURSOR_PAGE_DOWN);

    // Selection (Shift + movement)
    addCmd(KeyModifier::SHIFT, KeyCode::LEFT,  EditorCommand::SELECT_LEFT);
    addCmd(KeyModifier::SHIFT, KeyCode::RIGHT, EditorCommand::SELECT_RIGHT);
    addCmd(KeyModifier::SHIFT, KeyCode::UP,    EditorCommand::SELECT_UP);
    addCmd(KeyModifier::SHIFT, KeyCode::DOWN,  EditorCommand::SELECT_DOWN);
    addCmd(KeyModifier::SHIFT, KeyCode::HOME,  EditorCommand::SELECT_LINE_START);
    addCmd(KeyModifier::SHIFT, KeyCode::END,   EditorCommand::SELECT_LINE_END);
    addCmd(KeyModifier::SHIFT, KeyCode::PAGE_UP,   EditorCommand::SELECT_PAGE_UP);
    addCmd(KeyModifier::SHIFT, KeyCode::PAGE_DOWN, EditorCommand::SELECT_PAGE_DOWN);

    // Editing
    addCmd(KeyModifier::NONE, KeyCode::BACKSPACE,  EditorCommand::BACKSPACE);
    addCmd(KeyModifier::NONE, KeyCode::DELETE_KEY, EditorCommand::DELETE_FORWARD);
    addCmd(KeyModifier::NONE,  KeyCode::TAB,   EditorCommand::INSERT_TAB);
    addCmd(KeyModifier::NONE,  KeyCode::ENTER, EditorCommand::INSERT_NEWLINE);

    // Ctrl/Cmd shortcuts
    addCmd(KeyModifier::CTRL, KeyCode::A, EditorCommand::SELECT_ALL);
    addCmd(KeyModifier::META, KeyCode::A, EditorCommand::SELECT_ALL);
    addCmd(KeyModifier::CTRL, KeyCode::Z, EditorCommand::UNDO);
    addCmd(KeyModifier::META, KeyCode::Z, EditorCommand::UNDO);
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::Z, EditorCommand::REDO);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::Z, EditorCommand::REDO);
    addCmd(KeyModifier::CTRL, KeyCode::Y, EditorCommand::REDO);
    addCmd(KeyModifier::META, KeyCode::Y, EditorCommand::REDO);

    // Clipboard (platform-handled)
    addCmd(KeyModifier::CTRL, KeyCode::C, EditorCommand::COPY);
    addCmd(KeyModifier::META, KeyCode::C, EditorCommand::COPY);
    addCmd(KeyModifier::CTRL, KeyCode::V, EditorCommand::PASTE);
    addCmd(KeyModifier::META, KeyCode::V, EditorCommand::PASTE);
    addCmd(KeyModifier::CTRL, KeyCode::X, EditorCommand::CUT);
    addCmd(KeyModifier::META, KeyCode::X, EditorCommand::CUT);
    addCmd(KeyModifier::CTRL, KeyCode::SPACE, EditorCommand::TRIGGER_COMPLETION);
    addCmd(KeyModifier::META, KeyCode::SPACE, EditorCommand::TRIGGER_COMPLETION);

    // Line operations (Ctrl/Cmd + Enter)
    addCmd(KeyModifier::CTRL, KeyCode::ENTER, EditorCommand::INSERT_LINE_BELOW);
    addCmd(KeyModifier::META, KeyCode::ENTER, EditorCommand::INSERT_LINE_BELOW);
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::ENTER, EditorCommand::INSERT_LINE_ABOVE);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::ENTER, EditorCommand::INSERT_LINE_ABOVE);

    // Line operations (Alt + arrow)
    addCmd(KeyModifier::ALT, KeyCode::UP,   EditorCommand::MOVE_LINE_UP);
    addCmd(KeyModifier::ALT, KeyCode::DOWN, EditorCommand::MOVE_LINE_DOWN);
    addCmd(KeyModifier::ALT | KeyModifier::SHIFT, KeyCode::UP,   EditorCommand::COPY_LINE_UP);
    addCmd(KeyModifier::ALT | KeyModifier::SHIFT, KeyCode::DOWN, EditorCommand::COPY_LINE_DOWN);

    // Delete line (Ctrl/Cmd + Shift + K)
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::K, EditorCommand::DELETE_LINE);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::K, EditorCommand::DELETE_LINE);

    return km;
  }

  KeyResolver::KeyResolver(int64_t pending_timeout_ms)
    : m_pending_timeout_ms_(pending_timeout_ms) {}

  void KeyResolver::setKeyMap(KeyMap key_map) {
    m_key_map_ = std::move(key_map);
    cancelPending();
  }

  ResolveResult KeyResolver::resolve(const KeyChord& chord) {
    if (m_pending_) {
      bool expired = !m_pending_sub_map_ ||
                     (TimeUtil::milliTime() - m_pending_time_ > m_pending_timeout_ms_);
      if (expired) {
        cancelPending();
      } else {
        auto it = m_pending_sub_map_->find(chord);
        const bool matched = (it != m_pending_sub_map_->end());
        const EditorCommand command = matched ? it->second : EditorCommand::NONE;
        cancelPending();
        if (matched) {
          return {ResolveStatus::MATCHED, command};
        }
        return {ResolveStatus::NO_MATCH, EditorCommand::NONE};
      }
    }

    const KeyMapEntry* entry = m_key_map_.lookup(chord);
    if (!entry) return {ResolveStatus::NO_MATCH, EditorCommand::NONE};

    if (auto* cmd = std::get_if<EditorCommand>(entry)) {
      return {ResolveStatus::MATCHED, *cmd};
    }
    if (auto* sub = std::get_if<HashMap<KeyChord, EditorCommand, KeyChordHash>>(entry)) {
      m_pending_ = true;
      m_pending_time_ = TimeUtil::milliTime();
      m_pending_sub_map_ = sub;
      return {ResolveStatus::PENDING, EditorCommand::NONE};
    }
    return {ResolveStatus::NO_MATCH, EditorCommand::NONE};
  }

  void KeyResolver::cancelPending() {
    m_pending_ = false;
    m_pending_time_ = 0;
    m_pending_sub_map_ = nullptr;
  }

} // namespace NS_SWEETEDITOR
