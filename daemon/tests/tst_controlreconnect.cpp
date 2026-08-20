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
        QCOMPARE(ControlReconnect::delayMs(20, 999), 16499);
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

        QVERIFY(session.prepareRetry(3, false));
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
        QVERIFY(session.prepareRetry(2, false));
        QVERIFY(session.prepareRetry(2, false));
        QVERIFY(!session.prepareRetry(2, false));
        QCOMPARE(session.completedAttempts(), 2);
        QVERIFY(!session.complete());
    }

    void outlastsTheAbsentLimitWhileBlueZReportsTheDeviceConnected()
    {
        ControlReconnect::Session session;
        session.begin(false);

        for (int i = 0; i < ControlReconnect::connectedAttemptLimit; ++i) {
            QVERIFY(session.prepareRetry(1, true));
        }
        QCOMPARE(session.connectedAttempts(), ControlReconnect::connectedAttemptLimit);
    }

    void stopsRetryingWhenTheDeviceNeverAcceptsTheSocket()
    {
        ControlReconnect::Session session;
        session.begin(false);

        for (int i = 0; i < ControlReconnect::connectedAttemptLimit; ++i) {
            QVERIFY(session.prepareRetry(3, true));
        }
        QVERIFY(!session.prepareRetry(3, true));
        QCOMPARE(session.completedAttempts(), ControlReconnect::connectedAttemptLimit);
    }

    void aLimitOfZeroRefusesEveryAbsentRetry()
    {
        ControlReconnect::Session session;
        session.begin(false);
        QVERIFY(!session.prepareRetry(0, false));
        QCOMPARE(session.completedAttempts(), 0);
    }

    void aRestartedSessionGetsBothBudgetsBack()
    {
        ControlReconnect::Session session;
        session.begin(false);
        QVERIFY(session.prepareRetry(1, false));
        QVERIFY(session.prepareRetry(1, true));
        QVERIFY(!session.prepareRetry(1, false));

        // begin() on a session that is still active must not inherit the spent budget.
        session.begin(false);
        QCOMPARE(session.completedAttempts(), 0);
        QVERIFY(session.prepareRetry(1, false));
        QVERIFY(session.prepareRetry(1, true));
    }

    void countsOnlyTheRetriesTakenWhileBlueZReportsTheDeviceGone()
    {
        ControlReconnect::Session session;
        session.begin(false);

        QVERIFY(session.prepareRetry(2, false));
        QVERIFY(session.prepareRetry(2, true));
        QVERIFY(session.prepareRetry(2, false));
        QVERIFY(!session.prepareRetry(2, false));
        QCOMPARE(session.completedAttempts(), 3);
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
        QVERIFY(!session.prepareRetry(3, false));
        QVERIFY(!session.complete());
    }

    void aProbeFromASupersededSessionIsRejected()
    {
        ControlReconnect::Session session;
        session.begin(true);
        const auto firstProbe = session.beginProbe();

        // Production only restarts a session after finalize cancels it, so drive that order.
        session.cancel();
        QVERIFY(!session.acceptsProbe(firstProbe));

        session.begin(true);
        QVERIFY(!session.acceptsProbe(firstProbe));

        const auto secondProbe = session.beginProbe();
        QVERIFY(firstProbe != secondProbe);
        QVERIFY(!session.acceptsProbe(firstProbe));
        QVERIFY(session.acceptsProbe(secondProbe));
    }
};

QTEST_GUILESS_MAIN(TestControlReconnect)
#include "tst_controlreconnect.moc"
