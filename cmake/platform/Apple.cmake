function(sweeteditor_platform_configure)
    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set(SWEETEDITOR_PLATFORM_ID "ios" PARENT_SCOPE)
        set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS IOS PARENT_SCOPE)
    else ()
        set(SWEETEDITOR_PLATFORM_ID "macos" PARENT_SCOPE)
        set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS MACOS PARENT_SCOPE)
    endif ()
endfunction()

function(sweeteditor_platform_validate_build_options)
    sweeteditor_validate_standard_build_options()
    if (SWEETEDITOR_BUILD_APPLE_FRAMEWORK)
        if (NOT SWEETEDITOR_BUILD_SHARED)
            message(FATAL_ERROR "SWEETEDITOR_BUILD_APPLE_FRAMEWORK requires SWEETEDITOR_BUILD_SHARED=ON")
        endif ()
        if (SWEETEDITOR_BUILD_STATIC)
            message(FATAL_ERROR "SWEETEDITOR_BUILD_APPLE_FRAMEWORK requires SWEETEDITOR_BUILD_STATIC=OFF; build the static archive separately")
        endif ()
        if (SWEETEDITOR_APPLE_STATIC_FRAMEWORK AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
            message(FATAL_ERROR "SWEETEDITOR_APPLE_STATIC_FRAMEWORK is only supported for iOS framework builds")
        endif ()
    endif ()
endfunction()

function(sweeteditor_platform_should_build_c_api_objects out_var)
    if (SWEETEDITOR_BUILD_STATIC OR SWEETEDITOR_BUILD_TESTS)
        set(${out_var} ON PARENT_SCOPE)
    else ()
        set(${out_var} OFF PARENT_SCOPE)
    endif ()
endfunction()

function(sweeteditor_platform_add_shared_target out_handled)
    if (NOT SWEETEDITOR_BUILD_SHARED)
        set(${out_handled} OFF PARENT_SCOPE)
        return()
    endif ()
    if (SWEETEDITOR_BUILD_APPLE_FRAMEWORK)
        set(${out_handled} ON PARENT_SCOPE)
        return()
    endif ()

    message(STATUS "add target: ${SWEETEDITOR_SHARED_LIB_NAME} as dynamic lib")
    add_library(${SWEETEDITOR_SHARED_LIB_NAME} SHARED
            ${SWEETEDITOR_CORE_SOURCE_FILES}
            ${SWEETEDITOR_C_API_SOURCE_FILES}
            ${SWEETEDITOR_PLATFORM_FILES}
    )
    sweeteditor_configure_compile_target(${SWEETEDITOR_SHARED_LIB_NAME})
    sweeteditor_link_public_target(${SWEETEDITOR_SHARED_LIB_NAME})
    set(${out_handled} ON PARENT_SCOPE)
endfunction()

function(sweeteditor_platform_add_extra_targets)
    if (NOT SWEETEDITOR_BUILD_APPLE_FRAMEWORK)
        return()
    endif ()

    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set(_sweeteditor_framework_name "SweetEditorCoreIOS")
        set(_sweeteditor_framework_identifier "com.qiplat.sweeteditor.core.ios")
    else ()
        set(_sweeteditor_framework_name "SweetEditorCoreMacOS")
        set(_sweeteditor_framework_identifier "com.qiplat.sweeteditor.core.macos")
    endif ()
    set(SWEETEDITOR_APPLE_FRAMEWORK_HEADER_DIR
            "${PROJECT_BINARY_DIR}/cmake/platform/apple/${_sweeteditor_framework_name}"
    )
    set(SWEETEDITOR_APPLE_FRAMEWORK_HEADER
            "${SWEETEDITOR_APPLE_FRAMEWORK_HEADER_DIR}/${_sweeteditor_framework_name}.h"
    )
    file(MAKE_DIRECTORY "${SWEETEDITOR_APPLE_FRAMEWORK_HEADER_DIR}")
    file(WRITE "${SWEETEDITOR_APPLE_FRAMEWORK_HEADER}"
            "#pragma once\n\n#include <${_sweeteditor_framework_name}/c_api.h>\n"
    )
    set(SWEETEDITOR_APPLE_FRAMEWORK_PUBLIC_HEADERS
            "${SWEETEDITOR_APPLE_FRAMEWORK_HEADER}"
            "${SWEETEDITOR_PUBLIC_HEADER_DIR}/c_api.h"
    )
    set_source_files_properties(${SWEETEDITOR_APPLE_FRAMEWORK_PUBLIC_HEADERS} PROPERTIES MACOSX_PACKAGE_LOCATION "Headers")
    message(STATUS "add target: ${_sweeteditor_framework_name} as Apple framework")
    add_library(${_sweeteditor_framework_name} SHARED
            ${SWEETEDITOR_CORE_SOURCE_FILES}
            ${SWEETEDITOR_C_API_SOURCE_FILES}
            ${SWEETEDITOR_PLATFORM_FILES}
            ${SWEETEDITOR_APPLE_FRAMEWORK_PUBLIC_HEADERS}
    )
    sweeteditor_configure_compile_target(${_sweeteditor_framework_name})
    sweeteditor_link_public_target(${_sweeteditor_framework_name})
    set_target_properties(${_sweeteditor_framework_name} PROPERTIES
            FRAMEWORK TRUE
            FRAMEWORK_VERSION A
            MACOSX_FRAMEWORK_IDENTIFIER "${_sweeteditor_framework_identifier}"
            OUTPUT_NAME "${_sweeteditor_framework_name}"
            PUBLIC_HEADER "${SWEETEDITOR_APPLE_FRAMEWORK_PUBLIC_HEADERS}"
            XCODE_ATTRIBUTE_DEFINES_MODULE YES
            XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${_sweeteditor_framework_identifier}"
    )

    if (SWEETEDITOR_APPLE_STATIC_FRAMEWORK)
        set_target_properties(${_sweeteditor_framework_name} PROPERTIES
                XCODE_ATTRIBUTE_MACH_O_TYPE staticlib
        )
    else ()
        set_target_properties(${_sweeteditor_framework_name} PROPERTIES
                XCODE_ATTRIBUTE_MACH_O_TYPE mh_dylib
                BUILD_WITH_INSTALL_NAME_DIR TRUE
                INSTALL_NAME_DIR "@rpath"
        )
    endif ()
endfunction()
