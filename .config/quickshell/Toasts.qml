import QtQuick
import Quickshell

// Notification toasts, stacked under the right pill.
//
// A new toast drops out from under the pill with an overshoot, and the ones
// already showing are shoved down the same way, so the stack reflows like
// something with mass rather than jumping. (Eased with OutBack rather than a
// SpringAnimation: a spring inside a ListView transition has no fixed end
// value and leaves items stranded mid-flight.) When its time is up a toast
// is drawn back up into the pill, and the pill's bell counts it.
//
// Hovering a toast holds its timer; clicking it runs the default action.
ListView {
    id: root

    width: 380
    height: contentHeight
    spacing: 8
    interactive: false

    // ScriptModel diffs by object identity, so adding one notification is an
    // insert, not a model reset — without that, add/displaced never run.
    model: ScriptModel { values: Notifs.popups }

    add: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { property: "y"; from: -24; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }
    displaced: Transition {
        NumberAnimation { property: "y"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { properties: "opacity,scale"; to: 1; duration: 150 }
    }
    // Leaving, a toast is sucked back up into the pill it came from — that is
    // where it went (the control center), so that is where it should be seen
    // going. InBack gives it a small dip before it lifts.
    remove: Transition {
        ParallelAnimation {
            NumberAnimation { property: "y"; to: -46; duration: 380; easing.type: Easing.InBack; easing.overshoot: 1.6 }
            NumberAnimation { property: "scale"; to: 0.35; duration: 380; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 140 }
                NumberAnimation { property: "opacity"; to: 0; duration: 240 }
            }
        }
    }

    delegate: Glass {
        id: toast

        required property var modelData
        readonly property var notif: modelData

        width: root.width
        height: card.implicitHeight
        radius: 18
        tint: Theme.tintOpen
        transformOrigin: Item.TopRight

        NotificationCard {
            id: card
            anchors.fill: parent
            notif: toast.notif
            onCloseClicked: Notifs.hidePopup(toast.notif)
            onBodyClicked: Notifs.activate(toast.notif)
        }

        readonly property int timeout: Notifs.timeoutFor(notif)
        property real remaining: 1

        // Thin line along the bottom: how long until it goes away.
        Rectangle {
            visible: toast.timeout > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            x: toast.radius / 2
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.35)
            width: (toast.width - toast.radius) * toast.remaining
        }

        // One animation is both the countdown and the progress line, so
        // pausing it on hover pauses both and resuming picks up where it was.
        NumberAnimation on remaining {
            from: 1
            to: 0
            duration: toast.timeout
            running: toast.timeout > 0
            paused: running && hoverWatch.hovered
            onFinished: Notifs.hidePopup(toast.notif)
        }

        HoverHandler { id: hoverWatch }
    }
}
