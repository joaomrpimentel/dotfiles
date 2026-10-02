-- Hyprland config (Lua). Replaces hyprland.conf, which Hyprland 0.56 treats as
-- legacy: it loads hyprland.lua when present and only falls back to the .conf
-- otherwise.
--
-- Everything on screen that is not a window — bar, menus, launcher,
-- notifications, OSD, workspace dots, wallpaper picker — is one Quickshell
-- process (../quickshell). This file only starts it and binds keys to its IPC:
--
--     qs ipc call shell toggle <launcher|clipboard|wallpaper|center|power|calendar>
--
-- Lua callbacks run on the compositor's event loop, so nothing in a bind may
-- block. Anything that waits on the outside world goes through exec_cmd.

local mainMod  = "SUPER"
local terminal = "kitty"
local browser  = "vivaldi-stable"

local function qs(menu)
    return hl.dsp.exec_cmd("qs ipc call shell toggle " .. menu)
end


-------------------
---- VARIABLES ----
-------------------

-- Cedilla: with the us/alt-intl layout, ' + c has to come out as ç, which only
-- the xim cedilla module does. GTK and Qt both need to be pointed at it.
hl.env("XMODIFIERS", "@im=cedilla")
hl.env("GTK_IM_MODULE", "xim")
hl.env("QT_IM_MODULE", "xim")

hl.env("GTK_THEME", "Adwaita:dark")
hl.env("XDG_MENU_PREFIX", "arch-")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- communicates theme to Qt apps


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- xdg-desktop-portal and libadwaita apps read gsettings, not settings.ini
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10'")

    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- The whole shell. Also the notification daemon, so it has to be up before
    -- anything below starts sending notifications.
    hl.exec_cmd("qs")

    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("waypaper --restore") -- restores wallpaper from waypaper's config
end)


--------------------
---- MONITORS ------
--------------------

local MONITOR     = "HDMI-A-1"
local NATIVE_MODE = "2560x1080@74.99800"
local RECORD_MODE = "1920x1080@74.99000"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Monochrome palette (see .config/PALETTE.md)
local mono = {
    fg      = "rgba(ffffffff)",
    dim     = "rgba(a2a2a2ff)",
    border  = "rgba(ffffff33)",
    border0 = "rgba(ffffff0d)",
    urgent  = "rgba(ff5555ff)",
}

hl.config({
    general = {
        gaps_in          = 4,
        gaps_out         = 8,
        border_size      = 1,
        col = {
            active_border   = mono.border,
            inactive_border = mono.border0,
        },
        resize_on_border = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding = 10,
        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            color        = "rgba(00000066)",
        },

        -- Glass. The shell draws the specular edge (quickshell/Glass.qml); this
        -- draws the material behind it. (The hyprglass plugin used to add real
        -- refraction on top. It stopped loading at 0.56 — hyprpm is gone and
        -- the cached build targets 0.55 — and was dropped. To bring it back,
        -- rebuild it and set it under hl.config({ plugin = { hyprglass = ... } })
        -- inside an `if hl.plugin.hyprglass then` guard.) Both halves are needed — a bright rim
        -- over a thin blur reads as a sticker, and a deep blur with no rim
        -- reads as fog.
        blur = {
            enabled = true,
            -- Down from size 8 / passes 4, which was where the pills grew a
            -- blur halo escaping past their rounded edges. Hyprland's blur runs
            -- as a downsample/upsample chain, so passes is a power of two on
            -- the sampling radius: 8 * 2^4 is a ~128px kernel against a 28px
            -- pill, and the alpha mask that is supposed to clip it is only
            -- evaluated at the downscaled resolution. The mask cannot follow a
            -- 14px corner radius at 1/16 scale, so the blur leaks outward.
            --
            -- Cost: this block is global, so kitty's backdrop gets the same
            -- lighter blur. brightness below carries most of kitty's weight.
            size   = 4,
            passes = 2,
            -- The panels sit at ~0.28-0.42 alpha to let this through, so the
            -- noise has to stay low or it reads as grain on the text.
            noise    = 0.006,
            contrast = 1.05,
            -- Vibrancy keeps the wallpaper's colour alive through the blur,
            -- which otherwise averages out to grey. Darkness holds the panel
            -- down so white text keeps its contrast over a bright wallpaper.
            vibrancy          = 0.32,
            vibrancy_darkness = 0.28,
            -- Compensates for kitty's backdrop sitting under its own 0.75
            -- alpha over a near-black #0c0c0c, which is what actually reads as
            -- "not translucent enough".
            brightness = 1.35,
            -- Tray menus are popups of the bar's layer surface.
            popups = true,
        },
    },

    animations = { enabled = true },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },

    input = {
        kb_layout          = "us",
        kb_variant         = "alt-intl",
        numlock_by_default = true,
        follow_mouse       = 1,
        touchpad = { natural_scroll = false },
    },
})


--------------------
---- ANIMATIONS ----
--------------------

