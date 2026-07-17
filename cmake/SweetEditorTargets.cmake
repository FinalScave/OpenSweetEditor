#[[
This file owns the common SweetEditor target graph. Platform files under
cmake/platform are included after platform detection and may override the
default sweeteditor_platform_* hooks declared below.

Platform hooks may set these values from sweeteditor_platform_configure:
SWEETEDITOR_PLATFORM_SOURCE_FILES, SWEETEDITOR_PLATFORM_INCLUDE_DIRS,
SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS, SWEETEDITOR_PLATFORM_COMPILE_OPTIONS,
SWEETEDITOR_PLATFORM_LINK_LIBRARIES.

Platform files may override:
sweeteditor_platform_configure()
sweeteditor_platform_validate_build_options()
sweeteditor_platform_supports_tests(out_var)
sweeteditor_platform_should_build_c_api_objects(out_var)
sweeteditor_platform_add_shared_target(out_handled)
sweeteditor_platform_add_extra_targets()
sweeteditor_platform_install_target_debug_symbols(target_name)
]]

set(SWEETEDITOR_TARGETS_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}")

function(sweeteditor_platform_configure)
endfunction()

function(sweeteditor_platform_supports_tests out_var)
    set(${out_var} ON PARENT_SCOPE)
endfunction()

function(sweeteditor_platform_should_build_c_api_objects out_var)
    if (SWEETEDITOR_BUILD_SHARED OR SWEETEDITOR_BUILD_STATIC OR SWEETEDITOR_BUILD_TESTS)
        set(${out_var} ON PARENT_SCOPE)
    else ()
        set(${out_var} OFF PARENT_SCOPE)
    endif ()
endfunction()

function(sweeteditor_platform_add_shared_target out_handled)
    set(${out_handled} OFF PARENT_SCOPE)
endfunction()

function(sweeteditor_platform_add_extra_targets)
endfunction()

function(sweeteditor_platform_install_target_debug_symbols target_name)
endfunction()

function(sweeteditor_validate_standard_build_options)
    if (NOT SWEETEDITOR_BUILD_SHARED
            AND NOT SWEETEDITOR_BUILD_STATIC
            AND NOT SWEETEDITOR_BUILD_TESTS
            AND NOT SWEETEDITOR_BUILD_APPLE_FRAMEWORK)
        message(FATAL_ERROR "At least one of SWEETEDITOR_BUILD_SHARED, SWEETEDITOR_BUILD_STATIC, or SWEETEDITOR_BUILD_TESTS must be enabled")
    endif ()
endfunction()

function(sweeteditor_platform_validate_build_options)
    if (SWEETEDITOR_BUILD_APPLE_FRAMEWORK)
        message(FATAL_ERROR "SWEETEDITOR_BUILD_APPLE_FRAMEWORK is only supported on Apple platforms")
    endif ()
    sweeteditor_validate_standard_build_options()
endfunction()

