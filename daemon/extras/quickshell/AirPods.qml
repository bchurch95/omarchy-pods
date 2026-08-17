// AirPods.qml — Quickshell consumer of OpenPods status IPC.
// Drops into ~/.config/quickshell/<your-shell>/ and exposes an
// `AirPods` singleton with the parsed status from /tmp/app_server.
// Polls every 5s while idle, 1s when the popover is shown (rebind
// `pollInterval` from the consumer if you need different cadence).
// Sample usage in CommandCenter.qml:
//   import "."  // pull in AirPods singleton from this folder
//   Rectangle {
//       visible: AirPods.connected
//       Text { text: AirPods.leftLevel + "% / " + AirPods.rightLevel + "%" }
//   }
// Schema source of truth: OpenPods linux/main.cpp `status` command
// path (currently checked out at ~/Projects/librepods until the
// filesystem-rename tick lands). schema_version field gates
// incompatible bumps.

import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    // Public read-only API. Defaults reflect "no AirPods, nothing known".
    readonly property bool connected: _connected
    readonly property string deviceName: _deviceName
    readonly property int noiseMode: _noiseMode // 0=Off 1=ANC 2=Trans 3=Adaptive
    readonly property int leftLevel: _leftLevel // -1 = unavailable
    readonly property int rightLevel: _rightLevel
    readonly property int caseLevel: _caseLevel
    readonly property bool leftCharging: _leftCharging
    readonly property bool rightCharging: _rightCharging
    readonly property bool caseCharging: _caseCharging
    readonly property bool leftInEar: _leftInEar
    readonly property bool rightInEar: _rightInEar
    readonly property int schemaVersion: _schemaVersion
    // 0 = PauseWhenOneRemoved (Apple default), 1 = PauseWhenBothRemoved,
    // 2 = Disabled (auto-pause/resume off). Mirrors
    // MediaController::EarDetectionBehavior in linux/media/mediacontroller.h.
    readonly property int earDetectionBehavior: _earDetectionBehavior
    // Conversation Awareness toggle (Pro2). Mirrors the AAP packet
    // state + daemon's QSettings persistence.
    readonly property bool conversationalAwareness: _conversationalAwareness
    // User-facing model string from enums.h:modelDisplayName, e.g.
    // "AirPods Pro 2 (USB-C)". Empty string when the daemon hasn't
    // identified the model yet (initial connect window or Unknown).
    readonly property string modelName: _modelName
    // Raw Apple model code (e.g. "A3334"). Useful for debugging the
    // parseModelNumber map when modelName comes back empty for a new
    // device — surface this alongside in the UI or have the user
    // report it via `librepods-ctl status | jq .model_number`.
    readonly property string modelNumber: _modelNumber
    // Adaptive Noise level (0-100). Only meaningful when noiseMode==3
    // (Adaptive); daemon refuses to push the AAP packet otherwise.
    readonly property int adaptiveNoiseLevel: _adaptiveNoiseLevel
    // One-Bud ANC mode (Pro2/Pro3). When true, ANC stays engaged
    // even with only one pod in ear (default behavior switches to
    // Transparency on solo-pod use). Mirrors AAP state + QSettings.
    readonly property bool oneBudANC: _oneBudANC
    // True when the daemon-identified model is one of the Pro
    // generations (Pro, Pro2 Lightning, Pro2 USB-C, Pro3). PodsMenu
    // uses this to gate Pro-only feature rows (Conversation
    // Awareness, One-Bud ANC, Adaptive Noise level slider). Empty-
    // string modelName means the device hasn't been identified yet
    // — UI should treat that as "still loading" and not hide
    // prematurely (a brief flash of all-rows-then-hidden looks
    // worse than waiting).
    readonly property bool isProSeries: _isProSeries
    // Configurable poll cadence. Bind faster while a tile is open.
    property int pollInterval: 5000
    // ---- internals ----
    property bool _connected: false
    property string _deviceName: ""
    property int _noiseMode: -1
    property int _leftLevel: -1
    property int _rightLevel: -1
    property int _caseLevel: -1
    property bool _leftCharging: false
    property bool _rightCharging: false
    property bool _caseCharging: false
    property bool _leftInEar: false
    property bool _rightInEar: false
    property int _schemaVersion: 0
    property int _earDetectionBehavior: 0
    property bool _conversationalAwareness: false
    property string _modelName: ""
    property string _modelNumber: ""
    property int _adaptiveNoiseLevel: 50
    property bool _oneBudANC: false
    property bool _isProSeries: false

    // Watchdog: timestamp (ms since epoch) of the last successful
    // _digest call. The "daemon down" detection uses this instead of
    // Socket onError, because Quickshell.Io.Socket fires onError on
    // every graceful peer-close — the daemon writes one JSON line then
    // disconnects, so onError-driven resets would race with parser
    // onRead and flip _connected = false right after we set it true.
    property double _lastDigestMs: 0

    // Public-facing refresh. Force an immediate status poll instead
    // of waiting for the next Timer tick.
    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    function _digest(line) {
        if (!line)
            return ;

        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            return ;
        }
        if (d.schema_version === undefined)
            return ;

        if (d.schema_version > 1) {
            // Forward-compat: OpenPods bumped the contract. Surface raw
            // version so the bar can warn the user instead of silently
            // showing stale data.
            root._schemaVersion = d.schema_version;
            return ;
        }
        root._schemaVersion = d.schema_version;
        root._connected = !!d.connected;
        root._deviceName = d.device_name || "";
        root._noiseMode = (typeof d.noise_mode === "number") ? d.noise_mode : -1;
        root._leftLevel = d.left && d.left.available ? d.left.level : -1;
        root._rightLevel = d.right && d.right.available ? d.right.level : -1;
        root._caseLevel = d.case && d.case.available ? d.case.level : -1;
        root._leftCharging = !!(d.left && d.left.charging);
        root._rightCharging = !!(d.right && d.right.charging);
        root._caseCharging = !!(d.case && d.case.charging);
        root._leftInEar = !!(d.left && d.left.in_ear);
        root._rightInEar = !!(d.right && d.right.in_ear);
        if (typeof d.ear_detection_behavior === "number")
            root._earDetectionBehavior = d.ear_detection_behavior;

        if (typeof d.conversational_awareness === "boolean")
            root._conversationalAwareness = d.conversational_awareness;
        if (typeof d.model_name === "string")
            root._modelName = d.model_name;
        if (typeof d.model_number === "string")
            root._modelNumber = d.model_number;
        if (typeof d.adaptive_noise_level === "number")
            root._adaptiveNoiseLevel = d.adaptive_noise_level;
        if (typeof d.one_bud_anc_mode === "boolean")
            root._oneBudANC = d.one_bud_anc_mode;
        if (typeof d.is_pro_series === "boolean")
            root._isProSeries = d.is_pro_series;

        root._lastDigestMs = Date.now();
    }

    // Public: write a command. Spawns a one-shot librepods-ctl
    // invocation per call; daemon receives via QLocalServer, ctl
    // exits. Returns immediately; status refresh on next Timer
    // tick propagates new state.
    function sendCommand(cmd) {
        cmdProc.command = ["/home/gm/Projects/librepods/linux/build/librepods-ctl", cmd];
        cmdProc.running = false;
        cmdProc.running = true;
    }

    function setNoiseMode(mode) {
        const names = ["noise:off", "noise:anc", "noise:transparency", "noise:adaptive"];
        if (mode >= 0 && mode < names.length) {
            sendCommand(names[mode]);
            // Optimistic local update; status poll confirms.
            root._noiseMode = mode;
        }
    }

    // Auto Ear Detection toggle. Maps the same 0/1/2 enum used by the
    // daemon: 0=PauseWhenOneRemoved (Apple default), 1=PauseWhenBothRemoved,
    // 2=Disabled. PodsMenu surfaces only on/off (default vs disabled);
    // the both-removed mode is reachable via openpods-ctl ear:both for
    // power users.
    function setEarDetectionBehavior(mode) {
        const names = ["ear:one", "ear:both", "ear:off"];
        if (mode >= 0 && mode < names.length) {
            sendCommand(names[mode]);
            root._earDetectionBehavior = mode;
        }
    }

    // Apple "Forget This Device" parity. Walks `bluetoothctl remove`
    // on the daemon side. Caller is responsible for confirming intent
    // — the IPC verb dispatches the bluetoothctl call directly.
    function forgetDevice() {
        sendCommand("forget");
    }

    // Pop-out: ask the daemon to surface its full Qt window (Main.qml).
    // The `reopen` verb is the same one the single-instance check uses
    // when a second launch attempt detects a running daemon, so it
    // reliably brings the window to the front + creates it if no
    // window is currently open.
    function reopenWindow() {
        sendCommand("reopen");
    }

    // BlueZ-level disconnect / reconnect for the paired AirPods. Both
    // shell out to bluetoothctl on the daemon side. Disconnect is
    // non-destructive (pairing keys persist; case lid opens or BlueZ
    // auto-reconnect bring them back). Connect requests an active
    // pair-up so the user can resume listening from another device
    // without unpairing.
    function disconnectAirPods() {
        sendCommand("disconnect");
    }
    function connectAirPods() {
        sendCommand("connect");
    }

    // Adaptive Noise level 0-100. Daemon ignores the verb when
    // noise_mode != Adaptive (3), so the caller can fire it blindly
    // from a slider without pre-checking — the optimistic local
    // update still reflects intent.
    function setAdaptiveNoiseLevel(level) {
        const n = Math.max(0, Math.min(100, Math.round(level)));
        sendCommand("adaptive:" + n);
        root._adaptiveNoiseLevel = n;
    }

    // Conversation Awareness (Pro2/Pro3). Daemon writes the AAP packet
    // + persists QSettings. Optimistic update so the toggle snaps in
    // the UI without waiting for the next status poll.
    function setConversationalAwareness(enabled) {
        sendCommand(enabled ? "ca:on" : "ca:off");
        root._conversationalAwareness = enabled;
    }

    // One-Bud ANC (Pro2/Pro3). When true, ANC stays engaged with one
    // pod in ear instead of cycling to Transparency.
    function setOneBudANC(enabled) {
        sendCommand(enabled ? "onebud:on" : "onebud:off");
        root._oneBudANC = enabled;
    }

    // Status poll via Process exec of librepods-ctl. Switched from
    // Quickshell.Io.Socket (iter-prev) because Socket latches into
    // a hard-fail state on daemon respawn that even path/connected
    // toggling can't recover — symptom: PodsMenu stays empty for
    // the rest of the session. Process exec is ~10ms per poll;
    // cheap relative to the 5s/1s cadence + bulletproof: the
    // librepods-ctl binary itself owns the socket-reconnect logic,
    // so daemon restarts don't strand the QML side.
    Process {
        id: statusProc
        command: ["/home/gm/Projects/librepods/linux/build/librepods-ctl", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._digest(data)
        }
    }

    // Write-only fire-and-forget command channel. Each verb is its
    // own one-shot Process invocation; librepods-ctl exits after
    // sending. No socket reuse, no latched-state issues.
    Process {
        id: cmdProc
        property string pending: ""
        command: ["/home/gm/Projects/librepods/linux/build/librepods-ctl", "status"]
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Re-run librepods-ctl each tick. Setting running=false
            // first guarantees a fresh process even if the previous
            // run is still alive (rare; usually finishes in <10ms).
            statusProc.running = false;
            statusProc.running = true;

            // Watchdog: if we haven't seen a successful digest in
            // 2.5 * pollInterval, mark disconnected. Same logic as
            // the old Socket path.
            const now = Date.now();
            if (root._lastDigestMs > 0 && now - root._lastDigestMs > root.pollInterval * 2.5) {
                root._connected = false;
            }
        }
    }

}
