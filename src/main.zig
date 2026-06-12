const std = @import("std");

// ── C wrapper extern declarations ─────────────────────────────────────────────
extern fn pg_gtk_init() void;
extern fn pg_gtk_main() void;
extern fn pg_gtk_main_quit() void;
extern fn pg_create_window(anchor_left: c_int, margin: c_int) *anyopaque;
extern fn pg_window_show(window: *anyopaque) void;
extern fn pg_window_realize(window: *anyopaque) void;
extern fn pg_set_input_shape(window: *anyopaque, x: c_int, y: c_int, w: c_int, h: c_int) void;
extern fn pg_queue_draw(window: *anyopaque) void;
extern fn pg_timeout_add(ms: c_uint, cb: *const fn (*anyopaque) callconv(std.builtin.CallingConvention.c) c_int, data: *anyopaque) c_uint;
extern fn pg_idle_add(cb: *const fn (*anyopaque) callconv(std.builtin.CallingConvention.c) c_int, data: *anyopaque) c_uint;
extern fn pg_source_remove(id: c_uint) void;
extern fn pg_connect_draw(window: *anyopaque, cb: *const fn (*anyopaque, *anyopaque, ?*anyopaque) callconv(std.builtin.CallingConvention.c) c_int) void;
extern fn pg_connect_button_press(window: *anyopaque, cb: *const fn (*anyopaque, *anyopaque, ?*anyopaque) callconv(std.builtin.CallingConvention.c) c_int) void;
extern fn pg_connect_destroy(window: *anyopaque, cb: *const fn (*anyopaque, ?*anyopaque) callconv(std.builtin.CallingConvention.c) void) void;
extern fn pg_event_coords(event: *anyopaque, x: *f64, y: *f64) void;
extern fn pg_draw_clear(cr: *anyopaque) void;
extern fn pg_draw_stop_button(cr: *anyopaque, cx: f64, cy: f64, r: f64) void;
extern fn pg_draw_bubble(
    cr: *anyopaque,
    text: [*]const u8, text_len: c_int,
    show_cursor: c_int,
    is_combo: c_int,
    opacity: f64,
    x: f64, y: f64,
    max_text_w: f64,
    pad_x: f64, pad_y: f64,
    bubble_radius: f64,
    out_bh: *f64,
) void;

// ── Layout constants ──────────────────────────────────────────────────────────
const WINDOW_W: f64    = 700;
const WINDOW_H: f64    = 320;
const BUBBLE_LEFT: f64 = 14;
const MAX_TEXT_W: f64  = 560;
const PAD_X: f64       = 20;
const PAD_Y: f64       = 14;
const BUBBLE_GAP: f64  = 10;
const BUBBLE_RADIUS: f64 = 16;
const STOP_BTN_R: f64  = 14;
const STOP_BTN_CX: f64 = WINDOW_W - STOP_BTN_R - 8;
const STOP_BTN_CY: f64 = WINDOW_H - STOP_BTN_R - 8;

// ── Timing ────────────────────────────────────────────────────────────────────
const BUBBLE_LIFETIME_MS: c_uint = 2500;
const FADE_STEPS: f64    = 15;
const FADE_INTERVAL_MS: c_uint = 33;
const GROUP_TIMEOUT_MS: c_uint = 2000;
const MAX_BUBBLES: usize = 5;

// ── Key codes ─────────────────────────────────────────────────────────────────
const KEY_LEFTSHIFT: u32  = 42;
const KEY_RIGHTSHIFT: u32 = 54;
const KEY_LEFTCTRL: u32   = 29;
const KEY_RIGHTCTRL: u32  = 97;
const KEY_LEFTALT: u32    = 56;
const KEY_RIGHTALT: u32   = 100;
const KEY_LEFTMETA: u32   = 125;
const KEY_RIGHTMETA: u32  = 126;
const KEY_BACKSPACE: u32  = 14;
const KEY_ENTER: u32      = 28;
const KEY_SPACE: u32      = 57;
const KEY_TAB: u32        = 15;
const KEY_ESC: u32        = 1;
const KEY_CAPSLOCK: u32   = 58;
const KEY_UP: u32         = 103;
const KEY_DOWN: u32       = 108;
const KEY_LEFT: u32       = 105;
const KEY_RIGHT: u32      = 106;
const KEY_DELETE: u32     = 111;
const KEY_HOME: u32       = 102;
const KEY_END: u32        = 107;
const KEY_PAGEUP: u32     = 104;
const KEY_PAGEDOWN: u32   = 109;
const KEY_INSERT: u32     = 110;
const KEY_PAUSE: u32      = 119;

