#pragma once

#include <QLatin1String>
#include <QString>

namespace AppleController
{
// Sample input: usb:v05ACp8290d0112dcE0dsc01dp01icE0isc01ip01in00 or acpi:BCM2E7C:APPLE-UART-BLTH:
// The UART part carries no vendor field, so its ACPI id is the only marker Apple leaves there.
inline bool modaliasIsApple(const QString &modalias)
{
    return modalias.contains(QLatin1String("v05AC"), Qt::CaseInsensitive)
        || modalias.contains(QLatin1String("APPLE-UART-BLTH"), Qt::CaseInsensitive);
}
}
