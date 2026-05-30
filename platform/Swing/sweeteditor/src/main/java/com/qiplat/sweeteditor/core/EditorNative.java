package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.foundation.IntRange;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * FFM (Foreign Function & Memory) binding layer, calling C++ dynamic library via Java 22 Foreign Linker API.
 * <p>
 * All C API functions are declared as MethodHandles in this class for {@link EditorCore} to call.
 */
public final class EditorNative {

    private static final Linker LINKER = Linker.nativeLinker();
    private static final SymbolLookup LIB;
    private static final String LIB_PATH_KEY = "sweeteditor.lib.path";
    private static final String LOAD_LIBRARY_ERROR =
            "Cannot load native library 'sweeteditor'. " +
                    "Set -Dsweeteditor.lib.path=<dir> or add the library to java.library.path. ";

    static {
        LIB = loadLibraryLookup();
    }

    private static SymbolLookup loadLibraryLookup() {
        String libName = System.mapLibraryName("sweeteditor");
        // -Dsweeteditor.lib.path explicitly specified (including the scenario auto-set by NativeLibraryExtractor.extract)
        SymbolLookup lookup = tryExplicitLibrary(libName);
        if (lookup != null) {
            return lookup;
        }
        // Try auto-extracting from JAR resources to default directory and load
        lookup = tryLoadFromJarResources();
        if (lookup != null) {
            return lookup;
        }
        // Fallback to system path (java.library.path)
        return loadLibraryFromSystem();
    }

    /**
     * Try auto-extracting the native library from JAR resources to the default directory (~/.sweeteditor/native/),
     * automatically set sweeteditor.lib.path and load after successful extraction.
     * This is the automatic fallback loading method for Maven release scenarios.
     */
    private static SymbolLookup tryLoadFromJarResources() {
        try {
            Path libPath = NativeLibraryExtractor.extractToDefaultDir();
            if (Files.exists(libPath)) {
                return SymbolLookup.libraryLookup(libPath, Arena.global());
            }
        } catch (Exception ignored) {
            // No native library resources in JAR (non-Maven release scenario), silently skip
        }
        return null;
    }

    private static SymbolLookup tryExplicitLibrary(String libName) {
        String libPath = System.getProperty(LIB_PATH_KEY);
        if (libPath == null || libPath.isBlank()) {
            return null;
        }
        return lookupLibrary(Path.of(libPath, libName));
    }

    private static SymbolLookup lookupLibrary(Path path) {
        if (!Files.exists(path)) {
            return null;
        }
        return SymbolLookup.libraryLookup(path, Arena.global());
    }

    private static SymbolLookup loadLibraryFromSystem() {
        try {
            System.loadLibrary("sweeteditor");
            return SymbolLookup.loaderLookup();
        } catch (UnsatisfiedLinkError e) {
            throw new UnsatisfiedLinkError(LOAD_LIBRARY_ERROR);
        }
    }

    private static MethodHandle downcall(String name, FunctionDescriptor desc) {
        return LINKER.downcallHandle(
                LIB.find(name).orElseThrow(() -> new UnsatisfiedLinkError("Symbol not found: " + name)),
                desc);
    }

    @FunctionalInterface
    private interface ThrowableSupplier<T> {
        T get() throws Throwable;
    }

    @FunctionalInterface
    private interface ThrowableRunnable {
        void run() throws Throwable;
    }

    @FunctionalInterface
    private interface BinaryInvoker {
        MemorySegment invoke(MemorySegment outSize) throws Throwable;
    }

    /**
     * Encapsulates the binary result returned by native, supporting zero-copy access.
     * <p>
     * The caller must call {@link #free()} after use to release native memory.
     * Recommend using try-finally pattern to ensure exception safety.
     */
    static final class NativeBinaryResult {
        private final MemorySegment ptr;
        private final long size;

        NativeBinaryResult(MemorySegment ptr, long size) {
            this.ptr = ptr;
            this.size = size;
        }

        /**
         * Whether there is valid data
         */
        boolean hasData() {
            return ptr != null && !ptr.equals(MemorySegment.NULL) && size > 0;
        }

        MemorySegment segment() {
            return ptr;
        }

        long size() {
            return size;
        }

        /**
         * Release memory allocated by the native side
         */
        void free() {
            if (ptr != null && !ptr.equals(MemorySegment.NULL)) {
                freeBinaryData(ptr.address());
            }
        }
    }

    private static RuntimeException wrapThrowable(Throwable t) {
        return new RuntimeException(t);
    }

    private static <T> T invokeValue(ThrowableSupplier<T> supplier) {
        try {
            return supplier.get();
        } catch (Throwable t) {
            throw wrapThrowable(t);
        }
    }

    private static void invokeVoid(ThrowableRunnable runnable) {
        try {
            runnable.run();
        } catch (Throwable t) {
            throw wrapThrowable(t);
        }
    }

    private static boolean invokeBoolean(ThrowableSupplier<Integer> supplier) {
        return invokeValue(() -> supplier.get() != 0);
    }

    private static NativeBinaryResult invokeBinaryResult(Arena arena, BinaryInvoker invoker) {
        try {
            MemorySegment outSize = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment ptr = invoker.invoke(outSize);
            long size = outSize.get(ValueLayout.JAVA_LONG, 0);
            if (ptr != null && !ptr.equals(MemorySegment.NULL) && size > 0 && size <= Integer.MAX_VALUE) {
                ptr = ptr.reinterpret(size);
            }
            return new NativeBinaryResult(ptr, size);
        } catch (Throwable t) {
            throw wrapThrowable(t);
        }
    }

    private static NativeBinaryResult invokeBinaryResult(BinaryInvoker invoker) {
        try (Arena arena = Arena.ofConfined()) {
            return invokeBinaryResult(arena, invoker);
        }
    }

    private static MemorySegment nullableString(Arena arena, String text) {
        return text != null ? arena.allocateFrom(text) : MemorySegment.NULL;
    }

    private static MemorySegment byteArraySegment(Arena arena, byte[] data) {
        return arena.allocateFrom(ValueLayout.JAVA_BYTE, data);
    }

    // ===================== text_measurer_t callback struct layout =====================
    // struct { float(*)(const U16Char*, int32_t); float(*)(const U16Char*); float(*)(int32_t); void(*)(float*, size_t); }
    // 4 function pointers, each occupying ADDRESS size
    public static final MemoryLayout MEASURER_LAYOUT = MemoryLayout.structLayout(
            ValueLayout.ADDRESS.withName("measure_text_width"),
            ValueLayout.ADDRESS.withName("measure_inlay_hint_width"),
            ValueLayout.ADDRESS.withName("measure_icon_width"),
            ValueLayout.ADDRESS.withName("get_font_metrics")
    );

