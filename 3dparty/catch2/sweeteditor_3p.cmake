if (TARGET SweetEditor3p::Catch2)
    return()
endif ()

add_library(sweeteditor_3p_catch2
        ${CMAKE_CURRENT_LIST_DIR}/src/catch_amalgamated.cpp
)

target_compile_features(sweeteditor_3p_catch2 PUBLIC cxx_std_17)
target_compile_definitions(sweeteditor_3p_catch2 PUBLIC CATCH_AMALGAMATED_CUSTOM_MAIN=ON)

target_include_directories(sweeteditor_3p_catch2
        PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/include
        PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/include/catch2
)

add_library(SweetEditor3p::Catch2 ALIAS sweeteditor_3p_catch2)
