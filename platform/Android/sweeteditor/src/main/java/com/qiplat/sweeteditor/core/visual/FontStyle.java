package com.qiplat.sweeteditor.core.visual;

/**
 * Font style bit flag constants (consistent with C++ FontStyle enum).
 * <p>
 * These are combinable bit flags, not mutually exclusive enum values.
 */
public final class FontStyle {
    public static final int NORMAL = 0;
    public static final int BOLD = 1;       // 1 << 0
    public static final int ITALIC = 1 << 1;  // 2
    public static final int STRIKETHROUGH = 1 << 2;  // 4

    private FontStyle() {
    }
}
