// Battery::parsePacket bounds + protocol regression.
//
// Pre-fix, parsePacket called packet[6] after only verifying the
// 6-byte BATTERY_STATUS header via startsWith. A 6-byte buffer
// (== header length, no count byte) would UB on packet[6].
// New code rejects size < 7 up front.

#include <QTest>
#include <QByteArray>
#include <QSignalSpy>
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(openpods, "openpods.test", QtWarningMsg)

#include "../battery.hpp"

class TestBattery : public QObject
{
    Q_OBJECT

private slots:
    void parsePacket_rejectsEmpty()
    {
        Battery b;
        QVERIFY(!b.parsePacket(QByteArray()));
    }

    void parsePacket_rejectsShortBelowHeader()
    {
        Battery b;
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS.left(4);
        QVERIFY(!b.parsePacket(buf));
    }

    void parsePacket_rejectsHeaderOnly()
    {
        // Exactly the header (6 bytes) — startsWith passes; pre-fix this
        // UB'd on packet[6].
        Battery b;
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        QCOMPARE(buf.size(), 6);
        QVERIFY(!b.parsePacket(buf));
    }

    void parsePacket_rejectsBatteryCountTooHigh()
    {
        Battery b;
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(4)); // count > 3 → reject
        QVERIFY(!b.parsePacket(buf));
    }

    void parsePacket_rejectsCountSizeMismatch()
    {
        Battery b;
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(1)); // 1 battery → expect 7 + 5 = 12 bytes
        buf.append(QByteArray(3, '\0')); // only 3 more = 10 total
        QVERIFY(!b.parsePacket(buf));
    }

    void parsePacket_acceptsSingleHeadset()
    {
        Battery b;
        QSignalSpy spy(&b, &Battery::batteryStatusChanged);

        // Build a valid 1-battery packet: header + count(1) + entry(5).
        // Entry layout: type, spacer(0x01), level, status, end(0x01)
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(1));                       // count
        buf.append(static_cast<char>(Battery::Component::Headset)); // type
        buf.append(static_cast<char>(0x01));                    // spacer
        buf.append(static_cast<char>(85));                      // level
        buf.append(static_cast<char>(Battery::BatteryStatus::Discharging));
        buf.append(static_cast<char>(0x01));                    // end

        QVERIFY(b.parsePacket(buf));
        QVERIFY(spy.count() >= 1);
        QCOMPARE(b.getHeadsetLevel(), quint8(85));
        QVERIFY(b.isHeadsetAvailable());
    }

    void parsePacket_rejectsBrokenSpacer()
    {
        Battery b;
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(1));
        buf.append(static_cast<char>(Battery::Component::Left));
        buf.append(static_cast<char>(0x42)); // spacer should be 0x01
        buf.append(static_cast<char>(50));
        buf.append(static_cast<char>(Battery::BatteryStatus::Discharging));
        buf.append(static_cast<char>(0x01));
        QVERIFY(!b.parsePacket(buf));
    }

    void parseEncryptedPacket_rejectsWrongSize()
    {
        Battery b;
        // Spec: must be exactly 16 bytes.
        QVERIFY(!b.parseEncryptedPacket(QByteArray(8,  '\0'), true, false, false));
        QVERIFY(!b.parseEncryptedPacket(QByteArray(15, '\0'), true, false, false));
        QVERIFY(!b.parseEncryptedPacket(QByteArray(17, '\0'), true, false, false));
    }

    void resetClearsState()
    {
        Battery b;
        // Synthesize a packet so the indicator reports a level, then reset.
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(1));
        buf.append(static_cast<char>(Battery::Component::Headset));
        buf.append(static_cast<char>(0x01));
        buf.append(static_cast<char>(75));
        buf.append(static_cast<char>(Battery::BatteryStatus::Discharging));
        buf.append(static_cast<char>(0x01));
        QVERIFY(b.parsePacket(buf));
        QCOMPARE(b.getHeadsetLevel(), quint8(75));

        b.reset();
        QCOMPARE(b.getHeadsetLevel(), quint8(0));
        QVERIFY(!b.isHeadsetAvailable());
    }

