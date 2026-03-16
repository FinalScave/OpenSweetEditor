package com.qiplat.sweeteditor.core.foundation;

/**
 * Auto-indent mode.
 */
public enum AutoIndentMode {
    /** No auto-indent, new line starts from column 0 */
    NONE(0),
    /** Keep the previous line's indent (copy leading whitespace) */
    KEEP_INDENT(1);

    public final int value;

    AutoIndentMode(int value) {
        this.value = value;
    }
}
