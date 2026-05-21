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
            $<TARGET_OBJECTS:${SWEETEDITOR_C_API_OBJECT_TARGET}>
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
    if (MSVC)
        target_compile_options(${target_name} PRIVATE /Zc:__cplusplus /utf-8)
        target_compile_definitions(${target_name} PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX=1)
    endif ()
    if (ANDROID)
        target_compile_definitions(${target_name} PRIVATE ANDROID)
    elseif (OHOS)
        target_compile_definitions(${target_name} PRIVATE OHOS)
    elseif (WIN32)
        target_compile_definitions(${target_name} PRIVATE WINDOWS _POSIX _POSIX_THREAD_SAFE_FUNCTIONS)
    elseif (APPLE)
        if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
            target_compile_definitions(${target_name} PRIVATE IOS)
        else ()
            target_compile_definitions(${target_name} PRIVATE OSX)
        endif ()
    elseif (EMSCRIPTEN)
        target_compile_definitions(${target_name} PRIVATE WASM)
    elseif (UNIX AND NOT APPLE)
        target_compile_definitions(${target_name} PRIVATE LINUX)
    endif ()
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
