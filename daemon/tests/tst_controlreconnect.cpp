#include <QtTest>

#include "../controlreconnect.hpp"

class TestControlReconnect : public QObject
{
    Q_OBJECT

private slots:
    void usesExponentialBackoff()
    {
        QCOMPARE(ControlReconnect::delayMs(1, 0), 1000);
        QCOMPARE(ControlReconnect::delayMs(2, 250), 2250);
        QCOMPARE(ControlReconnect::delayMs(3, 499), 4499);
    }

    void boundsInputs()
    {
        QCOMPARE(ControlReconnect::delayMs(0, -1), 1000);
        QCOMPARE(ControlReconnect::delayMs(20, 999), 512499);
    }

    void stopsAtConfiguredLimit()
    {
        QVERIFY(ControlReconnect::hasAttemptRemaining(0, 3));
        QVERIFY(ControlReconnect::hasAttemptRemaining(2, 3));
        QVERIFY(!ControlReconnect::hasAttemptRemaining(3, 3));
        QVERIFY(!ControlReconnect::hasAttemptRemaining(0, 0));
    }
};

QTEST_GUILESS_MAIN(TestControlReconnect)
#include "tst_controlreconnect.moc"
