package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class LinkedEditInteractionTest {

    @Rule
    public EditorTestRule editorRule = new EditorTestRule();

    @Test
    public void testInsertSnippet() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor ->
                editor.insertSnippet("for(${1:i}=0; ${1:i}<${2:n}; ${1:i}++)"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertFalse(text.isEmpty());
        boolean inLinked = editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing());
        assertTrue("Should be in linked editing after snippet insert", inLinked);
    }

    @Test
    public void testInsertSnippetExpandsText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("hello ${1:world}!"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertTrue("Text should contain expanded snippet", text.contains("hello"));
        assertTrue("Text should contain placeholder default", text.contains("world"));
    }

    @Test
    public void testStartLinkedEditing() {
        editorRule.loadText("foo bar foo");
        LinkedEditingModel model = new LinkedEditingModel.Builder()
                .addGroup(1, "foo")
                .addRange(0, 0, 0, 3)
                .addRange(0, 8, 0, 11)
                .and()
                .addGroup(0, null)
                .addRange(0, 11, 0, 11)
                .build();
        editorRule.runOnEditor(editor -> editor.startLinkedEditing(model));
        boolean inLinked = editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing());
        assertTrue("Should be in linked editing mode", inLinked);
    }

    @Test
    public void testLinkedEditingNext() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("${1:first} ${2:second}"));
        TextPosition pos1 = editorRule.runOnEditorSync(editor -> editor.getCursorPosition());
        editorRule.runOnEditor(editor -> editor.linkedEditingNext());
        TextPosition pos2 = editorRule.runOnEditorSync(editor -> editor.getCursorPosition());
        assertFalse("Cursor should move to next tab stop",
                pos1.line == pos2.line && pos1.column == pos2.column);
    }

    @Test
    public void testLinkedEditingPrev() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("${1:first} ${2:second}"));
        editorRule.runOnEditor(editor -> editor.linkedEditingNext());
        TextPosition posAtSecond = editorRule.runOnEditorSync(editor -> editor.getCursorPosition());
        editorRule.runOnEditor(editor -> editor.linkedEditingPrev());
        TextPosition posBackAtFirst = editorRule.runOnEditorSync(editor -> editor.getCursorPosition());
        assertFalse("Cursor should move back to previous tab stop",
                posAtSecond.line == posBackAtFirst.line && posAtSecond.column == posBackAtFirst.column);
    }

    @Test
    public void testCancelLinkedEditing() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("${1:first} ${2:second}"));
        assertTrue(editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing()));
        editorRule.runOnEditor(editor -> editor.cancelLinkedEditing());
        boolean inLinked = editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing());
        assertFalse("Should exit linked editing after cancel", inLinked);
    }

    @Test
    public void testLinkedEditingSync() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("${1:name} = ${1:name}"));
        // Cursor should be on first "name", type replacement
        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 0, 0, 4);
            editor.insertText("foo");
        });
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        // Both occurrences should be updated
        assertTrue("Both linked ranges should be synced", text.contains("foo = foo"));
    }

    @Test
    public void testLinkedEditingEndOnLastNext() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.insertSnippet("${1:a}${0}"));
        assertTrue(editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing()));
        // Navigate past all tab stops
        editorRule.runOnEditor(editor -> editor.linkedEditingNext());
        editorRule.waitForIdle();
        boolean inLinked = editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing());
        assertFalse("Should exit linked editing after navigating past last tab stop", inLinked);
    }

    @Test
    public void testIsInLinkedEditingInitiallyFalse() {
        editorRule.loadText("hello");
        boolean inLinked = editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing());
        assertFalse(inLinked);
    }

    @Test
    public void testSnippetWithMultipleGroups() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor ->
                editor.insertSnippet("function ${1:name}(${2:params}) {\n\t${0}\n}"));
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertTrue("Snippet should expand with defaults", text.contains("function name(params)"));
        assertTrue(editorRule.runOnEditorSync(editor -> editor.isInLinkedEditing()));
    }
}
