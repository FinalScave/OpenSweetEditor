set(TEST_PRODUCT_NAME unit_tests)
set(PERF_TEST_PRODUCT_NAME perf_tests)

file(GLOB_RECURSE UNIT_TEST_SOURCES
        core/*.cpp
        c_api/*.cpp
)

file(GLOB_RECURSE PERF_TEST_SOURCES
        perf/*.cpp
)

function(configure_sweeteditor_test_target target_name)
    target_sources(${target_name} PRIVATE
            $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
            ${SWEETEDITOR_C_API_OBJECTS}
    )
    target_include_directories(${target_name} PRIVATE
            ${SWEETEDITOR_PUBLIC_INCLUDE_DIR}
            ${CMAKE_CURRENT_SOURCE_DIR}/support
    )
    target_compile_definitions(${target_name} PRIVATE
            TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
            ENABLE_LOG=1
            ENABLE_PERF_LOG=1
            SWEETEDITOR_DEBUG=1
            SWEETEDITOR_EXPORT=1
    )
    sweeteditor_apply_platform_target(${target_name})
    target_link_libraries(${target_name} PRIVATE
            SweetEditor3p::Catch2
            ${SWEETEDITOR_LINK_LIB}
    )
endfunction()

add_executable(${TEST_PRODUCT_NAME}
        tests_main.cpp
        ${UNIT_TEST_SOURCES}
)
configure_sweeteditor_test_target(${TEST_PRODUCT_NAME})

add_executable(${PERF_TEST_PRODUCT_NAME}
        tests_main.cpp
        ${PERF_TEST_SOURCES}
)
configure_sweeteditor_test_target(${PERF_TEST_PRODUCT_NAME})

add_test(NAME UnitTests COMMAND ${TEST_PRODUCT_NAME})
