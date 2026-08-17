#pragma once

#include <QMetaType>
#include <QHash>

namespace AirpodsTrayApp
{
    namespace Enums
    {
        Q_NAMESPACE

        enum class NoiseControlMode : quint8
        {
            Off = 0,
            NoiseCancellation = 1,
            Transparency = 2,
            Adaptive = 3,

            MinValue = Off,
            MaxValue = Adaptive,
        };
        Q_ENUM_NS(NoiseControlMode)

        enum class AirPodsModel
        {
            Unknown,
            AirPods1,
            AirPods2,
            AirPods3,
            AirPodsPro,
            AirPodsPro2Lightning,
            AirPodsPro2USBC,
            AirPodsMaxLightning,
            AirPodsMaxUSBC,
            AirPods4,
            AirPods4ANC,
            AirPodsPro3
        };
        Q_ENUM_NS(AirPodsModel)

        // Get model enum from model number
        inline AirPodsModel parseModelNumber(const QString &modelNumber)
        {
            // Model numbers taken from https://support.apple.com/en-us/109525
            QHash<QString, AirPodsModel> modelNumberMap = {
                {"A1523", AirPodsModel::AirPods1},
                {"A1722", AirPodsModel::AirPods1},
                {"A2032", AirPodsModel::AirPods2},
                {"A2031", AirPodsModel::AirPods2},
                {"A2084", AirPodsModel::AirPodsPro},
                {"A2083", AirPodsModel::AirPodsPro},
                {"A2096", AirPodsModel::AirPodsMaxLightning},
                {"A3184", AirPodsModel::AirPodsMaxUSBC},
                {"A2565", AirPodsModel::AirPods3},
                {"A2564", AirPodsModel::AirPods3},
                {"A3047", AirPodsModel::AirPodsPro2USBC},
                {"A3048", AirPodsModel::AirPodsPro2USBC},
                {"A3049", AirPodsModel::AirPodsPro2USBC},
                {"A2931", AirPodsModel::AirPodsPro2Lightning},
                {"A2699", AirPodsModel::AirPodsPro2Lightning},
                {"A2698", AirPodsModel::AirPodsPro2Lightning},
                {"A3053", AirPodsModel::AirPods4},
                {"A3050", AirPodsModel::AirPods4},
                {"A3054", AirPodsModel::AirPods4},
                {"A3056", AirPodsModel::AirPods4ANC},
                {"A3055", AirPodsModel::AirPods4ANC},
                {"A3057", AirPodsModel::AirPods4ANC},
                // AirPods Pro 3 (announced Sept 2025, USB-C only). Apple
                // ships matched L/R buds + case under their own model
                // identifiers; the daemon receives whichever one the
                // primary pod reports in its AAP metadata. A3064
                // verified from a real device 2026-05-21
                // (`librepods-ctl status | jq .model_number`); the
                // other entries are the surrounding range likely used
                // for regional variants + L/R/case pairs. Add new
                // variants here as they surface in `Model Number:`
                // log lines.
                {"A3063", AirPodsModel::AirPodsPro3},
                {"A3064", AirPodsModel::AirPodsPro3},
                {"A3065", AirPodsModel::AirPodsPro3},
                {"A3066", AirPodsModel::AirPodsPro3},
                {"A3334", AirPodsModel::AirPodsPro3},
                {"A3335", AirPodsModel::AirPodsPro3},
                {"A3336", AirPodsModel::AirPodsPro3}};

            return modelNumberMap.value(modelNumber, AirPodsModel::Unknown);
        }

