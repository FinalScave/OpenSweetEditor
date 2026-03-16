package com.qiplat.sweeteditor;

import android.text.Editable;
import android.text.SpannableStringBuilder;
import android.util.Log;
import android.view.KeyEvent;
import android.view.inputmethod.BaseInputConnection;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Custom InputConnection for handling IME input method composing and commit.
 * <p>
 * Override getTextBeforeCursor / getTextAfterCursor / getSelectedText etc.,
 * read real document text directly from editor core to ensure IME gets correct context.
 */
public class SweetEditorInputConnection extends BaseInputConnection {
    private static final String TAG = "SweetEditorIC";
    private final SweetEditor mEditor;
    private final SpannableStringBuilder mEditable;

    public SweetEditorInputConnection(SweetEditor editor, boolean fullEditor) {
        super(editor, fullEditor);
        mEditor = editor;
        mEditable = new SpannableStringBuilder();
    }

    @Override
    public Editable getEditable() {
        return mEditable;
    }

    @Override
    public CharSequence getTextBeforeCursor(int n, int flags) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());

        if (col == 0 && cursorPos.line == 0) return "";

        String beforeInLine = lineText.substring(0, col);

        if (beforeInLine.length() >= n) {
            return beforeInLine.substring(beforeInLine.length() - n);
        }

        StringBuilder sb = new StringBuilder(beforeInLine);
        for (int line = cursorPos.line - 1; line >= 0 && sb.length() < n; line--) {
            String prevLineText = doc.getLineText(line);
            if (prevLineText == null) prevLineText = "";
            sb.insert(0, "\n");
            sb.insert(0, prevLineText);
        }

        String result = sb.toString();
        if (result.length() > n) {
            return result.substring(result.length() - n);
        }
        return result;
    }

    @Override
    public CharSequence getTextAfterCursor(int n, int flags) {
        Document doc = mEditor.getDocument();
        if (doc == null) return "";

        TextPosition cursorPos = mEditor.getCursorPosition();

        String lineText = doc.getLineText(cursorPos.line);
        if (lineText == null) lineText = "";

        int col = Math.min(cursorPos.column, lineText.length());
        String afterInLine = lineText.substring(col);

        if (afterInLine.length() >= n) {
            return afterInLine.substring(0, n);
        }

        StringBuilder sb = new StringBuilder(afterInLine);
        int lineCount = doc.getLineCount();
        for (int line = cursorPos.line + 1; line < lineCount && sb.length() < n; line++) {
            sb.append("\n");
            String nextLineText = doc.getLineText(line);
            if (nextLineText != null) {
                sb.append(nextLineText);
            }
        }

        String result = sb.toString();
        if (result.length() > n) {
            return result.substring(0, n);
        }
        return result;
    }

    @Override
    public CharSequence getSelectedText(int flags) {
        String selected = mEditor.getSelectedText();
        return selected != null ? selected : "";
    }

    @Override
    public boolean setComposingText(CharSequence text, int newCursorPosition) {
        Log.d(TAG, "setComposingText: text=" + text + ", newCursorPosition=" + newCursorPosition);
        if (!mEditor.isCompositionEnabled()) {
            return true;
        }
        mEditor.compositionUpdate(text != null ? text.toString() : "");
        return true;
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
        Log.d(TAG, "commitText: text=" + text + ", isComposing=" + mEditor.isComposing());
        String textStr = text != null ? text.toString() : "";
        if (!mEditor.isCompositionEnabled() || !mEditor.isComposing()) {
            if (!textStr.isEmpty()) {
                mEditor.insertText(textStr);
            }
        } else {
            mEditor.commitComposition(textStr);
        }
        return true;
    }

    @Override
    public boolean finishComposingText() {
        Log.d(TAG, "finishComposingText: isComposing=" + mEditor.isComposing());
        if (mEditor.isCompositionEnabled() && mEditor.isComposing()) {
            mEditor.commitComposition("");
        }
        return true;
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
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
            mEditor.copyToClipboard();
            return true;
        } else if (id == android.R.id.paste) {
            mEditor.pasteFromClipboard();
            return true;
        } else if (id == android.R.id.cut) {
            mEditor.cutToClipboard();
            return true;
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
}
