package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.foundation.CaretAffinity;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.ime.ImeCommand;
import com.qiplat.sweeteditor.core.ime.ImeCommandBatch;
import com.qiplat.sweeteditor.core.ime.ImeCommandKind;
import com.qiplat.sweeteditor.core.ime.ImeCoordinateSpace;
import com.qiplat.sweeteditor.core.ime.ImeHostAction;
import com.qiplat.sweeteditor.core.ime.ImeMutationModel;
import com.qiplat.sweeteditor.core.ime.ImeOffsetRange;
import com.qiplat.sweeteditor.core.ime.ImeResultCode;
import com.qiplat.sweeteditor.core.ime.ImeSelection;
import com.qiplat.sweeteditor.core.ime.ImeState;
import com.qiplat.sweeteditor.core.ime.ImeTextContext;
import com.qiplat.sweeteditor.core.ime.ImeTextSource;
import com.qiplat.sweeteditor.core.visual.CursorRect;

import java.awt.IllegalComponentStateException;
import java.awt.Point;
import java.awt.Rectangle;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.awt.event.InputMethodEvent;
import java.awt.event.InputMethodListener;
import java.awt.font.TextHitInfo;
import java.awt.im.InputContext;
import java.awt.im.InputMethodRequests;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.ArrayList;
import java.util.List;

final class InputConnection implements InputMethodListener, InputMethodRequests, FocusListener {
    private final SweetEditor owner;
    private ImeState state = new ImeState();
    private boolean endingInputContext;

    InputConnection(SweetEditor owner) {
        this.owner = owner;
    }

    boolean hasComposition() {
        return isRange(state.compositionRange);
    }

    private void beginSession() {
        if (isActive()) return;
        ImeState next = core().beginImeSession(ImeMutationModel.COMMAND);
        if (next == null || next.resultCode != ImeResultCode.OK || next.sessionId == 0) {
            return;
        }
        state = next;
    }

    void endSession(boolean endInputContext) {
        if (isActive()) {
            long sessionId = state.sessionId;
            state = new ImeState();
            owner.dispatchEditorActionResult(core().endImeSession(sessionId));
        }
        if (endInputContext) {
            endInputContextComposition();
        }
    }

    void synchronize(EditorActionResult result) {
        if (result == null) return;
        if (result.imeHostAction != ImeHostAction.NONE) {
            state = new ImeState();
            endInputContextComposition();
            return;
        }
        ImeState next = result.imeState;
        if (isActive() && next != null && next.resultCode == ImeResultCode.OK
                && next.sessionId == state.sessionId) {
            state = next;
        }
    }

    @Override
    public void focusGained(FocusEvent event) {
        beginSession();
    }

    @Override
    public void focusLost(FocusEvent event) {
        endSession(false);
    }

    @Override
    public void inputMethodTextChanged(InputMethodEvent event) {
        try {
            if (endingInputContext || !isActive()) return;
            String text = iteratorText(event.getText());
            int committedLength = Math.min(Math.max(event.getCommittedCharacterCount(), 0), text.length());
            String committed = text.substring(0, committedLength);
            String composed = text.substring(committedLength);
            List<ImeCommand> commands = new ArrayList<>(2);
            if (!committed.isEmpty()) {
                commands.add(command(ImeCommandKind.COMMIT_TEXT, committed));
            }
            if (!composed.isEmpty()) {
                ImeCommand update = command(ImeCommandKind.UPDATE_COMPOSITION, composed);
                int caret = compositionCaret(event.getCaret(), composed.length());
                update.selectionAfter = selection(ImeCoordinateSpace.COMPOSITION, caret, affinity(event.getCaret()));
                commands.add(update);
            } else if (committed.isEmpty() && hasComposition()) {
                commands.add(command(ImeCommandKind.COMMIT_TEXT, ""));
            }
            apply(commands);
            if (event.getVisiblePosition() != null) {
                owner.dispatchEditorActionResult(core().ensureCursorVisible());
            }
            owner.resetCursorBlink();
        } finally {
            event.consume();
        }
    }

    @Override
    public void caretPositionChanged(InputMethodEvent event) {
        try {
            TextHitInfo caret = event.getCaret();
            if (endingInputContext || caret == null || !hasComposition()) return;
            int compositionLength = compositionLength();
            int relativeOffset = clamp(caret.getInsertionIndex(), 0, compositionLength);
            long documentOffset = state.compositionRange.startUtf16 + relativeOffset;
            ImeCommand command = new ImeCommand();
            command.kind = ImeCommandKind.SET_SELECTION;
            command.selectionAfter = selection(ImeCoordinateSpace.DOCUMENT, documentOffset, affinity(caret));
            apply(List.of(command));
        } finally {
            event.consume();
        }
    }

