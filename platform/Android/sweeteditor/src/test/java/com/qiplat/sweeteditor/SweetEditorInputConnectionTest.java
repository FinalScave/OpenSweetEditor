package com.qiplat.sweeteditor;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class SweetEditorInputConnectionTest {
    @Test
    public void positiveCursorPositionIsRelativeToReplacementEnd() {
        assertEquals(5, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, 1, 10));
        assertEquals(6, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, 2, 10));
    }

    @Test
    public void nonPositiveCursorPositionIsRelativeToReplacementStart() {
        assertEquals(2, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, 0, 10));
        assertEquals(1, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, -1, 10));
    }

    @Test
    public void cursorPositionIsClampedToResultingText() {
        assertEquals(0, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, -10, 10));
        assertEquals(11, SweetEditorInputConnection.cursorAfterReplacement(2, 4, 3, 100, 10));
    }
}
