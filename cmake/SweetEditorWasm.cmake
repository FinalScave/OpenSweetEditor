set(WASM_COMMON_LINK_ITEMS
        ${SWEETEDITOR_LINK_LIB}
        "--no-entry"
        "-sWASM=1"
        "-sMODULARIZE=1"
        "-sEXPORT_ES6=1"
        "-sFORCE_FILESYSTEM=1"
        "-sALLOW_MEMORY_GROWTH=1"
        "-sNO_EXIT_RUNTIME=1"
        "-sENVIRONMENT=web,worker,node"
)

set(WASM_C_ABI_EXPORTED_FUNCTIONS
        _malloc
        _free
        _create_document_from_utf8
        _create_document_from_utf16
        _create_document_from_file
        _free_document
        _get_document_utf8
        _get_document_utf16
        _get_document_line_count
        _get_document_line_utf8
        _get_document_line_utf16
        _create_editor
        _free_editor
        _editor_set_document
        _editor_set_viewport
        _editor_on_font_metrics_changed
        _editor_set_fold_arrow_mode
        _editor_set_wrap_mode
        _editor_set_tab_size
        _editor_set_scale
        _editor_set_line_spacing
        _editor_set_content_start_padding
        _editor_set_show_split_line
        _editor_set_current_line_render_mode
        _editor_set_gutter_sticky
        _editor_set_gutter_visible
        _editor_set_handle_config
        _editor_set_scrollbar_config
        _editor_build_render_model
        _editor_get_layout_metrics
        _editor_handle_gesture_event
        _editor_update_pointer_modifiers
        _editor_tick_animations
        _editor_handle_key_event
        _editor_set_keymap
        _editor_insert_text
        _editor_replace_text
        _editor_delete_text
        _editor_backspace
        _editor_delete_forward
        _editor_move_line_up
        _editor_move_line_down
        _editor_copy_line_up
        _editor_copy_line_down
        _editor_delete_line
        _editor_insert_line_above
        _editor_insert_line_below
        _editor_undo
        _editor_redo
        _editor_can_undo
        _editor_can_redo
        _editor_set_cursor_position
        _editor_get_cursor_position
        _editor_select_all
        _editor_set_selection
        _editor_get_selection
        _editor_get_selected_text
        _editor_get_word_range_at_cursor
        _editor_get_word_at_cursor
        _editor_move_cursor_left
        _editor_move_cursor_right
        _editor_move_cursor_up
        _editor_move_cursor_down
        _editor_move_cursor_to_line_start
        _editor_move_cursor_to_line_end
        _editor_set_read_only
        _editor_is_read_only
        _editor_set_auto_indent_mode
        _editor_get_auto_indent_mode
        _editor_set_backspace_unindent
        _editor_set_insert_spaces
        _editor_scroll_to_line
        _editor_goto_position
        _editor_ensure_cursor_visible
        _editor_set_scroll
        _editor_get_scroll_metrics
        _editor_get_position_rect
        _editor_get_cursor_rect
        _editor_register_text_style
        _editor_set_line_spans
        _editor_set_batch_line_spans
        _editor_register_batch_text_styles
        _editor_clear_line_spans
        _editor_clear_highlights_layer
        _editor_set_line_inlay_hints
        _editor_set_batch_line_inlay_hints
        _editor_set_line_phantom_texts
        _editor_set_batch_line_phantom_texts
        _editor_set_line_gutter_icons
        _editor_set_batch_line_gutter_icons
        _editor_set_max_gutter_icons
        _editor_clear_gutter_icons
        _editor_set_line_codelens
        _editor_set_batch_line_codelens
        _editor_clear_codelens
        _editor_set_line_links
        _editor_set_batch_line_links
        _editor_clear_links
        _editor_get_link_target_at
        _editor_set_line_diagnostics
        _editor_set_batch_line_diagnostics
        _editor_clear_diagnostics
        _editor_set_indent_guides
        _editor_set_bracket_guides
        _editor_set_flow_guides
        _editor_set_separator_guides
        _editor_clear_guides
        _editor_set_bracket_pairs
        _editor_set_auto_closing_pairs
        _editor_set_matched_brackets
        _editor_clear_matched_brackets
        _editor_set_fold_regions
        _editor_toggle_fold
        _editor_fold_at
        _editor_unfold_at
        _editor_fold_all
        _editor_unfold_all
        _editor_is_line_visible
        _editor_get_visible_line_range
        _editor_clear_highlights
        _editor_clear_inlay_hints
        _editor_clear_phantom_texts
        _editor_clear_all_decorations
        _editor_insert_snippet
        _editor_start_linked_editing
        _editor_is_in_linked_editing
        _editor_linked_editing_next
        _editor_linked_editing_prev
        _editor_cancel_linked_editing
        _free_u16_string
        _free_u8_string
        _free_binary_data
        _editor_ime_is_composing
        _editor_ime_get_composing_range
        _editor_ime_get_composing_session_range
        _editor_ime_handle_command_message
        _editor_ime_handle_text_update_message
        _editor_ime_get_keyboard_script_class
        _editor_ime_get_sync_snapshot
        _editor_ime_get_command_input_context
        _editor_ime_get_text_update_input_context
)

