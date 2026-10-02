pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Replaces swaync.
//
// Every notification is kept (tracked) until dismissed, which is what the
// control center lists. A subset is also shown as a toast for a few seconds —
// `popups` — unless Do Not Disturb is on. Hiding a toast does not dismiss the
// notification; it stays in the center.
Singleton {
    id: root

    property bool dnd: false

    readonly property var list: server.trackedNotifications.values
    property var popups: []

    // Same timeouts swaync had: low 4s, normal 8s, critical never.
    // A notification's own expire timeout wins when it sets one.
    function timeoutFor(n) {
        // A toast's delegate outlives its notification by the length of the
        // remove transition.
        if (!n)
            return 0;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        // Already milliseconds (notify-send -t 2000 arrives as 2000).
        if (n.expireTimeout > 0)
            return n.expireTimeout;
        return n.urgency === NotificationUrgency.Low ? 4000 : 8000;
    }

    // A toast leaving on its own goes into the control center, and the pill
    // it flies into acknowledges it (RightModules' bell listens for this).
    signal absorbed

    function hidePopup(n) {
        const before = popups.length;
        popups = popups.filter(p => p !== n);
        if (popups.length < before && list.includes(n))
            absorbed();
    }

    // Clear-all is one sweep, not a collapse. Dismissing straight away removes
    // the rows one by one in the same frame, and each removal shoves the rest up
    // (the list's displaced transition), which reads as them leaving one at a
    // time. Instead `clearing` slides every row out together, lightly staggered,
    // and the real dismiss happens once they are gone.
    property bool clearing: false

    function clearAll() {
        popups = [];
        if (list.length === 0 || clearing)
            return;
        clearing = true;
        sweep.interval = Math.min(list.length, 8) * 35 + 280;
        sweep.restart();
    }

    Timer {
        id: sweep
        onTriggered: {
            // Copy first: dismissing mutates the tracked list underneath us.
            for (const n of [...server.trackedNotifications.values])
                n.dismiss();
            root.clearing = false;
        }
    }

    // Invoke the default action if the sender offered one; either way the
    // notification has been dealt with.
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def)
            def.invoke();
        else
            n.dismiss();
        hidePopup(n);
    }

    NotificationServer {
        id: server

        // Survive a shell reload (saving a .qml file) without dropping what
        // is already on screen.
        keepOnReload: true

        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: n => {
            n.tracked = true;
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 5);
        }
    }

    // A closed notification (dismissed here, or withdrawn by the app) must not
    // leave a dangling toast.
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            // Straight from the server: root.list is a binding that may not
            // have caught up yet inside this handler.
            const live = server.trackedNotifications.values;
            const kept = root.popups.filter(p => live.includes(p));
            if (kept.length !== root.popups.length)
                root.popups = kept;
        }
    }
}
