package com.qiplat.sweeteditor.newline;

import com.qiplat.sweeteditor.LanguageConfiguration;

/**
 * Newline context, provided to NewLineActionProvider for indent calculation.
 */
public class NewLineContext {
    /** Cursor line number (0-based) */
    public final int lineNumber;
    /** Cursor column number (0-based) */
    public final int column;
    /** Current line text */
    public final String lineText;
    /** Language configuration (may be null) */
    public final LanguageConfiguration languageConfiguration;

    public NewLineContext(int lineNumber, int column, String lineText,
                          LanguageConfiguration languageConfiguration) {
        this.lineNumber = lineNumber;
        this.column = column;
        this.lineText = lineText;
        this.languageConfiguration = languageConfiguration;
    }
}
