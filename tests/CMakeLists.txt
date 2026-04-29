set(TEST_PRODUCT_NAME unit_tests)
set(PERF_TEST_PRODUCT_NAME perf_tests)

add_definitions(-DCATCH_AMALGAMATED_CUSTOM_MAIN=ON)

file(GLOB_RECURSE UNIT_TEST_SOURCES
        core/*.cpp
        c_api/*.cpp
)

file(GLOB_RECURSE PERF_TEST_SOURCES
        perf/*.cpp
)

function(configure_sweeteditor_test_target target_name)
    target_sources(${target_name} PRIVATE $<TARGET_OBJECTS:${CORE_OBJECT_TARGET}>)
    target_include_directories(${target_name} PRIVATE
            ${3DPARTY_DIR}/include
            ${SRC_DIR}/include
            ${CMAKE_CURRENT_SOURCE_DIR}/support
    )
    target_link_libraries(${target_name} PRIVATE ${LINK_LIB})
endfunction()

add_executable(${TEST_PRODUCT_NAME}
        ${3DPARTY_DIR}/include/catch2/catch_amalgamated.cpp
        tests_main.cpp
        ${UNIT_TEST_SOURCES}
)
configure_sweeteditor_test_target(${TEST_PRODUCT_NAME})

add_executable(${PERF_TEST_PRODUCT_NAME}
        ${3DPARTY_DIR}/include/catch2/catch_amalgamated.cpp
        tests_main.cpp
        ${PERF_TEST_SOURCES}
)
configure_sweeteditor_test_target(${PERF_TEST_PRODUCT_NAME})

add_test(NAME UnitTests COMMAND ${TEST_PRODUCT_NAME})
