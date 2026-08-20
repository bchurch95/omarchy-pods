import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool daemonReachable: false
  property bool connected: false
  property string deviceName: ""
  property string modelName: ""
  property bool isProSeries: false
  property bool isHeadset: false
  property bool supportsNoiseOff: true
  property int noiseMode: Model.NOISE_UNKNOWN
  property int adaptiveNoiseLevel: 0
  property bool oneBudANC: false
  property bool conversationalAwareness: false
  property int earDetectionBehavior: Model.EAR_PAUSE_ONE_OUT
  property int lidState: Model.LID_UNKNOWN
  property bool schemaUnsupported: false
  property var leftPod: Model.defaultPod()
  property var rightPod: Model.defaultPod()
  property var caseBattery: ({ level: Model.LEVEL_UNKNOWN, charging: false })
  property var headsetBattery: ({ level: Model.LEVEL_UNKNOWN, charging: false, inEar: false })
  // Primitive copies of the levels. QML does not reliably re-evaluate
  // bindings that reach into a `property var` object, so hasBattery must
  // not depend on headsetBattery.level or the Max row stays hidden.
  property int leftLevel: Model.LEVEL_UNKNOWN
  property int rightLevel: Model.LEVEL_UNKNOWN
  property int caseLevel: Model.LEVEL_UNKNOWN
  property int headsetLevel: Model.LEVEL_UNKNOWN
  property bool headsetCharging: false
  property string lastError: ""
  property string actionStatus: ""

  readonly property string ctlPath: String(setting("ctlPath", "") || "librepods-ctl")
  readonly property bool busy: commandProcess.running
  // The daemon publishes here on change, so there is nothing to poll.
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/librepods/status.json"
  readonly property bool hasAirPods: daemonReachable && connected
  // Battery keeps arriving over BLE while the audio link is down, so it is not gated on connected.
  readonly property bool hasBattery: daemonReachable
    && (isHeadset
      ? headsetLevel !== Model.LEVEL_UNKNOWN
      : (leftLevel !== Model.LEVEL_UNKNOWN
        || rightLevel !== Model.LEVEL_UNKNOWN
        || caseLevel !== Model.LEVEL_UNKNOWN))

  // How long an optimistic value is held before the daemon's own state wins.
  readonly property int settleHoldMs: 4000
  readonly property int actionStatusMs: 2200

  // Held over incoming reads until the daemon agrees, so a write already in flight
  // when the click landed cannot snap the control back.
  property string _pendingField: ""
  property var _pendingValue: null

  // Single slot: a verb sent while another is in flight replaces the queued one
  // rather than being dropped, which is what arrow-key repeat produces.
  property var _queued: null

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function refresh() {
    stateFile.reload()
  }

  function applyLine(raw) {
    var status = Model.parseStatus(raw)
    if (!status.ok) {
      // A line we cannot read still proves the daemon is running and writing.
      daemonReachable = true
      connected = false
      schemaUnsupported = status.schemaTooNew
      lastError = status.lastError
      return
    }
    daemonReachable = true
    schemaUnsupported = false
    lastError = ""
    applyStatus(status)
  }

  // The daemon removes the file when it stops, so an absent file is a stopped daemon.
  function stateGone() {
    daemonReachable = false
    connected = false
    schemaUnsupported = false
    lastError = ""
  }

  function applyStatus(status) {
    connected = status.connected
    deviceName = status.deviceName
    modelName = status.modelName
    isProSeries = status.isProSeries
    supportsNoiseOff = status.supportsNoiseOff
    leftPod = status.left
    rightPod = status.right
    caseBattery = status.caseBattery
    leftLevel = status.left.level
    rightLevel = status.right.level
    caseLevel = status.caseBattery.level
    headsetLevel = status.headset.level
    headsetCharging = status.headset.charging === true
    headsetBattery = {
      level: status.headset.level,
      charging: status.headset.charging === true,
      inEar: false
    }
    // Flip the layout after the levels land, so hasBattery never observes
    // isHeadset=true against a still-unknown headsetLevel.
    isHeadset = status.isHeadset
    lidState = status.lidState

    noiseMode = _settle("noiseMode", status.noiseMode)
    adaptiveNoiseLevel = _settle("adaptiveNoiseLevel", status.adaptiveNoiseLevel)
    oneBudANC = _settle("oneBudANC", status.oneBudANC)
    conversationalAwareness = _settle("conversationalAwareness", status.conversationalAwareness)
    earDetectionBehavior = _settle("earDetectionBehavior", status.earDetectionBehavior)
  }

  function _settle(field, reported) {
    if (_pendingField !== field) return reported
    if (reported === _pendingValue) {
      _clearPending()
      return reported
    }
    return _pendingValue
  }

  function _clearPending() {
    _pendingField = ""
    _pendingValue = null
    settleTimer.stop()
  }

  function _send(verb, field, optimistic) {
    if (verb === "") return
    if (commandProcess.running) {
      _queued = { verb: verb, field: field, optimistic: optimistic }
      _pendingField = field
      _pendingValue = optimistic
      root[field] = optimistic
      settleTimer.restart()
      return
    }
    _pendingField = field
    _pendingValue = optimistic
    root[field] = optimistic
    settleTimer.restart()
    commandProcess.command = [ctlPath, verb]
    commandProcess.running = true
  }

  function setNoiseMode(mode) {
    _send(Model.noiseModeVerb(mode), "noiseMode", mode)
  }

  // The one list both the cycle and the panel rows are built from.
  function availableModes() {
    var modes = []
    if (supportsNoiseOff) modes.push(Model.NOISE_OFF)
    modes.push(Model.NOISE_TRANSPARENCY)
    if (isProSeries) modes.push(Model.NOISE_ADAPTIVE)
    modes.push(Model.NOISE_ANC)
    return modes
  }

  function cycleNoiseMode() {
    if (!hasAirPods) return
    var modes = availableModes()
    var at = modes.indexOf(noiseMode)
    // An unknown current mode has no next one, so start at the head instead of past it.
    setNoiseMode(at < 0 ? modes[0] : modes[(at + 1) % modes.length])
  }

  function setAdaptiveNoiseLevel(level) {
    var clamped = Math.max(0, Math.min(100, Math.round(level)))
    _send("adaptive:" + clamped, "adaptiveNoiseLevel", clamped)
  }

  function setConversationalAwareness(enabled) {
    _send(enabled ? "ca:on" : "ca:off", "conversationalAwareness", enabled)
  }

  function setOneBudANC(enabled) {
    _send(enabled ? "onebud:on" : "onebud:off", "oneBudANC", enabled)
  }

  function setEarDetectionBehavior(behavior) {
    _send(Model.earDetectionVerb(behavior), "earDetectionBehavior", behavior)
  }

  function cycleEarDetection() {
    setEarDetectionBehavior((earDetectionBehavior + 1) % Model.EAR_BEHAVIOR_COUNT)
  }

  Timer {
    // Bounds the optimistic hold, and re-reads because a verb that changed nothing
    // leaves the daemon's file untouched, so no watch fires to correct the display.
    id: settleTimer
    interval: root.settleHoldMs
    repeat: false
    onTriggered: { root._clearPending(); root.refresh() }
  }

  Timer {
    id: actionStatusTimer
    interval: root.actionStatusMs
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    // text() is stale inside the change signal, so both paths go through reload.
    onFileChanged: reload()
    onLoaded: root.applyLine(text())
    onLoadFailed: root.stateGone()
  }

  Process {
    id: commandProcess
    running: false
    command: []
    stderr: StdioCollector { id: commandErr; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode !== 0) {
        // Clearing the hold also stops the timer that would have re-read, so do it here.
        root._clearPending()
        root.refresh()
        root._queued = null
        // Its own field with its own timer, or the next status read wipes it unread.
        root.actionStatus = Model.elideError(commandErr.text || "librepods-ctl rejected the command")
        actionStatusTimer.restart()
      }
      if (root._queued) {
        var next = root._queued
        root._queued = null
        root._send(next.verb, next.field, next.optimistic)
      }
    }
  }
}
