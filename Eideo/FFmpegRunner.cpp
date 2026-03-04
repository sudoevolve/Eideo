#include "FFmpegRunner.h"
#include "TaskManager.h"
#include <QDebug>
#include <QFileInfo>
#include <QFile>
#include <QUrl>
#include <QDir>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDateTime>
#include <QRegularExpression>
#include <QUuid>

static QString locateFFmpeg() {
    QStringList searchPaths;
    QString appDir = QCoreApplication::applicationDirPath();
    QString cwd = QDir::currentPath();

    searchPaths << appDir;
    searchPaths << cwd;

    // Search up to 5 levels up from App Dir
    QDir dir(appDir);
    for (int i = 0; i < 5; ++i) {
        if (dir.cdUp()) {
            searchPaths << dir.absolutePath();
            // Also check for common project structure names if we stepped out of build dir
            searchPaths << dir.absolutePath() + "/Eideo";
            searchPaths << dir.absolutePath() + "/tools/Eideo";
        } else {
            break;
        }
    }
    
    // Search up to 5 levels up from Current Working Dir
    QDir dirCwd(cwd);
    for (int i = 0; i < 5; ++i) {
        if (dirCwd.cdUp()) {
            searchPaths << dirCwd.absolutePath();
            searchPaths << dirCwd.absolutePath() + "/Eideo";
            searchPaths << dirCwd.absolutePath() + "/tools/Eideo";
        } else {
            break;
        }
    }

    // Remove duplicates
    searchPaths.removeDuplicates();

    for (const QString &basePath : searchPaths) {
        QString p1 = basePath + "/ffmpeg.exe";
        if (QFile::exists(p1)) return p1;
        
        QString p2 = basePath + "/ffmpeg/bin/ffmpeg.exe";
        if (QFile::exists(p2)) return p2;
        
        QString p3 = basePath + "/bin/ffmpeg.exe";
        if (QFile::exists(p3)) return p3;
    }

    // Fallback: System PATH
    return "ffmpeg";
}

FFmpegRunner::FFmpegRunner(QObject *parent) : QObject(parent)
{
    m_process = new QProcess(this);
    m_videoProcess = new QProcess(this);
    m_audioProcess = new QProcess(this);
    m_isMuxing = false;
    m_hasAudioInput = false;
    connect(m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        emit outputLog(QString::fromUtf8(m_process->readAllStandardOutput()));
    });
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        QString output = QString::fromUtf8(m_process->readAllStandardError());
        emit outputLog(output);
        
        // Parse progress
        if (m_currentTask && m_currentTask->status() == "Running") {
            // Check for Duration if not yet found
            if (m_totalDuration == 0.0) {
                double dur = parseDuration(output);
                if (dur > 0) {
                    m_totalDuration = dur;
                    // emit outputLog(QString("Duration detected: %1 seconds").arg(dur));
                }
            }
            
            // Check for Time
            if (m_totalDuration > 0) {
                double cur = parseCurrentTime(output);
                if (cur > 0) {
                    double progress = cur / m_totalDuration;
                    if (progress > 1.0) progress = 1.0;
                    
                    m_currentTask->setProgress(progress);
                    m_currentTask->setDetails(QString("Processing... %1%").arg(QString::number(progress * 100, 'f', 1)));
                }
            }
        }
    });
    connect(m_videoProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        emit outputLog(QString::fromUtf8(m_videoProcess->readAllStandardOutput()));
    });
    connect(m_videoProcess, &QProcess::readyReadStandardError, this, [this]() {
        emit outputLog(QString::fromUtf8(m_videoProcess->readAllStandardError()));
    });
    connect(m_audioProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        emit outputLog(QString::fromUtf8(m_audioProcess->readAllStandardOutput()));
    });
    connect(m_audioProcess, &QProcess::readyReadStandardError, this, [this]() {
        emit outputLog(QString::fromUtf8(m_audioProcess->readAllStandardError()));
    });
    
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        QString errorMsg;
        switch (error) {
        case QProcess::FailedToStart:
            errorMsg = "FFmpeg failed to start. Check if ffmpeg is installed or path is correct.";
            break;
        case QProcess::Crashed:
            errorMsg = "FFmpeg crashed.";
            break;
        default:
            errorMsg = "An error occurred with FFmpeg process: " + QString::number(error);
            break;
        }
        emit outputLog(errorMsg);
        emit conversionFinished(false, errorMsg);
    });

    connect(m_process, &QProcess::finished,
            this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            if (m_isMuxing) {
                bool vidRemoved = false;
                bool audRemoved = false;
                if (!m_videoTempPath.isEmpty() && QFile::exists(m_videoTempPath)) vidRemoved = QFile::remove(m_videoTempPath);
                if (!m_audioTempPath.isEmpty() && QFile::exists(m_audioTempPath)) audRemoved = QFile::remove(m_audioTempPath);
                emit outputLog(QString("Temp cleanup: ") + (vidRemoved ? "video OK" : "video N/A") + ", " + (audRemoved ? "audio OK" : "audio N/A"));
                m_isMuxing = false;
                m_hasAudioInput = false;
            }
            emit conversionFinished(true, "Conversion successful");
            
            if (m_currentTask) {
                m_currentTask->setStatus("Completed");
                m_currentTask->setProgress(1.0);
                m_currentTask->setDetails("Finished successfully");
                // Do not delete m_currentTask here, let TaskManager manage it or user clear it.
                // Just detach our pointer.
                m_currentTask = nullptr;
            }
        } else {
            m_isMuxing = false;
            QString errorMsg = QString("Conversion failed with exit code %1").arg(exitCode);
            emit conversionFinished(false, errorMsg);
            
            if (m_currentTask) {
                m_currentTask->setStatus("Failed");
                m_currentTask->setDetails(errorMsg);
                m_currentTask = nullptr;
            }
        }
    });
}

