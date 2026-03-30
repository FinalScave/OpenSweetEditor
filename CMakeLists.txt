cmake_minimum_required(VERSION 3.10)
project(sweeteditor)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# compiler special
if (MSVC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Zc:__cplusplus /utf-8 /D_CRT_SECURE_NO_WARNINGS")
    add_definitions(-DNOMINMAX=1)
endif ()

# options
option(BUILD_TESTING "Includes testing source for unit tests" ON)
option(BUILD_SHARED_LIB "Build dynamic library" ON)
option(BUILD_STATIC_LIB "Build static library" ON)
add_definitions(-DTESTS_DIR="${CMAKE_SOURCE_DIR}/tests")
add_definitions(-DENABLE_LOG=1)
add_definitions(-DENABLE_PERF_LOG=1)
add_definitions(-DSWEETEDITOR_DEBUG=1)
add_definitions(-DSWEETEDITOR_EXPORT=1)

# initial config
set(LINK_LIB)
set(CMAKE_PROJECT_DIR ${CMAKE_SOURCE_DIR})
set(SRC_DIR ${CMAKE_PROJECT_DIR}/src)
set(3DPARTY_DIR ${CMAKE_PROJECT_DIR}/3dparty)
set(STATIC_LIB_NAME "${CMAKE_PROJECT_NAME}_static")
set(SHARED_LIB_NAME "${CMAKE_PROJECT_NAME}")

# header search path
list(APPEND INCLUDE_DIRS
        ${SRC_DIR}/include
        ${3DPARTY_DIR}/include
        ${3DPARTY_DIR}/include/simdutf
)

# platform special
set(PLATFORM_FILES)
set(WASM_BINDING_FILE)
set(WASM_TARGET_NAME sweeteditor_wasm)
if (ANDROID)
    file(GLOB_RECURSE PLATFORM_FILES ${CMAKE_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp/*.*)
    list(APPEND INCLUDE_DIRS ${CMAKE_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp)
    add_definitions(-DANDROID)
elseif (OHOS)
    file(GLOB_RECURSE PLATFORM_FILES ${CMAKE_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp/*.*)
    list(APPEND INCLUDE_DIRS ${CMAKE_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp)
    add_definitions(-DOHOS)
elseif (WIN32)
    add_definitions(-DWINDOWS -D_POSIX -D_POSIX_THREAD_SAFE_FUNCTIONS)
elseif (APPLE)
    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        add_definitions(-DIOS)
    else()
        add_definitions(-DOSX)
    endif()
elseif (EMSCRIPTEN)
    add_definitions(-DWASM)
    set(BUILD_SHARED_LIB OFF)
    set(BUILD_STATIC_LIB OFF)
    set(BUILD_TESTING OFF)
    set(WASM_BINDING_FILE ${CMAKE_PROJECT_DIR}/platform/Emscripten/sweeteditor_bindings.cpp)
elseif (UNIX AND NOT APPLE)
    add_definitions(-DLINUX)
endif ()

include_directories(${INCLUDE_DIRS})
file(GLOB_RECURSE CORE_SOURCE_FILES ${SRC_DIR}/core/*.*)

if (EMSCRIPTEN)
    message(STATUS "add target: ${WASM_TARGET_NAME} for wasm")
    add_executable(${WASM_TARGET_NAME} ${CORE_SOURCE_FILES} ${WASM_BINDING_FILE})
endif ()

# project shared/static lib
if (BUILD_SHARED_LIB)
    message(STATUS "add target: ${SHARED_LIB_NAME} as dynamic lib")
    add_library(${SHARED_LIB_NAME} SHARED ${CORE_SOURCE_FILES} ${PLATFORM_FILES})
endif ()
if (BUILD_STATIC_LIB)
    message(STATUS "add target: ${STATIC_LIB_NAME} as static lib")
    add_library(${STATIC_LIB_NAME} STATIC ${CORE_SOURCE_FILES} ${PLATFORM_FILES})
endif ()

# add library functions
function(add_platform_library dir filename type)
    if (${type} STREQUAL "STATIC")
        add_library(${dir} STATIC IMPORTED)
    elseif (${type} STREQUAL "SHARED")
        add_library(${dir} SHARED IMPORTED)
    else ()
        message(FATAL_ERROR "Error: add_platform_library type must be STATIC/SHARED")
    endif ()
    set(LIB_PATH)
    if (ANDROID)
        set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/android/${CMAKE_ANDROID_ARCH_ABI}/${filename})
    elseif (OHOS)
        set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/ohos/${OHOS_ARCH}/${filename})
    elseif (WIN32)
        if (MSVC)
            if(CMAKE_BUILD_TYPE STREQUAL "Release")
                set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/windows/msvc/release/${filename})
            else ()
                set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/windows/msvc/debug/${filename})
            endif ()
        else ()
            set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/windows/mingw64/${filename})
        endif ()
    elseif (APPLE)
        if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
            if (CMAKE_OSX_SYSROOT MATCHES ".*simulator.*" OR CMAKE_OSX_SYSROOT STREQUAL "iphonesimulator")
                set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/ios/simulator-${CMAKE_OSX_ARCHITECTURES}/${filename})
            else()
                set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/ios/${CMAKE_OSX_ARCHITECTURES}/${filename})
            endif()
        else()
            set(_OSX_ARCH ${CMAKE_OSX_ARCHITECTURES})
            if (NOT _OSX_ARCH OR _OSX_ARCH STREQUAL "")
                # CMAKE_OSX_ARCHITECTURES fallback to empty if host arch matches target, so detect host arch here
                execute_process(COMMAND uname -m OUTPUT_VARIABLE _OSX_ARCH OUTPUT_STRIP_TRAILING_WHITESPACE)
            endif()
            set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/osx/${_OSX_ARCH}/${filename})
        endif()
    elseif (EMSCRIPTEN)
        set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/emscripten/${filename})
    elseif (UNIX AND NOT APPLE)
        set(LIB_PATH ${3DPARTY_DIR}/lib/${dir}/linux/x86_64/${filename})
    endif ()
    message(STATUS "Add platform library: ${LIB_PATH}")
    set_target_properties(${dir} PROPERTIES IMPORTED_LOCATION ${LIB_PATH})
    set(LINK_LIB ${LINK_LIB} ${dir} PARENT_SCOPE)
endfunction()

# add library
if (ANDROID)
    find_library(ANDROID_LIB android)
    find_library(LOG_LIB log)
    add_platform_library(simdutf libsimdutf.a STATIC)
    set(LINK_LIB ${LINK_LIB} ${ANDROID_LIB} ${LOG_LIB})
elseif (OHOS)
    add_platform_library(simdutf libsimdutf.a STATIC)
    set(LINK_LIB ${LINK_LIB} libace_napi.z.so libhilog_ndk.z.so)
elseif (WIN32)
    if (MSVC)
        add_platform_library(simdutf simdutf.lib STATIC)
    else ()
        add_platform_library(simdutf libsimdutf.a STATIC)
    endif ()
    set(LINK_LIB ${LINK_LIB} DbgHelp)
elseif (APPLE)
    add_platform_library(simdutf libsimdutf.a STATIC)
elseif (EMSCRIPTEN)
    add_platform_library(simdutf libsimdutf.a STATIC)
elseif (UNIX AND NOT APPLE)
    add_platform_library(simdutf libsimdutf.a STATIC)
endif ()

if (BUILD_SHARED_LIB)
    target_link_libraries(${SHARED_LIB_NAME} PRIVATE ${LINK_LIB})
endif ()
# merge static libs
if (BUILD_STATIC_LIB)
    target_link_libraries(${STATIC_LIB_NAME} PRIVATE ${LINK_LIB})
    include(scripts/MergeStaticLib.cmake)
    get_target_property(SIMDUTF_PATH simdutf IMPORTED_LOCATION)
    merge_static_libs(${STATIC_LIB_NAME} ${SIMDUTF_PATH})
endif ()
if (EMSCRIPTEN)
    target_link_libraries(${WASM_TARGET_NAME} PRIVATE ${LINK_LIB})
    target_link_options(${WASM_TARGET_NAME} PRIVATE
            "--bind"
            "-O3"
            "-sWASM=1"
            "-sMODULARIZE=1"
            "-sEXPORT_ES6=1"
            "-sALLOW_MEMORY_GROWTH=1"
            "-sENVIRONMENT=web"
            "-sEXPORT_NAME=createSweetEditorModule"
    )
    set_target_properties(${WASM_TARGET_NAME} PROPERTIES
            OUTPUT_NAME "sweeteditor"
            SUFFIX ".js"
    )
endif ()

# Unit tests
if (BUILD_TESTING)
    message(STATUS "Unit tests enabled")
    if (NOT ANDROID AND NOT OHOS AND NOT EMSCRIPTEN)
        add_subdirectory(${CMAKE_PROJECT_DIR}/tests)
    endif ()
endif()

# config for installing
include(GNUInstallDirs)
set(INSTALL_TARGETS)
if (BUILD_SHARED_LIB)
    list(APPEND INSTALL_TARGETS ${SHARED_LIB_NAME})
endif ()
if (BUILD_STATIC_LIB)
    list(APPEND INSTALL_TARGETS ${STATIC_LIB_NAME})
endif ()
# install lib and executable
if (INSTALL_TARGETS)
    install(TARGETS ${INSTALL_TARGETS}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
    if (MSVC)
        foreach(TARGET_NAME ${INSTALL_TARGETS})
            get_target_property(tgt_type ${TARGET_NAME} TYPE)
            if (NOT tgt_type STREQUAL "STATIC_LIBRARY")
                install(FILES $<TARGET_PDB_FILE:${TARGET_NAME}>
                        DESTINATION ${CMAKE_INSTALL_BINDIR}
                        OPTIONAL
                )
            endif()
        endforeach()
    endif()
endif ()
# install headers
install(DIRECTORY ${SRC_DIR}/include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
)
