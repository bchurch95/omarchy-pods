#include <QtTest>

#include "../applecontroller.hpp"

class TestAppleController : public QObject
{
    Q_OBJECT

private slots:
    void detectsTheUsbAppleController()
    {
        // sysfs newline-terminates modalias and the caller does not trim it, so the fixtures carry it.
        QVERIFY(AppleController::modaliasIsApple(
            QStringLiteral("usb:v05ACp8290d0112dcE0dsc01dp01icE0isc01ip01in00\n")));
    }

    void detectsTheUartAppleController()
    {
        // Read off a MacBookPro14,1 running hci_uart_bcm, where a 05AC test never fires.
        QVERIFY(AppleController::modaliasIsApple(
            QStringLiteral("acpi:BCM2E7C:APPLE-UART-BLTH:\n")));
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
        // 05AC as somebody else's product id is not Apple's vendor field, which is what the v prefix guards.
        QVERIFY(!AppleController::modaliasIsApple(
            QStringLiteral("usb:v8087p05ACd0010dcE0dsc01dp01icE0isc01ip01in00")));
        QVERIFY(!AppleController::modaliasIsApple(QString()));
    }

    void matchesRegardlessOfCase()
    {
        // The kernel's own spelling is not guaranteed, so neither marker may assume upper case.
        QVERIFY(AppleController::modaliasIsApple(QStringLiteral("usb:v05acp8290")));
        QVERIFY(AppleController::modaliasIsApple(QStringLiteral("acpi:BCM2E7C:apple-uart-blth:")));
    }
};

QTEST_GUILESS_MAIN(TestAppleController)
#include "tst_applecontroller.moc"
