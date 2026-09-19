#include <qcoreapplication.h>
#include <qqmlapplicationengine.h>
#include <qguiapplication.h>
#include <qqmlcontext.h>

#include "ArchiveInterface.h"
#include "ArchiveRecoveryInterface.h"
#include "SeFileEntryObject.h"
#include "SeJobObject.h"
#include "SeMetadataObject.h"

int main(int argc, char** argv) {
	QGuiApplication app(argc, argv);

	QQmlApplicationEngine engine;

	ArchiveInterface archiveInterface;
	ArchiveRecoveryInterface recoveryInterface;
	engine.rootContext()->setContextProperty("archiveInterface", &archiveInterface);
	engine.rootContext()->setContextProperty("recoveryInterface", &recoveryInterface);

	qmlRegisterUncreatableType<SeFileEntryObject>("SecDet.Backend", 1, 0, "SeFileEntry", "Created by backend");
	qmlRegisterUncreatableType<SeJobObject>("SecDet.Backend", 1, 0, "SeJobObject", "Created by backend");
	qmlRegisterUncreatableType<SeMetadataObject>("SecDet.Backend", 1, 0, "SeMetadataObject", "Created by backend");

	engine.loadFromModule("UI", "MainWindow");

	return app.exec();
}