// ── linux/input.h constants ───────────────────────────────────────────────────
const EV_KEY: u16    = 1;
const KEY_MAX: usize = 0x2ff;
const O_RDONLY: c_int   = 0;
const O_NONBLOCK: c_int = 2048;


const input_event = extern struct {
    sec: i64,
    usec: i64,
    type: u16,
    code: u16,
    value: i32,
};

extern fn open(path: [*:0]const u8, flags: c_int) c_int;
extern fn close(fd: c_int) c_int;
extern fn read(fd: c_int, buf: *anyopaque, count: usize) isize;
extern fn ioctl(fd: c_int, request: c_uint, ...) c_int;
extern fn opendir(path: [*:0]const u8) ?*anyopaque;
extern fn closedir(dir: *anyopaque) c_int;
extern fn readdir(dir: *anyopaque) ?*DirentC;

const DirentC = extern struct {
    d_ino: u64,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
    d_name: [256]u8,
};

// fd_set for select
const FdSet = extern struct {
    fds_bits: [1024 / 64]u64 = std.mem.zeroes([1024 / 64]u64),

    fn zero(self: *FdSet) void {
        @memset(&self.fds_bits, 0);
    }
    fn set(self: *FdSet, fd: c_int) void {
        const i: usize = @intCast(fd);
        self.fds_bits[i / 64] |= @as(u64, 1) << @intCast(i % 64);
    }
    fn isSet(self: *const FdSet, fd: c_int) bool {
        const i: usize = @intCast(fd);
        return (self.fds_bits[i / 64] >> @intCast(i % 64)) & 1 != 0;
    }
};

const Timeval = extern struct {
    tv_sec: i64,
    tv_usec: i64,
};

extern fn select(nfds: c_int, readfds: *FdSet, writefds: ?*FdSet, exceptfds: ?*FdSet, timeout: *Timeval) c_int;

const Timespec = extern struct { tv_sec: i64, tv_nsec: i64 };
extern fn nanosleep(req: *const Timespec, rem: ?*Timespec) c_int;

// ── Bubble ────────────────────────────────────────────────────────────────────
const MAX_BUBBLE_TEXT = 512;

const Bubble = struct {
    text: [MAX_BUBBLE_TEXT]u8,
    text_len: usize,
    is_combo: bool,
    opacity: f64,
    lifetime_source: c_uint,
    fade_source: c_uint,
    active: bool,

    fn init() Bubble {
        return .{
            .text = std.mem.zeroes([MAX_BUBBLE_TEXT]u8),
            .text_len = 0,
            .is_combo = false,
            .opacity = 1.0,
            .lifetime_source = 0,
            .fade_source = 0,
            .active = false,
        };
    }

    fn getText(self: *const Bubble) []const u8 {
        return self.text[0..self.text_len];
    }

    fn appendChar(self: *Bubble, ch: []const u8) void {
        const n = @min(ch.len, MAX_BUBBLE_TEXT - self.text_len);
        @memcpy(self.text[self.text_len..self.text_len + n], ch[0..n]);
        self.text_len += n;
    }

    fn removeLastCodepoint(self: *Bubble) void {
        if (self.text_len == 0) return;
        var i = self.text_len - 1;
        while (i > 0 and (self.text[i] & 0xC0) == 0x80) i -= 1;
        self.text_len = i;
    }
};

// ── App state (global, accessed by GTK callbacks) ─────────────────────────────
const App = struct {
    window: *anyopaque,
    bubbles: [MAX_BUBBLES]Bubble,
    bubble_count: usize,
    group_idx: i32,   // index into bubbles[], or -1
    group_timer: c_uint,
    cursor_active: bool,
    shift: bool,
    ctrl: bool,
    alt: bool,
    meta: bool,
    dev_fds: [32]c_int,
    dev_count: usize,
};

var app: App = undefined;

// ── Bubble management ─────────────────────────────────────────────────────────

