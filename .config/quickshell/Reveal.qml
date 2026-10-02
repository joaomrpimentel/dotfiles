import QtQuick

// Wraps one piece of an opened panel so it drops in a little after its
// neighbour. A panel's items arriving in a wave, rather than all at once, is
// the other half of the organic feel — see Morph.qml for the first half.
//
//   Reveal { shown: morph.open; order: 3; Text { ... } }
//
// Only the entrance is staggered. Leaving is immediate and simultaneous: the
// panel is already collapsing, and a cascade on the way out reads as lag.
Item {
    id: root

    property bool shown: false
    property int order: 0
    // How far above its resting place an item starts.
    property real rise: 6

    default property alias content: holder.data

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height

    Item {
        id: holder
        anchors.fill: parent

        opacity: root.shown ? 1 : 0
        transform: Translate {
            id: shift
            y: root.shown ? 0 : -root.rise
            Behavior on y {
                SequentialAnimation {
                    PauseAnimation { duration: root.shown ? 60 + root.order * Theme.stagger : 0 }
                    NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
            }
        }
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? 60 + root.order * Theme.stagger : 0 }
                NumberAnimation { duration: root.shown ? 220 : 70; easing.type: Easing.OutCubic }
            }
        }
    }
}
