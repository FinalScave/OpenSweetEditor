package com.qiplat.sweeteditor;

import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.keymap.EditorBuiltinCommand;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;

import java.util.ArrayList;
import java.util.List;

/**
 * Widget-layer keyboard shortcut map that additionally holds command handlers.
 */
public class EditorKeyMap {

    @FunctionalInterface
    public interface ShortcutHandler {
        void onShortcut(@NonNull KeyBinding binding, @NonNull SweetEditor editor);
    }

    private final ArrayList<KeyBinding> mBindings = new ArrayList<>();
    private final SparseArray<ShortcutHandler> mCommands = new SparseArray<>();
    private int mNextCustomId = EditorBuiltinCommand.TRIGGER_COMPLETION.value + 1;

    public void addBinding(@NonNull KeyBinding binding) {
        mBindings.remove(binding);
        mBindings.add(binding);
    }

    public void removeBinding(@NonNull KeyBinding binding) {
        mBindings.remove(binding);
    }

    @NonNull
    public List<KeyBinding> getBindings() {
        return mBindings;
    }

    /**
     * Register a command handler for the given binding.
     * <p>
     * If {@code binding.command == EditorBuiltinCommand.NONE.value}, a custom command id is auto-assigned.
     *
     * @return the resolved command id
     */
    public int registerCommand(@NonNull KeyBinding binding,
                               @NonNull ShortcutHandler handler) {
        int commandId = binding.command;
        KeyBinding resolvedBinding = binding;
        if (commandId == EditorBuiltinCommand.NONE.value) {
            commandId = mNextCustomId++;
            resolvedBinding = new KeyBinding(binding.first, binding.second, commandId);
        } else if (commandId >= mNextCustomId) {
            mNextCustomId = commandId + 1;
        }
        mCommands.put(commandId, handler);
        addBinding(resolvedBinding);
        return commandId;
    }

    @Nullable
    public ShortcutHandler getCommand(int commandId) {
        return mCommands.get(commandId);
    }

    private static void bind(EditorKeyMap km, int modifiers, int keyCode, int command) {
        km.addBinding(new KeyBinding(modifiers, keyCode, command));
    }

