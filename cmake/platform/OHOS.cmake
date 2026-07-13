function(sweeteditor_platform_configure)
    set(SWEETEDITOR_PLATFORM_ID "ohos" PARENT_SCOPE)

    file(GLOB_RECURSE _sweeteditor_platform_files
            ${SWEETEDITOR_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp/*.*)
    set(SWEETEDITOR_PLATFORM_SOURCE_FILES ${_sweeteditor_platform_files} PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_INCLUDE_DIRS
            ${SWEETEDITOR_PROJECT_DIR}/platform/OHOS/sweeteditor/src/main/cpp
            PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS OHOS PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_LINK_LIBRARIES libace_napi.z.so libhilog_ndk.z.so PARENT_SCOPE)
endfunction()

function(sweeteditor_platform_supports_tests out_var)
    set(${out_var} OFF PARENT_SCOPE)
endfunction()
