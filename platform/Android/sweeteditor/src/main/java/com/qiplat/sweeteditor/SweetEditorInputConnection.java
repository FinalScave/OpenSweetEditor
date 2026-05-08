package com.qiplat.sweeteditor;

import android.content.Context;
import android.annotation.TargetApi;
import android.os.Build;
import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.util.Log;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.CompletionInfo;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.view.inputmethod.InputMethodSubtype;
import android.view.inputmethod.SurroundingText;
import android.view.inputmethod.TextAttribute;
import android.view.inputmethod.TextSnapshot;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.util.Locale;

/**
 * Custom InputConnection for handling IME input method composing and commit.
 * <p>
 * Override getTextBeforeCursor / getTextAfterCursor / getSelectedText etc.,
 * read real document text directly from editor core to ensure IME gets correct context.
 */
public class SweetEditorInputConnection extends BaseInputConnection {
    private static final String TAG = "SweetEditorIME";
    private static final boolean TRACE_IME = false;
    private static final int MAX_IME_TEXT_LENGTH = 32768;
    private static final int LIMITED_IME_CONTEXT_LENGTH = 2048;
    private static final int INITIAL_SURROUNDING_TEXT_LENGTH = 2048;
    private static final int IME_TEXT_WINDOW_HISTORY_SIZE = 8;
    private static int sNextConnectionId = 1;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable;
    private final int mConnectionId;
    private boolean mDocumentMirrorActive = false;
    private boolean mClosed = false;
    private int mBatchEditDepth = 0;
    private boolean mDeferredEditorFlush = false;
    private boolean mDeferredSelectionUpdate = false;
    private int mLastImeSelectionStart = Integer.MIN_VALUE;
    private int mLastImeSelectionEnd = Integer.MIN_VALUE;
    private int mLastImeComposingStart = Integer.MIN_VALUE;
    private int mLastImeComposingEnd = Integer.MIN_VALUE;
    private final ImeTextWindow[] mImeTextWindows = new ImeTextWindow[IME_TEXT_WINDOW_HISTORY_SIZE];
    private int mImeTextWindowWriteIndex = 0;

    private static class InitialSurroundingText {
        final CharSequence text;
        final int offset;

