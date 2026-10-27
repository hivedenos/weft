const std = @import("std");
const zqlite = @import("zqlite");

pub const DbError = error{
    NonExistentPath,
    ConfigurationFailed,
    ExistingMigrationNewer,
    WrongMigrationHistory,
};

pub const Database = struct {
    conn: zqlite.Conn,

    const migrations = [_][*:0]const u8{
        @embedFile("migrations/0001_initial.sql"),
    };

    pub fn open(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !Database {
        if (path.len == 0) return DbError.NonExistentPath;

        const db_path = try allocator.allocSentinel(u8, path.len, 0);
        defer allocator.free(db_path);

        @memcpy(db_path, path);

        const conn = try zqlite.open(db_path, zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode);
        errdefer conn.close();

        try conn.busyTimeout(5000);

        try conn.exec("PRAGMA foreign_keys = ON", .{});

        if (try intVal(conn, "PRAGMA foreign_keys;") != 1) return DbError.ConfigurationFailed;

        if (!std.mem.eql(u8, try textVal(conn, "PRAGMA journal_mode = WAL;"), "wal")) return DbError.ConfigurationFailed;

        try conn.exec("PRAGMA synchronous = FULL;", .{});

        try migrate(conn);

        return .{ .conn = conn };
    }

    pub fn close(self: *Database) void {
        self.conn.close();
        self.* = undefined;
    }

    fn migrate(conn: zqlite.Conn) !void {
        try conn.exec("BEGIN IMMEDIATE;", .{});
        errdefer conn.rollback();

        try conn.exec(
            \\ CREATE TABLE IF NOT EXISTS schema_migrations (
            \\    version INTEGER PRIMARY KEY CHECK (version > 0),
            \\    applied_at INTEGER NOT NULL
            \\ ) STRICT;
        , .{});

        const version = try intVal(conn, "SELECT COALESCE(max(version), 0) from schema_migrations;");
        if (version > migrations.len) return DbError.ExistingMigrationNewer;

        const count = try intVal(conn, "SELECT COUNT(version) from schema_migrations;");
        if (count != version) return DbError.WrongMigrationHistory;

        for (migrations, 0..) |migration, number| {
            if (number <= version) continue;

            try conn.execNoArgs(migration);

            try conn.exec(
                "INSERT INTO schema_migrations(version, applied_at) VALUES (?1, unixepoch())",
                .{@as(i64, @intCast(number))},
            );
        }

        try conn.commit();
    }

    fn intVal(conn: zqlite.Conn, query: []const u8) !i64 {
        const row = try conn.row(query, .{}) orelse return error.ExpectedDbRow;
        defer row.deinit();

        return row.int(0);
    }

    fn textVal(conn: zqlite.Conn, query: []const u8) ![]const u8 {
        const row = try conn.row(query, .{}) orelse return error.ExpectedDbRow;
        defer row.deinit();

        return row.text(0);
    }
};
