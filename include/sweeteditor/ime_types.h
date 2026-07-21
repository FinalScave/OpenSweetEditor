#ifndef SWEETEDITOR_IME_TYPES_H
#define SWEETEDITOR_IME_TYPES_H

#include <cstdint>
#include <optional>
#include <sweeteditor/editor_types.h>

namespace NS_SWEETEDITOR {

  enum class SE_PROTOCOL_ENUM(ime, COMMAND) ImeMutationModel {
    COMMAND = 0,
    TEXT_UPDATE = 1,
  };

  enum class SE_PROTOCOL_ENUM(ime, EDITING) ImeTextSource {
    EDITING = 0,
    COMMITTED = 1,
    EDITING_BUFFER = 2,
  };

  enum class SE_PROTOCOL_ENUM(ime, DOCUMENT) ImeCoordinateSpace {
    DOCUMENT = 0,
    EDITING_BUFFER = 1,
    CONTEXT_SLICE = 2,
    COMPOSITION = 3,
  };

  enum class SE_PROTOCOL_ENUM(ime, UTF16_CODE_UNIT) ImeTextUnit {
    UTF16_CODE_UNIT = 0,
    UNICODE_CODE_POINT = 1,
  };

  enum class SE_PROTOCOL_ENUM(ime, SET_SELECTION) ImeCommandKind {
    SET_SELECTION = 0,
    BEGIN_COMPOSITION = 1,
    UPDATE_COMPOSITION = 2,
    COMMIT_TEXT = 3,
    FINISH_COMPOSITION = 4,
    CANCEL_COMPOSITION = 5,
    DELETE_SURROUNDING = 6,
  };

  enum class SE_PROTOCOL_ENUM(ime, OK) ImeResultCode {
    OK = 0,
    SESSION_MISMATCH = 1,
    REJECTED = 2,
    READ_ONLY = 3,
  };

  enum class SE_PROTOCOL_ENUM(ime, NONE) ImeHostAction {
    NONE = 0,
    CLOSE_SESSION = 1,
    RESTART_SESSION = 2,
  };

  struct SE_PROTOCOL_VALUE(ime) ImeOffsetRange {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeCoordinateSpace coordinate_space {ImeCoordinateSpace::DOCUMENT};
    int64_t start_utf16 {-1};
    int64_t end_utf16 {-1};

    bool operator==(const ImeOffsetRange& other) const;
    bool operator!=(const ImeOffsetRange& other) const;
  };

  struct SE_PROTOCOL_VALUE(ime) ImeSelection {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeCoordinateSpace coordinate_space {ImeCoordinateSpace::DOCUMENT};
    int64_t anchor_utf16 {-1};
    int64_t active_utf16 {-1};
    SE_PROTOCOL_WIRE(enum_i32)
    CaretAffinity affinity {CaretAffinity::DOWNSTREAM};

    bool operator==(const ImeSelection& other) const;
    bool operator!=(const ImeSelection& other) const;
  };

  struct SE_PROTOCOL_IN(ime) ImeCommand {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeCommandKind kind {ImeCommandKind::SET_SELECTION};
    ImeOffsetRange target_range;
    ImeSelection selection_after;
    U8String text;
    int64_t delete_before {0};
    int64_t delete_after {0};
    SE_PROTOCOL_WIRE(enum_i32)
    ImeTextUnit text_unit {ImeTextUnit::UTF16_CODE_UNIT};
  };

  struct SE_PROTOCOL_IN(ime) ImeCommandBatch {
    uint64_t session_id {0};
    Vector<ImeCommand> commands;
  };

  struct SE_PROTOCOL_IN(ime) ImeTextUpdateStep {
    U8String old_text;
    ImeOffsetRange patch_range;
    U8String replacement_text;
    ImeSelection selection_after;
    ImeOffsetRange composition_after;
  };

  struct SE_PROTOCOL_IN(ime) ImeTextUpdateBatch {
    uint64_t session_id {0};
    uint64_t expected_state_revision {0};
    Vector<ImeTextUpdateStep> steps;
  };

  struct SE_PROTOCOL_OUT(ime) ImeState {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeResultCode result_code {ImeResultCode::OK};
    uint64_t session_id {0};
    uint64_t state_revision {0};
    ImeSelection selection;
    ImeOffsetRange composition_range;
  };

  struct SE_PROTOCOL_OUT(ime) ImeTextContext {
    SE_PROTOCOL_WIRE(enum_i32)
    ImeResultCode result_code {ImeResultCode::OK};
    int64_t slice_start_utf16 {0};
    int64_t total_length_utf16 {0};
    U8String text;
    ImeSelection selection;
    ImeOffsetRange composition_range;
  };

  struct CompositionState {
    TextRange current_range;
    std::optional<U8String> baseline_text_raw;
    CaretState baseline_caret;

    bool operator==(const CompositionState& other) const;
    bool operator!=(const CompositionState& other) const;
  };

  struct EditingBufferState {
    TextRange document_range;
    U8String text;
    int64_t safe_start_utf16 {0};
    int64_t safe_end_utf16 {0};
    uint64_t state_revision {1};
  };

  struct ImeSessionState {
    uint64_t session_id {0};
    std::optional<CompositionState> composition;
    std::optional<EditingBufferState> editing_buffer;
  };

  struct ImeActionResult {
    bool handled {false};
    TextEditResult edit_result;
    ImeHostAction host_action {ImeHostAction::NONE};
    ImeState state;
  };

}

#endif //SWEETEDITOR_IME_TYPES_H
