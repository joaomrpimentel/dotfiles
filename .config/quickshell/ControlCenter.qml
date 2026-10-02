import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// What the right pill opens into on SUPER+N. Replaces the swaync control center
// with the same pieces: quick toggles, volume, now playing, notifications.
FocusScope {
    id: root

    property bool shown: false
    signal done
    signal wantPower

    readonly property int pad: 16
    // At least as wide as the pill it opens from: a long track title in the
    // bar can make the pill wider than the panel, which left a gap on the left.
    property real minWidth: 0
    readonly property int innerWidth: Math.max(368, Math.round(minWidth) - pad * 2)

    implicitWidth: innerWidth + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    // wlsunset has no status query, so the toggle reflects whether it runs.
    property bool nightLight: false
    Process {
        id: nightProbe
        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.nightLight = code === 0
    }
    onShownChanged: if (shown) nightProbe.running = true

    function run(cmd) {
        done();
        // Give the panel a beat to leave, or the screenshot/picker catch it.
        delay.cmd = cmd;
        delay.start();
    }
    Timer {
        id: delay
        property var cmd: []
        interval: 220
        onTriggered: Quickshell.execDetached(cmd)
    }

    ColumnLayout {
        id: column
        x: root.pad
        y: root.pad
        width: root.innerWidth
        spacing: 14

        // ── Quick toggles ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            component Toggle: Reveal {
                id: t
                property string glyph
                property string label
                property bool on: false
                signal clicked
                shown: root.shown
                Layout.fillWidth: true
                implicitHeight: 64

                Rectangle {
                    width: t.width
                    height: 64
                    radius: 18
                    color: t.on ? Theme.fg : area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Theme.hover
                    border.width: 1
                    border.color: t.on ? "transparent" : Theme.border
                    Behavior on color { ColorAnimation { duration: 160 } }
                    scale: area.pressed ? 0.93 : 1
                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.002 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: t.glyph
                            font.pixelSize: 18
                            color: t.on ? "#121214" : Theme.fg
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: t.label
                            font.pixelSize: Theme.fontSize - 3
                            color: t.on ? "#121214" : Theme.faint
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: t.clicked()
                    }
                }
            }

            Toggle {
                order: 0
                glyph: Notifs.dnd ? "󰂛" : "󰂚"
                label: "Silêncio"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Toggle {
                order: 1
                glyph: "󰖔"
                label: "Noturno"
                on: root.nightLight
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", root.nightLight ? "pkill -x wlsunset" : "wlsunset -t 4000 -T 6500"]);
                    root.nightLight = !root.nightLight;
                }
            }
            Toggle {
                order: 2
                glyph: "󰄀"
                label: "Captura"
                onClicked: root.run([`${Quickshell.env("HOME")}/.config/hypr/scripts/screenshot.sh`])
            }
            Toggle {
                order: 3
                glyph: "󰈊"
                label: "Cor"
                onClicked: root.run(["hyprpicker", "-a"])
            }
            Toggle {
                order: 4
                glyph: "⏻"
                label: "Energia"
                onClicked: root.wantPower()
            }
        }

        // ── Volume ──────────────────────────────────────────────────────────
        Reveal {
            id: volBox
            shown: root.shown
            order: 5
            Layout.fillWidth: true
            implicitHeight: 24

            readonly property PwNode sink: Pipewire.defaultAudioSink
            readonly property var audio: sink?.audio ?? null
            PwObjectTracker { objects: [volBox.sink] }

            RowLayout {
                width: root.innerWidth
                height: 24
                spacing: 12

                Txt {
                    text: volBox.audio?.muted ? "󰖁" : "󰕾"
                    color: volBox.audio?.muted ? Theme.urgent : Theme.fg
                    font.pixelSize: 16
                    Layout.preferredWidth: 20
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (volBox.audio) volBox.audio.muted = !volBox.audio.muted
                    }
                }
                GlassSlider {
                    id: vol
                    Layout.fillWidth: true
                    value: volBox.audio?.volume ?? 0
                    muted: volBox.audio?.muted ?? false
                    onMoved: v => { if (volBox.audio) volBox.audio.volume = v; }
                }
                Txt {
                    text: `${Math.round(vol.value * 100)}%`
                    color: Theme.faint
                    font.pixelSize: Theme.fontSize - 1
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // ── Now playing ─────────────────────────────────────────────────────
        // Playing player first; otherwise the most recent one, paused. Hidden
        // when there is none, like swaync's autohide.
        Reveal {
            id: mediaBox
            readonly property MprisPlayer player: {
                const ps = Mpris.players.values.filter(p => p.identity !== "playerctld");
                return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
            }
            visible: player !== null
            shown: root.shown
            order: 6
            Layout.fillWidth: true
            implicitHeight: 84

            Rectangle {
                width: root.innerWidth
                height: 84
                radius: 18
                color: Theme.hover
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    ClippingRectangle {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Image {
                            anchors.fill: parent
                            source: mediaBox.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(120, 120)
                            asynchronous: true
                        }
                        Txt {
                            anchors.centerIn: parent
                            visible: !(mediaBox.player?.trackArtUrl)
                            text: "󰎈"
                            font.pixelSize: 22
                            color: Theme.faint
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Txt {
                            Layout.fillWidth: true
                            text: mediaBox.player?.trackTitle || mediaBox.player?.identity || ""
                            color: Theme.fg
                            elide: Text.ElideRight
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: mediaBox.player?.trackArtist ?? ""
                            color: Theme.faint
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            spacing: 18
                            Layout.topMargin: 4
                            component Ctl: Txt {
                                signal clicked
                                font.pixelSize: 16
                                color: ctlArea.containsMouse ? Theme.fg : Theme.dim
                                MouseArea {
                                    id: ctlArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    onClicked: parent.clicked()
                                }
                            }
                            Ctl { text: "󰒮"; onClicked: mediaBox.player?.previous() }
                            Ctl { text: mediaBox.player?.isPlaying ? "󰏤" : "󰐊"; onClicked: mediaBox.player?.togglePlaying() }
                            Ctl { text: "󰒭"; onClicked: mediaBox.player?.next() }
                        }
                    }
                }
            }
        }

        // ── Notifications ───────────────────────────────────────────────────
        Reveal {
            shown: root.shown
            order: 7
            Layout.fillWidth: true
            implicitHeight: 22

            RowLayout {
                width: root.innerWidth
                height: 22
                Txt {
                    Layout.fillWidth: true
                    text: Notifs.list.length ? `Notificações · ${Notifs.list.length}` : "Notificações"
                    color: Theme.fg
                }
                Txt {
                    visible: Notifs.list.length > 0
                    text: "Limpar"
                    color: clearArea.containsMouse ? Theme.fg : Theme.faint
                    font.pixelSize: Theme.fontSize - 1
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: Notifs.clearAll()
                    }
                }
            }
        }

        Reveal {
            shown: root.shown
            order: 8
            Layout.fillWidth: true
            implicitHeight: Notifs.list.length ? Math.min(list.contentHeight, 340) : 60

            Txt {
                visible: Notifs.list.length === 0
                width: root.innerWidth
                height: 60
                horizontalAlignment: Text.AlignHCenter
                text: "Nada por aqui"
                color: Theme.faint
            }

            ListView {
                id: list
                width: root.innerWidth
                height: Math.min(contentHeight, 340)
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: [...Notifs.list].reverse() }

                // Off during clear-all: the rows sweep out together instead.
                displaced: Transition {
                    enabled: !Notifs.clearing
                    NumberAnimation { property: "y"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
                remove: Transition {
                    enabled: !Notifs.clearing
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 160 }
                        NumberAnimation { property: "x"; to: 50; duration: 200; easing.type: Easing.InCubic }
                    }
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width

                    // Clear-all sweep, top row first.
                    readonly property int sweepDelay: Math.max(0, Math.min(index, 8)) * 35
                    opacity: Notifs.clearing ? 0 : 1
                    transform: Translate {
                        x: Notifs.clearing ? 70 : 0
                        Behavior on x {
                            SequentialAnimation {
                                PauseAnimation { duration: row.sweepDelay }
                                NumberAnimation { duration: 240; easing.type: Easing.InBack; easing.overshoot: 1.2 }
                            }
                        }
                    }
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: row.sweepDelay + 60 }
                            NumberAnimation { duration: 180 }
                        }
                    }
                    height: card.implicitHeight
                    radius: 16
                    color: Theme.hover
                    border.width: 1
                    border.color: Theme.border

                    NotificationCard {
                        id: card
                        width: parent.width
                        notif: modelData
                        onCloseClicked: modelData.dismiss()
                        onBodyClicked: Notifs.activate(modelData)
                    }
                }
            }
        }
    }
}
