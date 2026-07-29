#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum ImeCommandKind {
        SET_SELECTION = 0,
        BEGIN_COMPOSITION = 1,
        UPDATE_COMPOSITION = 2,
        COMMIT_TEXT = 3,
        FINISH_COMPOSITION = 4,
        CANCEL_COMPOSITION = 5,
        DELETE_SURROUNDING = 6
    }

    public enum ImeCoordinateSpace {
        DOCUMENT = 0,
        EDITING_BUFFER = 1,
        CONTEXT_SLICE = 2,
        COMPOSITION = 3
    }

    public enum ImeHostAction {
        NONE = 0,
        CLOSE_SESSION = 1,
        RESTART_SESSION = 2,
        SYNC_EDITING_STATE = 3
    }

    public enum ImeMutationModel {
        COMMAND = 0,
        TEXT_UPDATE = 1
    }

    public enum ImeResultCode {
        OK = 0,
        SESSION_MISMATCH = 1,
        REJECTED = 2,
        READ_ONLY = 3
    }

    public enum ImeTextSource {
        EDITING = 0,
        COMMITTED = 1,
        EDITING_BUFFER = 2
    }

    public enum ImeTextUnit {
        UTF16_CODE_UNIT = 0,
        UNICODE_CODE_POINT = 1
    }

    public sealed partial class ImeCommand {
        public ImeCommandKind Kind { get; set; } = ImeCommandKind.SET_SELECTION;
        public ImeOffsetRange TargetRange { get; set; } = new ImeOffsetRange();
        public ImeSelection SelectionAfter { get; set; } = new ImeSelection();
        public string Text { get; set; } = string.Empty;
        public long DeleteBefore { get; set; } = 0L;
        public long DeleteAfter { get; set; } = 0L;
        public ImeTextUnit TextUnit { get; set; } = ImeTextUnit.UTF16_CODE_UNIT;
    }

    public sealed partial class ImeCommandBatch {
        public long SessionId { get; set; } = 0L;
        public List<ImeCommand> Commands { get; set; } = new();
    }

    public sealed partial class ImeOffsetRange {
        public ImeCoordinateSpace CoordinateSpace { get; set; } = ImeCoordinateSpace.DOCUMENT;
        public long StartUtf16 { get; set; } = -1L;
        public long EndUtf16 { get; set; } = -1L;
    }

    public sealed partial class ImeSelection {
        public ImeCoordinateSpace CoordinateSpace { get; set; } = ImeCoordinateSpace.DOCUMENT;
        public long AnchorUtf16 { get; set; } = -1L;
        public long ActiveUtf16 { get; set; } = -1L;
        public CaretAffinity Affinity { get; set; } = CaretAffinity.DOWNSTREAM;
    }

    public sealed partial class ImeState {
        public ImeResultCode ResultCode { get; set; } = ImeResultCode.OK;
        public long SessionId { get; set; } = 0L;
        public long StateRevision { get; set; } = 0L;
        public ImeSelection Selection { get; set; } = new ImeSelection();
        public ImeOffsetRange CompositionRange { get; set; } = new ImeOffsetRange();
    }

    public sealed partial class ImeTextContext {
        public ImeResultCode ResultCode { get; set; } = ImeResultCode.OK;
        public long SliceStartUtf16 { get; set; } = 0L;
        public long TotalLengthUtf16 { get; set; } = 0L;
        public string Text { get; set; } = string.Empty;
        public ImeSelection Selection { get; set; } = new ImeSelection();
        public ImeOffsetRange CompositionRange { get; set; } = new ImeOffsetRange();
    }

    public sealed partial class ImeTextUpdateBatch {
        public long SessionId { get; set; } = 0L;
        public long ExpectedStateRevision { get; set; } = 0L;
        public List<ImeTextUpdateStep> Steps { get; set; } = new();
    }

    public sealed partial class ImeTextUpdateStep {
        public string OldText { get; set; } = string.Empty;
        public ImeOffsetRange PatchRange { get; set; } = new ImeOffsetRange();
        public string ReplacementText { get; set; } = string.Empty;
        public ImeSelection SelectionAfter { get; set; } = new ImeSelection();
        public ImeOffsetRange CompositionAfter { get; set; } = new ImeOffsetRange();
    }
}
