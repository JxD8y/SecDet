add_library(app_ui STATIC)

qt_add_qml_module(app_ui URI UI VERSION 1.0
				QML_FILES
				MainWindow.qml)