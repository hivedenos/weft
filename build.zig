const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const controller = b.addExecutable(.{
        .name = "controller",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/controller/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    controller.root_module.link_libc = true;

    const zqlite = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    controller.root_module.addImport("zqlite", zqlite.module("zqlite"));

    const dusty = b.dependency("dusty", .{
        .target = target,
        .optimize = optimize,
        .use_tls = false,
    });
    controller.root_module.addImport("dusty", dusty.module("dusty"));

    b.installArtifact(controller);

    const controller_check = b.addExecutable(.{
        .name = "controller",
        .root_module = controller.root_module,
    });

    const check = b.step("check-controller", "Check controller compilation");
    check.dependOn(&controller_check.step);

    const run_controller = b.addRunArtifact(controller);
    run_controller.addPassthruArgs();

    const run_step = b.step("run-controller", "Run the controller");
    run_step.dependOn(&run_controller.step);
}