function(sweeteditor_configure_platform)
    set(SWEETEDITOR_PLATFORM_ID "generic")
    set(SWEETEDITOR_PLATFORM_FILE "")

    if (ANDROID)
        set(SWEETEDITOR_PLATFORM_ID "android")
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/Android.cmake")
    elseif (OHOS)
        set(SWEETEDITOR_PLATFORM_ID "ohos")
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/OHOS.cmake")
    elseif (WIN32)
        set(SWEETEDITOR_PLATFORM_ID "windows")
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/Windows.cmake")
    elseif (APPLE)
        if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
            set(SWEETEDITOR_PLATFORM_ID "ios")
        else ()
            set(SWEETEDITOR_PLATFORM_ID "macos")
        endif ()
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/Apple.cmake")
    elseif (EMSCRIPTEN)
        set(SWEETEDITOR_PLATFORM_ID "emscripten")
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/Emscripten.cmake")
    elseif (UNIX)
        set(SWEETEDITOR_PLATFORM_ID "linux")
        set(SWEETEDITOR_PLATFORM_FILE "${SWEETEDITOR_TARGETS_CMAKE_DIR}/platform/Linux.cmake")
    endif ()

    set(_sweeteditor_platform_id "${SWEETEDITOR_PLATFORM_ID}")
    set(_sweeteditor_platform_file "${SWEETEDITOR_PLATFORM_FILE}")
    if (_sweeteditor_platform_file)
        include("${_sweeteditor_platform_file}")
    endif ()

    set(SWEETEDITOR_PLATFORM_ID "${_sweeteditor_platform_id}")
    set(SWEETEDITOR_PLATFORM_SOURCE_FILES)
    set(SWEETEDITOR_PLATFORM_INCLUDE_DIRS)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS)
    set(SWEETEDITOR_PLATFORM_COMPILE_OPTIONS)
    set(SWEETEDITOR_PLATFORM_LINK_LIBRARIES)

    sweeteditor_platform_configure()

    set(SWEETEDITOR_PLATFORM_ID "${SWEETEDITOR_PLATFORM_ID}" PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_SOURCE_FILES ${SWEETEDITOR_PLATFORM_SOURCE_FILES} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_INCLUDE_DIRS ${SWEETEDITOR_PLATFORM_INCLUDE_DIRS} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS ${SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_OPTIONS ${SWEETEDITOR_PLATFORM_COMPILE_OPTIONS} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_LINK_LIBRARIES ${SWEETEDITOR_PLATFORM_LINK_LIBRARIES} PARENT_SCOPE)
endfunction()

function(sweeteditor_apply_platform_target target_name)
    if (SWEETEDITOR_PLATFORM_COMPILE_OPTIONS)
        target_compile_options(${target_name} PRIVATE ${SWEETEDITOR_PLATFORM_COMPILE_OPTIONS})
    endif ()
    if (SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS)
        target_compile_definitions(${target_name} PRIVATE ${SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS})
    endif ()
endfunction()

function(sweeteditor_link_common_libraries target_name)
    target_link_libraries(${target_name} PRIVATE
            SweetEditor3p::NlohmannJson
            SweetEditor3p::UtfCpp
            ${SWEETEDITOR_LINK_LIB}
    )
endfunction()

function(sweeteditor_link_public_target target_name)
    target_include_directories(${target_name}
            PUBLIC
            $<BUILD_INTERFACE:${SWEETEDITOR_PUBLIC_INCLUDE_DIR}>
            $<INSTALL_INTERFACE:include>
    )
    sweeteditor_link_common_libraries(${target_name})
endfunction()

function(sweeteditor_configure_compile_target target_name)
    target_compile_features(${target_name} PRIVATE cxx_std_17)
    target_include_directories(${target_name} PRIVATE
            ${SWEETEDITOR_INCLUDE_DIRS}
            ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS}
    )
    target_compile_definitions(${target_name} PRIVATE
            TESTS_DIR="${PROJECT_SOURCE_DIR}/tests"
            ENABLE_LOG=1
            ENABLE_PERF_LOG=1
            SWEETEDITOR_DEBUG=1
            SWEETEDITOR_EXPORT=1
            SWEETEDITOR_SEARCH_IMPL_STD=${SWEETEDITOR_SEARCH_IMPL_STD}
            SWEETEDITOR_SEARCH_IMPL_ONIGURUMA=${SWEETEDITOR_SEARCH_IMPL_ONIGURUMA}
    )
    sweeteditor_apply_platform_target(${target_name})
endfunction()

function(sweeteditor_configure_search_implementation)
    if (SWEETEDITOR_SEARCH_IMPL STREQUAL "std")
        set(SWEETEDITOR_SEARCH_IMPL_STD 1 PARENT_SCOPE)
        set(SWEETEDITOR_SEARCH_IMPL_ONIGURUMA 0 PARENT_SCOPE)
    elseif (SWEETEDITOR_SEARCH_IMPL STREQUAL "oniguruma")
        message(FATAL_ERROR "SWEETEDITOR_SEARCH_IMPL=oniguruma is reserved but not implemented yet")
    else ()
        message(FATAL_ERROR "Unsupported SWEETEDITOR_SEARCH_IMPL: ${SWEETEDITOR_SEARCH_IMPL}")
    endif ()
endfunction()

