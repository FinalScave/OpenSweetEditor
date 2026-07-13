function(sweeteditor_platform_configure)
    set(SWEETEDITOR_PLATFORM_ID "android" PARENT_SCOPE)

    set(_sweeteditor_platform_files)
    if (SWEETEDITOR_BUILD_ANDROID_JNI)
        file(GLOB_RECURSE _sweeteditor_platform_files
                ${SWEETEDITOR_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp/*.*)
    endif ()
    set(SWEETEDITOR_PLATFORM_SOURCE_FILES ${_sweeteditor_platform_files} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_INCLUDE_DIRS
            ${SWEETEDITOR_PROJECT_DIR}/platform/Android/sweeteditor/src/main/cpp
            PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS ANDROID PARENT_SCOPE)

    find_library(_sweeteditor_android_lib android)
    find_library(_sweeteditor_log_lib log)
    set(SWEETEDITOR_PLATFORM_LINK_LIBRARIES
            ${_sweeteditor_android_lib}
            ${_sweeteditor_log_lib}
            PARENT_SCOPE)
endfunction()

function(sweeteditor_platform_supports_tests out_var)
    set(${out_var} OFF PARENT_SCOPE)
endfunction()