void FFmpegRunner::convertVideo(const QString &inputPath, const QString &outputFormat, const QString &quality)
{
    // Handle file:/// prefix if present
    QString localInput = QUrl(inputPath).isLocalFile() ? QUrl(inputPath).toLocalFile() : inputPath;
    
    if (!QFile::exists(localInput)) {
        emit conversionFinished(false, "Input file does not exist: " + localInput);
        return;
    }

    QFileInfo fileInfo(localInput);
    QString outputExtension = outputFormat;
    if (outputExtension.startsWith(".")) {
        outputExtension = outputExtension.mid(1);
    }
    
    QString outputPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_converted." + outputExtension;

    QString program = locateFFmpeg();

    QStringList arguments;
    arguments << "-y" << "-i" << localInput;

    // Apply quality settings (CRF for x264/x265/etc)
    // Lower CRF = Higher Quality. 
    // 18 = High (Visually lossless)
    // 23 = Medium (Default)
    // 28 = Low (More compression)
    if (quality == "High") {
        arguments << "-crf" << "18";
    } else if (quality == "Low") {
        arguments << "-crf" << "28";
    } else {
        // Default behavior, usually implies -crf 23 for x264
    }

    arguments << outputPath;

    emit outputLog("Executing: " + program + " " + arguments.join(" "));
    emit conversionStarted();

    // Create Task
    m_totalDuration = 0.0; 
    Task *task = new Task("Conversion", this);
    task->setStatus("Running");
    task->setDetails("Converting " + fileInfo.fileName());
    task->setProgress(0.0);
    connect(task, &Task::requestCancel, this, &FFmpegRunner::stopConversion);
    
    TaskManager::instance()->addTask(task);
    m_currentTask = task;

    m_process->start(program, arguments);
    
    // Force an initial progress update to ensure UI shows it
    emit outputLog("Conversion task started for: " + fileInfo.fileName());
}

void FFmpegRunner::stopConversion()
{
    if (m_process->state() == QProcess::Running) {
        m_process->kill();
        if (m_currentTask) {
            m_currentTask->setStatus("Cancelled");
            m_currentTask->setDetails("Cancelled by user");
            m_currentTask = nullptr;
        }
    }
}

