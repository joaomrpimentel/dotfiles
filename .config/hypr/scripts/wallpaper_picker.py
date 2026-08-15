#!/usr/bin/env python3
"""Wallpaper picker — a filmstrip over a dimmed desktop.

Reads the wallpaper folder straight out of waypaper's own config, and applies
the choice through `waypaper --wallpaper`, so the awww backend, fill mode and
transition settings stay exactly as configured and `waypaper --restore` still
brings the right image back at login.

    ← →  h l   move        Home / End  first / last
    Enter      apply       Escape      cancel
    r          random

Thumbnails are cached under ~/.cache/wallpaper-picker, keyed by path and mtime.
"""

import configparser
import hashlib
import os
import random
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell  # noqa: E402

NAMESPACE = "wallpaper-picker"
STYLE = os.path.expanduser("~/.config/hypr/wallpaper_picker.css")
WAYPAPER_CONFIG = os.path.expanduser("~/.config/waypaper/config.ini")
CACHE = os.path.expanduser("~/.cache/wallpaper-picker")
FALLBACK_FOLDER = os.path.expanduser("~/Wallpapers")

THUMB_W, THUMB_H = 320, 135
EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")


def wallpaper_folder():
    parser = configparser.ConfigParser()
    try:
        parser.read(WAYPAPER_CONFIG)
        folder = parser.get("Settings", "folder", fallback=FALLBACK_FOLDER)
    except configparser.Error:
        folder = FALLBACK_FOLDER
    return os.path.expanduser(folder.strip())


def current_wallpaper():
    parser = configparser.ConfigParser()
    try:
        parser.read(WAYPAPER_CONFIG)
        return os.path.expanduser(parser.get("Settings", "wallpaper", fallback=""))
    except configparser.Error:
        return ""


def wallpapers(folder):
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return []
    return [
        os.path.join(folder, name)
        for name in names
        if name.lower().endswith(EXTENSIONS)
        and os.path.isfile(os.path.join(folder, name))
    ]


def monitor_width():
    display = Gdk.Display.get_default()
    monitor = display.get_primary_monitor() or display.get_monitor(0)
    return monitor.get_geometry().width if monitor else 1920


def thumbnail(path):
    """Scale-to-fill into THUMB_W x THUMB_H, cached on disk."""
    os.makedirs(CACHE, exist_ok=True)
    key = f"{path}:{os.path.getmtime(path)}:{THUMB_W}x{THUMB_H}"
    cached = os.path.join(CACHE, hashlib.sha1(key.encode()).hexdigest() + ".png")

    if os.path.exists(cached):
        try:
            return GdkPixbuf.Pixbuf.new_from_file(cached)
        except GLib.Error:
            pass  # corrupt cache entry, fall through and rebuild

    source = GdkPixbuf.Pixbuf.new_from_file(path)
    scale = max(THUMB_W / source.get_width(), THUMB_H / source.get_height())
    width = max(1, round(source.get_width() * scale))
    height = max(1, round(source.get_height() * scale))
    scaled = source.scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
    cropped = scaled.new_subpixbuf(
        (width - THUMB_W) // 2, (height - THUMB_H) // 2, THUMB_W, THUMB_H
    )
    try:
        cropped.savev(cached, "png", [], [])
    except GLib.Error:
        pass  # cache is an optimisation, not a requirement
    return cropped


class Picker(Gtk.Window):
    def __init__(self, paths):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.paths = paths
        self.index = 0
        self.frames = []

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, NAMESPACE)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_exclusive_zone(self, -1)

        self.get_style_context().add_class("scrim")

        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        column.set_valign(Gtk.Align.CENTER)
        column.set_halign(Gtk.Align.CENTER)
        self.add(column)

        spacing = 14
        self.strip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=spacing)
        self.strip.set_halign(Gtk.Align.CENTER)

        # The strip only scrolls when it can't fit: give the viewport the full
        # width the thumbnails want, capped to the monitor minus a margin.
        wanted = len(paths) * (THUMB_W + spacing) + spacing
        self.scroller = Gtk.ScrolledWindow()
        self.scroller.set_policy(Gtk.PolicyType.EXTERNAL, Gtk.PolicyType.NEVER)
        self.scroller.set_size_request(min(wanted, monitor_width() - 160), THUMB_H + 24)
        self.scroller.add(self.strip)
        column.pack_start(self.scroller, False, False, 0)

        self.caption = Gtk.Label()
        self.caption.get_style_context().add_class("caption")
        column.pack_start(self.caption, False, False, 0)

        hint = Gtk.Label(label="← →  move      enter  apply      r  random      esc  cancel")
        hint.get_style_context().add_class("hint")
        column.pack_start(hint, False, False, 0)

        self._build()
        self.connect("key-press-event", self.on_key)

    def _build(self):
        current = current_wallpaper()
        for position, path in enumerate(self.paths):
            frame = Gtk.EventBox()
            frame.get_style_context().add_class("thumb")
            try:
                image = Gtk.Image.new_from_pixbuf(thumbnail(path))
            except GLib.Error:
                continue  # unreadable image — just leave it out of the strip
            frame.add(image)
            frame.connect("button-press-event", self.on_click, position)
            self.strip.pack_start(frame, False, False, 0)
            self.frames.append(frame)
            if os.path.abspath(path) == os.path.abspath(current):
                self.index = position
        self._sync()

    def _sync(self):
        for position, frame in enumerate(self.frames):
            context = frame.get_style_context()
            if position == self.index:
                context.add_class("selected")
            else:
                context.remove_class("selected")
        self.caption.set_text(os.path.basename(self.paths[self.index]))
        GLib.idle_add(self._scroll_into_view)

    def _scroll_into_view(self):
        frame = self.frames[self.index]
        allocation = frame.get_allocation()
        adjustment = self.scroller.get_hadjustment()
        page = adjustment.get_page_size()
        target = allocation.x + allocation.width / 2 - page / 2
        adjustment.set_value(
            max(adjustment.get_lower(), min(target, adjustment.get_upper() - page))
        )
        return GLib.SOURCE_REMOVE

    def move(self, delta):
        self.index = (self.index + delta) % len(self.frames)
        self._sync()

    def on_click(self, _widget, _event, position):
        self.index = position
        self._sync()
        self.apply()

    def apply(self):
        path = self.paths[self.index]
        subprocess.Popen(
            ["waypaper", "--wallpaper", path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        Gtk.main_quit()

    def on_key(self, _widget, event):
        key = Gdk.keyval_name(event.keyval)
        if key in ("Escape", "q"):
            Gtk.main_quit()
        elif key in ("Right", "l", "Tab"):
            self.move(1)
        elif key in ("Left", "h", "ISO_Left_Tab"):
            self.move(-1)
        elif key == "Home":
            self.index = 0
            self._sync()
        elif key == "End":
            self.index = len(self.frames) - 1
            self._sync()
        elif key == "r":
            self.index = random.randrange(len(self.frames))
            self._sync()
        elif key in ("Return", "KP_Enter", "space"):
            self.apply()
        return True


def load_style():
    provider = Gtk.CssProvider()
    try:
        provider.load_from_path(STYLE)
    except GLib.Error as error:
        print(f"wallpaper-picker: could not load {STYLE}: {error}", file=sys.stderr)
        return
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )


def main():
    folder = wallpaper_folder()
    paths = wallpapers(folder)
    if not paths:
        sys.exit(f"wallpaper-picker: no images in {folder}")

    load_style()
    window = Picker(paths)
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
