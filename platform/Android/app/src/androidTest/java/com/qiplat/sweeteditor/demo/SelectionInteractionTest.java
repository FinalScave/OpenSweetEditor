package com.qiplat.sweeteditor.demo;

import android.os.SystemClock;
import android.util.SparseArray;
import android.view.MotionEvent;

import androidx.annotation.NonNull;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.decoration.DecorationContext;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationReceiver;
import com.qiplat.sweeteditor.decoration.DecorationResult;
import com.qiplat.sweeteditor.decoration.DecorationType;

import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.EnumSet;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class SelectionInteractionTest {

    @Rule
    public EditorTestRule editorRule = new EditorTestRule();

    private String generateLongContent(int lines) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines; i++) {
            sb.append("line ").append(i).append(": some content that fills the editor viewport\n");
        }
        return sb.toString();
    }

    @Test
    public void testSetSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.setSelection(0, 0, 0, 5));
        TextRange sel = editorRule.runOnEditorSync(editor -> editor.getSelection());
        assertNotNull(sel);
        assertEquals(0, sel.start.line);
        assertEquals(0, sel.start.column);
        assertEquals(0, sel.end.line);
        assertEquals(5, sel.end.column);
    }

    @Test
    public void testSetSelectionWithRange() {
        editorRule.loadText("hello world");
        TextRange range = new TextRange(new TextPosition(0, 6), new TextPosition(0, 11));
        editorRule.runOnEditor(editor -> editor.setSelection(range));
        TextRange sel = editorRule.runOnEditorSync(editor -> editor.getSelection());
        assertNotNull(sel);
        assertEquals(0, sel.start.column);
        // Selection should cover "world"
    }

    @Test
    public void testHasSelection() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.setSelection(0, 0, 0, 5));
        boolean has = editorRule.runOnEditorSync(editor -> editor.hasSelection());
        assertTrue(has);
    }

    @Test
    public void testSelectAll() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.selectAll());
        String selected = editorRule.runOnEditorSync(editor -> editor.getSelectedText());
        assertEquals("hello world", selected);
    }

    @Test
    public void testGetSelectedText() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.setSelection(0, 0, 0, 5));
        String selected = editorRule.runOnEditorSync(editor -> editor.getSelectedText());
        assertEquals("hello", selected);
    }

    @Test
    public void testGetSelectedTextMultiLine() {
        editorRule.loadText("hello\nworld");
        editorRule.runOnEditor(editor -> editor.setSelection(0, 0, 1, 5));
        String selected = editorRule.runOnEditorSync(editor -> editor.getSelectedText());
        assertEquals("hello\nworld", selected);
    }

    @Test
    public void testDoubleTapSelectsWord() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> {
            int cx = editor.getWidth() / 4;
            int cy = 30;
            long downTime = SystemClock.uptimeMillis();
            // First tap
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, cx, cy, 0));
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime, downTime + 30, MotionEvent.ACTION_UP, cx, cy, 0));
            // Second tap (double-tap)
            long downTime2 = downTime + 100;
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime2, downTime2, MotionEvent.ACTION_DOWN, cx, cy, 0));
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime2, downTime2 + 30, MotionEvent.ACTION_UP, cx, cy, 0));
        });
        editorRule.waitForIdle();
        boolean has = editorRule.runOnEditorSync(editor -> editor.hasSelection());
        assertTrue("Double-tap should create a selection", has);
    }

    @Test
    public void testClearSelectionOnTap() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.selectAll());
        assertTrue(editorRule.runOnEditorSync(editor -> editor.hasSelection()));
        editorRule.runOnEditor(editor -> {
            int cx = editor.getWidth() / 2;
            int cy = 30;
            long downTime = SystemClock.uptimeMillis();
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, cx, cy, 0));
            editor.dispatchTouchEvent(MotionEvent.obtain(downTime, downTime + 50, MotionEvent.ACTION_UP, cx, cy, 0));
        });
        editorRule.waitForIdle();
        boolean has = editorRule.runOnEditorSync(editor -> editor.hasSelection());
        assertFalse("Tap should clear selection", has);
    }

    @Test
    public void testSelectionAfterCursorMove() {
        editorRule.loadText("hello world");
        editorRule.runOnEditor(editor -> editor.setSelection(0, 0, 0, 5));
        editorRule.runOnEditor(editor -> editor.setCursorPosition(new TextPosition(0, 0)));
        boolean has = editorRule.runOnEditorSync(editor -> editor.hasSelection());
        assertFalse("Setting cursor should clear selection", has);
    }

    @Test
    public void testDragSelectScrollRefreshesDecorationProviders() {
        AtomicInteger refreshCount = new AtomicInteger();
        DecorationProvider provider = new DecorationProvider() {
            @NonNull
            @Override
            public EnumSet<DecorationType> getCapabilities() {
                return EnumSet.of(DecorationType.SYNTAX_HIGHLIGHT);
            }

            @Override
            public void provideDecorations(@NonNull DecorationContext context, @NonNull DecorationReceiver receiver) {
                refreshCount.incrementAndGet();
                receiver.accept(new DecorationResult.Builder()
                        .syntaxSpans(new SparseArray<>(), DecorationResult.ApplyMode.REPLACE_RANGE)
                        .build());
            }
        };

        editorRule.loadText(generateLongContent(200));
        editorRule.runOnEditor(editor -> editor.addDecorationProvider(provider));
        editorRule.waitForIdle();
        refreshCount.set(0);

        editorRule.runOnEditor(editor -> {
            try {
                Field cachedModelField = editor.getClass().getDeclaredField("mCachedModel");
                cachedModelField.setAccessible(true);
                cachedModelField.set(editor, null);
                editor.getVisibleLineRange();

                EditorRenderModel cachedModel = new EditorRenderModel();
                cachedModel.scrollX = 0f;
                cachedModel.scrollY = 0f;
                cachedModelField.set(editor, cachedModel);

                Method fireGestureEvents = editor.getClass().getDeclaredMethod(
                        "fireGestureEvents",
                        EditorCore.EditorActionResult.class,
                        android.graphics.PointF.class,
                        int.class);
                fireGestureEvents.setAccessible(true);
                EditorCore.EditorActionResult result = new EditorCore.EditorActionResult(
                        true,
                        true,
                        0,
                        false,
                        true,
                        true,
                        true,
                        false,
                        false,
                        false,
                        false,
                        false,
                        false,
                        false,
                        true,
                        false,
                        java.util.Collections.emptyList(),
                        TextPosition.NONE,
                        new TextPosition(20, 0),
                        false,
                        new TextRange(),
                        true,
                        new TextRange(new TextPosition(0, 0), new TextPosition(20, 0)),
                        0f,
                        0f,
                        0f,
                        240f,
                        1f,
                        1f,
                        0,
                        0,
                        new EditorCore.ImeSyncSnapshot(),
                        EditorCore.GestureType.DRAG_SELECT,
                        EditorCore.EVENT_TYPE_TOUCH_MOVE,
                        new android.graphics.PointF(10f, 10f),
                        EditorCore.HitTarget.NONE,
                        0,
                        0);
                fireGestureEvents.invoke(editor, result, null, -1);
            } catch (ReflectiveOperationException e) {
                throw new AssertionError(e);
            }
        });
        editorRule.waitForIdle();

        assertTrue("Drag-select scrolling should trigger decoration refresh", refreshCount.get() > 0);
    }
}