double FFmpegRunner::parseDuration(const QString &line) {
    // Example: "Duration: 01:23:45.67,"
    QRegularExpression re("Duration: (\\d{2}):(\\d{2}):(\\d{2}\\.\\d+)");
    QRegularExpressionMatch match = re.match(line);
    if (match.hasMatch()) {
        double h = match.captured(1).toDouble();
        double m = match.captured(2).toDouble();
        double s = match.captured(3).toDouble();
        return h * 3600 + m * 60 + s;
    }
    return 0.0;
}

double FFmpegRunner::parseCurrentTime(const QString &line) {
    // Example: "time=00:00:15.25"
    QRegularExpression re("time=(\\d{2}):(\\d{2}):(\\d{2}\\.\\d+)");
    QRegularExpressionMatch match = re.match(line);
    if (match.hasMatch()) {
        double h = match.captured(1).toDouble();
        double m = match.captured(2).toDouble();
        double s = match.captured(3).toDouble();
        return h * 3600 + m * 60 + s;
    }
    return 0.0;
}

void FFmpegRunner::startScreenRecording(const QString &outputPath, const QString &framerate, const QString &audioDevice, const QString &videoEncoder, const QString &quality, const QString &captureMethod)
{
    QString program = locateFFmpeg();
    emit outputLog("Resolved FFmpeg path: " + program);

    if (m_videoProcess->state() == QProcess::Running || m_audioProcess->state() == QProcess::Running) {
        emit outputLog("Recording is already in progress; ignoring new start request.");
        return;
    }
    QStringList videoArgs;
    videoArgs << "-y";
    if (captureMethod == "ddagrab") {
        videoArgs << "-f" << "lavfi" << "-i" << QString("ddagrab=framerate=%1:draw_mouse=1").arg(framerate);
    } else {
        videoArgs << "-f" << "gdigrab" << "-framerate" << framerate << "-i" << "desktop";
    }
    if (audioDevice != "None" && !audioDevice.isEmpty()) {
        QString resolved = audioDevice;
        
        // Handle generic "System Audio" request
        if (resolved == "audio=Stereo Mix") {
            // Try to auto-detect Stereo Mix or similar via dshow first
            QVariantList devices = getAudioDevices();
            bool found = false;
            for (const QVariant &d : devices) {
                QVariantMap m = d.toMap();
                QString name = m.value("name").toString().toLower();
                if (name.contains("stereo mix") || name.contains("立体声混音") || name.contains("what u hear")) {
                    resolved = m.value("id").toString();
                    if (!resolved.startsWith("@")) resolved = "audio=" + m.value("name").toString();
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                resolved = "audio=立体声混音 (Realtek High Definition Audio)";
                emit outputLog("Warning: 'Stereo Mix' device not found in dshow list. "
                               "Please ensure 'Stereo Mix' is ENABLED in Windows Sound Control Panel -> Recording devices. "
                               "Attempting to use default name: " + resolved);
                for (const QVariant &d2 : devices) {
                    QVariantMap m2 = d2.toMap();
                    QString name2 = m2.value("name").toString().toLower();
                    QString id2 = m2.value("id").toString();
                    if (name2.contains("virtual-audio-capturer") || name2.contains("stereo mix") || name2.contains("立体声混音") || name2.contains("loopback") || name2.contains("what u hear")) {
                        resolved = id2;
                        if (!resolved.startsWith("@")) resolved = "audio=" + m2.value("name").toString();
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    for (const QVariant &d3 : devices) {
                        QVariantMap m3 = d3.toMap();
                        QString name3 = m3.value("name").toString().toLower();
                        QString id3 = m3.value("id").toString();
                        if (name3.contains("microphone") || name3.contains("麦克风")) {
                            resolved = id3;
                            if (!resolved.startsWith("@")) resolved = "audio=" + m3.value("name").toString();
                            found = true;
                            break;
                        }
                    }
                }
            }
        } 
        // Handle generic "Microphone" request
        else if (resolved == "audio=Microphone") {
             QVariantList devices = getAudioDevices();
             bool found = false;
             for (const QVariant &d : devices) {
                 QVariantMap m = d.toMap();
                 QString name = m.value("name").toString().toLower();
                 if (name.contains("microphone") || name.contains("麦克风")) {
                     resolved = m.value("id").toString();
                     if (!resolved.startsWith("@")) resolved = "audio=" + m.value("name").toString();
                     found = true;
                     break;
                 }
             }
             // If not found, keep "audio=Microphone" and let ffmpeg fail or try default?
             // Actually, better to try a likely guess if detection failed
             if (!found) resolved = "audio=麦克风 (Realtek High Definition Audio)";
        }
        else if (!resolved.startsWith("@") && !resolved.startsWith("audio=")) {
            // Legacy path: device name provided directly?
            QVariantList devices = getAudioDevices();
            for (const QVariant &d : devices) {
                QVariantMap m = d.toMap();
                if (m.value("name").toString() == resolved) {
                    resolved = m.value("id").toString();
                    break;
                }
            }
        }
        
        // Validate device exists before adding input
        bool audioValid = false;
        QVariantList devs = getAudioDevices();
        for (const QVariant &d : devs) {
            QVariantMap m = d.toMap();
            QString id = m.value("id").toString();
            QString name = m.value("name").toString();
            if (resolved.startsWith("@")) {
                if (id == resolved) { audioValid = true; break; }
            } else if (resolved.startsWith("audio=")) {
                if (id == resolved || ("audio=" + name) == resolved) { audioValid = true; break; }
            } else {
                if (name == resolved) { audioValid = true; break; }
            }
        }
        if (audioValid) {
            QStringList audioArgs;
            audioArgs << "-y" << "-thread_queue_size" << "512" << "-rtbufsize" << "64M" << "-f" << "dshow";
            if (resolved.startsWith("@")) {
                audioArgs << "-i" << ("audio=" + resolved);
            } else if (resolved.startsWith("audio=")) {
                audioArgs << "-i" << resolved;
            } else {
                audioArgs << "-i" << ("audio=" + resolved);
            }
            m_hasAudioInput = true;
            QString baseOut = QUrl(outputPath).isLocalFile() ? QUrl(outputPath).toLocalFile() : outputPath;
            if (baseOut.isEmpty()) {
                QString videoLocation = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
                if (videoLocation.isEmpty()) videoLocation = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
                baseOut = videoLocation + "/Eideo_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".mp4";
            }
            QFileInfo fi(baseOut);
            QString dir = fi.absolutePath();
            QString base = fi.completeBaseName();
            m_finalOutputPath = baseOut;
            m_audioTempPath = dir + "/" + base + "_aud.aac";
            audioArgs << "-vn" << "-c:a" << "aac" << "-ac" << "2" << "-ar" << "48000" << "-b:a" << "128k" << m_audioTempPath;
            m_audioProcess->setProcessChannelMode(QProcess::MergedChannels);
            emit outputLog("Starting Audio: " + program + " " + audioArgs.join(" "));
            m_audioProcess->start(program, audioArgs);
        } else {
            emit outputLog("Audio device not found, recording video only.");
        }
    }

    QString enc = videoEncoder.isEmpty() ? QString("libx264") : videoEncoder;
    QString programDetect = program;
    QProcess encProbe;
    QStringList encArgs;
    encArgs << "-hide_banner" << "-encoders";
    encProbe.start(programDetect, encArgs);
    encProbe.waitForFinished();
    QString encOutput = QString::fromLocal8Bit(encProbe.readAllStandardOutput());
    bool encOK = encOutput.contains(enc);
    if (!encOK) enc = "libx264";
    bool isDda = (captureMethod == "ddagrab");

    if (enc == "libx264") {
        videoArgs << "-c:v" << enc;
        if (isDda) {
             // ddagrab outputs d3d11 surface, we need to download it for libx264
             videoArgs << "-vf" << "hwdownload,format=bgra,format=yuv420p";
        } else {
             videoArgs << "-pix_fmt" << "yuv420p";
        }
        videoArgs << "-preset" << "ultrafast" << "-tune" << "zerolatency";
        
        // Quality control for libx264 via CRF
        if (quality == "High") videoArgs << "-crf" << "18";
        else if (quality == "Low") videoArgs << "-crf" << "28";
        else videoArgs << "-crf" << "23"; // Medium/Default
    } else {
        videoArgs << "-c:v" << enc;
        // For HW encoders with ddagrab, we often don't need to force pix_fmt as they can handle d3d11
        // But if using gdigrab, we likely need yuv420p
        if (!isDda) {
             videoArgs << "-pix_fmt" << "yuv420p";
        } else {
             // For ddagrab + HW encoder, usually we can skip pix_fmt to avoid software conversion failure
             // But specifically for h264_nvenc, it might need guidance or just work.
             // If we want to be safe for compatibility, we might need to insert a hardware scaler if defaults are weird,
             // but usually defaults work for local playback.
        }
    }
    if (enc == "h264_nvenc") {
        QString frStr = framerate;
        bool okFr = false;
        int frVal = frStr.toInt(&okFr);
        if (!okFr || frVal <= 0) frVal = 30;
        
        // Base bitrate logic
        int baseBps = frVal >= 60 ? 12000000 : 8000000; // 12Mbps@60, 8Mbps@<=30
        
        // Adjust for quality
        int bps = baseBps;
        if (quality == "High") bps = (int)(baseBps * 1.5); // 18Mbps / 12Mbps
        else if (quality == "Low") bps = (int)(baseBps * 0.6); // 7.2Mbps / 4.8Mbps
        
        // Use variable bitrate (VBR) for better handling of complex scenes (fast motion)
        // Increase buffer size to handle bursts
        videoArgs << "-rc" << "vbr" << "-cq" << "19"; // VBR with target quality
        videoArgs << "-b:v" << QString::number(bps);
        videoArgs << "-maxrate" << QString::number(int(bps * 1.5)); // Allow peaks
        videoArgs << "-bufsize" << QString::number(bps * 3); // Larger buffer
        
        // Performance presets
        videoArgs << "-preset" << "p4"; // P4 is good balance, p7 is max quality but slower
        videoArgs << "-tune" << "ll";   // Low latency
        
        videoArgs << "-g" << QString::number(frVal * 2);
        videoArgs << "-bf" << "2";
    } else if (enc == "h264_qsv" || enc == "h264_amf") {
        QString frStr2 = framerate;
        bool okFr2 = false;
        int frVal2 = frStr2.toInt(&okFr2);
        if (!okFr2 || frVal2 <= 0) frVal2 = 30;
        
        int baseBps2 = frVal2 >= 60 ? 12000000 : 8000000;
        int bps2 = baseBps2;
        if (quality == "High") bps2 = (int)(baseBps2 * 1.5);
        else if (quality == "Low") bps2 = (int)(baseBps2 * 0.6);
        
        videoArgs << "-b:v" << QString::number(bps2) << "-maxrate" << QString::number(bps2) << "-bufsize" << QString::number(bps2 * 2);
        videoArgs << "-g" << QString::number(frVal2 * 2);
    }
    videoArgs << "-vsync" << "cfr";
    videoArgs << "-r" << framerate;
    QFileInfo fi2(QUrl(outputPath).isLocalFile() ? QUrl(outputPath).toLocalFile() : outputPath);
    QString dir2 = fi2.exists() ? fi2.absolutePath() : (QStandardPaths::writableLocation(QStandardPaths::MoviesLocation).isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) : QStandardPaths::writableLocation(QStandardPaths::MoviesLocation));
    QString base2 = fi2.exists() ? fi2.completeBaseName() : QString("Eideo_") + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    m_finalOutputPath = fi2.exists() ? (fi2.isAbsolute() ? fi2.absoluteFilePath() : dir2 + "/" + fi2.fileName()) : dir2 + "/" + base2 + ".mp4";
    m_videoTempPath = dir2 + "/" + base2 + "_vid.mkv";
    videoArgs << "-an" << m_videoTempPath;

    // Fix file path if it starts with file:///
    QString cleanPath = QUrl(outputPath).isLocalFile() ? QUrl(outputPath).toLocalFile() : outputPath;
    if (cleanPath.isEmpty()) {
        QString videoLocation = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
        if (videoLocation.isEmpty()) videoLocation = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        cleanPath = videoLocation + "/Eideo_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".mp4";
    }
    emit outputLog("Starting Video: " + program + " " + videoArgs.join(" "));
    emit conversionStarted();
    m_videoProcess->setProcessChannelMode(QProcess::MergedChannels);
    m_videoProcess->start(program, videoArgs);
}

void FFmpegRunner::stopRecording()
{
    if (m_videoProcess->state() == QProcess::Running) {
        m_videoProcess->write("q");
        m_videoProcess->closeWriteChannel();
        if (!m_videoProcess->waitForFinished(5000)) {
             emit outputLog("Video process did not finish in time, killing...");
             m_videoProcess->kill();
        }
    }
    if (m_audioProcess->state() == QProcess::Running) {
        m_audioProcess->write("q");
        m_audioProcess->closeWriteChannel();
        if (!m_audioProcess->waitForFinished(5000)) m_audioProcess->kill();
    }
    QString program = locateFFmpeg();
    QStringList muxArgs;
    
    // Check if video file is valid
    QFileInfo videoFi(m_videoTempPath);
    bool videoOk = videoFi.exists() && videoFi.size() > 1024; // At least 1KB
    bool audioOk = m_hasAudioInput && !m_audioTempPath.isEmpty() && QFile::exists(m_audioTempPath) && QFileInfo(m_audioTempPath).size() > 0;

    if (!videoOk) {
        emit outputLog("Error: Video recording failed (file empty or invalid). Possible causes: 'DirectX' capture not supported on this device, or permission issues.");
        
        // Try to rescue audio if available
        if (audioOk) {
             emit outputLog("Attempting to save audio only...");
             QString audioOnlyPath = m_finalOutputPath;
             if (audioOnlyPath.endsWith(".mp4")) audioOnlyPath.replace(".mp4", ".aac");
             else audioOnlyPath += ".aac";
             
             if (QFile::exists(audioOnlyPath)) QFile::remove(audioOnlyPath);
             if (QFile::copy(m_audioTempPath, audioOnlyPath)) {
                 emit conversionFinished(true, "Video failed, but audio saved to: " + audioOnlyPath);
             } else {
                 emit conversionFinished(false, "Video failed and audio could not be saved.");
             }
             
             // Cleanup
             if (QFile::exists(m_audioTempPath)) QFile::remove(m_audioTempPath);
             if (QFile::exists(m_videoTempPath)) QFile::remove(m_videoTempPath);
        } else {
             emit conversionFinished(false, "Recording failed. No valid video or audio produced.");
        }
        m_isMuxing = false;
        return;
    }

    if (audioOk) {
        muxArgs << "-y" << "-i" << m_videoTempPath << "-i" << m_audioTempPath << "-map" << "0:v:0" << "-map" << "1:a:0" << "-c:v" << "copy" << "-c:a" << "copy" << "-shortest" << m_finalOutputPath;
    } else {
        muxArgs << "-y" << "-i" << m_videoTempPath << "-c" << "copy" << m_finalOutputPath;
    }
    emit outputLog("Muxing: " + program + " " + muxArgs.join(" "));
    m_isMuxing = true;
    m_process->setProcessChannelMode(QProcess::MergedChannels);
    m_process->start(program, muxArgs);
}

QVariantList FFmpegRunner::getAudioDevices()
{
    QString program = locateFFmpeg();

    QProcess probeProcess;
    QStringList arguments;
    // Command: ffmpeg -list_devices true -f dshow -i dummy
    arguments << "-list_devices" << "true" << "-f" << "dshow" << "-i" << "dummy";
    
    probeProcess.start(program, arguments);
    probeProcess.waitForFinished();
    
    QByteArray raw = probeProcess.readAllStandardError();
    QString outputUtf8 = QString::fromUtf8(raw);
    QString outputLocal = QString::fromLocal8Bit(raw);
    QString output = outputUtf8.count(QChar::ReplacementCharacter) <= outputLocal.count(QChar::ReplacementCharacter) ? outputUtf8 : outputLocal;
    
    return parseAudioDevices(output);
}

void FFmpegRunner::refreshAudioDevices()
{
    QString program = locateFFmpeg();
    QProcess *probeProcess = new QProcess(this);
    QStringList arguments;
    arguments << "-list_devices" << "true" << "-f" << "dshow" << "-i" << "dummy";

    connect(probeProcess, &QProcess::finished, this, [this, probeProcess](int, QProcess::ExitStatus) {
        QByteArray raw = probeProcess->readAllStandardError();
        QString outputUtf8 = QString::fromUtf8(raw);
        QString outputLocal = QString::fromLocal8Bit(raw);
        QString output = outputUtf8.count(QChar::ReplacementCharacter) <= outputLocal.count(QChar::ReplacementCharacter) ? outputUtf8 : outputLocal;
        
        QVariantList devices = parseAudioDevices(output);
        emit audioDevicesReady(devices);
        probeProcess->deleteLater();
    });

    // Handle error just in case
    connect(probeProcess, &QProcess::errorOccurred, this, [this, probeProcess](QProcess::ProcessError) {
         // Even on error, we might want to emit empty list or log
         emit outputLog("Error probing audio devices");
         probeProcess->deleteLater();
    });

    probeProcess->start(program, arguments);
}

QVariantList FFmpegRunner::parseAudioDevices(const QString &output)
{
    QVariantList devices;
    
    // Debug output
    qDebug() << "FFmpeg dshow output:" << output;

    // Parse output logic updated to capture Alternative names
    bool audioSection = false;
    QString lastDeviceName;
    
    QStringList lines = output.split("\n");
    for (const QString &line : lines) {
        QString trimmedLine = line.trimmed();
        
        // Remove [dshow @ ...] prefix if present
        if (trimmedLine.startsWith("[dshow")) {
            int bracketIndex = trimmedLine.indexOf("] ");
            if (bracketIndex != -1) {
                trimmedLine = trimmedLine.mid(bracketIndex + 2).trimmed();
            }
        }
        
        // Check for headers
        if (trimmedLine.contains("DirectShow audio devices")) {
            audioSection = true;
            lastDeviceName.clear();
            continue;
        }
        if (trimmedLine.contains("DirectShow video devices")) {
            audioSection = false;
            lastDeviceName.clear();
            continue;
        }
        
        if (trimmedLine.startsWith("Alternative name")) {
             if (!lastDeviceName.isEmpty()) {
                 // Found ID for the last device
                 int quoteStart = trimmedLine.indexOf("\"");
                 int quoteEnd = trimmedLine.lastIndexOf("\"");
                 if (quoteStart != -1 && quoteEnd != -1 && quoteEnd > quoteStart) {
                     QString deviceId = trimmedLine.mid(quoteStart + 1, quoteEnd - quoteStart - 1);
                     
                     QVariantMap deviceMap;
                     deviceMap["name"] = lastDeviceName;
                     deviceMap["id"] = deviceId;
                     devices.append(deviceMap);
                     emit outputLog("Detected Audio Device: " + lastDeviceName + " [" + deviceId + "]");
                     
                     lastDeviceName.clear(); // Consumed
                 }
             }
             continue;
        }
        
        // Try to find device name
        QString currentDeviceName;
        bool foundName = false;

        // Check for suffix (Format B)
        if (trimmedLine.endsWith("(audio)") || trimmedLine.contains("(audio)")) {
             int quoteStart = trimmedLine.indexOf("\"");
             int quoteEnd = trimmedLine.lastIndexOf("\"", trimmedLine.indexOf("(audio)")); 
             
             if (quoteStart != -1 && quoteEnd != -1 && quoteEnd > quoteStart) {
                 currentDeviceName = trimmedLine.mid(quoteStart + 1, quoteEnd - quoteStart - 1);
                 foundName = true;
             }
        }
        // Fallback to section based (Format A)
        else if (audioSection) {
            int quoteStart = trimmedLine.indexOf("\"");
            int quoteEnd = trimmedLine.lastIndexOf("\"");
            
            if (quoteStart != -1 && quoteEnd != -1 && quoteEnd > quoteStart) {
                // Ensure it's not "Alternative name" line (already handled above, but double check)
                if (!trimmedLine.startsWith("Alternative name")) {
                    currentDeviceName = trimmedLine.mid(quoteStart + 1, quoteEnd - quoteStart - 1);
                    foundName = true;
                }
            }
        }
        
        if (foundName) {
            // If we had a pending device without ID, we might want to add it as Name=ID?
            // Usually dshow list always provides alternative name right after.
            // If not, we can support name-only devices, but let's prioritize ID.
            if (!lastDeviceName.isEmpty()) {
                // Previous one didn't have an alt name? Add it with name as ID
                QVariantMap deviceMap;
                deviceMap["name"] = lastDeviceName;
                deviceMap["id"] = "audio=" + lastDeviceName; // Fallback
                devices.append(deviceMap);
                emit outputLog("Detected Audio Device (No ID): " + lastDeviceName);
            }
            lastDeviceName = currentDeviceName;
        }
    }
    
    // Handle last pending
    if (!lastDeviceName.isEmpty()) {
         QVariantMap deviceMap;
         deviceMap["name"] = lastDeviceName;
         deviceMap["id"] = "audio=" + lastDeviceName;
         devices.append(deviceMap);
         emit outputLog("Detected Audio Device (No ID): " + lastDeviceName);
    }
    
    return devices;
}

void FFmpegRunner::compressVideo(const QString &inputPath, int crf, const QString &preset, const QString &codec, const QString &resolution, const QString &audio)
{
    // Handle file:/// prefix if present
    QString localInput = QUrl(inputPath).isLocalFile() ? QUrl(inputPath).toLocalFile() : inputPath;
    
    if (!QFile::exists(localInput)) {
        emit conversionFinished(false, "Input file does not exist: " + localInput);
        return;
    }

    QFileInfo fileInfo(localInput);
    QString outputExtension = fileInfo.suffix(); // Keep original extension
    
    QString outputPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_compressed." + outputExtension;

    QString program = locateFFmpeg();

    QStringList arguments;
    arguments << "-y" << "-i" << localInput;

    // === Video Codec ===
    if (codec == "h265") {
        arguments << "-c:v" << "libx265";
        // h265 tag for Apple compatibility sometimes needed, but we'll keep it simple
        arguments << "-tag:v" << "hvc1"; 
    } else {
        arguments << "-c:v" << "libx264";
    }

    // === Resolution ===
    if (resolution == "1080p") {
        arguments << "-vf" << "scale=-2:1080";
    } else if (resolution == "720p") {
        arguments << "-vf" << "scale=-2:720";
    } else if (resolution == "480p") {
        arguments << "-vf" << "scale=-2:480";
    }
    // "Original" does nothing

    // === Compression Settings ===
    arguments << "-crf" << QString::number(crf);
    arguments << "-preset" << preset;

    // === Audio Settings ===
    if (audio == "Remove") {
        arguments << "-an";
    } else if (audio == "128k") {
        arguments << "-c:a" << "aac" << "-b:a" << "128k";
    } else if (audio == "64k") {
        arguments << "-c:a" << "aac" << "-b:a" << "64k";
    } else {
        // "Original"
        arguments << "-c:a" << "copy";
    }

    arguments << outputPath;

    emit outputLog("Executing: " + program + " " + arguments.join(" "));
    emit conversionStarted();

    // Create Task
    m_totalDuration = 0.0; 
    Task *task = new Task("Compression", this);
    task->setStatus("Running");
    task->setDetails("Compressing " + fileInfo.fileName());
    task->setProgress(0.0);
    connect(task, &Task::requestCancel, this, &FFmpegRunner::stopConversion);

    TaskManager::instance()->addTask(task);
    m_currentTask = task;

    m_process->start(program, arguments);
}