fn addBubble(text: []const u8, is_combo: bool) usize {
    if (app.bubble_count >= MAX_BUBBLES) {
        // evict oldest
        const old = &app.bubbles[0];
        if (old.lifetime_source != 0) pg_source_remove(old.lifetime_source);
        if (old.fade_source != 0)     pg_source_remove(old.fade_source);
        var i: usize = 0;
        while (i < MAX_BUBBLES - 1) : (i += 1) {
            app.bubbles[i] = app.bubbles[i + 1];
        }
        app.bubbles[MAX_BUBBLES - 1] = Bubble.init();
        app.bubble_count = MAX_BUBBLES - 1;
        if (app.group_idx > 0) {
            app.group_idx -= 1;
        } else if (app.group_idx == 0) {
            app.group_idx = -1;
        }
    }

    const idx = app.bubble_count;
    app.bubble_count += 1;
    var b = &app.bubbles[idx];
    b.* = Bubble.init();
    b.active = true;
    b.is_combo = is_combo;
    b.opacity = 1.0;
    b.appendChar(text);
    b.lifetime_source = pg_timeout_add(BUBBLE_LIFETIME_MS, startFadeCb, b);
    pg_queue_draw(app.window);
    return idx;
}

fn removeBubble(idx: usize) void {
    const b = &app.bubbles[idx];
    if (b.lifetime_source != 0) pg_source_remove(b.lifetime_source);
    if (b.fade_source != 0)     pg_source_remove(b.fade_source);
    b.* = Bubble.init();
    var i = idx;
    while (i < app.bubble_count - 1) : (i += 1) {
        app.bubbles[i] = app.bubbles[i + 1];
    }
    app.bubbles[app.bubble_count - 1] = Bubble.init();
    app.bubble_count -= 1;
    const idxi = @as(i32, @intCast(idx));
    if (app.group_idx == idxi) {
        app.group_idx = -1;
    } else if (app.group_idx > idxi) {
        app.group_idx -= 1;
    }
}

fn resetBubbleLifetime(idx: usize) void {
    const b = &app.bubbles[idx];
    if (b.lifetime_source != 0) pg_source_remove(b.lifetime_source);
    if (b.fade_source != 0)     pg_source_remove(b.fade_source);
    b.opacity = 1.0;
    b.fade_source = 0;
    b.lifetime_source = pg_timeout_add(BUBBLE_LIFETIME_MS, startFadeCb, b);
}

fn cancelGroupTimer() void {
    if (app.group_timer != 0) {
        pg_source_remove(app.group_timer);
        app.group_timer = 0;
    }
}

fn flushGroup() void {
    app.group_idx = -1;
    app.group_timer = 0;
    app.cursor_active = false;
    pg_queue_draw(app.window);
}

// ── GLib callbacks ────────────────────────────────────────────────────────────

export fn startFadeCb(data: *anyopaque) c_int {
    const b: *Bubble = @ptrCast(@alignCast(data));
    b.lifetime_source = 0;
    b.fade_source = pg_timeout_add(FADE_INTERVAL_MS, fadeStepCb, b);
    return 0; // G_SOURCE_REMOVE
}

export fn fadeStepCb(data: *anyopaque) c_int {
    const b: *Bubble = @ptrCast(@alignCast(data));
    b.opacity -= 1.0 / FADE_STEPS;
    if (b.opacity <= 0) {
        b.fade_source = 0;
        for (0..app.bubble_count) |i| {
            if (&app.bubbles[i] == b) {
                removeBubble(i);
                break;
            }
        }
        pg_queue_draw(app.window);
        return 0; // G_SOURCE_REMOVE
    }
    pg_queue_draw(app.window);
    return 1; // G_SOURCE_CONTINUE
}

export fn flushGroupCb(_: *anyopaque) c_int {
    flushGroup();
    return 0;
}

const KeyEvent = struct { keycode: u32, keystate: u32 };

export fn keyEventIdleCb(data: *anyopaque) c_int {
    const ev: *KeyEvent = @ptrCast(@alignCast(data));
    dispatchKey(ev.keycode, ev.keystate);
    std.heap.c_allocator.destroy(ev);
    return 0;
}

// ── GTK callbacks ─────────────────────────────────────────────────────────────


export fn onDraw(_: *anyopaque, cr: *anyopaque, _: ?*anyopaque) c_int {
    pg_draw_clear(cr);
    pg_draw_stop_button(cr, STOP_BTN_CX, STOP_BTN_CY, STOP_BTN_R);

    var bottom_y = WINDOW_H;
    var i = app.bubble_count;
    while (i > 0) {
        i -= 1;
        const b = &app.bubbles[i];
        if (b.opacity <= 0) continue;
        const show_cursor: c_int = if (app.group_idx == @as(i32, @intCast(i)) and app.cursor_active) 1 else 0;
        var bh: f64 = 0;
        // Pass y = bottom_y; the C function draws at (y - bh) and sets *out_bh
        pg_draw_bubble(
            cr,
            &b.text, @intCast(b.text_len),
            show_cursor,
            if (b.is_combo) @as(c_int, 1) else @as(c_int, 0),
            b.opacity,
            BUBBLE_LEFT, bottom_y,
            MAX_TEXT_W, PAD_X, PAD_Y, BUBBLE_RADIUS,
            &bh,
        );
        bottom_y -= bh + BUBBLE_GAP;
    }
    return 0;
}

