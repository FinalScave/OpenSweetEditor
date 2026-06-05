cmake_minimum_required(VERSION 3.10)
project(sweeteditor)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)

# Build options
if (PROJECT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    set(SWEETEDITOR_DEFAULT_BUILD_TESTS ON)
    set(SWEETEDITOR_DEFAULT_BUILD_WASM_MODULES ON)
else ()
    set(SWEETEDITOR_DEFAULT_BUILD_TESTS OFF)
    set(SWEETEDITOR_DEFAULT_BUILD_WASM_MODULES OFF)
endif ()

option(SWEETEDITOR_BUILD_TESTS "Build SweetEditor tests" ${SWEETEDITOR_DEFAULT_BUILD_TESTS})
option(SWEETEDITOR_BUILD_SHARED "Build SweetEditor dynamic library" ON)
option(SWEETEDITOR_BUILD_STATIC "Build SweetEditor static library" ON)
option(SWEETEDITOR_BUILD_WASM_C_ABI "Build SweetEditor WebAssembly C ABI module" ${SWEETEDITOR_DEFAULT_BUILD_WASM_MODULES})
option(SWEETEDITOR_BUILD_WASM_EMBIND "Build SweetEditor WebAssembly embind module" ${SWEETEDITOR_DEFAULT_BUILD_WASM_MODULES})
set(SWEETEDITOR_SEARCH_IMPL "std" CACHE STRING "Search implementation: std, oniguruma")
set_property(CACHE SWEETEDITOR_SEARCH_IMPL PROPERTY STRINGS std oniguruma)

if (SWEETEDITOR_SEARCH_IMPL STREQUAL "std")
    set(SWEETEDITOR_SEARCH_IMPL_STD 1)
    set(SWEETEDITOR_SEARCH_IMPL_ONIGURUMA 0)
elseif (SWEETEDITOR_SEARCH_IMPL STREQUAL "oniguruma")
    message(FATAL_ERROR "SWEETEDITOR_SEARCH_IMPL=oniguruma is reserved but not implemented yet")
else ()
    message(FATAL_ERROR "Unsupported SWEETEDITOR_SEARCH_IMPL: ${SWEETEDITOR_SEARCH_IMPL}")
endif ()
if (EMSCRIPTEN)
    if (NOT SWEETEDITOR_BUILD_STATIC AND NOT SWEETEDITOR_BUILD_TESTS AND NOT SWEETEDITOR_BUILD_WASM_C_ABI AND NOT SWEETEDITOR_BUILD_WASM_EMBIND)
        message(FATAL_ERROR "At least one of SWEETEDITOR_BUILD_STATIC, SWEETEDITOR_BUILD_TESTS, SWEETEDITOR_BUILD_WASM_C_ABI, or SWEETEDITOR_BUILD_WASM_EMBIND must be enabled for Emscripten")
    endif ()
elseif (NOT SWEETEDITOR_BUILD_SHARED AND NOT SWEETEDITOR_BUILD_STATIC AND NOT SWEETEDITOR_BUILD_TESTS)
    message(FATAL_ERROR "At least one of SWEETEDITOR_BUILD_SHARED, SWEETEDITOR_BUILD_STATIC, or SWEETEDITOR_BUILD_TESTS must be enabled")
endif ()

# Paths and target names
set(SWEETEDITOR_LINK_LIB)
set(SWEETEDITOR_PROJECT_DIR ${PROJECT_SOURCE_DIR})
set(SWEETEDITOR_SRC_DIR ${SWEETEDITOR_PROJECT_DIR}/src)
set(SWEETEDITOR_PUBLIC_INCLUDE_DIR ${SWEETEDITOR_PROJECT_DIR}/include)
set(SWEETEDITOR_PUBLIC_HEADER_DIR ${SWEETEDITOR_PUBLIC_INCLUDE_DIR}/sweeteditor)
set(SWEETEDITOR_CORE_OBJECT_TARGET "${PROJECT_NAME}_core_objects")
set(SWEETEDITOR_C_API_OBJECT_TARGET "${PROJECT_NAME}_c_api_objects")
set(SWEETEDITOR_STATIC_LIB_NAME "${PROJECT_NAME}_static")
set(SWEETEDITOR_SHARED_LIB_NAME "${PROJECT_NAME}")
set(SWEETEDITOR_APPLE_FRAMEWORK_NAME "SweetEditorCore")

# Third-party dependencies
include(cmake/SweetEditorThirdParty.cmake)
set(SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS
        $<TARGET_PROPERTY:SweetEditor3p::NlohmannJson,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:SweetEditor3p::UtfCpp,INTERFACE_INCLUDE_DIRECTORIES>
        $<TARGET_PROPERTY:SweetEditor3p::Simdutf,INTERFACE_INCLUDE_DIRECTORIES>
)

# Include paths
list(APPEND INCLUDE_DIRS
        ${SWEETEDITOR_PUBLIC_INCLUDE_DIR}
        ${SWEETEDITOR_SRC_DIR}
)

# Platform inputs
set(PLATFORM_FILES)
if (ANDROID)
    file(GLOB_RECURSE PLATFORM_FILES ${SWEETEDITOR_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp/*.*)
    list(APPEND INCLUDE_DIRS ${SWEETEDITOR_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp)
elseif (OHOS)
    file(GLOB_RECURSE PLATFORM_FILES ${SWEETEDITOR_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp/*.*)
    list(APPEND INCLUDE_DIRS ${SWEETEDITOR_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp)
endif ()

# Sources
file(GLOB_RECURSE CORE_SOURCE_FILES CONFIGURE_DEPENDS ${SWEETEDITOR_SRC_DIR}/*.*)
set(C_API_SOURCE_FILE "${SWEETEDITOR_SRC_DIR}/c_api.cpp")
list(REMOVE_ITEM CORE_SOURCE_FILES ${C_API_SOURCE_FILE})

# Dependencies
list(APPEND SWEETEDITOR_LINK_LIB SweetEditor3p::Simdutf)
if (ANDROID)
    find_library(ANDROID_LIB android)
    find_library(LOG_LIB log)
    set(SWEETEDITOR_LINK_LIB ${SWEETEDITOR_LINK_LIB} ${ANDROID_LIB} ${LOG_LIB})
elseif (OHOS)
    set(SWEETEDITOR_LINK_LIB ${SWEETEDITOR_LINK_LIB} libace_napi.z.so libhilog_ndk.z.so)
elseif (WIN32)
    set(SWEETEDITOR_LINK_LIB ${SWEETEDITOR_LINK_LIB} DbgHelp)
endif ()

# Object targets
add_library(${SWEETEDITOR_CORE_OBJECT_TARGET} OBJECT ${CORE_SOURCE_FILES} ${PLATFORM_FILES})
set_target_properties(${SWEETEDITOR_CORE_OBJECT_TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE
        ${INCLUDE_DIRS}
        ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
)
target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE
        TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
        ENABLE_LOG=1
        ENABLE_PERF_LOG=1
        SWEETEDITOR_DEBUG=1
        SWEETEDITOR_EXPORT=1
        SWEETEDITOR_SEARCH_IMPL_STD=${SWEETEDITOR_SEARCH_IMPL_STD}
        SWEETEDITOR_SEARCH_IMPL_ONIGURUMA=${SWEETEDITOR_SEARCH_IMPL_ONIGURUMA}
)
if (MSVC)
    target_compile_options(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE /Zc:__cplusplus /utf-8)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX=1)
endif ()
if (ANDROID)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE ANDROID)
elseif (OHOS)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE OHOS)
elseif (WIN32)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE WINDOWS _POSIX _POSIX_THREAD_SAFE_FUNCTIONS)
elseif (APPLE)
    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE IOS)
    else ()
        target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE OSX)
    endif ()
elseif (EMSCRIPTEN)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE WASM)
elseif (UNIX AND NOT APPLE)
    target_compile_definitions(${SWEETEDITOR_CORE_OBJECT_TARGET} PRIVATE LINUX)
endif ()

if (SWEETEDITOR_BUILD_STATIC OR (SWEETEDITOR_BUILD_TESTS AND NOT EMSCRIPTEN) OR (SWEETEDITOR_BUILD_SHARED AND NOT EMSCRIPTEN AND NOT APPLE))
    add_library(${SWEETEDITOR_C_API_OBJECT_TARGET} OBJECT ${C_API_SOURCE_FILE})
    set_target_properties(${SWEETEDITOR_C_API_OBJECT_TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_include_directories(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE
            ${INCLUDE_DIRS}
            ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
    )
    target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE
            TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
            ENABLE_LOG=1
            ENABLE_PERF_LOG=1
            SWEETEDITOR_DEBUG=1
            SWEETEDITOR_EXPORT=1
            SWEETEDITOR_SEARCH_IMPL_STD=${SWEETEDITOR_SEARCH_IMPL_STD}
            SWEETEDITOR_SEARCH_IMPL_ONIGURUMA=${SWEETEDITOR_SEARCH_IMPL_ONIGURUMA}
    )
    if (MSVC)
        target_compile_options(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE /Zc:__cplusplus /utf-8)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX=1)
    endif ()
    if (ANDROID)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE ANDROID)
    elseif (OHOS)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE OHOS)
    elseif (WIN32)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE WINDOWS _POSIX _POSIX_THREAD_SAFE_FUNCTIONS)
    elseif (APPLE)
        if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
            target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE IOS)
        else ()
            target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE OSX)
        endif ()
    elseif (EMSCRIPTEN)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE WASM)
    elseif (UNIX AND NOT APPLE)
        target_compile_definitions(${SWEETEDITOR_C_API_OBJECT_TARGET} PRIVATE LINUX)
    endif ()
endif ()

# Project libraries
if (SWEETEDITOR_BUILD_SHARED AND NOT EMSCRIPTEN)
    message(STATUS "add target: ${SWEETEDITOR_SHARED_LIB_NAME} as dynamic lib")
    if (APPLE)
        add_library(${SWEETEDITOR_SHARED_LIB_NAME} SHARED ${CORE_SOURCE_FILES} ${C_API_SOURCE_FILE} ${PLATFORM_FILES})
        file(GLOB_RECURSE APPLE_PUBLIC_HEADERS ${SWEETEDITOR_PUBLIC_HEADER_DIR}/*.h ${SWEETEDITOR_PUBLIC_HEADER_DIR}/*.hpp)
        set_target_properties(${SWEETEDITOR_SHARED_LIB_NAME} PROPERTIES
                FRAMEWORK TRUE
                FRAMEWORK_VERSION A
                MACOSX_FRAMEWORK_IDENTIFIER "com.qiplat.${SWEETEDITOR_APPLE_FRAMEWORK_NAME}"
                XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.qiplat.${SWEETEDITOR_APPLE_FRAMEWORK_NAME}"
                PUBLIC_HEADER "${APPLE_PUBLIC_HEADERS}"
                OUTPUT_NAME "${SWEETEDITOR_APPLE_FRAMEWORK_NAME}"
                XCODE_GENERATE_SCHEME TRUE
        )
        target_include_directories(${SWEETEDITOR_SHARED_LIB_NAME}
                PUBLIC
                $<BUILD_INTERFACE:${SWEETEDITOR_PUBLIC_INCLUDE_DIR}>
                $<INSTALL_INTERFACE:include>
                PRIVATE
                ${INCLUDE_DIRS}
                ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
        )
        target_compile_definitions(${SWEETEDITOR_SHARED_LIB_NAME} PRIVATE
                TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
                ENABLE_LOG=1
                ENABLE_PERF_LOG=1
                SWEETEDITOR_DEBUG=1
                SWEETEDITOR_EXPORT=1
                SWEETEDITOR_SEARCH_IMPL_STD=${SWEETEDITOR_SEARCH_IMPL_STD}
                SWEETEDITOR_SEARCH_IMPL_ONIGURUMA=${SWEETEDITOR_SEARCH_IMPL_ONIGURUMA}
        )
        if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
            target_compile_definitions(${SWEETEDITOR_SHARED_LIB_NAME} PRIVATE IOS)
        else ()
            target_compile_definitions(${SWEETEDITOR_SHARED_LIB_NAME} PRIVATE OSX)
        endif ()
    else ()
        add_library(${SWEETEDITOR_SHARED_LIB_NAME} SHARED
                $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
                $<TARGET_OBJECTS:${SWEETEDITOR_C_API_OBJECT_TARGET}>
        )
        target_include_directories(${SWEETEDITOR_SHARED_LIB_NAME}
                PUBLIC
                $<BUILD_INTERFACE:${SWEETEDITOR_PUBLIC_INCLUDE_DIR}>
                $<INSTALL_INTERFACE:include>
        )
    endif ()
elseif (SWEETEDITOR_BUILD_SHARED AND EMSCRIPTEN)
    message(STATUS "skip target: ${SWEETEDITOR_SHARED_LIB_NAME} dynamic lib is not used for Emscripten")
endif ()
if (SWEETEDITOR_BUILD_STATIC)
    message(STATUS "add target: ${SWEETEDITOR_STATIC_LIB_NAME} as static lib")
    add_library(${SWEETEDITOR_STATIC_LIB_NAME} STATIC
            $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
            $<TARGET_OBJECTS:${SWEETEDITOR_C_API_OBJECT_TARGET}>
    )
    target_include_directories(${SWEETEDITOR_STATIC_LIB_NAME}
            PUBLIC
            $<BUILD_INTERFACE:${SWEETEDITOR_PUBLIC_INCLUDE_DIR}>
            $<INSTALL_INTERFACE:include>
    )
    target_compile_definitions(${SWEETEDITOR_STATIC_LIB_NAME} PUBLIC SWEETEDITOR_STATIC=1)
    add_library(SweetEditor::sweeteditor_static ALIAS ${SWEETEDITOR_STATIC_LIB_NAME})
endif ()
if (TARGET ${SWEETEDITOR_SHARED_LIB_NAME})
    add_library(SweetEditor::sweeteditor ALIAS ${SWEETEDITOR_SHARED_LIB_NAME})
elseif (TARGET ${SWEETEDITOR_STATIC_LIB_NAME})
    add_library(SweetEditor::sweeteditor ALIAS ${SWEETEDITOR_STATIC_LIB_NAME})
endif ()

# Link libraries
if (TARGET ${SWEETEDITOR_SHARED_LIB_NAME})
    target_link_libraries(${SWEETEDITOR_SHARED_LIB_NAME} PRIVATE
            SweetEditor3p::NlohmannJson
            SweetEditor3p::UtfCpp
            ${SWEETEDITOR_LINK_LIB}
    )
endif ()
if (TARGET ${SWEETEDITOR_STATIC_LIB_NAME})
    target_link_libraries(${SWEETEDITOR_STATIC_LIB_NAME} PRIVATE
            SweetEditor3p::NlohmannJson
            SweetEditor3p::UtfCpp
            ${SWEETEDITOR_LINK_LIB}
    )
    include(cmake/MergeStaticLib.cmake)
    merge_static_libs(${SWEETEDITOR_STATIC_LIB_NAME} SweetEditor3p::Simdutf)
endif ()

# WebAssembly targets
if (EMSCRIPTEN AND (SWEETEDITOR_BUILD_WASM_C_ABI OR SWEETEDITOR_BUILD_WASM_EMBIND))
    include(cmake/SweetEditorWasm.cmake)
endif ()

# Unit tests
if (SWEETEDITOR_BUILD_TESTS)
    enable_testing()
    message(STATUS "Unit tests enabled")
    if (NOT ANDROID AND NOT OHOS AND NOT EMSCRIPTEN)
        add_subdirectory(${SWEETEDITOR_PROJECT_DIR}/tests)
    endif ()
endif ()

# Install
include(GNUInstallDirs)
set(INSTALL_TARGETS)
if (TARGET ${SWEETEDITOR_SHARED_LIB_NAME})
    list(APPEND INSTALL_TARGETS ${SWEETEDITOR_SHARED_LIB_NAME})
endif ()
if (TARGET ${SWEETEDITOR_STATIC_LIB_NAME})
    list(APPEND INSTALL_TARGETS ${SWEETEDITOR_STATIC_LIB_NAME})
endif ()
if (INSTALL_TARGETS)
    if (APPLE AND SWEETEDITOR_BUILD_SHARED)
        install(TARGETS ${INSTALL_TARGETS}
                RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
                FRAMEWORK DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    else ()
        install(TARGETS ${INSTALL_TARGETS}
                RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    endif ()
    if (MSVC)
        foreach(TARGET_NAME ${INSTALL_TARGETS})
            get_target_property(tgt_type ${TARGET_NAME} TYPE)
            if (NOT tgt_type STREQUAL "STATIC_LIBRARY")
                install(FILES $<TARGET_PDB_FILE:${TARGET_NAME}>
                        DESTINATION ${CMAKE_INSTALL_BINDIR}
                        OPTIONAL
                )
            endif ()
        endforeach ()
    endif ()
endif ()
install(DIRECTORY ${SWEETEDITOR_PUBLIC_HEADER_DIR}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
)
