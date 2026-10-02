import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// GOES-19 satellite view, cropped to Brazil. Replaces the feh window the
// weather module used to open. The right pill — where the weather sits —
// stretches into it.
//
// scripts/weather_satellite.sh still does the fetching: `check` refreshes the
// image in the background every hour along with the forecast, `update` fetches
// it now. This only displays the cached crop.
//
//     scroll        zoom toward the pointer
//     drag          pan while zoomed
//     double-click  back to the whole picture
Item {
    id: root

    property bool shown: false
    property string forecast: ""

    readonly property string imagePath: `${Quickshell.env("HOME")}/.cache/waybar-weather/weather_sat.png`
    readonly property int size: 520
    readonly property int pad: 14

    implicitWidth: size + pad * 2
    implicitHeight: pad + 24 + 10 + size + pad

    // Each open re-reads the file (the hourly refresh may have replaced it) and
    // starts zoomed out. The query string defeats Qt's image cache.
    property real stamp: 0
    onShownChanged: {
        if (!shown)
            return;
        stamp = Date.now();
        reset();
    }

    Process {
        id: fetch
        command: [`${Quickshell.shellDir}/scripts/weather_satellite.sh`, "update"]
        onExited: root.stamp = Date.now()
    }

    // ── Zoom and pan ────────────────────────────────────────────────────────
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property bool dragging: false

    function clampPan() {
        const min = size - size * zoom;
        panX = Math.max(min, Math.min(0, panX));
        panY = Math.max(min, Math.min(0, panY));
    }
    function zoomAt(mx, my, factor) {
        const z = Math.max(1, Math.min(5, zoom * factor));
        // Keep the point under the pointer where it is.
        panX = mx - (mx - panX) * (z / zoom);
        panY = my - (my - panY) * (z / zoom);
        zoom = z;
        clampPan();
    }
    function reset() {
        zoom = 1;
        panX = 0;
        panY = 0;
    }

    ColumnLayout {
        x: root.pad
        y: root.pad
        width: root.size
        spacing: 10

        Reveal {
            shown: root.shown
            order: 0
            Layout.fillWidth: true
            implicitHeight: 24

            RowLayout {
                width: root.size
                height: 24
                Txt {
                    text: root.forecast || "Satélite"
                    color: Theme.fg
                }
                Item { Layout.fillWidth: true }
                Txt {
                    text: root.zoom > 1.01 ? `${root.zoom.toFixed(1)}×` : "GOES-19 · Brasil"
                    color: Theme.faint
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        Reveal {
            shown: root.shown
            order: 1
            rise: 12
            Layout.preferredWidth: root.size
            Layout.preferredHeight: root.size

            ClippingRectangle {
                id: viewport
                width: root.size
                height: root.size
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.05)

                Image {
                    id: sat
                    source: root.stamp ? `file://${root.imagePath}?${root.stamp}` : ""
                    cache: false
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectCrop

                    x: root.panX
                    y: root.panY
                    width: root.size * root.zoom
                    height: root.size * root.zoom

                    // Loose spring on zoom, so a wheel notch lands with a little
                    // give. Off while dragging: the image must stick to the pointer.
                    Behavior on x { enabled: !root.dragging; SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.25 } }
                    Behavior on y { enabled: !root.dragging; SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.25 } }
                    Behavior on width { SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.25 } }
                    Behavior on height { SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.25 } }

                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    // Nothing cached yet (first run, or a cleared cache): fetch now.
                    onStatusChanged: {
                        if (status === Image.Error && !fetch.running)
                            fetch.running = true;
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    visible: sat.status !== Image.Ready
                    text: fetch.running ? "Baixando imagem…" : sat.status === Image.Error ? "Sem imagem" : ""
                    color: Theme.faint
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.zoom > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                    property real lastX
                    property real lastY

                    onWheel: wheel => root.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y > 0 ? 1.35 : 1 / 1.35)
                    onDoubleClicked: root.reset()
                    onPressed: mouse => {
                        lastX = mouse.x;
                        lastY = mouse.y;
                        root.dragging = true;
                    }
                    onReleased: root.dragging = false
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        root.panX += mouse.x - lastX;
                        root.panY += mouse.y - lastY;
                        lastX = mouse.x;
                        lastY = mouse.y;
                        root.clampPan();
                    }
                }
            }
        }
    }
}
