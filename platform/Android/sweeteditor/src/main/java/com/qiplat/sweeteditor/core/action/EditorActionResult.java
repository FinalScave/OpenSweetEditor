package com.qiplat.sweeteditor.core.action;

import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.interaction.EventType;
import com.qiplat.sweeteditor.core.interaction.GestureType;
import com.qiplat.sweeteditor.core.interaction.HitTarget;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.visual.PointerCursorType;
import java.util.List;

public final class EditorActionResult {
    public boolean handled = false;
    public boolean needsRedraw = false;
    public EditorActionSource source = EditorActionSource.NONE;
    public TextChangeKind textChangeKind = TextChangeKind.NONE;
    public boolean contentChanged = false;
    public boolean cursorChanged = false;
    public boolean selectionChanged = false;
    public boolean scrollChanged = false;
    public boolean scaleChanged = false;
    public boolean pointerCursorChanged = false;
    public boolean compositionChanged = false;
    public boolean decorationChanged = false;
    public boolean needsImeSync = false;
    public boolean needsEdgeScroll = false;
    public boolean needsFling = false;
    public boolean needsAnimation = false;
    public boolean isHandleDrag = false;
    public java.util.List<TextChange> changes = new java.util.ArrayList<>();
    public TextPosition cursorBefore = new TextPosition();
    public TextPosition cursorAfter = new TextPosition();
    public boolean hasSelectionBefore = false;
    public boolean hasSelectionAfter = false;
    public TextRange selectionBefore = new TextRange();
    public TextRange selectionAfter = new TextRange();
    public float scrollXBefore = 0f;
    public float scrollYBefore = 0f;
    public float scrollXAfter = 0f;
    public float scrollYAfter = 0f;
    public float scaleBefore = 1f;
    public float scaleAfter = 1f;
    public PointerCursorType pointerCursorBefore = PointerCursorType.TEXT;
    public PointerCursorType pointerCursorAfter = PointerCursorType.TEXT;
    public ImeSyncSnapshot imeSync = new ImeSyncSnapshot();
    public GestureType gestureType = GestureType.UNDEFINED;
    public EventType gestureEventType = EventType.UNDEFINED;
    public PointF tapPoint = new PointF();
    public HitTarget hitTarget = new HitTarget();
    public int modifiers = KeyModifier.NONE;
    public int command = 0;

    public EditorActionResult() {
    }

    public EditorActionResult(boolean handled, boolean needsRedraw, EditorActionSource source, TextChangeKind textChangeKind, boolean contentChanged, boolean cursorChanged, boolean selectionChanged, boolean scrollChanged, boolean scaleChanged, boolean pointerCursorChanged, boolean compositionChanged, boolean decorationChanged, boolean needsImeSync, boolean needsEdgeScroll, boolean needsFling, boolean needsAnimation, boolean isHandleDrag, java.util.List<TextChange> changes, TextPosition cursorBefore, TextPosition cursorAfter, boolean hasSelectionBefore, boolean hasSelectionAfter, TextRange selectionBefore, TextRange selectionAfter, float scrollXBefore, float scrollYBefore, float scrollXAfter, float scrollYAfter, float scaleBefore, float scaleAfter, PointerCursorType pointerCursorBefore, PointerCursorType pointerCursorAfter, ImeSyncSnapshot imeSync, GestureType gestureType, EventType gestureEventType, PointF tapPoint, HitTarget hitTarget, int modifiers, int command) {
        this.handled = handled;
        this.needsRedraw = needsRedraw;
        this.source = source;
        this.textChangeKind = textChangeKind;
        this.contentChanged = contentChanged;
        this.cursorChanged = cursorChanged;
        this.selectionChanged = selectionChanged;
        this.scrollChanged = scrollChanged;
        this.scaleChanged = scaleChanged;
        this.pointerCursorChanged = pointerCursorChanged;
        this.compositionChanged = compositionChanged;
        this.decorationChanged = decorationChanged;
        this.needsImeSync = needsImeSync;
        this.needsEdgeScroll = needsEdgeScroll;
        this.needsFling = needsFling;
        this.needsAnimation = needsAnimation;
        this.isHandleDrag = isHandleDrag;
        this.changes = changes;
        this.cursorBefore = cursorBefore;
        this.cursorAfter = cursorAfter;
        this.hasSelectionBefore = hasSelectionBefore;
        this.hasSelectionAfter = hasSelectionAfter;
        this.selectionBefore = selectionBefore;
        this.selectionAfter = selectionAfter;
        this.scrollXBefore = scrollXBefore;
        this.scrollYBefore = scrollYBefore;
        this.scrollXAfter = scrollXAfter;
        this.scrollYAfter = scrollYAfter;
        this.scaleBefore = scaleBefore;
        this.scaleAfter = scaleAfter;
        this.pointerCursorBefore = pointerCursorBefore;
        this.pointerCursorAfter = pointerCursorAfter;
        this.imeSync = imeSync;
        this.gestureType = gestureType;
        this.gestureEventType = gestureEventType;
        this.tapPoint = tapPoint;
        this.hitTarget = hitTarget;
        this.modifiers = modifiers;
        this.command = command;
    }
}
