package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.util.Arrays;
import java.util.Collections;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class FoldingInteractionTest {

    @Rule
    public EditorTestRule editorRule = new EditorTestRule();

    private String generateLines(int count) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++) {
            sb.append("line ").append(i).append("\n");
        }
        return sb.toString();
    }

    @Test
    public void testSetFoldRegions() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor ->
                editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8))));
        // Should not crash
    }

    @Test
    public void testToggleFoldAt() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor ->
                editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8))));
        editorRule.runOnEditor(editor -> editor.toggleFoldAt(2));
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertFalse("toggleFoldAt should fold a valid fold region", line5Visible);
    }

    @Test
    public void testFoldHidesLines() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8)));
            editor.toggleFoldAt(2);
        });
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertFalse("Line 5 should be hidden after folding region 2-8", line5Visible);
    }

    @Test
    public void testFoldStartLineStaysVisible() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8)));
            editor.toggleFoldAt(2);
        });
        boolean line2Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(2));
        assertTrue("Fold start line should remain visible", line2Visible);
    }

    @Test
    public void testUnfoldRestoresVisibility() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8)));
            editor.toggleFoldAt(2);
            editor.toggleFoldAt(2);
        });
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertTrue("Line 5 should be visible after unfolding", line5Visible);
    }

    @Test
    public void testFoldAll() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Arrays.asList(
                    new FoldRegion(2, 5),
                    new FoldRegion(10, 15)));
            editor.foldAll();
        });
        boolean line3Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(3));
        boolean line12Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(12));
        assertFalse("Line 3 should be hidden after foldAll", line3Visible);
        assertFalse("Line 12 should be hidden after foldAll", line12Visible);
    }

    @Test
    public void testUnfoldAll() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Arrays.asList(
                    new FoldRegion(2, 5),
                    new FoldRegion(10, 15)));
            editor.foldAll();
            editor.unfoldAll();
        });
        boolean line3Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(3));
        boolean line12Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(12));
        assertTrue("Line 3 should be visible after unfoldAll", line3Visible);
        assertTrue("Line 12 should be visible after unfoldAll", line12Visible);
    }

    @Test
    public void testFoldReducesContentHeight() {
        editorRule.loadText(generateLines(100));
        ScrollMetrics before = editorRule.runOnEditorSync(editor -> editor.getScrollMetrics());
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(10, 50)));
            editor.foldAll();
        });
        ScrollMetrics after = editorRule.runOnEditorSync(editor -> editor.getScrollMetrics());
        assertTrue("Content height should decrease after folding",
                after.contentHeight < before.contentHeight);
    }

    @Test
    public void testFoldAtSpecificLine() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8)));
            editor.foldAt(2);
        });
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertFalse("Line 5 should be hidden after foldAt", line5Visible);
    }

    @Test
    public void testUnfoldAtSpecificLine() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8)));
            editor.foldAt(2);
            editor.unfoldAt(2);
        });
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertTrue("Line 5 should be visible after unfoldAt", line5Visible);
    }

    @Test
    public void testToggleFoldAtInvalidLine() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor ->
                editor.setFoldRegions(Collections.singletonList(new FoldRegion(2, 8))));
        editorRule.runOnEditor(editor -> editor.toggleFoldAt(0));
        boolean line5Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(5));
        assertTrue("toggleFoldAt on non-fold line should leave fold region visible", line5Visible);
    }

    @Test
    public void testLinesOutsideFoldRemainVisible() {
        editorRule.loadText(generateLines(20));
        editorRule.runOnEditor(editor -> {
            editor.setFoldRegions(Collections.singletonList(new FoldRegion(5, 10)));
            editor.foldAt(5);
        });
        boolean line0Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(0));
        boolean line15Visible = editorRule.runOnEditorSync(editor -> editor.isLineVisible(15));
        assertTrue("Line 0 should remain visible", line0Visible);
        assertTrue("Line 15 should remain visible", line15Visible);
    }
}
