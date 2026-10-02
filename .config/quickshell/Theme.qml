pragma Singleton

import QtQuick
import Quickshell

// One place for the numbers every panel shares.
//
// This is the reference copy of the glass recipe; the GTK stylesheets for
// swaync, walker and the workspace dots repeat it. A dark, mostly transparent
// tint that lets Hyprland's blur do the work, a diagonal sheen that is gone by
// ~58%, and a lit top rim over a shaded bottom rim. The rim pairing is what
// reads as thickness; drop it and the panel flattens into a decal.
Singleton {
    // Glass
    readonly property color tint: Qt.rgba(18 / 255, 18 / 255, 20 / 255, 0.28)
    // Opened panels sit over arbitrary windows rather than over the wallpaper
    // strip, so they need a little more body to keep text legible.
    readonly property color tintOpen: Qt.rgba(18 / 255, 18 / 255, 20 / 255, 0.42)
    readonly property color border: Qt.rgba(1, 1, 1, 0.11)
    readonly property color rimTop: Qt.rgba(1, 1, 1, 0.24)
    readonly property color rimBottom: Qt.rgba(0, 0, 0, 0.30)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)

    // Text
    readonly property color fg: "#ffffff"
    readonly property color dim: "#dcdcdc"
    readonly property color faint: Qt.rgba(1, 1, 1, 0.45)
    readonly property color urgent: "#ff5555"

    readonly property string font: "JetBrainsMono Nerd Font"
    // Same 13px / weight 500 as the bar had: this is a ~81dpi ultrawide, and at
    // lighter weights small stems have almost no pixels to land on.
    readonly property int fontSize: 13
    readonly property int fontWeight: Font.Medium

    // Geometry
    readonly property int barHeight: 28
    readonly property int barMarginTop: 6
    readonly property int barMarginSide: 8
    readonly property int radius: 14
    readonly property int radiusOpen: 22
    readonly property int padX: 9

    // The surface is this tall regardless of what is open, and the input mask
    // follows the panels. Resizing a layer surface every animation frame costs
    // a configure round-trip per frame and stutters; masking a fixed one is free.
    readonly property int surfaceHeight: 720

    // Motion. Opening is a loose spring that overshoots and settles, which is
    // most of what makes the panel feel like it grows out of the pill rather
    // than being swapped in. Closing is stiff and critically damped — the eye
    // wants dismissal to be quick and not wobble.
    readonly property real springOpen: 3.6
    readonly property real dampOpen: 0.24
    readonly property real springClose: 6.0
    readonly property real dampClose: 0.55
    readonly property real springMass: 1.0
    // Panels that leave the bar and float (launcher, power) travel further and
    // move slower and heavier, with a softer settle.
    readonly property real springDrop: 2.2
    readonly property real dampDrop: 0.26
    readonly property real springDropClose: 3.2
    readonly property real dampDropClose: 0.5
    readonly property real massDrop: 1.3
    // How far a floating panel can get from its pill before the glass neck
    // between them pinches off. Bigger holds on longer.
    readonly property real gooReach: 150
    // Travel time of a floating panel, which is how long the split lasts.
    readonly property int dropOpenMs: 720
    readonly property int dropCloseMs: 520

    // Delay between neighbouring items when an opened panel's content cascades in.
    readonly property int stagger: 22
}
