const std = @import("std");
const Query = std.Target.Query;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

const features = Target.x86.Feature;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;
    disabled_features.addFeature(@intFromEnum(features.mmx));
    disabled_features.addFeature(@intFromEnum(features.sse));
    disabled_features.addFeature(@intFromEnum(features.sse2));
    disabled_features.addFeature(@intFromEnum(features.avx));
    disabled_features.addFeature(@intFromEnum(features.avx2));
    enabled_features.addFeature(@intFromEnum(features.soft_float));

    const x86_i686 = Query{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &Target.x86.cpu.i686 },
        .abi = .none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{ .whitelist = &[_]Query{x86_i686}, .default_target = x86_i686 });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "simpleos.elf",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).

    // b.installArtifact(lib);

    const kernel = b.addExecutable(.{
        .name = "simpleos.elf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    kernel.setLinkerScript(b.path("src/linker.ld"));
    b.installArtifact(kernel);

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.step);

    const iso_dir = b.fmt("{s}/iso_root/", .{b.cache_root.path.?});
    const kernel_path = b.getInstallPath(.bin, kernel.out_filename);
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});

    const iso_cmd_str: []const []const u8 = &[_][]const u8{
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ",
            iso_dir,
            "/boot",
            " && ",
            "cp ",
            kernel_path,
            " ",
            iso_dir,
            "/boot",
            " && ",
            "cp src/grub.cfg ",
            iso_dir,
            "/boot",
            " && ",
            "grub-mkrescue -o ",
            iso_path,
            " ",
            iso_dir,
        }) catch unreachable,
    };

    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);

    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);

    const run_cmd_str = &[_][]const u8{
        "qemu-system-x86_64",
        "-cdrom",
        iso_path,
        "-debugcon",
        "stdio",
        "-vga",
        "virtio",
        "-m",
        "4G",
        "-machine",
        "q35,accel=kvm:whpx:tcg",
        "-no-reboot",
        "-no-shutdown",
    };

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel using qemu");
    run_step.dependOn(&run_cmd.step);
}