    @Override
    public Rectangle getTextLocation(TextHitInfo offset) {
        refreshState();
        long documentOffset;
        if (hasComposition()) {
            int relativeOffset = offset == null ? 0 : clamp(offset.getInsertionIndex(), 0, compositionLength());
            documentOffset = state.compositionRange.startUtf16 + relativeOffset;
        } else {
            documentOffset = validSelection(state.selection) ? state.selection.activeUtf16 : 0;
        }
        return screenRect(documentOffset);
    }

    @Override
    public TextHitInfo getLocationOffset(int x, int y) {
        refreshState();
        if (!hasComposition()) return null;
        Point origin = screenOrigin();
        int localX = x - origin.x;
        int localY = y - origin.y;
        ImeTextContext compositionContext = context(
                ImeTextSource.EDITING, state.compositionRange.startUtf16, compositionLength());
        if (compositionContext == null) return null;
        String composition = compositionContext.text;

        int bestOffset = -1;
        float bestX = 0;
        float bestDistance = Float.MAX_VALUE;
        float lineMinX = Float.MAX_VALUE;
        float lineMaxX = -Float.MAX_VALUE;
        for (int offset = 0; offset <= composition.length(); offset++) {
            if (!isUtf16Boundary(composition, offset)) continue;
            CursorRect rect = positionRect(state.compositionRange.startUtf16 + offset);
            if (rect == null || localY < rect.y - 2 || localY > rect.y + rect.height + 2) continue;
            lineMinX = Math.min(lineMinX, rect.x);
            lineMaxX = Math.max(lineMaxX, rect.x);
            float distance = Math.abs(localX - rect.x);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestOffset = offset;
                bestX = rect.x;
            }
        }
        if (bestOffset < 0 || localX < lineMinX - 8 || localX > lineMaxX + 8) return null;
        if (bestOffset > 0 && localX < bestX) {
            return TextHitInfo.trailing(bestOffset - 1);
        }
        return TextHitInfo.leading(bestOffset);
    }

    @Override
    public int getInsertPositionOffset() {
        refreshState();
        if (!validSelection(state.selection)) return 0;
        return toInt(projectToCommitted(state.selection.activeUtf16));
    }

    @Override
    public AttributedCharacterIterator getCommittedText(
            int beginIndex,
            int endIndex,
            AttributedCharacterIterator.Attribute[] attributes) {
        int totalLength = committedLength();
        if (beginIndex < 0 || endIndex < beginIndex || endIndex > totalLength) {
            throw new IllegalArgumentException("Invalid committed text range");
        }
        String text = exactCommittedText(beginIndex, endIndex, totalLength);
        return new AttributedString(text == null ? "" : text).getIterator();
    }

    @Override
    public int getCommittedTextLength() {
        return committedLength();
    }

    @Override
    public AttributedCharacterIterator cancelLatestCommittedText(
            AttributedCharacterIterator.Attribute[] attributes) {
        return null;
    }

    @Override
    public AttributedCharacterIterator getSelectedText(AttributedCharacterIterator.Attribute[] attributes) {
        refreshState();
        if (!validSelection(state.selection)) return null;
        long start = projectToCommitted(Math.min(state.selection.anchorUtf16, state.selection.activeUtf16));
        long end = projectToCommitted(Math.max(state.selection.anchorUtf16, state.selection.activeUtf16));
        if (start >= end || end > Integer.MAX_VALUE) return null;
        int totalLength = committedLength();
        String text = exactCommittedText((int) start, (int) end, totalLength);
        return text == null || text.isEmpty() ? null : new AttributedString(text).getIterator();
    }

    private EditorCore core() {
        return owner.getEditorCore();
    }

    private boolean isActive() {
        return state.sessionId != 0;
    }

    private void apply(List<ImeCommand> commands) {
        if (!isActive() || commands.isEmpty()) return;
        owner.dispatchEditorActionResult(core().applyImeCommands(new ImeCommandBatch(state.sessionId, commands)));
    }

    private void refreshState() {
        if (!isActive()) return;
        ImeState next = core().getImeState(state.sessionId);
        if (next != null && next.resultCode == ImeResultCode.OK && next.sessionId == state.sessionId) {
            state = next;
        }
    }

    private ImeTextContext context(ImeTextSource source, long start, long length) {
        if (!isActive()) return null;
        ImeTextContext context = core().getImeContext(state.sessionId, source, start, length);
        return context != null && context.resultCode == ImeResultCode.OK ? context : null;
    }

    private int committedLength() {
        refreshState();
        ImeTextContext context = context(ImeTextSource.COMMITTED, 0, 0);
        return context == null ? 0 : toInt(context.totalLengthUtf16);
    }

    private String exactCommittedText(int begin, int end, int totalLength) {
        int queryStart = Math.max(0, begin - 1);
        int queryEnd = Math.min(totalLength, end + 1);
        ImeTextContext context = context(ImeTextSource.COMMITTED, queryStart, queryEnd - queryStart);
        if (context == null) return null;
        long localStart = begin - context.sliceStartUtf16;
        long localEnd = end - context.sliceStartUtf16;
        if (localStart < 0 || localEnd < localStart || localEnd > context.text.length()) return null;
        return context.text.substring((int) localStart, (int) localEnd);
    }

    private long projectToCommitted(long editingOffset) {
        if (!hasComposition()) return editingOffset;
        long compositionStart = state.compositionRange.startUtf16;
        long compositionEnd = state.compositionRange.endUtf16;
        if (editingOffset < compositionStart) return editingOffset;
        ImeTextContext editing = context(ImeTextSource.EDITING, 0, 0);
        ImeTextContext committed = context(ImeTextSource.COMMITTED, 0, 0);
        if (editing == null || committed == null) return editingOffset;
        long baselineEnd = compositionEnd + committed.totalLengthUtf16 - editing.totalLengthUtf16;
        if (editingOffset >= compositionEnd) {
            return editingOffset + baselineEnd - compositionEnd;
        }
        return compositionStart;
    }

    private int compositionLength() {
        return toInt(state.compositionRange.endUtf16 - state.compositionRange.startUtf16);
    }

    private Rectangle screenRect(long documentOffset) {
        CursorRect rect = positionRect(documentOffset);
        Point origin = screenOrigin();
        if (rect == null) return new Rectangle(origin.x, origin.y, 0, 1);
        return new Rectangle(origin.x + Math.round(rect.x), origin.y + Math.round(rect.y), 0,
                Math.max(1, Math.round(rect.height)));
    }

    private CursorRect positionRect(long documentOffset) {
        TextPosition position = positionForOffset(documentOffset);
        return position == null ? null : owner.getPositionRect(position.line, position.column);
    }

    private TextPosition positionForOffset(long offset) {
        Document document = owner.getDocument();
        if (document == null || offset < 0) return null;
        long remaining = offset;
        int lineCount = document.getLineCount();
        for (int line = 0; line < lineCount; line++) {
            int lineLength = document.getLineText(line).length();
            if (remaining <= lineLength) return new TextPosition(line, (int) remaining);
            remaining -= lineLength;
            if (line + 1 < lineCount) {
                remaining--;
            }
        }
        return lineCount == 0 ? new TextPosition() : new TextPosition(
                lineCount - 1,
                document.getLineText(lineCount - 1).length());
    }

    private Point screenOrigin() {
        try {
            return owner.getLocationOnScreen();
        } catch (IllegalComponentStateException ignored) {
            return new Point();
        }
    }

    private void endInputContextComposition() {
        if (endingInputContext) return;
        InputContext inputContext = owner.getInputContext();
        if (inputContext == null) return;
        endingInputContext = true;
        try {
            inputContext.endComposition();
        } finally {
            endingInputContext = false;
        }
    }

    private static ImeCommand command(ImeCommandKind kind, String text) {
        ImeCommand command = new ImeCommand();
        command.kind = kind;
        command.text = text;
        return command;
    }

    private static ImeSelection selection(ImeCoordinateSpace space, long offset, CaretAffinity affinity) {
        return new ImeSelection(space, offset, offset, affinity);
    }

    private static CaretAffinity affinity(TextHitInfo hit) {
        return hit != null && !hit.isLeadingEdge() ? CaretAffinity.UPSTREAM : CaretAffinity.DOWNSTREAM;
    }

    private static int compositionCaret(TextHitInfo caret, int length) {
        return caret == null ? 0 : clamp(caret.getInsertionIndex(), 0, length);
    }

    private static String iteratorText(AttributedCharacterIterator iterator) {
        if (iterator == null) return "";
        StringBuilder text = new StringBuilder();
        for (char current = iterator.first(); current != AttributedCharacterIterator.DONE; current = iterator.next()) {
            text.append(current);
        }
        return text.toString();
    }

    private static boolean isRange(ImeOffsetRange range) {
        return range != null && range.startUtf16 >= 0 && range.endUtf16 >= range.startUtf16;
    }

    private static boolean validSelection(ImeSelection selection) {
        return selection != null && selection.anchorUtf16 >= 0 && selection.activeUtf16 >= 0;
    }

    private static boolean isUtf16Boundary(String text, int offset) {
        return offset <= 0 || offset >= text.length()
                || !Character.isHighSurrogate(text.charAt(offset - 1))
                || !Character.isLowSurrogate(text.charAt(offset));
    }

    private static int clamp(int value, int minimum, int maximum) {
        return Math.max(minimum, Math.min(value, maximum));
    }

    private static int toInt(long value) {
        if (value < 0) return 0;
        return value > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) value;
    }
}
