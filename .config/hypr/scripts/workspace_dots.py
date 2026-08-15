#!/usr/bin/env python3
"""Ephemeral workspace indicator for Hyprland.

A bottom-anchored layer-shell strip of dots that stays hidden and pops up for a
moment whenever the focused workspace changes.

    bright  you are here
    medium  has windows
    faint   empty, but sits between two used workspaces

The strip is only as long as it needs to be: it ends at the highest workspace
that is either occupied or focused, so an empty workspace only earns a dot when
something is using a workspace past it. That is what makes a gap readable — the
faint dots tell you how far along the row the bright one is.

Waybar can't do that (its persistent-workspaces count is static), hence the
hand-rolled widget. Hiding unmaps the layer surface, so the slide comes from
`layerrule { match:namespace = ^(dots)$; animation = slide }` in hyprland.conf.
"""

import json
import os
import socket
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

VISIBLE_MS = 1200
NAMESPACE = "dots"
STYLE = os.path.expanduser("~/.config/hypr/dots.css")

# Hyprland event lines are "<event>>><data>". Only focus changes pop the strip
# up; a window merely opening elsewhere must not.
TRIGGERS = ("workspace", "workspacev2", "focusedmon", "focusedmonv2")


def hypr_dir():
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        sys.exit("HYPRLAND_INSTANCE_SIGNATURE is unset — not running under Hyprland")
    return os.path.join(runtime, "hypr", signature)


def claim_singleton():
    """Abstract-namespace socket as a lock, so a Hyprland reload can't stack
    two indicators on top of each other."""
    lock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        lock.bind("\0hypr-workspace-dots")
    except OSError:
        sys.exit(0)
    return lock  # kept alive for the process lifetime


class Hypr:
    """Request/response over Hyprland's control socket."""

    def __init__(self, directory):
        self.path = os.path.join(directory, ".socket.sock")

    def request(self, command):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.connect(self.path)
            sock.sendall(command.encode())
            chunks = []
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                chunks.append(chunk)
        finally:
            sock.close()
        return json.loads(b"".join(chunks) or b"null")

    def state(self):
        """(active workspace id, set of occupied workspace ids)."""
        workspaces = self.request("j/workspaces") or []
        active = self.request("j/activeworkspace") or {}
        occupied = {
            w["id"] for w in workspaces if w["id"] > 0 and w.get("windows", 0) > 0
        }
        return active.get("id", 1), occupied


class Dots(Gtk.Window):
    def __init__(self, hypr):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.hypr = hypr
        self.hide_source = None

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, NAMESPACE)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 8)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        # No exclusive zone: the strip floats over whatever is below it.
        GtkLayerShell.set_exclusive_zone(self, 0)

        self.get_style_context().add_class("dots-window")

        self.pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.pill.get_style_context().add_class("pill")
        self.add(self.pill)

        self.connect("realize", self._make_click_through)

    def _make_click_through(self, *_):
        """Purely informational — never eat a click."""
        self.get_window().input_shape_combine_region(None, 0, 0)

    def _render(self):
        for child in self.pill.get_children():
            self.pill.remove(child)

        active, occupied = self.hypr.state()
        count = max([active] + list(occupied) + [1])

        for index in range(1, count + 1):
            dot = Gtk.Label(label="●")
            context = dot.get_style_context()
            context.add_class("dot")
            if index == active:
                context.add_class("active")
            elif index in occupied:
                context.add_class("occupied")
            else:
                context.add_class("empty")
            self.pill.pack_start(dot, False, False, 0)

        self.pill.show_all()

    def pop(self):
        self._render()
        self.show()
        if self.hide_source is not None:
            GLib.source_remove(self.hide_source)
        self.hide_source = GLib.timeout_add(VISIBLE_MS, self._on_timeout)

    def _on_timeout(self):
        self.hide_source = None
        self.hide()
        return GLib.SOURCE_REMOVE


def load_style():
    provider = Gtk.CssProvider()
    try:
        provider.load_from_path(STYLE)
    except GLib.Error as error:
        print(f"dots: could not load {STYLE}: {error}", file=sys.stderr)
        return
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )


def main():
    lock = claim_singleton()  # noqa: F841 — must outlive main()
    directory = hypr_dir()

    load_style()
    window = Dots(Hypr(directory))

    events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    events.connect(os.path.join(directory, ".socket2.sock"))
    events.setblocking(False)

    buffer = bytearray()

    def on_event(_fd, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            Gtk.main_quit()
            return False
        try:
            chunk = events.recv(4096)
        except BlockingIOError:
            return True
        if not chunk:
            Gtk.main_quit()
            return False
        buffer.extend(chunk)
        while b"\n" in buffer:
            index = buffer.index(b"\n")
            line = bytes(buffer[:index]).decode(errors="replace")
            del buffer[: index + 1]
            if line.split(">>", 1)[0] in TRIGGERS:
                window.pop()
        return True

    GLib.io_add_watch(
        events.fileno(),
        GLib.PRIORITY_DEFAULT,
        GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR,
        on_event,
    )
    Gtk.main()


if __name__ == "__main__":
    main()
