set(TEST_PRODUCT_NAME unit_tests)
add_definitions(-DCATCH_AMALGAMATED_CUSTOM_MAIN=ON)
add_executable(${TEST_PRODUCT_NAME}
        ${3DPARTY_DIR}/include/catch2/catch_amalgamated.cpp
        tests_main.cpp
        unicode_util.cpp
        edit_document.cpp
        document_parity.cpp
        editor_core_editing.cpp
        editor_render.cpp
        editor_undo_redo.cpp
        editor_scroll.cpp
        gesture.cpp
        interaction_behavior.cpp
        keymap.cpp
        layout_mapping.cpp
        layout_decorations.cpp
        decoration_adjust.cpp
        editor_composition.cpp
        editor_linked_editing.cpp
        c_api_smoke.cpp
        performance_baseline.cpp
)

target_include_directories(${TEST_PRODUCT_NAME} PRIVATE
        ${3DPARTY_DIR}/include
        ${SRC_DIR}/include
)

target_link_libraries(${TEST_PRODUCT_NAME} PRIVATE ${STATIC_LIB_NAME})

enable_testing()
add_test(NAME UnitTests COMMAND ${TEST_PRODUCT_NAME})
