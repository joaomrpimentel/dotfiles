# My Dotfiles

![Showcase of the dotfiles](assets/screen.png)

Personal Arch + Hyprland setup. Monochrome and translucent: dark glass surfaces,
white-on-gray monospace, no accent color anywhere except one red for things that
are actually wrong. See [`.config/PALETTE.md`](.config/PALETTE.md) for the exact
values and the one deliberate exception (the terminal keeps hued ANSI colors, or
`git diff` becomes unreadable).

## Structure

- `.config/` — configuration directories for each application.
- `.config/PALETTE.md` — the color contract every config follows.
- `install.sh` — symlinks everything into place (backing up what's there) and
  optionally installs the packages.

## Included configurations

- **Hyprland** — compositor, configured in Lua (`hypr/hyprland.lua`), 1px
  borders, blur, spring animations.
- **Quickshell** — everything on screen that isn't a window, in
  `quickshell/`: the bar (three translucent pills), and every menu growing out
  of the pill it belongs to — calendar, launcher (apps, calculator, commands,
  clipboard), wallpaper picker, control center, power menu, weather satellite,
  volume OSD — plus notification toasts and the workspace dots.
- **Kitty** — terminal, translucent, desaturated ANSI palette.
- **Neovim** — LazyVim-ish setup on the `zenwritten` grayscale colorscheme.
- **Zsh + Starship** — zinit plugins, monochrome fzf, two-line minimal prompt.
- **Zathura** — monochrome chrome plus recolored (dark-mode) pages.
- **Waypaper / awww** — wallpaper.
- **Toolkit themes** — this is what stops third-party apps from being the odd
  one out.

Not managed here, and still on their own palettes: btop (set to the stock
`greyscale` theme in `~/.config/btop/btop.conf`, which this repo doesn't own),
mpv, vlc, obs and the browsers.

## Keybinds worth remembering

| Keys | Action |
| --- | --- |
| `SUPER` (tap) | launcher (`=` calc, `>` run, `:` clipboard) |
| `SUPER + T` / `B` / `E` | terminal / browser / files |
| `SUPER + N` | control center + notifications |
| `SUPER + V` | clipboard history |
| `SUPER + W` | wallpaper picker |
| `SUPER + P` | cycle bar mode: normal → por baixo → oculta |
| `SUPER + L` | lock |
| `SUPER + Q` / `F` | close / fullscreen |
| `SUPER + ALT + F` | toggle float |
| `SUPER + SHIFT + S` | screenshot to clipboard |
| `SUPER + SHIFT + R` | 2560x1080 ↔ 1920x1080 (recording) |
| `SUPER + 1..0` | workspace (pops the dots) |
| `SUPER + SHIFT/ALT + 1..0` | move window there (with / without following) |
| `CTRL + ALT + DEL` | power menu |

## Installation

```bash
chmod +x install.sh
./install.sh
```

It backs up anything already at the target path as `<name>.backup_<timestamp>`
before linking.
