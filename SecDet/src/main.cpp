#include <qcoreapplication.h>
#include <qqmlapplicationengine.h>
#include <qguiapplication.h>
#include <expected>

#include <libsecdet/SeArchive.h>

int main(int argc, char** argv) {
	QGuiApplication app(argc, argv);

	QQmlApplicationEngine engine;

	engine.loadFromModule("UI", "MainWindow");

	return app.exec();
}