#include "ScreenRecorder.h"

ScreenRecorder::ScreenRecorder(QObject *parent) : QObject(parent) {}

void ScreenRecorder::startRecording()
{
    if (ffmpeg.state() != QProcess::NotRunning)
        return;

    QString program = "ffmpeg";

    // Windows 使用 gdigrab 抓屏，输出文件为 output.mp4
    QStringList args = {
        "-y",
        "-f", "gdigrab",
        "-framerate", "30",
        "-i", "desktop",
        "-pix_fmt", "yuv420p",
        "output.mp4"
    };

    ffmpeg.start(program, args);
    if (ffmpeg.waitForStarted()) {
        emit recordingStarted();
    }
}

void ScreenRecorder::stopRecording()
{
    if (ffmpeg.state() == QProcess::Running) {
        // 发送“q”指令优雅停止 FFmpeg 录制
        ffmpeg.write("q");
        ffmpeg.waitForFinished();
        emit recordingStopped();
    }
}
