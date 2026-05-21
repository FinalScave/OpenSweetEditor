if (TARGET SweetEditor3p::NlohmannJson)
    return()
endif ()

add_library(sweeteditor_3p_nlohmann_json INTERFACE)

target_compile_features(sweeteditor_3p_nlohmann_json INTERFACE cxx_std_17)

target_include_directories(sweeteditor_3p_nlohmann_json
        INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/include
)

add_library(SweetEditor3p::NlohmannJson ALIAS sweeteditor_3p_nlohmann_json)