function(sweeteditor_configure_targets)
    set(SWEETEDITOR_SRC_DIR ${SWEETEDITOR_PROJECT_DIR}/src)
    set(SWEETEDITOR_CORE_OBJECT_TARGET "${PROJECT_NAME}_core_objects")
    set(SWEETEDITOR_C_API_OBJECT_TARGET "${PROJECT_NAME}_c_api_objects")

    sweeteditor_configure_search_implementation()
    sweeteditor_configure_platform()
    sweeteditor_platform_validate_build_options()

    include("${SWEETEDITOR_TARGETS_CMAKE_DIR}/SweetEditorThirdParty.cmake")
    set(SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS
            $<TARGET_PROPERTY:SweetEditor3p::NlohmannJson,INTERFACE_INCLUDE_DIRECTORIES>
            $<TARGET_PROPERTY:SweetEditor3p::UtfCpp,INTERFACE_INCLUDE_DIRECTORIES>
            $<TARGET_PROPERTY:SweetEditor3p::Simdutf,INTERFACE_INCLUDE_DIRECTORIES>
    )
    set(SWEETEDITOR_LINK_LIB SweetEditor3p::Simdutf ${SWEETEDITOR_PLATFORM_LINK_LIBRARIES})

    set(SWEETEDITOR_INCLUDE_DIRS
            ${SWEETEDITOR_PUBLIC_INCLUDE_DIR}
            ${SWEETEDITOR_SRC_DIR}
            ${SWEETEDITOR_PLATFORM_INCLUDE_DIRS}
    )
    set(SWEETEDITOR_PLATFORM_FILES ${SWEETEDITOR_PLATFORM_SOURCE_FILES})

    file(GLOB_RECURSE SWEETEDITOR_CORE_SOURCE_FILES CONFIGURE_DEPENDS ${SWEETEDITOR_SRC_DIR}/*.*)
    set(SWEETEDITOR_C_API_SOURCE_FILES "${SWEETEDITOR_SRC_DIR}/c_api.cpp")
    list(REMOVE_ITEM SWEETEDITOR_CORE_SOURCE_FILES ${SWEETEDITOR_C_API_SOURCE_FILES})

    sweeteditor_platform_supports_tests(SWEETEDITOR_TARGETS_ENABLE_TESTS)

    add_library(${SWEETEDITOR_CORE_OBJECT_TARGET} OBJECT
            ${SWEETEDITOR_CORE_SOURCE_FILES}
            ${SWEETEDITOR_PLATFORM_FILES}
    )
    set_target_properties(${SWEETEDITOR_CORE_OBJECT_TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    sweeteditor_configure_compile_target(${SWEETEDITOR_CORE_OBJECT_TARGET})

    sweeteditor_platform_should_build_c_api_objects(_sweeteditor_build_c_api_objects)
    set(SWEETEDITOR_C_API_OBJECTS)
    if (_sweeteditor_build_c_api_objects)
        add_library(${SWEETEDITOR_C_API_OBJECT_TARGET} OBJECT ${SWEETEDITOR_C_API_SOURCE_FILES})
        set_target_properties(${SWEETEDITOR_C_API_OBJECT_TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
        sweeteditor_configure_compile_target(${SWEETEDITOR_C_API_OBJECT_TARGET})
        list(APPEND SWEETEDITOR_C_API_OBJECTS $<TARGET_OBJECTS:${SWEETEDITOR_C_API_OBJECT_TARGET}>)
    endif ()

    sweeteditor_platform_add_shared_target(_sweeteditor_platform_handled)
    if (NOT _sweeteditor_platform_handled AND SWEETEDITOR_BUILD_SHARED)
        message(STATUS "add target: ${SWEETEDITOR_SHARED_LIB_NAME} as dynamic lib")
        add_library(${SWEETEDITOR_SHARED_LIB_NAME} SHARED
                $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
                ${SWEETEDITOR_C_API_OBJECTS}
        )
        sweeteditor_link_public_target(${SWEETEDITOR_SHARED_LIB_NAME})
    endif ()

    if (SWEETEDITOR_BUILD_STATIC)
        message(STATUS "add target: ${SWEETEDITOR_STATIC_LIB_NAME} as static lib")
        add_library(${SWEETEDITOR_STATIC_LIB_NAME} STATIC
                $<TARGET_OBJECTS:${SWEETEDITOR_CORE_OBJECT_TARGET}>
                ${SWEETEDITOR_C_API_OBJECTS}
        )
        sweeteditor_link_public_target(${SWEETEDITOR_STATIC_LIB_NAME})
        target_compile_definitions(${SWEETEDITOR_STATIC_LIB_NAME} PUBLIC SWEETEDITOR_STATIC=1)
        add_library(SweetEditor::sweeteditor_static ALIAS ${SWEETEDITOR_STATIC_LIB_NAME})

        include("${SWEETEDITOR_TARGETS_CMAKE_DIR}/MergeStaticLib.cmake")
        merge_static_libs(${SWEETEDITOR_STATIC_LIB_NAME} SweetEditor3p::Simdutf)
    endif ()

    if (TARGET ${SWEETEDITOR_SHARED_LIB_NAME})
        add_library(SweetEditor::sweeteditor ALIAS ${SWEETEDITOR_SHARED_LIB_NAME})
    elseif (TARGET ${SWEETEDITOR_STATIC_LIB_NAME})
        add_library(SweetEditor::sweeteditor ALIAS ${SWEETEDITOR_STATIC_LIB_NAME})
    endif ()

    sweeteditor_platform_add_extra_targets()

    set(SWEETEDITOR_PLATFORM_ID "${SWEETEDITOR_PLATFORM_ID}" PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS ${SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_OPTIONS ${SWEETEDITOR_PLATFORM_COMPILE_OPTIONS} PARENT_SCOPE)
    set(SWEETEDITOR_CORE_OBJECT_TARGET ${SWEETEDITOR_CORE_OBJECT_TARGET} PARENT_SCOPE)
    set(SWEETEDITOR_C_API_OBJECT_TARGET ${SWEETEDITOR_C_API_OBJECT_TARGET} PARENT_SCOPE)
    set(SWEETEDITOR_INCLUDE_DIRS ${SWEETEDITOR_INCLUDE_DIRS} PARENT_SCOPE)
    set(SWEETEDITOR_LINK_LIB ${SWEETEDITOR_LINK_LIB} PARENT_SCOPE)
    set(SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS ${SWEETEDITOR_THIRD_PARTY_INCLUDE_DIRS} PARENT_SCOPE)
    set(SWEETEDITOR_C_API_OBJECTS ${SWEETEDITOR_C_API_OBJECTS} PARENT_SCOPE)
    set(SWEETEDITOR_TARGETS_ENABLE_TESTS ${SWEETEDITOR_TARGETS_ENABLE_TESTS} PARENT_SCOPE)
endfunction()
