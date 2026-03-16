package com.qiplat.sweeteditor.core.visual;

/**
 * Visual render run type enumeration.
 */
public enum VisualRunType {
    /** Normal text. */
    TEXT,
    /** Whitespace. */
    WHITESPACE,
    /** Newline character. */
    NEWLINE,
    /** Inlay content (text or icon). */
    INLAY_HINT,
    /** Phantom text (for Copilot code suggestions). */
    PHANTOM_TEXT,
    /** Fold placeholder (" … " shown at end of folded region first line). */
    FOLD_PLACEHOLDER
}
