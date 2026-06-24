#ifndef SWEETEDITOR_IME_TYPES_H
#define SWEETEDITOR_IME_TYPES_H

#include <cstdint>
#include <sweeteditor/editor_types.h>

namespace NS_SWEETEDITOR {

  enum class SE_PROTOCOL_ENUM(ime, GRAPHEME) ImeTextUnit {
    GRAPHEME = 0,
    CODE_POINT = 1,
  };

  enum class SE_PROTOCOL_ENUM(ime, DOCUMENT_WINDOW) ImeTextUpdateScope {
    DOCUMENT_WINDOW = 0,
    TRANSIENT_INPUT = 1,
  };

  enum class SE_PROTOCOL_ENUM(ime, NONE) ImeInputContextKind {
    NONE = 0,
    SELECTION_ONLY = 1,
    DOCUMENT_WINDOW = 2,
    TRANSIENT_INPUT = 3,
  };

  enum class SE_PROTOCOL_ENUM(ime, NONE) ImeMarkedRangeRole {
    NONE = 0,
    PREEDIT = 1,
    SYSTEM_MARK = 2,
  };

  enum class SE_PROTOCOL_ENUM(ime, SET_SELECTION) ImeCommandKind {
    SET_SELECTION = 0,
    SET_PREEDIT_TEXT = 1,
    COMMIT_TEXT = 2,
    FINISH_PREEDIT = 3,
    CANCEL_PREEDIT = 4,
    SET_MARKED_RANGE = 5,
    CLEAR_MARKED_RANGE = 6,
    REPLACE_TEXT = 7,
    DELETE_SURROUNDING_TEXT = 8,
    SET_KEYBOARD_SCRIPT = 9,
  };

  enum class SE_PROTOCOL_ENUM(ime, SNAPSHOT) ImeTextUpdateKind {
    SNAPSHOT = 0,
    PATCH = 1,
  };

  struct SE_PROTOCOL_VALUE(ime) ImeOffsetRange {
    int32_t start {0};
    int32_t end {0};
  };

  struct SE_PROTOCOL_VALUE(ime) ImeMarkedRange {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeMarkedRangeRole role {ImeMarkedRangeRole::NONE};
    ImeOffsetRange range {-1, -1};
  };

  struct SE_PROTOCOL_VALUE(ime) ImeTextPatch {
    ImeOffsetRange range {-1, -1};
    U8String text;
  };

  struct SE_PROTOCOL_OUT(ime) ImeInputContext {
    uint64_t id {0};
    int32_t revision {0};
    int32_t document_start_offset {0};
    U8String text;
    ImeOffsetRange selection;
    bool has_preedit_range {false};
    ImeOffsetRange preedit_range {-1, -1};
    bool has_system_mark_range {false};
    ImeOffsetRange system_mark_range {-1, -1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeInputContextKind kind {ImeInputContextKind::NONE};
  };

  enum class SE_PROTOCOL_ENUM(ime, UNKNOWN) ImeScriptClass {
    UNKNOWN,
    LATIN,
    CJK,
    KANA,
    HANGUL,
  };

  enum class SE_PROTOCOL_ENUM(ime, NONE) ImeContextPolicy {
    NONE,
    LIMITED_FOR_CANDIDATES,
  };

  struct SE_PROTOCOL_IN(ime) ImeCommandMessage {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeCommandKind kind {ImeCommandKind::SET_SELECTION};
    uint64_t context_id {0};
    int32_t context_revision {0};
    int32_t document_start_offset {0};
    ImeOffsetRange range {-1, -1};
    ImeOffsetRange selection {-1, -1};
    U8String text;
    int32_t cursor_offset {1};
    int32_t delete_before {0};
    int32_t delete_after {0};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextUnit text_unit {ImeTextUnit::GRAPHEME};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeMarkedRangeRole marked_role {ImeMarkedRangeRole::NONE};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeTextUpdateMessage {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextUpdateKind kind {ImeTextUpdateKind::SNAPSHOT};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextUpdateScope scope {ImeTextUpdateScope::DOCUMENT_WINDOW};
    uint64_t context_id {0};
    int32_t context_revision {0};
    int32_t document_start_offset {0};
    U8String text;
    ImeTextPatch patch;
    ImeOffsetRange selection {-1, -1};
    ImeMarkedRange marked_range;
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  /// Snapshot that platform layers use to synchronize IME selection and marked ranges.
  struct SE_PROTOCOL_OUT(ime) ImeSyncSnapshot {
    TextPosition cursor;
    TextRange selection;
    bool has_selection {false};
    bool has_preedit_range {false};
    TextRange preedit_range;
    bool has_system_mark_range {false};
    TextRange system_mark_range;
    SE_PROTOCOL_WIRE(enum_i32)
    ImeContextPolicy context_policy {ImeContextPolicy::NONE};
    bool clear_system_mark {false};
  };

  /// Result of a semantic IME action handled by the core.
  struct ImeActionResult {
    bool handled {false};
    bool content_changed {false};
    bool cursor_changed {false};
    bool selection_changed {false};
    TextEditResult edit_result;
    ImeSyncSnapshot sync;
  };

  /// IME composition ownership.
  enum class CompositionKind {
    NONE,
    PREEDIT_TEXT,
    DOCUMENT_RANGE,
  };

  /// IME composition state.
  struct CompositionState {
    /// Source and ownership of the active composition.
    CompositionKind kind {CompositionKind::NONE};
    /// Start position of composition in the document.
    TextPosition start_position;
    /// Authoritative document range owned by this active composition.
    TextRange anchor_range;
    /// Original text captured from anchor_range.
    U8String original_text;
    /// Current preedit text.
    U8String preedit_text;
    /// UTF-16 column count of current preedit text for exact cursor placement.
    size_t preedit_columns {0};
  };

}

#endif //SWEETEDITOR_IME_TYPES_H
