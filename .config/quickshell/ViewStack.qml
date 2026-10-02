import QtQuick

// Several panels that open out of the same pill. Only `current` is shown and
// only it sizes the stack, so switching views while the pill is open (the
// launcher turning into the clipboard, the control center into the power menu)
// is the glass springing from one size to the other while the contents
// crossfade — the same motion as opening.
//
// Children are matched by objectName. Keeping them all alive, rather than
// loading one at a time, is deliberate: the wallpaper thumbnails stay decoded
// and the launcher's app list stays built between opens.
Item {
    id: root

    property string current
    // Which edge the views hug: Qt.AlignHCenter or Qt.AlignRight.
    property int align: Qt.AlignHCenter

    readonly property Item active: {
        for (const c of children)
            if (c.objectName === current)
                return c;
        return null;
    }

    implicitWidth: active?.implicitWidth ?? 0
    implicitHeight: active?.implicitHeight ?? 0

    Component.onCompleted: {
        for (const c of children) {
            const view = c;
            view.x = Qt.binding(() => root.align === Qt.AlignRight ? root.width - view.implicitWidth
                                                                  : (root.width - view.implicitWidth) / 2);
            view.opacity = Qt.binding(() => view.objectName === root.current ? 1 : 0);
            view.visible = Qt.binding(() => view.opacity > 0);
        }
    }
}
