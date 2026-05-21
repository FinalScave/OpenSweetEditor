package com.qiplat.sweeteditor;

import android.graphics.Typeface;

import androidx.annotation.NonNull;
import androidx.annotation.MainThread;

import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.AutoIndentMode;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.WrapMode;

/**
 * Centralized configuration for {@link SweetEditor}.
 * <p>
 * Obtain via {@link SweetEditor#getSettings()}. All setters take effect immediately.
 * Public APIs on this class are main-thread only.
 */
@MainThread
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
    private boolean mGutterSticky = false;
    private boolean mGutterVisible = true;
    private CurrentLineRenderMode mCurrentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
    private AutoIndentMode mAutoIndentMode = AutoIndentMode.KEEP_INDENT;
    private boolean mBackspaceUnindent = true;
    private boolean mReadOnly = false;
    private int mMaxGutterIcons = 0;
    private long mDecorationScrollRefreshMinIntervalMs = 16L;
    private float mDecorationOverscanViewportMultiplier = 1.5f;
    private boolean mCursorAnimationEnabled = true;

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
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setScale(scale);
        mEditor.dispatchEditorActionResult(result);
    }

    public float getScale() {
        return mScale;
    }

    public void setFoldArrowMode(@NonNull FoldArrowMode mode) {
        mFoldArrowMode = mode;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setFoldArrowMode(mode.value);
        mEditor.dispatchEditorActionResult(result);
    }

    @NonNull
    public FoldArrowMode getFoldArrowMode() {
        return mFoldArrowMode;
    }

    public void setWrapMode(@NonNull WrapMode mode) {
        mWrapMode = mode;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setWrapMode(mode.value);
        mEditor.dispatchEditorActionResult(result);
    }

    @NonNull
    public WrapMode getWrapMode() {
        return mWrapMode;
    }

    public void setLineSpacing(float add, float mult) {
        mLineSpacingAdd = add;
        mLineSpacingMult = mult;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setLineSpacing(add, mult);
        mEditor.dispatchEditorActionResult(result);
    }

    public float getLineSpacingAdd() {
        return mLineSpacingAdd;
    }

    public float getLineSpacingMult() {
        return mLineSpacingMult;
    }

    public void setContentStartPadding(float padding) {
        mContentStartPadding = Math.max(0f, padding);
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setContentStartPadding(mContentStartPadding);
        mEditor.dispatchEditorActionResult(result);
    }

    public float getContentStartPadding() {
        return mContentStartPadding;
    }

    public void setShowSplitLine(boolean show) {
        mShowSplitLine = show;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setShowSplitLine(show);
        mEditor.dispatchEditorActionResult(result);
    }

    public boolean isShowSplitLine() {
        return mShowSplitLine;
    }

    public void setGutterSticky(boolean sticky) {
        mGutterSticky = sticky;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setGutterSticky(sticky);
        mEditor.dispatchEditorActionResult(result);
    }

    public boolean isGutterSticky() {
        return mGutterSticky;
    }

    public void setGutterVisible(boolean visible) {
        mGutterVisible = visible;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setGutterVisible(visible);
        mEditor.dispatchEditorActionResult(result);
    }

    public boolean isGutterVisible() {
        return mGutterVisible;
    }

    public void setCurrentLineRenderMode(@NonNull CurrentLineRenderMode mode) {
        mCurrentLineRenderMode = mode;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setCurrentLineRenderMode(mode.value);
        mEditor.dispatchEditorActionResult(result);
    }

    @NonNull
    public CurrentLineRenderMode getCurrentLineRenderMode() {
        return mCurrentLineRenderMode;
    }

    public void setAutoIndentMode(@NonNull AutoIndentMode mode) {
        mAutoIndentMode = mode;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setAutoIndentMode(mode.value);
        mEditor.dispatchEditorActionResult(result);
    }

    @NonNull
    public AutoIndentMode getAutoIndentMode() {
        return mAutoIndentMode;
    }

    public void setBackspaceUnindent(boolean enabled) {
        mBackspaceUnindent = enabled;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setBackspaceUnindent(enabled);
        mEditor.dispatchEditorActionResult(result);
    }

    public boolean isBackspaceUnindent() {
        return mBackspaceUnindent;
    }

    public void setReadOnly(boolean readOnly) {
        mReadOnly = readOnly;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setReadOnly(readOnly);
        mEditor.dispatchEditorActionResult(result);
    }

    public boolean isReadOnly() {
        return mReadOnly;
    }

    public void setMaxGutterIcons(int count) {
        mMaxGutterIcons = count;
        EditorCore.EditorActionResult result = mEditor.getEditorCore().setMaxGutterIcons(count);
        mEditor.dispatchEditorActionResult(result);
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

    public void setCursorAnimationEnabled(boolean enabled) {
        mCursorAnimationEnabled = enabled;
        mEditor.requestCursorAnimationRefresh();
    }

    public boolean isCursorAnimationEnabled() {
        return mCursorAnimationEnabled;
    }

}
