package com.qiplat.sweeteditor.newline;

/**
 * Newline action result, describing the text to be inserted after pressing Enter.
 */
public class NewLineAction {
    /** Full text to insert (includes newline and indent) */
    public final String text;

    public NewLineAction(String text) {
        this.text = text;
    }
}
