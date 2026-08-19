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

    void tracksRecoveryLifecycle()
    {
        ControlReconnect::Session session;
        session.begin(true);
        QCOMPARE(session.state(), ControlReconnect::State::Waiting);

        const auto firstProbe = session.beginProbe();
        QVERIFY(session.acceptsProbe(firstProbe));
        session.beginConnection();
        QVERIFY(!session.acceptsProbe(firstProbe));
        QCOMPARE(session.state(), ControlReconnect::State::ConnectingSocket);

        QVERIFY(session.prepareRetry(3));
        QCOMPARE(session.completedAttempts(), 1);
        QCOMPARE(session.state(), ControlReconnect::State::Waiting);

        const auto secondProbe = session.beginProbe();
        QVERIFY(session.acceptsProbe(secondProbe));
        QVERIFY(!session.acceptsProbe(firstProbe));
        QVERIFY(session.complete());
        QCOMPARE(session.state(), ControlReconnect::State::Idle);
        QVERIFY(!session.acceptsProbe(secondProbe));
    }

    void stopsRetryingAtTheAttemptLimit()
    {
        ControlReconnect::Session session;
        session.begin(false);
        QVERIFY(session.prepareRetry(2));
        QVERIFY(session.prepareRetry(2));
        QVERIFY(!session.prepareRetry(2));
        QCOMPARE(session.completedAttempts(), 2);
        QVERIFY(!session.complete());
    }

    void aCancelledSessionCannotBeRetried()
    {
        ControlReconnect::Session session;
        session.begin(true);
        const auto probe = session.beginProbe();

        session.cancel();
        QCOMPARE(session.state(), ControlReconnect::State::Idle);
        QVERIFY(!session.isActive());
        QVERIFY(!session.acceptsProbe(probe));
        QVERIFY(!session.prepareRetry(3));
        QVERIFY(!session.complete());
    }

    void aProbeFromASupersededSessionIsRejected()
    {
        ControlReconnect::Session session;
        session.begin(true);
        const auto firstProbe = session.beginProbe();

        // A second disconnect restarts the session while the first probe is still in flight.
        session.begin(true);
        const auto secondProbe = session.beginProbe();

        QVERIFY(!session.acceptsProbe(firstProbe));
        QVERIFY(session.acceptsProbe(secondProbe));
    }
};

QTEST_GUILESS_MAIN(TestControlReconnect)
#include "tst_controlreconnect.moc"
