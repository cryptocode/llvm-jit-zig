const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "jit",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    switch (target.result.os.tag) {
        .linux => lib.linkSystemLibrary("LLVM-17"),
        .macos => {
            lib.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/llvm/lib" });
            lib.addIncludePath(.{ .cwd_relative = "/usr/local/opt/llvm/include" });
            lib.linkSystemLibrary("LLVM");
        },
        else => lib.linkSystemLibrary("LLVM"),
    }

    b.installArtifact(lib);
    _ = try b.modules.put("llvm", &lib.root_module);

    const exe = b.addExecutable(.{
        .name = "jit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("llvm", b.modules.get("llvm").?);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/llvm/lib" });
    lib_unit_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/llvm/include" });
    lib_unit_tests.linkSystemLibrary("LLVM");

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
