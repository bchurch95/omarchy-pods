#pragma once

#include <QLatin1String>
#include <QString>

namespace AppleController
{
// Apple ships this controller on USB, carrying vendor id 05AC, and on UART,
// where the ACPI id has no vendor field and reads APPLE-UART-BLTH instead.
// Samples: usb:v05ACp8290d0112... and acpi:BCM2E7C:APPLE-UART-BLTH:
// Both markers are matched whole, so an unrelated ACPI id that merely starts
// with APPLE does not pause the scan on hardware that never asked for it.
inline bool modaliasIsApple(const QString &modalias)
{
    return modalias.contains(QLatin1String("v05AC"), Qt::CaseInsensitive)
        || modalias.contains(QLatin1String("APPLE-UART-BLTH"), Qt::CaseInsensitive);
}
}
