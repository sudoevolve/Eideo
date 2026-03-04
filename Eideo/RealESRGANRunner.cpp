#include "RealESRGANRunner.h"
#include "TaskManager.h"
#include <QDebug>
#include <QFileInfo>
#include <QFile>
#include <QUrl>
#include <QDir>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QRegularExpression>
#include <cmath>

RealESRGANRunner::RealESRGANRunner(QObject *parent) : QObject(parent)
{
    m_process = new QProcess(this);
    
    // Lambda to handle output from both stdout and stderr
    auto handleOutput = [this](const QString &output) {
        emit outputLog(output);
        
        // Parse progress (e.g., "23.45%")
        if (output.contains("%")) {
            static QRegularExpression re("(\\d+\\.?\\d*)%");
            QRegularExpressionMatch match = re.match(output);
            if (match.hasMatch()) {
                double p = match.captured(1).toDouble();
                double progressValue = p / 100.0;
                if (progressValue > 1.0) progressValue = 1.0;
                
                emit progressChanged(progressValue);
                if (m_currentTask) {
                    m_currentTask->setProgress(progressValue);
                    m_currentTask->setDetails(QString("Processing... %1%").arg(QString::number(p, 'f', 2)));
                }
                // Return early to avoid overwriting details with raw output if it was just progress
                return;
            }
        }

        // Fallback: parse ratio pattern like "23/100", "frame 10/245", "tile 2/8"
        {
            static QRegularExpression ratioRe("(\\b|^)(\\d+)\\s*/\\s*(\\d+)(\\b|$)");
            QRegularExpressionMatch rm = ratioRe.match(output);
            if (rm.hasMatch()) {
                int num = rm.captured(2).toInt();
                int den = rm.captured(3).toInt();
                if (den > 0 && num >= 0 && num <= den && den <= 10000) {
                    double progressValue = double(num) / double(den);
                    if (progressValue > 1.0) progressValue = 1.0;
                    emit progressChanged(progressValue);
                    if (m_currentTask) {
                        m_currentTask->setProgress(progressValue);
                        m_currentTask->setDetails(QString("Processing... %1/%2").arg(num).arg(den));
                    }
                    return;
                }
            }
        }

        if (m_currentTask) {
            // Update details with last output line if it's not just a newline
             QString trimmed = output.trimmed();
             if (!trimmed.isEmpty()) {
                 // Keep details short
                 if (trimmed.length() > 50) trimmed = trimmed.left(47) + "...";
                 m_currentTask->setDetails(trimmed);
             }
        }
    };
    
    connect(m_process, &QProcess::readyReadStandardOutput, this, [this, handleOutput]() {
        handleOutput(QString::fromUtf8(m_process->readAllStandardOutput()));
    });
    
    connect(m_process, &QProcess::readyReadStandardError, this, [this, handleOutput]() {
        handleOutput(QString::fromUtf8(m_process->readAllStandardError()));
    });

    connect(m_process, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (m_currentTask) {
            if (exitStatus == QProcess::NormalExit && exitCode == 0) {
                m_currentTask->setStatus("Completed");
                m_currentTask->setProgress(1.0);
                m_currentTask->setDetails("Finished successfully");
            } else {
                // If status is already Cancelled (set in stop()), don't overwrite with Failed
                if (m_currentTask->status() != "Cancelled") {
                    m_currentTask->setStatus("Failed");
                    m_currentTask->setDetails(QString("Failed with code %1").arg(exitCode));
                }
            }
            m_currentTask = nullptr;
        }

        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            emit finished(true, "Process successful");
        } else {
            emit finished(false, QString("Process failed with exit code %1").arg(exitCode));
        }
    });
    
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            if (m_currentTask) {
                m_currentTask->setStatus("Failed");
                m_currentTask->setDetails("Failed to start executable");
                m_currentTask = nullptr;
            }
            emit finished(false, "Failed to start executable.");
        }
    });

    // Initial model scan
    refreshModels();
}

