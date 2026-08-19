find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

set(CMAKE_AUTOMOC ON)

add_subdirectory("UI")

qt_add_executable(SecDet)

target_sources(SecDet PRIVATE src/main.cpp)

set_target_properties(SecDet PROPERTIES WIN32_EXECUTABLE $<NOT:$<CONFIG:Debug>>)
target_link_libraries(SecDet PRIVATE
					Qt6::Core
					Qt6::Quick
					Qt6::Qml)

target_link_libraries(SecDet PRIVATE $<LINK_LIBRARY:WHOLE_ARCHIVE,app_ui> app_uiplugin)