set(WASM_C_ABI_RUNTIME_METHODS
        ccall
        cwrap
        UTF8ToString
        stringToUTF8
        lengthBytesUTF8
        getValue
        setValue
        addFunction
        removeFunction
        FS
)

set(WASM_EMBIND_RUNTIME_METHODS
        FS
)

string(REPLACE ";" "','" WASM_C_ABI_EXPORTED_FUNCTIONS_ARG "${WASM_C_ABI_EXPORTED_FUNCTIONS}")
set(WASM_C_ABI_EXPORTED_FUNCTIONS_ARG "['${WASM_C_ABI_EXPORTED_FUNCTIONS_ARG}']")
string(REPLACE ";" "','" WASM_C_ABI_RUNTIME_METHODS_ARG "${WASM_C_ABI_RUNTIME_METHODS}")
set(WASM_C_ABI_RUNTIME_METHODS_ARG "['${WASM_C_ABI_RUNTIME_METHODS_ARG}']")
string(REPLACE ";" "','" WASM_EMBIND_RUNTIME_METHODS_ARG "${WASM_EMBIND_RUNTIME_METHODS}")
set(WASM_EMBIND_RUNTIME_METHODS_ARG "['${WASM_EMBIND_RUNTIME_METHODS_ARG}']")

if (SWEETEDITOR_BUILD_WASM_C_ABI)
    set(WASM_C_ABI_TARGET "${PROJECT_NAME}_wasm_c_abi")
    set(WASM_C_API_OBJECT_TARGET "${PROJECT_NAME}_wasm_c_api_objects")
    message(STATUS "add target: ${WASM_C_ABI_TARGET} as WebAssembly C ABI module")
    add_library(${WASM_C_API_OBJECT_TARGET} OBJECT ${C_API_SOURCE_FILE})
    set_target_properties(${WASM_C_API_OBJECT_TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_include_directories(${WASM_C_API_OBJECT_TARGET} PRIVATE
            ${INCLUDE_DIRS}
            ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
    )
    target_compile_definitions(${WASM_C_API_OBJECT_TARGET} PRIVATE
            TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
            ENABLE_LOG=1
            ENABLE_PERF_LOG=1
            SWEETEDITOR_DEBUG=1
            SWEETEDITOR_EXPORT=1
            WASM
            SWEETEDITOR_BUILD_WASM_C_ABI
    )
    add_executable(${WASM_C_ABI_TARGET}
            $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
            $<TARGET_OBJECTS:${WASM_C_API_OBJECT_TARGET}>
    )
    set_target_properties(${WASM_C_ABI_TARGET} PROPERTIES OUTPUT_NAME "sweeteditor_c_abi")
    target_link_libraries(${WASM_C_ABI_TARGET} PRIVATE
            SweetEditor3p::NlohmannJson
            SweetEditor3p::UtfCpp
            ${WASM_COMMON_LINK_ITEMS}
            "-sEXPORT_NAME=SweetEditorCAbi"
            "-sEXPORTED_FUNCTIONS=${WASM_C_ABI_EXPORTED_FUNCTIONS_ARG}"
            "-sEXPORTED_RUNTIME_METHODS=${WASM_C_ABI_RUNTIME_METHODS_ARG}"
            "-sALLOW_TABLE_GROWTH=1"
    )
endif ()

if (SWEETEDITOR_BUILD_WASM_EMBIND)
    set(WASM_EMBIND_TARGET "${PROJECT_NAME}_wasm_embind")
    message(STATUS "add target: ${WASM_EMBIND_TARGET} as WebAssembly embind module")
    add_executable(${WASM_EMBIND_TARGET}
            $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
            ${SWEETEDITOR_PROJECT_DIR}/platform/Emscripten/sweeteditor_bindings.cpp
    )
    set_target_properties(${WASM_EMBIND_TARGET} PROPERTIES OUTPUT_NAME "sweeteditor_embind")
    target_include_directories(${WASM_EMBIND_TARGET} PRIVATE
            ${INCLUDE_DIRS}
            ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
    )
    target_compile_definitions(${WASM_EMBIND_TARGET} PRIVATE
            TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
            ENABLE_LOG=1
            ENABLE_PERF_LOG=1
            SWEETEDITOR_DEBUG=1
            SWEETEDITOR_EXPORT=1
            WASM
    )
    target_link_libraries(${WASM_EMBIND_TARGET} PRIVATE
            SweetEditor3p::NlohmannJson
            SweetEditor3p::UtfCpp
            ${WASM_COMMON_LINK_ITEMS}
            "--bind"
            "-sEXPORT_NAME=SweetEditorEmbind"
            "-sEXPORTED_RUNTIME_METHODS=${WASM_EMBIND_RUNTIME_METHODS_ARG}"
    )
endif ()
