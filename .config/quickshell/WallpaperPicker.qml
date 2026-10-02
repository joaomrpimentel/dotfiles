import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper filmstrip. Replaces hypr/scripts/wallpaper_picker.py and its
// stylesheet. Opens out of the clock pill (SUPER+W).
//
// Reads the folder and the current image straight out of waypaper's config and
// applies through `waypaper --wallpaper`, so the awww backend, fill mode and
// transition stay exactly as configured and `waypaper --restore` still brings
// the right image back at login.
//
//     ← →  h l  Tab   move        Home / End   first / last
//     Enter           apply       Esc          cancel
//     r               random
FocusScope {
    id: root

    property bool shown: false
    property real maxWidth: 1600
    signal done

    readonly property int thumbW: 320
    readonly property int thumbH: 135
    readonly property int gap: 14
    readonly property int pad: 18

    implicitWidth: Math.min(Math.max(strip.count, 1) * (thumbW + gap) + gap, maxWidth - pad * 2) + pad * 2
    implicitHeight: pad + thumbH + 24 + 12 + 22 + 18 + pad

    // ── waypaper's config ───────────────────────────────────────────────────
    readonly property string home: Quickshell.env("HOME")
    function expand(p) {
        return p.startsWith("~") ? home + p.slice(1) : p;
    }
    property string folder: `${home}/Wallpapers`
    property string currentPath: ""

    FileView {
        path: `${root.home}/.config/waypaper/config.ini`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const f = t.match(/^folder\s*=\s*(.+)$/m);
            const w = t.match(/^wallpaper\s*=\s*(.+)$/m);
            if (f)
                root.folder = root.expand(f[1].trim());
            root.currentPath = w ? root.expand(w[1].trim()) : "";
        }
    }

    FolderListModel {
        id: files
        folder: `file://${root.folder}`
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
    }

    // Every open starts on the wallpaper in use.
    onShownChanged: if (shown) selectCurrent()
    function selectCurrent() {
        for (let i = 0; i < files.count; i++) {
            if (files.get(i, "filePath") === currentPath) {
                strip.currentIndex = i;
                strip.positionViewAtIndex(i, ListView.Center);
                return;
            }
        }
    }

    function apply() {
        const p = files.get(strip.currentIndex, "filePath");
        if (!p)
            return;
        Quickshell.execDetached(["waypaper", "--wallpaper", p]);
        done();
    }

    focus: true
    Keys.onPressed: event => {
        const n = strip.count;
        if (!n)
            return;
        if ([Qt.Key_Right, Qt.Key_L, Qt.Key_Tab].includes(event.key))
            strip.currentIndex = (strip.currentIndex + 1) % n;
        else if ([Qt.Key_Left, Qt.Key_H, Qt.Key_Backtab].includes(event.key))
            strip.currentIndex = (strip.currentIndex - 1 + n) % n;
        else if (event.key === Qt.Key_Home)
            strip.currentIndex = 0;
        else if (event.key === Qt.Key_End)
            strip.currentIndex = n - 1;
        else if (event.key === Qt.Key_R)
            strip.currentIndex = Math.floor(Math.random() * n);
        else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            apply();
        else
            return;
        event.accepted = true;
    }

    ListView {
        id: strip
        x: root.pad
        y: root.pad
        width: root.implicitWidth - root.pad * 2
        height: root.thumbH + 24
        orientation: ListView.Horizontal
        spacing: root.gap
        leftMargin: root.gap / 2
        rightMargin: root.gap / 2
        clip: true
        model: files
        boundsBehavior: Flickable.StopAtBounds

        // The selection glides to the middle of the strip.
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: width / 2 - root.thumbW / 2
        preferredHighlightEnd: width / 2 + root.thumbW / 2
        highlightMoveDuration: 380
        highlightMoveVelocity: -1

        delegate: Reveal {
            id: thumb
            required property int index
            required property string filePath
            required property string fileName

            readonly property bool selected: ListView.isCurrentItem

            shown: root.shown
            // Ripples outward from the selected wallpaper.
            order: Math.min(Math.abs(index - strip.currentIndex), 10)
            rise: 10
            width: root.thumbW
            implicitHeight: root.thumbH + 24

            ClippingRectangle {
                y: 12
                width: root.thumbW
                height: root.thumbH
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: thumb.selected ? 2 : 1
                border.color: thumb.selected ? Theme.fg : Theme.border

                scale: thumb.selected ? 1.06 : hoverArea.containsMouse ? 0.97 : 0.92
                opacity: thumb.selected ? 1 : 0.62
                Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.002 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Image {
                    anchors.fill: parent
                    source: `file://${thumb.filePath}`
                    sourceSize: Qt.size(root.thumbW, root.thumbH)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // The wallpaper in use gets a small dot, so it's findable
                // after moving the selection away from it.
                Rectangle {
                    visible: thumb.filePath === root.currentPath
                    anchors { top: parent.top; right: parent.right; margins: 10 }
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.fg
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        strip.currentIndex = thumb.index;
                        root.apply();
                    }
                }
            }
        }
    }

    Txt {
        id: caption
        y: strip.y + strip.height + 12
        width: root.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: files.get(strip.currentIndex, "fileName") ?? ""
        color: Theme.fg
    }
    Txt {
        y: caption.y + 24
        width: root.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: "← →  mover      enter  aplicar      r  aleatório      esc  cancelar"
        color: Theme.faint
        font.pixelSize: Theme.fontSize - 2
    }
}
