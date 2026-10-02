import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// What the clock pill opens into, floating below the bar. Replaces wofi/scripts/powermenu.sh.
//
// Four fixed glyph buttons in a row, same order as the wofi version so muscle
// memory carries over. ←/→ (or h/l) move, Enter fires, Esc closes (handled by
// Bar.qml's key scope).
FocusScope {
    id: root

    property bool shown: false
    signal done

    readonly property int pad: 14
    readonly property int size: 96
    readonly property int tall: 84
    readonly property int gap: 8

    readonly property var actions: [
        { glyph: "󰐥", label: "Desligar",  cmd: ["systemctl", "poweroff"], danger: true },
        { glyph: "󰜉", label: "Reiniciar", cmd: ["systemctl", "reboot"],   danger: true },
        { glyph: "󰤄", label: "Suspender", cmd: ["systemctl", "suspend"],  danger: false },
        // hyprctl dispatch takes Lua under the Lua config, a bare name under
        // the legacy one.
        { glyph: "󰈆", label: "Sair",      cmd: ["hyprctl", "dispatch", Hyprland.usingLua ? "hl.dsp.exit()" : "exit"], danger: false }
    ]

    // Opens on Desligar, so Ctrl+Alt+Del → Enter shuts down.
    property int current: 0

    function fire(i) {
        const a = actions[i];
        if (!a)
            return;
        done();
        Quickshell.execDetached(a.cmd);
    }

    onShownChanged: if (shown) current = 0

    implicitWidth: row.implicitWidth + pad * 2
    implicitHeight: row.implicitHeight + pad * 2

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            current = current <= 0 ? actions.length - 1 : current - 1;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            current = (current + 1) % actions.length;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            fire(current);
        } else {
            return;
        }
        event.accepted = true;
    }

    RowLayout {
        id: row
        x: root.pad
        y: root.pad
        spacing: root.gap

        Repeater {
            model: root.actions

            Reveal {
                id: cell
                required property var modelData
                required property int index

                shown: root.shown
                order: index
                rise: 10
                implicitWidth: root.size
                implicitHeight: root.tall

                readonly property bool lit: root.current === index

                Rectangle {
                    width: root.size
                    height: root.tall
                    radius: 16
                    color: cell.lit ? Theme.hover : "transparent"
                    border.width: 1
                    border.color: cell.lit ? Theme.border : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    // Hovered button swells a touch — small, springy, and it
                    // lets go the moment the pointer leaves.
                    scale: area.pressed ? 0.94 : cell.lit ? 1.04 : 1
                    Behavior on scale {
                        SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.002 }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.glyph
                            font.pixelSize: 30
                            color: cell.lit && cell.modelData.danger ? Theme.urgent
                                 : cell.lit ? Theme.fg : Theme.dim
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.label
                            font.pixelSize: Theme.fontSize - 2
                            color: cell.lit ? Theme.fg : Theme.faint
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = cell.index
                        onClicked: root.fire(cell.index)
                    }
                }
            }
        }
    }
}
