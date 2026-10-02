//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

// Entry point. `qs` (no arguments) loads this from ~/.config/quickshell.
//
// UseQApplication above is needed for tray menus: SystemTrayItem.display()
// opens a platform menu, which requires a QApplication rather than the plain
// QGuiApplication Quickshell starts by default.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        Workspaces {}
    }

    // `qs ipc call shell toggle power` etc. — what hyprland.conf binds to.
    // Lives here rather than in ShellState.qml: a handler inside a singleton never
    // registered its target.
    IpcHandler {
        target: "shell"

        function toggle(name: string): void {
            ShellState.toggle(name);
        }
        function close(): void {
            ShellState.close();
        }
        function current(): string {
            return ShellState.menu;
        }
        function notifications(): string {
            return `${Notifs.list.length} tracked, ${Notifs.popups.length} showing, dnd ${Notifs.dnd}`;
        }
        function clearNotifications(): void {
            Notifs.clearAll();
        }
        function dnd(): bool {
            Notifs.dnd = !Notifs.dnd;
            return Notifs.dnd;
        }
        function cycleBarMode(): void {
            ShellState.cycleBarMode();
        }
    }
}
