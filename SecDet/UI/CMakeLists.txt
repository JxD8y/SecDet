add_library(app_ui STATIC)

set_source_files_properties(Colors.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(app_ui URI UI VERSION 1.0
				RESOURCES
				Fonts/MaterialIconsRound-Regular.otf	
				QML_FILES
					MainWindow.qml
					Colors.qml
					ArchiveInfoPage.qml
					PasswordDialog.qml
					CreateArchive.qml
					ProgressWindow.qml
					SpeedGraph.qml
					MultiPartProgressBar.qml
					ArchiveSettingsPage.qml
				)