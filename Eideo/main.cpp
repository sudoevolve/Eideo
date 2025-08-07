#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "ScreenRecorder.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<ScreenRecorder>("Eideo", 1, 0, "ScreenRecorder");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Eideo", "Main");

    return app.exec();
}
