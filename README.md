# popsicle

A Wayland-native keystroke overlay that displays your keypresses as chat bubbles — a [bubbly](https://github.com/siduck/bubbly) alternative for Wayland.

Built with Python, evdev, GTK3 layer shell, and Cairo.

![demo](https://github.com/crisecheverria/popsicle/assets/demo.gif)

## Features

- **Chat-bubble display** anchored to the bottom of the screen
- **Sentence grouping** — characters accumulate in one bubble as you type; a new bubble starts after a pause
- **Space & backspace** work naturally inside the active bubble
- **Blinking cursor** (`_`) while a bubble is being typed
- **Enter** finalizes the current bubble silently
- **Modifier combos** (`Ctrl+C`, `Super+L`, `Alt+F4`, etc.) shown in a distinct colour
- **Special keys** (arrows, F-keys, Tab, Esc, etc.) get their own small bubble
- **Bubbles fade out** automatically after a configurable lifetime
- **Click-through overlay** — never blocks clicks on your apps
- **Stop button** — small `×` in the corner to quit without a terminal
- **Configurable** via command-line flags
- **Desktop file** included for launching from your app menu (Walker, Rofi, etc.)
- **Logs to file** (`~/.local/share/popsicle.log`) when launched without a terminal

## Requirements

- Wayland compositor with `wlr-layer-shell` support (Hyprland, Sway, river, etc.)
- `python-gobject`
- `gtk-layer-shell` + GObject introspection bindings
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

Click the small `×` button in the bottom-right corner of the overlay to stop it.

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--font FONT` | `sans 14` | Pango font string |
| `--anchor {left,right}` | `left` | Screen side to anchor to |
| `--lifetime MS` | `2500` | ms a bubble stays visible before fading |
| `--opacity 0-1` | `0.9` | Bubble background opacity |
| `--margin PX` | `40` | Gap from screen edge in px |
| `--group-timeout MS` | `2000` | ms of inactivity before the next keypress starts a new bubble |

Examples:

```bash
python popsicle.py --anchor right --font "Inter 16" --opacity 0.85
python popsicle.py --lifetime 3500 --group-timeout 3000 --margin 60
```

## App menu / desktop launcher

Copy the included `.desktop` file to your applications directory:

```bash
cp popsicle.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
```

You can then launch popsicle from your app menu (Walker, Rofi, etc.).

## How it works

- **Input** — reads raw keyboard events from `/dev/input/event*` using `evdev` in a background thread; key events are posted to the GTK main loop via `GLib.idle_add` for thread-safe UI updates
- **Display** — a transparent `wlr-layer-shell` overlay window rendered entirely with Cairo + Pango; no GTK child widgets (GTK3 layout gives them 1×1 allocations in this setup)
- **Click-through** — `input_shape_combine_region` limits mouse input to only the stop button area; everything else passes through to the windows below
