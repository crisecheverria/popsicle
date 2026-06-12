const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_flags = [_][]const u8{
        "-I/usr/include/gtk-layer-shell",
        "-I/usr/include/gtk-3.0",
        "-I/usr/include/glib-2.0",
        "-I/usr/lib/glib-2.0/include",
        "-I/usr/include/pango-1.0",
        "-I/usr/include/cairo",
        "-I/usr/include/gdk-pixbuf-2.0",
        "-I/usr/include/atk-1.0",
        "-I/usr/include/harfbuzz",
        "-I/usr/include/freetype2",
        "-I/usr/include/pixman-1",
        "-I/usr/include/gio-unix-2.0",
        "-I/usr/include/fribidi",
        "-I/usr/include/libpng16",
    };

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Compile the GTK/Cairo C wrapper
    mod.addCSourceFile(.{
        .file = b.path("src/popsicle_gtk.c"),
        .flags = &c_flags,
    });

    mod.addIncludePath(.{ .cwd_relative = "src" });

    mod.linkSystemLibrary("gtk-layer-shell", .{});
    mod.linkSystemLibrary("gtk-3", .{});
    mod.linkSystemLibrary("gdk-3", .{});
    mod.linkSystemLibrary("cairo-gobject", .{});
    mod.linkSystemLibrary("gdk_pixbuf-2.0", .{});
    mod.linkSystemLibrary("atk-1.0", .{});
    mod.linkSystemLibrary("pangocairo-1.0", .{});
    mod.linkSystemLibrary("pango-1.0", .{});
    mod.linkSystemLibrary("cairo", .{});
    mod.linkSystemLibrary("gio-2.0", .{});
    mod.linkSystemLibrary("harfbuzz", .{});
    mod.linkSystemLibrary("gobject-2.0", .{});
    mod.linkSystemLibrary("glib-2.0", .{});

    const exe = b.addExecutable(.{
        .name = "popsicle",
        .root_module = mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run popsicle");
    run_step.dependOn(&run_cmd.step);
}
