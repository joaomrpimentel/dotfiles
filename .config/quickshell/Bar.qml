import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// The bar, one per screen. Replaces waybar, and is where every menu comes from.
//
// Three glass pills — stats on the left, clock in the middle, the rest on the
// right. The middle and right pills are Morphs, and each menu grows out of the
// pill it belongs to:
//
//     clock pill   calendar (click)   launcher (SUPER)   clipboard (SUPER+V)
//                  wallpaper (SUPER+W)   power (⏻, Ctrl+Alt+Del)
//     right pill   control center (SUPER+N)
//                  weather satellite (click the forecast)
//                  volume OSD (whenever the volume changes)
//
// Notification toasts drop out from under the right pill.
//
// The layer surface is a fixed Theme.surfaceHeight tall and almost entirely
// transparent. `mask` limits input to the glass shapes as they animate, so
// clicks anywhere else fall through to the windows underneath.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    screen: modelData

    // An empty menuScreen means "wherever": right after launch Hyprland's
    // focused monitor isn't known yet, and a keybind must still work.
    readonly property string menu: ShellState.menuScreen === "" || ShellState.menuScreen === screen.name ? ShellState.menu : ""
    readonly property bool menuOpen: menu !== ""
    readonly property bool centerOpen: ShellState.centerMenus.includes(menu)
    readonly property bool rightMenu: ShellState.rightMenus.includes(menu)
    readonly property bool rightOpen: rightMenu || ShellState.osd

    // What each pill shows. Updated only while something is open, so a closing
    // pill keeps its content on screen until it has finished collapsing.
    property string forecast: ""
    property string centerView: "calendar"
    property string rightView: "center"
    // Worked out from `menu` directly: the centerOpen/rightMenu bindings may
    // not have re-evaluated yet when this handler runs.
    onMenuChanged: {
        if (ShellState.centerMenus.includes(menu))
            centerView = menu;
        if (ShellState.rightMenus.includes(menu))
            rightView = menu;
        else if (ShellState.osd)
            rightView = "osd";
        focusMenu();
    }
    Connections {
        target: ShellState
        function onOsdChanged() {
            if (ShellState.osd && !bar.rightMenu)
                bar.rightView = "osd";
        }
    }

    // Keyboard goes to whichever view just opened (the launcher's search field,
    // the power menu's arrow keys). Deferred a tick so the view is current.
    function focusMenu() {
        Qt.callLater(() => {
            if (bar.centerOpen)
                clockPill.openedItem?.active?.forceActiveFocus();
            else if (bar.rightMenu)
                rightPill.openedItem?.active?.forceActiveFocus();
        });
    }

    readonly property bool hiddenMode: ShellState.barMode === "hidden"

    // Where floating menus sit, below the pill: about a fifth of the way down,
    // kept short enough that the tallest launcher still fits on the surface.
    readonly property real dropY: Math.min(Math.round(screen.height * 0.2), Theme.surfaceHeight - Theme.barMarginTop - 460)

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.surfaceHeight
    color: "transparent"

    // Hidden mode hides the pills, not the shell: menus, the OSD and toasts
    // still appear, each bringing only its own pill along.
    visible: !hiddenMode || menuOpen || ShellState.osd || Notifs.popups.length > 0
    exclusiveZone: ShellState.barMode === "normal" ? Theme.barHeight + Theme.barMarginTop : 0

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive while a menu is up: it opens from a keybind with no click on
    // the surface, and the launcher has to receive typing immediately.
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        Region { item: statsPill.opacity > 0 ? statsPill : null }
        Region { item: clockPill.opacity > 0 ? clockPill.body : null }
        Region { item: clockPill.dock.visible ? clockPill.dock : null }
        Region { item: rightPill.opacity > 0 ? rightPill.body : null }
        Region { item: toasts.opacity > 0 ? toasts : null }
    }

    // Click anywhere outside the bar's glass and the open menu closes. The grab
    // only covers this window, and the transparent part of it is masked out, so
    // "outside" includes the empty space right under the panel.
    HyprlandFocusGrab {
        active: bar.menuOpen
        windows: [bar]
        onCleared: ShellState.close()
    }

    component Fade: NumberAnimation { duration: 220; easing.type: Easing.OutCubic }

    FocusScope {
        id: keys
        anchors.fill: parent
        Keys.onEscapePressed: ShellState.close()

        Item {
            id: row
            anchors {
                fill: parent
                topMargin: Theme.barMarginTop
                leftMargin: Theme.barMarginSide
                rightMargin: Theme.barMarginSide
            }

            // ── Left: stats ─────────────────────────────────────────────────
            Glass {
                id: statsPill
                width: stats.implicitWidth
                height: Theme.barHeight
                opacity: bar.hiddenMode ? 0 : 1
                Behavior on opacity { Fade {} }

                Stats {
                    id: stats
                    anchors.fill: parent
                }
            }

            // ── Middle: clock ───────────────────────────────────────────────
            Morph {
                id: clockPill
                anchors.horizontalCenter: parent.horizontalCenter
                grow: Qt.AlignHCenter
                open: bar.centerOpen
                // The launcher and the power menu leave the bar and float
                // further down the screen; the calendar and the wallpaper
                // picker stay hanging off it.
                drop: ["launcher", "clipboard", "power"].includes(bar.centerView) ? bar.dropY : 0
                keepPill: !bar.hiddenMode
                opacity: !bar.hiddenMode || bar.centerOpen ? 1 : 0
                Behavior on opacity { Fade {} }

                SystemClock {
                    id: time
                    precision: SystemClock.Minutes
                }

                closed: Txt {
                    // Qt's pt_BR short names carry a trailing period ("sex.",
                    // "set."); the waybar version had none, so strip it.
                    text: Qt.locale("pt_BR").toString(time.date, "ddd dd MMM  HH:mm").replace(/\./g, "")
                    color: Theme.fg
                    leftPadding: Theme.padX + 4
                    rightPadding: Theme.padX + 4
                    height: Theme.barHeight

                    MouseArea {
                        anchors.fill: parent
                        onClicked: ShellState.toggle("calendar", bar.screen.name)
                    }
                }

                opened: ViewStack {
                    current: bar.centerView
                    align: Qt.AlignHCenter

                    Calendar {
                        objectName: "calendar"
                        shown: clockPill.open && bar.centerView === "calendar"
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    Launcher {
                        objectName: "launcher"
                        startMode: "apps"
                        shown: clockPill.showing && bar.centerView === "launcher"
                        onDone: ShellState.close()
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    Launcher {
                        objectName: "clipboard"
                        startMode: "clipboard"
                        shown: clockPill.showing && bar.centerView === "clipboard"
                        onDone: ShellState.close()
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    PowerMenu {
                        objectName: "power"
                        shown: clockPill.showing && bar.centerView === "power"
                        onDone: ShellState.close()
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    WallpaperPicker {
                        objectName: "wallpaper"
                        // Stays between the side pills instead of covering them.
                        maxWidth: row.width - 2 * Math.max(statsPill.width, rightPill.width) - 48
                        shown: clockPill.open && bar.centerView === "wallpaper"
                        onDone: ShellState.close()
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }
            }

            // ── Right: media, weather, volume, tray, power ──────────────────
            Morph {
                id: rightPill
                anchors.right: parent.right
                grow: Qt.AlignRight
                open: bar.rightOpen
                opacity: !bar.hiddenMode || bar.rightOpen ? 1 : 0
                Behavior on opacity { Fade {} }

                closed: RightModules {
                    window: bar
                    height: Theme.barHeight
                    onPowerClicked: ShellState.toggle("power", bar.screen.name)
                    onWeatherClicked: ShellState.toggle("satellite", bar.screen.name)
                    onForecastChanged: bar.forecast = forecast
                }

                opened: ViewStack {
                    current: bar.rightView
                    align: Qt.AlignRight

                    ControlCenter {
                        objectName: "center"
                        minWidth: rightPill.width
                        shown: rightPill.open && bar.rightView === "center"
                        onDone: ShellState.close()
                        onWantPower: ShellState.open("power", bar.screen.name)
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    Satellite {
                        objectName: "satellite"
                        forecast: bar.forecast
                        shown: rightPill.open && bar.rightView === "satellite"
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    VolumeOsd {
                        objectName: "osd"
                        minWidth: rightPill.width
                        shown: rightPill.open && bar.rightView === "osd"
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }
            }

            // ── Toasts, under the right pill ────────────────────────────────
            // Out of the way while the right pill is open: the control center
            // lists the same notifications, and the satellite wants the space.
            Toasts {
                id: toasts
                anchors.right: parent.right
                y: Theme.barHeight + 10
                opacity: bar.rightOpen ? 0 : 1
                Behavior on opacity { Fade {} }
            }
        }
    }
}
