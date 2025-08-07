#ifndef SCREENRECORDER_H
#define SCREENRECORDER_H

#include <QObject>
#include <QProcess>

class ScreenRecorder : public QObject
{
    Q_OBJECT
public:
    explicit ScreenRecorder(QObject *parent = nullptr);

    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();

signals:
    void recordingStarted();
    void recordingStopped();

private:
    QProcess ffmpeg;
};

#endif // SCREENRECORDER_H
