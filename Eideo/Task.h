#ifndef TASK_H
#define TASK_H

#include <QObject>
#include <QUuid>

class Task : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString details READ details NOTIFY detailsChanged)

public:
    explicit Task(const QString &name, QObject *parent = nullptr) 
        : QObject(parent), m_name(name), m_status("Pending"), m_progress(0.0) {
        m_id = QUuid::createUuid().toString();
    }

    QString id() const { return m_id; }
    QString name() const { return m_name; }
    QString status() const { return m_status; }
    double progress() const { return m_progress; }
    QString details() const { return m_details; }

    void setStatus(const QString &status) {
        if (m_status != status) {
            m_status = status;
            emit statusChanged();
        }
    }

    void setProgress(double progress) {
        if (m_progress != progress) {
            m_progress = progress;
            emit progressChanged();
        }
    }

    void setDetails(const QString &details) {
        if (m_details != details) {
            m_details = details;
            emit detailsChanged();
        }
    }

    // Virtual method to be overridden by specific task implementations
    // to handle cleanup of temporary files, etc.
    virtual void cleanup() {}

public slots:
    // Request the task to be cancelled. 
    // The actual cancellation logic should be connected to the requestCancel signal.
    void cancel() { 
        if (m_status == "Running" || m_status == "Pending") {
            emit requestCancel(); 
        }
    }

signals:
    void statusChanged();
    void progressChanged();
    void detailsChanged();
    void requestCancel();

private:
    QString m_id;
    QString m_name;
    QString m_status;
    double m_progress;
    QString m_details;
};

#endif // TASK_H
