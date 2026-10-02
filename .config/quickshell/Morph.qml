import QtQuick

// A glass pill that grows into a panel.
//
// This is the whole effect: the menu is not a second window that appears next
// to the bar, it is the same glass rectangle springing out to a new size while
// its content crossfades. The spring overshoots slightly on the way out, which
// is what sells it as the pill stretching rather than a panel being swapped in.
//
// Layout only ever sees the closed size (implicitWidth/Height below), so the
// rest of the bar does not shuffle when a menu opens. The glass overflows the
// item downward and sideways; Bar.qml's input mask follows `body` and `dock`.
Item {
    id: root

    property bool open: false
    property Component closed
    property Component opened

    // Which way the panel grows horizontally from the pill:
    // Qt.AlignHCenter grows both ways, Qt.AlignRight stays pinned to the
    // pill's right edge and grows leftwards, Qt.AlignLeft the reverse.
    property int grow: Qt.AlignHCenter

    // How far down the screen the opened panel travels. 0 keeps it attached to
    // the bar; anything else lets it leave the pill and float lower, with a
    // copy of the pill (`dock`) staying behind so the bar keeps its shape.
    property real drop: 0
    // Whether that copy is shown. Off in hidden bar mode, where the pill
    // itself is only there to carry the menu.
    property bool keepPill: true

    // The moving glass and the pill left behind, for the input mask.
    readonly property Item body: glass
    readonly property Item dock: dock
    readonly property Item openedItem: openedLoader.item

    implicitWidth: closedLoader.implicitWidth
    implicitHeight: Theme.barHeight

    // Spring parameters follow the direction of travel: loose going out, stiff
    // coming back. Bound here so a close that interrupts an open picks up the
    // stiff spring immediately, from wherever the panel currently is.
    // A panel that floats away moves further, so it gets a slower, heavier
    // spring that reads as something letting go rather than snapping.
    readonly property bool _floating: drop > 0
    readonly property real _spring: _floating ? (open ? Theme.springDrop : Theme.springDropClose)
                                              : (open ? Theme.springOpen : Theme.springClose)
    readonly property real _damping: _floating ? (open ? Theme.dampDrop : Theme.dampDropClose)
                                               : (open ? Theme.dampOpen : Theme.dampClose)
    readonly property real _mass: _floating ? Theme.massDrop : Theme.springMass

    // How far along its way a floating panel is: 0 home in the pill, 1 at
    // `drop`. Timed rather than sprung — a spring covers the distance in a
    // flash and the split goes by unseen. Opening starts slow, as if the glass
    // resisted, and gives way with a small overshoot; closing sets off at once
    // (a slow start there reads as the panel fading in place) and eases into
    // the pill as the two fuse.
    property real travel: open && _floating ? 1 : 0
    Behavior on travel {
        NumberAnimation {
            id: travelAnim
            duration: root.open ? Theme.dropOpenMs : Theme.dropCloseMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? [0.55, 0.0, 0.25, 1.1, 1, 1]
                                          : [0.3, 0.15, 0.3, 1.0, 1, 1]
        }
    }
    readonly property bool _travelling: travelAnim.running
    // Whether the opened content should be showing. A floating panel keeps it
    // on the way back until it has shrunk most of the way, so what travels up
    // is still the panel and not an empty shell of glass.
    readonly property bool showing: open || (_floating && travel > 0.6)
    // Size follows travel but leads it: still pill-sized while the neck first
    // forms, fully grown by the time it snaps.
    readonly property real _grow: {
        const t = Math.max(0, Math.min(1, (travel - 0.08) / 0.62));
        return t * t * (3 - 2 * t);
    }

    // While a panel floats, the pill and the panel are painted as one surface
    // by a metaball shader: the panel buds off the pill, a neck of glass
    // stretches between them and pinches off, and closing runs it backwards
    // until the two fuse. Dock and glass go bare and keep only their content.
    readonly property bool _goo: _floating && keepPill
    function _v4(c) { return Qt.vector4d(c.r, c.g, c.b, c.a); }

    ShaderEffect {
        id: goo
        readonly property real m: 2
        visible: root._goo
        x: Math.min(0, glass.x) - m
        y: -m
        width: Math.max(root.width, glass.x + glass.width) - x + m
        height: Math.max(root.height, glass.y + glass.height) - y + m

        property vector2d res: Qt.vector2d(width, height)
        property vector4d rectA: Qt.vector4d(-x, -y, root.width, root.height)
        property vector4d rectB: Qt.vector4d(glass.x - x, glass.y - y, glass.width, glass.height)
        property real radA: Theme.radius
        property real radB: glass.radius
        property real reach: Theme.gooReach
        property vector4d tintA: root._v4(Theme.tint)
        property vector4d tintB: root._v4(glass.tint)
        property vector4d borderCol: root._v4(Theme.border)
        property vector4d rimTopCol: root._v4(Theme.rimTop)
        property vector4d rimBottomCol: root._v4(Theme.rimBottom)

        fragmentShader: Qt.resolvedUrl("shaders/goo.frag.qsb")
    }

    // The pill left behind while the panel is away. It stays up after closing
    // too: the panel comes back by fusing into it, so this is the pill until a
    // non-floating view takes over.
    Glass {
        id: dock
        bare: root._goo
        width: root.width
        height: root.height
        // No fade: it swaps with the glass's own copy of the pill, which
        // appears and disappears instantly too, so the pill never blinks.
        visible: root._floating && root.keepPill
        Loader {
            active: root.drop > 0
            sourceComponent: root.closed
            height: Theme.barHeight
        }
    }

    Glass {
        id: glass

        bare: root._goo
        tint: root.open ? Theme.tintOpen : Theme.tint
        readonly property real openW: Math.max(openedLoader.implicitWidth, root.width)
        readonly property real openH: openedLoader.implicitHeight
        // A floating panel is driven by `travel` instead of springs: it leaves
        // as a copy of the pill and only grows into the panel on the way down,
        // so the split happens between two bodies of a size — a cell dividing,
        // not a panel appearing on top of the pill and sliding off.
        width: root._floating ? root.width + (openW - root.width) * root._grow
             : root.open ? openW : root.width
        height: root._floating ? root.height + (openH - root.height) * root._grow
              : root.open ? openH : root.height
        radius: root._floating ? Theme.radius + (Theme.radiusOpen - Theme.radius) * root._grow
              : root.open ? Theme.radiusOpen : Theme.radius
        y: root._floating ? root.drop * root.travel : 0
        x: root.grow === Qt.AlignRight ? root.width - width
         : root.grow === Qt.AlignLeft ? 0
         : (root.width - width) / 2

        // Springs for docked panels, and for a floating one that has settled
        // and changes size (the launcher's list growing as you type).
        Behavior on width {
            enabled: !root._floating || !root._travelling
            SpringAnimation { spring: root._spring; damping: root._damping; mass: root._mass; epsilon: 0.3 }
        }
        Behavior on height {
            enabled: !root._floating || !root._travelling
            SpringAnimation { spring: root._spring; damping: root._damping; mass: root._mass; epsilon: 0.3 }
        }
        Behavior on radius {
            enabled: !root._floating
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on tint {
            ColorAnimation { duration: 200 }
        }

        // Content is clipped to the glass so nothing spills out while the
        // spring is still undersized. A rectangular clip is fine because both
        // contents keep clear of the rounded corners with their own padding.
        clip: true

        Loader {
            id: closedLoader
            sourceComponent: root.closed
            height: Theme.barHeight
            // Pinned to the same edge the panel grows from, so the pill's own
            // content stays put while it fades rather than sliding with the glass.
            x: root.grow === Qt.AlignRight ? glass.width - width
             : root.grow === Qt.AlignLeft ? 0
             : (glass.width - width) / 2

            // The dock shows the pill while a floating panel is around.
            opacity: root.open || (root._floating && root.keepPill) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                enabled: !root._floating
                NumberAnimation { duration: root.open ? 90 : 220; easing.type: Easing.OutCubic }
            }
        }

        Loader {
            id: openedLoader
            sourceComponent: root.opened
            x: root.grow === Qt.AlignRight ? glass.width - width
             : root.grow === Qt.AlignLeft ? 0
             : (glass.width - width) / 2

            // Content arrives a beat after the glass starts moving and leaves
            // immediately, so the eye follows the shape first. A floating
            // panel fills in once it has mostly grown and empties as it shrinks.
            opacity: root._floating ? Math.max(0, Math.min(1, (root._grow - 0.55) / 0.4))
                   : root.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: !root._floating
                SequentialAnimation {
                    PauseAnimation { duration: root.open ? 70 : 0 }
                    NumberAnimation { duration: root.open ? 220 : 80; easing.type: Easing.OutCubic }
                }
            }

            // A small settle-in, scaled from the edge the panel grows from.
            scale: root.open ? 1 : 0.94
            transformOrigin: root.grow === Qt.AlignRight ? Item.TopRight
                           : root.grow === Qt.AlignLeft ? Item.TopLeft
                           : Item.Top
            Behavior on scale {
                NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }
        }
    }
}
