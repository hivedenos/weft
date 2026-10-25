const std = @import("std");

pub const Config = struct {
    listen_address: std.Io.net.IpAddress,
    db_path: []const u8,
};

pub const ParseError = error{
    UnknownOption,
    MissingValue,
    MissingAddress,
    MissingDatabasePath,
    InvalidListenAddress,
    InvalidDbPath,
};

pub fn parse(
    args: []const []const u8,
) ParseError!Config {
    var listen: ?std.Io.net.IpAddress = null;
    var db_path: ?[]const u8 = null;
    var arg_index: u8 = 0;

    while (arg_index < args.len) : (arg_index += 1) {
        const option = args[arg_index];
        const is_listen = std.mem.eql(u8, option, "--listen");
        const is_db = std.mem.eql(u8, option, "--db");

        std.log.info("address: {s} {} {}", .{ option, is_listen, is_db });

        if (!is_listen and !is_db) return ParseError.UnknownOption;

        arg_index += 1;

        const option_value = args[arg_index];
        if (std.mem.startsWith(u8, option_value, "--")) return ParseError.MissingValue;

        if (is_listen) {
            const colon_index = std.mem.indexOf(u8, option_value, ":") orelse return ParseError.InvalidListenAddress;

            std.log.info("address: {s} {d}", .{ option_value[0..colon_index], colon_index });

            const host = option_value[0..colon_index];
            const port = std.fmt.parseInt(u16, option_value[colon_index + 1 ..], 10) catch return ParseError.InvalidListenAddress;

            if (port == 0) return ParseError.InvalidListenAddress;

            listen = std.Io.net.IpAddress.parseIp4(host, port) catch return ParseError.InvalidListenAddress;
        }

        if (is_db) {
            if (option_value.len == 0) return ParseError.InvalidDbPath;

            db_path = option_value;
        }

        // arg_index += 1;
    }

    return .{
        .listen_address = listen orelse return ParseError.MissingAddress,
        .db_path = db_path orelse return ParseError.MissingDatabasePath,
    };
}
