#ifndef TASKMANAGER_H
#define TASKMANAGER_H

#include <QObject>
#include <QList>
#include "Task.h"

class TaskManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QList<QObject*> tasks READ tasks NOTIFY tasksChanged)

public:
    static TaskManager* instance();
    
    QList<QObject*> tasks() const { return m_tasks; }
    
    Q_INVOKABLE void addTask(Task* task);
    Q_INVOKABLE void removeTask(const QString& taskId);
    Q_INVOKABLE void clearCompleted();

signals:
    void tasksChanged();

private:
    explicit TaskManager(QObject *parent = nullptr);
    QList<QObject*> m_tasks;
};

#endif // TASKMANAGER_H