export fn onButtonPress(_: *anyopaque, event: *anyopaque, _: ?*anyopaque) c_int {
    var ex: f64 = 0;
    var ey: f64 = 0;
    pg_event_coords(event, &ex, &ey);
    const dx = ex - STOP_BTN_CX;
    const dy = ey - STOP_BTN_CY;
    if (dx * dx + dy * dy <= STOP_BTN_R * STOP_BTN_R) {
        pg_gtk_main_quit();
    }
    return 1;
}

export fn onDestroy(_: *anyopaque, _: ?*anyopaque) void {
    pg_gtk_main_quit();
}

// ── Key dispatch ──────────────────────────────────────────────────────────────

fn dispatchKey(keycode: u32, keystate: u32) void {
    if (keystate == 2) return; // repeat

    switch (keycode) {
        KEY_LEFTSHIFT, KEY_RIGHTSHIFT => { app.shift = keystate == 1; return; },
        KEY_LEFTCTRL,  KEY_RIGHTCTRL  => { app.ctrl  = keystate == 1; return; },
        KEY_LEFTALT,   KEY_RIGHTALT   => { app.alt   = keystate == 1; return; },
        KEY_LEFTMETA,  KEY_RIGHTMETA  => { app.meta  = keystate == 1; return; },
        else => {},
    }
    if (keystate != 1) return;

    if (app.ctrl or app.alt or app.meta) {
        cancelGroupTimer();
        flushGroup();
        var buf: [64]u8 = undefined;
        var pos: usize = 0;
        const parts = [_]struct { flag: bool, name: []const u8 }{
            .{ .flag = app.ctrl,  .name = "Ctrl" },
            .{ .flag = app.alt,   .name = "Alt" },
            .{ .flag = app.meta,  .name = "Super" },
            .{ .flag = app.shift, .name = "Shift" },
        };
        for (parts) |p| {
            if (!p.flag) continue;
            if (pos > 0) { buf[pos] = '+'; pos += 1; }
            @memcpy(buf[pos..pos + p.name.len], p.name);
            pos += p.name.len;
        }
        const ch = keyToChar(keycode, app.shift);
        if (ch.len > 0) {
            if (pos > 0) { buf[pos] = '+'; pos += 1; }
            @memcpy(buf[pos..pos + ch.len], ch);
            pos += ch.len;
        }
        if (pos > 0) _ = addBubble(buf[0..pos], true);
        return;
    }

    if (keycode == KEY_BACKSPACE) {
        cancelGroupTimer();
        if (app.group_idx >= 0) {
            const gi: usize = @intCast(app.group_idx);
            app.bubbles[gi].removeLastCodepoint();
            if (app.bubbles[gi].text_len > 0) {
                resetBubbleLifetime(gi);
                app.cursor_active = true;
                app.group_timer = pg_timeout_add(GROUP_TIMEOUT_MS, flushGroupCb, app.window);
            } else {
                removeBubble(gi);
                flushGroup();
            }
        }
        pg_queue_draw(app.window);
        return;
    }

    if (keycode == KEY_ENTER) {
        cancelGroupTimer();
        flushGroup();
        return;
    }

    const special = specialKeyName(keycode);
    if (special.len > 0) {
        cancelGroupTimer();
        flushGroup();
        _ = addBubble(special, false);
        return;
    }

    const ch = keyToChar(keycode, app.shift);
    if (ch.len > 0) {
        cancelGroupTimer();
        if (app.group_idx >= 0) {
            const gi: usize = @intCast(app.group_idx);
            app.bubbles[gi].appendChar(ch);
            resetBubbleLifetime(gi);
        } else {
            app.group_idx = @intCast(addBubble(ch, false));
        }
        app.cursor_active = true;
        app.group_timer = pg_timeout_add(GROUP_TIMEOUT_MS, flushGroupCb, app.window);
        pg_queue_draw(app.window);
    }
}

