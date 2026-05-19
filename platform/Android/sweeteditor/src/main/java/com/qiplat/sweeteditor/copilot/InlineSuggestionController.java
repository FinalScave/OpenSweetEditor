package com.qiplat.sweeteditor.copilot;

import android.content.Context;
import android.util.SparseArray;
import android.view.KeyEvent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Collections;
import java.util.List;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.EditorEventListener;
import com.qiplat.sweeteditor.event.ScrollChangedEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;

/**
 * Manages inline suggestion lifecycle: phantom text injection, event subscriptions,
 * Tab/Esc key interception, and delegates UI to {@link InlineSuggestionActionBar}.
 */
public class InlineSuggestionController implements InlineSuggestionActionBar.ActionCallback {

    private final SweetEditor editor;
    private final InlineSuggestionActionBar actionBar;

    @Nullable private InlineSuggestion currentSuggestion;
    @Nullable private InlineSuggestionListener listener;

    private float cachedCursorX;
    private float cachedCursorY;
    private float cachedCursorHeight;
    private boolean suppressAutoDismiss = false;

    private final EditorEventListener<TextChangedEvent> textWatcher = e -> autoDismiss();
    private final EditorEventListener<CursorChangedEvent> cursorWatcher = e -> autoDismiss();
    private final EditorEventListener<ScrollChangedEvent> scrollWatcher;

    public InlineSuggestionController(@NonNull Context context, @NonNull SweetEditor editor) {
        this.editor = editor;
        EditorTheme theme = editor.getTheme();
        this.actionBar = new InlineSuggestionActionBar(context,
                theme.inlineSuggestionBarBgColor,
                theme.inlineSuggestionBarAcceptColor,
                theme.inlineSuggestionBarDismissColor);
        this.actionBar.setCallback(this);
        this.scrollWatcher = e -> {
            if (isShowing()) {
                actionBar.updatePosition(editor, cachedCursorX, cachedCursorY, cachedCursorHeight);
            }
        };
    }

    public void setListener(@Nullable InlineSuggestionListener listener) {
        this.listener = listener;
    }

    /**
     * Forward theme changes to the action bar without recreating the controller.
     */
    public void applyTheme(@NonNull EditorTheme theme) {
        actionBar.applyTheme(
                theme.inlineSuggestionBarBgColor,
                theme.inlineSuggestionBarAcceptColor,
                theme.inlineSuggestionBarDismissColor);
    }

    public boolean isShowing() {
        return actionBar.isShowing();
    }

    /**
     * Show inline suggestion: inject phantom text and display action bar.
     */
    public void show(@NonNull InlineSuggestion suggestion) {
        if (isShowing()) {
            clearQuietly();
        }
        currentSuggestion = suggestion;
        injectPhantomText(suggestion);

        CursorRect rect = editor.getPositionRect(suggestion.line, suggestion.column);
        cachedCursorX = rect.x;
        cachedCursorY = rect.y;
        cachedCursorHeight = rect.height;

        actionBar.showAt(editor, cachedCursorX, cachedCursorY, cachedCursorHeight);
        subscribeEvents();
    }

    /**
     * Accept current suggestion: write text into document and clear phantom.
     */
    public void accept() {
        if (currentSuggestion == null) return;
        InlineSuggestion suggestion = currentSuggestion;

        withSuppressedAutoDismiss(() -> {
            unsubscribeEvents();
            editor.clearPhantomTexts();
            TextPosition pos = new TextPosition(suggestion.line, suggestion.column);
            editor.replaceText(new TextRange(pos, pos), suggestion.text);
            actionBar.dismissImmediately();
            currentSuggestion = null;
        });

        if (listener != null) listener.onSuggestionAccepted(suggestion);
    }

    /**
     * Dismiss current suggestion without inserting text.
     */
    public void dismiss() {
        if (currentSuggestion == null) return;
        InlineSuggestion suggestion = currentSuggestion;

        withSuppressedAutoDismiss(() -> {
            unsubscribeEvents();
            editor.clearPhantomTexts();
            actionBar.dismiss();
            currentSuggestion = null;
        });

        if (listener != null) listener.onSuggestionDismissed(suggestion);
    }

    /**
     * Handle Android key codes. Returns true if consumed.
     * KEYCODE_TAB → accept, KEYCODE_ESCAPE → dismiss.
     */
    public boolean handleAndroidKeyCode(int androidKeyCode) {
        if (!isShowing()) return false;
        if (androidKeyCode == KeyEvent.KEYCODE_TAB) {
            accept();
            return true;
        }
        if (androidKeyCode == KeyEvent.KEYCODE_ESCAPE) {
            dismiss();
            return true;
        }
        return false;
    }

    /**
     * Update action bar position (called from SweetEditor onDraw).
     */
    public void updatePosition(float cursorX, float cursorY, float cursorHeight) {
        cachedCursorX = cursorX;
        cachedCursorY = cursorY;
        cachedCursorHeight = cursorHeight;
        if (isShowing()) {
            actionBar.updatePosition(editor, cursorX, cursorY, cursorHeight);
        }
    }

    @Override
    public void onAccept() {
        accept();
    }

    @Override
    public void onDismiss() {
        dismiss();
    }

    private void autoDismiss() {
        if (suppressAutoDismiss) return;
        dismiss();
    }

    private void clearQuietly() {
        withSuppressedAutoDismiss(() -> {
            unsubscribeEvents();
            editor.clearPhantomTexts();
            actionBar.dismissImmediately();
            currentSuggestion = null;
        });
    }

    private void withSuppressedAutoDismiss(Runnable action) {
        suppressAutoDismiss = true;
        try {
            action.run();
        } finally {
            suppressAutoDismiss = false;
        }
    }

    private void injectPhantomText(InlineSuggestion suggestion) {
        SparseArray<List<PhantomText>> phantoms = new SparseArray<>();
        phantoms.put(suggestion.line,
                Collections.singletonList(new PhantomText(suggestion.column, suggestion.text)));
        editor.clearPhantomTexts();
        editor.setBatchLinePhantomTexts(phantoms);
    }

    private void subscribeEvents() {
        editor.subscribe(TextChangedEvent.class, textWatcher);
        editor.subscribe(CursorChangedEvent.class, cursorWatcher);
        editor.subscribe(ScrollChangedEvent.class, scrollWatcher);
    }

    private void unsubscribeEvents() {
        editor.unsubscribe(TextChangedEvent.class, textWatcher);
        editor.unsubscribe(CursorChangedEvent.class, cursorWatcher);
        editor.unsubscribe(ScrollChangedEvent.class, scrollWatcher);
    }
}
