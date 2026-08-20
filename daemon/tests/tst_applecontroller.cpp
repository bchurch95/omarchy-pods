#include <QtTest>

#include "../applecontroller.hpp"

class TestAppleController : public QObject
{
    Q_OBJECT

private slots:
    void detectsTheUsbAppleController()
    {
        QVERIFY(AppleController::modaliasIsApple(
            QStringLiteral("usb:v05ACp8290d0112dcE0dsc01dp01icE0isc01ip01in00")));
    }

    void detectsTheUartAppleController()
    {
        // Read off a MacBookPro14,1 running hci_uart_bcm, where a 05AC test never fires.
        QVERIFY(AppleController::modaliasIsApple(
            QStringLiteral("acpi:BCM2E7C:APPLE-UART-BLTH:")));
    }

    void leavesOtherVendorsAlone()
    {
        // Intel, the common non-Apple case, plus a non-Apple ACPI id.
        QVERIFY(!AppleController::modaliasIsApple(
            QStringLiteral("usb:v8087p0A2Bd0010dcE0dsc01dp01icE0isc01ip01in00")));
        QVERIFY(!AppleController::modaliasIsApple(
            QStringLiteral("acpi:BCM2E39:")));
        // An ACPI id that only starts with APPLE is not the UART controller.
        QVERIFY(!AppleController::modaliasIsApple(
            QStringLiteral("acpi:BCM2E39:APPLE-OTHER:")));
        QVERIFY(!AppleController::modaliasIsApple(QString()));
    }

    void matchesRegardlessOfCase()
    {
        // sysfs spelling is not guaranteed and the USB test was already case-insensitive.
        QVERIFY(AppleController::modaliasIsApple(QStringLiteral("usb:v05acp8290")));
        QVERIFY(AppleController::modaliasIsApple(QStringLiteral("acpi:BCM2E7C:apple-uart-blth:")));
    }
};

QTEST_GUILESS_MAIN(TestAppleController)
#include "tst_applecontroller.moc"
