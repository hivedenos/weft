const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const controller = b.addExecutable(.{ .name = "controller", .root_module = b.createModule(.{
        .root_source_file = b.path("src/controller/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });

    b.installArtifact(controller);

    const run_controller = b.addRunArtifact(controller);
    run_controller.addPassthruArgs();

    const run_step = b.step("run-controller", "Run the controller");
    run_step.dependOn(&run_controller.step);
}
