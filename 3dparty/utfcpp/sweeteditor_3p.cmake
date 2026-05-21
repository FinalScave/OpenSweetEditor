if (TARGET SweetEditor3p::UtfCpp)
    return()
endif ()

add_library(sweeteditor_3p_utfcpp INTERFACE)

target_compile_features(sweeteditor_3p_utfcpp INTERFACE cxx_std_17)

target_include_directories(sweeteditor_3p_utfcpp
        INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/include
)

add_library(SweetEditor3p::UtfCpp ALIAS sweeteditor_3p_utfcpp)