    // Callback function descriptors
    public static final FunctionDescriptor MEASURE_TEXT_WIDTH_DESC = FunctionDescriptor.of(
            ValueLayout.JAVA_FLOAT, ValueLayout.ADDRESS, ValueLayout.JAVA_INT);
    public static final FunctionDescriptor MEASURE_INLAY_HINT_WIDTH_DESC = FunctionDescriptor.of(
            ValueLayout.JAVA_FLOAT, ValueLayout.ADDRESS);
    public static final FunctionDescriptor MEASURE_ICON_WIDTH_DESC = FunctionDescriptor.of(
            ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_INT);
    public static final FunctionDescriptor GET_FONT_METRICS_DESC = FunctionDescriptor.ofVoid(
            ValueLayout.ADDRESS, ValueLayout.JAVA_LONG);

    // ===================== Native handles =====================

    private static final MethodHandle CREATE_DOCUMENT = downcall("create_document_from_utf16",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));
    private static final MethodHandle CREATE_DOCUMENT_FROM_FILE = downcall("create_document_from_file",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_DOCUMENT_LINE_TEXT = downcall("get_document_line_utf16",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_DOCUMENT_LINE_COUNT = downcall("get_document_line_count",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle CREATE_EDITOR = downcall("create_editor",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, MEASURER_LAYOUT, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_EDITOR_DOCUMENT = downcall("editor_set_document",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_VIEWPORT = downcall("editor_set_viewport",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_SHORT, ValueLayout.JAVA_SHORT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle SET_FOLD_ARROW_MODE = downcall("editor_set_fold_arrow_mode",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_LINE_SPACING = downcall("editor_set_line_spacing",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle SET_CONTENT_START_PADDING = downcall("editor_set_content_start_padding",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_SHOW_SPLIT_LINE = downcall("editor_set_show_split_line",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_GUTTER_STICKY = downcall("editor_set_gutter_sticky",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_GUTTER_VISIBLE = downcall("editor_set_gutter_visible",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_CURRENT_LINE_RENDER_MODE = downcall("editor_set_current_line_render_mode",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle BUILD_RENDER_MODEL = downcall("editor_build_render_model",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_LAYOUT_METRICS = downcall("editor_get_layout_metrics",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle TICK_EDGE_SCROLL = downcall("editor_tick_edge_scroll",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle TICK_FLING = downcall("editor_tick_fling",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle TICK_ANIMATIONS = downcall("editor_tick_animations",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle HANDLE_GESTURE = downcall("editor_handle_gesture_event",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle UPDATE_POINTER_MODIFIERS = downcall("editor_update_pointer_modifiers",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_TEXT = downcall("editor_insert_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle DELETE_TEXT = downcall("editor_delete_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle DELETE_FORWARD = downcall("editor_delete_forward",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_LINE_DOWN = downcall("editor_move_line_down",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle COPY_LINE_DOWN = downcall("editor_copy_line_down",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_LINE_ABOVE = downcall("editor_insert_line_above",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle UNDO = downcall("editor_undo",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CAN_UNDO = downcall("editor_can_undo",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_CURSOR = downcall("editor_set_cursor_position",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_LEFT = downcall("editor_move_cursor_left",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_RIGHT = downcall("editor_move_cursor_right",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_UP = downcall("editor_move_cursor_up",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_DOWN = downcall("editor_move_cursor_down",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_TO_LINE_START = downcall("editor_move_cursor_to_line_start",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_CURSOR_TO_LINE_END = downcall("editor_move_cursor_to_line_end",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SELECT_ALL = downcall("editor_select_all",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_SELECTION = downcall("editor_get_selection",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle GET_WORD_RANGE_AT_CURSOR = downcall("editor_get_word_range_at_cursor",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle IS_COMPOSING = downcall("editor_is_composing",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_COMPOSING_RANGE = downcall("editor_get_composing_range",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle GET_COMPOSING_SESSION_RANGE = downcall("editor_get_composing_session_range",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle IME_UPDATE_PREEDIT = downcall("editor_ime_update_preedit",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_SET_COMPOSING_TEXT = downcall("editor_ime_set_composing_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_SET_COMPOSING_TEXT_SELECTION = downcall("editor_ime_set_composing_text_selection",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_COMMIT_TEXT = downcall("editor_ime_commit_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_FINISH_PREEDIT = downcall("editor_ime_finish_preedit",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle IME_CANCEL_PREEDIT = downcall("editor_ime_cancel_preedit",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle IME_MARK_DOCUMENT_RANGE = downcall("editor_ime_mark_document_range",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_MARK_DOCUMENT_RANGE_BY_OFFSET = downcall("editor_ime_mark_document_range_by_offset",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_REPLACE_TEXT = downcall("editor_ime_replace_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_REPLACE_DOCUMENT_TEXT = downcall("editor_ime_replace_document_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_REPLACE_INPUT_CONTEXT_TEXT = downcall("editor_ime_replace_input_context_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_MARK_INPUT_CONTEXT_RANGE = downcall("editor_ime_mark_input_context_range",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_NOTIFY_DOCUMENT_SELECTION_CHANGED =
            downcall("editor_ime_notify_document_selection_changed",
                    FunctionDescriptor.of(ValueLayout.ADDRESS,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                            ValueLayout.ADDRESS));

    private static final MethodHandle IME_NOTIFY_INPUT_CONTEXT_SELECTION_CHANGED =
            downcall("editor_ime_notify_input_context_selection_changed",
                    FunctionDescriptor.of(ValueLayout.ADDRESS,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                            ValueLayout.ADDRESS));

    private static final MethodHandle IME_UPDATE_INPUT_STATE_TEXT =
            downcall("editor_ime_update_input_state_text",
                    FunctionDescriptor.of(ValueLayout.ADDRESS,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                            ValueLayout.ADDRESS,
                            ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                            ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                            ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_UPDATE_INPUT_STATE_SELECTION =
            downcall("editor_ime_update_input_state_selection",
                    FunctionDescriptor.of(ValueLayout.ADDRESS,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                            ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                            ValueLayout.ADDRESS));

    private static final MethodHandle IME_REPLACE_INPUT_STATE_TEXT =
            downcall("editor_ime_replace_input_state_text",
                    FunctionDescriptor.of(ValueLayout.ADDRESS,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT,
                            ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                            ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                            ValueLayout.ADDRESS));

    private static final MethodHandle IME_DELETE_BACKWARD = downcall("editor_ime_delete_backward",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_DELETE_FORWARD = downcall("editor_ime_delete_forward",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_DELETE_SURROUNDING = downcall("editor_ime_delete_surrounding",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_NOTIFY_SELECTION_CHANGED = downcall("editor_ime_notify_selection_changed",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));

    private static final MethodHandle IME_NOTIFY_CURSOR_CHANGED = downcall("editor_ime_notify_cursor_changed",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle IME_SET_KEYBOARD_SCRIPT_CLASS = downcall("editor_ime_set_keyboard_script_class",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IME_GET_KEYBOARD_SCRIPT_CLASS = downcall("editor_ime_get_keyboard_script_class",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_IME_SYNC_SNAPSHOT = downcall("editor_get_ime_sync_snapshot",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_IME_INPUT_CONTEXT = downcall("editor_get_ime_input_context",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_READ_ONLY = downcall("editor_set_read_only",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle IS_READ_ONLY = downcall("editor_is_read_only",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_AUTO_INDENT_MODE = downcall("editor_set_auto_indent_mode",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_BACKSPACE_UNINDENT = downcall("editor_set_backspace_unindent",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle GET_POSITION_RECT = downcall("editor_get_position_rect",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_SNIPPET = downcall("editor_insert_snippet",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle IS_IN_LINKED_EDITING = downcall("editor_is_in_linked_editing",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle LINKED_EDITING_PREV = downcall("editor_linked_editing_prev",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SCROLL_TO_LINE = downcall("editor_scroll_to_line",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE,
                    ValueLayout.ADDRESS));

    private static final MethodHandle SET_SCROLL = downcall("editor_set_scroll",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT,
                    ValueLayout.ADDRESS));

    private static final MethodHandle REGISTER_TEXT_STYLE = downcall("editor_register_text_style",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));


    private static final MethodHandle CLEAR_GUTTER_ICONS = downcall("editor_clear_gutter_icons",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_LINE_DIAGNOSTICS = downcall("editor_set_line_diagnostics",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));


    private static final MethodHandle CLEAR_GUIDES = downcall("editor_clear_guides",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_BRACKET_PAIRS = downcall("editor_set_bracket_pairs",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_AUTO_CLOSING_PAIRS = downcall("editor_set_auto_closing_pairs",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_MATCHED_BRACKETS = downcall("editor_clear_matched_brackets",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_FOLD_REGIONS = downcall("editor_set_fold_regions",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));

    private static final MethodHandle FOLD_AT = downcall("editor_fold_at",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle FOLD_ALL = downcall("editor_fold_all",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle IS_LINE_VISIBLE = downcall("editor_is_line_visible",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_HIGHLIGHTS = downcall("editor_clear_highlights",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_LINE_SPANS = downcall("editor_clear_line_spans",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE,
                    ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_INLAY_HINTS = downcall("editor_clear_inlay_hints",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_ALL_DECORATIONS = downcall("editor_clear_all_decorations",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle FREE_BINARY_DATA = downcall("free_binary_data",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_DOCUMENT = downcall("free_document",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_EDITOR = downcall("free_editor",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle ON_FONT_METRICS_CHANGED = downcall("editor_on_font_metrics_changed",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle HANDLE_KEY_EVENT = downcall("editor_handle_key_event",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_SHORT, ValueLayout.ADDRESS, ValueLayout.JAVA_BYTE, ValueLayout.ADDRESS));

    private static final MethodHandle REPLACE_TEXT = downcall("editor_replace_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle MOVE_LINE_UP = downcall("editor_move_line_up",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle DELETE_LINE = downcall("editor_delete_line",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle REDO = downcall("editor_redo",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_CURSOR = downcall("editor_get_cursor_position",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle GET_SELECTED_TEXT = downcall("editor_get_selected_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_WORD_AT_CURSOR = downcall("editor_get_word_at_cursor",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_LINK_TARGET_AT = downcall("editor_get_link_target_at",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_AUTO_INDENT_MODE = downcall("editor_get_auto_indent_mode",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_HANDLE_CONFIG = downcall("editor_set_handle_config",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_SCROLLBAR_CONFIG = downcall("editor_set_scrollbar_config",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_CURSOR_RECT = downcall("editor_get_cursor_rect",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle START_LINKED_EDITING = downcall("editor_start_linked_editing",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));

    private static final MethodHandle CANCEL_LINKED_EDITING = downcall("editor_cancel_linked_editing",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GOTO_LINE = downcall("editor_goto_position",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));

    private static final MethodHandle ENSURE_CURSOR_VISIBLE = downcall("editor_ensure_cursor_visible",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle SET_LINE_SPANS = downcall("editor_set_line_spans",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS));


    private static final MethodHandle CLEAR_DIAGNOSTICS = downcall("editor_clear_diagnostics",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));


    private static final MethodHandle SET_MATCHED_BRACKETS = downcall("editor_set_matched_brackets",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle TOGGLE_FOLD = downcall("editor_toggle_fold",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle UNFOLD_ALL = downcall("editor_unfold_all",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_HIGHLIGHTS_LAYER = downcall("editor_clear_highlights_layer",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE, ValueLayout.ADDRESS));

    private static final MethodHandle FREE_U8_STRING = downcall("free_u8_string",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_U16_STRING = downcall("free_u16_string",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_WRAP_MODE = downcall("editor_set_wrap_mode",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_TAB_SIZE = downcall("editor_set_tab_size",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_INSERT_SPACES = downcall("editor_set_insert_spaces",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));

    private static final MethodHandle SET_SCALE = downcall("editor_set_scale",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.ADDRESS));

    private static final MethodHandle BACKSPACE = downcall("editor_backspace",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle COPY_LINE_UP = downcall("editor_copy_line_up",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_LINE_BELOW = downcall("editor_insert_line_below",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CAN_REDO = downcall("editor_can_redo",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_SELECTION = downcall("editor_set_selection",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle LINKED_EDITING_NEXT = downcall("editor_linked_editing_next",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_SCROLL_METRICS = downcall("editor_get_scroll_metrics",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_VISIBLE_LINE_RANGE = downcall("editor_get_visible_line_range",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));


    private static final MethodHandle SET_MAX_GUTTER_ICONS = downcall("editor_set_max_gutter_icons",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));


    private static final MethodHandle UNFOLD_AT = downcall("editor_unfold_at",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CLEAR_PHANTOM_TEXTS = downcall("editor_clear_phantom_texts",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    // ===================== Binary payload API =====================

    private static final FunctionDescriptor BINARY_PAYLOAD_DESC =
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS);

    private static final MethodHandle SET_LINE_INLAY_HINTS = downcall("editor_set_line_inlay_hints", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_INLAY_HINTS = downcall("editor_set_batch_line_inlay_hints", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_PHANTOM_TEXTS = downcall("editor_set_line_phantom_texts", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_PHANTOM_TEXTS = downcall("editor_set_batch_line_phantom_texts", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_GUTTER_ICONS = downcall("editor_set_line_gutter_icons", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_GUTTER_ICONS = downcall("editor_set_batch_line_gutter_icons", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_CODELENS = downcall("editor_set_line_codelens", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_CODELENS = downcall("editor_set_batch_line_codelens", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_LINKS = downcall("editor_set_line_links", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_LINKS = downcall("editor_set_batch_line_links", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_SPANS = downcall("editor_set_batch_line_spans", BINARY_PAYLOAD_DESC);
    private static final MethodHandle REGISTER_BATCH_TEXT_STYLES = downcall("editor_register_batch_text_styles", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_DIAGNOSTICS = downcall("editor_set_batch_line_diagnostics", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_INDENT_GUIDES = downcall("editor_set_indent_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BRACKET_GUIDES = downcall("editor_set_bracket_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_FLOW_GUIDES = downcall("editor_set_flow_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_SEPARATOR_GUIDES = downcall("editor_set_separator_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_KEYMAP = downcall("editor_set_keymap", BINARY_PAYLOAD_DESC);
    private static final MethodHandle CLEAR_CODELENS = downcall("editor_clear_codelens",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));
    private static final MethodHandle CLEAR_LINKS = downcall("editor_clear_links",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    // ===================== Document API =====================

    public static long createDocument(Arena arena, String text) {
        try {
            MemorySegment utf16 = arena.allocateFrom(text, StandardCharsets.UTF_16LE);
            return (long) CREATE_DOCUMENT.invokeExact(utf16);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static long createDocumentFromFile(Arena arena, String path) {
        try {
            MemorySegment utf8 = path != null ? arena.allocateFrom(path) : MemorySegment.NULL;
            return (long) CREATE_DOCUMENT_FROM_FILE.invokeExact(utf8);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static void freeDocument(long handle) {
        invokeVoid(() -> {
            FREE_DOCUMENT.invokeExact(handle);
        });
    }

    public static String getDocumentLineText(long documentHandle, int line) {
        try {
            MemorySegment ptr = (MemorySegment) GET_DOCUMENT_LINE_TEXT.invokeExact(documentHandle, (long) line);
            String text = readUtf16String(ptr);
            if (ptr != null && !ptr.equals(MemorySegment.NULL)) {
                freeU16String(ptr.address());
            }
            return text;
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static int getDocumentLineCount(long documentHandle) {
        return invokeValue(() -> (int) (long) GET_DOCUMENT_LINE_COUNT.invokeExact(documentHandle));
    }

    // ===================== Editor Lifecycle =====================

    public static long createEditor(MemorySegment measurer, byte[] optionsData, Arena arena) {
        MemorySegment optionsSeg = arena.allocate(optionsData.length);
        optionsSeg.copyFrom(MemorySegment.ofArray(optionsData));
        return invokeValue(() -> (long) CREATE_EDITOR.invokeExact(measurer, optionsSeg, (long) optionsData.length));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static long createEditor(MemorySegment measurer, MemorySegment optionsSeg, long optionsSize) {
        return invokeValue(() -> (long) CREATE_EDITOR.invokeExact(measurer, optionsSeg, optionsSize));
    }

    public static void freeEditor(long handle) {
        invokeVoid(() -> {
            FREE_EDITOR.invokeExact(handle);
        });
    }

    public static NativeBinaryResult setEditorDocument(long editorHandle, long documentHandle) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_EDITOR_DOCUMENT.invokeExact(editorHandle, documentHandle, outSize));
    }

    // ===================== Viewport/Font/Appearance =====================

    public static NativeBinaryResult setViewport(long handle, int width, int height) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_VIEWPORT.invokeExact(handle, (short) width, (short) height, outSize));
    }

    public static NativeBinaryResult onFontMetricsChanged(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) ON_FONT_METRICS_CHANGED.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult setFoldArrowMode(long handle, int mode) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_FOLD_ARROW_MODE.invokeExact(handle, mode, outSize));
    }

    public static NativeBinaryResult setWrapMode(long handle, int mode) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_WRAP_MODE.invokeExact(handle, mode, outSize));
    }

    public static NativeBinaryResult setTabSize(long handle, int tabSize) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_TAB_SIZE.invokeExact(handle, tabSize, outSize));
    }

    public static NativeBinaryResult setInsertSpaces(long handle, int enabled) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_INSERT_SPACES.invokeExact(handle, enabled, outSize));
    }

    public static NativeBinaryResult setScale(long handle, float scale) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_SCALE.invokeExact(handle, scale, outSize));
    }

    public static NativeBinaryResult setLineSpacing(long handle, float add, float mult) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_LINE_SPACING.invokeExact(handle, add, mult, outSize));
    }

    public static NativeBinaryResult setContentStartPadding(long handle, float padding) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_CONTENT_START_PADDING.invokeExact(handle, padding, outSize));
    }

    public static NativeBinaryResult setShowSplitLine(long handle, boolean show) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_SHOW_SPLIT_LINE.invokeExact(handle, show ? 1 : 0, outSize));
    }

    public static NativeBinaryResult setGutterSticky(long handle, boolean sticky) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_GUTTER_STICKY.invokeExact(handle, sticky ? 1 : 0, outSize));
    }

    public static NativeBinaryResult setGutterVisible(long handle, boolean visible) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_GUTTER_VISIBLE.invokeExact(handle, visible ? 1 : 0, outSize));
    }

    public static NativeBinaryResult setCurrentLineRenderMode(long handle, int mode) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_CURRENT_LINE_RENDER_MODE.invokeExact(handle, mode, outSize));
    }

    // ===================== Rendering =====================

    public static NativeBinaryResult buildRenderModel(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) BUILD_RENDER_MODEL.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult getLayoutMetrics(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) GET_LAYOUT_METRICS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult tickEdgeScroll(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) TICK_EDGE_SCROLL.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult tickFling(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) TICK_FLING.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult tickAnimations(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) TICK_ANIMATIONS.invokeExact(handle, outSize));
    }

    // ===================== Gesture/Keyboard Events =====================

    public static NativeBinaryResult handleGestureEvent(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) HANDLE_GESTURE.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult updatePointerModifiers(long handle, int modifiers) {
        return invokeBinaryResult(outSize -> (MemorySegment) UPDATE_POINTER_MODIFIERS.invokeExact(handle, (byte) modifiers, outSize));
    }

    public static NativeBinaryResult handleKeyEvent(long handle, int keyCode, String text, int modifiers, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) HANDLE_KEY_EVENT.invokeExact(handle,
                (short) keyCode, nullableString(arena, text), (byte) modifiers, outSize));
    }

    // ===================== Text Editing =====================

    public static NativeBinaryResult insertText(long handle, String text, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) INSERT_TEXT.invokeExact(handle, arena.allocateFrom(text), outSize));
    }

    public static NativeBinaryResult replaceText(long handle,
                                                 int startLine, int startColumn, int endLine, int endColumn,
                                                 String text, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) REPLACE_TEXT.invokeExact(handle,
                (long) startLine, (long) startColumn, (long) endLine, (long) endColumn,
                arena.allocateFrom(text), outSize));
    }

    public static NativeBinaryResult deleteText(long handle,
                                                int startLine, int startColumn, int endLine, int endColumn) {
        return invokeBinaryResult(outSize -> (MemorySegment) DELETE_TEXT.invokeExact(handle,
                (long) startLine, (long) startColumn, (long) endLine, (long) endColumn, outSize));
    }

    public static NativeBinaryResult backspace(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) BACKSPACE.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult deleteForward(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) DELETE_FORWARD.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult moveLineUp(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) MOVE_LINE_UP.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult moveLineDown(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) MOVE_LINE_DOWN.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult copyLineUp(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) COPY_LINE_UP.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult copyLineDown(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) COPY_LINE_DOWN.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult deleteLine(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) DELETE_LINE.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult insertLineAbove(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) INSERT_LINE_ABOVE.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult insertLineBelow(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) INSERT_LINE_BELOW.invokeExact(handle, outSize));
    }

    // ===================== Undo/Redo =====================

    public static NativeBinaryResult undo(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) UNDO.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult redo(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) REDO.invokeExact(handle, outSize));
    }

    public static boolean canUndo(long handle) {
        return invokeBoolean(() -> (int) CAN_UNDO.invokeExact(handle));
    }

    public static boolean canRedo(long handle) {
        return invokeBoolean(() -> (int) CAN_REDO.invokeExact(handle));
    }

    // ===================== Cursor/Selection =====================

    public static NativeBinaryResult setCursorPosition(long handle, int line, int column) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_CURSOR.invokeExact(handle, (long) line, (long) column, outSize));
    }

    public static NativeBinaryResult moveCursorLeft(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_LEFT.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static NativeBinaryResult moveCursorRight(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_RIGHT.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static NativeBinaryResult moveCursorUp(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_UP.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static NativeBinaryResult moveCursorDown(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_DOWN.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static NativeBinaryResult moveCursorToLineStart(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_TO_LINE_START.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static NativeBinaryResult moveCursorToLineEnd(long handle, boolean extendSelection) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) MOVE_CURSOR_TO_LINE_END.invokeExact(handle, extendSelection ? 1 : 0, outSize));
    }

    public static int[] getCursorPosition(long handle, Arena arena) {
        try {
            MemorySegment outLine = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outColumn = arena.allocate(ValueLayout.JAVA_LONG);
            GET_CURSOR.invokeExact(handle, outLine, outColumn);
            return new int[]{(int) outLine.get(ValueLayout.JAVA_LONG, 0), (int) outColumn.get(ValueLayout.JAVA_LONG, 0)};
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static NativeBinaryResult selectAll(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) SELECT_ALL.invokeExact(handle, outSize));
    }

    public static int[] getSelection(long handle, Arena arena) {
        try {
            MemorySegment outSL = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outSC = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outEL = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outEC = arena.allocate(ValueLayout.JAVA_LONG);
            int hasSelection = (int) GET_SELECTION.invokeExact(handle, outSL, outSC, outEL, outEC);
            if (hasSelection == 0) return null;
            return new int[]{
                    (int) outSL.get(ValueLayout.JAVA_LONG, 0), (int) outSC.get(ValueLayout.JAVA_LONG, 0),
                    (int) outEL.get(ValueLayout.JAVA_LONG, 0), (int) outEC.get(ValueLayout.JAVA_LONG, 0)
            };
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static NativeBinaryResult setSelection(long handle, int startLine, int startColumn, int endLine, int endColumn) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_SELECTION.invokeExact(
                handle, (long) startLine, (long) startColumn, (long) endLine, (long) endColumn, outSize));
    }

    public static String getSelectedText(long handle) {
        try {
            MemorySegment ptr = (MemorySegment) GET_SELECTED_TEXT.invokeExact(handle);
            if (ptr.equals(MemorySegment.NULL)) return "";
            return ptr.reinterpret(Long.MAX_VALUE).getString(0);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static int[] getWordRangeAtCursor(long handle, Arena arena) {
        try {
            MemorySegment outSL = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outSC = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outEL = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outEC = arena.allocate(ValueLayout.JAVA_LONG);
            GET_WORD_RANGE_AT_CURSOR.invokeExact(handle, outSL, outSC, outEL, outEC);
            return new int[]{
                    (int) outSL.get(ValueLayout.JAVA_LONG, 0), (int) outSC.get(ValueLayout.JAVA_LONG, 0),
                    (int) outEL.get(ValueLayout.JAVA_LONG, 0), (int) outEC.get(ValueLayout.JAVA_LONG, 0)
            };
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static String getWordAtCursor(long handle) {
        try {
            MemorySegment ptr = (MemorySegment) GET_WORD_AT_CURSOR.invokeExact(handle);
            if (ptr.equals(MemorySegment.NULL)) return "";
            return ptr.reinterpret(Long.MAX_VALUE).getString(0);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static String getLinkTargetAt(long handle, int line, int column) {
        try {
            MemorySegment ptr = (MemorySegment) GET_LINK_TARGET_AT.invokeExact(handle, (long) line, (long) column);
            String text = readUtf8String(ptr);
            if (ptr != null && !ptr.equals(MemorySegment.NULL)) {
                freeU8String(ptr.address());
            }
            return text;
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    // ===================== IME =====================

    public static boolean isComposing(long handle) {
        return invokeBoolean(() -> (int) IS_COMPOSING.invokeExact(handle));
    }

    public static int[] getComposingRange(long handle, Arena arena) {
        return readNativeRange(arena, GET_COMPOSING_RANGE, handle);
    }

    public static int[] getComposingSessionRange(long handle, Arena arena) {
        return readNativeRange(arena, GET_COMPOSING_SESSION_RANGE, handle);
    }

    private static int[] readNativeRange(Arena arena, MethodHandle method, long handle) {
        try {
            MemorySegment outSL = arena.allocate(ValueLayout.JAVA_INT);
            MemorySegment outSC = arena.allocate(ValueLayout.JAVA_INT);
            MemorySegment outEL = arena.allocate(ValueLayout.JAVA_INT);
            MemorySegment outEC = arena.allocate(ValueLayout.JAVA_INT);
            method.invokeExact(handle, outSL, outSC, outEL, outEC);
            return new int[]{
                    outSL.get(ValueLayout.JAVA_INT, 0), outSC.get(ValueLayout.JAVA_INT, 0),
                    outEL.get(ValueLayout.JAVA_INT, 0), outEC.get(ValueLayout.JAVA_INT, 0)
            };
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    public static NativeBinaryResult updateImePreedit(long handle, String text, int scriptHint, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) IME_UPDATE_PREEDIT.invokeExact(handle, nullableString(arena, text), scriptHint, outSize));
    }

    public static NativeBinaryResult setImeComposingText(long handle,
                                                         String text,
                                                         int cursorOffset,
                                                         int scriptHint,
                                                         Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_SET_COMPOSING_TEXT.invokeExact(
                handle, nullableString(arena, text), cursorOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult setImeComposingTextSelection(long handle,
                                                                  String text,
                                                                  long selectionStartOffset,
                                                                  long selectionEndOffset,
                                                                  int scriptHint,
                                                                  Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_SET_COMPOSING_TEXT_SELECTION.invokeExact(
                handle, nullableString(arena, text), selectionStartOffset, selectionEndOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult commitImeText(long handle, String text, int scriptHint, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) IME_COMMIT_TEXT.invokeExact(handle, nullableString(arena, text), scriptHint, outSize));
    }

    public static NativeBinaryResult finishImePreedit(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_FINISH_PREEDIT.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult cancelImePreedit(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_CANCEL_PREEDIT.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult markImeDocumentRange(long handle,
                                                          int startLine, int startColumn,
                                                          int endLine, int endColumn,
                                                          int scriptHint) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_MARK_DOCUMENT_RANGE.invokeExact(
                handle,
                (long) startLine, (long) startColumn, (long) endLine, (long) endColumn,
                scriptHint, outSize));
    }

    public static NativeBinaryResult markImeDocumentRangeByOffset(long handle,
                                                                  long startOffset,
                                                                  long endOffset,
                                                                  int scriptHint) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_MARK_DOCUMENT_RANGE_BY_OFFSET.invokeExact(
                handle, startOffset, endOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult replaceImeText(long handle,
                                                    int startLine, int startColumn,
                                                    int endLine, int endColumn,
                                                    String text,
                                                    int scriptHint,
                                                    Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_REPLACE_TEXT.invokeExact(
                handle,
                (long) startLine, (long) startColumn, (long) endLine, (long) endColumn,
                nullableString(arena, text), scriptHint, outSize));
    }

    public static NativeBinaryResult replaceImeDocumentText(long handle,
                                                            long startOffset,
                                                            long endOffset,
                                                            String text,
                                                            int cursorOffset,
                                                            int scriptHint,
                                                            Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_REPLACE_DOCUMENT_TEXT.invokeExact(
                handle, startOffset, endOffset, nullableString(arena, text), cursorOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult replaceImeInputContextText(long handle,
                                                                long startOffset,
                                                                long endOffset,
                                                                String text,
                                                                int cursorOffset,
                                                                int scriptHint,
                                                                Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_REPLACE_INPUT_CONTEXT_TEXT.invokeExact(
                handle, startOffset, endOffset, nullableString(arena, text), cursorOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult markImeInputContextRange(long handle,
                                                              long startOffset,
                                                              long endOffset,
                                                              int scriptHint) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_MARK_INPUT_CONTEXT_RANGE.invokeExact(
                handle, startOffset, endOffset, scriptHint, outSize));
    }

    public static NativeBinaryResult notifyImeDocumentSelectionChanged(long handle,
                                                                       long startOffset,
                                                                       long endOffset) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_NOTIFY_DOCUMENT_SELECTION_CHANGED.invokeExact(
                handle, startOffset, endOffset, outSize));
    }

    public static NativeBinaryResult notifyImeInputContextSelectionChanged(long handle,
                                                                           long startOffset,
                                                                           long endOffset) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_NOTIFY_INPUT_CONTEXT_SELECTION_CHANGED.invokeExact(
                handle, startOffset, endOffset, outSize));
    }

    public static NativeBinaryResult updateImeInputStateText(long handle,
                                                             long contextId,
                                                             int documentStartOffset,
                                                             String text,
                                                             int selectionStartOffset,
                                                             int selectionEndOffset,
                                                             int composingStartOffset,
                                                             int composingEndOffset,
                                                             int scriptHint,
                                                             Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_UPDATE_INPUT_STATE_TEXT.invokeExact(
                handle,
                contextId,
                documentStartOffset,
                nullableString(arena, text),
                selectionStartOffset,
                selectionEndOffset,
                composingStartOffset,
                composingEndOffset,
                scriptHint,
                outSize));
    }

    public static NativeBinaryResult updateImeInputStateSelection(long handle,
                                                                  long contextId,
                                                                  int documentStartOffset,
                                                                  int selectionStartOffset,
                                                                  int selectionEndOffset) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_UPDATE_INPUT_STATE_SELECTION.invokeExact(
                handle,
                contextId,
                documentStartOffset,
                selectionStartOffset,
                selectionEndOffset,
                outSize));
    }

    public static NativeBinaryResult replaceImeInputStateText(long handle,
                                                              long contextId,
                                                              int documentStartOffset,
                                                              long startOffset,
                                                              long endOffset,
                                                              String text,
                                                              int cursorOffset,
                                                              int scriptHint,
                                                              Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) IME_REPLACE_INPUT_STATE_TEXT.invokeExact(
                handle,
                contextId,
                documentStartOffset,
                startOffset,
                endOffset,
                nullableString(arena, text),
                cursorOffset,
                scriptHint,
                outSize));
    }

    public static NativeBinaryResult deleteImeBackward(long handle, long beforeLength, int textUnit) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) IME_DELETE_BACKWARD.invokeExact(handle, beforeLength, textUnit, outSize));
    }

    public static NativeBinaryResult deleteImeForward(long handle, long afterLength, int textUnit) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) IME_DELETE_FORWARD.invokeExact(handle, afterLength, textUnit, outSize));
    }

    public static NativeBinaryResult deleteImeSurrounding(long handle,
                                                          long beforeLength,
                                                          long afterLength,
                                                          int textUnit) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_DELETE_SURROUNDING.invokeExact(
                handle, beforeLength, afterLength, textUnit, outSize));
    }

    public static NativeBinaryResult notifyImeSelectionChanged(long handle,
                                                               int startLine, int startColumn,
                                                               int endLine, int endColumn) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_NOTIFY_SELECTION_CHANGED.invokeExact(
                handle,
                (long) startLine, (long) startColumn, (long) endLine, (long) endColumn,
                outSize));
    }

    public static NativeBinaryResult notifyImeCursorChanged(long handle, int cursorLine, int cursorColumn) {
        return invokeBinaryResult(outSize -> (MemorySegment) IME_NOTIFY_CURSOR_CHANGED.invokeExact(
                handle, (long) cursorLine, (long) cursorColumn, outSize));
    }

    public static NativeBinaryResult setImeKeyboardScriptClass(long handle, int scriptClass) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) IME_SET_KEYBOARD_SCRIPT_CLASS.invokeExact(handle, scriptClass, outSize));
    }

    public static int getImeKeyboardScriptClass(long handle) {
        return invokeValue(() -> (int) IME_GET_KEYBOARD_SCRIPT_CLASS.invokeExact(handle));
    }

    public static NativeBinaryResult getImeSyncSnapshot(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) GET_IME_SYNC_SNAPSHOT.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult getImeInputContext(long handle, long beforeLength, long afterLength) {
        return invokeBinaryResult(outSize -> (MemorySegment) GET_IME_INPUT_CONTEXT.invokeExact(
                handle, beforeLength, afterLength, outSize));
    }

    // ===================== Read-only =====================

    public static NativeBinaryResult setReadOnly(long handle, boolean readOnly) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_READ_ONLY.invokeExact(handle, readOnly ? 1 : 0, outSize));
    }

    public static boolean isReadOnly(long handle) {
        return invokeValue(() -> (int) IS_READ_ONLY.invokeExact(handle)) != 0;
    }

    // ===================== Auto-indent =====================

    public static NativeBinaryResult setAutoIndentMode(long handle, int mode) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_AUTO_INDENT_MODE.invokeExact(handle, mode, outSize));
    }

    public static int getAutoIndentMode(long handle) {
        return invokeValue(() -> (int) GET_AUTO_INDENT_MODE.invokeExact(handle));
    }

    public static NativeBinaryResult setBackspaceUnindent(long handle, int enabled) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BACKSPACE_UNINDENT.invokeExact(handle, enabled, outSize));
    }

    // ===================== Handle Config =====================

    public static NativeBinaryResult setHandleConfig(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_HANDLE_CONFIG.invokeExact(
                handle, payload, size, outSize));
    }

    public static NativeBinaryResult setScrollbarConfig(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_SCROLLBAR_CONFIG.invokeExact(
                handle, payload, size, outSize));
    }

    // ===================== Position/Coordinate Query =====================

    public static float[] getPositionRect(long handle, int line, int column, Arena arena) {
        MemorySegment px = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment py = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment ph = arena.allocate(ValueLayout.JAVA_FLOAT);
        try {
            GET_POSITION_RECT.invokeExact(handle, (long) line, (long) column, px, py, ph);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
        return new float[]{px.get(ValueLayout.JAVA_FLOAT, 0), py.get(ValueLayout.JAVA_FLOAT, 0), ph.get(ValueLayout.JAVA_FLOAT, 0)};
    }

    public static float[] getCursorRect(long handle, Arena arena) {
        MemorySegment px = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment py = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment ph = arena.allocate(ValueLayout.JAVA_FLOAT);
        try {
            GET_CURSOR_RECT.invokeExact(handle, px, py, ph);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
        return new float[]{px.get(ValueLayout.JAVA_FLOAT, 0), py.get(ValueLayout.JAVA_FLOAT, 0), ph.get(ValueLayout.JAVA_FLOAT, 0)};
    }

    public static IntRange getVisibleLineRange(long handle, Arena arena) {
        MemorySegment startLine = arena.allocate(ValueLayout.JAVA_INT);
        MemorySegment endLine = arena.allocate(ValueLayout.JAVA_INT);
        try {
            GET_VISIBLE_LINE_RANGE.invokeExact(handle, startLine, endLine);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
        return new IntRange(startLine.get(ValueLayout.JAVA_INT, 0), endLine.get(ValueLayout.JAVA_INT, 0));
    }

    // ===================== Linked Editing =====================

    public static NativeBinaryResult insertSnippet(long handle, String snippetTemplate, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) INSERT_SNIPPET.invokeExact(handle, arena.allocateFrom(snippetTemplate), outSize));
    }

    public static NativeBinaryResult startLinkedEditing(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) START_LINKED_EDITING.invokeExact(
                handle, byteArraySegment(arena, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult startLinkedEditing(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) START_LINKED_EDITING.invokeExact(handle, payload, size, outSize));
    }

    public static boolean isInLinkedEditing(long handle) {
        return invokeBoolean(() -> (int) IS_IN_LINKED_EDITING.invokeExact(handle));
    }

    public static NativeBinaryResult linkedEditingNext(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) LINKED_EDITING_NEXT.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult linkedEditingPrev(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) LINKED_EDITING_PREV.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult cancelLinkedEditing(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CANCEL_LINKED_EDITING.invokeExact(handle, outSize));
    }

    // ===================== Scroll/Navigation =====================

    public static NativeBinaryResult scrollToLine(long handle, int line, int behavior) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SCROLL_TO_LINE.invokeExact(handle, (long) line, (byte) behavior, outSize));
    }

    public static NativeBinaryResult gotoLine(long handle, int line, int column) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) GOTO_LINE.invokeExact(handle, (long) line, (long) column, outSize));
    }

    public static NativeBinaryResult ensureCursorVisible(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) ENSURE_CURSOR_VISIBLE.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult setScroll(long handle, float scrollX, float scrollY) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_SCROLL.invokeExact(handle, scrollX, scrollY, outSize));
    }

    public static NativeBinaryResult getScrollMetrics(long handle, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) GET_SCROLL_METRICS.invokeExact(handle, outSize));
    }

    // ===================== Style/Highlight =====================

    public static NativeBinaryResult registerTextStyle(long handle, int styleId, int color, int bgColor, int fontStyle) {
        return invokeBinaryResult(outSize -> (MemorySegment) REGISTER_TEXT_STYLE.invokeExact(
                handle, styleId, color, bgColor, fontStyle, outSize));
    }

    public static NativeBinaryResult registerBatchTextStyles(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) REGISTER_BATCH_TEXT_STYLES.invokeExact(
                handle, byteArraySegment(arena, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult registerBatchTextStyles(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) REGISTER_BATCH_TEXT_STYLES.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setLineSpans(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_SPANS.invokeExact(
                handle, byteArraySegment(arena, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setLineSpans(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_LINE_SPANS.invokeExact(handle, payload, size, outSize));
    }

    // ===================== InlayHint / PhantomText =====================


    // ===================== Gutter Icons =====================


    public static NativeBinaryResult clearGutterIcons(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_GUTTER_ICONS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult setMaxGutterIcons(long handle, int count) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_MAX_GUTTER_ICONS.invokeExact(handle, count, outSize));
    }

    // ===================== Diagnostic Decorations =====================

    public static NativeBinaryResult setLineDiagnostics(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_DIAGNOSTICS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setLineDiagnostics(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_LINE_DIAGNOSTICS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult clearDiagnostics(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_DIAGNOSTICS.invokeExact(handle, outSize));
    }

    // ===================== Guide =====================


    public static NativeBinaryResult clearGuides(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_GUIDES.invokeExact(handle, outSize));
    }

    // ===================== Bracket Pair Highlight =====================

    public static NativeBinaryResult setBracketPairs(long handle, int[] openChars, int[] closeChars, Arena arena) {
        return invokeBinaryResult(arena, outSize -> {
            MemorySegment openSeg = arena.allocateFrom(ValueLayout.JAVA_INT, openChars);
            MemorySegment closeSeg = arena.allocateFrom(ValueLayout.JAVA_INT, closeChars);
            return (MemorySegment) SET_BRACKET_PAIRS.invokeExact(handle, openSeg, closeSeg, (long) openChars.length,
                    outSize);
        });
    }

    public static NativeBinaryResult setAutoClosingPairs(long handle, int[] openChars, int[] closeChars, Arena arena) {
        return invokeBinaryResult(arena, outSize -> {
            MemorySegment openSeg = arena.allocateFrom(ValueLayout.JAVA_INT, openChars);
            MemorySegment closeSeg = arena.allocateFrom(ValueLayout.JAVA_INT, closeChars);
            return (MemorySegment) SET_AUTO_CLOSING_PAIRS.invokeExact(handle, openSeg, closeSeg,
                    (long) openChars.length, outSize);
        });
    }

    public static NativeBinaryResult setMatchedBrackets(long handle, int openLine, int openCol, int closeLine, int closeCol) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_MATCHED_BRACKETS.invokeExact(
                handle, (long) openLine, (long) openCol, (long) closeLine, (long) closeCol, outSize));
    }

    public static NativeBinaryResult clearMatchedBrackets(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_MATCHED_BRACKETS.invokeExact(handle, outSize));
    }

    // ===================== Fold =====================

    public static NativeBinaryResult setFoldRegions(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_FOLD_REGIONS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setFoldRegions(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_FOLD_REGIONS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult toggleFold(long handle, int line) {
        return invokeBinaryResult(outSize -> (MemorySegment) TOGGLE_FOLD.invokeExact(handle, (long) line, outSize));
    }

    public static NativeBinaryResult foldAt(long handle, int line) {
        return invokeBinaryResult(outSize -> (MemorySegment) FOLD_AT.invokeExact(handle, (long) line, outSize));
    }

    public static NativeBinaryResult unfoldAt(long handle, int line) {
        return invokeBinaryResult(outSize -> (MemorySegment) UNFOLD_AT.invokeExact(handle, (long) line, outSize));
    }

    public static NativeBinaryResult foldAll(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) FOLD_ALL.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult unfoldAll(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) UNFOLD_ALL.invokeExact(handle, outSize));
    }

    public static boolean isLineVisible(long handle, int line) {
        try {
            return ((int) IS_LINE_VISIBLE.invokeExact(handle, (long) line)) != 0;
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    // ===================== Clear =====================

    public static NativeBinaryResult clearHighlights(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_HIGHLIGHTS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult clearLineSpans(long handle, int line, int layer) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) CLEAR_LINE_SPANS.invokeExact(handle, (long) line, (byte) layer, outSize));
    }

    public static NativeBinaryResult clearHighlightsLayer(long handle, int layer) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) CLEAR_HIGHLIGHTS_LAYER.invokeExact(handle, (byte) layer, outSize));
    }

    public static NativeBinaryResult clearInlayHints(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_INLAY_HINTS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult clearPhantomTexts(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_PHANTOM_TEXTS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult clearAllDecorations(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_ALL_DECORATIONS.invokeExact(handle, outSize));
    }

    // ===================== Binary Payload Methods =====================

    public static NativeBinaryResult setLineInlayHints(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_INLAY_HINTS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setLineInlayHints(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_LINE_INLAY_HINTS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineInlayHints(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_INLAY_HINTS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBatchLineInlayHints(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_INLAY_HINTS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setLinePhantomTexts(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_PHANTOM_TEXTS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setLinePhantomTexts(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_LINE_PHANTOM_TEXTS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLinePhantomTexts(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_PHANTOM_TEXTS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBatchLinePhantomTexts(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_PHANTOM_TEXTS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setLineGutterIcons(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_GUTTER_ICONS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setLineGutterIcons(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_LINE_GUTTER_ICONS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineGutterIcons(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_GUTTER_ICONS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBatchLineGutterIcons(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_GUTTER_ICONS.invokeExact(handle, payload, size, outSize));
    }

    // ===================== CodeLens =====================

    public static NativeBinaryResult clearCodeLens(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_CODELENS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult setLineCodeLens(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_CODELENS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult setLineCodeLens(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_LINE_CODELENS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineCodeLens(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_CODELENS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult setBatchLineCodeLens(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_CODELENS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult clearLinks(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) CLEAR_LINKS.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult setLineLinks(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_LINE_LINKS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult setLineLinks(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_LINE_LINKS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineLinks(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_LINKS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult setBatchLineLinks(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_LINKS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineSpans(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_SPANS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBatchLineSpans(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_SPANS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBatchLineDiagnostics(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BATCH_LINE_DIAGNOSTICS.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBatchLineDiagnostics(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BATCH_LINE_DIAGNOSTICS.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setKeyMap(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_KEYMAP.invokeExact(
                handle, byteArraySegment(arena, payload), (long) payload.length, outSize));
    }

    public static NativeBinaryResult setKeyMap(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_KEYMAP.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setIndentGuides(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_INDENT_GUIDES.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setIndentGuides(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_INDENT_GUIDES.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setBracketGuides(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_BRACKET_GUIDES.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setBracketGuides(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_BRACKET_GUIDES.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setFlowGuides(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_FLOW_GUIDES.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setFlowGuides(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize -> (MemorySegment) SET_FLOW_GUIDES.invokeExact(handle, payload, size, outSize));
    }

    public static NativeBinaryResult setSeparatorGuides(long handle, byte[] payload, Arena arena) {
        return invokeBinaryResult(arena, outSize -> (MemorySegment) SET_SEPARATOR_GUIDES.invokeExact(
                handle, arena.allocateFrom(ValueLayout.JAVA_BYTE, payload), (long) payload.length, outSize));
    }

    /**
     * Zero-copy overload: pass pre-encoded MemorySegment directly
     */
    public static NativeBinaryResult setSeparatorGuides(long handle, MemorySegment payload, long size) {
        return invokeBinaryResult(outSize ->
                (MemorySegment) SET_SEPARATOR_GUIDES.invokeExact(handle, payload, size, outSize));
    }

    // ===================== Utilities =====================

    public static void freeBinaryData(long ptr) {
        invokeVoid(() -> {
            FREE_BINARY_DATA.invokeExact(ptr);
        });
    }

    public static void freeU8String(long ptr) {
        invokeVoid(() -> {
            FREE_U8_STRING.invokeExact(ptr);
        });
    }

    public static void freeU16String(long ptr) {
        invokeVoid(() -> {
            FREE_U16_STRING.invokeExact(ptr);
        });
    }

    /**
     * Read the null-terminated UTF-8 string returned by C++
     */
    public static String readUtf8String(MemorySegment ptr) {
        if (ptr.equals(MemorySegment.NULL)) return null;
        return ptr.reinterpret(Long.MAX_VALUE).getString(0);
    }

    /**
     * Read the null-terminated UTF-16LE string returned by C++
     */
    public static String readUtf16String(MemorySegment ptr) {
        if (ptr.equals(MemorySegment.NULL)) return null;
        // Reinterpret to a large region to scan for null terminator
        MemorySegment reinterpreted = ptr.reinterpret(Long.MAX_VALUE);
        // Find null terminator (2-byte aligned)
        long offset = 0;
        while (reinterpreted.get(ValueLayout.JAVA_SHORT, offset) != 0) {
            offset += 2;
        }
        if (offset == 0) return "";
        byte[] bytes = new byte[(int) offset];
        MemorySegment.copy(reinterpreted, ValueLayout.JAVA_BYTE, 0, bytes, 0, bytes.length);
        return new String(bytes, StandardCharsets.UTF_16LE);
    }

    /**
     * Create upcall stub
     */
    public static MemorySegment createUpcallStub(Arena arena, Object target, Class<?> ownerType,
                                                 String methodName, MethodType methodType, FunctionDescriptor desc) {
        try {
            MethodHandle mh = MethodHandles.publicLookup()
                    .findVirtual(ownerType, methodName, methodType)
                    .bindTo(target);
            return LINKER.upcallStub(mh, desc, arena);
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    private EditorNative() {
    }
}
