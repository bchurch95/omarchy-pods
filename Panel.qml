import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.thisisgm.omapods"
  ipcTarget: "omapods"
  manageIpc: false

  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", true) === true
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color barIconColor: pods.hasAirPods ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Say nothing extra once a section already explains the state.
  readonly property bool guidanceVisible: !pods.hasAirPods && !pods.hasBattery && !pods.schemaUnsupported

  property int phraseIndex: 0

  readonly property int lowBatteryPercent: 20
  readonly property int adaptiveStepPercent: 5
  readonly property int phraseIntervalMs: 2800

  // Ten, matching the stock panels.
  readonly property var activePhrases: [
    "All gone Pete Tong",
    "Essential Selection",
    "Genius Bar stumped",
    "Warming the decks",
    "Hands in the air",
    "Ibiza incoming",
    "Rinsing the low end",
    "Big tune loading",
    "Cued and counting in",
    "Ecosystem escaped"
  ]
  readonly property string heroPhraseText: activePhrases[phraseIndex % activePhrases.length]

  readonly property bool adaptiveVisible: pods.hasAirPods && pods.isProSeries && pods.noiseMode === Model.NOISE_ADAPTIVE
  readonly property bool proControlsVisible: pods.hasAirPods && pods.isProSeries
  readonly property string lidLabel: Model.lidText(pods.lidState)

  // The daemon decides which modes this device has, so the panel never draws a
  // row the hardware silently ignores.
  readonly property var modes: pods.availableModes()

  // Rebuilt whenever a section appears, so j and k never land on a hidden control.
  readonly property var cursorRows: {
    var rows = []
    if (!pods.hasAirPods) return rows
    for (var i = 0; i < modes.length; i++) rows.push("mode:" + modes[i])
    if (adaptiveVisible) rows.push("adaptive")
    if (proControlsVisible) {
      rows.push("ca")
      rows.push("onebud")
    }
    rows.push("ear")
    return rows
  }

  readonly property string cursorRow: cursorRows.length === 0
    ? ""
    : cursorRows[Math.max(0, Math.min(cursorIndex, cursorRows.length - 1))]

  function rowHasCursor(name) {
    return cursorActive && cursorRow === name
  }

  function moveCursor(dy) {
    cursorActive = true
    if (cursorRows.length === 0) return
    cursorIndex = Math.max(0, Math.min(cursorRows.length - 1, cursorIndex + dy))
  }

  function nudgeCursor(dx) {
    if (cursorRow === "adaptive") pods.setAdaptiveNoiseLevel(pods.adaptiveNoiseLevel + dx * adaptiveStepPercent)
  }

  function activateCursor() {
    var name = cursorRow
    if (name.indexOf("mode:") === 0) pods.setNoiseMode(parseInt(name.substring(5), 10))
    else if (name === "ca") pods.setConversationalAwareness(!pods.conversationalAwareness)
    else if (name === "onebud") pods.setOneBudANC(!pods.oneBudANC)
    else if (name === "ear") pods.cycleEarDetection()
  }

  function focusRow(name) {
    var at = cursorRows.indexOf(name)
    if (at < 0) return
    cursorActive = true
    cursorIndex = at
  }

  visible: !hideWhenDisconnected || pods.hasAirPods || pods.hasBattery
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    if (panelFlick) panelFlick.contentY = 0
    pods.refresh()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: pods
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { pods.refresh(); return "ok" }
    function noise(): string { pods.cycleNoiseMode(); return "ok" }
    function status(): string { return Model.noiseModeName(pods.noiseMode) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        AirPodsIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
        }
      }
    }
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) pods.cycleNoiseMode()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.nudgeCursor(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "r") pods.refresh()
        else if (!pods.hasAirPods) return
        else if (key === "o" && pods.supportsNoiseOff) pods.setNoiseMode(Model.NOISE_OFF)
        else if (key === "t") pods.setNoiseMode(Model.NOISE_TRANSPARENCY)
        else if (key === "n") pods.setNoiseMode(Model.NOISE_ANC)
        else if (key === "a" && pods.isProSeries) pods.setNoiseMode(Model.NOISE_ADAPTIVE)
        else if (key === "c" && pods.isProSeries) pods.setConversationalAwareness(!pods.conversationalAwareness)
        else if (key === "b" && pods.isProSeries) pods.setOneBudANC(!pods.oneBudANC)
        else if (key === "e") pods.cycleEarDetection()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: pods.modelName !== "" ? pods.modelName : (pods.deviceName !== "" ? pods.deviceName : "AirPods")
            meta: pods.hasAirPods ? root.heroPhraseText
              : pods.schemaUnsupported ? "Unsupported status schema"
              : pods.daemonReachable ? "Not connected"
              : "librepods is not running"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: pods.hasAirPods ? 1.0 : 0.5
            iconComponent: Component {
              AirPodsIcon {
                iconSize: Style.font.display
                color: pods.hasAirPods ? root.foreground : root.dim
              }
            }
          }

          Text {
            // A command failure gets its own field, or the next status poll wipes it unread.
            visible: pods.actionStatus !== "" || (pods.lastError !== "" && pods.daemonReachable)
            width: parent.width
            text: pods.actionStatus !== "" ? pods.actionStatus : pods.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: pods.hasBattery
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "BATTERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              PodRow { width: parent.width; label: "Left"; pod: pods.leftPod }
              PodRow { width: parent.width; label: "Right"; pod: pods.rightPod }
              PodRow {
                width: parent.width
                label: "Case"
                pod: ({ level: pods.caseBattery.level, charging: pods.caseBattery.charging, inEar: false })
                meta: root.lidLabel
              }
            }
          }

          PanelSeparator {
            visible: pods.hasBattery && pods.hasAirPods
            foreground: root.foreground
          }

          Column {
            visible: pods.hasAirPods
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "LISTENING MODE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.modes
                ModeRow {
                  required property var modelData
                  width: parent.width
                  mode: modelData
                }
              }
            }

            SliderRow {
              visible: root.adaptiveVisible
              width: parent.width
            }
          }

          PanelSeparator {
            visible: root.proControlsVisible
            foreground: root.foreground
          }

          Column {
            visible: root.proControlsVisible
            width: parent.width
            spacing: Style.space(6)

            ToggleRow {
              width: parent.width
              rowName: "ca"
              label: "Conversation Awareness"
              caption: "Lower the volume when you start talking"
              checked: pods.conversationalAwareness
              onToggled: pods.setConversationalAwareness(!pods.conversationalAwareness)
            }

            ToggleRow {
              width: parent.width
              rowName: "onebud"
              label: "One-Bud ANC"
              caption: "Keep noise cancellation on with one pod in"
              checked: pods.oneBudANC
              onToggled: pods.setOneBudANC(!pods.oneBudANC)
            }
          }

          PanelSeparator {
            visible: pods.hasAirPods
            foreground: root.foreground
          }

          Column {
            visible: pods.hasAirPods
            width: parent.width
            spacing: Style.space(6)

            ValueRow {
              width: parent.width
              rowName: "ear"
              label: "Ear detection"
              value: Model.earDetectionName(pods.earDetectionBehavior)
            }
          }

          Text {
            visible: root.guidanceVisible
            width: parent.width
            text: pods.daemonReachable
              ? "Open the case or connect your AirPods to see battery and listening controls."
              : "Start the librepods daemon to see battery and listening controls."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  Timer {
    id: phraseTimer
    interval: root.phraseIntervalMs
    running: root.opened && pods.hasAirPods
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  component PodRow: Item {
    id: podRow
    property string label: ""
    property var pod: Model.defaultPod()
    property string meta: ""

    readonly property string metaText: meta !== "" ? meta : Model.podMeta(pod)
    readonly property bool low: pod.level !== Model.LEVEL_UNKNOWN
      && pod.level <= root.lowBatteryPercent && !pod.charging

    implicitHeight: podLayout.implicitHeight

    RowLayout {
      id: podLayout
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(8)

      Text {
        text: podRow.label
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.preferredWidth: Style.space(44)
      }

      Rectangle {
        id: meterTrack
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: Style.space(6)
        radius: height / 2
        color: Qt.darker(root.foreground, 3.2)

        Rectangle {
          width: meterTrack.width * Model.levelFraction(podRow.pod.level)
          height: parent.height
          radius: parent.radius
          color: podRow.low ? root.urgent : root.foreground
        }
      }

      Text {
        text: Model.levelText(podRow.pod.level)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Style.space(38)
      }

      Text {
        text: podRow.metaText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        Layout.preferredWidth: Style.space(56)
      }
    }
  }

  component ModeRow: CursorSurface {
    id: modeRow
    property int mode: 0

    readonly property string rowName: "mode:" + mode
    readonly property bool selected: pods.noiseMode === mode

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: modeLabel.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(modeRow.rowName)
      onClicked: pods.setNoiseMode(modeRow.mode)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        id: modeLabel
        Layout.fillWidth: true
        text: Model.noiseModeName(modeRow.mode)
        color: root.foreground
        opacity: modeRow.selected ? 1.0 : 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        text: Model.GLYPH_CHECK
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        opacity: modeRow.selected ? 1.0 : 0.0
      }
    }
  }

  component ToggleRow: CursorSurface {
    id: toggleRow
    property string rowName: ""
    property string label: ""
    property string caption: ""
    property bool checked: false

    signal toggled()

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: toggleContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(toggleRow.rowName)
      onClicked: toggleRow.toggled()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      ColumnLayout {
        id: toggleContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: toggleRow.label
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: toggleRow.caption
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      ToggleSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: toggleRow.checked
        busy: pods.busy
        hasCursor: toggleRow.hasCursor
        foreground: root.foreground
        onToggled: toggleRow.toggled()
      }
    }
  }

  component ValueRow: CursorSurface {
    id: valueRow
    property string rowName: ""
    property string label: ""
    property string value: ""

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: valueLabel.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(valueRow.rowName)
      onClicked: pods.cycleEarDetection()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        id: valueLabel
        Layout.fillWidth: true
        text: valueRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        text: valueRow.value
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }

  component SliderRow: Item {
    id: sliderRow
    implicitHeight: sliderColumn.implicitHeight

    Column {
      id: sliderColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(4)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Adaptive noise"
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Item {
          width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
          height: 1
        }

        Text {
          text: pods.adaptiveNoiseLevel + "%"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      PanelSlider {
        width: parent.width
        bar: root.bar
        minimum: 0
        maximum: 100
        step: root.adaptiveStepPercent
        integer: true
        tickCount: 5
        value: pods.adaptiveNoiseLevel
        onReleased: function (v) { pods.setAdaptiveNoiseLevel(v) }
      }
    }
  }
}
