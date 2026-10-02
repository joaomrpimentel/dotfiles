import QtQuick
import QtQuick.Effects

// The glass material, as a rectangle. Everything that has a background in the
// shell is one of these — see Theme.qml for why each layer is there.
//
// Hyprland blurs whatever is behind this (layerrule `blur` on the quickshell
// namespace). This draws the tint, the sheen and the rim on top of that blur.
Rectangle {
    id: root

    property color tint: Theme.tint
    // Draws nothing, keeping only its geometry and clip, for when something
    // else paints the material for it (Morph's goo while a panel splits off).
    property bool bare: false

    color: bare ? "transparent" : tint
    radius: Theme.radius
    border.width: bare ? 0 : 1
    border.color: Theme.border

    // Sheen: a white wash strongest at the top that is gone well before the
    // text baseline. Capped in absolute pixels rather than scaled with height,
    // so an opened 300px panel keeps the same lit top edge as a 28px pill
    // instead of turning milky all the way down.
    Rectangle {
        visible: !root.bare
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 1
        }
        height: Math.min(parent.height * 0.6, 34)
        topLeftRadius: root.radius - 1
        topRightRadius: root.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.14) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.00) }
        }
    }

    // Rim: a 1px ring, lit at the top and shaded at the bottom. QML can't put a
    // gradient on a border, so the ring is drawn twice — white and black — and
    // each copy is faded out towards the opposite edge with an alpha mask.
    component Rim: Item {
        id: rim
        property color color
        property bool fromTop: true
        property real reach: 12

        anchors.fill: parent

        Rectangle {
            id: ring
            anchors.fill: parent
            anchors.margins: 1
            radius: root.radius - 1
            color: "transparent"
            border.width: 1
            border.color: rim.color
            visible: false
            layer.enabled: true
        }

        Item {
            id: fade
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                width: parent.width
                height: Math.min(rim.reach, parent.height)
                y: rim.fromTop ? 0 : parent.height - height
                gradient: Gradient {
                    GradientStop { position: 0; color: rim.fromTop ? "white" : "transparent" }
                    GradientStop { position: 1; color: rim.fromTop ? "transparent" : "white" }
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: ring
            maskEnabled: true
            maskSource: fade
        }
    }

    Rim { visible: !root.bare; color: Theme.rimTop; fromTop: true; reach: 14 }
    Rim { visible: !root.bare; color: Theme.rimBottom; fromTop: false; reach: 8 }
}
