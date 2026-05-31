package com.qiplat.sweeteditor.core.keymap;

import java.util.Objects;

public final class KeyBinding {
    public KeyChord first = new KeyChord();
    public KeyChord second = new KeyChord();
    public int command = 0;

    public KeyBinding() {
    }

    public KeyBinding(KeyChord first, KeyChord second, int command) {
        this.first = first;
        this.second = second;
        this.command = command;
    }

    public KeyBinding(KeyChord first, int command) {
        this(first, KeyChord.EMPTY, command);
    }

    public KeyBinding(int modifiers, int keyCode, int command) {
        this(new KeyChord(modifiers, keyCode), KeyChord.EMPTY, command);
    }

    public KeyBinding(int firstModifiers, int firstKeyCode,
                      int secondModifiers, int secondKeyCode, int command) {
        this(new KeyChord(firstModifiers, firstKeyCode),
                new KeyChord(secondModifiers, secondKeyCode), command);
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof KeyBinding)) return false;
        KeyBinding other = (KeyBinding) obj;
        return command == other.command
                && Objects.equals(first, other.first)
                && Objects.equals(second, other.second);
    }

    @Override
    public int hashCode() {
        return Objects.hash(first, second, command);
    }
}
