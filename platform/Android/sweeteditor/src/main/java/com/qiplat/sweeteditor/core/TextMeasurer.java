package com.qiplat.sweeteditor.core;

import android.graphics.Paint;
import android.graphics.Typeface;

import com.qiplat.sweeteditor.core.visual.FontStyle;
import com.qiplat.sweeteditor.perf.MeasurePerfStats;

/**
 * Text measurer, responsible for measuring the width of the editor's main font and InlayHint font.
 * <p>
 * Holds a reference to externally created {@link Paint} to ensure measurement and drawing use the same font configuration.
 */
public class TextMeasurer {
    private final Paint mTextPaint;
    private final Paint mInlayHintPaint;
    private Typeface mBaseTypeface;
    private float mTextSize = 12;
    private float mScale = 1;
    /** Icon width query callback, set externally via setIconWidthProvider */
    private IconWidthProvider mIconWidthProvider;
    /** Per-frame measurement performance stats (optional), set by SweetEditor before onDraw */
    private MeasurePerfStats mPerfStats;

    /** Icon width query interface */
    public interface IconWidthProvider {
        float getIconWidth(int iconId);
    }

    /**
     * @param textPaint       Main text Paint (externally created, TextMeasurer holds reference)
     * @param inlayHintPaint InlayHint-specific Paint (externally created, TextMeasurer holds reference)
     */
    public TextMeasurer(Paint textPaint, Paint inlayHintPaint) {
        this.mTextPaint = textPaint;
        this.mInlayHintPaint = inlayHintPaint;
        this.mBaseTypeface = textPaint.getTypeface();
        if (this.mBaseTypeface == null) {
            this.mBaseTypeface = Typeface.DEFAULT;
        }
        float initialTextSize = textPaint.getTextSize();
        if (initialTextSize > 0f) {
            this.mTextSize = initialTextSize;
        }
    }

    /** Set per-frame measurement performance stats collector (null to disable) */
    public void setPerfStats(MeasurePerfStats perfStats) {
        mPerfStats = perfStats;
    }

    public void setTypeface(Typeface typeface) {
        mBaseTypeface = typeface;
        mTextPaint.setTypeface(typeface);
    }

    public void setTextSize(float textSize) {
        mTextSize = textSize;
        mTextPaint.setTextSize(mTextSize * mScale);
    }

    public void setScale(float scale) {
        mScale = scale;
        mTextPaint.setTextSize(mTextSize * mScale);
    }

    /** Set icon width query callback */
    public void setIconWidthProvider(IconWidthProvider provider) {
        mIconWidthProvider = provider;
    }

    /**
     * Measure editor main font text width.
     *
     * @param text      text content
     * @param fontStyle font style bit flags (BOLD=1, ITALIC=2, STRIKETHROUGH=4, combinable via bitwise OR)
     * @return measured width (pixels)
     */
    float measureWidth(String text, int fontStyle) {
        long t0 = mPerfStats != null ? System.nanoTime() : 0;

        boolean isBold = (fontStyle & FontStyle.BOLD) != 0;
        boolean isItalic = (fontStyle & FontStyle.ITALIC) != 0;
        boolean isStrikethrough = (fontStyle & FontStyle.STRIKETHROUGH) != 0;

        // Select Typeface style based on bit flags
        int typefaceStyle = Typeface.NORMAL;
        if (isBold && isItalic) {
            typefaceStyle = Typeface.BOLD_ITALIC;
        } else if (isBold) {
            typefaceStyle = Typeface.BOLD;
        } else if (isItalic) {
            typefaceStyle = Typeface.ITALIC;
        }

        Typeface targetTypeface = Typeface.create(mBaseTypeface, typefaceStyle);
        mTextPaint.setTypeface(targetTypeface);
        mTextPaint.setStrikeThruText(isStrikethrough);

        float width = mTextPaint.measureText(text);

        // Restore default style
        mTextPaint.setTypeface(mBaseTypeface);
        mTextPaint.setStrikeThruText(false);

        if (mPerfStats != null) {
            mPerfStats.recordText(System.nanoTime() - t0, text.length(), fontStyle);
        }
        return width;
    }

    /**
     * Measure InlayHint text width (using InlayHint's dedicated font).
     *
     * @param text InlayHint text content
     * @return measured width (pixels)
     */
    float measureInlayHintWidth(String text) {
        long t0 = mPerfStats != null ? System.nanoTime() : 0;
        float width = mInlayHintPaint.measureText(text);
        if (mPerfStats != null) {
            mPerfStats.recordInlay(System.nanoTime() - t0, text.length());
        }
        return width;
    }

    /**
     * Measure icon width.
     *
     * @param iconId icon resource ID
     * @return icon drawing width (pixels)
     */
    float measureIconWidth(int iconId) {
        long t0 = mPerfStats != null ? System.nanoTime() : 0;
        float width;
        if (mIconWidthProvider != null) {
            width = mIconWidthProvider.getIconWidth(iconId);
        } else {
            width = getFontHeight();
        }
        if (mPerfStats != null) {
            mPerfStats.recordIcon(System.nanoTime() - t0);
        }
        return width;
    }

    float getFontHeight() {
        return mTextPaint.getFontMetrics().bottom - mTextPaint.getFontMetrics().top;
    }

    /**
     * Get font ascent (negative value, distance from baseline to top of visible characters).
     *
     * @return ascent value
     */
    float getFontAscent() {
        return mTextPaint.getFontMetrics().ascent;
    }

    /**
     * Get font descent (positive value, distance from baseline to bottom of visible characters).
     *
     * @return descent value
     */
    float getFontDescent() {
        return mTextPaint.getFontMetrics().descent;
    }
}
