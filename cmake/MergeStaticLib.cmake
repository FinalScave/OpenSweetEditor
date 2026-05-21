function(merge_static_libs target)
    set(LIB_FILES)
    foreach (lib ${ARGN})
        if (TARGET ${lib})
            get_target_property(lib_type ${lib} TYPE)
            if (lib_type STREQUAL "STATIC_LIBRARY")
                list(APPEND LIB_FILES $<TARGET_FILE:${lib}>)
            endif ()
        else ()
            list(APPEND LIB_FILES ${lib})
        endif ()
    endforeach ()

    if (MSVC)
        add_custom_command(TARGET ${target} POST_BUILD
                COMMAND echo "Merging all static libs '${LIB_FILES}' into ${target} for MSVC"
                COMMAND link /lib /out:${PROJECT_BINARY_DIR}/temp_merged.lib $<TARGET_FILE:${target}> ${LIB_FILES}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_BINARY_DIR}/temp_merged.lib $<TARGET_FILE:${target}>
                COMMAND ${CMAKE_COMMAND} -E remove ${PROJECT_BINARY_DIR}/temp_merged.lib
                VERBATIM
        )
    else ()
        set(LIB_EXTRACT_DIRS)
        file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/temp_extract)
        # Extract all static library objects before merging.
        foreach (lib_file ${LIB_FILES})
            get_filename_component(lib_name ${lib_file} NAME_WE)
            set(LIB_EXTRACT_DIR ${PROJECT_BINARY_DIR}/temp_extract/${lib_name})
            list(APPEND LIB_EXTRACT_DIRS ${LIB_EXTRACT_DIR})
            add_custom_command(TARGET ${target} POST_BUILD
                    COMMAND echo "Decompose static lib '${lib_file}' with objects into ${LIB_EXTRACT_DIR}"
                    COMMAND ${CMAKE_COMMAND} -E make_directory ${LIB_EXTRACT_DIR}
                    COMMAND cd ${LIB_EXTRACT_DIR} && ${CMAKE_AR} -x ${lib_file}
            )
        endforeach ()
        # Extract the main target objects into the same merge area.
        set(TARGET_EXTRACT_DIR ${PROJECT_BINARY_DIR}/temp_extract/${target})
        add_custom_command(TARGET ${target} POST_BUILD
                COMMAND echo "Decompose main target '${target}' with objects into ${TARGET_EXTRACT_DIR}"
                COMMAND ${CMAKE_COMMAND} -E make_directory ${TARGET_EXTRACT_DIR}
                COMMAND cd ${TARGET_EXTRACT_DIR} && ${CMAKE_AR} x $<TARGET_FILE:${target}>
        )

        if (WIN32)
            set(EXT_OBJ obj)
        else ()
            set(EXT_OBJ o)
        endif ()
        # Merge the main target objects into a replacement static library.
        set(TEMP_STATIC_LIB ${PROJECT_BINARY_DIR}/temp_merged.a)
        add_custom_command(TARGET ${target} POST_BUILD
                COMMAND echo "Merging main target objects into ${target} for g++"
                COMMAND ${CMAKE_AR} rcs ${TEMP_STATIC_LIB} ${TARGET_EXTRACT_DIR}/*.${EXT_OBJ}
        )
        # Append each dependency archive into the replacement static library.
        foreach (lib_extract_dir ${LIB_EXTRACT_DIRS})
            if (NOT lib_extract_dir STREQUAL TARGET_EXTRACT_DIR)
                add_custom_command(TARGET ${target} POST_BUILD
                        COMMAND echo "Merging ${lib_extract_dir} objects into ${target} for g++"
                        COMMAND ${CMAKE_AR} q ${TEMP_STATIC_LIB} ${lib_extract_dir}/*.${EXT_OBJ}
                )
            endif ()
        endforeach ()
        # Refresh the archive index after replacing the target archive.
        add_custom_command(TARGET ${target} POST_BUILD
                COMMAND echo "ranlib with ${target} for g++"
                COMMAND ${CMAKE_RANLIB} ${TEMP_STATIC_LIB}
                COMMAND ${CMAKE_COMMAND} -E copy ${TEMP_STATIC_LIB} $<TARGET_FILE:${target}>
                COMMAND ${CMAKE_COMMAND} -E remove ${TEMP_STATIC_LIB}
        )
    endif ()
endfunction()
