function(sweeteditor_platform_configure)
    set(SWEETEDITOR_PLATFORM_ID "windows" PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS
            WINDOWS
            _POSIX
            _POSIX_THREAD_SAFE_FUNCTIONS
            PARENT_SCOPE)
    set(SWEETEDITOR_PLATFORM_LINK_LIBRARIES DbgHelp PARENT_SCOPE)

    if (MSVC)
        set(SWEETEDITOR_PLATFORM_COMPILE_OPTIONS /Zc:__cplusplus /utf-8 PARENT_SCOPE)
        set(SWEETEDITOR_PLATFORM_COMPILE_DEFINITIONS
                WINDOWS
                _POSIX
                _POSIX_THREAD_SAFE_FUNCTIONS
                _CRT_SECURE_NO_WARNINGS
                NOMINMAX=1
                PARENT_SCOPE)
    endif ()
endfunction()

function(sweeteditor_platform_install_target_debug_symbols target_name)
    if (MSVC)
        get_target_property(tgt_type ${target_name} TYPE)
        if (NOT tgt_type STREQUAL "STATIC_LIBRARY")
            install(FILES $<TARGET_PDB_FILE:${target_name}>
                    DESTINATION ${CMAKE_INSTALL_BINDIR}
                    OPTIONAL
            )
        endif ()
    endif ()
endfunction()
