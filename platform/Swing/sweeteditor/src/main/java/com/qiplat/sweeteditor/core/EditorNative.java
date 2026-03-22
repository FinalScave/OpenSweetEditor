package com.qiplat.sweeteditor.core;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
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
    private static final String[] LIB_SEARCH_PATHS = {
            "../../cmake-build-release-visual-studio/bin/Release",
            "../../cmake-build-release-visual-studio/bin/Debug",
            "../../cmake-build-release-visual-studio/bin",
            "../../cmake-build-release/bin",
            "../../cmake-build-debug-visual-studio/bin/Debug",
            "../../cmake-build-debug-visual-studio/bin",
            "../../cmake-build-debug/bin",
            "../../cmake-build-debug/lib",
            "../../build/bin",
            "../../build/lib",
            "../../build/mac/lib",
    };
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
        // Auto-detect from source-relative paths during development
        lookup = tryLoadFromCandidates(libName, LIB_SEARCH_PATHS);
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

    private static SymbolLookup tryLoadFromCandidates(String libName, String[] searchPaths) {
        for (String searchPath : searchPaths) {
            SymbolLookup lookup = lookupLibrary(Path.of(searchPath, libName).toAbsolutePath().normalize());
            if (lookup != null) {
                return lookup;
            }
        }
        return null;
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

        /** Whether there is valid data */
        boolean hasData() {
            return ptr != null && !ptr.equals(MemorySegment.NULL) && size > 0;
        }

        /**
         * Zero-copy ByteBuffer view, directly reading native memory.
         * <p>
         * Note: The returned ByteBuffer must not be used after calling {@link #free()}.
         */
        ByteBuffer asByteBuffer() {
            if (!hasData()) return null;
            return ptr.asByteBuffer().order(ByteOrder.nativeOrder());
        }

        /** Release memory allocated by the native side */
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

    private static final MethodHandle GET_DOCUMENT_LINE_TEXT = downcall("get_document_line_text",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_DOCUMENT_LINE_COUNT = downcall("get_document_line_count",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle CREATE_EDITOR = downcall("create_editor",
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, MEASURER_LAYOUT, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_EDITOR_DOCUMENT = downcall("set_editor_document",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_VIEWPORT = downcall("set_editor_viewport",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_SHORT, ValueLayout.JAVA_SHORT));

    private static final MethodHandle SET_FOLD_ARROW_MODE = downcall("editor_set_fold_arrow_mode",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle SET_LINE_SPACING = downcall("editor_set_line_spacing",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT));

    private static final MethodHandle SET_CONTENT_START_PADDING = downcall("editor_set_content_start_padding",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT));

    private static final MethodHandle SET_SHOW_SPLIT_LINE = downcall("editor_set_show_split_line",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle SET_CURRENT_LINE_RENDER_MODE = downcall("editor_set_current_line_render_mode",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle BUILD_RENDER_MODEL = downcall("build_editor_render_model",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle TICK_EDGE_SCROLL = downcall("editor_tick_edge_scroll",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle HANDLE_GESTURE_EX = downcall("handle_editor_gesture_event_ex",
            FunctionDescriptor.of(ValueLayout.ADDRESS,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE, ValueLayout.JAVA_BYTE, ValueLayout.ADDRESS,
                    ValueLayout.JAVA_BYTE, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT, ValueLayout.ADDRESS));

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
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle SELECT_ALL = downcall("editor_select_all",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_SELECTION = downcall("editor_get_selection",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle GET_WORD_RANGE_AT_CURSOR = downcall("editor_get_word_range_at_cursor",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle COMP_START = downcall("editor_composition_start",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle COMP_END = downcall("editor_composition_end",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle IS_COMPOSING = downcall("editor_is_composing",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_READ_ONLY = downcall("editor_set_read_only",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle IS_READ_ONLY = downcall("editor_is_read_only",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_AUTO_INDENT_MODE = downcall("editor_set_auto_indent_mode",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle GET_POSITION_RECT = downcall("editor_get_position_rect",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_SNIPPET = downcall("editor_insert_snippet",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle IS_IN_LINKED_EDITING = downcall("editor_is_in_linked_editing",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle LINKED_EDITING_PREV = downcall("editor_linked_editing_prev",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SCROLL_TO_LINE = downcall("editor_scroll_to_line",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE));

    private static final MethodHandle SET_SCROLL = downcall("editor_set_scroll",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT));

    private static final MethodHandle REGISTER_TEXT_STYLE = downcall("editor_register_text_style",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.JAVA_INT, ValueLayout.JAVA_INT));





    private static final MethodHandle CLEAR_GUTTER_ICONS = downcall("editor_clear_gutter_icons",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_LINE_DIAGNOSTICS = downcall("editor_set_line_diagnostics",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));



    private static final MethodHandle CLEAR_GUIDES = downcall("editor_clear_guides",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_BRACKET_PAIRS = downcall("editor_set_bracket_pairs",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_MATCHED_BRACKETS = downcall("editor_clear_matched_brackets",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_FOLD_REGIONS = downcall("editor_set_fold_regions",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle FOLD_AT = downcall("editor_fold_at",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle FOLD_ALL = downcall("editor_fold_all",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle IS_LINE_VISIBLE = downcall("editor_is_line_visible",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_HIGHLIGHTS = downcall("editor_clear_highlights",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_INLAY_HINTS = downcall("editor_clear_inlay_hints",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_ALL_DECORATIONS = downcall("editor_clear_all_decorations",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_BINARY_DATA = downcall("free_binary_data",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_DOCUMENT = downcall("free_document",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle FREE_EDITOR = downcall("free_editor",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle RESET_MEASURER = downcall("reset_editor_text_measurer",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle HANDLE_KEY_EVENT = downcall("handle_editor_key_event",
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

    private static final MethodHandle COMP_UPDATE = downcall("editor_composition_update",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle GET_AUTO_INDENT_MODE = downcall("editor_get_auto_indent_mode",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_HANDLE_CONFIG = downcall("editor_set_handle_config",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT,
                    ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT));

    private static final MethodHandle SET_SCROLLBAR_CONFIG = downcall("editor_set_scrollbar_config",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT, ValueLayout.JAVA_FLOAT,
                    ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT,
                    ValueLayout.JAVA_INT, ValueLayout.JAVA_INT));

    private static final MethodHandle GET_CURSOR_RECT = downcall("editor_get_cursor_rect",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG,
                    ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.ADDRESS));

    private static final MethodHandle START_LINKED_EDITING = downcall("editor_start_linked_editing",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));

    private static final MethodHandle CANCEL_LINKED_EDITING = downcall("editor_cancel_linked_editing",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle GOTO_LINE = downcall("editor_goto_position",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_LINE_SPANS = downcall("editor_set_line_spans",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG));





    private static final MethodHandle CLEAR_DIAGNOSTICS = downcall("editor_clear_diagnostics",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));



    private static final MethodHandle SET_MATCHED_BRACKETS = downcall("editor_set_matched_brackets",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle TOGGLE_FOLD = downcall("editor_toggle_fold",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle UNFOLD_ALL = downcall("editor_unfold_all",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_HIGHLIGHTS_LAYER = downcall("editor_clear_highlights_layer",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_BYTE));

    private static final MethodHandle FREE_U16_STRING = downcall("free_u16_string",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_WRAP_MODE = downcall("editor_set_wrap_mode",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));

    private static final MethodHandle SET_SCALE = downcall("editor_set_scale",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_FLOAT));

    private static final MethodHandle BACKSPACE = downcall("editor_backspace",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle COPY_LINE_UP = downcall("editor_copy_line_up",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle INSERT_LINE_BELOW = downcall("editor_insert_line_below",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));

    private static final MethodHandle CAN_REDO = downcall("editor_can_redo",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle SET_SELECTION = downcall("editor_set_selection",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG,
                    ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle COMP_CANCEL = downcall("editor_composition_cancel",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    private static final MethodHandle LINKED_EDITING_NEXT = downcall("editor_linked_editing_next",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG));

    private static final MethodHandle GET_SCROLL_METRICS = downcall("editor_get_scroll_metrics",
            FunctionDescriptor.of(ValueLayout.ADDRESS, ValueLayout.JAVA_LONG, ValueLayout.ADDRESS));



    private static final MethodHandle SET_MAX_GUTTER_ICONS = downcall("editor_set_max_gutter_icons",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.JAVA_INT));



    private static final MethodHandle UNFOLD_AT = downcall("editor_unfold_at",
            FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG));

    private static final MethodHandle CLEAR_PHANTOM_TEXTS = downcall("editor_clear_phantom_texts",
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG));

    // ===================== Binary payload API =====================

    private static final FunctionDescriptor BINARY_PAYLOAD_DESC =
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG, ValueLayout.ADDRESS, ValueLayout.JAVA_LONG);

    private static final MethodHandle SET_LINE_INLAY_HINTS = downcall("editor_set_line_inlay_hints", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_INLAY_HINTS = downcall("editor_set_batch_line_inlay_hints", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_PHANTOM_TEXTS = downcall("editor_set_line_phantom_texts", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_PHANTOM_TEXTS = downcall("editor_set_batch_line_phantom_texts", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_LINE_GUTTER_ICONS = downcall("editor_set_line_gutter_icons", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_GUTTER_ICONS = downcall("editor_set_batch_line_gutter_icons", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_SPANS = downcall("editor_set_batch_line_spans", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BATCH_LINE_DIAGNOSTICS = downcall("editor_set_batch_line_diagnostics", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_INDENT_GUIDES = downcall("editor_set_indent_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_BRACKET_GUIDES = downcall("editor_set_bracket_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_FLOW_GUIDES = downcall("editor_set_flow_guides", BINARY_PAYLOAD_DESC);
    private static final MethodHandle SET_SEPARATOR_GUIDES = downcall("editor_set_separator_guides", BINARY_PAYLOAD_DESC);

    // ===================== Document API =====================

    public static long createDocument(Arena arena, String text) {
        try {
            MemorySegment utf16 = arena.allocateFrom(text, StandardCharsets.UTF_16LE);
            return (long) CREATE_DOCUMENT.invokeExact(utf16);
        } catch (Throwable t) { throw new RuntimeException(t); }
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
        } catch (Throwable t) { throw new RuntimeException(t); }
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

    /** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static long createEditor(MemorySegment measurer, MemorySegment optionsSeg, long optionsSize) {
        return invokeValue(() -> (long) CREATE_EDITOR.invokeExact(measurer, optionsSeg, optionsSize));
    }

    public static void freeEditor(long handle) {
        invokeVoid(() -> {
            FREE_EDITOR.invokeExact(handle);
        });
    }

    public static void setEditorDocument(long editorHandle, long documentHandle) {
        invokeVoid(() -> {
            SET_EDITOR_DOCUMENT.invokeExact(editorHandle, documentHandle);
        });
    }

    // ===================== Viewport/Font/Appearance =====================

    public static void setViewport(long handle, int width, int height) {
        invokeVoid(() -> {
            SET_VIEWPORT.invokeExact(handle, (short) width, (short) height);
        });
    }

    public static void resetMeasurer(long handle) {
        invokeVoid(() -> {
            RESET_MEASURER.invokeExact(handle);
        });
    }

    public static void setFoldArrowMode(long handle, int mode) {
        invokeVoid(() -> {
            SET_FOLD_ARROW_MODE.invokeExact(handle, mode);
        });
    }

    public static void setWrapMode(long handle, int mode) {
        invokeVoid(() -> {
            SET_WRAP_MODE.invokeExact(handle, mode);
        });
    }

    public static void setScale(long handle, float scale) {
        invokeVoid(() -> {
            SET_SCALE.invokeExact(handle, scale);
        });
    }

    public static void setLineSpacing(long handle, float add, float mult) {
        invokeVoid(() -> {
            SET_LINE_SPACING.invokeExact(handle, add, mult);
        });
    }

    public static void setContentStartPadding(long handle, float padding) {
        invokeVoid(() -> {
            SET_CONTENT_START_PADDING.invokeExact(handle, padding);
        });
    }

    public static void setShowSplitLine(long handle, boolean show) {
        invokeVoid(() -> {
            SET_SHOW_SPLIT_LINE.invokeExact(handle, show ? 1 : 0);
        });
    }

    public static void setCurrentLineRenderMode(long handle, int mode) {
        invokeVoid(() -> {
            SET_CURRENT_LINE_RENDER_MODE.invokeExact(handle, mode);
        });
    }

    // ===================== Rendering =====================

    public static NativeBinaryResult buildRenderModel(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) BUILD_RENDER_MODEL.invokeExact(handle, outSize));
    }

    public static NativeBinaryResult tickEdgeScroll(long handle) {
        return invokeBinaryResult(outSize -> (MemorySegment) TICK_EDGE_SCROLL.invokeExact(handle, outSize));
    }

    // ===================== Gesture/Keyboard Events =====================

    public static NativeBinaryResult handleGestureEventEx(long handle, int type, int pointerCount, Arena arena, float[] points,
                                               int modifiers, float wheelDeltaX, float wheelDeltaY, float directScale) {
        return invokeBinaryResult(arena, outSize -> {
            MemorySegment pointsSeg = arena.allocateFrom(ValueLayout.JAVA_FLOAT, points);
            return (MemorySegment) HANDLE_GESTURE_EX.invokeExact(handle,
                    (byte) type, (byte) pointerCount, pointsSeg,
                    (byte) modifiers, wheelDeltaX, wheelDeltaY, directScale, outSize);
        });
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

    public static void setCursorPosition(long handle, int line, int column) {
        invokeVoid(() -> {
            SET_CURSOR.invokeExact(handle, (long) line, (long) column);
        });
    }

    public static int[] getCursorPosition(long handle, Arena arena) {
        try {
            MemorySegment outLine = arena.allocate(ValueLayout.JAVA_LONG);
            MemorySegment outColumn = arena.allocate(ValueLayout.JAVA_LONG);
            GET_CURSOR.invokeExact(handle, outLine, outColumn);
            return new int[]{(int) outLine.get(ValueLayout.JAVA_LONG, 0), (int) outColumn.get(ValueLayout.JAVA_LONG, 0)};
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void selectAll(long handle) {
        invokeVoid(() -> {
            SELECT_ALL.invokeExact(handle);
        });
    }

    public static void setSelection(long handle, int startLine, int startColumn, int endLine, int endColumn) {
        invokeVoid(() -> {
            SET_SELECTION.invokeExact(handle, (long) startLine, (long) startColumn, (long) endLine, (long) endColumn);
        });
    }

    public static String getSelectedText(long handle) {
        try {
            MemorySegment ptr = (MemorySegment) GET_SELECTED_TEXT.invokeExact(handle);
            if (ptr.equals(MemorySegment.NULL)) return "";
            return ptr.reinterpret(Long.MAX_VALUE).getString(0);
        } catch (Throwable t) { throw new RuntimeException(t); }
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
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static String getWordAtCursor(long handle) {
        try {
            MemorySegment ptr = (MemorySegment) GET_WORD_AT_CURSOR.invokeExact(handle);
            if (ptr.equals(MemorySegment.NULL)) return "";
            return ptr.reinterpret(Long.MAX_VALUE).getString(0);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== IME =====================

    public static void compositionStart(long handle) {
        invokeVoid(() -> {
            COMP_START.invokeExact(handle);
        });
    }

    public static void compositionUpdate(long handle, String text, Arena arena) {
        invokeVoid(() -> {
            COMP_UPDATE.invokeExact(handle, arena.allocateFrom(text));
        });
    }

    public static NativeBinaryResult compositionEnd(long handle, String text, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) COMP_END.invokeExact(handle, nullableString(arena, text), outSize));
    }

    public static void compositionCancel(long handle) {
        invokeVoid(() -> {
            COMP_CANCEL.invokeExact(handle);
        });
    }

    public static boolean isComposing(long handle) {
        return invokeBoolean(() -> (int) IS_COMPOSING.invokeExact(handle));
    }

    // ===================== Read-only =====================

    public static void setReadOnly(long handle, boolean readOnly) {
        invokeVoid(() -> {
            SET_READ_ONLY.invokeExact(handle, readOnly ? 1 : 0);
        });
    }

    public static boolean isReadOnly(long handle) {
        return invokeValue(() -> (int) IS_READ_ONLY.invokeExact(handle)) != 0;
    }

    // ===================== Auto-indent =====================

    public static void setAutoIndentMode(long handle, int mode) {
        invokeVoid(() -> {
            SET_AUTO_INDENT_MODE.invokeExact(handle, mode);
        });
    }

    public static int getAutoIndentMode(long handle) {
        return invokeValue(() -> (int) GET_AUTO_INDENT_MODE.invokeExact(handle));
    }

    // ===================== Handle Config =====================

    public static void setHandleConfig(long handle, float radius, float centerDist,
                                       float lineWidth, float touchPadding, float dragYOffset) {
        invokeVoid(() -> {
            SET_HANDLE_CONFIG.invokeExact(handle, radius, centerDist, lineWidth, touchPadding, dragYOffset);
        });
    }

    public static void setScrollbarConfig(long handle, float thickness, float minThumb, float thumbHitPadding,
                                          int mode, boolean thumbDraggable, int trackTapMode,
                                          int fadeDelayMs, int fadeDurationMs) {
        invokeVoid(() -> {
            SET_SCROLLBAR_CONFIG.invokeExact(
                    handle,
                    thickness,
                    minThumb,
                    thumbHitPadding,
                    mode,
                    thumbDraggable ? 1 : 0,
                    trackTapMode,
                    fadeDelayMs,
                    fadeDurationMs);
        });
    }

    // ===================== Position/Coordinate Query =====================

    public static float[] getPositionRect(long handle, int line, int column, Arena arena) {
        MemorySegment px = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment py = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment ph = arena.allocate(ValueLayout.JAVA_FLOAT);
        try { GET_POSITION_RECT.invokeExact(handle, (long)line, (long)column, px, py, ph); }
        catch (Throwable t) { throw new RuntimeException(t); }
        return new float[]{px.get(ValueLayout.JAVA_FLOAT, 0), py.get(ValueLayout.JAVA_FLOAT, 0), ph.get(ValueLayout.JAVA_FLOAT, 0)};
    }

    public static float[] getCursorRect(long handle, Arena arena) {
        MemorySegment px = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment py = arena.allocate(ValueLayout.JAVA_FLOAT);
        MemorySegment ph = arena.allocate(ValueLayout.JAVA_FLOAT);
        try { GET_CURSOR_RECT.invokeExact(handle, px, py, ph); }
        catch (Throwable t) { throw new RuntimeException(t); }
        return new float[]{px.get(ValueLayout.JAVA_FLOAT, 0), py.get(ValueLayout.JAVA_FLOAT, 0), ph.get(ValueLayout.JAVA_FLOAT, 0)};
    }

    // ===================== Linked Editing =====================

    public static NativeBinaryResult insertSnippet(long handle, String snippetTemplate, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) INSERT_SNIPPET.invokeExact(handle, arena.allocateFrom(snippetTemplate), outSize));
    }

    public static void startLinkedEditing(long handle, byte[] payload, Arena arena) {
        invokeVoid(() -> {
            START_LINKED_EDITING.invokeExact(handle, byteArraySegment(arena, payload), (long) payload.length);
        });
    }

    public static boolean isInLinkedEditing(long handle) {
        return invokeBoolean(() -> (int) IS_IN_LINKED_EDITING.invokeExact(handle));
    }

    public static boolean linkedEditingNext(long handle) {
        return invokeBoolean(() -> (int) LINKED_EDITING_NEXT.invokeExact(handle));
    }

    public static boolean linkedEditingPrev(long handle) {
        return invokeBoolean(() -> (int) LINKED_EDITING_PREV.invokeExact(handle));
    }

    public static void cancelLinkedEditing(long handle) {
        invokeVoid(() -> {
            CANCEL_LINKED_EDITING.invokeExact(handle);
        });
    }

    // ===================== Scroll/Navigation =====================

    public static void scrollToLine(long handle, int line, int behavior) {
        invokeVoid(() -> {
            SCROLL_TO_LINE.invokeExact(handle, (long) line, (byte) behavior);
        });
    }

    public static void gotoLine(long handle, int line, int column) {
        invokeVoid(() -> {
            GOTO_LINE.invokeExact(handle, (long) line, (long) column);
        });
    }

    public static void setScroll(long handle, float scrollX, float scrollY) {
        invokeVoid(() -> {
            SET_SCROLL.invokeExact(handle, scrollX, scrollY);
        });
    }

    public static NativeBinaryResult getScrollMetrics(long handle, Arena arena) {
        return invokeBinaryResult(arena, outSize ->
                (MemorySegment) GET_SCROLL_METRICS.invokeExact(handle, outSize));
    }

    // ===================== Style/Highlight =====================

    public static void registerTextStyle(long handle, int styleId, int color, int bgColor, int fontStyle) {
        invokeVoid(() -> {
            REGISTER_TEXT_STYLE.invokeExact(handle, styleId, color, bgColor, fontStyle);
        });
    }

    public static void setLineSpans(long handle, byte[] payload, Arena arena) {
        invokeVoid(() -> {
            SET_LINE_SPANS.invokeExact(handle, byteArraySegment(arena, payload), (long) payload.length);
        });
    }

    /** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setLineSpans(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_LINE_SPANS.invokeExact(handle, payload, size);
        });
    }

    // ===================== InlayHint / PhantomText =====================



    // ===================== Gutter Icons =====================



    public static void clearGutterIcons(long handle) {
        try { CLEAR_GUTTER_ICONS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void setMaxGutterIcons(long handle, int count) {
        try { SET_MAX_GUTTER_ICONS.invokeExact(handle, count); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Diagnostic Decorations =====================

    public static void setLineDiagnostics(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_LINE_DIAGNOSTICS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    /** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setLineDiagnostics(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_LINE_DIAGNOSTICS.invokeExact(handle, payload, size);
        });
    }

    public static void clearDiagnostics(long handle) {
        try { CLEAR_DIAGNOSTICS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Guide =====================



    public static void clearGuides(long handle) {
        try { CLEAR_GUIDES.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Bracket Pair Highlight =====================

    public static void setBracketPairs(long handle, int[] openChars, int[] closeChars, Arena arena) {
        try {
            MemorySegment openSeg = arena.allocateFrom(ValueLayout.JAVA_INT, openChars);
            MemorySegment closeSeg = arena.allocateFrom(ValueLayout.JAVA_INT, closeChars);
            SET_BRACKET_PAIRS.invokeExact(handle, openSeg, closeSeg, (long) openChars.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void setMatchedBrackets(long handle, int openLine, int openCol, int closeLine, int closeCol) {
        try { SET_MATCHED_BRACKETS.invokeExact(handle, (long) openLine, (long) openCol, (long) closeLine, (long) closeCol); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void clearMatchedBrackets(long handle) {
        try { CLEAR_MATCHED_BRACKETS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Fold =====================

    public static void setFoldRegions(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_FOLD_REGIONS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    /** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setFoldRegions(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_FOLD_REGIONS.invokeExact(handle, payload, size);
        });
    }

    public static boolean toggleFold(long handle, int line) {
        try { return ((int) TOGGLE_FOLD.invokeExact(handle, (long) line)) != 0; }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static boolean foldAt(long handle, int line) {
        try { return ((int) FOLD_AT.invokeExact(handle, (long) line)) != 0; }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static boolean unfoldAt(long handle, int line) {
        try { return ((int) UNFOLD_AT.invokeExact(handle, (long) line)) != 0; }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void foldAll(long handle) {
        try { FOLD_ALL.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void unfoldAll(long handle) {
        try { UNFOLD_ALL.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static boolean isLineVisible(long handle, int line) {
        try { return ((int) IS_LINE_VISIBLE.invokeExact(handle, (long) line)) != 0; }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Clear =====================

    public static void clearHighlights(long handle) {
        try { CLEAR_HIGHLIGHTS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void clearHighlightsLayer(long handle, int layer) {
        try { CLEAR_HIGHLIGHTS_LAYER.invokeExact(handle, (byte) layer); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void clearInlayHints(long handle) {
        try { CLEAR_INLAY_HINTS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void clearPhantomTexts(long handle) {
        try { CLEAR_PHANTOM_TEXTS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    public static void clearAllDecorations(long handle) {
        try { CLEAR_ALL_DECORATIONS.invokeExact(handle); }
        catch (Throwable t) { throw new RuntimeException(t); }
    }

    // ===================== Binary Payload Methods =====================

    public static void setLineInlayHints(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_LINE_INLAY_HINTS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setLineInlayHints(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_LINE_INLAY_HINTS.invokeExact(handle, payload, size);
        });
    }

    public static void setBatchLineInlayHints(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BATCH_LINE_INLAY_HINTS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBatchLineInlayHints(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BATCH_LINE_INLAY_HINTS.invokeExact(handle, payload, size);
        });
    }

    public static void setLinePhantomTexts(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_LINE_PHANTOM_TEXTS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setLinePhantomTexts(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_LINE_PHANTOM_TEXTS.invokeExact(handle, payload, size);
        });
    }

    public static void setBatchLinePhantomTexts(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BATCH_LINE_PHANTOM_TEXTS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBatchLinePhantomTexts(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BATCH_LINE_PHANTOM_TEXTS.invokeExact(handle, payload, size);
        });
    }

    public static void setLineGutterIcons(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_LINE_GUTTER_ICONS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setLineGutterIcons(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_LINE_GUTTER_ICONS.invokeExact(handle, payload, size);
        });
    }

    public static void setBatchLineGutterIcons(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BATCH_LINE_GUTTER_ICONS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBatchLineGutterIcons(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BATCH_LINE_GUTTER_ICONS.invokeExact(handle, payload, size);
        });
    }

    public static void setBatchLineSpans(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BATCH_LINE_SPANS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBatchLineSpans(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BATCH_LINE_SPANS.invokeExact(handle, payload, size);
        });
    }

    public static void setBatchLineDiagnostics(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BATCH_LINE_DIAGNOSTICS.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBatchLineDiagnostics(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BATCH_LINE_DIAGNOSTICS.invokeExact(handle, payload, size);
        });
    }

    public static void setIndentGuides(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_INDENT_GUIDES.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setIndentGuides(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_INDENT_GUIDES.invokeExact(handle, payload, size);
        });
    }

    public static void setBracketGuides(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_BRACKET_GUIDES.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setBracketGuides(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_BRACKET_GUIDES.invokeExact(handle, payload, size);
        });
    }

    public static void setFlowGuides(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_FLOW_GUIDES.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setFlowGuides(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_FLOW_GUIDES.invokeExact(handle, payload, size);
        });
    }

    public static void setSeparatorGuides(long handle, byte[] payload, Arena arena) {
        try {
            MemorySegment seg = arena.allocateFrom(ValueLayout.JAVA_BYTE, payload);
            SET_SEPARATOR_GUIDES.invokeExact(handle, seg, (long) payload.length);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

/** Zero-copy overload: pass pre-encoded MemorySegment directly */
    public static void setSeparatorGuides(long handle, MemorySegment payload, long size) {
        invokeVoid(() -> {
            SET_SEPARATOR_GUIDES.invokeExact(handle, payload, size);
        });
    }

    // ===================== Utilities =====================

    public static void freeBinaryData(long ptr) {
        invokeVoid(() -> {
            FREE_BINARY_DATA.invokeExact(ptr);
        });
    }

    public static void freeU16String(long ptr) {
        invokeVoid(() -> {
            FREE_U16_STRING.invokeExact(ptr);
        });
    }

    /** Read the null-terminated UTF-16LE string returned by C++ */
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

    /** Create upcall stub */
    public static MemorySegment createUpcallStub(Arena arena, Object target, Class<?> ownerType,
                                                  String methodName, MethodType methodType, FunctionDescriptor desc) {
        try {
            MethodHandle mh = MethodHandles.publicLookup()
                    .findVirtual(ownerType, methodName, methodType)
                    .bindTo(target);
            return LINKER.upcallStub(mh, desc, arena);
        } catch (Throwable t) { throw new RuntimeException(t); }
    }

    private EditorNative() {}
}

