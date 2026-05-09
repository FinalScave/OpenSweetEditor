package com.qiplat.sweeteditor;

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

    private float mScale = 1.0f;
    private float mEditorTextSize = 14f;
    private String mFontFamily = "monospace";
    private boolean mGutterVisible = true;
    private FoldArrowMode mFoldArrowMode = FoldArrowMode.ALWAYS;
    private WrapMode mWrapMode = WrapMode.NONE;
    private float mLineSpacingAdd = 0f;
    private float mLineSpacingMult = 1.0f;
    private float mContentStartPadding = 0f;
    private boolean mShowSplitLine = true;
    private boolean mGutterSticky = true;
    private CurrentLineRenderMode mCurrentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
    private AutoIndentMode mAutoIndentMode = AutoIndentMode.KEEP_INDENT;
    private boolean mBackspaceUnindent = true;
    private boolean mReadOnly = false;
    private int mMaxGutterIcons = 0;
    private int mDecorationScrollRefreshMinIntervalMs = 16;
    private float mDecorationOverscanViewportMultiplier = 1.5f;
    private boolean mCursorAnimationEnabled = true;
    private boolean mGutterAnimationEnabled = true;

    EditorSettings(SweetEditor editor) {
        mEditor = editor;
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

    public void setEditorTextSize(float textSize) {
        mEditorTextSize = textSize;
        mEditor.updateFonts(mFontFamily, mEditorTextSize);
        mEditor.flush();
    }

    public float getEditorTextSize() {
        return mEditorTextSize;
    }

    public void setFontFamily(String fontFamily) {
        mFontFamily = fontFamily;
        mEditor.updateFonts(mFontFamily, mEditorTextSize);
        mEditor.flush();
    }

    public String getFontFamily() {
        return mFontFamily;
    }

    public void setGutterVisible(boolean visible) {
        mGutterVisible = visible;
        mEditor.getEditorCore().setGutterVisible(visible);
        mEditor.flush();
    }

    public boolean isGutterVisible() {
        return mGutterVisible;
    }

    public void setFoldArrowMode(FoldArrowMode mode) {
        mFoldArrowMode = mode;
        mEditor.getEditorCore().setFoldArrowMode(mode.value);
        mEditor.flush();
    }

    public FoldArrowMode getFoldArrowMode() {
        return mFoldArrowMode;
    }

    public void setWrapMode(WrapMode mode) {
        mWrapMode = mode;
        mEditor.getEditorCore().setWrapMode(mode.value);
        mEditor.flush();
    }

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

    public void setCurrentLineRenderMode(CurrentLineRenderMode mode) {
        mCurrentLineRenderMode = mode;
        mEditor.getEditorCore().setCurrentLineRenderMode(mode.value);
        mEditor.flush();
    }

    public CurrentLineRenderMode getCurrentLineRenderMode() {
        return mCurrentLineRenderMode;
    }

    public void setAutoIndentMode(AutoIndentMode mode) {
        mAutoIndentMode = mode;
        mEditor.getEditorCore().setAutoIndentMode(mode.value);
    }

    public AutoIndentMode getAutoIndentMode() {
        return mAutoIndentMode;
    }

    public void setBackspaceUnindent(boolean enabled) {
        mBackspaceUnindent = enabled;
        mEditor.getEditorCore().setBackspaceUnindent(enabled);
    }

    public boolean isBackspaceUnindent() {
        return mBackspaceUnindent;
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
        mEditor.flush();
    }

    public int getMaxGutterIcons() {
        return mMaxGutterIcons;
    }

    public void setDecorationScrollRefreshMinIntervalMs(int intervalMs) {
        mDecorationScrollRefreshMinIntervalMs = Math.max(0, intervalMs);
        mEditor.requestDecorationRefresh();
    }

    public int getDecorationScrollRefreshMinIntervalMs() {
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

    public void setGutterAnimationEnabled(boolean enabled) {
        mGutterAnimationEnabled = enabled;
        mEditor.requestGutterAnimationRefresh();
    }

    public boolean isGutterAnimationEnabled() {
        return mGutterAnimationEnabled;
    }

}
