# popsicle

A Wayland-native keystroke overlay that displays your keypresses as chat bubbles — a [bubbly](https://github.com/siduck/bubbly) alternative for Wayland.

Built with Python, evdev, GTK3 layer shell, and Cairo.

## Features

- Chat-bubble style display anchored to the bottom of the screen
- Characters group into sentences as you type; space and backspace work naturally
- Blinking cursor while a bubble is active
- Modifier combos shown as `Ctrl+C`, `Super+L`, etc.
- Special keys (arrows, F-keys, Tab) get their own bubble
- Bubbles fade out automatically
- Click-through — never interferes with your apps
- Configurable via command-line flags

## Requirements

- Wayland compositor with `wlr-layer-shell` support (Hyprland, Sway, river, etc.)
- `python-gobject`
- `gtk-layer-shell` + Python GObject bindings
- `python-evdev`
- `python-cairo` (pycairo)

On Arch Linux:

```bash
sudo pacman -S python-gobject gtk-layer-shell python-evdev python-cairo
```

## Setup

popsicle reads directly from `/dev/input/event*`, so your user needs to be in the `input` group:

```bash
sudo usermod -aG input $USER
```

Log out and back in (or run `newgrp input` in the current shell) for the change to take effect.

## Usage

```bash
python popsicle.py
```

### Options

```
--font FONT           Pango font string (default: "sans 14")
--anchor {left,right} screen side to anchor to (default: left)
--lifetime MS         ms before a bubble fades (default: 2500)
--opacity 0-1         bubble background opacity (default: 0.9)
--margin PX           gap from screen edge in px (default: 40)
```

Examples:

```bash
python popsicle.py --anchor right --font "Inter 16" --opacity 0.85
python popsicle.py --lifetime 3500 --margin 60
```

## Autostart

Copy the included `.desktop` file to your applications directory:

```bash
cp popsicle.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
```

You can then launch it from your app menu, or add it to your compositor's autostart. For Hyprland, add to `~/.config/hypr/hyprland.conf`:

```
exec-once = python /path/to/popsicle/popsicle.py
```

## How it works

- **Input**: reads raw keyboard events from `/dev/input/event*` using `evdev` in a background thread
- **Display**: a transparent `wlr-layer-shell` overlay window rendered entirely with Cairo — no GTK child widgets, which avoids GTK3 layout sizing quirks
- **Threading**: key events are posted to the GTK main loop via `GLib.idle_add` for thread-safe UI updates
