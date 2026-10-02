import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Ephemeral workspace indicator. Replaces hypr/scripts/workspace_dots.py.
//
// A strip of dots at the bottom edge that rises for a moment whenever the
// focused workspace changes, then sinks back out of sight.
//
//     bright capsule  you are here
//     medium dot      has windows
//     faint dot       empty, but sits between two used workspaces
//
// The strip ends at the highest workspace that is occupied or focused, so an
// empty workspace only earns a dot when something is using one past it — that
// is what makes a gap readable.
//
// Where the Python version redrew the row, here the capsule travels: it slides
// and stretches from the old dot to the new one on a spring, so the eye tracks
// where you went instead of re-reading the row.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property int visibleMs: 1200
    readonly property int dotGap: 18
    readonly property int dotSize: 6
    readonly property int capsule: 18

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 1
    readonly property var occupied: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.toplevels.values.length > 0)
        .map(w => w.id)
    readonly property int count: Math.max(1, active, ...occupied)

    property bool shown: false

    anchors.bottom: true
    margins.bottom: 8
    implicitWidth: 520
    implicitHeight: 40
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.namespace: "quickshell-dots"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Purely informational: never eats a click.
    mask: Region {}

    // Only focus changes pop the strip; a window opening elsewhere must not.
    onActiveChanged: pop()
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { root.pop(); }
    }

    function pop() {
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: root.visibleMs
        onTriggered: root.shown = false
    }

    Glass {
        id: pill

        readonly property int innerWidth: (root.count - 1) * root.dotGap + root.capsule
        width: innerWidth + 22
        height: 22
        radius: 11
        anchors.horizontalCenter: parent.horizontalCenter

        // Rises out of the bottom edge on a loose spring, sinks on a stiff one.
        y: root.shown ? root.height - height - 4 : root.height + 12
        opacity: root.shown ? 1 : 0

        Behavior on y {
            SpringAnimation {
                spring: root.shown ? Theme.springOpen : Theme.springClose
                damping: root.shown ? Theme.dampOpen : Theme.dampClose
                epsilon: 0.3
            }
        }
        Behavior on opacity { NumberAnimation { duration: root.shown ? 120 : 260 } }
        Behavior on width {
            SpringAnimation { spring: Theme.springOpen; damping: 0.35; epsilon: 0.3 }
        }

        Item {
            id: row
            x: 11
            width: pill.innerWidth
            height: parent.height

            Repeater {
                model: root.count

                Rectangle {
                    required property int index
                    readonly property int ws: index + 1
                    x: index * root.dotGap + (root.capsule - root.dotSize) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dotSize
                    height: root.dotSize
                    radius: width / 2
                    color: root.occupied.includes(ws) ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // The capsule. It is drawn as a stretch between a leading and a
            // trailing edge that follow the target on different springs, so on
            // a jump it elongates toward the destination and then contracts —
            // the liquid "blob" motion — instead of sliding as a rigid block.
            Rectangle {
                id: capsule

                readonly property real target: (root.active - 1) * root.dotGap
                property real lead: target
                property real trail: target

                Behavior on lead { SpringAnimation { spring: 5.5; damping: 0.42; epsilon: 0.2 } }
                Behavior on trail { SpringAnimation { spring: 2.8; damping: 0.38; epsilon: 0.2 } }

                onTargetChanged: {
                    lead = target;
                    trail = target;
                }

                x: Math.min(lead, trail)
                width: Math.abs(lead - trail) + root.capsule
                height: root.dotSize + 2
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
            }
        }
    }
}
