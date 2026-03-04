#ifndef FFMPEGRUNNER_H
#define FFMPEGRUNNER_H

#include <QObject>
#include <QProcess>
#include <QVariant>
#include "Task.h"

class FFmpegRunner : public QObject
{
    Q_OBJECT
public:
    explicit FFmpegRunner(QObject *parent = nullptr);

    Q_INVOKABLE void convertVideo(const QString &inputPath, const QString &outputFormat, const QString &quality);
    Q_INVOKABLE void compressVideo(const QString &inputPath, int crf, const QString &preset, const QString &codec, const QString &resolution, const QString &audio);
    Q_INVOKABLE void startScreenRecording(const QString &outputPath, const QString &framerate = "30", const QString &audioDevice = "None", const QString &videoEncoder = "libx264", const QString &quality = "Medium", const QString &captureMethod = "gdigrab");
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void stopConversion(); // New method for stopping conversion/compression
    Q_INVOKABLE QVariantList getAudioDevices();
    Q_INVOKABLE void refreshAudioDevices();

signals:
    void conversionStarted();
    void conversionFinished(bool success, const QString &message);
    void outputLog(const QString &log);
    void audioDevicesReady(const QVariantList &devices);

private:
    QVariantList parseAudioDevices(const QString &output);
    QProcess *m_process;
    QProcess *m_videoProcess;
    QProcess *m_audioProcess;
    Task *m_currentTask = nullptr; // Task tracking
    QString m_videoTempPath;
    QString m_audioTempPath;
    QString m_finalOutputPath;
    bool m_hasAudioInput;
    bool m_isMuxing;
    
    // Progress tracking helpers
    double m_totalDuration = 0.0;
    double parseDuration(const QString &line);
    double parseCurrentTime(const QString &line);
};

#endif // FFMPEGRUNNER_H
