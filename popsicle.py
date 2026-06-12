#!/usr/bin/env python3
"""popsicle — Wayland keystroke overlay (bubbly alternative)"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, GLib, GtkLayerShell, Pango, PangoCairo, Gdk

import evdev
from evdev import ecodes, InputDevice
import threading
import select
import signal
import sys
import math
import cairo
import argparse
import logging
import os

# When launched without a terminal (e.g. from .desktop), log to file
LOG_FILE = os.path.expanduser("~/.local/share/popsicle.log")
if not sys.stderr.isatty():
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    _log = open(LOG_FILE, "w", buffering=1)
    sys.stdout = _log
    sys.stderr = _log

# ── Layout ────────────────────────────────────────────────────────────────────
WINDOW_W       = 700      # px — width of the overlay area
WINDOW_H       = 320      # px — height of the overlay area
BUBBLE_LEFT    = 14       # left margin for bubbles
MAX_TEXT_W     = 560      # max text width before wrapping
PAD_X          = 20       # horizontal text padding inside bubble
PAD_Y          = 14       # vertical text padding inside bubble
BUBBLE_GAP     = 10       # px between bubbles
BUBBLE_RADIUS  = 16       # corner radius (not a full pill)
FONT           = "sans 14"
STOP_BTN_R     = 14       # radius of the stop button circle
STOP_BTN_CX    = WINDOW_W - STOP_BTN_R - 8
STOP_BTN_CY    = WINDOW_H - STOP_BTN_R - 8

# ── Timing ────────────────────────────────────────────────────────────────────
BUBBLE_LIFETIME = 2500    # ms before fade begins
FADE_STEPS      = 15
FADE_INTERVAL   = 33      # ms per step  (~500 ms total)
GROUP_TIMEOUT   = 2000    # ms to group consecutive chars (longer = more sentence-like)
MAX_BUBBLES     = 5

# ── Colours (r,g,b,a) ─────────────────────────────────────────────────────────
BG_NORMAL  = (0.93, 0.96, 1.00, 0.90)   # light blue-white
BG_COMBO   = (0.88, 0.91, 1.00, 0.93)   # slightly deeper for combos
FG_NORMAL  = (0.13, 0.13, 0.18, 1.00)   # near-black text
FG_COMBO   = (0.25, 0.10, 0.55, 1.00)   # purple for combos

# ── Key tables ────────────────────────────────────────────────────────────────
MODIFIER_KEYS = {
    ecodes.KEY_LEFTSHIFT,  ecodes.KEY_RIGHTSHIFT,
    ecodes.KEY_LEFTCTRL,   ecodes.KEY_RIGHTCTRL,
    ecodes.KEY_LEFTALT,    ecodes.KEY_RIGHTALT,
    ecodes.KEY_LEFTMETA,   ecodes.KEY_RIGHTMETA,
}

SPECIAL_KEY_NAMES = {
    ecodes.KEY_TAB:       '⇥',
    ecodes.KEY_ESC:       'Esc',
    ecodes.KEY_CAPSLOCK:  'Caps',
    ecodes.KEY_UP:        '↑',
    ecodes.KEY_DOWN:      '↓',
    ecodes.KEY_LEFT:      '←',
    ecodes.KEY_RIGHT:     '→',
    ecodes.KEY_DELETE:    'Del',
    ecodes.KEY_HOME:      'Home',
    ecodes.KEY_END:       'End',
    ecodes.KEY_PAGEUP:    'PgUp',
    ecodes.KEY_PAGEDOWN:  'PgDn',
    ecodes.KEY_INSERT:    'Ins',
    ecodes.KEY_PAUSE:     'Pause',
    **{getattr(ecodes, f'KEY_F{i}'): f'F{i}' for i in range(1, 13)},
}

CHAR_MAP = {
    ecodes.KEY_SPACE: (' ', ' '),
    ecodes.KEY_1: ('1', '!'),    ecodes.KEY_2: ('2', '@'),
    ecodes.KEY_3: ('3', '#'),    ecodes.KEY_4: ('4', '$'),
    ecodes.KEY_5: ('5', '%'),    ecodes.KEY_6: ('6', '^'),
    ecodes.KEY_7: ('7', '&'),    ecodes.KEY_8: ('8', '*'),
    ecodes.KEY_9: ('9', '('),    ecodes.KEY_0: ('0', ')'),
    ecodes.KEY_MINUS:      ('-', '_'),
    ecodes.KEY_EQUAL:      ('=', '+'),
    ecodes.KEY_LEFTBRACE:  ('[', '{'),
    ecodes.KEY_RIGHTBRACE: (']', '}'),
    ecodes.KEY_BACKSLASH:  ('\\', '|'),
    ecodes.KEY_SEMICOLON:  (';', ':'),
    ecodes.KEY_APOSTROPHE: ("'", '"'),
    ecodes.KEY_GRAVE:      ('`', '~'),
    ecodes.KEY_COMMA:      (',', '<'),
    ecodes.KEY_DOT:        ('.', '>'),
    ecodes.KEY_SLASH:      ('/', '?'),
}


def key_to_char(keycode, shift):
    if keycode in SPECIAL_KEY_NAMES:
        return SPECIAL_KEY_NAMES[keycode]
    if keycode in CHAR_MAP:
        return CHAR_MAP[keycode][1 if shift else 0]
    name = ecodes.bytype[ecodes.EV_KEY].get(keycode, '')
    if isinstance(name, list):
        name = name[0]
    if name.startswith('KEY_') and len(name) == 5 and name[4].isalpha():
        return name[4] if shift else name[4].lower()
    return None


def find_keyboards():
    devices = []
    for path in evdev.list_devices():
        try:
            dev = InputDevice(path)
            caps = dev.capabilities()
            keys = caps.get(ecodes.EV_KEY, [])
            if ecodes.KEY_A in keys and ecodes.KEY_SPACE in keys:
                devices.append(dev)
        except (PermissionError, OSError):
            pass
    return devices


def text_pixel_size(text):
    """Return (width, height) in pixels for text rendered in FONT (with wrapping)."""
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1)
    cr   = cairo.Context(surf)
    lay  = PangoCairo.create_layout(cr)
    lay.set_text(text, -1)
    lay.set_font_description(Pango.FontDescription(FONT))
    lay.set_width(MAX_TEXT_W * Pango.SCALE)
    lay.set_wrap(Pango.WrapMode.WORD_CHAR)
    return lay.get_pixel_size()


class PopsicleApp:
    def __init__(self, anchor="left", margin=40):
        self.modifiers      = set()
        self.group_text     = ""
        self.group_entry    = None
        self.group_timer    = None
        self.bubbles        = []   # list of dicts: {text, opacity, is_combo, timer, fade_timer}
        self.cursor_active  = False

        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        h_edge = GtkLayerShell.Edge.LEFT if anchor == "left" else GtkLayerShell.Edge.RIGHT
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self.window, h_edge,                    True)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.BOTTOM, margin)
        GtkLayerShell.set_margin(self.window, h_edge,                    margin)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(self.window, -1)

        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.window.set_visual(visual)
        self.window.set_app_paintable(True)

        self.window.set_size_request(WINDOW_W, WINDOW_H)
        self.window.connect('destroy', Gtk.main_quit)
        self.window.connect('draw', self._on_draw)
        self.window.show_all()

        self.window.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.window.connect('button-press-event', self._on_button_press)

        self.window.realize()
        self._update_input_shape()

    # ── Drawing ───────────────────────────────────────────────────────────────

    def _on_draw(self, widget, cr):
        # Transparent background
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        self._draw_stop_button(cr)

        # Draw bubbles stacked from the bottom, right-aligned
        y = WINDOW_H
        for bubble in reversed(self.bubbles):
            if bubble['opacity'] <= 0:
                continue
            bh = self._draw_bubble(cr, bubble, y)
            y -= bh + BUBBLE_GAP

        return False

    def _update_input_shape(self):
        """Only the stop button area receives mouse events; everything else is click-through."""
        r = STOP_BTN_R
        rect = cairo.RectangleInt(int(STOP_BTN_CX - r), int(STOP_BTN_CY - r), r * 2, r * 2)
        self.window.input_shape_combine_region(cairo.Region(rect))

    def _draw_stop_button(self, cr):
        cx, cy, r = STOP_BTN_CX, STOP_BTN_CY, STOP_BTN_R
        cr.new_path()
        cr.arc(cx, cy, r, 0, 2 * math.pi)
        cr.set_source_rgba(0.15, 0.15, 0.20, 0.65)
        cr.fill()
        cr.new_path()
        cr.select_font_face("sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(14)
        ext = cr.text_extents("×")
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.80)
        cr.move_to(cx - ext.width / 2 - ext.x_bearing,
                   cy - ext.height / 2 - ext.y_bearing)
        cr.show_text("×")

    def _on_button_press(self, widget, event):
        dx = event.x - STOP_BTN_CX
        dy = event.y - STOP_BTN_CY
        if dx * dx + dy * dy <= STOP_BTN_R * STOP_BTN_R:
            Gtk.main_quit()
        return True

    def _draw_bubble(self, cr, bubble, bottom_y):
        """Draw one bubble with its bottom edge at bottom_y. Returns bubble height."""
        text     = bubble['text']
        is_combo = bubble['is_combo']
        opacity  = bubble['opacity']

        display = text
        if bubble is self.group_entry and self.cursor_active:
            display = text + '_'

        lay = PangoCairo.create_layout(cr)
        lay.set_text(display, -1)
        lay.set_font_description(Pango.FontDescription(FONT))
        lay.set_width(MAX_TEXT_W * Pango.SCALE)
        lay.set_wrap(Pango.WrapMode.WORD_CHAR)
        pw, ph = lay.get_pixel_size()

        bw = pw + PAD_X * 2
        bh = ph + PAD_Y * 2
        r  = min(BUBBLE_RADIUS, bh / 2)

        x = BUBBLE_LEFT
        y = bottom_y - bh

        br, bg_g, bb, ba = BG_COMBO if is_combo else BG_NORMAL
        fr, fg_g, fb, fa = FG_COMBO if is_combo else FG_NORMAL

        # Rounded rectangle background
        cr.new_path()
        cr.set_source_rgba(br, bg_g, bb, ba * opacity)
        cr.arc(x + r,      y + r,      r, math.pi,        1.5 * math.pi)
        cr.arc(x + bw - r, y + r,      r, 1.5 * math.pi,  0)
        cr.arc(x + bw - r, y + bh - r, r, 0,              0.5 * math.pi)
        cr.arc(x + r,      y + bh - r, r, 0.5 * math.pi,  math.pi)
        cr.close_path()
        cr.fill()

        # Text
        cr.new_path()
        cr.set_source_rgba(fr, fg_g, fb, fa * opacity)
        cr.move_to(x + PAD_X, y + PAD_Y)
        PangoCairo.show_layout(cr, lay)

        return bh

    # ── Cursor ────────────────────────────────────────────────────────────────

    def _show_cursor(self):
        self.cursor_active = True
        self.window.queue_draw()

    def _hide_cursor(self):
        self.cursor_active = False
        self.window.queue_draw()

    # ── Bubble lifecycle ──────────────────────────────────────────────────────

    def _add_bubble(self, text, is_combo=False):
        if len(self.bubbles) >= MAX_BUBBLES:
            old = self.bubbles.pop(0)
            self._cancel_timers(old)

        entry = {
            'text':       text,
            'is_combo':   is_combo,
            'opacity':    1.0,
            'timer':      None,
            'fade_timer': None,
        }
        entry['timer'] = GLib.timeout_add(BUBBLE_LIFETIME, self._start_fade, entry)
        self.bubbles.append(entry)
        self.window.queue_draw()
        return entry

    def _cancel_timers(self, entry):
        if entry['timer']:
            GLib.source_remove(entry['timer'])
            entry['timer'] = None
        if entry['fade_timer']:
            GLib.source_remove(entry['fade_timer'])
            entry['fade_timer'] = None

    def _start_fade(self, entry):
        entry['timer']      = None
        entry['fade_timer'] = GLib.timeout_add(FADE_INTERVAL, self._fade_step, entry)
        return GLib.SOURCE_REMOVE

    def _fade_step(self, entry):
        entry['opacity'] -= 1.0 / FADE_STEPS
        if entry['opacity'] <= 0:
            entry['fade_timer'] = None
            if entry in self.bubbles:
                self.bubbles.remove(entry)
        self.window.queue_draw()
        return GLib.SOURCE_CONTINUE if entry['opacity'] > 0 else GLib.SOURCE_REMOVE

    def _reset_group_lifetime(self, entry):
        self._cancel_timers(entry)
        entry['opacity'] = 1.0
        entry['timer']   = GLib.timeout_add(BUBBLE_LIFETIME, self._start_fade, entry)

    def _cancel_group_timer(self):
        if self.group_timer:
            GLib.source_remove(self.group_timer)
            self.group_timer = None

    def _flush_group(self):
        self.group_text  = ""
        self.group_entry = None
        self.group_timer = None
        self._hide_cursor()
        return GLib.SOURCE_REMOVE

    # ── Key dispatch ──────────────────────────────────────────────────────────

    def dispatch_key(self, keycode, keystate):
        if keystate == 2:
            return GLib.SOURCE_REMOVE

        if keycode in MODIFIER_KEYS:
            if keystate == 1:
                self.modifiers.add(keycode)
            else:
                self.modifiers.discard(keycode)
            return GLib.SOURCE_REMOVE

        if keystate != 1:
            return GLib.SOURCE_REMOVE

        shift = bool(self.modifiers & {ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT})
        ctrl  = bool(self.modifiers & {ecodes.KEY_LEFTCTRL,  ecodes.KEY_RIGHTCTRL})
        alt   = bool(self.modifiers & {ecodes.KEY_LEFTALT,   ecodes.KEY_RIGHTALT})
        meta  = bool(self.modifiers & {ecodes.KEY_LEFTMETA,  ecodes.KEY_RIGHTMETA})
        char  = key_to_char(keycode, shift)

        if ctrl or alt or meta:
            self._cancel_group_timer()
            self._flush_group()
            parts = []
            if ctrl:  parts.append('Ctrl')
            if alt:   parts.append('Alt')
            if meta:  parts.append('Super')
            if shift: parts.append('Shift')
            if char:  parts.append(char)
            if parts:
                self._add_bubble('+'.join(parts), is_combo=True)

        elif keycode == ecodes.KEY_BACKSPACE:
            self._cancel_group_timer()
            if self.group_entry and self.group_text:
                self.group_text = self.group_text[:-1]
                if self.group_text:
                    self.group_entry['text'] = self.group_text
                    self._reset_group_lifetime(self.group_entry)
                    self._show_cursor()
                    self.group_timer = GLib.timeout_add(GROUP_TIMEOUT, self._flush_group)
                else:
                    self._cancel_timers(self.group_entry)
                    if self.group_entry in self.bubbles:
                        self.bubbles.remove(self.group_entry)
                    self._flush_group()  # also stops cursor

        elif keycode == ecodes.KEY_ENTER:
            # Finalize current bubble silently; next keypress starts a new one
            self._cancel_group_timer()
            self._flush_group()

        elif keycode in SPECIAL_KEY_NAMES:
            self._cancel_group_timer()
            self._flush_group()
            if char:
                self._add_bubble(char)

        elif char:
            self._cancel_group_timer()
            if self.group_entry:
                self.group_text += char
                self.group_entry['text'] = self.group_text
                self._reset_group_lifetime(self.group_entry)
            else:
                self.group_text  = char
                self.group_entry = self._add_bubble(char)
            self._show_cursor()
            self.group_timer = GLib.timeout_add(GROUP_TIMEOUT, self._flush_group)

        return GLib.SOURCE_REMOVE

    # ── Input loop ────────────────────────────────────────────────────────────

    def run_input_loop(self, devices):
        fds = {dev.fd: dev for dev in devices}
        while fds:
            try:
                readable, _, _ = select.select(list(fds.keys()), [], [], 1.0)
                for fd in readable:
                    dev = fds[fd]
                    try:
                        for event in dev.read():
                            if event.type == ecodes.EV_KEY:
                                GLib.idle_add(self.dispatch_key, event.code, event.value)
                    except OSError:
                        fds.pop(fd, None)
            except Exception:
                break


def parse_args():
    p = argparse.ArgumentParser(
        description="popsicle — Wayland keystroke overlay",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("--font",     default=FONT,            metavar="FONT",
                   help='Pango font string, e.g. "sans 14" or "Inter Bold 16"')
    p.add_argument("--anchor",   default="left",          choices=["left", "right"],
                   help="which side of the screen to anchor to")
    p.add_argument("--lifetime", default=BUBBLE_LIFETIME, type=int, metavar="MS",
                   help="ms a bubble stays visible before fading")
    p.add_argument("--opacity",  default=0.90,            type=float, metavar="0-1",
                   help="bubble background opacity")
    p.add_argument("--margin",        default=40,              type=int, metavar="PX",
                   help="px gap from screen edge")
    p.add_argument("--group-timeout", default=GROUP_TIMEOUT,  type=int, metavar="MS",
                   help="ms of inactivity before a new bubble starts")
    return p.parse_args()


def apply_args(args):
    global FONT, BUBBLE_LIFETIME, GROUP_TIMEOUT, BG_NORMAL, BG_COMBO
    FONT            = args.font
    BUBBLE_LIFETIME = args.lifetime
    GROUP_TIMEOUT   = args.group_timeout
    # Re-apply opacity to background colours
    r, g, b, _ = BG_NORMAL
    BG_NORMAL = (r, g, b, args.opacity)
    r, g, b, _ = BG_COMBO
    BG_COMBO  = (r, g, b, min(1.0, args.opacity + 0.03))


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    args = parse_args()
    apply_args(args)

    devices = find_keyboards()
    if not devices:
        print("popsicle: no keyboard devices found.", file=sys.stderr)
        print("  Make sure you're in the 'input' group:", file=sys.stderr)
        print("    sudo usermod -aG input $USER  (then re-login)", file=sys.stderr)
        print("  Or activate it in this shell: newgrp input", file=sys.stderr)
        sys.exit(1)

    print(f"popsicle: watching {len(devices)} device(s):")
    for dev in devices:
        print(f"  {dev.path}  {dev.name}")

    app = PopsicleApp(anchor=args.anchor, margin=args.margin)

    t = threading.Thread(target=app.run_input_loop, args=(devices,), daemon=True)
    t.start()

    Gtk.main()


if __name__ == '__main__':
    main()
