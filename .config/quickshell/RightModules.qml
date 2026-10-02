import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// Right pill, closed state: now playing, weather, volume, tray, power button.
// The whole pill is what grows into the control center — see Bar.qml.
RowLayout {
    id: root

    required property var window
    signal powerClicked
    signal weatherClicked
    readonly property string forecast: weather.text

    spacing: 0

    component Module: Txt {
        Layout.fillHeight: true
        leftPadding: Theme.padX
        rightPadding: Theme.padX
        color: hovered ? Theme.fg : Theme.dim
        Behavior on color { ColorAnimation { duration: 150 } }

        readonly property alias hovered: area.containsMouse
        signal clicked(var mouse)
        signal wheeled(var wheel)

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => parent.clicked(mouse)
            onWheel: wheel => parent.wheeled(wheel)
        }
    }

    // ── Now playing ─────────────────────────────────────────────────────────
    // Only while something is actually playing. Browsers keep a paused MPRIS
    // entry alive long after the video ended, and a stale title parked in the
    // bar is clutter. Hidden means the pill closes up around it.
    readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying) ?? null

    Module {
        visible: root.player !== null
        Layout.maximumWidth: 360
        elide: Text.ElideRight
        text: {
            const p = root.player;
            if (!p)
                return "";
            const t = (p.trackTitle ?? "").trim();
            const a = (p.trackArtist ?? "").trim();
            return t && a ? `${t} — ${a}` : t + a;
        }
        onClicked: root.player?.togglePlaying()
        onWheeled: wheel => wheel.angleDelta.y > 0 ? root.player?.next() : root.player?.previous()
    }

    // ── Weather ─────────────────────────────────────────────────────────────
    // wttr.in one-liner; the script also refreshes the satellite image in the
    // background, and a click stretches the pill into it (Satellite.qml).
    Module {
        id: weather
        visible: text !== ""
        onClicked: root.weatherClicked()

        Process {
            id: weatherProc
            command: [`${Quickshell.shellDir}/scripts/weather_satellite.sh`, "check"]
            stdout: StdioCollector {
                // wttr pads between the icon and the temperature; collapse it.
                // An error page is not a forecast, so anything long is dropped.
                onStreamFinished: {
                    const t = text.trim().replace(/\s+/g, " ");
                    weather.text = t.length < 24 ? t : "";
                }
            }
        }
        Timer {
            interval: 3600 * 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: weatherProc.running = true
        }
    }

    // ── Notifications ───────────────────────────────────────────────────────
    // How many are waiting in the control center. Swells when a toast lands in
    // it, so the eye connects the toast that just left with where it went.
    Module {
        id: bell
        visible: Notifs.list.length > 0 || Notifs.dnd
        text: Notifs.dnd ? "󰂛" : `󰂚 ${Notifs.list.length}`
        onClicked: ShellState.toggle("center")

        transformOrigin: Item.Center
        scale: 1
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.22; epsilon: 0.005 } }
        Connections {
            target: Notifs
            function onAbsorbed() {
                bell.scale = 1.35;
                bellSettle.restart();
            }
        }
        Timer {
            id: bellSettle
            interval: 90
            onTriggered: bell.scale = 1
        }
    }

    // ── Volume ──────────────────────────────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    // Pipewire only fills in a node's audio properties while it is tracked.
    PwObjectTracker { objects: [root.sink] }

    Module {
        readonly property var audio: root.sink?.audio ?? null
        readonly property int pct: Math.round((audio?.volume ?? 0) * 100)
        visible: audio !== null
        text: audio?.muted ? "󰖁 mudo" : `${pct < 34 ? "󰕿" : pct < 67 ? "󰖀" : "󰕾"} ${pct}%`
        color: audio?.muted ? Theme.urgent : hovered ? Theme.fg : Theme.dim

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                audio.muted = !audio.muted;
            else
                Quickshell.execDetached(["pavucontrol"]);
        }
        onWheeled: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            audio.volume = Math.max(0, Math.min(1, audio.volume + step));
        }
    }

    // ── Tray ────────────────────────────────────────────────────────────────
    Row {
        Layout.fillHeight: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        spacing: 8
        visible: SystemTray.items.values.length > 0

        Repeater {
            model: SystemTray.items

            IconImage {
                id: icon
                required property SystemTrayItem modelData
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 14
                source: modelData.icon

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        const item = icon.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const p = icon.mapToItem(null, 0, icon.height + 6);
                                item.display(root.window, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                }
            }
        }
    }

    // ── Power ───────────────────────────────────────────────────────────────
    Module {
        text: "⏻"
        font.pixelSize: 15
        rightPadding: 12
        color: hovered ? Theme.urgent : Theme.dim
        onClicked: root.powerClicked()
    }
}
