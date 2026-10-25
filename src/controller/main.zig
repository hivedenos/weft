const std = @import("std");
const config = @import("config.zig");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const cfg = config.parse(args[1..]) catch |err| {
        std.log.err("invalid configuration: {s}", .{@errorName(err)});
        std.debug.print(
            "Usage: controller --listen <IPv4:port> --db <path>\n",
            .{},
        );

        std.process.exit(2);
    };

    std.log.info("valid configuration loaded: listen={f} db={s}", .{
        cfg.listen_address, cfg.db_path,
    });
}