void RealESRGANRunner::refreshModels()
{
    QString program = locateExecutable();
    if (program.isEmpty()) {
        m_modelList.clear();
        emit modelListChanged();
        return;
    }

    QFileInfo programInfo(program);
    QDir modelDir(programInfo.absolutePath() + "/models");
    
    if (!modelDir.exists()) {
        m_modelList.clear();
        emit modelListChanged();
        return;
    }

    QStringList models;
    // Look for .param files, which define the network structure
    QStringList filters;
    filters << "*.param";
    
    QStringList files = modelDir.entryList(filters, QDir::Files);
    for (const QString &file : files) {
        QFileInfo fi(file);
        models << fi.completeBaseName();
    }
    
    if (m_modelList != models) {
        m_modelList = models;
        emit modelListChanged();
    }
}

QStringList RealESRGANRunner::modelList() const
{
    return m_modelList;
}

QString RealESRGANRunner::locateExecutable() {
    QStringList searchPaths;
    QString appDir = QCoreApplication::applicationDirPath();
    QString cwd = QDir::currentPath();

    searchPaths << appDir;
    searchPaths << cwd;

    QDir dir(appDir);
    for (int i = 0; i < 5; ++i) {
        if (dir.cdUp()) {
            searchPaths << dir.absolutePath();
            searchPaths << dir.absolutePath() + "/Eideo";
            searchPaths << dir.absolutePath() + "/tools/Eideo";
        } else {
            break;
        }
    }
    
    searchPaths.removeDuplicates();

    // Possible executable names
    QStringList execNames;
    execNames << "realesrgan-ncnn-vulkan.exe" << "waifu2x-ncnn-vulkan.exe";

    for (const QString &basePath : searchPaths) {
        // Check direct path
        for (const QString &exeName : execNames) {
             QString p1 = basePath + "/" + exeName;
             if (QFile::exists(p1)) return p1;
             
             QString p2 = basePath + "/bin/" + exeName;
             if (QFile::exists(p2)) return p2;
             
             QString p3 = basePath + "/tools/" + exeName;
             if (QFile::exists(p3)) return p3;
        }
        
        // Check subdirectories (e.g., bin/realesrgan-ncnn-vulkan-v0.2.0-windows/)
        QDir binDir(basePath + "/bin");
        if (binDir.exists()) {
            QStringList dirs = binDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &d : dirs) {
                for (const QString &exeName : execNames) {
                    QString p = binDir.filePath(d) + "/" + exeName;
                    if (QFile::exists(p)) return p;
                }
            }
        }
    }

    return "";
}

void RealESRGANRunner::upscaleImage(const QString &inputPath, const QString &modelName, int scale)
{
    if (m_process->state() != QProcess::NotRunning) {
        emit finished(false, "Process is already running");
        return;
    }

    QString program = locateExecutable();
    if (program.isEmpty()) {
        emit outputLog("Error: Real-ESRGAN/Waifu2x executable not found. Please place 'realesrgan-ncnn-vulkan.exe' in the app directory or bin folder.");
        emit finished(false, "Executable not found");
        return;
    }

    QString localInput = QUrl(inputPath).isLocalFile() ? QUrl(inputPath).toLocalFile() : inputPath;
    if (!QFile::exists(localInput)) {
        emit finished(false, "Input file does not exist");
        return;
    }

    QFileInfo fileInfo(localInput);
    QString outputPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_upscaled.png";

    QStringList arguments;
    arguments << "-i" << localInput;
    arguments << "-o" << outputPath;
    
    if (!modelName.isEmpty()) {
        arguments << "-n" << modelName;
    }
    
    arguments << "-s" << QString::number(scale);

    // Create Task
    QString taskName = QString("Upscale %1 (x%2)").arg(fileInfo.fileName()).arg(scale);
    m_currentTask = new Task(taskName);
    m_currentTask->setStatus("Running");
    m_currentTask->setDetails("Initializing...");
    
    // Connect cancel request
    connect(m_currentTask, &Task::requestCancel, this, &RealESRGANRunner::stop);
    
    TaskManager::instance()->addTask(m_currentTask);

    emit outputLog("Executing: " + program + " " + arguments.join(" "));
    emit started();

    // Set working directory to the folder containing the executable
    QFileInfo programInfo(program);
    m_process->setWorkingDirectory(programInfo.absolutePath());

    m_process->start(program, arguments);
}

void RealESRGANRunner::upscaleVideo(const QString &inputPath, const QString &modelName, int scale)
{
    emit outputLog("Video upscaling is not yet fully implemented. It requires FFmpeg integration to split frames.");
    emit finished(false, "Not implemented");
}

void RealESRGANRunner::stop()
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
