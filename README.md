# popsicle

A Wayland-native keystroke overlay that displays your keypresses as chat bubbles — a [bubbly](https://github.com/siduck/bubbly) alternative for Wayland.

Built with Zig, GTK3 layer shell, and Cairo.

![demo](https://github.com/crisecheverria/popsicle/assets/demo.gif)

## Features

- **Chat-bubble display** anchored to the bottom of the screen
- **Sentence grouping** — characters accumulate in one bubble as you type; a new bubble starts after a pause
- **Space & backspace** work naturally inside the active bubble
- **Cursor** (`_`) shown while a bubble is being typed
- **Enter** finalizes the current bubble silently
- **Modifier combos** (`Ctrl+C`, `Super+L`, `Alt+F4`, etc.) shown in a distinct colour
- **Special keys** (arrows, F-keys, Tab, Esc, etc.) get their own small bubble
- **Bubbles fade out** automatically after a configurable lifetime
- **Click-through overlay** — never blocks clicks on your apps
- **Stop button** — small `×` in the corner to quit without a terminal
- **Desktop file** included for launching from your app menu (Walker, Rofi, etc.)

## Requirements

- Wayland compositor with `wlr-layer-shell` support (Hyprland, Sway, river, etc.)
- `gtk-layer-shell`
- `gtk3`
- `pango` + `cairo`

On Arch Linux:

```bash
sudo pacman -S gtk-layer-shell gtk3 pango cairo
```

## Build

Requires [Zig](https://ziglang.org/) 0.17.0-dev or later.

```bash
zig build
```

The binary is produced at `zig-out/bin/popsicle`.

## Setup

popsicle reads directly from `/dev/input/event*`, so your user needs to be in the `input` group:

```bash
sudo usermod -aG input $USER
```

Log out and back in (or run `newgrp input` in the current shell) for the change to take effect.

## Usage

```bash
./zig-out/bin/popsicle
```

Click the small `×` button in the bottom-right corner of the overlay to stop it.

## App menu / desktop launcher

Copy the included `.desktop` file to your applications directory:

```bash
cp popsicle.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/
```

You can then launch popsicle from your app menu (Walker, Rofi, etc.).

## How it works

- **Input** — reads raw kernel input events from `/dev/input/event*` in a background thread; key events are posted to the GTK main loop via `g_idle_add` for thread-safe UI updates
- **Display** — a transparent `wlr-layer-shell` overlay window rendered entirely with Cairo + Pango; no GTK child widgets (GTK3 layout gives them 1×1 allocations in this setup)
- **Click-through** — `input_shape_combine_region` limits mouse input to only the stop button area; everything else passes through to the windows below
- **Architecture** — all app logic (bubble state, key dispatch, input thread) is in Zig (`src/main.zig`); GTK/Cairo/Pango calls go through a thin C wrapper (`src/popsicle_gtk.c`) to avoid header translation issues
