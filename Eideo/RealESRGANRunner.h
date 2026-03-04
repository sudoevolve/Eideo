#ifndef REALESRGANRUNNER_H
#define REALESRGANRUNNER_H

#include <QObject>
#include <QProcess>
#include <QVariant>
#include "Task.h"

class RealESRGANRunner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList modelList READ modelList NOTIFY modelListChanged)

public:
    explicit RealESRGANRunner(QObject *parent = nullptr);

    Q_INVOKABLE void upscaleImage(const QString &inputPath, const QString &modelName, int scale);
    Q_INVOKABLE void upscaleVideo(const QString &inputPath, const QString &modelName, int scale);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void refreshModels();

    QStringList modelList() const;

signals:
    void started();
    void finished(bool success, const QString &message);
    void outputLog(const QString &log);
    void progressChanged(double progress);
    void modelListChanged();

private:
    QProcess *m_process;
    QStringList m_modelList;
    Task *m_currentTask = nullptr;
    QString locateExecutable();
};

#endif // REALESRGANRUNNER_H
