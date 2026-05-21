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

import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.IntRange;

public class SweetEditorInputConnection extends BaseInputConnection {
    private static final int MAX_IME_TEXT_LENGTH = 32768;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable = new SpannableStringBuilder();
    private boolean mClosed = false;
    private long mInputContextId = 0;
    private int mInputDocumentStartOffset = 0;

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
        EditorCore.ImeInputContext context = syncEditableFromCore();
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT
                | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE
                | EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT;
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        IntRange selectionOffsets = getImeSelectionOffsets();
        outAttrs.initialSelStart = selectionOffsets.start;
        outAttrs.initialSelEnd = selectionOffsets.end;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                && context.kind == EditorCore.ImeInputContextKind.DOCUMENT_WINDOW
                && mEditable.length() > 0) {
            outAttrs.setInitialSurroundingSubText(mEditable, mInputDocumentStartOffset);
        }
    }

    @Override
    public boolean setSelection(int start, int end) {
        if (!isActive()) {
            return false;
        }
        int safeStart = clampEditableOffset(start, mEditable.length());
        int safeEnd = clampEditableOffset(end, mEditable.length());
        Selection.setSelection(mEditable, safeStart, safeEnd);
        EditorCore.EditorActionResult result = mEditor.getEditorCore().updateImeInputStateSelection(
                mInputContextId,
                mInputDocumentStartOffset,
                safeStart,
                safeEnd);
        finishImeAction(result, "ime-selection");
        return result.handled;
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        if (!isActive()) {
            return false;
        }
        super.setComposingText(text != null ? text : "", newCursorPosition);
        return pushEditableTextState("ime-update");
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean setComposingText(CharSequence text, int newCursorPosition, TextAttribute textAttribute) {
        return setComposingText(text, newCursorPosition);
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        if (!isActive()) {
            return false;
        }
        int safeStart = clampEditableOffset(Math.min(start, end), mEditable.length());
        int safeEnd = clampEditableOffset(Math.max(start, end), mEditable.length());
        super.setComposingRegion(safeStart, safeEnd);
        return pushEditableTextState("ime-region");
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
        super.commitText(text != null ? text : "", newCursorPosition);
        return pushEditableTextState("ime-commit");
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
        if (!isActive() || start < 0 || end < 0) {
            return false;
        }
        EditorCore.EditorActionResult result = mEditor.getEditorCore().replaceImeInputStateText(
                mInputContextId,
                mInputDocumentStartOffset,
                Math.min(start, end),
                Math.max(start, end),
                text != null ? text.toString() : "",
                newCursorPosition,
                EditorCore.ImeScriptClass.UNKNOWN);
        finishImeAction(result, "ime-replace");
        return result.handled;
    }

    @Override
    public boolean finishComposingText() {
        if (!isActive()) {
            return false;
        }
        EditorCore.EditorActionResult result = mEditor.getEditorCore().finishImePreedit();
        finishImeAction(result, "ime-finish");
        return true;
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength, EditorCore.ImeTextUnit.GRAPHEME);
    }

    @Override
    public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
        return deleteSurroundingTextInternal(beforeLength, afterLength, EditorCore.ImeTextUnit.CODE_POINT);
    }

    @Override
    public boolean sendKeyEvent(KeyEvent event) {
        if (!isActive()) {
            return false;
        }
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();
            if (keyCode == KeyEvent.KEYCODE_DEL) {
                EditorCore.EditorActionResult result = mEditor.getEditorCore().deleteImeBackward(
                        1,
                        EditorCore.ImeTextUnit.GRAPHEME);
                finishImeAction(result, "ime-delete");
                return result.handled;
            }
            if (keyCode == KeyEvent.KEYCODE_FORWARD_DEL) {
                EditorCore.EditorActionResult result = mEditor.getEditorCore().deleteImeForward(
                        1,
                        EditorCore.ImeTextUnit.GRAPHEME);
                finishImeAction(result, "ime-delete");
                return result.handled;
            }
            mEditor.handleKeyEventFromIME(event);
        }
        return true;
    }

    IntRange getImeSelectionOffsets() {
        int start = Selection.getSelectionStart(mEditable);
        int end = Selection.getSelectionEnd(mEditable);
        if (start < 0 || end < 0) {
            return new IntRange(mInputDocumentStartOffset, mInputDocumentStartOffset);
        }
        int documentStart = mInputDocumentStartOffset + clampEditableOffset(start, mEditable.length());
        int documentEnd = mInputDocumentStartOffset + clampEditableOffset(end, mEditable.length());
        return documentStart <= documentEnd
                ? new IntRange(documentStart, documentEnd)
                : new IntRange(documentEnd, documentStart);
    }

    void updateImeSelectionState() {
        InputMethodManager imm = getInputMethodManager();
        if (imm == null) {
            return;
        }
        syncEditableFromCore();
        IntRange selectionOffsets = getImeSelectionOffsets();
        IntRange composingOffsets = getImeComposingOffsets();
        imm.updateSelection(mEditor, selectionOffsets.start, selectionOffsets.end,
                composingOffsets.start, composingOffsets.end);
    }

    void restartImeInput() {
        InputMethodManager imm = getInputMethodManager();
        if (imm != null) {
            imm.restartInput(mEditor);
        }
    }

    private boolean pushEditableTextState(String perfName) {
        long t0 = System.nanoTime();
        int selectionStart = Selection.getSelectionStart(mEditable);
        int selectionEnd = Selection.getSelectionEnd(mEditable);
        int composingStart = BaseInputConnection.getComposingSpanStart(mEditable);
        int composingEnd = BaseInputConnection.getComposingSpanEnd(mEditable);
        EditorCore.EditorActionResult result = mEditor.getEditorCore().updateImeInputStateText(
                mInputContextId,
                mInputDocumentStartOffset,
                mEditable.toString(),
                selectionStart,
                selectionEnd,
                composingStart,
                composingEnd,
                EditorCore.ImeScriptClass.UNKNOWN);
        finishImeAction(result, perfName, t0);
        return result.handled;
    }

    private boolean deleteSurroundingTextInternal(int beforeLength, int afterLength, int textUnit) {
        if (!isActive()) {
            return false;
        }
        long t0 = System.nanoTime();
        EditorCore.EditorActionResult result = mEditor.getEditorCore().deleteImeSurrounding(
                Math.max(0, beforeLength),
                Math.max(0, afterLength),
                textUnit);
        finishImeAction(result, "ime-delete", t0);
        return result.handled;
    }

    private void finishImeAction(EditorCore.EditorActionResult result, String perfName) {
        finishImeAction(result, perfName, System.nanoTime());
    }

    private void finishImeAction(EditorCore.EditorActionResult result, String perfName, long startTimeNanos) {
        mEditor.dispatchEditorActionResult(result);
        mEditor.logInputPerf(startTimeNanos, perfName);
    }

    void onEditorActionResult(EditorCore.EditorActionResult result) {
        if (result.needsImeSync) {
            updateImeSelectionState();
        }
    }

    private EditorCore.ImeInputContext syncEditableFromCore() {
        EditorCore.ImeInputContext context = mEditor.getEditorCore().getImeInputContext(
                MAX_IME_TEXT_LENGTH / 2,
                MAX_IME_TEXT_LENGTH / 2);
        if (context.id == 0) {
            clearEditableState();
            return context;
        }
        syncEditableFromContext(context);
        return context;
    }

    private void syncEditableFromContext(EditorCore.ImeInputContext context) {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.replace(0, mEditable.length(), context.text);
        mInputContextId = context.id;
        mInputDocumentStartOffset = Math.max(0, context.documentStartOffset);
        int selectionStart = clampEditableOffset(context.selection.start, mEditable.length());
        int selectionEnd = clampEditableOffset(context.selection.end, mEditable.length());
        Selection.setSelection(mEditable, selectionStart, selectionEnd);
        if (context.hasComposition && isValidEditableRange(context.composition, mEditable.length())) {
            super.setComposingRegion(
                    clampEditableOffset(context.composition.start, mEditable.length()),
                    clampEditableOffset(context.composition.end, mEditable.length()));
        }
    }

    private IntRange getImeComposingOffsets() {
        int composingStart = BaseInputConnection.getComposingSpanStart(mEditable);
        int composingEnd = BaseInputConnection.getComposingSpanEnd(mEditable);
        if (composingStart < 0 || composingEnd < 0 || composingStart == composingEnd) {
            return new IntRange(-1, -1);
        }
        int start = mInputDocumentStartOffset + clampEditableOffset(composingStart, mEditable.length());
        int end = mInputDocumentStartOffset + clampEditableOffset(composingEnd, mEditable.length());
        return start <= end ? new IntRange(start, end) : new IntRange(end, start);
    }

    private boolean isActive() {
        return !mClosed;
    }

    private int clampEditableOffset(int offset, int textLength) {
        return Math.max(0, Math.min(offset, textLength));
    }

    private boolean isValidEditableRange(EditorCore.ImeTextRange range, int textLength) {
        return range != null
                && range.start >= 0
                && range.end >= 0
                && range.start <= textLength
                && range.end <= textLength
                && range.start != range.end;
    }

    private InputMethodManager getInputMethodManager() {
        return (InputMethodManager) mEditor.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    private void clearEditableState() {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.clear();
        Selection.setSelection(mEditable, 0);
        mInputContextId = 0;
        mInputDocumentStartOffset = 0;
    }
}
