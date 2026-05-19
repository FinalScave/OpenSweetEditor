package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class EditingInteractionTest {

    @Rule
    public EditorTestRule editorRule = new EditorTestRule();

    @Test
    public void testInsertText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertText("hello"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello", text);
    }

    @Test
    public void testInsertTextResult() {
        editorRule.loadText("");
        AtomicBoolean textChanged = new AtomicBoolean(false);
        editorRule.runOnEditor(editor -> editor.subscribe(TextChangedEvent.class, event -> textChanged.set(true)));
        editorRule.runOnEditor(editor -> editor.insertText("abc"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("abc", text);
        assertTrue(textChanged.get());
    }

    @Test
    public void testInsertMultiLineText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertText("line1\nline2\nline3"));
        int lineCount = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineCount());
        assertEquals(3, lineCount);
    }

    @Test
    public void testDeleteText() {
        editorRule.loadText("hello world");
        TextRange range = new TextRange(new TextPosition(0, 0), new TextPosition(0, 5));
        editorRule.runOnEditor(editor -> editor.deleteText(range));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals(" world", text);
    }

    @Test
    public void testReplaceText() {
        editorRule.loadText("hello world");
        TextRange range = new TextRange(new TextPosition(0, 0), new TextPosition(0, 5));
        editorRule.runOnEditor(editor -> editor.replaceText(range, "goodbye"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("goodbye world", text);
    }

    @Test
    public void testMoveLineUp() {
        editorRule.loadText("first\nsecond");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(1, 0));
            editor.moveLineUp();
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("second\nfirst", text);
    }

    @Test
    public void testMoveLineDown() {
        editorRule.loadText("first\nsecond");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.moveLineDown();
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("second\nfirst", text);
    }

    @Test
    public void testCopyLineUp() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.copyLineUp();
        });
        int lineCount = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineCount());
        assertEquals(2, lineCount);
        String line0 = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineText(0));
        String line1 = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineText(1));
        assertEquals(line0, line1);
    }

    @Test
    public void testCopyLineDown() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.copyLineDown();
        });
        int lineCount = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineCount());
        assertEquals(2, lineCount);
    }

    @Test
    public void testDeleteLine() {
        editorRule.loadText("first\nsecond");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.deleteLine();
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("second", text);
    }

    @Test
    public void testInsertLineAbove() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.insertLineAbove();
        });
        int lineCount = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineCount());
        assertEquals(2, lineCount);
        String line0 = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineText(0));
        assertTrue("First line should be empty", line0.isEmpty());
    }

    @Test
    public void testInsertLineBelow() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 0));
            editor.insertLineBelow();
        });
        int lineCount = editorRule.runOnEditorSync(editor -> editor.getDocument().getLineCount());
        assertEquals(2, lineCount);
    }

    @Test
    public void testUndo() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> editor.insertText(" world"));
        String afterInsert = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello world", afterInsert);
        editorRule.runOnEditor(editor -> editor.undo());
        String afterUndo = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello", afterUndo);
    }

    @Test
    public void testRedo() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> editor.insertText(" world"));
        editorRule.runOnEditor(editor -> editor.undo());
        editorRule.runOnEditor(editor -> editor.redo());
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello world", text);
    }

    @Test
    public void testCanUndoInitiallyFalse() {
        editorRule.loadText("hello");
        boolean canUndo = editorRule.runOnEditorSync(editor -> editor.canUndo());
        assertFalse(canUndo);
    }

    @Test
    public void testCanUndoAfterEdit() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> editor.insertText("x"));
        boolean canUndo = editorRule.runOnEditorSync(editor -> editor.canUndo());
        assertTrue(canUndo);
    }

    @Test
    public void testCanRedoAfterUndo() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> editor.insertText("x"));
        editorRule.runOnEditor(editor -> editor.undo());
        boolean canRedo = editorRule.runOnEditorSync(editor -> editor.canRedo());
        assertTrue(canRedo);
    }

    @Test
    public void testTextChangedEvent() throws InterruptedException {
        editorRule.loadText("hello");
        AtomicBoolean eventReceived = new AtomicBoolean(false);
        CountDownLatch latch = new CountDownLatch(1);
        editorRule.runOnEditor(editor -> editor.subscribe(TextChangedEvent.class, e -> {
            eventReceived.set(true);
            latch.countDown();
        }));
        editorRule.runOnEditor(editor -> editor.insertText("x"));
        assertTrue("TextChangedEvent should be received", latch.await(2, TimeUnit.SECONDS));
        assertTrue(eventReceived.get());
    }

    @Test
    public void testInsertAtCursorPosition() {
        editorRule.loadText("helloworld");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 5));
            editor.insertText(" ");
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello world", text);
    }

    @Test
    public void testReplaceSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 0, 0, 5);
            editor.insertText("goodbye");
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("goodbye world", text);
    }
}