// ── Key tables ────────────────────────────────────────────────────────────────

fn specialKeyName(code: u32) []const u8 {
    return switch (code) {
        KEY_TAB      => "\xe2\x87\xa5",
        KEY_ESC      => "Esc",
        KEY_CAPSLOCK => "Caps",
        KEY_UP       => "\xe2\x86\x91",
        KEY_DOWN     => "\xe2\x86\x93",
        KEY_LEFT     => "\xe2\x86\x90",
        KEY_RIGHT    => "\xe2\x86\x92",
        KEY_DELETE   => "Del",
        KEY_HOME     => "Home",
        KEY_END      => "End",
        KEY_PAGEUP   => "PgUp",
        KEY_PAGEDOWN => "PgDn",
        KEY_INSERT   => "Ins",
        KEY_PAUSE    => "Pause",
        59 => "F1",  60 => "F2",  61 => "F3",  62 => "F4",
        63 => "F5",  64 => "F6",  65 => "F7",  66 => "F8",
        67 => "F9",  68 => "F10", 87 => "F11", 88 => "F12",
        else => "",
    };
}

const CharEntry = struct { normal: []const u8, shifted: []const u8 };

fn charMap(code: u32) ?CharEntry {
    return switch (code) {
        KEY_SPACE => .{ .normal = " ", .shifted = " " },
        2  => .{ .normal = "1", .shifted = "!" },
        3  => .{ .normal = "2", .shifted = "@" },
        4  => .{ .normal = "3", .shifted = "#" },
        5  => .{ .normal = "4", .shifted = "$" },
        6  => .{ .normal = "5", .shifted = "%" },
        7  => .{ .normal = "6", .shifted = "^" },
        8  => .{ .normal = "7", .shifted = "&" },
        9  => .{ .normal = "8", .shifted = "*" },
        10 => .{ .normal = "9", .shifted = "(" },
        11 => .{ .normal = "0", .shifted = ")" },
        12 => .{ .normal = "-", .shifted = "_" },
        13 => .{ .normal = "=", .shifted = "+" },
        26 => .{ .normal = "[", .shifted = "{" },
        27 => .{ .normal = "]", .shifted = "}" },
        43 => .{ .normal = "\\", .shifted = "|" },
        39 => .{ .normal = ";", .shifted = ":" },
        40 => .{ .normal = "'", .shifted = "\"" },
        41 => .{ .normal = "`", .shifted = "~" },
        51 => .{ .normal = ",", .shifted = "<" },
        52 => .{ .normal = ".", .shifted = ">" },
        53 => .{ .normal = "/", .shifted = "?" },
        else => null,
    };
}

const alpha_lower = "qwertyuiopasdfghjklzxcvbnm";
const alpha_upper = "QWERTYUIOPASDFGHJKLZXCVBNM";
const alpha_codes = [_]u32{
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
    30, 31, 32, 33, 34, 35, 36, 37, 38,
    44, 45, 46, 47, 48, 49, 50,
};

fn keyToChar(code: u32, shift: bool) []const u8 {
    if (charMap(code)) |e| return if (shift) e.shifted else e.normal;
    for (alpha_codes, 0..) |kc, i| {
        if (kc == code) {
            if (shift) return alpha_upper[i..i + 1];
            return alpha_lower[i..i + 1];
        }
    }
    return "";
}

// ── Input device detection ────────────────────────────────────────────────────

fn isKeyboard(fd: c_int) bool {
    const KEY_A_CODE: usize = 30;
    const SPACE_CODE: usize = 57;
    var evbits: [(KEY_MAX + 1) / 8 + 1]u8 = std.mem.zeroes([(KEY_MAX + 1) / 8 + 1]u8);
    var keybits: [(KEY_MAX + 1) / 8 + 1]u8 = std.mem.zeroes([(KEY_MAX + 1) / 8 + 1]u8);

    const ev_size = evbits.len;
    const key_size = keybits.len;
    // EVIOCGBIT(0, len) = _IOC(_IOC_READ, 'E', 0x20+0, len)
    // _IOC(dir,type,nr,size) = (dir<<30)|(type<<8)|nr|(size<<16)
    // _IOC_READ = 2
    const eviocgbit_ev:  c_uint = @intCast(0x80000000 | ((ev_size  & 0x3fff) << 16) | (0x45 << 8) | 0x20);
    const eviocgbit_key: c_uint = @intCast(0x80000000 | ((key_size & 0x3fff) << 16) | (0x45 << 8) | (0x20 + 1));

    if (ioctl(fd, eviocgbit_ev,  &evbits)  < 0) return false;
    if ((evbits[EV_KEY / 8] >> @intCast(EV_KEY % 8)) & 1 == 0) return false;
    if (ioctl(fd, eviocgbit_key, &keybits) < 0) return false;
    if ((keybits[KEY_A_CODE / 8] >> @intCast(KEY_A_CODE % 8)) & 1 == 0) return false;
    if ((keybits[SPACE_CODE / 8] >> @intCast(SPACE_CODE % 8)) & 1 == 0) return false;
    return true;
}

