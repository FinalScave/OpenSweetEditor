package com.qiplat.sweeteditor;

import android.graphics.Typeface;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.foundation.AutoIndentMode;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.WrapMode;

/**
 * Centralized configuration for {@link SweetEditor}.
 * <p>
 * Obtain via {@link SweetEditor#getSettings()}. All setters take effect immediately.
 */
public class EditorSettings {

    private final SweetEditor mEditor;

    private float mTextSize = 36f;
    private Typeface mTypeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL);
    private float mScale = 1.0f;
    private FoldArrowMode mFoldArrowMode = FoldArrowMode.ALWAYS;
    private WrapMode mWrapMode = WrapMode.NONE;
    private float mLineSpacingAdd = 0f;
    private float mLineSpacingMult = 1.0f;
    private float mContentStartPadding = 0f;
    private boolean mShowSplitLine = true;
    private boolean mGutterSticky = true;
    private boolean mGutterVisible = true;
    private CurrentLineRenderMode mCurrentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
    private AutoIndentMode mAutoIndentMode = AutoIndentMode.NONE;
    private boolean mReadOnly = false;
    private int mMaxGutterIcons = 0;
    private long mDecorationScrollRefreshMinIntervalMs = 16L;
    private float mDecorationOverscanViewportMultiplier = 1.5f;

    EditorSettings(@NonNull SweetEditor editor) {
        mEditor = editor;
    }

    public void setEditorTextSize(float textSize) {
        mTextSize = textSize;
        mEditor.applyTextSize(textSize);
    }

    public float getEditorTextSize() {
        return mTextSize;
    }

    public void setTypeface(@NonNull Typeface typeface) {
        mTypeface = typeface;
        mEditor.applyTypeface(typeface);
    }

    @NonNull
    public Typeface getTypeface() {
        return mTypeface;
    }

    public void setScale(float scale) {
        mScale = scale;
        mEditor.getEditorCore().setScale(scale);
        mEditor.syncPlatformScale(scale);
        mEditor.flush();
    }

    public float getScale() {
        return mScale;
    }

    public void setFoldArrowMode(@NonNull FoldArrowMode mode) {
        mFoldArrowMode = mode;
        mEditor.getEditorCore().setFoldArrowMode(mode.value);
    }

    @NonNull
    public FoldArrowMode getFoldArrowMode() {
        return mFoldArrowMode;
    }

    public void setWrapMode(@NonNull WrapMode mode) {
        mWrapMode = mode;
        mEditor.getEditorCore().setWrapMode(mode.value);
        mEditor.flush();
    }

    @NonNull
    public WrapMode getWrapMode() {
        return mWrapMode;
    }

    public void setLineSpacing(float add, float mult) {
        mLineSpacingAdd = add;
        mLineSpacingMult = mult;
        mEditor.getEditorCore().setLineSpacing(add, mult);
        mEditor.flush();
    }

    public float getLineSpacingAdd() {
        return mLineSpacingAdd;
    }

    public float getLineSpacingMult() {
        return mLineSpacingMult;
    }

    public void setContentStartPadding(float padding) {
        mContentStartPadding = Math.max(0f, padding);
        mEditor.getEditorCore().setContentStartPadding(mContentStartPadding);
        mEditor.flush();
    }

    public float getContentStartPadding() {
        return mContentStartPadding;
    }

    public void setShowSplitLine(boolean show) {
        mShowSplitLine = show;
        mEditor.getEditorCore().setShowSplitLine(show);
        mEditor.flush();
    }

    public boolean isShowSplitLine() {
        return mShowSplitLine;
    }

    public void setGutterSticky(boolean sticky) {
        mGutterSticky = sticky;
        mEditor.getEditorCore().setGutterSticky(sticky);
        mEditor.flush();
    }

    public boolean isGutterSticky() {
        return mGutterSticky;
    }

    public void setGutterVisible(boolean visible) {
        mGutterVisible = visible;
        mEditor.getEditorCore().setGutterVisible(visible);
        mEditor.flush();
    }

    public boolean isGutterVisible() {
        return mGutterVisible;
    }

    public void setCurrentLineRenderMode(@NonNull CurrentLineRenderMode mode) {
        mCurrentLineRenderMode = mode;
        mEditor.getEditorCore().setCurrentLineRenderMode(mode.value);
        mEditor.flush();
    }

    @NonNull
    public CurrentLineRenderMode getCurrentLineRenderMode() {
        return mCurrentLineRenderMode;
    }

    public void setAutoIndentMode(@NonNull AutoIndentMode mode) {
        mAutoIndentMode = mode;
        mEditor.getEditorCore().setAutoIndentMode(mode.value);
    }

    @NonNull
    public AutoIndentMode getAutoIndentMode() {
        return mAutoIndentMode;
    }

    public void setReadOnly(boolean readOnly) {
        mReadOnly = readOnly;
        mEditor.getEditorCore().setReadOnly(readOnly);
    }

    public boolean isReadOnly() {
        return mReadOnly;
    }

    public void setMaxGutterIcons(int count) {
        mMaxGutterIcons = count;
        mEditor.getEditorCore().setMaxGutterIcons(count);
    }

    public int getMaxGutterIcons() {
        return mMaxGutterIcons;
    }

    public void setDecorationScrollRefreshMinIntervalMs(long intervalMs) {
        mDecorationScrollRefreshMinIntervalMs = Math.max(0L, intervalMs);
        mEditor.requestDecorationRefresh();
    }

    public long getDecorationScrollRefreshMinIntervalMs() {
        return mDecorationScrollRefreshMinIntervalMs;
    }

    public void setDecorationOverscanViewportMultiplier(float multiplier) {
        mDecorationOverscanViewportMultiplier = Math.max(0f, multiplier);
        mEditor.requestDecorationRefresh();
    }

    public float getDecorationOverscanViewportMultiplier() {
        return mDecorationOverscanViewportMultiplier;
    }
}
