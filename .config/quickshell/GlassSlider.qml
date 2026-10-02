import QtQuick

// A thin track that fattens under the pointer. Drag or click to set, scroll to
// nudge. `value` is 0..1; `moved(v)` fires on user input only, so a binding
// from outside (the live volume) never fights the drag.
Item {
    id: root

    property real value: 0
    property bool muted: false
    signal moved(real v)

    implicitHeight: 22

    readonly property bool active: area.containsMouse || area.pressed

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.active ? 10 : 6
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.12)
        Behavior on height { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.05 } }

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            color: root.muted ? Qt.rgba(1, 1, 1, 0.3) : Theme.fg
            Behavior on width {
                enabled: !area.pressed
                SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.3 }
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        function set(mx) {
            root.moved(Math.max(0, Math.min(1, mx / width)));
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
