#ifndef SWEETEDITOR_IME_TYPES_H
#define SWEETEDITOR_IME_TYPES_H

#include <cstdint>
#include <sweeteditor/editor_types.h>

namespace NS_SWEETEDITOR {

  enum struct SE_PROTOCOL_ENUM(ime, GRAPHEME) ImeTextUnit {
    GRAPHEME = 0,
    CODE_POINT = 1,
  };

  enum struct SE_PROTOCOL_ENUM(ime, DOCUMENT_WINDOW) ImeTextModelMode {
    DOCUMENT_WINDOW = 0,
    TRANSIENT_INPUT = 1,
  };

  enum struct SE_PROTOCOL_ENUM(ime, NONE) ImeInputContextKind {
    NONE = 0,
    SELECTION_ONLY = 1,
    DOCUMENT_WINDOW = 2,
    TRANSIENT_INPUT = 3,
  };

  struct SE_PROTOCOL_VALUE(ime) ImeTextRange {
    int32_t start {0};
    int32_t end {0};
  };

  struct SE_PROTOCOL_OUT(ime) ImeInputContext {
    uint64_t id {0};
    int32_t revision {0};
    int32_t document_start_offset {0};
    U8String text;
    ImeTextRange selection;
    bool has_composition {false};
    ImeTextRange composition {-1, -1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeInputContextKind kind {ImeInputContextKind::NONE};
  };

  enum struct SE_PROTOCOL_ENUM(ime, UNKNOWN) ImeScriptClass {
    UNKNOWN,
    LATIN,
    CJK,
    KANA,
    HANGUL,
  };

  enum struct SE_PROTOCOL_ENUM(ime, NONE) ImePreeditStorage {
    NONE,
    VISIBLE_DOCUMENT_COMPOSITION,
    SHADOW_ONLY,
  };

  enum struct SE_PROTOCOL_ENUM(ime, NONE) ImeContextPolicy {
    NONE,
    LIMITED_FOR_CANDIDATES,
  };

  struct SE_PROTOCOL_IN(ime) ImeTextReplacement {
    TextRange range;
    U8String text;
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeDocumentTextReplacement {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t start_offset {0};
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t end_offset {0};
    U8String text;
    int32_t cursor_offset {1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeInputContextTextReplacement {
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t start_offset {0};
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t end_offset {0};
    U8String text;
    int32_t cursor_offset {1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeTextModelState {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextModelMode mode {ImeTextModelMode::DOCUMENT_WINDOW};
    uint64_t context_id {0};
    int32_t document_start_offset {0};
    U8String text;
    ImeTextRange selection;
    ImeTextRange composition {-1, -1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeTextModelDelta {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextModelMode mode {ImeTextModelMode::DOCUMENT_WINDOW};
    uint64_t context_id {0};
    int32_t document_start_offset {0};
    U8String old_text;
    ImeTextRange delta {-1, -1};
    U8String delta_text;
    ImeTextRange selection;
    ImeTextRange composition {-1, -1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  struct SE_PROTOCOL_IN(ime) ImeInputStateTextReplacement {
    uint64_t context_id {0};
    int32_t document_start_offset {0};
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t start_offset {0};
    SE_PROTOCOL_WIRE(size_as_u32)
    size_t end_offset {0};
    U8String text;
    int32_t cursor_offset {1};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeScriptClass script_class {ImeScriptClass::UNKNOWN};
  };

  /// Snapshot that platform layers use to synchronize IME selection and marked ranges.
  struct SE_PROTOCOL_OUT(ime) ImeSyncSnapshot {
    TextPosition cursor;
    TextRange selection;
    bool has_selection {false};
    bool has_composing_session {false};
    bool has_visible_composition_range {false};
    TextRange visible_composition_range;
    bool has_platform_marked_range {false};
    TextRange platform_marked_range;
    SE_PROTOCOL_WIRE(enum_i32)
    ImePreeditStorage preedit_storage {ImePreeditStorage::NONE};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeContextPolicy context_policy {ImeContextPolicy::NONE};
    bool clear_platform_preedit {false};
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
  enum struct CompositionKind {
    NONE,
    PREEDIT_TEXT,
    DOCUMENT_RANGE,
  };

  enum struct CompositionPhase {
    INACTIVE,
    ACTIVE,
  };

  /// IME composition state.
  struct CompositionState {
    /// Whether composition is visible and active.
    bool is_composing {false};
    /// Whether there is an active composition session.
    bool has_session {false};
    /// Current session phase.
    CompositionPhase phase {CompositionPhase::INACTIVE};
    /// Whether composition decoration and IME composing offsets should be exposed.
    bool visible {false};
    /// Source and ownership of the active composition.
    CompositionKind kind {CompositionKind::NONE};
    /// Start position of composition in the document.
    TextPosition start_position;
    /// Authoritative document range owned by this composition session.
    TextRange anchor_range;
    /// Original text captured from anchor_range.
    U8String original_text;
    /// Current composing text.
    U8String composing_text;
    /// UTF-16 column count of current composing text for exact cursor placement.
    size_t composing_columns {0};
  };

}

#endif //SWEETEDITOR_IME_TYPES_H