    private static void addCommonBindings(EditorKeyMap km) {
        bind(km, KeyModifier.NONE, KeyCode.LEFT,      EditorBuiltinCommand.CURSOR_LEFT.value);
        bind(km, KeyModifier.NONE, KeyCode.RIGHT,     EditorBuiltinCommand.CURSOR_RIGHT.value);
        bind(km, KeyModifier.NONE, KeyCode.UP,        EditorBuiltinCommand.CURSOR_UP.value);
        bind(km, KeyModifier.NONE, KeyCode.DOWN,      EditorBuiltinCommand.CURSOR_DOWN.value);
        bind(km, KeyModifier.NONE, KeyCode.HOME,      EditorBuiltinCommand.CURSOR_LINE_START.value);
        bind(km, KeyModifier.NONE, KeyCode.END,       EditorBuiltinCommand.CURSOR_LINE_END.value);
        bind(km, KeyModifier.NONE, KeyCode.PAGE_UP,   EditorBuiltinCommand.CURSOR_PAGE_UP.value);
        bind(km, KeyModifier.NONE, KeyCode.PAGE_DOWN, EditorBuiltinCommand.CURSOR_PAGE_DOWN.value);

        bind(km, KeyModifier.SHIFT, KeyCode.LEFT,      EditorBuiltinCommand.SELECT_LEFT.value);
        bind(km, KeyModifier.SHIFT, KeyCode.RIGHT,     EditorBuiltinCommand.SELECT_RIGHT.value);
        bind(km, KeyModifier.SHIFT, KeyCode.UP,        EditorBuiltinCommand.SELECT_UP.value);
        bind(km, KeyModifier.SHIFT, KeyCode.DOWN,      EditorBuiltinCommand.SELECT_DOWN.value);
        bind(km, KeyModifier.SHIFT, KeyCode.HOME,      EditorBuiltinCommand.SELECT_LINE_START.value);
        bind(km, KeyModifier.SHIFT, KeyCode.END,       EditorBuiltinCommand.SELECT_LINE_END.value);
        bind(km, KeyModifier.SHIFT, KeyCode.PAGE_UP,   EditorBuiltinCommand.SELECT_PAGE_UP.value);
        bind(km, KeyModifier.SHIFT, KeyCode.PAGE_DOWN, EditorBuiltinCommand.SELECT_PAGE_DOWN.value);

        bind(km, KeyModifier.NONE, KeyCode.BACKSPACE,  EditorBuiltinCommand.BACKSPACE.value);
        bind(km, KeyModifier.NONE, KeyCode.DELETE_KEY,  EditorBuiltinCommand.DELETE_FORWARD.value);
        bind(km, KeyModifier.NONE, KeyCode.TAB,        EditorBuiltinCommand.INSERT_TAB.value);
        bind(km, KeyModifier.NONE, KeyCode.ENTER,      EditorBuiltinCommand.INSERT_NEWLINE.value);

        bind(km, KeyModifier.CTRL, KeyCode.A, EditorBuiltinCommand.SELECT_ALL.value);
        bind(km, KeyModifier.META, KeyCode.A, EditorBuiltinCommand.SELECT_ALL.value);

        bind(km, KeyModifier.CTRL, KeyCode.Z, EditorBuiltinCommand.UNDO.value);
        bind(km, KeyModifier.META, KeyCode.Z, EditorBuiltinCommand.UNDO.value);

        km.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.C, EditorBuiltinCommand.COPY.value),
                (binding, editor) -> editor.copyToClipboard());
        km.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.C, EditorBuiltinCommand.COPY.value),
                (binding, editor) -> editor.copyToClipboard());
        km.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.V, EditorBuiltinCommand.PASTE.value),
                (binding, editor) -> editor.pasteFromClipboard());
        km.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.V, EditorBuiltinCommand.PASTE.value),
                (binding, editor) -> editor.pasteFromClipboard());
        km.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.X, EditorBuiltinCommand.CUT.value),
                (binding, editor) -> editor.cutToClipboard());
        km.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.X, EditorBuiltinCommand.CUT.value),
                (binding, editor) -> editor.cutToClipboard());

        km.registerCommand(
                new KeyBinding(KeyModifier.CTRL, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION.value),
                (binding, editor) -> editor.triggerCompletion());
        km.registerCommand(
                new KeyBinding(KeyModifier.META, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION.value),
                (binding, editor) -> editor.triggerCompletion());
    }

    /**
     * Create the default key map (VS Code style).
     */
    public static EditorKeyMap defaultKeyMap() {
        return vscode();
    }

    /**
     * VS Code key bindings.
     */
    public static EditorKeyMap vscode() {
        EditorKeyMap km = new EditorKeyMap();
        addCommonBindings(km);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO.value);

        bind(km, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(km, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(km, KeyModifier.ALT, KeyCode.UP,   EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(km, KeyModifier.ALT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);
        bind(km, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP,   EditorBuiltinCommand.COPY_LINE_UP.value);
        bind(km, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.COPY_LINE_DOWN.value);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);

        return km;
    }

    /**
     * JetBrains (IntelliJ IDEA) key bindings.
     */
    public static EditorKeyMap jetbrains() {
        EditorKeyMap km = new EditorKeyMap();
        addCommonBindings(km);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);

        bind(km, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE.value);
        bind(km, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE.value);

        bind(km, KeyModifier.CTRL, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN.value);
        bind(km, KeyModifier.META, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN.value);

        bind(km, KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(km, KeyModifier.CTRL | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(km, KeyModifier.META | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(km, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP,   EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(km, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);

        return km;
    }

    /**
     * Sublime Text key bindings.
     */
    public static EditorKeyMap sublime() {
        EditorKeyMap km = new EditorKeyMap();
        addCommonBindings(km);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO.value);
        bind(km, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO.value);

        bind(km, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(km, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW.value);
        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE.value);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.UP,   EditorBuiltinCommand.MOVE_LINE_UP.value);
        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN.value);

        bind(km, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);
        bind(km, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE.value);

        return km;
    }
}
