#include "TaskManager.h"

TaskManager* TaskManager::instance()
{
    static TaskManager* _instance = new TaskManager();
    return _instance;
}

TaskManager::TaskManager(QObject *parent) : QObject(parent)
{
}

void TaskManager::addTask(Task* task)
{
    if (!task) return;
    // Set parent to TaskManager so it doesn't get deleted unexpectedly
    task->setParent(this);
    m_tasks.append(task);
    emit tasksChanged();
}

void TaskManager::removeTask(const QString& taskId)
{
    for (int i = 0; i < m_tasks.size(); ++i) {
        Task* task = qobject_cast<Task*>(m_tasks[i]);
        if (task && task->id() == taskId) {
            task->cleanup(); // Cleanup before deleting
            m_tasks.removeAt(i);
            task->deleteLater();
            emit tasksChanged();
            return;
        }
    }
}

void TaskManager::clearCompleted()
{
    bool changed = false;
    for (int i = m_tasks.size() - 1; i >= 0; --i) {
        Task* task = qobject_cast<Task*>(m_tasks[i]);
        if (task && (task->status() == "Completed" || task->status() == "Cancelled" || task->status() == "Failed")) {
            task->cleanup();
            m_tasks.removeAt(i);
            task->deleteLater();
            changed = true;
        }
    }
    
    if (changed) {
        emit tasksChanged();
    }
}