fn findKeyboards() void {
    app.dev_count = 0;
    const dir = opendir("/dev/input") orelse return;
    defer _ = closedir(dir);

    while (readdir(dir)) |entry| {
        const name = std.mem.sliceTo(&entry.d_name, 0);
        if (!std.mem.startsWith(u8, name, "event")) continue;

        var path_buf: [64]u8 = undefined;
        const written = std.fmt.bufPrint(&path_buf, "/dev/input/{s}", .{name}) catch continue;
        path_buf[written.len] = 0;

        const fd = open(@ptrCast(&path_buf), O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;

        if (isKeyboard(fd)) {
            if (app.dev_count < app.dev_fds.len) {
                app.dev_fds[app.dev_count] = fd;
                app.dev_count += 1;
            } else {
                _ = close(fd);
            }
        } else {
            _ = close(fd);
        }
    }
}

// ── Input thread ──────────────────────────────────────────────────────────────

fn inputThread(_: void) void {
    while (true) {
        var fds = FdSet{};
        fds.zero();
        var max_fd: c_int = -1;

        for (0..app.dev_count) |i| {
            const fd = app.dev_fds[i];
            if (fd < 0) continue;
            fds.set(fd);
            if (fd > max_fd) max_fd = fd;
        }

        if (max_fd < 0) {
            var ts = Timespec{ .tv_sec = 0, .tv_nsec = 100_000_000 };
            _ = nanosleep(&ts, null);
            continue;
        }

        var tv = Timeval{ .tv_sec = 1, .tv_usec = 0 };
        const ret = select(max_fd + 1, &fds, null, null, &tv);
        if (ret <= 0) continue;

        for (0..app.dev_count) |i| {
            const fd = app.dev_fds[i];
            if (fd < 0) continue;
            if (!fds.isSet(fd)) continue;

            while (true) {
                var ev: input_event = undefined;
                const n = read(fd, &ev, @sizeOf(input_event));
                if (n < @as(isize, @intCast(@sizeOf(input_event)))) break;
                if (ev.type != EV_KEY) continue;

                const ke = std.heap.c_allocator.create(KeyEvent) catch continue;
                ke.* = .{ .keycode = ev.code, .keystate = @bitCast(ev.value) };
                _ = pg_idle_add(keyEventIdleCb, ke);
            }
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main() !void {
    // Initialize app state
    app.bubble_count = 0;
    app.group_idx = -1;
    app.group_timer = 0;
    app.cursor_active = false;
    app.shift = false;
    app.ctrl = false;
    app.alt = false;
    app.meta = false;
    app.dev_count = 0;
    for (&app.bubbles) |*b| b.* = Bubble.init();
    for (&app.dev_fds) |*fd| fd.* = -1;

    pg_gtk_init();

    findKeyboards();
    if (app.dev_count == 0) {
        const msg = "popsicle: no keyboard devices found.\n  Run: sudo usermod -aG input $USER  then re-login\n";
        std.debug.print("{s}", .{msg});
        std.process.exit(1);
    }

    std.debug.print("popsicle: watching {} device(s)\n", .{app.dev_count});

    const window = pg_create_window(1, 40); // anchor_left=1, margin=40
    app.window = window;

    pg_connect_draw(window, onDraw);
    pg_connect_button_press(window, onButtonPress);
    pg_connect_destroy(window, onDestroy);

    pg_window_show(window);
    pg_window_realize(window);

    const r = @as(c_int, @intFromFloat(STOP_BTN_R));
    const cx = @as(c_int, @intFromFloat(STOP_BTN_CX));
    const cy = @as(c_int, @intFromFloat(STOP_BTN_CY));
    pg_set_input_shape(window, cx - r, cy - r, r * 2, r * 2);

    const thread = try std.Thread.spawn(.{}, inputThread, .{{}});
    thread.detach();

    pg_gtk_main();
}
