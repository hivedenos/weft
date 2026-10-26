const std = @import("std");
const dusty = @import("dusty");

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    address: std.Io.net.IpAddress,
) !void {
    var server = dusty.Server(void).init(allocator, io, .{
        .listeners = &.{
            .{ .address = .{
                .ip = address,
            } },
        },
    }, {});
    defer server.deinit();

    server.router.get("/healthz", health);

    std.log.info("starting HTTP server on {f}", .{address});
    try server.run();
}

fn health(_: *dusty.Request, response: *dusty.Response) !void {
    response.status = .ok;

    try response.header("Content-Type", "application/json");
    response.body = "{\"status\":\"ok\"}";
}
