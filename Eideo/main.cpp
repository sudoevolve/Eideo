#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include "FFmpegRunner.h"
#include "RealESRGANRunner.h"
#include "TaskManager.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/new/prefix1/fonts/icon.ico"));
    
    qmlRegisterType<FFmpegRunner>("EvolveUI.Utils", 1, 0, "FFmpegRunner");
    qmlRegisterType<RealESRGANRunner>("EvolveUI.Utils", 1, 0, "RealESRGANRunner");
    
    QQmlApplicationEngine engine;
    
    // Register TaskManager singleton
    engine.rootContext()->setContextProperty("TaskManager", TaskManager::instance());
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [](){ QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("EvolveUI", "Main");
    return app.exec();
}

