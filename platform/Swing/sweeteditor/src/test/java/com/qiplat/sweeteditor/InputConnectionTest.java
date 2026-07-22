package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import org.junit.jupiter.api.Test;

import javax.swing.SwingUtilities;
import java.awt.event.FocusEvent;
import java.awt.event.InputMethodEvent;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.awt.font.TextHitInfo;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InputConnectionTest {
    @Test
    void compositionIsProvisionalUntilCommitted() throws Exception {
        onEdt(() -> {
            SweetEditor editor = editor("");
            InputConnection connection = connection(editor);

            sendText(editor, "hello", 0, null);
            assertEquals("hello", editor.getDocument().getText());
            TextPosition cursor = editor.getCursorPosition();
            assertEquals(0, cursor.line);
            assertEquals(0, cursor.column);
            assertTrue(connection.hasComposition());
            assertFalse(editor.canUndo());
            assertEquals(0, editor.getInputMethodRequests().getCommittedTextLength());

            sendText(editor, "hello ", 6, null);
            assertEquals("hello ", editor.getDocument().getText());
            assertFalse(connection.hasComposition());
            assertTrue(editor.canUndo());

            editor.undo();
            assertEquals("", editor.getDocument().getText());
            connection.endSession(false);
        });
    }

    @Test
    void committedTextQueriesPreserveUtf16Indices() throws Exception {
        onEdt(() -> {
            SweetEditor editor = editor("A😀B");
            InputConnection connection = connection(editor);
            AttributedCharacterIterator iterator = editor.getInputMethodRequests().getCommittedText(
                    2,
                    3,
                    new AttributedCharacterIterator.Attribute[0]);

            assertEquals("A😀B".substring(2, 3), iteratorText(iterator));
            assertNull(editor.getInputMethodRequests().cancelLatestCommittedText(
                    new AttributedCharacterIterator.Attribute[0]));
            connection.endSession(false);
        });
    }

    @Test
    void emptyTextChangedCommitsAnEmptyComposition() throws Exception {
        onEdt(() -> {
            SweetEditor editor = editor("");
            InputConnection connection = connection(editor);
            sendText(editor, "draft", 0, TextHitInfo.leading(5));

            sendText(editor, null, 0, null);

            assertEquals("", editor.getDocument().getText());
            assertFalse(connection.hasComposition());
            assertFalse(editor.canUndo());
            connection.endSession(false);
        });
    }

    @Test
    void closedSessionWaitsForTheNextFocusGeneration() throws Exception {
        onEdt(() -> {
            SweetEditor editor = editor("old");
            InputConnection connection = connection(editor);
            editor.loadDocument(new Document("new"));

            sendText(editor, "x", 1, null);
            assertEquals("new", editor.getDocument().getText());

            connection.focusLost(new FocusEvent(editor, FocusEvent.FOCUS_LOST));
            connection.focusGained(new FocusEvent(editor, FocusEvent.FOCUS_GAINED));
            sendText(editor, "x", 1, null);
            assertEquals("xnew", editor.getDocument().getText());
            connection.endSession(false);
        });
    }

    @Test
    void physicalBackspaceUsesCoreEditingWhileComposing() throws Exception {
        onEdt(() -> {
            SweetEditor editor = editor("");
            InputConnection connection = connection(editor);
            sendText(editor, "ab", 0, TextHitInfo.leading(2));

            KeyEvent event = new KeyEvent(editor, KeyEvent.KEY_PRESSED, 0, 0, KeyEvent.VK_BACK_SPACE, '\b');
            for (KeyListener listener : editor.getKeyListeners()) {
                listener.keyPressed(event);
            }

            assertEquals("a", editor.getDocument().getText());
            assertFalse(connection.hasComposition());
            assertTrue(editor.canUndo());
            connection.endSession(false);
        });
    }

    private static SweetEditor editor(String text) {
        SweetEditor editor = new SweetEditor();
        editor.loadDocument(new Document(text));
        connection(editor).focusGained(new FocusEvent(editor, FocusEvent.FOCUS_GAINED));
        return editor;
    }

    private static InputConnection connection(SweetEditor editor) {
        for (var listener : editor.getInputMethodListeners()) {
            if (listener instanceof InputConnection connection) return connection;
        }
        throw new AssertionError("InputConnection is not registered");
    }

    private static void sendText(SweetEditor editor, String text, int committedCount, TextHitInfo caret) {
        AttributedCharacterIterator iterator = text == null ? null : new AttributedString(text).getIterator();
        InputMethodEvent event = new InputMethodEvent(
                editor,
                InputMethodEvent.INPUT_METHOD_TEXT_CHANGED,
                iterator,
                committedCount,
                caret,
                null);
        connection(editor).inputMethodTextChanged(event);
    }

    private static String iteratorText(AttributedCharacterIterator iterator) {
        StringBuilder text = new StringBuilder();
        for (char current = iterator.first(); current != AttributedCharacterIterator.DONE; current = iterator.next()) {
            text.append(current);
        }
        return text.toString();
    }

    private static void onEdt(ThrowingRunnable action) throws Exception {
        AtomicReference<Throwable> failure = new AtomicReference<>();
        SwingUtilities.invokeAndWait(() -> {
            try {
                action.run();
            } catch (Throwable throwable) {
                failure.set(throwable);
            }
        });
        if (failure.get() instanceof Exception exception) throw exception;
        if (failure.get() instanceof Error error) throw error;
    }

    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
