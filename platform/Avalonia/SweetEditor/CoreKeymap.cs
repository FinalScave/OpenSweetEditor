#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum EditorBuiltinCommand {
        NONE = 0,
        CURSOR_LEFT = 1,
        CURSOR_RIGHT = 2,
        CURSOR_UP = 3,
        CURSOR_DOWN = 4,
        CURSOR_LINE_START = 5,
        CURSOR_LINE_END = 6,
        CURSOR_PAGE_UP = 7,
        CURSOR_PAGE_DOWN = 8,
        SELECT_LEFT = 9,
        SELECT_RIGHT = 10,
        SELECT_UP = 11,
        SELECT_DOWN = 12,
        SELECT_LINE_START = 13,
        SELECT_LINE_END = 14,
        SELECT_PAGE_UP = 15,
        SELECT_PAGE_DOWN = 16,
        SELECT_ALL = 17,
        BACKSPACE = 18,
        DELETE_FORWARD = 19,
        INSERT_TAB = 20,
        INSERT_NEWLINE = 21,
        INSERT_LINE_ABOVE = 22,
        INSERT_LINE_BELOW = 23,
        UNDO = 24,
        REDO = 25,
        MOVE_LINE_UP = 26,
        MOVE_LINE_DOWN = 27,
        COPY_LINE_UP = 28,
        COPY_LINE_DOWN = 29,
        DELETE_LINE = 30,
        COPY = 31,
        PASTE = 32,
        CUT = 33,
        TRIGGER_COMPLETION = 34
    }

    [Flags]
    public enum KeyCode {
        NONE = 0,
        BACKSPACE = 8,
        TAB = 9,
        ENTER = 13,
        ESCAPE = 27,
        DELETE_KEY = 46,
        LEFT = 37,
        UP = 38,
        RIGHT = 39,
        DOWN = 40,
        HOME = 36,
        END = 35,
        PAGE_UP = 33,
        PAGE_DOWN = 34,
        A = 65,
        C = 67,
        D = 68,
        V = 86,
        X = 88,
        Z = 90,
        Y = 89,
        K = 75,
        SPACE = 32
    }

    [Flags]
    public enum KeyModifier {
        NONE = 0,
        SHIFT = 1,
        CTRL = 2,
        ALT = 4,
        META = 8
    }

    public sealed partial class KeyBinding {
        public KeyChord First { get; set; } = new KeyChord();
        public KeyChord Second { get; set; } = new KeyChord();
        public int Command { get; set; } = 0;
    }

    public sealed partial class KeyChord {
        public int Modifiers { get; set; } = 0;
        public int KeyCode { get; set; } = 0;
    }
}
