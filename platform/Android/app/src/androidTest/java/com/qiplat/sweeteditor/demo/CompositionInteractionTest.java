package com.qiplat.sweeteditor.demo;

import android.os.Build;
import android.view.KeyEvent;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.SurroundingText;
import android.view.inputmethod.TextSnapshot;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.lang.reflect.Method;

import static org.junit.Assert.*;

/**
 * Tests IME composition flow through InputConnection.
 */
@RunWith(AndroidJUnit4.class)
public class CompositionInteractionTest {

    @Rule
    public EditorTestRule editorRule = new EditorTestRule();

    private InputConnection getInputConnection() {
        return editorRule.runOnEditorSync(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            return editor.onCreateInputConnection(info);
        });
    }

    private EditorCore getEditorCore(SweetEditor editor) {
        try {
            Method method = SweetEditor.class.getDeclaredMethod("getEditorCore");
            method.setAccessible(true);
            return (EditorCore) method.invoke(editor);
        } catch (Exception e) {
            throw new AssertionError(e);
        }
    }

    private boolean isComposing() {
        return editorRule.runOnEditorSync(editor -> getEditorCore(editor).isComposing());
    }

    private TextRange getComposingRange() {
        return editorRule.runOnEditorSync(editor -> getEditorCore(editor).getComposingRange());
    }

    @Test
    public void testCompositionFlowCommit() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection ic = getInputConnection();
        assertNotNull("InputConnection should not be null", ic);
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("pin", 1);
        });
        editorRule.waitForIdle();
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.finishComposingText();
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("pin", text);
    }

    @Test
    public void testCompositionCommitText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.commitText("hello", 1);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello", text);
    }

    @Test
    public void testCompositionMultipleCommits() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.commitText("hello", 1);
            conn.commitText(" ", 1);
            conn.commitText("world", 1);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("hello world", text);
    }

    @Test
    public void testInputConnectionNotNull() {
        editorRule.loadText("hello");
        InputConnection ic = getInputConnection();
        assertNotNull(ic);
    }

    @Test
    public void testOnCheckIsTextEditor() {
        boolean isTextEditor = editorRule.runOnEditorSync(editor -> editor.onCheckIsTextEditor());
        assertTrue("SweetEditor should report as text editor", isTextEditor);
    }

    @Test
    public void testDeleteSurroundingText() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(0, 5));
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.deleteSurroundingText(5, 0);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals(" world", text);
    }

    @Test
    public void testComposingTextUpdate() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("p", 1);
            conn.setComposingText("pi", 1);
            conn.setComposingText("pin", 1);
            conn.commitText("pin", 1);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("pin", text);
    }

    @Test
    public void testCompositionCandidateReplacesPreeditText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("n", 1);
            conn.setComposingText("ni", 1);
            conn.commitText("you", 1);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("you", text);
        assertFalse(isComposing());
    }

    @Test
    public void testCompositionBackspaceShrinksThenDeletesLastCharacter() {
        String initialText = "package demo;\nclass Example {}";
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(1, 0));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> conn.setComposingText("how", 1));
        editorRule.waitForIdle();
        assertEquals("package demo;\nhowclass Example {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());

        editorRule.runOnEditor(editor -> conn.deleteSurroundingText(1, 0));
        editorRule.waitForIdle();
        assertEquals("package demo;\nhoclass Example {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());

        editorRule.runOnEditor(editor -> conn.deleteSurroundingText(1, 0));
        editorRule.waitForIdle();
        assertEquals("package demo;\nhclass Example {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());

        editorRule.runOnEditor(editor -> conn.deleteSurroundingText(1, 0));
        editorRule.waitForIdle();
        assertEquals(initialText, editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        assertNull(getComposingRange());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(1, cursor.line);
        assertEquals(0, cursor.column);
    }

    @Test
    public void testCompositionFinishAfterShrinkDeletesLastCharacterWithoutJumpingToDocumentStart() {
        String initialText = "package demo;\nclass Example {}";
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(1, 0));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.setComposingText("ho", 1);
            conn.setComposingText("h", 1);
            conn.finishComposingText();
            conn.setComposingRegion(0, 1);
        });
        editorRule.waitForIdle();
        assertEquals(initialText, editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(1, cursor.line);
        assertEquals(0, cursor.column);
    }

    @Test
    public void testCompositionCommitAfterShrinkDeletesLastCharacterWithoutJumpingToDocumentStart() {
        String initialText = "package demo;\nclass Example {}";
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(1, 0));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.setComposingText("ho", 1);
            conn.setComposingText("h", 1);
            conn.commitText("h", 1);
            conn.setComposingRegion(0, 1);
        });
        editorRule.waitForIdle();
        assertEquals(initialText, editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(1, cursor.line);
        assertEquals(0, cursor.column);
    }

    @Test
    public void testComposingSessionEndsWhenCursorMovesToWhitespace() {
        editorRule.loadText("abc  ");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 5));
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("how", 1);
            editor.setCursorPosition(new TextPosition(0, 4));
        });
        editorRule.waitForIdle();
        assertEquals("abc  how", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(4, cursor.column);
    }

    @Test
    public void testCompositionDoesNotRestartAtWordMiddleAfterCursorMove() {
        editorRule.loadText("abc  ");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 5));
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("how", 1);
            editor.setCursorPosition(new TextPosition(0, 1));
        });
        editorRule.waitForIdle();
        assertEquals("abc  how", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(1, cursor.column);
    }

    @Test
    public void testCompositionRestartsAtWordEndAfterCursorMove() {
        editorRule.loadText("abc  ");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 5));
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("how", 1);
            editor.setCursorPosition(new TextPosition(0, 3));
        });
        editorRule.waitForIdle();
        assertEquals("abc  how", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());
        TextRange range = getComposingRange();
        assertNotNull(range);
        assertEquals(0, range.start.line);
        assertEquals(0, range.start.column);
        assertEquals(0, range.end.line);
        assertEquals(3, range.end.column);
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(3, cursor.column);
    }

    @Test
    public void testStaleComposingRegionAfterMovingToBlankLineDoesNotJumpToDocumentStart() {
        String colorLine = "static int[] colors = new int[0];";
        int colorsStart = colorLine.indexOf("colors");
        int colorsEnd = colorsStart + "colors".length();
        editorRule.loadText("package demo;\n" + colorLine + "\n\nclass Example {}");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(1, colorsEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> conn.setComposingRegion(colorsStart, colorsEnd));
        editorRule.waitForIdle();
        assertTrue(isComposing());
        TextRange range = getComposingRange();
        assertNotNull(range);
        assertEquals(1, range.start.line);
        assertEquals(colorsStart, range.start.column);
        assertEquals(1, range.end.line);
        assertEquals(colorsEnd, range.end.column);

        editorRule.runOnEditor(editor -> {
            editor.setCursorPosition(new TextPosition(2, 0));
            conn.setComposingRegion(0, colorsEnd - colorsStart);
        });
        editorRule.waitForIdle();

        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(2, cursor.line);
        assertEquals(0, cursor.column);
    }

    @Test
    public void testRepeatedDocumentRangeCandidateCommitReplacesWord() {
        String initialText = "record Point(double x, double y) {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.setComposingRegion(pointStart, pointEnd);
            conn.setComposingRegion(pointStart, pointEnd);
            conn.commitText("Points", 1);
        });
        editorRule.waitForIdle();

        assertEquals("record Points(double x, double y) {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(pointStart + "Points".length(), cursor.column);
    }

    @Test
    public void testDocumentRangePreeditCandidateFinishReplacesWord() {
        String initialText = "record Point(double x, double y) {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.setComposingText("Points", 1);
            conn.finishComposingText();
        });
        editorRule.waitForIdle();

        assertEquals("record Points(double x, double y) {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(pointStart + "Points".length(), cursor.column);
    }

    @Test
    public void testFinishedDocumentRangeCandidateCommitReplacesOriginalWordAfterCursorMove() {
        String initialText = "record Point(double x, double y) {}\nclass Other {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.finishComposingText();
            editor.setCursorPosition(new TextPosition(1, 0));
            conn.commitText("Points", 1);
        });
        editorRule.waitForIdle();

        assertEquals("record Points(double x, double y) {}\nclass Other {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(pointStart + "Points".length(), cursor.column);
    }

    @Test
    public void testFinishedDocumentRangeCandidateCommitIsIgnoredWhenOriginalRangeChanged() {
        String initialText = "record Point(double x, double y) {}\nclass Other {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.finishComposingText();
            editor.setCursorPosition(new TextPosition(1, 0));
            editor.replaceText(
                    new TextRange(new TextPosition(0, pointStart), new TextPosition(0, pointEnd)),
                    "Spot");
            conn.commitText("Points", 1);
        });
        editorRule.waitForIdle();

        assertEquals("record Spot(double x, double y) {}\nclass Other {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(1, cursor.line);
        assertEquals(0, cursor.column);
    }

    @Test
    public void testFinishedDocumentRangeSetComposingTextReplacesOriginalWordAfterCursorMove() {
        String initialText = "record Point(double x, double y) {}\nclass Other {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.finishComposingText();
            editor.setCursorPosition(new TextPosition(1, 0));
            conn.setComposingText("Points", 1);
            conn.finishComposingText();
        });
        editorRule.waitForIdle();

        assertEquals("record Points(double x, double y) {}\nclass Other {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(pointStart + "Points".length(), cursor.column);
    }

    @Test
    public void testFinishedDocumentRangeSetComposingTextThenCommitDoesNotDuplicate() {
        String initialText = "record Point(double x, double y) {}\nclass Other {}";
        int pointStart = initialText.indexOf("Point");
        int pointEnd = pointStart + "Point".length();
        editorRule.loadText(initialText);
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, pointEnd));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(pointStart, pointEnd);
            conn.finishComposingText();
            editor.setCursorPosition(new TextPosition(1, 0));
            conn.setComposingText("Points", 1);
            conn.commitText("Points", 1);
        });
        editorRule.waitForIdle();

        assertEquals("record Points(double x, double y) {}\nclass Other {}", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
        TextPosition cursor = editorRule.runOnEditorSync(SweetEditor::getCursorPosition);
        assertEquals(0, cursor.line);
        assertEquals(pointStart + "Points".length(), cursor.column);
    }

    @Test
    public void testDisabledCompositionCandidateCommit() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(false));
        editorRule.runOnEditor(editor -> {
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("ni", 1);
            conn.commitText("you", 1);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("you", text);
    }

    @Test
    public void testCommittedCandidateBackspaceIgnoresStaleComposingPrefix() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.commitText("how", 1);
            conn.deleteSurroundingText(1, 0);
            conn.commitText("h", 1);
            conn.setComposingRegion(0, 1);
        });
        editorRule.waitForIdle();
        assertEquals("ho", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));

        editorRule.runOnEditor(editor -> {
            conn.deleteSurroundingText(1, 0);
            conn.setComposingText("h", 1);
            conn.commitText("h", 1);
        });
        editorRule.waitForIdle();
        assertEquals("h", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));

        editorRule.runOnEditor(editor -> {
            conn.deleteSurroundingText(1, 0);
            conn.commitText("h", 1);
        });
        editorRule.waitForIdle();
        assertEquals("", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
    }

    @Test
    public void testFinishedCandidateBackspaceIgnoresStaleComposingPrefix() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.finishComposingText();
            conn.deleteSurroundingText(1, 0);
            conn.commitText("h", 1);
            conn.setComposingText("h", 1);
        });
        editorRule.waitForIdle();
        assertEquals("ho", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));

        editorRule.runOnEditor(editor -> {
            conn.deleteSurroundingText(1, 0);
            conn.commitText("h", 1);
        });
        editorRule.waitForIdle();
        assertEquals("h", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));

        editorRule.runOnEditor(editor -> {
            conn.deleteSurroundingText(1, 0);
            conn.setComposingText("h", 1);
        });
        editorRule.waitForIdle();
        assertEquals("", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
    }

    @Test
    public void testCommittedCandidateDoesNotReopenCompositionForSameWord() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.commitText("how", 1);
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection restartedConnection = editor.onCreateInputConnection(info);
            restartedConnection.setComposingRegion(0, 3);
            restartedConnection.setComposingText("how", 1);
        });
        editorRule.waitForIdle();

        assertEquals("how", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
    }

    @Test
    public void testFinishedCandidateSuppressedRegionBackspaceSyncsCommittedText() {
        editorRule.loadText("");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();
        InputConnection[] activeConnection = new InputConnection[]{conn};

        editorRule.runOnEditor(editor -> {
            conn.setComposingText("how", 1);
            conn.finishComposingText();
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection restartedConnection = editor.onCreateInputConnection(info);
            activeConnection[0] = restartedConnection;
            restartedConnection.setComposingRegion(0, 3);
            restartedConnection.setComposingText("ho", 1);
        });
        editorRule.waitForIdle();
        assertEquals("ho", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());

        editorRule.runOnEditor(editor -> activeConnection[0].setComposingText("h", 1));
        editorRule.waitForIdle();
        assertEquals("h", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertTrue(isComposing());

        editorRule.runOnEditor(editor -> activeConnection[0].finishComposingText());
        editorRule.waitForIdle();
        assertEquals("", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
    }

    @Test
    public void testCompositionEnabledDeleteSurroundingTextDeletesSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 0, 0, 5);
            conn.deleteSurroundingText(1, 0);
        });
        editorRule.waitForIdle();

        assertEquals(" world", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(editorRule.runOnEditorSync(SweetEditor::hasSelection));
    }

    @Test
    public void testCompositionEnabledDeleteSurroundingTextInCodePointsDeletesSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 6, 0, 11);
            conn.deleteSurroundingTextInCodePoints(1, 0);
        });
        editorRule.waitForIdle();

        assertEquals("hello ", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(editorRule.runOnEditorSync(SweetEditor::hasSelection));
    }

    @Test
    public void testCompositionEnabledSendDeleteKeyDeletesSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 0, 0, 5);
            conn.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL));
        });
        editorRule.waitForIdle();

        assertEquals(" world", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(editorRule.runOnEditorSync(SweetEditor::hasSelection));
    }

    @Test
    public void testCompositionEnabledEmptyCommitDeletesSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.getSettings().setCompositionEnabled(true));
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            editor.setSelection(0, 0, 0, 5);
            conn.commitText("", 1);
        });
        editorRule.waitForIdle();

        assertEquals(" world", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(editorRule.runOnEditorSync(SweetEditor::hasSelection));
    }

    @Test
    public void testDisabledCompositionCleanupDeleteDoesNotRemoveCommittedText() {
        editorRule.loadText("a");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(false);
            editor.setCursorPosition(new TextPosition(0, 1));
            android.view.inputmethod.EditorInfo info = new android.view.inputmethod.EditorInfo();
            InputConnection conn = editor.onCreateInputConnection(info);
            conn.setComposingText("ni", 1);
            conn.commitText("you", 1);
            conn.deleteSurroundingText(2, 0);
        });
        editorRule.waitForIdle();
        String text = editorRule.runOnEditorSync(editor -> editor.getDocument().getText());
        assertEquals("ayou", text);
    }

    @Test
    public void testDisabledCompositionExposesLimitedCandidateContextWithoutVisibleComposition() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(false);
            editor.setSelection(0, 0, 0, 5);
        });
        InputConnection conn = getInputConnection();

        assertEquals("hello", conn.getSelectedText(0).toString());

        editorRule.runOnEditor(editor -> editor.setCursorPosition(new TextPosition(0, 2)));
        editorRule.waitForIdle();
        assertEquals("he", conn.getTextBeforeCursor(5, 0).toString());
        assertEquals("llo", conn.getTextAfterCursor(5, 0).toString());

        editorRule.runOnEditor(editor -> conn.setComposingText("how", 1));
        editorRule.waitForIdle();
        assertEquals("hello", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());

        editorRule.runOnEditor(editor -> conn.commitText("how", 1));
        editorRule.waitForIdle();
        assertEquals("hehowllo", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
    }

    @Test
    public void testSurroundingTextExposesDocumentContext() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return;
        }
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 5));
        });
        InputConnection conn = getInputConnection();

        SurroundingText surroundingText = conn.getSurroundingText(5, 6, 0);

        assertNotNull(surroundingText);
        assertEquals("hello world", surroundingText.getText().toString());
        assertEquals(5, surroundingText.getSelectionStart());
        assertEquals(5, surroundingText.getSelectionEnd());
        assertEquals(0, surroundingText.getOffset());
    }

    @Test
    public void testTakeSnapshotIncludesVisibleCompositionRange() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return;
        }
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 5));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> conn.setComposingRegion(0, 5));
        editorRule.waitForIdle();
        TextSnapshot snapshot = conn.takeSnapshot();

        assertNotNull(snapshot);
        assertEquals(0, snapshot.getCompositionStart());
        assertEquals(5, snapshot.getCompositionEnd());
    }

    @Test
    public void testNonLatinDocumentRangeDoesNotOpenEditorComposition() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 2));
            EditorCore core = getEditorCore(editor);
            core.markImeDocumentRange(
                    new TextRange(new TextPosition(0, 0), new TextPosition(0, 5)),
                    EditorCore.ImeScriptClass.CJK);
        });
        editorRule.waitForIdle();

        assertFalse(isComposing());
        assertEquals("hello", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
    }

    @Test
    public void testReplaceTextImeEventInsertsWithoutComposition() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return;
        }
        editorRule.loadText("value");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(false);
            editor.setCursorPosition(new TextPosition(0, 2));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> conn.replaceText(0, 5, "result", 1, null));
        editorRule.waitForIdle();

        assertEquals("varesultlue", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
    }

    @Test
    public void testMiddleWordEditorCompositionDoesNotReplaceAfterFinish() {
        editorRule.loadText("hello");
        editorRule.runOnEditor(editor -> {
            editor.getSettings().setCompositionEnabled(true);
            editor.setCursorPosition(new TextPosition(0, 2));
        });
        InputConnection conn = getInputConnection();

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(0, 5);
            conn.finishComposingText();
            conn.setComposingText("x", 1);
        });
        editorRule.waitForIdle();

        assertEquals("hexllo", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());

        editorRule.runOnEditor(editor -> {
            conn.setComposingRegion(0, 6);
            conn.setComposingText("xy", 1);
        });
        editorRule.waitForIdle();

        assertEquals("hexyllo", editorRule.runOnEditorSync(editor -> editor.getDocument().getText()));
        assertFalse(isComposing());
    }
}