private:
    // Sample input: a 16-byte decrypted payload, byte 1 left, byte 2 right, byte 3 case, high bit charging.
    QByteArray payload(int left, int right, int caseLevel)
    {
        QByteArray p(16, '\0');
        p[1] = static_cast<char>(left);
        p[2] = static_cast<char>(right);
        p[3] = static_cast<char>(caseLevel);
        return p;
    }

private slots:
    void encryptedCaseZero_isUnknownWhileNothingIsDockedToReadIt()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(80, 80, 0), true, false, false));
        QVERIFY(!b.isCaseAvailable());
    }

    void encryptedCaseZero_isTrustedWhenAPodIsDocked()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(80, 80, 0), true, true, false));
        QVERIFY(b.isCaseAvailable());
        QCOMPARE(b.getCaseLevel(), quint8(0));
    }

    void encryptedCaseLevel_survivesThePodsLeavingTheCase()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(80, 80, 80), true, true, false));
        QCOMPARE(b.getCaseLevel(), quint8(80));

        QVERIFY(b.parseEncryptedPacket(payload(80, 80, 0), true, false, false));
        QVERIFY(b.isCaseAvailable());
        QCOMPARE(b.getCaseLevel(), quint8(80));
    }

    // A headset keeps its single battery in payload byte 1, but isLeftPodPrimary
    // flips when the headphones come off, which renames that byte from the left
    // slot to the right one. Following the mapping made the level look like it had
    // moved to a slot reading 0 -- not the 0x7F that means unknown -- so the panel
    // flickered 100% -> 0% -> 100% on every off/on. Observed on AirPods Max
    // (USB-C, A3184): rawByte1 held 100 across both states while primaryLeft went
    // true -> false.
    void encryptedHeadset_levelSurvivesThePrimaryFlip()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(100, 0, 0), true, false, true));
        QCOMPARE(b.getHeadsetLevel(), quint8(100));

        // Same bytes, primary flipped: the reading must not move.
        QVERIFY(b.parseEncryptedPacket(payload(100, 0, 0), false, false, true));
        QVERIFY(b.isHeadsetAvailable());
        QCOMPARE(b.getHeadsetLevel(), quint8(100));
    }

    // The unused slot reads 0, so 0 must not be filtered as "unknown" -- an empty
    // headset has to be able to report itself empty.
    void encryptedHeadsetZero_isARealReading()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(0, 0, 0), true, false, true));
        QVERIFY(b.isHeadsetAvailable());
        QCOMPARE(b.getHeadsetLevel(), quint8(0));
    }

    void encryptedHeadsetUnknown_leavesTheKnownLevelAlone()
    {
        Battery b;
        QVERIFY(b.parsePacket(headsetPacket(100)));
        QCOMPARE(b.getHeadsetLevel(), quint8(100));

        // 0x7F is the documented unknown marker; a level already established over
        // the AAP battery packet outlives it.
        QVERIFY(b.parseEncryptedPacket(payload(0x7F, 100, 0), true, false, true));
        QCOMPARE(b.getHeadsetLevel(), quint8(100));
    }

    void encryptedHeadsetCharging_comesFromTheHighBit()
    {
        Battery b;
        QVERIFY(b.parseEncryptedPacket(payload(90, 0, 0), true, false, true));
        QCOMPARE(b.getHeadsetLevel(), quint8(90));
        QVERIFY(!b.isHeadsetCharging());

        QVERIFY(b.parseEncryptedPacket(payload(0x80 | 90, 0, 0), true, false, true));
        QCOMPARE(b.getHeadsetLevel(), quint8(90));
        QVERIFY(b.isHeadsetCharging());
    }

private:
    // The AAP battery packet for a headset, which is what establishes a real level.
    QByteArray headsetPacket(int level)
    {
        QByteArray buf = AirPodsPackets::Parse::BATTERY_STATUS;
        buf.append(static_cast<char>(1));
        buf.append(static_cast<char>(Battery::Component::Headset));
        buf.append(static_cast<char>(0x01));
        buf.append(static_cast<char>(level));
        buf.append(static_cast<char>(Battery::BatteryStatus::Discharging));
        buf.append(static_cast<char>(0x01));
        return buf;
    }
};

QTEST_GUILESS_MAIN(TestBattery)
#include "tst_battery.moc"
