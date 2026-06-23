package com.qiplat.sweeteditor;

import android.annotation.TargetApi;
import android.content.Context;
import android.os.Build;
import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.view.inputmethod.TextAttribute;

import com.qiplat.sweeteditor.core.ime.ImeInputContextKind;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeOffsetRange;
import com.qiplat.sweeteditor.core.ime.ImeMarkedRange;
import com.qiplat.sweeteditor.core.ime.ImeMarkedRangeRole;
import com.qiplat.sweeteditor.core.ime.ImeScriptClass;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateKind;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateMessage;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateScope;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.foundation.IntRange;

public class SweetEditorInputConnection extends BaseInputConnection {
    private static final int MAX_IME_TEXT_LENGTH = 32768;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable = new SpannableStringBuilder();
    private boolean mClosed = false;
    private long mInputContextId = 0;
    private int mInputContextRevision = 0;
    private int mInputDocumentStartOffset = 0;
    private ImeMarkedRangeRole mEditableMarkedRole = ImeMarkedRangeRole.NONE;

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        Selection.setSelection(mEditable, 0);
        syncEditableFromCore();
    }

    @Override
    public void closeConnection() {
        mClosed = true;
        clearEditableState();
        super.closeConnection();
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    void configureEditorInfo(EditorInfo outAttrs) {
        ImeInputContext context = syncEditableFromCore();
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT
                | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE
                | EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT;
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        IntRange selectionOffsets = getImeSelectionOffsets(context);
        outAttrs.initialSelStart = selectionOffsets.start;
        outAttrs.initialSelEnd = selectionOffsets.end;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                && context.kind == ImeInputContextKind.DOCUMENT_WINDOW
                && mEditable.length() > 0) {
            outAttrs.setInitialSurroundingSubText(mEditable,
                    Math.max(0, context.documentStartOffset));
        }
    }

    @Override
    public boolean setSelection(int start, int end) {
        if (!isActive() || !ensureEditableTextWindow()) {
            return false;
        }
        int safeStart = clampEditableOffset(start, mEditable.length());
        int safeEnd = clampEditableOffset(end, mEditable.length());
        Selection.setSelection(mEditable, safeStart, safeEnd);
        return sendEditableTextSnapshot("ime-selection");
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        if (!isActive()) {
            return false;
        }
        if (!ensureEditableTextWindow()) {
            return false;
        }
        ImeMarkedRangeRole nextRole = mEditableMarkedRole == ImeMarkedRangeRole.SYSTEM_MARK
                ? ImeMarkedRangeRole.SYSTEM_MARK
                : ImeMarkedRangeRole.PREEDIT;
        super.setComposingText(text != null ? text : "", newCursorPosition);
        mEditableMarkedRole = nextRole;
        refreshEditableMarkedStateAfterLocalEdit();
        return sendEditableTextSnapshot("ime-update");
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean setComposingText(CharSequence text, int newCursorPosition, TextAttribute textAttribute) {
        return setComposingText(text, newCursorPosition);
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        if (!isActive() || !ensureEditableTextWindow()) {
            return false;
        }
        int safeStart = clampEditableOffset(Math.min(start, end), mEditable.length());
        int safeEnd = clampEditableOffset(Math.max(start, end), mEditable.length());
        super.setComposingRegion(safeStart, safeEnd);
        mEditableMarkedRole = ImeMarkedRangeRole.SYSTEM_MARK;
        return sendEditableTextSnapshot("ime-region");
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean setComposingRegion(int start, int end, TextAttribute textAttribute) {
        return setComposingRegion(start, end);
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        if (!isActive()) {
            return false;
        }
        ensureEditableTextWindow();
        ImeMarkedRangeRole markedRole = mEditableMarkedRole;
        if (markedRole == ImeMarkedRangeRole.SYSTEM_MARK && !shouldCommitSystemMarkedRange(text)) {
            BaseInputConnection.removeComposingSpans(mEditable);
        }
        super.commitText(text != null ? text : "", newCursorPosition);
        mEditableMarkedRole = ImeMarkedRangeRole.NONE;
        return sendEditableTextSnapshot("ime-commit");
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean commitText(CharSequence text, int newCursorPosition, TextAttribute textAttribute) {
        return commitText(text, newCursorPosition);
    }

    @Override
    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    public boolean replaceText(int start, int end, CharSequence text,
                               int newCursorPosition, TextAttribute textAttribute) {
        if (!isActive() || !ensureEditableTextWindow() || start < 0 || end < 0) {
            return false;
        }
        super.replaceText(start, end, text != null ? text : "", newCursorPosition, textAttribute);
        mEditableMarkedRole = ImeMarkedRangeRole.NONE;
        return sendEditableTextSnapshot("ime-replace");
    }

    @Override
    public boolean finishComposingText() {
        if (!isActive() || !ensureEditableTextWindow()) {
            return false;
        }
        super.finishComposingText();
        mEditableMarkedRole = ImeMarkedRangeRole.NONE;
        return sendEditableTextSnapshot("ime-finish");
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength);
    }

    @Override
    public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength);
    }

    @Override
    public boolean sendKeyEvent(KeyEvent event) {
        if (!isActive()) {
            return false;
        }
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();
            if (keyCode == KeyEvent.KEYCODE_DEL) {
                return deleteSurroundingText(1, 0);
            }
            if (keyCode == KeyEvent.KEYCODE_FORWARD_DEL) {
                return deleteSurroundingText(0, 1);
            }
            mEditor.handleKeyEventFromIME(event);
        }
        return true;
    }

    IntRange getImeSelectionOffsets(ImeInputContext context) {
        int start = Selection.getSelectionStart(mEditable);
        int end = Selection.getSelectionEnd(mEditable);
        int documentStartOffset = context != null
                ? Math.max(0, context.documentStartOffset)
                : 0;
        if (start < 0 || end < 0) {
            return new IntRange(documentStartOffset, documentStartOffset);
        }
        int documentStart = documentStartOffset + clampEditableOffset(start, mEditable.length());
        int documentEnd = documentStartOffset + clampEditableOffset(end, mEditable.length());
        return documentStart <= documentEnd
                ? new IntRange(documentStart, documentEnd)
                : new IntRange(documentEnd, documentStart);
    }

    void updateImeSelectionState() {
        InputMethodManager imm = getInputMethodManager();
        if (imm == null) {
            return;
        }
        ImeInputContext context = syncEditableFromCore();
        IntRange selectionOffsets = getImeSelectionOffsets(context);
        IntRange composingOffsets = getImeComposingOffsets(context);
        imm.updateSelection(mEditor, selectionOffsets.start, selectionOffsets.end,
                composingOffsets.start, composingOffsets.end);
    }

    private boolean sendEditableTextSnapshot(String perfName) {
        long t0 = System.nanoTime();
        ImeTextUpdateMessage message = new ImeTextUpdateMessage();
        message.kind = ImeTextUpdateKind.SNAPSHOT;
        message.scope = ImeTextUpdateScope.DOCUMENT_WINDOW;
        message.contextId = mInputContextId;
        message.contextRevision = mInputContextRevision;
        message.documentStartOffset = mInputDocumentStartOffset;
        message.text = mEditable.toString();
        message.selection = getEditableSelectionRange();
        message.markedRange = getEditableMarkedRange();
        message.scriptClass = ImeScriptClass.UNKNOWN;
        EditorActionResult result = mEditor.getEditorCore().handleImeTextUpdateMessage(message);
        finishImeAction(result, perfName, t0);
        return result.handled;
    }

    private boolean deleteSurroundingTextInternal(int beforeLength, int afterLength) {
        if (!isActive()) {
            return false;
        }
        if (!ensureEditableTextWindow()) {
            return false;
        }
        int safeBefore = Math.max(0, beforeLength);
        int safeAfter = Math.max(0, afterLength);
        boolean handled = isValidEditableRange(getEditableComposingRange(), mEditable.length())
                ? deleteEditableSurroundingText(safeBefore, safeAfter)
                : super.deleteSurroundingText(safeBefore, safeAfter);
        refreshEditableMarkedStateAfterLocalEdit();
        return sendEditableTextSnapshot("ime-delete") || handled;
    }

    private boolean deleteEditableSurroundingText(int beforeLength, int afterLength) {
        int start = Selection.getSelectionStart(mEditable);
        int end = Selection.getSelectionEnd(mEditable);
        if (start < 0 || end < 0) {
            return false;
        }
        int a = Math.min(start, end);
        int b = Math.max(start, end);
        int deleteStart = Math.max(0, a - beforeLength);
        int deletedBefore = a - deleteStart;
        if (deletedBefore > 0) {
            mEditable.delete(deleteStart, a);
        }
        b -= deletedBefore;
        int deleteEnd = Math.min(mEditable.length(), b + afterLength);
        if (deleteEnd > b) {
            mEditable.delete(b, deleteEnd);
        }
        return true;
    }

    private void finishImeAction(EditorActionResult result, String perfName) {
        finishImeAction(result, perfName, System.nanoTime());
    }

    private void finishImeAction(EditorActionResult result, String perfName, long startTimeNanos) {
        mEditor.dispatchEditorActionResult(result);
        mEditor.logInputPerf(startTimeNanos, perfName);
    }

    void onEditorActionResult(EditorActionResult result) {
        if (result.needsImeSync) {
            updateImeSelectionState();
        }
    }

    private ImeInputContext syncEditableFromCore() {
        ImeInputContext context = mEditor.getEditorCore().getImeTextUpdateInputContext(
                ImeTextUpdateScope.DOCUMENT_WINDOW,
                MAX_IME_TEXT_LENGTH / 2,
                MAX_IME_TEXT_LENGTH / 2);
        if (!isEditableTextWindow(context)) {
            clearEditableState();
            return context;
        }
        syncEditableFromContext(context);
        return context;
    }

    private void syncEditableFromContext(ImeInputContext context) {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.replace(0, mEditable.length(), context.text);
        mEditableMarkedRole = ImeMarkedRangeRole.NONE;
        mInputContextId = context.id;
        mInputContextRevision = context.revision;
        mInputDocumentStartOffset = Math.max(0, context.documentStartOffset);
        int selectionStart = clampEditableOffset(context.selection.start, mEditable.length());
        int selectionEnd = clampEditableOffset(context.selection.end, mEditable.length());
        Selection.setSelection(mEditable, selectionStart, selectionEnd);
        if (context.hasComposition && isValidEditableRange(context.composition, mEditable.length())) {
            int preeditStart = clampEditableOffset(context.composition.start, mEditable.length());
            int preeditEnd = clampEditableOffset(context.composition.end, mEditable.length());
            super.setComposingRegion(preeditStart, preeditEnd);
            mEditableMarkedRole = ImeMarkedRangeRole.PREEDIT;
        } else if (context.hasSystemMarkRange && isValidEditableRange(context.systemMarkRange, mEditable.length())) {
            int markStart = clampEditableOffset(context.systemMarkRange.start, mEditable.length());
            int markEnd = clampEditableOffset(context.systemMarkRange.end, mEditable.length());
            super.setComposingRegion(markStart, markEnd);
            mEditableMarkedRole = ImeMarkedRangeRole.SYSTEM_MARK;
        }
    }

    private IntRange getImeComposingOffsets(ImeInputContext context) {
        if (context != null
                && context.hasSystemMarkRange
                && isValidEditableRange(context.systemMarkRange, mEditable.length())) {
            int documentStartOffset = Math.max(0, context.documentStartOffset);
            int start = documentStartOffset
                    + clampEditableOffset(context.systemMarkRange.start, mEditable.length());
            int end = documentStartOffset
                    + clampEditableOffset(context.systemMarkRange.end, mEditable.length());
            return start <= end ? new IntRange(start, end) : new IntRange(end, start);
        }
        int composingStart = BaseInputConnection.getComposingSpanStart(mEditable);
        int composingEnd = BaseInputConnection.getComposingSpanEnd(mEditable);
        if (composingStart < 0 || composingEnd < 0 || composingStart == composingEnd) {
            return new IntRange(-1, -1);
        }
        int documentStartOffset = context != null
                ? Math.max(0, context.documentStartOffset)
                : 0;
        int start = documentStartOffset + clampEditableOffset(composingStart, mEditable.length());
        int end = documentStartOffset + clampEditableOffset(composingEnd, mEditable.length());
        return start <= end ? new IntRange(start, end) : new IntRange(end, start);
    }

    private boolean isActive() {
        return !mClosed;
    }

    private boolean ensureEditableTextWindow() {
        if (mInputContextId != 0) {
            return true;
        }
        return isEditableTextWindow(syncEditableFromCore());
    }

    private boolean isEditableTextWindow(ImeInputContext context) {
        return context != null
                && context.id != 0
                && context.kind == ImeInputContextKind.DOCUMENT_WINDOW;
    }

    private int clampEditableOffset(int offset, int textLength) {
        return Math.max(0, Math.min(offset, textLength));
    }

    private boolean isValidEditableRange(ImeOffsetRange range, int textLength) {
        return range != null
                && range.start >= 0
                && range.end >= 0
                && range.start <= textLength
                && range.end <= textLength
                && range.start != range.end;
    }

    private boolean shouldCommitSystemMarkedRange(CharSequence text) {
        if (mEditableMarkedRole != ImeMarkedRangeRole.SYSTEM_MARK) {
            return false;
        }
        if (!isValidEditableRange(getEditableComposingRange(), mEditable.length())) {
            return false;
        }
        int textLength = text != null ? text.length() : 0;
        return textLength == 0 || textLength > 1;
    }

    private ImeOffsetRange getEditableSelectionRange() {
        int start = Selection.getSelectionStart(mEditable);
        int end = Selection.getSelectionEnd(mEditable);
        if (start < 0 || end < 0) {
            return new ImeOffsetRange(-1, -1);
        }
        int safeStart = clampEditableOffset(start, mEditable.length());
        int safeEnd = clampEditableOffset(end, mEditable.length());
        return safeStart <= safeEnd
                ? new ImeOffsetRange(safeStart, safeEnd)
                : new ImeOffsetRange(safeEnd, safeStart);
    }

    private ImeMarkedRange getEditableMarkedRange() {
        if (mEditableMarkedRole == ImeMarkedRangeRole.NONE) {
            return new ImeMarkedRange();
        }
        ImeOffsetRange range = getEditableComposingRange();
        if (!isValidEditableRange(range, mEditable.length())) {
            return new ImeMarkedRange();
        }
        return new ImeMarkedRange(mEditableMarkedRole, range);
    }

    private void refreshEditableMarkedStateAfterLocalEdit() {
        if (!isValidEditableRange(getEditableComposingRange(), mEditable.length())) {
            mEditableMarkedRole = ImeMarkedRangeRole.NONE;
        }
    }

    private ImeOffsetRange getEditableComposingRange() {
        int composingStart = BaseInputConnection.getComposingSpanStart(mEditable);
        int composingEnd = BaseInputConnection.getComposingSpanEnd(mEditable);
        ImeOffsetRange range = new ImeOffsetRange(composingStart, composingEnd);
        if (!isValidEditableRange(range, mEditable.length())) {
            return new ImeOffsetRange(-1, -1);
        }
        return new ImeOffsetRange(
                clampEditableOffset(Math.min(composingStart, composingEnd), mEditable.length()),
                clampEditableOffset(Math.max(composingStart, composingEnd), mEditable.length()));
    }

    private InputMethodManager getInputMethodManager() {
        return (InputMethodManager) mEditor.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    private void clearEditableState() {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.clear();
        Selection.setSelection(mEditable, 0);
        mInputContextId = 0;
        mInputContextRevision = 0;
        mInputDocumentStartOffset = 0;
        mEditableMarkedRole = ImeMarkedRangeRole.NONE;
    }
}
