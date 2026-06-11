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

    public static class KeyCode {
        public const int NONE = 0;
        public const int BACKSPACE = 8;
        public const int TAB = 9;
        public const int ENTER = 13;
        public const int ESCAPE = 27;
        public const int SPACE = 32;
        public const int PAGE_UP = 33;
        public const int PAGE_DOWN = 34;
        public const int END = 35;
        public const int HOME = 36;
        public const int LEFT = 37;
        public const int UP = 38;
        public const int RIGHT = 39;
        public const int DOWN = 40;
        public const int DELETE_KEY = 46;
        public const int A = 65;
        public const int C = 67;
        public const int D = 68;
        public const int K = 75;
        public const int V = 86;
        public const int X = 88;
        public const int Y = 89;
        public const int Z = 90;
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
