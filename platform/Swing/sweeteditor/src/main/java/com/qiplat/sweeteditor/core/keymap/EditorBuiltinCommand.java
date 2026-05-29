package com.qiplat.sweeteditor.core.keymap;

public enum EditorBuiltinCommand {
    NONE(0),
    CURSOR_LEFT(1),
    CURSOR_RIGHT(2),
    CURSOR_UP(3),
    CURSOR_DOWN(4),
    CURSOR_LINE_START(5),
    CURSOR_LINE_END(6),
    CURSOR_PAGE_UP(7),
    CURSOR_PAGE_DOWN(8),
    SELECT_LEFT(9),
    SELECT_RIGHT(10),
    SELECT_UP(11),
    SELECT_DOWN(12),
    SELECT_LINE_START(13),
    SELECT_LINE_END(14),
    SELECT_PAGE_UP(15),
    SELECT_PAGE_DOWN(16),
    SELECT_ALL(17),
    BACKSPACE(18),
    DELETE_FORWARD(19),
    INSERT_TAB(20),
    INSERT_NEWLINE(21),
    INSERT_LINE_ABOVE(22),
    INSERT_LINE_BELOW(23),
    UNDO(24),
    REDO(25),
    MOVE_LINE_UP(26),
    MOVE_LINE_DOWN(27),
    COPY_LINE_UP(28),
    COPY_LINE_DOWN(29),
    DELETE_LINE(30),
    COPY(31),
    PASTE(32),
    CUT(33),
    TRIGGER_COMPLETION(34);

    public final int value;

    EditorBuiltinCommand(int value) {
        this.value = value;
    }

    public static EditorBuiltinCommand fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return CURSOR_LEFT;
            case 2: return CURSOR_RIGHT;
            case 3: return CURSOR_UP;
            case 4: return CURSOR_DOWN;
            case 5: return CURSOR_LINE_START;
            case 6: return CURSOR_LINE_END;
            case 7: return CURSOR_PAGE_UP;
            case 8: return CURSOR_PAGE_DOWN;
            case 9: return SELECT_LEFT;
            case 10: return SELECT_RIGHT;
            case 11: return SELECT_UP;
            case 12: return SELECT_DOWN;
            case 13: return SELECT_LINE_START;
            case 14: return SELECT_LINE_END;
            case 15: return SELECT_PAGE_UP;
            case 16: return SELECT_PAGE_DOWN;
            case 17: return SELECT_ALL;
            case 18: return BACKSPACE;
            case 19: return DELETE_FORWARD;
            case 20: return INSERT_TAB;
            case 21: return INSERT_NEWLINE;
            case 22: return INSERT_LINE_ABOVE;
            case 23: return INSERT_LINE_BELOW;
            case 24: return UNDO;
            case 25: return REDO;
            case 26: return MOVE_LINE_UP;
            case 27: return MOVE_LINE_DOWN;
            case 28: return COPY_LINE_UP;
            case 29: return COPY_LINE_DOWN;
            case 30: return DELETE_LINE;
            case 31: return COPY;
            case 32: return PASTE;
            case 33: return CUT;
            case 34: return TRIGGER_COMPLETION;
            default: return NONE;
        }
    }
}
