#ifndef SWEETEDITOR_KEYMAP_H
#define SWEETEDITOR_KEYMAP_H

#include <cstdint>
#include <functional>
#include <variant>
#include <sweeteditor/macro.h>

namespace NS_SWEETEDITOR {

  /// Keyboard key code definitions
  enum struct SE_PROTOCOL_FLAGS(keymap) KeyCode : uint16_t {
    NONE = 0,
    BACKSPACE = 8,
    TAB = 9,
    ENTER = 13,
    ESCAPE = 27,
    DELETE_KEY = 46,
    LEFT = 37,
    UP = 38,
    RIGHT = 39,
    DOWN = 40,
    HOME = 36,
    END = 35,
    PAGE_UP = 33,
    PAGE_DOWN = 34,
    A = 65,
    C = 67,
    D = 68,
    V = 86,
    X = 88,
    Z = 90,
    Y = 89,
    K = 75,
    SPACE = 32,
  };

  /// Modifier key flags
  enum struct SE_PROTOCOL_FLAGS(keymap) KeyModifier : uint8_t {
    NONE  = 0,
    SHIFT = 1 << 0,
    CTRL  = 1 << 1,
    ALT   = 1 << 2,
    META  = 1 << 3,
  };
  inline KeyModifier operator&(KeyModifier a, KeyModifier b) { return static_cast<KeyModifier>(static_cast<uint8_t>(a) & static_cast<uint8_t>(b)); }
  inline KeyModifier operator|(KeyModifier a, KeyModifier b) { return static_cast<KeyModifier>(static_cast<uint8_t>(a) | static_cast<uint8_t>(b)); }
  inline bool hasAnyModifier(KeyModifier value, KeyModifier mask) { return static_cast<uint8_t>(value & mask) != 0; }

  /// A single key chord: one key press with optional modifiers
  struct KeyChord {
    KeyModifier modifiers {KeyModifier::NONE};
    KeyCode key_code {KeyCode::NONE};

    bool operator==(const KeyChord& other) const;
    bool operator!=(const KeyChord& other) const;
    bool empty() const { return key_code == KeyCode::NONE; }
  };

  struct KeyChordHash {
    size_t operator()(const KeyChord& chord) const noexcept {
      return std::hash<uint32_t>()((static_cast<uint32_t>(chord.key_code) << 8) | static_cast<uint32_t>(chord.modifiers));
    }
  };

   /// Editor command identifiers mapped from key bindings
  enum struct EditorCommand : uint32_t {
    NONE = 0,
    CURSOR_LEFT,
    CURSOR_RIGHT,
    CURSOR_UP,
    CURSOR_DOWN,
    CURSOR_LINE_START,
    CURSOR_LINE_END,
    CURSOR_PAGE_UP,
    CURSOR_PAGE_DOWN,
    SELECT_LEFT,
    SELECT_RIGHT,
    SELECT_UP,
    SELECT_DOWN,
    SELECT_LINE_START,
    SELECT_LINE_END,
    SELECT_PAGE_UP,
    SELECT_PAGE_DOWN,
    SELECT_ALL,
    BACKSPACE,
    DELETE_FORWARD,
    INSERT_TAB,
    INSERT_NEWLINE,
    INSERT_LINE_ABOVE,
    INSERT_LINE_BELOW,
    UNDO,
    REDO,
    MOVE_LINE_UP,
    MOVE_LINE_DOWN,
    COPY_LINE_UP,
    COPY_LINE_DOWN,
    DELETE_LINE,
    COPY,
    PASTE,
    CUT,
    TRIGGER_COMPLETION,
  };

  /// A key binding entry: one or two chords mapped to a command
  struct KeyBinding {
    KeyChord first;
    KeyChord second;  // second.empty() means single-chord binding
    EditorCommand command {EditorCommand::NONE};
  };

  /// Mapping entry: either a direct command or a sub-map for multi-chord bindings
  using KeyMapEntry = std::variant<EditorCommand, HashMap<KeyChord, EditorCommand, KeyChordHash>>;

  /// Keyboard shortcut mapping table
  class KeyMap {
  public:
    /// Add a single binding to the map
    void addBinding(const KeyBinding& binding);

    /// Look up a first-chord entry. Returns nullptr if not found.
    const KeyMapEntry* lookup(const KeyChord& chord) const;

    /// Create the default key map (VS Code-like bindings)
    static KeyMap createDefault();

  private:
    HashMap<KeyChord, KeyMapEntry, KeyChordHash> m_entries_;
  };

  /// Result of a key resolve operation
  enum struct ResolveStatus : uint8_t {
    MATCHED,    // A command was resolved
    PENDING,    // Waiting for the second chord
    NO_MATCH,   // No binding found
  };

  struct ResolveResult {
    ResolveStatus status {ResolveStatus::NO_MATCH};
    EditorCommand command {EditorCommand::NONE};
  };

  /// Stateful resolver that owns a KeyMap and handles multi-chord key sequences with timeout
  class KeyResolver {
  public:
    explicit KeyResolver(int64_t pending_timeout_ms = 2000);

    /// Replace the current key map
    void setKeyMap(KeyMap key_map);

    /// Resolve a key chord against the owned key map
    ResolveResult resolve(const KeyChord& chord);

    /// Whether a multi-chord sequence is pending
    bool isPending() const { return m_pending_; }

  private:
    void cancelPending();
    int64_t m_pending_timeout_ms_;
    KeyMap m_key_map_;
    bool m_pending_ {false};
    int64_t m_pending_time_ {0};
    const HashMap<KeyChord, EditorCommand, KeyChordHash>* m_pending_sub_map_ {nullptr};
  };
} // namespace NS_SWEETEDITOR
#endif //SWEETEDITOR_KEYMAP_H
