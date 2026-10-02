import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Volume OSD. Replaces swayosd. The right pill — where the volume already
// lives — stretches into this for a moment whenever the volume changes, from
// the media keys or anywhere else. See ShellState.osd.
Item {
    id: root

    property bool shown: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property int pct: Math.round((audio?.volume ?? 0) * 100)

    // At least as wide as the pill, same as ControlCenter.
    property real minWidth: 0

    implicitWidth: Math.max(300, Math.round(minWidth))
    implicitHeight: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        Reveal {
            shown: root.shown
            order: 0
            implicitWidth: 20
            implicitHeight: 20
            Txt {
                width: 20
                height: 20
                text: root.audio?.muted ? "󰖁" : root.pct < 34 ? "󰕿" : root.pct < 67 ? "󰖀" : "󰕾"
                color: root.audio?.muted ? Theme.urgent : Theme.fg
                font.pixelSize: 16
            }
        }
        Reveal {
            shown: root.shown
            order: 1
            Layout.fillWidth: true
            implicitHeight: 22
            GlassSlider {
                width: parent.width
                value: root.audio?.volume ?? 0
                muted: root.audio?.muted ?? false
                onMoved: v => { if (root.audio) root.audio.volume = v; }
            }
        }
        Reveal {
            shown: root.shown
            order: 2
            implicitWidth: 38
            implicitHeight: 20
            Txt {
                width: 38
                height: 20
                horizontalAlignment: Text.AlignRight
                text: root.audio?.muted ? "mudo" : `${root.pct}%`
                color: Theme.dim
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