        InitialSurroundingText(CharSequence text, int offset) {
            this.text = text;
            this.offset = offset;
        }
    }

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        mConnectionId = sNextConnectionId++;
        mEditable = new SpannableStringBuilder();
        Selection.setSelection(mEditable, 0);
        trace("create");
    }

    @Override
    public void closeConnection() {
        mClosed = true;
        clearEditableMirror();
        clearImeSelectionCache();
        clearImeTextWindows();
        trace("close");
    }

    private boolean isActive() {
        return !mClosed;
    }

    void configureEditorInfo(EditorInfo outAttrs) {
        clearImeSelectionCache();
        clearImeTextWindows();
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        int contextPolicy = snapshot.contextPolicy;
        int inputType = EditorInfo.TYPE_CLASS_TEXT
                | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE
                | EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT;
        int imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        outAttrs.inputType = inputType;
        outAttrs.imeOptions = imeOptions;
        IntRange selectionOffsets = getImeSelectionOffsets();
        outAttrs.initialSelStart = selectionOffsets.start;
        outAttrs.initialSelEnd = selectionOffsets.end;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                && shouldExposeDocumentContext(contextPolicy)) {
            InitialSurroundingText initialText = buildInitialSurroundingText(snapshot, contextPolicy);
            if (initialText != null) {
                outAttrs.setInitialSurroundingSubText(initialText.text, initialText.offset);
            }
        }
    }

    private static class ImeTextWindow {
        final int startOffset;
        final int endOffset;
        final int selectionStartOffset;
        final int selectionEndOffset;
        final int composingStartOffset;
        final int composingEndOffset;
        final int documentLength;

        ImeTextWindow(int startOffset,
                      int endOffset,
                      int selectionStartOffset,
                      int selectionEndOffset,
                      int composingStartOffset,
                      int composingEndOffset,
                      int documentLength) {
            this.startOffset = startOffset;
            this.endOffset = endOffset;
            this.selectionStartOffset = selectionStartOffset;
            this.selectionEndOffset = selectionEndOffset;
            this.composingStartOffset = composingStartOffset;
            this.composingEndOffset = composingEndOffset;
            this.documentLength = documentLength;
        }

        int length() {
            return Math.max(0, endOffset - startOffset);
        }
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    @Override
    public boolean beginBatchEdit() {
        if (!isActive()) {
            return false;
        }
        mBatchEditDepth++;
        trace("beginBatchEdit depth=" + mBatchEditDepth);
        return true;
    }

    @Override
    public boolean endBatchEdit() {
        if (!isActive()) {
            return false;
        }
        if (mBatchEditDepth > 0) {
            mBatchEditDepth--;
        }
        trace("endBatchEdit depth=" + mBatchEditDepth);
        if (mBatchEditDepth == 0) {
            flushDeferredImeWork();
        }
        return true;
    }

    @Override
    public int getCursorCapsMode(int reqModes) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return 0;
        }
        String text = doc.getText();
        IntRange selection = getImeSelectionOffsets();
        int offset = Math.max(0, Math.min(selection.start, text.length()));
        return TextUtils.getCapsMode(text, offset, reqModes);
    }

    @Override
    public boolean setSelection(int start, int end) {
        trace("before setSelection start=" + start + " end=" + end);
        if (!isActive()) {
            return false;
        }
        TextRange range = resolveAbsoluteImeTextRange(start, end);
        if (range == null) {
            return false;
        }
        EditorCore.ImeActionResult result = mEditor.getEditorCore().notifyImeSelectionChanged(range);
        dispatchImeActionResult(result);
        flushEditorAfterImeAction();
        updateImeSelectionState();
        trace("after setSelection");
        return result.handled;
    }

    @Override
    public CharSequence getTextBeforeCursor(int n, int flags) {
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        int contextPolicy = snapshot.contextPolicy;
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return "";
        }
        String documentText = doc.getText();
        IntRange selection = getImeSelectionOffsets(snapshot);
        int selectionStart = clampEditableOffset(selection.start, documentText.length());
        int selectionEnd = clampEditableOffset(selection.end, documentText.length());
        int before = limitContextLength(n, contextPolicy);
        int start = Math.max(0, selectionStart - before);
        rememberSnapshotTextWindow(snapshot, documentText.length());
        rememberImeTextWindow(start, selectionStart, selectionStart, selectionEnd, documentText.length());
        return applyComposingSpan(documentText.substring(start, selectionStart), flags, start);
    }

    @Override
    public CharSequence getTextAfterCursor(int n, int flags) {
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        int contextPolicy = snapshot.contextPolicy;
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return "";
        }
        String documentText = doc.getText();
        IntRange selection = getImeSelectionOffsets(snapshot);
        int selectionStart = clampEditableOffset(selection.start, documentText.length());
        int selectionEnd = clampEditableOffset(selection.end, documentText.length());
        int after = limitContextLength(n, contextPolicy);
        int end = Math.min(documentText.length(), selectionEnd + after);
        rememberSnapshotTextWindow(snapshot, documentText.length());
        rememberImeTextWindow(selectionEnd, end, selectionStart, selectionEnd, documentText.length());
        return applyComposingSpan(documentText.substring(selectionEnd, end), flags, selectionEnd);
    }

    @Override
    public CharSequence getSelectedText(int flags) {
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        int contextPolicy = snapshot.contextPolicy;
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return "";
        }
        String documentText = doc.getText();
        IntRange selection = getImeSelectionOffsets(snapshot);
        int selectionStart = clampEditableOffset(selection.start, documentText.length());
        int selectionEnd = clampEditableOffset(selection.end, documentText.length());
        if (selectionStart == selectionEnd) {
            return "";
        }
        rememberSnapshotTextWindow(snapshot, documentText.length());
        rememberImeTextWindow(selectionStart, selectionEnd, selectionStart, selectionEnd, documentText.length());
        return applyComposingSpan(documentText.substring(selectionStart, selectionEnd), flags, selectionStart);
    }

    @Override
    @TargetApi(Build.VERSION_CODES.S)
    public SurroundingText getSurroundingText(int beforeLength, int afterLength, int flags) {
        trace("before getSurroundingText before=" + beforeLength + " after=" + afterLength);
        if ((beforeLength | afterLength) < 0) {
            throw new IllegalArgumentException("length < 0");
        }
        int contextPolicy = getImeContextPolicy();
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return new SurroundingText("", 0, 0, -1);
        }
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return new SurroundingText("", 0, 0, -1);
        }
        String documentText = doc.getText();
        IntRange selection = getImeSelectionOffsets();
        int selectionStart = Math.max(0, Math.min(selection.start, documentText.length()));
        int selectionEnd = Math.max(0, Math.min(selection.end, documentText.length()));
        int before = limitContextLength(beforeLength, contextPolicy);
        int after = limitContextLength(afterLength, contextPolicy);
        int start = Math.max(0, selectionStart - before);
        int end = Math.min(documentText.length(), selectionEnd + after);
        String surroundingText = documentText.substring(start, end);
        IntRange localSelection = new IntRange(selectionStart - start, selectionEnd - start);
        CharSequence surrounding = applyComposingSpan(surroundingText, flags, start);
        rememberSnapshotTextWindow(snapshot, documentText.length());
        rememberImeTextWindow(start, end, selectionStart, selectionEnd, documentText.length());
        return new SurroundingText(surrounding,
                localSelection.start,
                localSelection.end,
                start);
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        trace("before setComposingText text=" + quote(text) + " newCursor=" + newCursorPosition);
        if (!isActive()) {
            return false;
        }
        String textStr = text != null ? text.toString() : "";
        updateComposition(textStr, resolveAndReportImeScriptHint(), newCursorPosition);
        trace("after setComposingText text=" + quote(textStr));
        return true;
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean setComposingText(CharSequence text, int newCursorPosition, TextAttribute textAttribute) {
        return setComposingText(text, newCursorPosition);
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        trace("before setComposingRegion start=" + start + " end=" + end);
        if (!isActive()) {
            return false;
        }
        markComposingRegion(start, end);
        trace("after setComposingRegion start=" + start + " end=" + end);
        return true;
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public boolean setComposingRegion(int start, int end, TextAttribute textAttribute) {
        return setComposingRegion(start, end);
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        trace("before commitText text=" + quote(text) + " newCursor=" + newCursorPosition);
        if (!isActive()) {
            return false;
        }
        String textStr = text != null ? text.toString() : "";
        if (textStr.isEmpty() && !hasImeComposingSession() && deleteImeSelection("commitText empty")) {
            return true;
        }
        commitComposition(textStr, resolveAndReportImeScriptHint(), newCursorPosition);
        trace("after commitText text=" + quote(textStr));
        return true;
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
        trace("before replaceText start=" + start + " end=" + end
                + " text=" + quote(text) + " newCursor=" + newCursorPosition);
        if (!isActive()) {
            return false;
        }
        Document doc = mEditor.getDocument();
        if (doc == null || start < 0 || end < 0) {
            return false;
        }
        TextRange range = resolveImeTextRange(start, end);
        if (range == null) {
            return false;
        }
        EditorCore.ImeActionResult result = mEditor.getEditorCore().replaceImeText(
                range,
                text != null ? text.toString() : "",
                resolveAndReportImeScriptHint());
        dispatchImeActionResult(result);
        applyImeCursorPosition(newCursorPosition, text != null ? text.toString() : "", result);
        flushEditorAfterImeAction();
        updateImeSelectionState();
        trace("after replaceText result=" + result.handled);
        return result.handled;
    }

    @Override
    public boolean finishComposingText() {
        trace("before finishComposingText");
        if (!isActive()) {
            return false;
        }
        if (hasImeComposingSession()) {
            finishComposition();
            trace("after finishComposingText session");
            return true;
        }
        trace("after finishComposingText no-op");
        return true;
    }

    @Override
    public boolean commitCompletion(CompletionInfo text) {
        trace("before commitCompletion text=" + quote(text != null ? text.getText() : null));
        if (!isActive()) {
            return false;
        }
        trace("after commitCompletion");
        return true;
    }

    @Override
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    public TextSnapshot takeSnapshot() {
        SurroundingText surroundingText = getSurroundingText(
                MAX_IME_TEXT_LENGTH / 2,
                MAX_IME_TEXT_LENGTH / 2,
                GET_TEXT_WITH_STYLES);
        IntRange composing = getImeComposingOffsets();
        int composingStart = composing.start >= 0 ? composing.start : -1;
        int composingEnd = composing.end >= 0 ? composing.end : -1;
        int capsMode = getCursorCapsMode(TextUtils.CAP_MODE_CHARACTERS
                | TextUtils.CAP_MODE_WORDS
                | TextUtils.CAP_MODE_SENTENCES);
        return new TextSnapshot(surroundingText, composingStart, composingEnd, capsMode);
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        trace("before deleteSurroundingText before=" + beforeLength + " after=" + afterLength);
        if (!isActive()) {
            return false;
        }
        return deleteSurroundingTextInternal(beforeLength, afterLength,
                EditorCore.ImeTextUnit.UTF16_CODE_UNIT, "deleteSurroundingText");
    }

    @Override
    public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
        trace("before deleteSurroundingTextInCodePoints before=" + beforeLength + " after=" + afterLength);
        if (!isActive()) {
            return false;
        }
        return deleteSurroundingTextInternal(beforeLength, afterLength,
                EditorCore.ImeTextUnit.CODE_POINT, "deleteSurroundingTextInCodePoints");
    }

    private boolean deleteSurroundingTextInternal(int beforeLength, int afterLength, int textUnit, String source) {
        clearShadowEditable();
        boolean result = deleteImeSurroundingText(beforeLength, afterLength, textUnit);
        trace("after " + source + " before=" + beforeLength + " after=" + afterLength
                + " result=" + result);
        return result;
    }

    @Override
    public boolean performContextMenuAction(int id) {
        if (!isActive()) {
            return false;
        }
        if (id == android.R.id.selectAll) {
            mEditor.selectAll();
            return true;
        } else if (id == android.R.id.copy) {
            return mEditor.copyToClipboard();
        } else if (id == android.R.id.paste) {
            mEditor.pasteFromClipboard();
            return true;
        } else if (id == android.R.id.cut) {
            return mEditor.cutToClipboard();
        }
        return super.performContextMenuAction(id);
    }

    @Override
    public boolean sendKeyEvent(KeyEvent event) {
        if (!isActive()) {
            return false;
        }
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();
            if (keyCode == KeyEvent.KEYCODE_DEL) {
                clearShadowEditable();
                deleteImeBackward();
                trace("after sendKeyEvent delete backward");
                return true;
            }
            if (keyCode == KeyEvent.KEYCODE_FORWARD_DEL) {
                clearShadowEditable();
                deleteImeForward();
                trace("after sendKeyEvent delete forward");
                return true;
            }
            mEditor.handleKeyEventFromIME(event);
        }
        return true;
    }

    private int getImeContextPolicy() {
        return mEditor.getEditorCore().getImeSyncSnapshot().contextPolicy;
    }

    private boolean hasImeComposingSession() {
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        return snapshot.platformMarkedRange != null
                || snapshot.visibleCompositionRange != null
                || snapshot.preeditStorage == EditorCore.ImePreeditStorage.SHADOW_ONLY;
    }

    private void dispatchImeActionResult(EditorCore.ImeActionResult result) {
        mEditor.dispatchImeTextChanged(result.editResult);
        if (result.sync.clearPlatformPreedit) {
            BaseInputConnection.removeComposingSpans(mEditable);
        }
        syncPlatformTextInputState(result.sync);
    }

    private void flushEditorAfterImeAction() {
        if (mBatchEditDepth > 0) {
            mDeferredEditorFlush = true;
            return;
        }
        mEditor.flush();
    }

    private void flushDeferredImeWork() {
        if (mDeferredEditorFlush) {
            mDeferredEditorFlush = false;
            mEditor.flush();
        }
        if (mDeferredSelectionUpdate) {
            mDeferredSelectionUpdate = false;
            updateImeSelectionState();
        }
    }

    private void applyImeCursorPosition(int newCursorPosition,
                                        String text,
                                        EditorCore.ImeActionResult result) {
        if (newCursorPosition == 1) {
            return;
        }
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return;
        }
        IntRange editRange = resolveImeCursorEditRange(text, result);
        if (editRange == null) {
            return;
        }
        int targetOffset = newCursorPosition > 0
                ? editRange.end + newCursorPosition - 1
                : editRange.start + newCursorPosition;
        targetOffset = Math.max(0, Math.min(targetOffset, doc.getText().length()));
        TextPosition target = doc.getPositionFromCharIndex(targetOffset);
        EditorCore.ImeActionResult selectionResult = mEditor.getEditorCore().notifyImeCursorChanged(target);
        dispatchImeActionResult(selectionResult);
    }

    private IntRange resolveImeCursorEditRange(String text, EditorCore.ImeActionResult result) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return null;
        }
        TextRange range = result.sync.platformMarkedRange != null
                ? result.sync.platformMarkedRange
                : result.sync.visibleCompositionRange;
        if (range != null) {
            int start = doc.getCharIndexFromPosition(range.start);
            int end = doc.getCharIndexFromPosition(range.end);
            return start <= end ? new IntRange(start, end) : new IntRange(end, start);
        }
        if (result.editResult.changed && !result.editResult.changes.isEmpty()) {
            TextRange changedRange = result.editResult.changes.get(0).range;
            int start = doc.getCharIndexFromPosition(changedRange.start);
            return new IntRange(start, start + (text != null ? text.length() : 0));
        }
        int cursor = doc.getCharIndexFromPosition(result.sync.cursor);
        return new IntRange(cursor, cursor);
    }

    private TextRange markComposingRegion(int startOffset, int endOffset) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return null;
        }
        TextRange range = resolveImeComposingRegion(startOffset, endOffset);
        if (range == null || isCollapsed(range)) {
            if (hasImeComposingSession()) {
                finishComposition(false);
            }
            return null;
        }
        if (isCurrentComposingRange(range)) {
            return copyRange(range);
        }
        EditorCore.ImeActionResult result = mEditor.getEditorCore().markImeDocumentRange(
                range,
                resolveAndReportImeScriptHint());
        dispatchImeActionResult(result);
        flushEditorAfterImeAction();
        return copyRange(range);
    }

    private TextRange resolveImeComposingRegion(int startOffset, int endOffset) {
        TextRange range = resolveImeTextRange(startOffset, endOffset);
        if (range == null || isCollapsed(range)) {
            return null;
        }
        return range;
    }

    private TextRange resolveAbsoluteImeTextRange(int startOffset, int endOffset) {
        return resolveImeTextRange(startOffset, endOffset, false);
    }

    private TextRange resolveImeTextRange(int startOffset, int endOffset) {
        return resolveImeTextRange(startOffset, endOffset, true);
    }

    private TextRange resolveImeTextRange(int startOffset, int endOffset, boolean allowWindowOffsets) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return null;
        }
        int documentLength = doc.getText().length();
        IntRange offsets = resolveImeTextOffsets(startOffset, endOffset, documentLength, allowWindowOffsets);
        if (offsets == null) {
            return null;
        }
        return new TextRange(
                doc.getPositionFromCharIndex(offsets.start),
                doc.getPositionFromCharIndex(offsets.end));
    }

    private IntRange resolveImeTextOffsets(int startOffset,
                                           int endOffset,
                                           int documentLength,
                                           boolean allowWindowOffsets) {
        int rawStart = Math.min(startOffset, endOffset);
        int rawEnd = Math.max(startOffset, endOffset);
        IntRange absolute = new IntRange(
                clampEditableOffset(rawStart, documentLength),
                clampEditableOffset(rawEnd, documentLength));
        if (!allowWindowOffsets) {
            return absolute;
        }
        IntRange window = resolveWindowRelativeImeOffsets(rawStart, rawEnd, documentLength);
        return shouldPreferWindowOffsets(absolute, window) ? window : absolute;
    }

    private IntRange resolveWindowRelativeImeOffsets(int rawStart, int rawEnd, int documentLength) {
        if (rawStart < 0 || rawEnd < 0) {
            return null;
        }
        IntRange best = null;
        int bestScore = Integer.MAX_VALUE;
        for (int i = 0; i < IME_TEXT_WINDOW_HISTORY_SIZE; i++) {
            int index = (mImeTextWindowWriteIndex - 1 - i + IME_TEXT_WINDOW_HISTORY_SIZE)
                    % IME_TEXT_WINDOW_HISTORY_SIZE;
            ImeTextWindow window = mImeTextWindows[index];
            if (window == null || window.documentLength != documentLength) {
                continue;
            }
            int windowLength = window.length();
            if (rawStart > windowLength || rawEnd > windowLength) {
                continue;
            }
            if (!rawRangeTouchesWindowTarget(rawStart, rawEnd, window)) {
                continue;
            }
            int translatedStart = window.startOffset + rawStart;
            int translatedEnd = window.startOffset + rawEnd;
            if (translatedStart < 0 || translatedEnd < 0
                    || translatedStart > documentLength || translatedEnd > documentLength) {
                continue;
            }
            int score = distanceToWindowTarget(rawStart, rawEnd, window) * IME_TEXT_WINDOW_HISTORY_SIZE + i;
            if (score < bestScore) {
                bestScore = score;
                best = new IntRange(translatedStart, translatedEnd);
            }
        }
        return best;
    }

    private boolean shouldPreferWindowOffsets(IntRange absolute, IntRange window) {
        if (window == null || rangesEqual(absolute, window)) {
            return false;
        }
        IntRange composing = getImeComposingOffsets();
        if (rangesEqual(absolute, composing)) {
            return false;
        }
        if (rangesEqual(window, composing)) {
            return true;
        }
        IntRange selection = getImeSelectionOffsets();
        int absoluteDistance = distanceToDocumentTarget(absolute, selection);
        int windowDistance = distanceToDocumentTarget(window, selection);
        return windowDistance < absoluteDistance;
    }

    private boolean rawRangeTouchesWindowTarget(int rawStart, int rawEnd, ImeTextWindow window) {
        if (rangesTouch(rawStart, rawEnd, window.selectionStartOffset, window.selectionEndOffset)) {
            return true;
        }
        return window.composingStartOffset >= 0
                && window.composingEndOffset >= 0
                && rangesTouch(rawStart, rawEnd, window.composingStartOffset, window.composingEndOffset);
    }

    private int distanceToWindowTarget(int rawStart, int rawEnd, ImeTextWindow window) {
        int selectionDistance = distanceToOffsets(rawStart, rawEnd,
                window.selectionStartOffset,
                window.selectionEndOffset);
        if (window.composingStartOffset < 0 || window.composingEndOffset < 0) {
            return selectionDistance;
        }
        return Math.min(selectionDistance,
                distanceToOffsets(rawStart, rawEnd,
                        window.composingStartOffset,
                        window.composingEndOffset));
    }

    private int distanceToDocumentTarget(IntRange range, IntRange target) {
        return distanceToOffsets(range.start, range.end, target.start, target.end);
    }

    private static int distanceToOffsets(int start, int end, int targetStart, int targetEnd) {
        if (rangesTouch(start, end, targetStart, targetEnd)) {
            return 0;
        }
        if (end < targetStart) {
            return targetStart - end;
        }
        return start - targetEnd;
    }

    private boolean isCurrentComposingRange(TextRange range) {
        if (!mEditor.getEditorCore().isComposing()) {
            return false;
        }
        TextRange currentRange = mEditor.getEditorCore().getComposingRange();
        return currentRange != null && rangesEqual(currentRange, range);
    }

    private void updateComposition(String text) {
        updateComposition(text, EditorCore.ImeScriptClass.UNKNOWN, 1);
    }

    private void updateComposition(String text, int scriptHint) {
        updateComposition(text, scriptHint, 1);
    }

    private void updateComposition(String text, int scriptHint, int newCursorPosition) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().updateImePreedit(text, scriptHint);
        dispatchImeActionResult(result);
        applyImeCursorPosition(newCursorPosition, text, result);
        flushEditorAfterImeAction();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-update");
    }

    private void commitComposition(String text) {
        commitComposition(text, EditorCore.ImeScriptClass.UNKNOWN, 1);
    }

    private void commitComposition(String text, int scriptHint) {
        commitComposition(text, scriptHint, 1);
    }

    private void commitComposition(String text, int scriptHint, int newCursorPosition) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().commitImeText(text, scriptHint);
        dispatchImeActionResult(result);
        applyImeCursorPosition(newCursorPosition, text, result);
        flushEditorAfterImeAction();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-commit");
    }

    private void finishComposition() {
        finishComposition(true);
    }

    private void finishComposition(boolean updateSelection) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().finishImePreedit();
        dispatchImeActionResult(result);
        flushEditorAfterImeAction();
        if (updateSelection) {
            updateImeSelectionState();
        }
        mEditor.logInputPerf(t0, "ime-finish");
    }

    private boolean deleteImeBackward() {
        return deleteImeBackward(EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
    }

    private boolean deleteImeBackward(int textUnit) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().deleteImeBackward(1, textUnit);
        return finishImeDelete(result, t0);
    }

    private boolean deleteImeForward() {
        return deleteImeForward(EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
    }

    private boolean deleteImeForward(int textUnit) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().deleteImeForward(1, textUnit);
        return finishImeDelete(result, t0);
    }

    private boolean deleteImeSurroundingText(int beforeLength, int afterLength, int textUnit) {
        long t0 = System.nanoTime();
        EditorCore.ImeActionResult result = mEditor.getEditorCore().deleteImeSurrounding(
                Math.max(0, beforeLength),
                Math.max(0, afterLength),
                textUnit);
        return finishImeDelete(result, t0);
    }

    private boolean finishImeDelete(EditorCore.ImeActionResult result, long startTimeNanos) {
        dispatchImeActionResult(result);
        flushEditorAfterImeAction();
        updateImeSelectionState();
        mEditor.logInputPerf(startTimeNanos, "ime-delete");
        return result.handled;
    }

    IntRange getImeSelectionOffsets() {
        return getImeSelectionOffsets(mEditor.getEditorCore().getImeSyncSnapshot());
    }

    private IntRange getImeSelectionOffsets(EditorCore.ImeSyncSnapshot snapshot) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return new IntRange(0, 0);
        }

        TextRange selection = snapshot.selection;
        if (selection != null) {
            int start = doc.getCharIndexFromPosition(selection.start);
            int end = doc.getCharIndexFromPosition(selection.end);
            return start <= end ? new IntRange(start, end) : new IntRange(end, start);
        }

        int cursor = doc.getCharIndexFromPosition(snapshot.cursor);
        return new IntRange(cursor, cursor);
    }

    void updateImeSelectionState() {
        if (mBatchEditDepth > 0) {
            mDeferredSelectionUpdate = true;
            return;
        }
        InputMethodManager imm = getInputMethodManager();
        if (imm == null) {
            return;
        }
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        syncPlatformTextInputState(snapshot);
        IntRange selectionOffsets = getImeSelectionOffsets(snapshot);
        IntRange composingOffsets = getImeComposingOffsets(snapshot);
        if (mLastImeSelectionStart == selectionOffsets.start
                && mLastImeSelectionEnd == selectionOffsets.end
                && mLastImeComposingStart == composingOffsets.start
                && mLastImeComposingEnd == composingOffsets.end) {
            return;
        }
        mLastImeSelectionStart = selectionOffsets.start;
        mLastImeSelectionEnd = selectionOffsets.end;
        mLastImeComposingStart = composingOffsets.start;
        mLastImeComposingEnd = composingOffsets.end;
        imm.updateSelection(mEditor, selectionOffsets.start, selectionOffsets.end,
                composingOffsets.start, composingOffsets.end);
    }

    void restartImeInput() {
        clearImeSelectionCache();
        clearImeTextWindows();
        InputMethodManager imm = getInputMethodManager();
        if (imm != null) {
            imm.restartInput(mEditor);
        }
    }

    private IntRange getImeComposingOffsets() {
        return getImeComposingOffsets(mEditor.getEditorCore().getImeSyncSnapshot());
    }

    private IntRange getImeComposingOffsets(EditorCore.ImeSyncSnapshot snapshot) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return new IntRange(-1, -1);
        }
        TextRange range = snapshot.platformMarkedRange;
        if (range == null || isCollapsed(range)) {
            return new IntRange(-1, -1);
        }

        int start = doc.getCharIndexFromPosition(range.start);
        int end = doc.getCharIndexFromPosition(range.end);
        return start <= end ? new IntRange(start, end) : new IntRange(end, start);
    }

    private InitialSurroundingText buildInitialSurroundingText(EditorCore.ImeSyncSnapshot snapshot,
                                                               int contextPolicy) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return null;
        }
        String documentText = doc.getText();
        IntRange selection = getImeSelectionOffsets();
        int selectionStart = Math.max(0, Math.min(selection.start, documentText.length()));
        int selectionEnd = Math.max(0, Math.min(selection.end, documentText.length()));
        int before = limitContextLength(MAX_IME_TEXT_LENGTH / 2, contextPolicy);
        int after = limitContextLength(MAX_IME_TEXT_LENGTH / 2, contextPolicy);
        before = Math.min(before, INITIAL_SURROUNDING_TEXT_LENGTH / 2);
        after = Math.min(after, INITIAL_SURROUNDING_TEXT_LENGTH / 2);
        int start = Math.max(0, selectionStart - before);
        int end = Math.min(documentText.length(), selectionEnd + after);
        if (start == end) {
            return null;
        }
        CharSequence text = applyComposingSpan(documentText.substring(start, end),
                GET_TEXT_WITH_STYLES,
                start);
        rememberSnapshotTextWindow(snapshot, documentText.length());
        rememberImeTextWindow(start, end, selectionStart, selectionEnd, documentText.length());
        return new InitialSurroundingText(text, start);
    }

    private CharSequence applyComposingSpan(String text, int flags, int documentOffset) {
        if ((flags & GET_TEXT_WITH_STYLES) == 0 || text.isEmpty()) {
            return text;
        }
        IntRange composing = getImeComposingOffsets();
        if (composing.start < 0 || composing.end < 0) {
            return text;
        }
        int start = Math.max(0, composing.start - documentOffset);
        int end = Math.min(text.length(), composing.end - documentOffset);
        if (start >= end) {
            return text;
        }
        SpannableStringBuilder styled = new SpannableStringBuilder(text);
        styled.setSpan(new Object(), start, end,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE | Spanned.SPAN_COMPOSING);
        return styled;
    }

    private void syncPlatformTextInputState(EditorCore.ImeSyncSnapshot snapshot) {
        Document doc = mEditor.getDocument();
        if (!shouldExposeDocumentContext(snapshot.contextPolicy) || doc == null) {
            if (mDocumentMirrorActive) {
                clearEditableMirror();
            }
            return;
        }

        syncPlatformTextInputState(doc.getText(),
                getImeSelectionOffsets(snapshot),
                getImeComposingOffsets(snapshot));
    }

    private void syncPlatformTextInputState(String text,
                                            IntRange selectionOffsets,
                                            IntRange composingOffsets) {
        boolean hasComposingRange = isValidEditableRange(composingOffsets, text.length());

        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.replace(0, mEditable.length(), text);
        mDocumentMirrorActive = true;

        int selectionStart = clampEditableOffset(selectionOffsets.start, mEditable.length());
        int selectionEnd = clampEditableOffset(selectionOffsets.end, mEditable.length());
        Selection.setSelection(mEditable, selectionStart, selectionEnd);
        if (hasComposingRange && composingOffsets.start != composingOffsets.end) {
            super.setComposingRegion(
                    clampEditableOffset(composingOffsets.start, mEditable.length()),
                    clampEditableOffset(composingOffsets.end, mEditable.length()));
        }
    }

    private boolean isValidEditableRange(IntRange range, int textLength) {
        return range != null
                && range.start >= 0
                && range.end >= 0
                && range.start <= textLength
                && range.end <= textLength
                && range.start != range.end;
    }

    private int clampEditableOffset(int offset, int textLength) {
        return Math.max(0, Math.min(offset, textLength));
    }

    private void rememberSnapshotTextWindow(EditorCore.ImeSyncSnapshot snapshot, int documentLength) {
        if (snapshot.platformTextWindowText == null || snapshot.platformTextWindowText.isEmpty()) {
            return;
        }
        int start = clampEditableOffset(snapshot.platformTextWindowStartOffset, documentLength);
        int end = clampEditableOffset(start + snapshot.platformTextWindowText.length(), documentLength);
        int selectionStart = start + snapshot.platformTextWindowSelectionOffsets.start;
        int selectionEnd = start + snapshot.platformTextWindowSelectionOffsets.end;
        int composingStart = snapshot.platformTextWindowComposingOffsets.start >= 0
                ? start + snapshot.platformTextWindowComposingOffsets.start
                : -1;
        int composingEnd = snapshot.platformTextWindowComposingOffsets.end >= 0
                ? start + snapshot.platformTextWindowComposingOffsets.end
                : -1;
        rememberImeTextWindow(start, end, selectionStart, selectionEnd,
                composingStart, composingEnd, documentLength);
    }

    private void rememberImeTextWindow(int startOffset,
                                       int endOffset,
                                       int selectionStartOffset,
                                       int selectionEndOffset,
                                       int documentLength) {
        IntRange composing = getImeComposingOffsets();
        rememberImeTextWindow(startOffset, endOffset, selectionStartOffset, selectionEndOffset,
                composing.start, composing.end, documentLength);
    }

    private void rememberImeTextWindow(int startOffset,
                                       int endOffset,
                                       int selectionStartOffset,
                                       int selectionEndOffset,
                                       int composingStartOffset,
                                       int composingEndOffset,
                                       int documentLength) {
        int start = clampEditableOffset(startOffset, documentLength);
        int end = clampEditableOffset(endOffset, documentLength);
        if (end < start) {
            int tmp = start;
            start = end;
            end = tmp;
        }
        if (start == end) {
            return;
        }
        int selectionStart = clampEditableOffset(selectionStartOffset, documentLength) - start;
        int selectionEnd = clampEditableOffset(selectionEndOffset, documentLength) - start;
        int composingStart = composingStartOffset >= 0
                ? clampEditableOffset(composingStartOffset, documentLength) - start
                : -1;
        int composingEnd = composingEndOffset >= 0
                ? clampEditableOffset(composingEndOffset, documentLength) - start
                : -1;
        mImeTextWindows[mImeTextWindowWriteIndex] = new ImeTextWindow(
                start,
                end,
                selectionStart,
                selectionEnd,
                composingStart,
                composingEnd,
                documentLength);
        mImeTextWindowWriteIndex = (mImeTextWindowWriteIndex + 1) % IME_TEXT_WINDOW_HISTORY_SIZE;
    }

    private void clearImeTextWindows() {
        for (int i = 0; i < IME_TEXT_WINDOW_HISTORY_SIZE; i++) {
            mImeTextWindows[i] = null;
        }
        mImeTextWindowWriteIndex = 0;
    }

    private void clearImeSelectionCache() {
        mLastImeSelectionStart = Integer.MIN_VALUE;
        mLastImeSelectionEnd = Integer.MIN_VALUE;
        mLastImeComposingStart = Integer.MIN_VALUE;
        mLastImeComposingEnd = Integer.MIN_VALUE;
    }

    private InputMethodManager getInputMethodManager() {
        return (InputMethodManager) mEditor.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    private boolean isCollapsed(TextRange range) {
        return range.start.line == range.end.line && range.start.column == range.end.column;
    }

    private static boolean rangesEqual(TextRange left, TextRange right) {
        return comparePosition(left.start, right.start) == 0 && comparePosition(left.end, right.end) == 0;
    }

    private static boolean rangesEqual(IntRange left, IntRange right) {
        return left != null && right != null && left.start == right.start && left.end == right.end;
    }

    private static boolean rangesTouch(int start, int end, int targetStart, int targetEnd) {
        return end >= targetStart && start <= targetEnd;
    }

    private static TextRange copyRange(TextRange range) {
        return new TextRange(
                new TextPosition(range.start.line, range.start.column),
                new TextPosition(range.end.line, range.end.column));
    }

    private static int comparePosition(TextPosition left, TextPosition right) {
        if (left.line != right.line) {
            return Integer.compare(left.line, right.line);
        }
        return Integer.compare(left.column, right.column);
    }

    private boolean shouldExposeDocumentContext(int contextPolicy) {
        return contextPolicy != EditorCore.ImeContextPolicy.NONE;
    }

    private int limitContextLength(int requestedLength, int contextPolicy) {
        int length = Math.max(0, Math.min(requestedLength, MAX_IME_TEXT_LENGTH));
        if (contextPolicy == EditorCore.ImeContextPolicy.LIMITED_FOR_CANDIDATES) {
            return Math.min(length, LIMITED_IME_CONTEXT_LENGTH);
        }
        return length;
    }

    private int resolveImeScriptHint() {
        return resolveSubtypeImeScriptHint();
    }

    private int resolveAndReportImeScriptHint() {
        int scriptHint = resolveImeScriptHint();
        if (scriptHint != EditorCore.ImeScriptClass.UNKNOWN) {
            mEditor.getEditorCore().setImeKeyboardScriptClass(scriptHint);
        }
        return scriptHint;
    }

    private int resolveSubtypeImeScriptHint() {
        InputMethodManager imm = (InputMethodManager) mEditor.getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm == null) {
            return EditorCore.ImeScriptClass.UNKNOWN;
        }
        InputMethodSubtype subtype = imm.getCurrentInputMethodSubtype();
        if (subtype == null) {
            return EditorCore.ImeScriptClass.UNKNOWN;
        }
        String languageTag = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N ? subtype.getLanguageTag() : "";
        return resolveSubtypeImeScriptHint(languageTag,
                subtype.getLocale(),
                subtype.getExtraValue(),
                subtype.isAsciiCapable());
    }

    private static int resolveSubtypeImeScriptHint(String languageTag,
                                                   String locale,
                                                   String extraValue,
                                                   boolean asciiCapable) {
        int languageTagScript = resolveLanguageImeScriptHint(languageTag);
        if (languageTagScript != EditorCore.ImeScriptClass.UNKNOWN) {
            return languageTagScript;
        }
        int localeScript = resolveLanguageImeScriptHint(locale);
        if (localeScript != EditorCore.ImeScriptClass.UNKNOWN) {
            return localeScript;
        }
        int extraScript = resolveExtraValueImeScriptHint(extraValue);
        if (extraScript != EditorCore.ImeScriptClass.UNKNOWN) {
            return extraScript;
        }
        return EditorCore.ImeScriptClass.UNKNOWN;
    }

    private static int resolveLanguageImeScriptHint(String locale) {
        if (locale == null || locale.isEmpty()) {
            return EditorCore.ImeScriptClass.UNKNOWN;
        }
        String normalized = locale.replace('_', '-');
        String language = Locale.forLanguageTag(normalized).getLanguage();
        if (language == null || language.isEmpty()) {
            int separator = normalized.indexOf('-');
            language = (separator >= 0 ? normalized.substring(0, separator) : normalized)
                    .toLowerCase(Locale.ROOT);
        }
        if ("zh".equals(language)) {
            return EditorCore.ImeScriptClass.CJK;
        }
        if ("ja".equals(language)) {
            return EditorCore.ImeScriptClass.KANA;
        }
        if ("ko".equals(language)) {
            return EditorCore.ImeScriptClass.HANGUL;
        }
        String script = Locale.forLanguageTag(normalized).getScript();
        if ("Latn".equalsIgnoreCase(script)) {
            return EditorCore.ImeScriptClass.LATIN;
        }
        return EditorCore.ImeScriptClass.UNKNOWN;
    }

    private static int resolveExtraValueImeScriptHint(String extraValue) {
        if (extraValue == null || extraValue.isEmpty()) {
            return EditorCore.ImeScriptClass.UNKNOWN;
        }
        String value = extraValue.toLowerCase(Locale.ROOT);
        if (value.contains("zh") || value.contains("pinyin")
                || value.contains("cangjie") || value.contains("wubi")) {
            return EditorCore.ImeScriptClass.CJK;
        }
        if (value.contains("ja") || value.contains("kana")) {
            return EditorCore.ImeScriptClass.KANA;
        }
        if (value.contains("ko") || value.contains("hangul")) {
            return EditorCore.ImeScriptClass.HANGUL;
        }
        if (value.contains("latin") || value.contains("alphabet")) {
            return EditorCore.ImeScriptClass.LATIN;
        }
        return EditorCore.ImeScriptClass.UNKNOWN;
    }

    private void clearShadowEditable() {
        BaseInputConnection.removeComposingSpans(mEditable);
        if (Selection.getSelectionStart(mEditable) < 0) {
            Selection.setSelection(mEditable, 0);
        }
    }

    private void clearEditableMirror() {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.clear();
        mDocumentMirrorActive = false;
        Selection.setSelection(mEditable, 0);
    }

    private boolean deleteImeSelection(String source) {
        TextRange selection = mEditor.getSelection();
        if (selection == null) {
            return false;
        }

        clearShadowEditable();
        deleteImeSurroundingText(0, 0, EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
        trace("after " + source + " deleted selection");
        return true;
    }

    private void trace(String event) {
        if (!TRACE_IME) {
            return;
        }
        Document doc = mEditor.getDocument();
        String text = doc != null ? doc.getText() : "";
        if (text.length() > 80) {
            text = text.substring(0, 80) + "...";
        }
        TextPosition cursor = mEditor.getCursorPosition();
        IntRange selection = getImeSelectionOffsets();
        Log.d(TAG, "#" + mConnectionId
                + " " + event
                + " text=" + quote(text)
                + " cursor=(" + cursor.line + "," + cursor.column + ")"
                + " selection=(" + selection.start + "," + selection.end + ")"
                + " composing=" + mEditor.getEditorCore().isComposing()
                + " session=" + hasImeComposingSession());
    }

    private String quote(CharSequence text) {
        return text == null ? "null" : "\"" + text + "\"";
    }
}
