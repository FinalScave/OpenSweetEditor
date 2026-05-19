package com.qiplat.sweeteditor.copilot;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.event.*;

import java.awt.event.KeyEvent;
import java.util.List;

/**
 * Controller managing inline suggestion lifecycle: PhantomText injection,
 * event listening, Tab/Esc interception, and action bar display.
 */
public class InlineSuggestionController {

    private final SweetEditor editor;
    private InlineSuggestionActionBar actionBar;
    private InlineSuggestion currentSuggestion;
    private InlineSuggestionListener listener;
    private boolean showing = false;

    private final EditorEventListener<TextChangedEvent> textListener = e -> autoDismiss();
    private final EditorEventListener<CursorChangedEvent> cursorListener = e -> autoDismiss();

    public InlineSuggestionController(SweetEditor editor) {
        this.editor = editor;
    }

    public void show(InlineSuggestion suggestion) {
        if (suggestion == null || suggestion.text == null || suggestion.text.isEmpty()) return;

        // Dismiss previous suggestion if any
        if (showing) {
            clearPhantomText();
        }

        currentSuggestion = suggestion;
        showing = true;

        editor.setLinePhantomTexts(suggestion.line,
                List.of(new PhantomText(suggestion.column, suggestion.text)));

        editor.subscribe(TextChangedEvent.class, textListener);
        editor.subscribe(CursorChangedEvent.class, cursorListener);

        if (actionBar == null) {
            actionBar = new InlineSuggestionActionBar(editor, editor.getTheme(),
                    this::accept, this::dismiss);
        }
        actionBar.showAtCursor();
    }

    public void accept() {
        if (!showing) return;
        InlineSuggestion suggestion = currentSuggestion;

        clearAndUnsubscribe();

        if (suggestion != null) {
            editor.getEditorCore().setCursorPosition(suggestion.line, suggestion.column);
            editor.insertText(suggestion.text);
        }

        if (listener != null && suggestion != null) {
            listener.onSuggestionAccepted(suggestion);
        }
    }

    public void dismiss() {
        if (!showing) return;
        InlineSuggestion suggestion = currentSuggestion;

        clearAndUnsubscribe();

        if (listener != null && suggestion != null) {
            listener.onSuggestionDismissed(suggestion);
        }
    }

    public boolean isShowing() {
        return showing;
    }

    public void setListener(InlineSuggestionListener listener) {
        this.listener = listener;
    }

    public void close() {
        if (showing) {
            clearAndUnsubscribe();
        }
        listener = null;
    }

    public void applyTheme(EditorTheme theme) {
        if (actionBar != null) {
            actionBar.applyTheme(theme);
        }
    }

    /**
     * Intercepts Tab (accept) and Escape (dismiss) key events.
     * @return true if the key was consumed
     */
    public boolean handleKeyEvent(int keyCode) {
        if (!showing) return false;
        if (keyCode == KeyEvent.VK_TAB) {
            accept();
            return true;
        }
        if (keyCode == KeyEvent.VK_ESCAPE) {
            dismiss();
            return true;
        }
        return false;
    }

    public void updatePosition(float cursorX, float cursorY, float cursorHeight) {
        if (actionBar != null && showing) {
            actionBar.updatePosition(cursorX, cursorY, cursorHeight);
        }
    }

    private void autoDismiss() {
        if (!showing) return;
        InlineSuggestion suggestion = currentSuggestion;
        clearAndUnsubscribe();
        if (listener != null && suggestion != null) {
            listener.onSuggestionDismissed(suggestion);
        }
    }

    private void clearAndUnsubscribe() {
        showing = false;
        clearPhantomText();
        currentSuggestion = null;

        editor.unsubscribe(TextChangedEvent.class, textListener);
        editor.unsubscribe(CursorChangedEvent.class, cursorListener);

        if (actionBar != null) {
            actionBar.dismiss();
        }
    }

    private void clearPhantomText() {
        if (currentSuggestion != null) {
            editor.setLinePhantomTexts(currentSuggestion.line, List.of());
        }
    }
}
