find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml)

set(CMAKE_AUTOMOC ON)

add_subdirectory("UI")

qt_add_executable(SecDet)

target_sources(SecDet PRIVATE 
    src/main.cpp
    src/ArchiveInterface.h
    src/ArchiveInterface.cpp
    src/SeFileEntryObject.h
    src/SeFileEntryObject.cpp
    src/SeJobObject.h
    src/SeJobObject.cpp
    src/SeMetadataObject.h
    src/SeMetadataObject.cpp
    src/SeJobModel.h
    src/SeJobModel.cpp
    src/ArchiveTreeModel.h
    src/ArchiveTreeModel.cpp
    src/ArchiveRecoveryInterface.h
    src/ArchiveRecoveryInterface.cpp
)

set_target_properties(SecDet PROPERTIES WIN32_EXECUTABLE $<NOT:$<CONFIG:Debug>>)
target_link_libraries(SecDet PRIVATE
					Qt6::Core
					Qt6::Gui
					Qt6::Quick
					Qt6::Qml)
					

target_link_libraries(SecDet PRIVATE $<LINK_LIBRARY:WHOLE_ARCHIVE,app_ui> app_uiplugin)
target_link_libraries(SecDet PRIVATE libsecdet)
