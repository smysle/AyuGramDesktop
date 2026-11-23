find_package(Git REQUIRED)

set(ayu_lib_ui_patch "${CMAKE_CURRENT_LIST_DIR}/ayugram_lib_ui.patch")
set(lib_ui_loc "${CMAKE_CURRENT_BINARY_DIR}/ayu-lib-ui-src")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ayu_lib_ui_patch}")

if (NOT EXISTS "${submodules_loc}/lib_ui/CMakeLists.txt")
    message(FATAL_ERROR "Initialize the Telegram/lib_ui submodule before configuring.")
endif()

file(REMOVE_RECURSE "${lib_ui_loc}")
file(COPY "${submodules_loc}/lib_ui/" DESTINATION "${lib_ui_loc}"
    PATTERN ".git" EXCLUDE)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "GIT_CEILING_DIRECTORIES=${CMAKE_CURRENT_BINARY_DIR}"
        "${GIT_EXECUTABLE}" apply "${ayu_lib_ui_patch}"
    WORKING_DIRECTORY "${lib_ui_loc}"
    COMMAND_ERROR_IS_FATAL ANY
)

add_subdirectory("${lib_ui_loc}" lib_ui)
