package com.qiplat.sweeteditor;

import android.content.Context;
import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.util.Log;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.view.inputmethod.InputMethodSubtype;

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
    private static final int MAX_IME_TEXT_LENGTH = 512;
    private static final int LIMITED_IME_CONTEXT_LENGTH = 64;
    private static int sNextConnectionId = 1;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable;
    private final int mConnectionId;
    private int mPendingFallbackDeleteBeforeLength = 0;
    private int mLastImeSelectionStart = Integer.MIN_VALUE;
    private int mLastImeSelectionEnd = Integer.MIN_VALUE;
    private int mLastImeComposingStart = Integer.MIN_VALUE;
    private int mLastImeComposingEnd = Integer.MIN_VALUE;

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        mConnectionId = sNextConnectionId++;
        mEditable = new SpannableStringBuilder();
        Selection.setSelection(mEditable, 0);
        trace("create");
    }

    void configureEditorInfo(EditorInfo outAttrs) {
        clearImeSelectionCache();
        int inputType = EditorInfo.TYPE_CLASS_TEXT | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE;
        int imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        if (!mEditor.isCompositionEnabled()) {
            inputType |= EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                    | EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD;
            imeOptions |= EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING;
        }
        outAttrs.inputType = inputType;
        outAttrs.imeOptions = imeOptions;
        IntRange selectionOffsets = getImeSelectionOffsets();
        outAttrs.initialSelStart = selectionOffsets.start;
        outAttrs.initialSelEnd = selectionOffsets.end;
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    @Override
    public CharSequence getTextBeforeCursor(int n, int flags) {
        int contextPolicy = getImeContextPolicy();
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        if (shouldExposeShadowText()) {
            return super.getTextBeforeCursor(limitContextLength(n, contextPolicy), flags);
        }

        return getDocumentTextBeforeCursor(limitContextLength(n, contextPolicy), contextPolicy);
    }

    @Override
    public CharSequence getTextAfterCursor(int n, int flags) {
        int contextPolicy = getImeContextPolicy();
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        if (shouldExposeShadowText()) {
            return super.getTextAfterCursor(limitContextLength(n, contextPolicy), flags);
        }

        return getDocumentTextAfterCursor(limitContextLength(n, contextPolicy), contextPolicy);
    }

    @Override
    public CharSequence getSelectedText(int flags) {
        int contextPolicy = getImeContextPolicy();
        if (!shouldExposeDocumentContext(contextPolicy)) {
            return "";
        }
        if (shouldExposeShadowText()) {
            CharSequence selected = super.getSelectedText(flags);
            return selected != null ? selected : "";
        }
        if (mEditor.getSelection() == null) {
            return "";
        }

        String selected = mEditor.getSelectedText();
        return selected != null ? selected : "";
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        trace("before setComposingText text=" + quote(text) + " newCursor=" + newCursorPosition);
        mPendingFallbackDeleteBeforeLength = 0;
        String textStr = text != null ? text.toString() : "";
        if (!mEditor.isCompositionEnabled()) {
            if (text != null && text.length() > 0) {
                mEditable.replace(0, mEditable.length(), text);
                BaseInputConnection.setComposingSpans(mEditable);
                Selection.setSelection(mEditable, mEditable.length());
            } else {
                clearShadowEditable();
            }
            trace("after setComposingText disabled");
            return true;
        }
        clearShadowEditable();
        updateComposition(textStr, resolveImeScriptHint());
        trace("after setComposingText text=" + quote(textStr));
        return true;
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        trace("before setComposingRegion start=" + start + " end=" + end);
        if (!mEditor.isCompositionEnabled()) {
            trace("after setComposingRegion disabled");
            return true;
        }
        markComposingRegion(start, end);
        trace("after setComposingRegion start=" + start + " end=" + end);
        return true;
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        trace("before commitText text=" + quote(text) + " newCursor=" + newCursorPosition);
        String textStr = text != null ? text.toString() : "";
        if (textStr.isEmpty() && deleteImeSelection("commitText empty")) {
            return true;
        }
        if (!mEditor.isCompositionEnabled()) {
            int pendingCleanupLength = mEditable.length();
            clearShadowEditable();
            if (!textStr.isEmpty()) {
                commitComposition(textStr, resolveImeScriptHint());
            }
            mPendingFallbackDeleteBeforeLength = Math.max(mPendingFallbackDeleteBeforeLength, pendingCleanupLength);
            updateImeSelectionState();
            trace("after commitText disabled text=" + quote(textStr));
        } else {
            clearShadowEditable();
            commitComposition(textStr, resolveImeScriptHint());
            trace("after commitText text=" + quote(textStr));
        }
        return true;
    }

    @Override
    public boolean finishComposingText() {
        trace("before finishComposingText");
        if (mEditor.isCompositionEnabled() && hasImeComposingSession()) {
            finishComposition();
            trace("after finishComposingText session");
            return true;
        }

        if (!mEditor.isCompositionEnabled() && mEditable.length() > 0) {
            mPendingFallbackDeleteBeforeLength = mEditable.length();
            clearShadowEditable();
            updateImeSelectionState();
            trace("after finishComposingText disabled cleanup");
        }
        trace("after finishComposingText no-op");
        return true;
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        trace("before deleteSurroundingText before=" + beforeLength + " after=" + afterLength);
        return deleteSurroundingTextInternal(beforeLength, afterLength,
                EditorCore.ImeTextUnit.UTF16_CODE_UNIT, "deleteSurroundingText");
    }

    @Override
    public boolean deleteSurroundingTextInCodePoints(int beforeLength, int afterLength) {
        trace("before deleteSurroundingTextInCodePoints before=" + beforeLength + " after=" + afterLength);
        return deleteSurroundingTextInternal(beforeLength, afterLength,
                EditorCore.ImeTextUnit.CODE_POINT, "deleteSurroundingTextInCodePoints");
    }

    private boolean deleteSurroundingTextInternal(int beforeLength, int afterLength, int textUnit, String source) {
        if (!mEditor.isCompositionEnabled()) {
            if (deleteImeSelection(source)) {
                return true;
            }
            if (mEditable.length() > 0) {
                boolean result = textUnit == EditorCore.ImeTextUnit.CODE_POINT
                        ? super.deleteSurroundingTextInCodePoints(beforeLength, afterLength)
                        : super.deleteSurroundingText(beforeLength, afterLength);
                trace("after " + source + " disabled shadow result=" + result);
                return result;
            }
            int remainingBefore = consumePendingFallbackDelete(beforeLength);
            if (remainingBefore == 0 && afterLength == 0) {
                trace("after " + source + " disabled consumed fallback");
                return true;
            }
            mPendingFallbackDeleteBeforeLength = 0;
            if (remainingBefore == 1 && afterLength == 0 && hasCollapsedImeSelection()) {
                deleteImeBackward(textUnit);
                trace("after " + source + " disabled backspace fallback");
                return true;
            }
            if (remainingBefore == 0 && afterLength == 1 && hasCollapsedImeSelection()) {
                deleteImeForward(textUnit);
                trace("after " + source + " disabled forward fallback");
                return true;
            }
            boolean result = deleteImeSurroundingText(remainingBefore, afterLength, textUnit);
            trace("after " + source + " disabled direct result=" + result);
            return result;
        }

        clearShadowEditable();
        boolean result = deleteImeSurroundingText(beforeLength, afterLength, textUnit);
        trace("after " + source + " before=" + beforeLength + " after=" + afterLength
                + " result=" + result);
        return result;
    }

    @Override
    public boolean performContextMenuAction(int id) {
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
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();
            if (mEditor.isCompositionEnabled() && keyCode == KeyEvent.KEYCODE_DEL) {
                clearShadowEditable();
                deleteImeBackward();
                trace("after sendKeyEvent delete backward");
                return true;
            }
            if (mEditor.isCompositionEnabled() && keyCode == KeyEvent.KEYCODE_FORWARD_DEL) {
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
        return mEditor.getEditorCore().getImeSyncSnapshot().hasComposingSession;
    }

    private EditorCore.ImeEventResult handleImeCoreEvent(int type,
                                                         String text,
                                                         TextRange range,
                                                         TextPosition cursor,
                                                         long beforeLength,
                                                         long afterLength) {
        return handleImeCoreEvent(type, text, range, cursor, beforeLength, afterLength,
                EditorCore.ImeTextUnit.UTF16_CODE_UNIT, EditorCore.ImeScriptClass.UNKNOWN);
    }

    private EditorCore.ImeEventResult handleImeCoreEvent(int type,
                                                         String text,
                                                         TextRange range,
                                                         TextPosition cursor,
                                                         long beforeLength,
                                                         long afterLength,
                                                         int scriptHint) {
        return handleImeCoreEvent(type, text, range, cursor, beforeLength, afterLength,
                EditorCore.ImeTextUnit.UTF16_CODE_UNIT, scriptHint);
    }

    private EditorCore.ImeEventResult handleImeCoreEvent(int type,
                                                         String text,
                                                         TextRange range,
                                                         TextPosition cursor,
                                                         long beforeLength,
                                                         long afterLength,
                                                         int textUnit,
                                                         int scriptHint) {
        return mEditor.getEditorCore().handleImeEvent(
                type,
                text,
                range,
                cursor,
                beforeLength,
                afterLength,
                textUnit,
                scriptHint);
    }

    private void dispatchImeEventResult(EditorCore.ImeEventResult result) {
        mEditor.dispatchImeTextChanged(result.editResult);
        if (result.sync.clearPlatformPreedit) {
            clearShadowEditable();
        }
        if (result.sync.requestRestartInput) {
            mEditor.post(this::restartImeInput);
        }
    }

    private TextRange markComposingRegion(int startOffset, int endOffset) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return null;
        }
        TextRange range = resolveImeComposingRegion(startOffset, endOffset);
        if (range == null || isCollapsed(range)) {
            updateImeSelectionState();
            return null;
        }
        if (isCurrentComposingRange(range)) {
            return copyRange(range);
        }
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                EditorCore.ImeEventType.MARK_DOCUMENT_RANGE,
                null,
                range,
                null,
                0,
                0);
        dispatchImeEventResult(result);
        mEditor.flush();
        updateImeSelectionState();
        return copyRange(range);
    }

    private TextRange resolveImeComposingRegion(int startOffset, int endOffset) {
        int start = Math.max(0, Math.min(startOffset, endOffset));
        int end = Math.max(0, Math.max(startOffset, endOffset));
        Document doc = mEditor.getDocument();
        if (doc == null || start == end) {
            return null;
        }

        TextPosition cursor = mEditor.getCursorPosition();
        String lineText = doc.getLineText(cursor.line);
        int lineLength = lineText != null ? lineText.length() : 0;
        if (start <= lineLength && end <= lineLength) {
            TextRange lineRange = new TextRange(
                    new TextPosition(cursor.line, start),
                    new TextPosition(cursor.line, end));
            return containsPosition(lineRange, cursor) ? lineRange : null;
        }

        TextRange documentRange = new TextRange(
                doc.getPositionFromCharIndex(start),
                doc.getPositionFromCharIndex(end));
        return containsPosition(documentRange, cursor) ? documentRange : null;
    }

    private boolean isCurrentComposingRange(TextRange range) {
        if (!mEditor.getEditorCore().isComposing()) {
            return false;
        }
        TextRange currentRange = mEditor.getEditorCore().getComposingRange();
        return currentRange != null && rangesEqual(currentRange, range);
    }

    private void updateComposition(String text) {
        updateComposition(text, EditorCore.ImeScriptClass.UNKNOWN);
    }

    private void updateComposition(String text, int scriptHint) {
        long t0 = System.nanoTime();
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                EditorCore.ImeEventType.UPDATE_PREEDIT,
                text,
                null,
                null,
                0,
                0,
                scriptHint);
        dispatchImeEventResult(result);
        mEditor.flush();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-update");
    }

    private void commitComposition(String text) {
        commitComposition(text, EditorCore.ImeScriptClass.UNKNOWN);
    }

    private void commitComposition(String text, int scriptHint) {
        long t0 = System.nanoTime();
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                EditorCore.ImeEventType.COMMIT_TEXT,
                text,
                null,
                null,
                0,
                0,
                scriptHint);
        dispatchImeEventResult(result);
        mEditor.flush();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-commit");
    }

    private void finishComposition() {
        long t0 = System.nanoTime();
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                EditorCore.ImeEventType.FINISH_PREEDIT,
                null,
                null,
                null,
                0,
                0);
        dispatchImeEventResult(result);
        mEditor.flush();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-finish");
    }

    private boolean deleteImeBackward() {
        return deleteImeBackward(EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
    }

    private boolean deleteImeBackward(int textUnit) {
        return deleteImeText(EditorCore.ImeEventType.DELETE_BACKWARD, 1, 0, textUnit);
    }

    private boolean deleteImeForward() {
        return deleteImeForward(EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
    }

    private boolean deleteImeForward(int textUnit) {
        return deleteImeText(EditorCore.ImeEventType.DELETE_FORWARD, 0, 1, textUnit);
    }

    private boolean deleteImeSurroundingText(int beforeLength, int afterLength, int textUnit) {
        return deleteImeText(
                EditorCore.ImeEventType.DELETE_SURROUNDING,
                Math.max(0, beforeLength),
                Math.max(0, afterLength),
                textUnit);
    }

    private boolean deleteImeText(int type, int beforeLength, int afterLength, int textUnit) {
        long t0 = System.nanoTime();
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                type,
                null,
                null,
                null,
                beforeLength,
                afterLength,
                textUnit,
                EditorCore.ImeScriptClass.UNKNOWN);
        dispatchImeEventResult(result);
        mEditor.flush();
        updateImeSelectionState();
        mEditor.logInputPerf(t0, "ime-delete");
        return result.handled;
    }

    IntRange getImeSelectionOffsets() {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return new IntRange(0, 0);
        }

        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
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
        InputMethodManager imm = getInputMethodManager();
        if (imm == null) {
            return;
        }
        IntRange selectionOffsets = getImeSelectionOffsets();
        IntRange composingOffsets = getImeComposingOffsets();
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
        InputMethodManager imm = getInputMethodManager();
        if (imm != null) {
            imm.restartInput(mEditor);
        }
    }

    boolean restartCompositionAtCursorWord() {
        if (mEditor.getDocument() == null || !mEditor.isCompositionEnabled()) {
            return false;
        }
        TextRange range = mEditor.getEditorCore().getWordRangeAtCursor();
        if (range == null || isCollapsed(range)) {
            return false;
        }
        EditorCore.ImeEventResult result = handleImeCoreEvent(
                EditorCore.ImeEventType.MARK_DOCUMENT_RANGE,
                null,
                range,
                null,
                0,
                0);
        return result.sync.visibleCompositionRange != null;
    }

    private IntRange getImeComposingOffsets() {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return new IntRange(-1, -1);
        }
        EditorCore.ImeSyncSnapshot snapshot = mEditor.getEditorCore().getImeSyncSnapshot();
        TextRange range = snapshot.visibleCompositionRange;
        if (range == null || isCollapsed(range)) {
            return new IntRange(-1, -1);
        }

        int start = doc.getCharIndexFromPosition(range.start);
        int end = doc.getCharIndexFromPosition(range.end);
        return start <= end ? new IntRange(start, end) : new IntRange(end, start);
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

    private static boolean containsPosition(TextRange range, TextPosition position) {
        return comparePosition(range.start, position) <= 0 && comparePosition(position, range.end) <= 0;
    }

    private static boolean rangesEqual(TextRange left, TextRange right) {
        return comparePosition(left.start, right.start) == 0 && comparePosition(left.end, right.end) == 0;
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

    private CharSequence getDocumentTextBeforeCursor(int n, int contextPolicy) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());
        int start = contextPolicy == EditorCore.ImeContextPolicy.CURRENT_TOKEN
                ? findTokenStart(lineText, col)
                : 0;

        String beforeInLine = lineText.substring(start, col);
        return beforeInLine.length() > n
                ? beforeInLine.substring(beforeInLine.length() - n)
                : beforeInLine;
    }

    private CharSequence getDocumentTextAfterCursor(int n, int contextPolicy) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());
        int end = contextPolicy == EditorCore.ImeContextPolicy.CURRENT_TOKEN
                ? findTokenEnd(lineText, col)
                : lineText.length();
        String afterInLine = lineText.substring(col, end);
        return afterInLine.length() > n
                ? afterInLine.substring(0, n)
                : afterInLine;
    }

    private boolean shouldExposeDocumentContext(int contextPolicy) {
        return contextPolicy != EditorCore.ImeContextPolicy.NONE;
    }

    private int limitContextLength(int requestedLength, int contextPolicy) {
        int length = Math.max(0, Math.min(requestedLength, MAX_IME_TEXT_LENGTH));
        if (contextPolicy == EditorCore.ImeContextPolicy.LIMITED_FOR_CANDIDATES
                || contextPolicy == EditorCore.ImeContextPolicy.CURRENT_TOKEN) {
            return Math.min(length, LIMITED_IME_CONTEXT_LENGTH);
        }
        return length;
    }

    private int findTokenStart(String text, int column) {
        int index = Math.min(column, text.length());
        while (index > 0) {
            int previous = text.offsetByCodePoints(index, -1);
            int codePoint = text.codePointAt(previous);
            if (!isTokenCodePoint(codePoint)) {
                break;
            }
            index = previous;
        }
        return index;
    }

    private int findTokenEnd(String text, int column) {
        int index = Math.min(column, text.length());
        while (index < text.length()) {
            int codePoint = text.codePointAt(index);
            if (!isTokenCodePoint(codePoint)) {
                break;
            }
            index += Character.charCount(codePoint);
        }
        return index;
    }

    private boolean isTokenCodePoint(int codePoint) {
        return Character.isLetterOrDigit(codePoint) || codePoint == '_' || codePoint > 0x7F;
    }

    private boolean shouldExposeShadowText() {
        return false;
    }

    private int resolveImeScriptHint() {
        return resolveSubtypeImeScriptHint();
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
        String locale = subtype.getLocale();
        if (locale == null || locale.isEmpty()) {
            return EditorCore.ImeScriptClass.UNKNOWN;
        }
        int separator = locale.indexOf('_');
        int dash = locale.indexOf('-');
        if (separator < 0 || (dash >= 0 && dash < separator)) {
            separator = dash;
        }
        String language = (separator >= 0 ? locale.substring(0, separator) : locale).toLowerCase(Locale.ROOT);
        if ("zh".equals(language)) {
            return EditorCore.ImeScriptClass.CJK;
        }
        if ("ja".equals(language)) {
            return EditorCore.ImeScriptClass.KANA;
        }
        if ("ko".equals(language)) {
            return EditorCore.ImeScriptClass.HANGUL;
        }
        return EditorCore.ImeScriptClass.UNKNOWN;
    }

    private void clearShadowEditable() {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.clear();
        Selection.setSelection(mEditable, 0);
    }

    private boolean deleteImeSelection(String source) {
        TextRange selection = mEditor.getSelection();
        if (selection == null) {
            return false;
        }

        clearShadowEditable();
        deleteImeText(EditorCore.ImeEventType.DELETE_SURROUNDING, 0, 0,
                EditorCore.ImeTextUnit.UTF16_CODE_UNIT);
        trace("after " + source + " deleted selection");
        return true;
    }

    private int consumePendingFallbackDelete(int beforeLength) {
        if (beforeLength <= 0 || mPendingFallbackDeleteBeforeLength <= 0) {
            return beforeLength;
        }

        int consumed = Math.min(beforeLength, mPendingFallbackDeleteBeforeLength);
        mPendingFallbackDeleteBeforeLength -= consumed;
        return beforeLength - consumed;
    }

    private boolean hasCollapsedImeSelection() {
        IntRange selectionOffsets = getImeSelectionOffsets();
        return selectionOffsets.start == selectionOffsets.end;
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
