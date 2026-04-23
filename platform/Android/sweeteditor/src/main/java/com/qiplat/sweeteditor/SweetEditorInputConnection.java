package com.qiplat.sweeteditor;

import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Custom InputConnection for handling IME input method composing and commit.
 * <p>
 * Override getTextBeforeCursor / getTextAfterCursor / getSelectedText etc.,
 * read real document text directly from editor core to ensure IME gets correct context.
 */
public class SweetEditorInputConnection extends BaseInputConnection {
    private static final int MAX_IME_TEXT_LENGTH = 512;

    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable;
    private int mPendingFallbackDeleteBeforeLength = 0;

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        mEditable = new SpannableStringBuilder();
        Selection.setSelection(mEditable, 0);
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    @Override
    public CharSequence getTextBeforeCursor(int n, int flags) {
        n = Math.min(n, MAX_IME_TEXT_LENGTH);
        if (shouldExposeShadowText()) {
            return super.getTextBeforeCursor(n, flags);
        }

        return getDocumentTextBeforeCursor(n);
    }

    @Override
    public CharSequence getTextAfterCursor(int n, int flags) {
        n = Math.min(n, MAX_IME_TEXT_LENGTH);
        if (shouldExposeShadowText()) {
            return super.getTextAfterCursor(n, flags);
        }

        return getDocumentTextAfterCursor(n);
    }

    @Override
    public CharSequence getSelectedText(int flags) {
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
        mPendingFallbackDeleteBeforeLength = 0;
        if (!mEditor.isCompositionEnabled()) {
            if (text != null && text.length() > 0) {
                // Just insert it as if it's already committed text to prevent shadow composition states
                mEditor.insertText(text.toString());
            }
            return true;
        }
        mEditor.compositionUpdate(text != null ? text.toString() : "");
        return true;
    }

    @Override
    public boolean setComposingRegion(int start, int end) {
        if (!mEditor.isCompositionEnabled()) {
            return true;
        }
        mEditor.setComposingRegion(start, end);
        return true;
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        String textStr = text != null ? text.toString() : "";
        if (!mEditor.isCompositionEnabled() || !mEditor.isComposing()) {
            mPendingFallbackDeleteBeforeLength = mEditable.length();
            clearShadowEditable();
            if (textStr.equals("\n")) {
                mEditor.handleKeyEventFromIME(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER));
            } else if (!textStr.isEmpty()) {
                mEditor.insertText(textStr);
            }
            if (!mEditor.isCompositionEnabled()) {
                mEditor.updateImeSelectionState();
            }
        } else {
            mEditor.commitComposition(textStr);
        }
        return true;
    }

    @Override
    public boolean finishComposingText() {
        if (mEditor.isCompositionEnabled() && mEditor.isComposing()) {
            mEditor.commitComposition("");
            return true;
        }

        if (!mEditor.isCompositionEnabled() && mEditable.length() > 0) {
            mPendingFallbackDeleteBeforeLength = mEditable.length();
            clearShadowEditable();
            mEditor.updateImeSelectionState();
        }
        return true;
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
        if (!mEditor.isCompositionEnabled()) {
            int remainingBefore = consumePendingFallbackDelete(beforeLength);
            if (mEditable.length() > 0) {
                return super.deleteSurroundingText(remainingBefore, afterLength);
            }
            if (remainingBefore == 0 && afterLength == 0) {
                return true;
            }
            mPendingFallbackDeleteBeforeLength = 0;
            if (remainingBefore == 1 && afterLength == 0 && hasCollapsedImeSelection()) {
                sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL));
                sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL));
                return true;
            }
            if (remainingBefore == 0 && afterLength == 1 && hasCollapsedImeSelection()) {
                sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_FORWARD_DEL));
                sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_FORWARD_DEL));
                return true;
            }
            return deleteDocumentSurroundingText(remainingBefore, afterLength);
        }

        for (int i = 0; i < beforeLength; i++) {
            sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL));
            sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL));
        }
        for (int i = 0; i < afterLength; i++) {
            sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_FORWARD_DEL));
            sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_FORWARD_DEL));
        }
        return true;
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
            mEditor.handleKeyEventFromIME(event);
        }
        return true;
    }

    private CharSequence getDocumentTextBeforeCursor(int n) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());

        String beforeInLine = lineText.substring(0, col);
        return beforeInLine.length() > n
                ? beforeInLine.substring(beforeInLine.length() - n)
                : beforeInLine;
    }

    private CharSequence getDocumentTextAfterCursor(int n) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());
        String afterInLine = lineText.substring(col);
        return afterInLine.length() > n
                ? afterInLine.substring(0, n)
                : afterInLine;
    }

    private boolean shouldExposeShadowText() {
        return false;
    }

    private void clearShadowEditable() {
        BaseInputConnection.removeComposingSpans(mEditable);
        mEditable.clear();
        Selection.setSelection(mEditable, 0);
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
        IntRange selectionOffsets = mEditor.getImeSelectionOffsets();
        return selectionOffsets.start == selectionOffsets.end;
    }

    private boolean deleteDocumentSurroundingText(int beforeLength, int afterLength) {
        Document doc = mEditor.getDocument();
        if (doc == null) {
            return true;
        }

        IntRange selectionOffsets = mEditor.getImeSelectionOffsets();
        long rawDeleteStart = (long) selectionOffsets.start - Math.max(0, beforeLength);
        long rawDeleteEnd = (long) selectionOffsets.end + Math.max(0, afterLength);
        int deleteStart = (int) Math.max(0L, Math.min(rawDeleteStart, Integer.MAX_VALUE));
        int deleteEnd = (int) Math.max(0L, Math.min(rawDeleteEnd, Integer.MAX_VALUE));
        if (deleteStart >= deleteEnd) {
            return true;
        }

        TextRange deleteRange = new TextRange(
                doc.getPositionFromCharIndex(deleteStart),
                doc.getPositionFromCharIndex(deleteEnd));
        mEditor.deleteText(deleteRange);
        mEditor.updateImeSelectionState();
        return true;
    }
}
