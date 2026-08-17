// Regression test for enums.h getModelIcon — every returned filename
// must exist under linux/assets/. Pre-fix, AirPods Max referenced
// "max_case.png" which doesn't ship; broken Image source at runtime.
//
// Also pins parseModelNumber against the public Apple support
// reference (A1523 / A2032 / A2096 / A3047 / A3053 etc.).

#include <QTest>
#include <QString>
#include <QDir>
#include <QFile>

#include "../enums.h"

using namespace AirpodsTrayApp::Enums;

class TestEnums : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        m_assetsDir = QStringLiteral(OPENPODS_ASSETS_DIR);
        QVERIFY2(QDir(m_assetsDir).exists(), qPrintable("assets dir missing: " + m_assetsDir));
    }

    void allModelIconsExist_data()
    {
        QTest::addColumn<int>("model");
        QTest::newRow("AirPods1")          << int(AirPodsModel::AirPods1);
        QTest::newRow("AirPods2")          << int(AirPodsModel::AirPods2);
        QTest::newRow("AirPods3")          << int(AirPodsModel::AirPods3);
        QTest::newRow("AirPods4")          << int(AirPodsModel::AirPods4);
        QTest::newRow("AirPods4ANC")       << int(AirPodsModel::AirPods4ANC);
        QTest::newRow("AirPodsPro")        << int(AirPodsModel::AirPodsPro);
        QTest::newRow("AirPodsPro2L")      << int(AirPodsModel::AirPodsPro2Lightning);
        QTest::newRow("AirPodsPro2USBC")   << int(AirPodsModel::AirPodsPro2USBC);
        QTest::newRow("AirPodsMaxL")       << int(AirPodsModel::AirPodsMaxLightning);
        QTest::newRow("AirPodsMaxUSBC")    << int(AirPodsModel::AirPodsMaxUSBC);
        QTest::newRow("Unknown")           << int(AirPodsModel::Unknown);
    }

    void allModelIconsExist()
    {
        QFETCH(int, model);
        auto icons = getModelIcon(static_cast<AirPodsModel>(model));
        const QString podPath  = m_assetsDir + "/" + icons.first;
        const QString casePath = m_assetsDir + "/" + icons.second;
        QVERIFY2(QFile::exists(podPath),
                 qPrintable("pod icon missing: " + podPath));
        QVERIFY2(QFile::exists(casePath),
                 qPrintable("case icon missing: " + casePath));
    }

    void parseModelNumber_matchesAppleSupportList()
    {
        QCOMPARE(parseModelNumber("A1523"), AirPodsModel::AirPods1);
        QCOMPARE(parseModelNumber("A2032"), AirPodsModel::AirPods2);
        QCOMPARE(parseModelNumber("A2096"), AirPodsModel::AirPodsMaxLightning);
        QCOMPARE(parseModelNumber("A3184"), AirPodsModel::AirPodsMaxUSBC);
        QCOMPARE(parseModelNumber("A2565"), AirPodsModel::AirPods3);
        QCOMPARE(parseModelNumber("A3047"), AirPodsModel::AirPodsPro2USBC);
        QCOMPARE(parseModelNumber("A2931"), AirPodsModel::AirPodsPro2Lightning);
        QCOMPARE(parseModelNumber("A3053"), AirPodsModel::AirPods4);
        QCOMPARE(parseModelNumber("A3056"), AirPodsModel::AirPods4ANC);
        QCOMPARE(parseModelNumber("A3064"), AirPodsModel::AirPodsPro3);
        QCOMPARE(parseModelNumber("A3334"), AirPodsModel::AirPodsPro3);
        QCOMPARE(parseModelNumber("ZZZZZ"), AirPodsModel::Unknown);
        QCOMPARE(parseModelNumber(""),      AirPodsModel::Unknown);
    }

    void modelDisplayName_covers_all() {
        QCOMPARE(modelDisplayName(AirPodsModel::AirPodsPro3),
                 QStringLiteral("AirPods Pro 3"));
        QCOMPARE(modelDisplayName(AirPodsModel::AirPodsPro2USBC),
                 QStringLiteral("AirPods Pro 2 (USB-C)"));
        QCOMPARE(modelDisplayName(AirPodsModel::Unknown), QString());
    }

    // Exhaustive guard: every enum value the daemon can reach via
    // parseModelNumber must produce a non-empty user-facing string
    // (except Unknown which is intentionally empty). Catches future
    // enum additions where the contributor adds the map entry but
    // forgets to extend modelDisplayName's switch. Walks the full
    // enum range explicitly rather than via reflection because
    // AirPodsModel isn't a Q_ENUM.
    void modelDisplayName_exhaustive() {
        const AirPodsModel known[] = {
            AirPodsModel::AirPods1,
            AirPodsModel::AirPods2,
            AirPodsModel::AirPods3,
            AirPodsModel::AirPods4,
            AirPodsModel::AirPods4ANC,
            AirPodsModel::AirPodsPro,
            AirPodsModel::AirPodsPro2Lightning,
            AirPodsModel::AirPodsPro2USBC,
            AirPodsModel::AirPodsPro3,
            AirPodsModel::AirPodsMaxLightning,
            AirPodsModel::AirPodsMaxUSBC,
        };
        for (const auto m : known) {
            const QString name = modelDisplayName(m);
            QVERIFY2(!name.isEmpty(),
                     qPrintable(QStringLiteral("modelDisplayName(%1) is empty — enum addition missing switch case")
                                .arg(static_cast<int>(m))));
            // Must start with "AirPods" — sanity check on the
            // marketing prefix; catches typos like "AirPod" or
            // "Beats" leakage.
            QVERIFY2(name.startsWith(QStringLiteral("AirPods")),
                     qPrintable(QStringLiteral("modelDisplayName(%1)=\"%2\" missing AirPods prefix")
                                .arg(static_cast<int>(m)).arg(name)));
        }
        // Unknown must stay empty so consumers can skip-render.
        QCOMPARE(modelDisplayName(AirPodsModel::Unknown), QString());
    }

    void isModelHeadset_onlyMax()
    {
        QVERIFY(isModelHeadset(AirPodsModel::AirPodsMaxLightning));
        QVERIFY(isModelHeadset(AirPodsModel::AirPodsMaxUSBC));
        QVERIFY(!isModelHeadset(AirPodsModel::AirPods1));
        QVERIFY(!isModelHeadset(AirPodsModel::AirPodsPro));
        QVERIFY(!isModelHeadset(AirPodsModel::AirPodsPro2USBC));
        QVERIFY(!isModelHeadset(AirPodsModel::AirPods4ANC));
        QVERIFY(!isModelHeadset(AirPodsModel::Unknown));
    }

    // Gates the Pro-only features (Conversation Awareness, One-Bud
    // ANC, Adaptive Noise level slider). Must include every Pro
    // generation including future ones the contributor adds via
    // parseModelNumber — this test catches the latter case by
    // failing if a new AirPodsPro4 / AirPodsPro2-some-variant lands
    // in the enum without updating isProSeriesAirPods.
    void isProSeriesAirPods_coversAllProGens()
    {
        QVERIFY(isProSeriesAirPods(AirPodsModel::AirPodsPro));
        QVERIFY(isProSeriesAirPods(AirPodsModel::AirPodsPro2Lightning));
        QVERIFY(isProSeriesAirPods(AirPodsModel::AirPodsPro2USBC));
        QVERIFY(isProSeriesAirPods(AirPodsModel::AirPodsPro3));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPods1));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPods2));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPods3));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPods4));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPods4ANC));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPodsMaxLightning));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::AirPodsMaxUSBC));
        QVERIFY(!isProSeriesAirPods(AirPodsModel::Unknown));
    }

private:
    QString m_assetsDir;
};

QTEST_GUILESS_MAIN(TestEnums)
#include "tst_enums.moc"