        // Return icons based on model
        inline QPair<QString, QString> getModelIcon(AirPodsModel model) {
            switch (model) {
                case AirPodsModel::AirPods1:
                case AirPodsModel::AirPods2:
                    return {"pod.png", "pod_case.png"};
                case AirPodsModel::AirPods3:
                    return {"pod3.png", "pod3_case.png"};
                case AirPodsModel::AirPods4:
                case AirPodsModel::AirPods4ANC:
                    return {"pod3.png", "pod4_case.png"};
                case AirPodsModel::AirPodsPro:
                case AirPodsModel::AirPodsPro2Lightning:
                case AirPodsModel::AirPodsPro2USBC:
                case AirPodsModel::AirPodsPro3:
                    // Pro3 keeps the Pro silhouette; once a Pro3-specific
                    // asset is shipped, split this case.
                    return {"podpro.png", "podpro_case.png"};
                case AirPodsModel::AirPodsMaxLightning:
                case AirPodsModel::AirPodsMaxUSBC:
                    // AirPods Max has no physical charging case; the
                    // battery.hpp side never marks caseAvailable=true
                    // for headsets, so this slot is normally unused.
                    // Falling back to podmax.png instead of the missing
                    // `max_case.png` keeps Image.status = Ready if the
                    // QML ever does request it.
                    return {"podmax.png", "podmax.png"};
                default:
                    return {"pod.png", "pod_case.png"}; // Default icon for unknown models
            }
        }

        // User-facing model name for status surfaces (PodsMenu header
        // subtitle, openpods-ctl status, future MPRIS metadata). Maps the
        // internal enum to the marketing name Apple uses on the box.
        // Unknown -> empty string so the consumer can decide whether to
        // hide the slot or show a fallback.
        inline QString modelDisplayName(AirPodsModel model) {
            switch (model) {
                case AirPodsModel::AirPods1:               return QStringLiteral("AirPods");
                case AirPodsModel::AirPods2:               return QStringLiteral("AirPods (2nd generation)");
                case AirPodsModel::AirPods3:               return QStringLiteral("AirPods (3rd generation)");
                case AirPodsModel::AirPods4:               return QStringLiteral("AirPods 4");
                case AirPodsModel::AirPods4ANC:            return QStringLiteral("AirPods 4 with ANC");
                case AirPodsModel::AirPodsPro:             return QStringLiteral("AirPods Pro");
                case AirPodsModel::AirPodsPro2Lightning:   return QStringLiteral("AirPods Pro 2");
                case AirPodsModel::AirPodsPro2USBC:        return QStringLiteral("AirPods Pro 2 (USB-C)");
                case AirPodsModel::AirPodsMaxLightning:    return QStringLiteral("AirPods Max");
                case AirPodsModel::AirPodsMaxUSBC:         return QStringLiteral("AirPods Max (USB-C)");
                case AirPodsModel::AirPodsPro3:            return QStringLiteral("AirPods Pro 3");
                case AirPodsModel::Unknown:                return QString();
            }
            return QString();
        }

        // TODO: Only used for parseEncryptedPacket for battery status. Is it possible to determine this
        // from the data in the packet rather than by model? i.e number of batteries
        inline bool isModelHeadset(AirPodsModel model) {
            switch (model) {
                case AirPodsModel::AirPodsMaxLightning:
                case AirPodsModel::AirPodsMaxUSBC:
                    return true;
                default:
                    return false;
            }
        }

        // AirPods Pro 3 dropped the Off listening mode: the AAP packet is accepted
        // and silently ignored, measured three times against a real device with
        // both pods in ear while Transparency applied immediately afterwards.
        inline bool supportsNoiseOff(AirPodsModel model) {
            return model != AirPodsModel::AirPodsPro3;
        }

        // True for the AirPods Pro family (any generation). Used by
        // surfaces that gate Pro-only features — Conversation
        // Awareness, One-Bud ANC, Adaptive Noise level — so the
        // PodsMenu toggles can hide cleanly on AirPods 1/2/3/4 and the
        // daemon's AAP no-ops can be skipped before the packet write.
        inline bool isProSeriesAirPods(AirPodsModel model) {
            switch (model) {
                case AirPodsModel::AirPodsPro:
                case AirPodsModel::AirPodsPro2Lightning:
                case AirPodsModel::AirPodsPro2USBC:
                case AirPodsModel::AirPodsPro3:
                    return true;
                default:
                    return false;
            }
        }

    }
}
