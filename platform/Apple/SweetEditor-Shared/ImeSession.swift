import Foundation

package final class ImeSession {
    private let core: EditorCore
    package private(set) var state = ImeState()
    package private(set) var isEnabled = true

    package init(core: EditorCore) {
        self.core = core
    }

    package var isActive: Bool {
        state.session_id != 0
    }

    package var hasComposition: Bool {
        Self.range(from: state.composition_range) != nil
    }

    package var selectionRange: NSRange? {
        Self.range(from: state.selection)
    }

    package var compositionRange: NSRange? {
        Self.range(from: state.composition_range)
    }

    package var totalLength: Int? {
        context(start: 0, length: 0).map { Int($0.total_length_utf16) }
    }

    @discardableResult
    package func begin() -> Bool {
        guard !isActive,
              let nextState = core.beginImeSession(.COMMAND),
              nextState.result_code == .OK,
              nextState.session_id != 0 else {
            return false
        }
        state = nextState
        return true
    }

    @discardableResult
    package func end() -> EditorActionResult? {
        guard isActive else { return nil }
        let sessionId = state.session_id
        clear()
        return core.endImeSession(sessionId)
    }

    @discardableResult
    package func setEnabled(_ enabled: Bool) -> EditorActionResult? {
        guard isEnabled != enabled else { return nil }
        isEnabled = enabled
        if !enabled && hasComposition {
            return cancelComposition()
        }
        return nil
    }

    package func synchronize(_ result: EditorActionResult) {
        if result.ime_host_action == .CLOSE_SESSION
            || result.ime_host_action == .RESTART_SESSION {
            clear()
            return
        }
        let nextState = result.ime_state
        if nextState.result_code == .OK,
           nextState.session_id == state.session_id,
           nextState.session_id != 0 {
            state = nextState
        }
    }

    package func text(in range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let context = context(start: range.location, length: range.length) else {
            return nil
        }
        return context.text
    }

    package func setSelection(_ range: NSRange, affinity: CaretAffinity) -> EditorActionResult? {
        guard let selection = selection(from: range, affinity: affinity) else { return nil }
        return apply([ImeCommand(kind: .SET_SELECTION, selection_after: selection)])
    }

    package func updateComposition(
        _ text: String,
        selectedRange: NSRange,
        replacementRange: NSRange? = nil
    ) -> EditorActionResult? {
        guard isEnabled, isActive else { return nil }

        let textLength = text.utf16.count
        guard Self.isValid(selectedRange, upperBound: textLength) else { return nil }

        var commands: [ImeCommand] = []
        var target = ImeOffsetRange()
        var selectionBase = 0

        if hasComposition {
            if let replacementRange, replacementRange.location != NSNotFound {
                guard let compositionRange,
                      Self.isValid(replacementRange, upperBound: compositionRange.length) else {
                    return nil
                }
                target = Self.range(replacementRange, coordinateSpace: .COMPOSITION)
                selectionBase = replacementRange.location
            }
        } else {
            guard let selectionRange else { return nil }
            commands.append(ImeCommand(
                kind: .BEGIN_COMPOSITION,
                target_range: Self.range(selectionRange, coordinateSpace: .DOCUMENT)
            ))
        }

        let selectionAfter = ImeSelection(
            coordinate_space: .COMPOSITION,
            anchor_utf16: Int64(selectionBase + selectedRange.location),
            active_utf16: Int64(selectionBase + selectedRange.location + selectedRange.length),
            affinity: .DOWNSTREAM
        )
        commands.append(ImeCommand(
            kind: .UPDATE_COMPOSITION,
            target_range: target,
            selection_after: selectionAfter,
            text: text
        ))
        return apply(commands)
    }

    package func commitText(_ text: String, replacementRange: NSRange? = nil) -> EditorActionResult? {
        guard isActive else { return nil }
        guard let replacementRange else {
            return apply([ImeCommand(kind: .COMMIT_TEXT, text: text)])
        }
        guard replacementRange.location != NSNotFound else {
            return apply([ImeCommand(kind: .COMMIT_TEXT, text: text)])
        }
        guard Self.isWellFormed(replacementRange) else { return nil }

        let target = Self.range(replacementRange, coordinateSpace: .DOCUMENT)
        if hasComposition, compositionRange != replacementRange {
            return apply([
                ImeCommand(kind: .FINISH_COMPOSITION),
                ImeCommand(kind: .COMMIT_TEXT, target_range: target, text: text),
            ])
        }
        return apply([ImeCommand(kind: .COMMIT_TEXT, text: text)])
    }

    package func finishComposition() -> EditorActionResult? {
        guard isActive else { return nil }
        return apply([ImeCommand(kind: .FINISH_COMPOSITION)])
    }

    package func cancelComposition() -> EditorActionResult? {
        guard isActive else { return nil }
        return apply([ImeCommand(kind: .CANCEL_COMPOSITION)])
    }

    private func apply(_ commands: [ImeCommand]) -> EditorActionResult? {
        guard isActive, !commands.isEmpty else { return nil }
        let sessionId = state.session_id
        let result = core.applyImeCommands(ImeCommandBatch(session_id: sessionId, commands: commands))
        if result.ime_host_action != .NONE
            || result.ime_state.result_code == .SESSION_MISMATCH
            || result.ime_state.result_code == .REJECTED
            || result.ime_state.result_code == .READ_ONLY {
            clear()
        } else if result.ime_state.session_id == sessionId {
            state = result.ime_state
        }
        return result
    }

    private func context(start: Int, length: Int) -> ImeTextContext? {
        guard isActive, start >= 0, length >= 0,
              let context = core.getImeContext(
                state.session_id,
                source: .EDITING,
                startUtf16: Int64(start),
                lengthUtf16: Int64(length)
              ),
              context.result_code == .OK else {
            return nil
        }
        return context
    }

    private func selection(from range: NSRange, affinity: CaretAffinity) -> ImeSelection? {
        guard range.location != NSNotFound else { return nil }
        let start = Int64(range.location)
        let end = Int64(range.location + range.length)
        let current = state.selection
        if min(current.anchor_utf16, current.active_utf16) == start,
           max(current.anchor_utf16, current.active_utf16) == end {
            return current
        }
        return ImeSelection(
            coordinate_space: .DOCUMENT,
            anchor_utf16: start,
            active_utf16: end,
            affinity: range.length == 0 ? affinity : .UPSTREAM
        )
    }

    private func clear() {
        state = ImeState()
    }

    private static func range(from selection: ImeSelection) -> NSRange? {
        guard selection.anchor_utf16 >= 0, selection.active_utf16 >= 0 else { return nil }
        let start = min(selection.anchor_utf16, selection.active_utf16)
        let end = max(selection.anchor_utf16, selection.active_utf16)
        guard start <= Int.max, end <= Int.max else { return nil }
        return NSRange(location: Int(start), length: Int(end - start))
    }

    private static func range(from range: ImeOffsetRange) -> NSRange? {
        guard range.start_utf16 >= 0, range.end_utf16 >= range.start_utf16,
              range.start_utf16 <= Int.max, range.end_utf16 <= Int.max else {
            return nil
        }
        return NSRange(location: Int(range.start_utf16), length: Int(range.end_utf16 - range.start_utf16))
    }

    private static func range(_ range: NSRange, coordinateSpace: ImeCoordinateSpace) -> ImeOffsetRange {
        ImeOffsetRange(
            coordinate_space: coordinateSpace,
            start_utf16: Int64(range.location),
            end_utf16: Int64(range.location + range.length)
        )
    }

    private static func isValid(_ range: NSRange, upperBound: Int) -> Bool {
        range.location != NSNotFound
            && range.location >= 0
            && range.length >= 0
            && range.location <= upperBound
            && range.length <= upperBound - range.location
    }

    private static func isWellFormed(_ range: NSRange) -> Bool {
        range.location != NSNotFound
            && range.location >= 0
            && range.length >= 0
            && range.length <= Int.max - range.location
    }
}
