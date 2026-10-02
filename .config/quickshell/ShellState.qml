pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Shell-wide state. Lives in a singleton because there is one Bar per screen
// and all of them must agree on which menu is open and how the bar sits.
Singleton {
    id: root

    // "" when nothing is open, otherwise the name of the open menu. Only one
    // menu is ever open at a time. Each belongs to the pill it grows out of:
    readonly property var centerMenus: ["calendar", "launcher", "clipboard", "wallpaper", "power"]
    readonly property var rightMenus: ["center", "satellite"]
    property string menu: ""
    // Screen the menu belongs to, so a keybind opens it on the focused monitor
    // instead of on every monitor at once.
    property string menuScreen: ""

    function open(name, screenName) {
        menuScreen = screenName ?? Hyprland.focusedMonitor?.name ?? "";
        menu = name;
    }

    function close() {
        menu = "";
    }

    function toggle(name, screenName) {
        if (menu === name)
            close();
        else
            open(name, screenName);
    }

    // How the bar shares the top of the screen (SUPER+P cycles):
    //   normal   reserves its strip; tiled windows start below it
    //   overlap  floats; windows run underneath it
    //   hidden   not shown
    // Replaces waybar/scripts/bar_mode.sh. Waybar needed a restart against a
    // second config file to flip `exclusive`; here it is a binding.
    property string barMode: "normal"

    function cycleBarMode() {
        barMode = ({
                normal: "overlap",
                overlap: "hidden"
            })[barMode] ?? "normal";
        modeFile.setText(barMode);
    }

    // Stored in the runtime dir like the old script did, so the mode survives a
    // shell reload or a compositor restart but resets on reboot.
    FileView {
        id: modeFile
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-bar-mode`
        printErrors: false
        onLoaded: {
            const m = text().trim();
            if (["normal", "overlap", "hidden"].includes(m))
                root.barMode = m;
        }
    }

    // ── Volume OSD ──────────────────────────────────────────────────────────
    // True for a moment after the volume changes. Not a menu: it takes no
    // keyboard focus and a click elsewhere doesn't need to dismiss it.
    property bool osd: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    // PipeWire reports the current volume once when the sink is first bound,
    // and again whenever the default sink changes. Neither is the user touching
    // the volume, so changes are ignored until things have settled.
    property bool osdArmed: false
    onSinkChanged: {
        osdArmed = false;
        armTimer.restart();
    }
    Timer {
        id: armTimer
        interval: 1500
        running: true
        onTriggered: root.osdArmed = true
    }

    function flashOsd() {
        // The control center already shows a live slider.
        if (!osdArmed || menu === "center")
            return;
        osd = true;
        osdTimer.restart();
    }
    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: root.osd = false
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.flashOsd(); }
        function onMutedChanged() { root.flashOsd(); }
    }
}
