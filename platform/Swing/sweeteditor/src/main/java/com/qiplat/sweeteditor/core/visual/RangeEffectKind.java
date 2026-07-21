package com.qiplat.sweeteditor.core.visual;

public enum RangeEffectKind {
    SELECTION(0),
    SEARCH_MATCH(1),
    SEARCH_CURRENT(2),
    DOCUMENT_HIGHLIGHT_TEXT(3),
    DOCUMENT_HIGHLIGHT_READ(4),
    DOCUMENT_HIGHLIGHT_WRITE(5),
    LINKED_EDITING_ACTIVE(6),
    LINKED_EDITING_INACTIVE(7),
    IME_COMPOSITION(8),
    BRACKET_MATCH(9),
    DIAGNOSTIC_ERROR(10),
    DIAGNOSTIC_WARNING(11),
    DIAGNOSTIC_INFO(12),
    DIAGNOSTIC_HINT(13);

    public final int value;

    RangeEffectKind(int value) {
        this.value = value;
    }

    public static RangeEffectKind fromValue(int value) {
        switch (value) {
            case 0: return SELECTION;
            case 1: return SEARCH_MATCH;
            case 2: return SEARCH_CURRENT;
            case 3: return DOCUMENT_HIGHLIGHT_TEXT;
            case 4: return DOCUMENT_HIGHLIGHT_READ;
            case 5: return DOCUMENT_HIGHLIGHT_WRITE;
            case 6: return LINKED_EDITING_ACTIVE;
            case 7: return LINKED_EDITING_INACTIVE;
            case 8: return IME_COMPOSITION;
            case 9: return BRACKET_MATCH;
            case 10: return DIAGNOSTIC_ERROR;
            case 11: return DIAGNOSTIC_WARNING;
            case 12: return DIAGNOSTIC_INFO;
            case 13: return DIAGNOSTIC_HINT;
            default: throw new IllegalArgumentException("Unknown RangeEffectKind value: " + value);
        }
    }
}
