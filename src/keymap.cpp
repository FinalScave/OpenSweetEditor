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
        HashMap<KeyChord, EditorCommandId, KeyChordHash> sub;
        sub[binding.second] = binding.command;
        m_entries_[binding.first] = std::move(sub);
      } else if (auto* sub = std::get_if<HashMap<KeyChord, EditorCommandId, KeyChordHash>>(&it->second)) {
        (*sub)[binding.second] = binding.command;
      } else {
        // Overwrite a single-chord entry with a sub-map
        HashMap<KeyChord, EditorCommandId, KeyChordHash> sub_map;
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
    const auto addCmd = [&km](KeyModifier mods, KeyCode key, EditorBuiltinCommand cmd) {
      km.addBinding({{mods, key}, {}, static_cast<EditorCommandId>(cmd)});
    };

    // Cursor movement
    addCmd(KeyModifier::NONE,  KeyCode::LEFT,  EditorBuiltinCommand::CURSOR_LEFT);
    addCmd(KeyModifier::NONE,  KeyCode::RIGHT, EditorBuiltinCommand::CURSOR_RIGHT);
    addCmd(KeyModifier::NONE,  KeyCode::UP,    EditorBuiltinCommand::CURSOR_UP);
    addCmd(KeyModifier::NONE,  KeyCode::DOWN,  EditorBuiltinCommand::CURSOR_DOWN);
    addCmd(KeyModifier::NONE,  KeyCode::HOME,  EditorBuiltinCommand::CURSOR_LINE_START);
    addCmd(KeyModifier::NONE,  KeyCode::END,   EditorBuiltinCommand::CURSOR_LINE_END);
    addCmd(KeyModifier::NONE, KeyCode::PAGE_UP,   EditorBuiltinCommand::CURSOR_PAGE_UP);
    addCmd(KeyModifier::NONE, KeyCode::PAGE_DOWN, EditorBuiltinCommand::CURSOR_PAGE_DOWN);

    // Selection (Shift + movement)
    addCmd(KeyModifier::SHIFT, KeyCode::LEFT,  EditorBuiltinCommand::SELECT_LEFT);
    addCmd(KeyModifier::SHIFT, KeyCode::RIGHT, EditorBuiltinCommand::SELECT_RIGHT);
    addCmd(KeyModifier::SHIFT, KeyCode::UP,    EditorBuiltinCommand::SELECT_UP);
    addCmd(KeyModifier::SHIFT, KeyCode::DOWN,  EditorBuiltinCommand::SELECT_DOWN);
    addCmd(KeyModifier::SHIFT, KeyCode::HOME,  EditorBuiltinCommand::SELECT_LINE_START);
    addCmd(KeyModifier::SHIFT, KeyCode::END,   EditorBuiltinCommand::SELECT_LINE_END);
    addCmd(KeyModifier::SHIFT, KeyCode::PAGE_UP,   EditorBuiltinCommand::SELECT_PAGE_UP);
    addCmd(KeyModifier::SHIFT, KeyCode::PAGE_DOWN, EditorBuiltinCommand::SELECT_PAGE_DOWN);

    // Editing
    addCmd(KeyModifier::NONE, KeyCode::BACKSPACE,  EditorBuiltinCommand::BACKSPACE);
    addCmd(KeyModifier::NONE, KeyCode::DELETE_KEY, EditorBuiltinCommand::DELETE_FORWARD);
    addCmd(KeyModifier::NONE,  KeyCode::TAB,   EditorBuiltinCommand::INSERT_TAB);
    addCmd(KeyModifier::NONE,  KeyCode::ENTER, EditorBuiltinCommand::INSERT_NEWLINE);

    // Ctrl/Cmd shortcuts
    addCmd(KeyModifier::CTRL, KeyCode::A, EditorBuiltinCommand::SELECT_ALL);
    addCmd(KeyModifier::META, KeyCode::A, EditorBuiltinCommand::SELECT_ALL);
    addCmd(KeyModifier::CTRL, KeyCode::Z, EditorBuiltinCommand::UNDO);
    addCmd(KeyModifier::META, KeyCode::Z, EditorBuiltinCommand::UNDO);
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::Z, EditorBuiltinCommand::REDO);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::Z, EditorBuiltinCommand::REDO);
    addCmd(KeyModifier::CTRL, KeyCode::Y, EditorBuiltinCommand::REDO);
    addCmd(KeyModifier::META, KeyCode::Y, EditorBuiltinCommand::REDO);

    // Clipboard (platform-handled)
    addCmd(KeyModifier::CTRL, KeyCode::C, EditorBuiltinCommand::COPY);
    addCmd(KeyModifier::META, KeyCode::C, EditorBuiltinCommand::COPY);
    addCmd(KeyModifier::CTRL, KeyCode::V, EditorBuiltinCommand::PASTE);
    addCmd(KeyModifier::META, KeyCode::V, EditorBuiltinCommand::PASTE);
    addCmd(KeyModifier::CTRL, KeyCode::X, EditorBuiltinCommand::CUT);
    addCmd(KeyModifier::META, KeyCode::X, EditorBuiltinCommand::CUT);
    addCmd(KeyModifier::CTRL, KeyCode::SPACE, EditorBuiltinCommand::TRIGGER_COMPLETION);
    addCmd(KeyModifier::META, KeyCode::SPACE, EditorBuiltinCommand::TRIGGER_COMPLETION);

    // Line operations (Ctrl/Cmd + Enter)
    addCmd(KeyModifier::CTRL, KeyCode::ENTER, EditorBuiltinCommand::INSERT_LINE_BELOW);
    addCmd(KeyModifier::META, KeyCode::ENTER, EditorBuiltinCommand::INSERT_LINE_BELOW);
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::ENTER, EditorBuiltinCommand::INSERT_LINE_ABOVE);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::ENTER, EditorBuiltinCommand::INSERT_LINE_ABOVE);

    // Line operations (Alt + arrow)
    addCmd(KeyModifier::ALT, KeyCode::UP,   EditorBuiltinCommand::MOVE_LINE_UP);
    addCmd(KeyModifier::ALT, KeyCode::DOWN, EditorBuiltinCommand::MOVE_LINE_DOWN);
    addCmd(KeyModifier::ALT | KeyModifier::SHIFT, KeyCode::UP,   EditorBuiltinCommand::COPY_LINE_UP);
    addCmd(KeyModifier::ALT | KeyModifier::SHIFT, KeyCode::DOWN, EditorBuiltinCommand::COPY_LINE_DOWN);

    // Delete line (Ctrl/Cmd + Shift + K)
    addCmd(KeyModifier::CTRL | KeyModifier::SHIFT, KeyCode::K, EditorBuiltinCommand::DELETE_LINE);
    addCmd(KeyModifier::META | KeyModifier::SHIFT, KeyCode::K, EditorBuiltinCommand::DELETE_LINE);

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
        const EditorCommandId command = matched ? it->second : 0;
        cancelPending();
        if (matched) {
          return {ResolveStatus::MATCHED, command};
        }
        return {ResolveStatus::NO_MATCH, 0};
      }
    }

    const KeyMapEntry* entry = m_key_map_.lookup(chord);
    if (!entry) return {ResolveStatus::NO_MATCH, 0};

    if (auto* cmd = std::get_if<EditorCommandId>(entry)) {
      return {ResolveStatus::MATCHED, *cmd};
    }
    if (auto* sub = std::get_if<HashMap<KeyChord, EditorCommandId, KeyChordHash>>(entry)) {
      m_pending_ = true;
      m_pending_time_ = TimeUtil::milliTime();
      m_pending_sub_map_ = sub;
      return {ResolveStatus::PENDING, 0};
    }
    return {ResolveStatus::NO_MATCH, 0};
  }

  void KeyResolver::cancelPending() {
    m_pending_ = false;
    m_pending_time_ = 0;
    m_pending_sub_map_ = nullptr;
  }

} // namespace NS_SWEETEDITOR
