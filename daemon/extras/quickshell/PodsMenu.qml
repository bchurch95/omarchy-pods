// PodsMenu — OpenPods Quickshell menu mounted via shell.qml.
//
// v0 scaffold: read-only state + noise-control segmented + per-pod
// battery rows. Reuses CommandCenter design language (PanelWindow +
// WlrLayershell.Overlay + Theme tokens, no bespoke primitives).
//
// Data: AirPods singleton (subscribes to /tmp/app_server status IPC,
// schema_version 1). Future: swap to com.openpods.Pods1 D-Bus when
// implemented (queued in LOOP_BACKLOG.md under OEM integration).
//
// Visibility: UiState.podsMenuShown. Tray-icon left-click handler
// flips it; iter-future SNI binding will own that.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Variants {
    model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

    PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        visible: UiState.podsMenuShown
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-podsmenu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        exclusionMode: ExclusionMode.Ignore

        onVisibleChanged: {
            if (visible) {
                // Force a fresh status poll the moment the menu opens.
                // Otherwise the user might briefly see the empty-state
                // text on first-launch open before the 5 s Timer fires
                // its first tick. AirPods.refresh() returns immediately;
                // the daemon reply lands within ~10 ms and the digest
                // flips _connected + populates the model name.
                AirPods.refresh();
                // Speed the poll cadence to 1 s while the menu is open
                // so battery percentages + ear-sense state stay near-
                // live as the user interacts; restore the 5 s idle
                // cadence when the menu hides so the daemon isn't
                // serving 5x as many requests for an off-screen panel.
                AirPods.pollInterval = 1000;
                keyHandler.forceActiveFocus();
            } else {
                AirPods.pollInterval = 5000;
            }
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: panel.visible
            Keys.onEscapePressed: UiState.podsMenuShown = false

            // Arrow-key parity with the mouse-wheel cycle handler on
            // the noise-control segmented (iter-43). Whole menu treats
            // Left/Right as cycle controls while open — no per-segment
            // focus ring needed for v0 since there is only one
            // adjustable surface. Up/Down route through the same
            // direction so trackpad-only users can swipe vertically
            // and still drive the cycle.
            Keys.onLeftPressed: cycleNoise(-1)
            Keys.onUpPressed:   cycleNoise(-1)
            Keys.onRightPressed: cycleNoise(1)
            Keys.onDownPressed:  cycleNoise(1)
            Keys.onReturnPressed: cycleNoise(1)
            Keys.onSpacePressed:  cycleNoise(1)
            function cycleNoise(dir) {
                if (!AirPods.connected) return;
                const cur = AirPods.noiseMode < 0 ? 0 : AirPods.noiseMode;
                AirPods.setNoiseMode((cur + dir + 4) % 4);
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.podsMenuShown = false
        }

        Rectangle {
            id: contentPanel
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 38
            anchors.rightMargin: 8
            width: 380
            height: Math.min(540, parent.height - 46)
            radius: 12
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1
            clip: true

            // Top-level AT-SPI label so screen readers announce the
            // surface on focus. Role = Dialog because the panel is
            // modal-by-click-outside, matching the Apple Control
            // Center "AirPods card" affordance.
            Accessible.role: Accessible.Dialog
            Accessible.name: AirPods.deviceName !== "" ? AirPods.deviceName + " menu"
                                                       : "OpenPods menu"

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // Header
                RowLayout {
                    width: parent.width
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: AirPods.deviceName !== "" ? AirPods.deviceName : "OpenPods"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Theme.colFg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        // Model subtitle. Hidden when the daemon hasn't
                        // identified the device yet (Unknown enum -> empty
                        // string). Apple Control Center stacks the model
                        // marketing name immediately below the device name
                        // — match that layout exactly.
                        Text {
                            visible: text !== ""
                            text: AirPods.modelName
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.colDim
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            // Screen readers already read the device-name
                            // line above as the dialog header; mark this
                            // as a model-identifier StaticText so Orca
                            // says "AirPods Pro 3" instead of skipping
                            // the unlabeled secondary line entirely.
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Model: " + text
                            Accessible.ignored: !visible
                        }
                    }
                    Rectangle {
                        id: connDot
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: AirPods.connected ? Theme.colOnline : Theme.colUrgent
                        Layout.alignment: Qt.AlignVCenter
                        // Status dot is the only visual cue for connection
                        // state in the header. Without a11y, Orca skips it.
                        // Read as a status indicator so the announcer says
                        // "Connected" / "Disconnected" right after the
                        // device name.
                        Accessible.role: Accessible.StaticText
                        Accessible.name: AirPods.connected ? "Connected" : "Disconnected"

                        // Color transitions smoothly on connect/disconnect
                        // events. Without this the dot snaps, which reads
                        // as a state-loss glitch rather than a status change.
                        Behavior on color {
                            ColorAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }

                        // Subtle 1.0 <-> 0.55 breathing while connected
                        // signals "live link". Stops the moment connection
                        // drops so a dead dot doesn't look alive. Period
                        // chosen so the dot peaks once per 2.4s — slow
                        // enough not to compete with the segmented control's
                        // 180ms hover animation.
                        SequentialAnimation on opacity {
                            id: connBreath
                            running: AirPods.connected
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 1200; easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) connDot.opacity = 1.0
                        }
                    }
                    Text {
                        text: AirPods.connected ? "Connected" : "Disconnected"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.colDim
                    }
                }

                // Battery row — L pod, R pod, case
                RowLayout {
                    width: parent.width
                    spacing: 14
                    visible: AirPods.connected

                    Repeater {
                        model: [
                            { label: "L",    level: AirPods.leftLevel,  charging: AirPods.leftCharging,  inEar: AirPods.leftInEar,  hasEarSense: true },
                            { label: "R",    level: AirPods.rightLevel, charging: AirPods.rightCharging, inEar: AirPods.rightInEar, hasEarSense: true },
                            { label: "Case", level: AirPods.caseLevel,  charging: AirPods.caseCharging,  inEar: true,               hasEarSense: false }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            // In-ear visual cue: dim the whole cell to 0.5
                            // when the pod is out of ear (matches PodColumn
                            // in Main.qml + Apple's iOS Settings cell
                            // dimming behavior). Case never has in-ear
                            // semantics, so hasEarSense gates the dim.
                            opacity: (modelData.hasEarSense && !modelData.inEar) ? 0.5 : 1.0
                            Behavior on opacity {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            // AT-SPI: each battery cell announces as
                            // "<label> battery <N percent>" or
                            // "<label> battery unknown" when the source
                            // isn't reporting. Charging state appended
                            // when applicable. In-ear suffix added for
                            // L/R so the screen reader user knows wear
                            // status without scanning the visual dim.
                            // Role = StaticText so assistive tools don't
                            // try to invoke it.
                            Accessible.role: Accessible.StaticText
                            Accessible.name: {
                                const lvl = modelData.level >= 0
                                    ? modelData.level + " percent"
                                    : "unknown";
                                const chg = modelData.charging ? ", charging" : "";
                                const ear = modelData.hasEarSense
                                    ? (modelData.inEar ? ", in ear" : ", out of ear")
                                    : "";
                                return modelData.label + " battery " + lvl + chg + ear;
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 3
                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.colDim
                                }
                                // Bolt glyph next to the L/R/Case label
                                // when that source is charging. Mirrors
                                // the iOS battery row indicator: a small
                                // lightning bolt at the source name level
                                // is more legible than relying purely on
                                // the percentage going green, especially
                                // when the percentage is itself dimmed
                                // (out-of-ear at 0.5 opacity).
                                Text {
                                    visible: modelData.charging
                                    text: "\u{f0e7}"  // nf-mdi-flash
                                    font.family: Theme.iconFont
                                    font.pixelSize: 10
                                    color: Theme.colOnline
                                    Accessible.ignored: true
                                }
                            }
                            Text {
                                id: levelText
                                // Critical-battery state: known level <=10
                                // and the source isn't charging. Matches
                                // the LowBatteryLatch threshold in main.cpp
                                // (linux/lowbatterywatcher.hpp) — keep the
                                // two in sync.
                                readonly property bool critical: modelData.level >= 0
                                    && modelData.level <= 10
                                    && !modelData.charging
                                text: modelData.level >= 0
                                      ? modelData.level + "%"
                                      : "—"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.features: { "tnum": 1 }
                                color: critical
                                       ? Theme.colUrgent
                                       : (modelData.charging ? Theme.colOnline : Theme.colFg)
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Layout.alignment: Qt.AlignHCenter

                                // Soft 1.0 <-> 0.55 sine pulse while the
                                // source is critical. Runs only when
                                // `critical` is true; opacity is snapped
                                // back to 1.0 when the condition clears
                                // so we don't leave the text dimmed mid-
                                // cycle.
                                SequentialAnimation on opacity {
                                    running: levelText.critical
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                                }
                                onCriticalChanged: if (!critical) opacity = 1.0
                            }
                        }
                    }
                }

                // Noise control — read-only display for v0; future tick
                // wires the Set call once D-Bus surface exists.
                Column {
                    width: parent.width
                    spacing: 8
                    visible: AirPods.connected

                    Text {
                        text: "NOISE CONTROL"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                        color: Theme.colDim
                    }
                    RowLayout {
                        width: parent.width
                        spacing: 0

                        // macOS Control Center parity: scrolling the wheel
                        // over the noise-control segmented advances/retreats
                        // the mode. Up = previous (Off..Adaptive..backwards),
                        // down = next. Touchpad two-finger swipe routes the
                        // same way because both produce angleDelta.y.
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: function(event) {
                                if (event.angleDelta.y === 0) return;
                                const cur = AirPods.noiseMode < 0 ? 0 : AirPods.noiseMode;
                                const dir = event.angleDelta.y > 0 ? -1 : 1;
                                const next = (cur + dir + 4) % 4;
                                AirPods.setNoiseMode(next);
                                event.accepted = true;
                            }
                        }

                        Repeater {
                            model: ["Off", "ANC", "Transparency", "Adaptive"]
                            delegate: Rectangle {
                                id: noiseSeg
                                required property int index
                                required property string modelData
                                readonly property bool selected: index === AirPods.noiseMode
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 6
                                // Three-state visual: selected > pressed > hover > rest.
                                // Selected wins because the chosen mode should always
                                // look distinct from any transient interaction tint.
                                color: selected ? Theme.colToggleOn
                                       : segHover.pressed ? Theme.colBorder
                                       : segHover.containsMouse ? Theme.colBorder
                                       : Theme.colToggleOff
                                border.color: noiseSeg.activeFocus ? Theme.colAccent : Theme.colBorder
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                activeFocusOnTab: true
                                Keys.onReturnPressed: AirPods.setNoiseMode(noiseSeg.index)
                                Keys.onSpacePressed: AirPods.setNoiseMode(noiseSeg.index)

                                Accessible.role: Accessible.Button
                                Accessible.name: modelData
                                Accessible.checkable: true
                                Accessible.checked: selected
                                Accessible.onPressAction: AirPods.setNoiseMode(index)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: selected ? Font.DemiBold : Font.Normal
                                    color: selected ? Theme.colBg : Theme.colFg
                                }
                                MouseArea {
                                    id: segHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AirPods.setNoiseMode(index)
                                }
                            }
                        }
                    }
                }

                // Adaptive Noise level slider. Only meaningful when
                // noise_mode == Adaptive (3); hidden otherwise to match
                // Apple Control Center, which collapses the slider when
                // Adaptive isn't the active mode. Snap to 5% steps so it
                // matches Quickshell's keyboard-volume step (see OPEN
                // BUG: AVRCP-stem volume 6.67% snap).
                ColumnLayout {
                    width: parent.width
                    spacing: 6
                    visible: AirPods.connected && AirPods.noiseMode === 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Adaptive Noise"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.colFg
                            Layout.fillWidth: true
                        }
                        Text {
                            text: AirPods.adaptiveNoiseLevel + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.features: { "tnum": 1 }
                            color: Theme.colDim
                        }
                    }

                    Slider {
                        id: adaptiveSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 5
                        snapMode: Slider.SnapAlways
                        value: AirPods.adaptiveNoiseLevel
                        Accessible.role: Accessible.Slider
                        Accessible.name: "Adaptive Noise level"
                        // Live numeric value for screen readers. Without
                        // this AT-SPI reads only the role + name; Orca
                        // can't announce "37 percent" on every step.
                        Accessible.description: Math.round(value) + " percent"
                        Accessible.ignored: !visible

                        onMoved: AirPods.setAdaptiveNoiseLevel(value)

                        background: Rectangle {
                            x: adaptiveSlider.leftPadding
                            y: adaptiveSlider.topPadding + adaptiveSlider.availableHeight / 2 - height / 2
                            width: adaptiveSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.colToggleOff
                            Rectangle {
                                width: adaptiveSlider.visualPosition * parent.width
                                height: parent.height
                                color: Theme.colFg
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: adaptiveSlider.leftPadding + adaptiveSlider.visualPosition * (adaptiveSlider.availableWidth - width)
                            y: adaptiveSlider.topPadding + adaptiveSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.colFg
                            border.color: Theme.colBorder
                            border.width: 1
                        }
                    }
                }

                // Automatic Ear Detection toggle. Apple Settings > AirPods
                // parity. enum: 0 = PauseWhenOneRemoved (default, "on" in
                // PodsMenu UI), 1 = PauseWhenBothRemoved, 2 = Disabled
                // ("off"). PodsMenu collapses the tri-state into a binary
                // on/off because that's how Apple presents it; the
                // both-removed mode stays reachable via `openpods-ctl
                // ear:both` for power users.
                RowLayout {
                    width: parent.width
                    spacing: 12
                    visible: AirPods.connected

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Automatic Ear Detection"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colFg
                        }
                        Text {
                            text: "Pause when a pod is removed"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colDim
                        }
                    }

                    Rectangle {
                        id: earToggle
                        readonly property bool enabled_: AirPods.earDetectionBehavior !== 2
                        implicitWidth: 44
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        radius: 13
                        color: enabled_ ? Theme.colToggleOn : Theme.colToggleOff
                        // Focus ring: colAccent when activeFocus, colBorder
                        // otherwise. Lets keyboard-tabbed users see the
                        // current focus target on toggle controls.
                        border.color: earToggle.activeFocus ? Theme.colAccent : Theme.colBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: AirPods.setEarDetectionBehavior(earToggle.enabled_ ? 2 : 0)
                        Keys.onSpacePressed: AirPods.setEarDetectionBehavior(earToggle.enabled_ ? 2 : 0)

                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Automatic Ear Detection"
                        Accessible.checkable: true
                        Accessible.checked: enabled_
                        Accessible.onPressAction: AirPods.setEarDetectionBehavior(enabled_ ? 2 : 0)

                        Rectangle {
                            id: earKnob
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.colBg
                            anchors.verticalCenter: parent.verticalCenter
                            x: earToggle.enabled_ ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            // Press-down feedback. Apple toggles spring the
                            // knob inward when held; matched here with a
                            // brief scale 1.0 -> 0.86 on press. The Behavior
                            // animates the release rebound. transformOrigin
                            // stays Center so the press doesn't drift the
                            // knob's anchor.
                            scale: earMouse.pressed ? 0.86 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: earMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AirPods.setEarDetectionBehavior(earToggle.enabled_ ? 2 : 0)
                        }
                    }
                }

                // Conversation Awareness toggle. Pro2/Pro3 only.
                // Visibility: AirPods.connected AND (isProSeries OR
                // modelName empty). The empty-modelName clause keeps
                // the row visible during the first ~10ms after connect
                // when the daemon hasn't received AAP metadata yet —
                // hiding-then-showing produces a visible flicker on
                // tray-click. Once identification lands, non-Pro models
                // hide the row cleanly. Matches Apple Control Center
                // hardware-gating + iter-100 isProSeriesAirPods helper.
                RowLayout {
                    width: parent.width
                    spacing: 12
                    visible: AirPods.connected && (AirPods.isProSeries || AirPods.modelName === "")

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Conversation Awareness"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colFg
                        }
                        Text {
                            text: "Lower volume when you start speaking"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colDim
                        }
                    }

                    Rectangle {
                        id: caToggle
                        readonly property bool enabled_: AirPods.conversationalAwareness
                        implicitWidth: 44
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        radius: 13
                        color: enabled_ ? Theme.colToggleOn : Theme.colToggleOff
                        border.color: caToggle.activeFocus ? Theme.colAccent : Theme.colBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: AirPods.setConversationalAwareness(!caToggle.enabled_)
                        Keys.onSpacePressed: AirPods.setConversationalAwareness(!caToggle.enabled_)

                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Conversation Awareness"
                        Accessible.checkable: true
                        Accessible.checked: enabled_
                        Accessible.onPressAction: AirPods.setConversationalAwareness(!enabled_)

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.colBg
                            anchors.verticalCenter: parent.verticalCenter
                            x: caToggle.enabled_ ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            scale: caMouse.pressed ? 0.86 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: caMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AirPods.setConversationalAwareness(!caToggle.enabled_)
                        }
                    }
                }

                // One-Bud ANC toggle. Pro2/Pro3 only. Same Pro-series
                // gate as Conversation Awareness above; see that block's
                // comment for the empty-modelName rationale.
                RowLayout {
                    width: parent.width
                    spacing: 12
                    visible: AirPods.connected && (AirPods.isProSeries || AirPods.modelName === "")

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "One-Bud ANC"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colFg
                        }
                        Text {
                            text: "Keep noise cancellation on with one pod"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colDim
                        }
                    }

                    Rectangle {
                        id: onebudToggle
                        readonly property bool enabled_: AirPods.oneBudANC
                        implicitWidth: 44
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        radius: 13
                        color: enabled_ ? Theme.colToggleOn : Theme.colToggleOff
                        border.color: onebudToggle.activeFocus ? Theme.colAccent : Theme.colBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: AirPods.setOneBudANC(!onebudToggle.enabled_)
                        Keys.onSpacePressed: AirPods.setOneBudANC(!onebudToggle.enabled_)

                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "One-Bud ANC"
                        Accessible.checkable: true
                        Accessible.checked: enabled_
                        Accessible.onPressAction: AirPods.setOneBudANC(!enabled_)

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.colBg
                            anchors.verticalCenter: parent.verticalCenter
                            x: onebudToggle.enabled_ ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            scale: onebudMouse.pressed ? 0.86 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: onebudMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AirPods.setOneBudANC(!onebudToggle.enabled_)
                        }
                    }
                }

                // Connect / Disconnect — label tracks the current
                // AirPods.connected state. Clicking shells out to
                // bluetoothctl on the daemon side (no AAP packet, just
                // BlueZ control). Always visible so the user can
                // re-establish the link from PodsMenu when the dropdown
                // says disconnected.
                Rectangle {
                    id: connectButton
                    Layout.fillWidth: true
                    width: parent.width
                    implicitHeight: 32
                    radius: 8
                    // Three-state visual + focus ring. Pressed > hover >
                    // focus > rest. Pressed darkens via colBorder, focus
                    // adds a 1px colAccent border ring so keyboard-tabbed
                    // users see active state. Rest uses colToggleOff.
                    color: connectHover.pressed ? Theme.colBorder
                          : connectHover.containsMouse ? Theme.colBorder
                          : Theme.colToggleOff
                    border.color: connectButton.activeFocus ? Theme.colAccent : Theme.colBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    activeFocusOnTab: true
                    Keys.onReturnPressed: {
                        if (AirPods.connected) AirPods.disconnectAirPods();
                        else AirPods.connectAirPods();
                    }
                    Keys.onSpacePressed: {
                        if (AirPods.connected) AirPods.disconnectAirPods();
                        else AirPods.connectAirPods();
                    }

                    Text {
                        anchors.centerIn: parent
                        text: AirPods.connected ? "Disconnect" : "Connect"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.colFg
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: AirPods.connected
                                     ? "Disconnect AirPods"
                                     : "Connect AirPods"
                    Accessible.onPressAction: {
                        if (AirPods.connected) AirPods.disconnectAirPods();
                        else AirPods.connectAirPods();
                    }

                    MouseArea {
                        id: connectHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (AirPods.connected) AirPods.disconnectAirPods();
                            else AirPods.connectAirPods();
                        }
                    }
                }

                // Pop-out: surface the full Main.qml app window. Apple
                // Control Center's "Pop Out" affordance on the AirPods
                // card. Uses the existing `reopen` IPC verb (the same
                // path the single-instance check uses when a second
                // launch attempts to start). Non-destructive — no
                // confirmation needed.
                Rectangle {
                    id: popoutButton
                    visible: AirPods.connected
                    Layout.fillWidth: true
                    width: parent.width
                    implicitHeight: 32
                    radius: 8
                    color: popoutHover.pressed ? Theme.colBorder
                          : popoutHover.containsMouse ? Theme.colBorder
                          : Theme.colToggleOff
                    border.color: popoutButton.activeFocus ? Theme.colAccent : Theme.colBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    activeFocusOnTab: true
                    Keys.onReturnPressed: {
                        AirPods.reopenWindow();
                        UiState.podsMenuShown = false;
                    }
                    Keys.onSpacePressed: {
                        AirPods.reopenWindow();
                        UiState.podsMenuShown = false;
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Pop Out Window"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.colFg
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: "Pop out the full OpenPods window"
                    Accessible.onPressAction: {
                        AirPods.reopenWindow();
                        UiState.podsMenuShown = false;
                    }

                    MouseArea {
                        id: popoutHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            AirPods.reopenWindow();
                            UiState.podsMenuShown = false;
                        }
                    }
                }

                // Footer — destructive actions. Tap-to-arm pattern instead
                // of a modal dialog: first click flips the label to
                // "Tap again to confirm" + sets a 4s auto-reset timer;
                // second click within the window invokes
                // AirPods.forgetDevice() (daemon walks `bluetoothctl
                // remove <addr>`) and closes the menu. Matches the
                // reversible-action guidance — Apple shows a dialog,
                // we collapse it into one in-place affordance.
                Rectangle {
                    id: forgetButton
                    visible: AirPods.connected
                    Layout.fillWidth: true
                    width: parent.width
                    implicitHeight: 32
                    radius: 8
                    color: armed
                           ? Theme.colUrgent
                           : (forgetHover.containsMouse ? Theme.colBorder : Theme.colToggleOff)
                    border.color: armed ? Theme.colUrgent : Theme.colBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    property bool armed: false
                    Timer {
                        id: armResetTimer
                        interval: 4000
                        onTriggered: forgetButton.armed = false
                    }

                    Text {
                        anchors.centerIn: parent
                        text: forgetButton.armed
                              ? "Tap again to confirm"
                              : "Forget This Device"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: forgetButton.armed ? Font.DemiBold : Font.Medium
                        color: forgetButton.armed ? Theme.colBg : Theme.colUrgent
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: forgetButton.armed
                                     ? "Tap again to confirm forget device"
                                     : "Forget This Device"
                    Accessible.onPressAction: {
                        if (forgetButton.armed) {
                            AirPods.forgetDevice();
                            UiState.podsMenuShown = false;
                            forgetButton.armed = false;
                        } else {
                            forgetButton.armed = true;
                            armResetTimer.restart();
                        }
                    }

                    MouseArea {
                        id: forgetHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (forgetButton.armed) {
                                AirPods.forgetDevice();
                                UiState.podsMenuShown = false;
                                forgetButton.armed = false;
                            } else {
                                forgetButton.armed = true;
                                armResetTimer.restart();
                            }
                        }
                    }
                }

                // Empty-state when disconnected
                Text {
                    visible: !AirPods.connected
                    text: "Open the case lid or pair via bluetoothctl."
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.colDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