-- Springs, not beziers, for anything that moves: a spring keeps its velocity
-- when it is interrupted, so a window retargeted mid-flight bends toward the new
-- spot instead of restarting. That is the same motion the shell's panels use
-- (quickshell/Theme.qml), so windows and menus feel like one system.
--
-- dampening is the raw coefficient c, not the ratio (the wiki calls it
-- `damping`; 0.56 only accepts `dampening`). The ratio is
-- zeta = c / (2 * sqrt(stiffness * mass)); below 1 it overshoots.
--   settle  zeta ~0.85  moves and resizes; lands without a visible bounce
--   pop     zeta ~0.62  window open; one soft overshoot, like the menus
hl.curve("settle", { type = "spring", mass = 1, stiffness = 260, dampening = 27.4 })
hl.curve("pop",    { type = "spring", mass = 1, stiffness = 220, dampening = 18.4 })

-- Closing gets a plain curve on purpose: dismissal should be quick and must not
-- wobble, the same rule the shell's menus follow.
hl.curve("out",   { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })

hl.animation({ leaf = "windows",       enabled = true, speed = 4.5, spring = "settle" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.0, spring = "pop",    style = "popin 88%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.6, bezier = "out",    style = "popin 92%" })
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "default" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "quick" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4.5, spring = "settle", style = "slide" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3,   spring = "settle", style = "slide" })


---------------------
---- LAYER RULES ----
---------------------

-- The shell animates its own surfaces — pills stretching into panels, toasts
-- dropping out of the bar. A compositor slide on top of that would move the
-- whole 2560px surface at once and fight the motion inside it.
--
-- Blur: the surfaces are mostly transparent, and ignore_alpha keeps the blur to
-- the glass shapes (tint alpha >= 0.28). The empty space around them is 0.
hl.layer_rule({
    name         = "shell",
    match        = { namespace = "^quickshell" },
    blur         = true,
    ignore_alpha = 0.2,
    no_anim      = true,
})


----------------------
---- WINDOW RULES ----
----------------------

-- Reading tier, 0.75 (see PALETTE.md). Zathura ignores alpha on the recolored
-- page, so per-colour rgba in zathurarc leaves the page solid while the frame
-- goes glass. Fading the whole window is the only way it matches kitty.
hl.window_rule({
    name    = "zathura-glass",
    match   = { class = "org.pwmt.zathura" },
    opacity = "0.75 0.75",
})


------------------
---- KEYBINDS ----
------------------

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Shell. SUPER alone opens the launcher on release, so SUPER held for any other
-- combo doesn't flash it.
-- The modifier has to be in the combo: on release SUPER is still held as a
-- modifier, so a bare "Super_L" (modmask 0) never matches. Same as the old
-- `bindr = SUPER, SUPER_L`.
hl.bind(mainMod .. " + Super_L", qs("launcher"), { release = true })
hl.bind(mainMod .. " + V", qs("clipboard"))
hl.bind(mainMod .. " + W", qs("wallpaper"))
hl.bind(mainMod .. " + N", qs("center"))
hl.bind("CTRL + ALT + Delete", qs("power"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call shell cycleBarMode")) -- normal -> por baixo -> oculta

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Float and park at 50% x 60%, centred. Was scripts/toggle_float.sh, which had
-- to sleep and re-query hyprctl to learn the new state; here it is synchronous.
hl.bind(mainMod .. " + ALT + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local win = hl.get_active_window()
    local mon = hl.get_active_monitor()
    if win and win.floating and mon then
        hl.dispatch(hl.dsp.window.resize({ x = math.floor(mon.width * 0.5), y = math.floor(mon.height * 0.6) }))
        hl.dispatch(hl.dsp.window.center())
    end
end)

-- Resize with the keyboard (mainly for floating windows)
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshot to clipboard
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))

-- Native ultrawide <-> 1920x1080 for recording. Was scripts/toggle_resolution.sh.
hl.bind(mainMod .. " + SHIFT + R", function()
    local mon = hl.get_monitor(MONITOR)
    if not mon then
        return
    end
    local native = mon.width == 2560
    hl.monitor({ output = MONITOR, mode = native and RECORD_MODE or NATIVE_MODE, position = "0x0", scale = 1 })
    hl.exec_cmd(native and "notify-send -t 2000 Display 'Modo gravação: 1920x1080'"
                        or "notify-send -t 2000 Display 'Modo nativo: 2560x1080'")
end)

-- Workspaces 1-10:
--   SUPER + n          go there
--   SUPER + SHIFT + n  take the window along
--   SUPER + ALT + n    send the window, stay here
for i = 1, 10 do
    local key = tostring(i % 10) -- 10 is the 0 key
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i, follow = true }))
    hl.bind(mainMod .. " + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Volume. The shell watches PipeWire and shows its own OSD on any change, so
-- these only need to change the volume.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

-- Media keys (the shell's now-playing pill follows along)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
