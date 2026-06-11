package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.config.AutoIndentMode;
import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.config.FoldArrowMode;
import com.qiplat.sweeteditor.core.config.WhitespaceRenderMode;
import com.qiplat.sweeteditor.core.config.WrapMode;

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
    private WhitespaceRenderMode mRenderWhitespace = WhitespaceRenderMode.NONE;
    private boolean mRenderLineBreaks = false;
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
        EditorActionResult result = mEditor.getEditorCore().setScale(scale);
        mEditor.dispatchEditorActionResult(result);
    }

    public float getScale() {
        return mScale;
    }

    public void setEditorTextSize(float textSize) {
        mEditorTextSize = textSize;
        mEditor.updateFonts(mFontFamily, mEditorTextSize);
    }

    public float getEditorTextSize() {
        return mEditorTextSize;
    }

    public void setFontFamily(String fontFamily) {
        mFontFamily = fontFamily;
        mEditor.updateFonts(mFontFamily, mEditorTextSize);
    }

    public String getFontFamily() {
        return mFontFamily;
    }

    public void setGutterVisible(boolean visible) {
        mGutterVisible = visible;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setGutterVisible(visible));
    }

    public boolean isGutterVisible() {
        return mGutterVisible;
    }

    public void setFoldArrowMode(FoldArrowMode mode) {
        mFoldArrowMode = mode;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setFoldArrowMode(mode.value));
    }

    public FoldArrowMode getFoldArrowMode() {
        return mFoldArrowMode;
    }

    public void setWrapMode(WrapMode mode) {
        mWrapMode = mode;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setWrapMode(mode.value));
    }

    public WrapMode getWrapMode() {
        return mWrapMode;
    }

    public void setRenderWhitespace(WhitespaceRenderMode mode) {
        mRenderWhitespace = mode;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setRenderWhitespace(mode.value));
    }

    public WhitespaceRenderMode getRenderWhitespace() {
        return mRenderWhitespace;
    }

    public void setRenderLineBreaks(boolean enabled) {
        mRenderLineBreaks = enabled;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setRenderLineBreaks(enabled));
    }

    public boolean isRenderLineBreaks() {
        return mRenderLineBreaks;
    }

    public void setLineSpacing(float add, float mult) {
        mLineSpacingAdd = add;
        mLineSpacingMult = mult;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setLineSpacing(add, mult));
    }

    public float getLineSpacingAdd() {
        return mLineSpacingAdd;
    }

    public float getLineSpacingMult() {
        return mLineSpacingMult;
    }

    public void setContentStartPadding(float padding) {
        mContentStartPadding = Math.max(0f, padding);
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setContentStartPadding(mContentStartPadding));
    }

    public float getContentStartPadding() {
        return mContentStartPadding;
    }

    public void setShowSplitLine(boolean show) {
        mShowSplitLine = show;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setShowSplitLine(show));
    }

    public boolean isShowSplitLine() {
        return mShowSplitLine;
    }

    public void setGutterSticky(boolean sticky) {
        mGutterSticky = sticky;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setGutterSticky(sticky));
    }

    public boolean isGutterSticky() {
        return mGutterSticky;
    }

    public void setCurrentLineRenderMode(CurrentLineRenderMode mode) {
        mCurrentLineRenderMode = mode;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setCurrentLineRenderMode(mode.value));
    }

    public CurrentLineRenderMode getCurrentLineRenderMode() {
        return mCurrentLineRenderMode;
    }

    public void setAutoIndentMode(AutoIndentMode mode) {
        mAutoIndentMode = mode;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setAutoIndentMode(mode.value));
    }

    public AutoIndentMode getAutoIndentMode() {
        return mAutoIndentMode;
    }

    public void setBackspaceUnindent(boolean enabled) {
        mBackspaceUnindent = enabled;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setBackspaceUnindent(enabled));
    }

    public boolean isBackspaceUnindent() {
        return mBackspaceUnindent;
    }

    public void setReadOnly(boolean readOnly) {
        mReadOnly = readOnly;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setReadOnly(readOnly));
    }

    public boolean isReadOnly() {
        return mReadOnly;
    }

    public void setMaxGutterIcons(int count) {
        mMaxGutterIcons = count;
        mEditor.dispatchEditorActionResult(mEditor.getEditorCore().setMaxGutterIcons(count));
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
