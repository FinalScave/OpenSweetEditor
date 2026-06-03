package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.foundation.PointF;
import java.util.List;

public final class EditorRenderModel {
    public float splitX = 0f;
    public boolean splitLineVisible = true;
    public float scrollX = 0f;
    public float scrollY = 0f;
    public float viewportWidth = 0f;
    public float viewportHeight = 0f;
    public PointF currentLine = new PointF();
    public CurrentLineRenderMode currentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
    public java.util.List<VisualLine> lines = new java.util.ArrayList<>();
    public Cursor cursor = new Cursor();
    public java.util.List<RangeEffectRenderItem> rangeEffects = new java.util.ArrayList<>();
    public SelectionHandle selectionStartHandle = new SelectionHandle();
    public SelectionHandle selectionEndHandle = new SelectionHandle();
    public java.util.List<GuideSegment> guideSegments = new java.util.ArrayList<>();
    public int maxGutterIcons = 0;
    public java.util.List<GutterIconRenderItem> gutterIcons = new java.util.ArrayList<>();
    public java.util.List<FoldMarkerRenderItem> foldMarkers = new java.util.ArrayList<>();
    public ScrollbarModel verticalScrollbar = new ScrollbarModel();
    public ScrollbarModel horizontalScrollbar = new ScrollbarModel();
    public boolean gutterSticky = true;
    public boolean gutterVisible = true;
    public PointerCursorType pointerCursorType = PointerCursorType.TEXT;

    public EditorRenderModel() {
    }

    public EditorRenderModel(float splitX, boolean splitLineVisible, float scrollX, float scrollY, float viewportWidth, float viewportHeight, PointF currentLine, CurrentLineRenderMode currentLineRenderMode, java.util.List<VisualLine> lines, Cursor cursor, java.util.List<RangeEffectRenderItem> rangeEffects, SelectionHandle selectionStartHandle, SelectionHandle selectionEndHandle, java.util.List<GuideSegment> guideSegments, int maxGutterIcons, java.util.List<GutterIconRenderItem> gutterIcons, java.util.List<FoldMarkerRenderItem> foldMarkers, ScrollbarModel verticalScrollbar, ScrollbarModel horizontalScrollbar, boolean gutterSticky, boolean gutterVisible, PointerCursorType pointerCursorType) {
        this.splitX = splitX;
        this.splitLineVisible = splitLineVisible;
        this.scrollX = scrollX;
        this.scrollY = scrollY;
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
        this.currentLine = currentLine;
        this.currentLineRenderMode = currentLineRenderMode;
        this.lines = lines;
        this.cursor = cursor;
        this.rangeEffects = rangeEffects;
        this.selectionStartHandle = selectionStartHandle;
        this.selectionEndHandle = selectionEndHandle;
        this.guideSegments = guideSegments;
        this.maxGutterIcons = maxGutterIcons;
        this.gutterIcons = gutterIcons;
        this.foldMarkers = foldMarkers;
        this.verticalScrollbar = verticalScrollbar;
        this.horizontalScrollbar = horizontalScrollbar;
        this.gutterSticky = gutterSticky;
        this.gutterVisible = gutterVisible;
        this.pointerCursorType = pointerCursorType;
    }
}
