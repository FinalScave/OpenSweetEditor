#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum EventType {
        UNDEFINED = 0,
        TOUCH_DOWN = 1,
        TOUCH_POINTER_DOWN = 2,
        TOUCH_MOVE = 3,
        TOUCH_POINTER_UP = 4,
        TOUCH_UP = 5,
        TOUCH_CANCEL = 6,
        MOUSE_DOWN = 7,
        MOUSE_MOVE = 8,
        MOUSE_UP = 9,
        MOUSE_WHEEL = 10,
        MOUSE_RIGHT_DOWN = 11,
        DIRECT_SCALE = 12,
        DIRECT_SCROLL = 13
    }

    public enum GestureType {
        UNDEFINED = 0,
        TAP = 1,
        DOUBLE_TAP = 2,
        LONG_PRESS = 3,
        SCALE = 4,
        SCROLL = 5,
        FAST_SCROLL = 6,
        DRAG_SELECT = 7,
        CONTEXT_MENU = 8
    }

    public enum HitTargetType {
        NONE = 0,
        INLAY_HINT_TEXT = 1,
        INLAY_HINT_ICON = 2,
        GUTTER_ICON = 3,
        FOLD_PLACEHOLDER = 4,
        FOLD_GUTTER = 5,
        INLAY_HINT_COLOR = 6,
        CODELENS = 7,
        LINK = 8
    }

    public sealed partial class HitTarget {
        public HitTargetType Type { get; set; } = HitTargetType.NONE;
        public int Line { get; set; } = 0;
        public int Column { get; set; } = 0;
        public int IconId { get; set; } = 0;
        public int ColorValue { get; set; } = 0;
    }
}
