#ifndef AUTOSTARTMANAGER_HPP
#define AUTOSTARTMANAGER_HPP

#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QCoreApplication>

class AutoStartManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool autoStartEnabled READ autoStartEnabled WRITE setAutoStartEnabled NOTIFY autoStartEnabledChanged)

public:
    explicit AutoStartManager(QObject *parent = nullptr) : QObject(parent)
    {
        QString autostartDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/autostart";
        QDir().mkpath(autostartDir);
        m_autostartFilePath = autostartDir + "/" + QCoreApplication::applicationName() + ".desktop";
    }

    bool autoStartEnabled() const
    {
        return QFile::exists(m_autostartFilePath);
    }

    void setAutoStartEnabled(bool enabled)
    {
        if (autoStartEnabled() == enabled)
        {
            return;
        }

        if (enabled)
        {
            createAutoStartEntry();
        }
        else
        {
            removeAutoStartEntry();
        }

        emit autoStartEnabledChanged(enabled);
    }

private:
    void createAutoStartEntry()
    {
        QString appPath = QCoreApplication::applicationFilePath();
        if (appPath.contains(' ')) {
            appPath = "\"" + appPath + "\"";
        }

        const QString content = QStringLiteral(
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=%1\n"
            "Exec=%2 --hide\n"
            "Icon=%3\n"
            "Comment=%4\n"
            "X-GNOME-Autostart-enabled=true\n"
            "Terminal=false\n")
            .arg(
                QCoreApplication::applicationName(),
                appPath,
                QCoreApplication::applicationName().toLower(),
                QCoreApplication::applicationName() + " autostart");

        // Atomic write: open<tmp> -> write -> close -> rename. No reader
        // can observe a half-written desktop file even if we race with
        // GNOME's autostart scanner or get killed mid-write.
        const QString tmpPath = m_autostartFilePath + ".tmp";
        QFile tmp(tmpPath);
        if (!tmp.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            qWarning() << "Failed to open autostart tmp:" << tmp.errorString();
            return;
        }
        if (tmp.write(content.toUtf8()) != content.toUtf8().size()) {
            qWarning() << "Short write to autostart tmp";
            tmp.close();
            QFile::remove(tmpPath);
            return;
        }
        tmp.close();
        QFile::remove(m_autostartFilePath); // QFile::rename does not replace
        if (!QFile::rename(tmpPath, m_autostartFilePath)) {
            qWarning() << "Failed to rename autostart tmp into place";
            QFile::remove(tmpPath);
        }
    }

    void removeAutoStartEntry()
    {
        // Unconditional remove — exists() then remove() is a TOCTOU race;
        // QFile::remove returns false harmlessly if the file is gone.
        QFile::remove(m_autostartFilePath);
    }

    QString m_autostartFilePath;

signals:
    void autoStartEnabledChanged(bool enabled);
};

#endif // AUTOSTARTMANAGER_HPP