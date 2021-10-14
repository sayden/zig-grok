const std = @import("std");
const g = @cImport(@cInclude("grok.h"));
const GrokError = @import("error.zig").GrokErrors;
const get_error = @import("error.zig").get_error;

pub fn main() !void {
    const user_patterns = "%{WORD:word1} %{WORD:word2}";
    const base_patterns = "/home/caster/software/grok/patterns/base";
    const input_text = "hello world";
    var page = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page);
    var allocator = &arena.allocator;
    defer arena.deinit();

    try execute(allocator, base_patterns, user_patterns, input_text);
}

const Result = struct {
    match_type: []const u8,
    str: []const u8,

    pub fn init(match_type: []const u8, str: []const u8) Result {
        return Result{
            .match_type = match_type,
            .str = str,
        };
    }
};

const Iterator = struct {
    match: *g.grok_match_t,

    pub fn init(match: *g.grok_match_t) Iterator {
        return Iterator{
            .match = match,
        };
    }

    pub fn next(self: *Iterator, type_buf: []u8, str_buf: []u8) !?Result {
        var t = type_buf;
        var s = str_buf;

        var name = @ptrCast([*c][*c]u8, &t);
        var str = @ptrCast([*c][*c]u8, &s);

        var len: c_int = 0;
        var namelen: c_int = 0;

        var res = g.grok_match_walk_next(self.match, name, &namelen, str, &len);
        if (res == 1) {
            // EOF
            return null;
        } else if (res > 1) {
            return get_error(res);
        }

        return Result.init(t[0..@intCast(usize, namelen)], s[0..@intCast(usize, len)]);
    }
};

fn execute(allocator: *std.mem.Allocator, base_patterns: [*c]const u8, user_patterns: [*c]const u8, input_text: [*c]const u8) !void {
    var mygrok = g.grok_new();
    defer g.free(mygrok);

    var res = g.grok_patterns_import_from_file(mygrok, base_patterns);
    if (res != 0) {
        return get_error(res);
    }

    res = g.grok_compile(mygrok, user_patterns);
    if (res != 0) {
        return get_error(res);
    }

    var match = g.grok_match_t{
        .end = 0,
        .start = 0,
        .subject = "",
        .grok = mygrok,
    };

    res = g.grok_exec(mygrok, input_text, &match);
    if (res != 0) {
        return get_error(res);
    }

    g.grok_match_walk_init(&match);

    var iter = Iterator.init(&match);

    var buf: []u8 = try allocator.alloc(u8, 100);
    defer allocator.free(buf);
    while (try iter.next(buf[0..50], buf[50..])) |result| {
        std.debug.print("Word: '{s}', Word: '{s}'\n", .{ result.match_type, result.str });
    }
}
