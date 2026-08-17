#include "playerstatuswatcher.h"
#include <QDBusConnection>
#include <QDBusPendingReply>
#include <QVariantMap>
#include <QDBusReply>
#include <QDBusConnectionInterface>
#include <QDebug>

PlayerStatusWatcher::PlayerStatusWatcher(const QString &playerService, QObject *parent)
    : QObject(parent),
      m_playerService(playerService),
      m_iface(new QDBusInterface(playerService, "/org/mpris/MediaPlayer2",
                                 "org.mpris.MediaPlayer2.Player", QDBusConnection::sessionBus(), this)),
      m_serviceWatcher(new QDBusServiceWatcher(playerService, QDBusConnection::sessionBus(),
                                               QDBusServiceWatcher::WatchForOwnerChange, this))
{
    if (!QDBusConnection::sessionBus().connect(
            playerService, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
            "PropertiesChanged", this,
            SLOT(onPropertiesChanged(QString,QVariantMap,QStringList))))
    {
        qWarning() << "PlayerStatusWatcher: failed to subscribe to PropertiesChanged for"
                   << playerService;
    }
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceOwnerChanged,
            this, &PlayerStatusWatcher::onServiceOwnerChanged);
    updateStatus();
}

void PlayerStatusWatcher::onPropertiesChanged(const QString &interface,
                                              const QVariantMap &changed,
                                              const QStringList &)
{
    if (interface == "org.mpris.MediaPlayer2.Player" && changed.contains("PlaybackStatus")) {
        emit playbackStatusChanged(changed.value("PlaybackStatus").toString());
    }
}

void PlayerStatusWatcher::updateStatus() {
    QVariant reply = m_iface->property("PlaybackStatus");
    if (reply.isValid()) {
        emit playbackStatusChanged(reply.toString());
    }
}

void PlayerStatusWatcher::onServiceOwnerChanged(const QString &name, const QString &, const QString &newOwner)
{
    if (name == m_playerService && newOwner.isEmpty()) {
        emit playbackStatusChanged(""); // player disappeared
    } else if (name == m_playerService && !newOwner.isEmpty()) {
        updateStatus(); // player appeared/reappeared
    }
}

QString PlayerStatusWatcher::getCurrentPlaybackStatus(const QString &playerService)
{
    QDBusConnection bus = QDBusConnection::sessionBus();

    // If a specific player was requested, query only that one.
    if (!playerService.isEmpty()) {
        QDBusInterface iface(playerService, "/org/mpris/MediaPlayer2",
                             "org.mpris.MediaPlayer2.Player", bus);
        if (iface.isValid()) {
            QVariant status = iface.property("PlaybackStatus");
            if (status.isValid()) return status.toString();
        }
        return QString();
    }

    // Otherwise pick the most-active player. Priority: Playing > Paused >
    // anything else (Stopped/empty).
    QString fallback;
    QStringList services = bus.interface()->registeredServiceNames().value();
    for (const QString &service : services) {
        if (!service.startsWith("org.mpris.MediaPlayer2.")) continue;
        QDBusInterface iface(service, "/org/mpris/MediaPlayer2",
                             "org.mpris.MediaPlayer2.Player", bus);
        if (!iface.isValid()) continue;
        QVariant status = iface.property("PlaybackStatus");
        if (!status.isValid()) continue;
        QString s = status.toString();
        if (s == "Playing") return s;
        if (s == "Paused" && fallback.isEmpty()) fallback = s;
    }
    return fallback;
}