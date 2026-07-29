package com.qiplat.sweeteditor;

import android.annotation.TargetApi;
import android.content.Context;
import android.os.Build;
import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.view.inputmethod.SurroundingText;
import android.view.inputmethod.TextAttribute;

import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.foundation.CaretAffinity;
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
import com.qiplat.sweeteditor.core.ime.ImeTextUnit;

import java.util.ArrayList;
import java.util.List;

public class SweetEditorInputConnection extends BaseInputConnection {
    private static final int MAX_IME_TEXT_LENGTH = 32768;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable = new SpannableStringBuilder();
    private final Object mComposingSpan = new Object();
    private long mSessionId;
    private long mWindowStartUtf16;
    private long mTotalLengthUtf16;
    private ImeState mState = new ImeState();

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        Selection.setSelection(mEditable, 0);
        ImeState state = mEditor.getEditorCore().beginImeSession(ImeMutationModel.COMMAND);
        if (state.resultCode != ImeResultCode.OK || state.sessionId == 0) {
            return;
        }
        mSessionId = state.sessionId;
    }

    @Override
    public void closeConnection() {
        closeOwnedSession();
        super.closeConnection();
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    boolean configureEditorInfo(EditorInfo outAttrs) {
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT
                | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE
                | EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT;
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        if (!syncFromCore()) {
            outAttrs.initialSelStart = 0;
            outAttrs.initialSelEnd = 0;
            return false;
        }
        outAttrs.initialSelStart = safeInt(mState.selection.anchorUtf16);
        outAttrs.initialSelEnd = safeInt(mState.selection.activeUtf16);
        int active = clampEditableOffset(mState.selection.activeUtf16 - mWindowStartUtf16);
        outAttrs.initialCapsMode = TextUtils.getCapsMode(mEditable, active,
                TextUtils.CAP_MODE_CHARACTERS | TextUtils.CAP_MODE_WORDS | TextUtils.CAP_MODE_SENTENCES);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && mEditable.length() > 0) {
            outAttrs.setInitialSurroundingSubText(mEditable, safeInt(mWindowStartUtf16));
        }
        return true;
    }

    @Override
    public boolean setSelection(int start, int end) {
        if (!isActive()) {
            return false;
        }
        ImeCommand command = command(ImeCommandKind.SET_SELECTION);
        command.selectionAfter = documentSelection(
                clampOffset(start, mTotalLengthUtf16),
                clampOffset(end, mTotalLengthUtf16));
        return applyCommands(singleCommand(command), "ime-selection");
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        return replaceCurrentText(ImeCommandKind.UPDATE_COMPOSITION, text, newCursorPosition, "ime-update");
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        if (!isActive()) {
            return false;
        }
        long safeStart = clampOffset(Math.min(start, end), mTotalLengthUtf16);
        long safeEnd = clampOffset(Math.max(start, end), mTotalLengthUtf16);
        List<ImeCommand> commands = new ArrayList<>(2);
        if (hasComposition(mState) || safeStart == safeEnd) {
            commands.add(command(ImeCommandKind.FINISH_COMPOSITION));
        }
        if (safeStart != safeEnd) {
            ImeCommand begin = command(ImeCommandKind.BEGIN_COMPOSITION);
            begin.targetRange = documentRange(safeStart, safeEnd);
            commands.add(begin);
        }
        return applyCommands(commands, "ime-region");
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        return replaceCurrentText(ImeCommandKind.COMMIT_TEXT, text, newCursorPosition, "ime-commit");
    }

    @Override
    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    public boolean replaceText(int start, int end, CharSequence text,
                               int newCursorPosition, TextAttribute textAttribute) {
        if (start < 0 || end < 0 || !isActive()) {
            return false;
        }
        long safeStart = clampOffset(Math.min(start, end), mTotalLengthUtf16);
        long safeEnd = clampOffset(Math.max(start, end), mTotalLengthUtf16);
        String replacement = text != null ? text.toString() : "";
        List<ImeCommand> commands = new ArrayList<>(2);
        if (hasComposition(mState)) {
            commands.add(command(ImeCommandKind.FINISH_COMPOSITION));
        }
        ImeCommand commit = command(ImeCommandKind.COMMIT_TEXT);
        commit.targetRange = documentRange(safeStart, safeEnd);
        commit.text = replacement;
        commit.selectionAfter = collapsedDocumentSelection(cursorAfterReplacement(
                safeStart, safeEnd, replacement.length(), newCursorPosition, mTotalLengthUtf16));
        commands.add(commit);
        return applyCommands(commands, "ime-replace");
    }

    @Override
    public boolean finishComposingText() {
        if (!isActive()) {
            return false;
        }
        return applyCommands(singleCommand(command(ImeCommandKind.FINISH_COMPOSITION)), "ime-finish");
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength, ImeTextUnit.UTF16_CODE_UNIT);
    }

    @Override
    public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength, ImeTextUnit.UNICODE_CODE_POINT);
    }

    @Override
    public boolean sendKeyEvent(KeyEvent event) {
        if (!isActive()) {
            return false;
        }
        if (event.getAction() != KeyEvent.ACTION_DOWN) {
            return true;
        }
        return mEditor.handleKeyEventFromIME(event);
    }

    @Override
    @TargetApi(Build.VERSION_CODES.S)
    public SurroundingText getSurroundingText(int beforeLength, int afterLength, int flags) {
        if (beforeLength < 0 || afterLength < 0 || !syncFromCore()) {
            return null;
        }
        SurroundingText local = super.getSurroundingText(beforeLength, afterLength, flags);
        if (local == null) return null;
        return new SurroundingText(local.getText(), local.getSelectionStart(), local.getSelectionEnd(),
                safeInt(mWindowStartUtf16 + local.getOffset()));
    }

    void onEditorActionResult(EditorActionResult result) {
        if (!isActive() || result == null) {
            return;
        }
        if (result.imeHostAction != ImeHostAction.NONE) {
            closeLocalSession();
            executeHostAction(result.imeHostAction);
            return;
        }
        if (result.imeState != null
                && result.imeState.resultCode == ImeResultCode.OK
                && result.imeState.sessionId == mSessionId
                && needsImeNotification(result)
                && syncMirror(result.imeState)) {
            updateImeSelectionState();
        } else if (result.imeState != null
                && result.imeState.resultCode == ImeResultCode.SESSION_MISMATCH) {
            closeLocalSession();
            executeHostAction(ImeHostAction.RESTART_SESSION);
        }
    }

    private boolean replaceCurrentText(ImeCommandKind kind, CharSequence text, int newCursorPosition,
                                       String perfName) {
        if (!isActive()) {
            return false;
        }
        String replacement = text != null ? text.toString() : "";
        long start;
        long end;
        if (hasComposition(mState)) {
            start = mState.compositionRange.startUtf16;
            end = mState.compositionRange.endUtf16;
        } else {
            start = Math.min(mState.selection.anchorUtf16, mState.selection.activeUtf16);
            end = Math.max(mState.selection.anchorUtf16, mState.selection.activeUtf16);
        }
        ImeCommand command = command(kind);
        command.text = replacement;
        command.selectionAfter = collapsedDocumentSelection(cursorAfterReplacement(
                start, end, replacement.length(), newCursorPosition, mTotalLengthUtf16));
        return applyCommands(singleCommand(command), perfName);
    }

    private boolean deleteSurroundingTextInternal(int beforeLength, int afterLength, ImeTextUnit textUnit) {
        if (beforeLength < 0 || afterLength < 0 || !isActive()) {
            return false;
        }
        ImeCommand command = command(ImeCommandKind.DELETE_SURROUNDING);
        command.deleteBefore = beforeLength;
        command.deleteAfter = afterLength;
        command.textUnit = textUnit;
        return applyCommands(singleCommand(command), "ime-delete");
    }

    private boolean applyCommands(List<ImeCommand> commands, String perfName) {
        if (!isActive() || commands.isEmpty()) {
            return false;
        }
        long startTimeNanos = System.nanoTime();
        EditorActionResult result = mEditor.getEditorCore().applyImeCommands(new ImeCommandBatch(mSessionId, commands));
        boolean accepted = result.handled && result.imeState != null
                && result.imeState.resultCode == ImeResultCode.OK;
        mEditor.dispatchEditorActionResult(result, this);
        mEditor.logInputPerf(startTimeNanos, perfName);
        return accepted;
    }

    private boolean syncFromCore() {
        if (!isActive()) {
            return false;
        }
        ImeState state = mEditor.getEditorCore().getImeState(mSessionId);
        if (state.resultCode != ImeResultCode.OK || state.sessionId != mSessionId) {
            closeLocalSession();
            return false;
        }
        return syncMirror(state);
    }

    private boolean syncMirror(ImeState state) {
        long selectionStart = Math.min(state.selection.anchorUtf16, state.selection.activeUtf16);
        long selectionEnd = Math.max(state.selection.anchorUtf16, state.selection.activeUtf16);
        long requiredStart = selectionStart;
        long requiredEnd = selectionEnd;
        if (hasComposition(state)) {
            requiredStart = Math.min(requiredStart, state.compositionRange.startUtf16);
            requiredEnd = Math.max(requiredEnd, state.compositionRange.endUtf16);
        }
        long start = Math.max(0, requiredStart - MAX_IME_TEXT_LENGTH / 2L);
        long length = Math.max(MAX_IME_TEXT_LENGTH, requiredEnd - start);
        ImeTextContext context = mEditor.getEditorCore().getImeContext(
                mSessionId, ImeTextSource.EDITING, start, length);
        if (context.resultCode != ImeResultCode.OK) {
            return false;
        }
        mState = state;
        mWindowStartUtf16 = context.sliceStartUtf16;
        mTotalLengthUtf16 = context.totalLengthUtf16;
        mEditable.removeSpan(mComposingSpan);
        mEditable.replace(0, mEditable.length(), context.text);
        if (hasSelection(context.selection)) {
            Selection.setSelection(mEditable, clampEditableOffset(context.selection.anchorUtf16),
                    clampEditableOffset(context.selection.activeUtf16));
        } else {
            Selection.setSelection(mEditable, 0);
        }
        if (hasRange(context.compositionRange)
                && context.compositionRange.startUtf16 != context.compositionRange.endUtf16) {
            mEditable.setSpan(mComposingSpan,
                    clampEditableOffset(context.compositionRange.startUtf16),
                    clampEditableOffset(context.compositionRange.endUtf16),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE | Spanned.SPAN_COMPOSING);
        }
        return true;
    }

    private void updateImeSelectionState() {
        if (!isActive()) {
            return;
        }
        InputMethodManager manager = getInputMethodManager();
        if (manager == null) {
            return;
        }
        int compositionStart = -1;
        int compositionEnd = -1;
        if (hasComposition(mState)) {
            compositionStart = safeInt(mState.compositionRange.startUtf16);
            compositionEnd = safeInt(mState.compositionRange.endUtf16);
        }
        manager.updateSelection(mEditor, safeInt(mState.selection.anchorUtf16),
                safeInt(mState.selection.activeUtf16),
                compositionStart,
                compositionEnd);
    }

    private void closeOwnedSession() {
        long sessionId = mSessionId;
        closeLocalSession();
        if (sessionId == 0) {
            return;
        }
        EditorActionResult result = mEditor.getEditorCore().endImeSession(sessionId);
        mEditor.dispatchEditorActionResult(result, this);
    }

    private void closeLocalSession() {
        mSessionId = 0;
        mEditable.removeSpan(mComposingSpan);
        mEditable.clear();
        Selection.setSelection(mEditable, 0);
        mWindowStartUtf16 = 0;
        mTotalLengthUtf16 = 0;
        mState = new ImeState();
    }

    private void executeHostAction(ImeHostAction hostAction) {
        if ((hostAction != ImeHostAction.CLOSE_SESSION
                && hostAction != ImeHostAction.RESTART_SESSION)
                || !mEditor.isCurrentInputConnection(this)
                || !mEditor.hasFocus()) {
            return;
        }
        InputMethodManager manager = getInputMethodManager();
        if (manager != null) {
            manager.restartInput(mEditor);
        }
    }

    private boolean isActive() {
        return mSessionId != 0;
    }

    boolean hasActiveComposition() {
        return isActive() && hasComposition(mState);
    }

    private InputMethodManager getInputMethodManager() {
        return (InputMethodManager) mEditor.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    private int clampEditableOffset(long offset) {
        return safeInt(Math.max(0, Math.min(offset, mEditable.length())));
    }

    private static ImeCommand command(ImeCommandKind kind) {
        ImeCommand command = new ImeCommand();
        command.kind = kind;
        return command;
    }

    private static List<ImeCommand> singleCommand(ImeCommand command) {
        List<ImeCommand> commands = new ArrayList<>(1);
        commands.add(command);
        return commands;
    }

    private static ImeOffsetRange documentRange(long start, long end) {
        return new ImeOffsetRange(ImeCoordinateSpace.DOCUMENT, start, end);
    }

    private static ImeSelection documentSelection(long anchor, long active) {
        return new ImeSelection(ImeCoordinateSpace.DOCUMENT, anchor, active, CaretAffinity.DOWNSTREAM);
    }

    private static ImeSelection collapsedDocumentSelection(long offset) {
        return documentSelection(offset, offset);
    }

    private static boolean hasComposition(ImeState state) {
        return state != null && hasRange(state.compositionRange);
    }

    private static boolean hasRange(ImeOffsetRange range) {
        return range != null && range.startUtf16 >= 0 && range.endUtf16 >= 0;
    }

    private static boolean hasSelection(ImeSelection selection) {
        return selection != null && selection.anchorUtf16 >= 0 && selection.activeUtf16 >= 0;
    }

    private static boolean needsImeNotification(EditorActionResult result) {
        return !result.textChanges.isEmpty() || result.cursorChanged
                || result.selectionChanged || result.compositionChanged;
    }

    static long cursorAfterReplacement(long targetStart, long targetEnd,
                                       int replacementLength, int newCursorPosition,
                                       long oldTotalLength) {
        long newTotalLength = oldTotalLength - (targetEnd - targetStart) + replacementLength;
        long cursor = newCursorPosition > 0
                ? targetStart + replacementLength + newCursorPosition - 1L
                : targetStart + newCursorPosition;
        return clampOffset(cursor, newTotalLength);
    }

    private static long clampOffset(long offset, long length) {
        return Math.max(0, Math.min(offset, Math.max(0, length)));
    }

    private static int safeInt(long value) {
        return (int) Math.max(Integer.MIN_VALUE, Math.min(Integer.MAX_VALUE, value));
    }
}
