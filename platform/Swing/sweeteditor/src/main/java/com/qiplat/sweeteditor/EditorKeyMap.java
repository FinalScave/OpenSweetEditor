package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.keymap.EditorBuiltinCommand;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class EditorKeyMap {
    @FunctionalInterface
    public interface ShortcutHandler {
        void onShortcut(KeyBinding binding, SweetEditor editor);
    }

    private final ArrayList<KeyBinding> bindings = new ArrayList<>();
    private final Map<Integer, ShortcutHandler> commands = new HashMap<>();
    private int nextCustomId = EditorBuiltinCommand.TRIGGER_COMPLETION.value + 1;

    public void addBinding(KeyBinding binding) {
        bindings.remove(binding);
        bindings.add(binding);
    }

    public void removeBinding(KeyBinding binding) {
        bindings.remove(binding);
    }

    public List<KeyBinding> getBindings() {
        return bindings;
    }

    public int registerCommand(KeyBinding binding, ShortcutHandler handler) {
        int commandId = binding.command;
        KeyBinding resolvedBinding = binding;
        if (commandId == EditorBuiltinCommand.NONE.value) {
            commandId = nextCustomId++;
            resolvedBinding = new KeyBinding(binding.first, binding.second, commandId);
        } else if (commandId >= nextCustomId) {
            nextCustomId = commandId + 1;
        }
        commands.put(commandId, handler);
        addBinding(resolvedBinding);
        return commandId;
    }

    public ShortcutHandler getCommand(int commandId) {
        return commands.get(commandId);
    }

    private static void bind(EditorKeyMap keyMap, int modifiers, int keyCode, int command) {
        keyMap.addBinding(new KeyBinding(modifiers, keyCode, command));
    }

    private static void addCommonBindings(EditorKeyMap keyMap) {
        bind(keyMap, KeyModifier.NONE, KeyCode.LEFT, EditorBuiltinCommand.CURSOR_LEFT.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.RIGHT, EditorBuiltinCommand.CURSOR_RIGHT.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.UP, EditorBuiltinCommand.CURSOR_UP.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.DOWN, EditorBuiltinCommand.CURSOR_DOWN.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.HOME, EditorBuiltinCommand.CURSOR_LINE_START.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.END, EditorBuiltinCommand.CURSOR_LINE_END.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_UP, EditorBuiltinCommand.CURSOR_PAGE_UP.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_DOWN, EditorBuiltinCommand.CURSOR_PAGE_DOWN.value);

        bind(keyMap, KeyModifier.SHIFT, KeyCode.LEFT, EditorBuiltinCommand.SELECT_LEFT.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.RIGHT, EditorBuiltinCommand.SELECT_RIGHT.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.SELECT_UP.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.SELECT_DOWN.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.HOME, EditorBuiltinCommand.SELECT_LINE_START.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.END, EditorBuiltinCommand.SELECT_LINE_END.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_UP, EditorBuiltinCommand.SELECT_PAGE_UP.value);
        bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_DOWN, EditorBuiltinCommand.SELECT_PAGE_DOWN.value);

        bind(keyMap, KeyModifier.NONE, KeyCode.BACKSPACE, EditorBuiltinCommand.BACKSPACE.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.DELETE_KEY, EditorBuiltinCommand.DELETE_FORWARD.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.TAB, EditorBuiltinCommand.INSERT_TAB.value);
        bind(keyMap, KeyModifier.NONE, KeyCode.ENTER, EditorBuiltinCommand.INSERT_NEWLINE.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.A, EditorBuiltinCommand.SELECT_ALL.value);
        bind(keyMap, KeyModifier.META, KeyCode.A, EditorBuiltinCommand.SELECT_ALL.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.Z, EditorBuiltinCommand.UNDO.value);
        bind(keyMap, KeyModifier.META, KeyCode.Z, EditorBuiltinCommand.UNDO.value);

        keyMap.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.C, EditorBuiltinCommand.COPY.value),
                (binding, editor) -> editor.copyToClipboard());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.C, EditorBuiltinCommand.COPY.value),
                (binding, editor) -> editor.copyToClipboard());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.V, EditorBuiltinCommand.PASTE.value),
                (binding, editor) -> editor.pasteFromClipboard());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.V, EditorBuiltinCommand.PASTE.value),
                (binding, editor) -> editor.pasteFromClipboard());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.X, EditorBuiltinCommand.CUT.value),
                (binding, editor) -> editor.cutToClipboard());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.X, EditorBuiltinCommand.CUT.value),
                (binding, editor) -> editor.cutToClipboard());

        keyMap.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION.value),
                (binding, editor) -> editor.triggerCompletion());
        keyMap.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION.value),
                (binding, editor) -> editor.triggerCompletion());
    }

    public static EditorKeyMap defaultKeyMap() {
        return vscode();
    }

    public static EditorKeyMap vscode() {
        EditorKeyMap keyMap = new EditorKeyMap();
        addCommonBindings(keyMap);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(keyMap, KeyModifier.ALT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(keyMap, KeyModifier.ALT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);
        bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.COPY_LINE_UP.value);
        bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.COPY_LINE_DOWN.value);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        return keyMap;
    }

    public static EditorKeyMap jetbrains() {
        EditorKeyMap keyMap = new EditorKeyMap();
        addCommonBindings(keyMap);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE.value);
        bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN.value);
        bind(keyMap, KeyModifier.META, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN.value);

        bind(keyMap, KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(keyMap, KeyModifier.CTRL | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(keyMap, KeyModifier.META | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);
        return keyMap;
    }

    public static EditorKeyMap sublime() {
        EditorKeyMap keyMap = new EditorKeyMap();
        addCommonBindings(keyMap);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO.value);
        bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO.value);

        bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);

        bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        return keyMap;
    }
}
