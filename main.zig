const std = @import("std");
const g = @cImport(@cInclude("grok.h"));
const GrokError = @import("error.zig").GrokErrors;
const get_error = @import("error.zig").get_error;
const json = std.json;

const jstruct = struct {
    word1: ?[]const u8 = null,
    word2: ?[]const u8 = null,
};

pub fn main() !void {
    const user_patterns = "%{WORD:word1} %{WORD:word2} in %{NUMBER:n}";
    const base_patterns = "/home/caster/software/grok/patterns/base";
    const input_text = "hello world in 2021";
    var page = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page);
    var allocator = &arena.allocator;
    defer arena.deinit();

    var js = jstruct{};
    var iter1 = try getIterator(base_patterns, user_patterns, input_text);
    defer iter1.deinit();
    try toStructAlloc(jstruct, &js, &iter1, allocator);
    std.debug.print("Result is: {}\n", .{js});

    js = jstruct{};

    var iter3 = try getIterator(base_patterns, user_patterns, input_text);
    defer iter3.deinit();

    var buf2 = try allocator.alloc(u8, 100);
    try toStruct(jstruct, &js, &iter3, buf2[0..50], buf2[50..]);
    std.debug.print("Result is: {}\n", .{js});
}

pub fn toStruct(comptime T: type, st: anytype, iter: *Iterator, key: []u8, value: []u8) !void {
    comptime var struct_t: std.builtin.TypeInfo = @typeInfo(T);

    while (try iter.next(key, value)) |token| {
        inline for (struct_t.Struct.fields) |field| {
            if (std.mem.eql(u8, token.get_name(), field.name)) {
                @field(st, field.name) = token.get_value();
                break;
            }
        }
    }
}

pub fn toStructAlloc(comptime T: type, st: anytype, iter: *Iterator, allocator: *std.mem.Allocator) !void {
    comptime var struct_t: std.builtin.TypeInfo = @typeInfo(T);

    while (try iter.nextAlloc(allocator)) |token| {
        inline for (struct_t.Struct.fields) |field| {
            if (std.mem.eql(u8, token.get_name(), field.name)) {
                @field(st, field.name) = token.get_value();
                break;
            }
        }
    }
}

const Result = struct {
    name: []const u8,
    namelen: usize,
    str: []const u8,
    strlen: usize,

    pub fn init(name: []const u8, str: []const u8) Result {
        return Result{
            .name = name,
            .str = str,
        };
    }

    pub fn get_value(self: *const Result) []const u8 {
        return self.str[0..self.strlen];
    }

    pub fn get_type(self: *const Result) []const u8 {
        for (self.name[0..self.namelen]) |c, i| {
            if (c == ':') {
                return self.name[0..i];
            }
        }

        return self.name;
    }

    pub fn get_name(self: *const Result) []const u8 {
        for (self.name[0..self.namelen]) |c, i| {
            if (c == ':') {
                return self.name[i + 1 .. self.namelen];
            }
        }
        return self.name;
    }
};

const Iterator = struct {
    match: g.grok_match_t,
    grok: [*c]g.grok_t,

    pub fn init(match: g.grok_match_t, grok: [*c]g.grok_t) Iterator {
        return Iterator{
            .match = match,
            .grok = grok,
        };
    }

    pub fn next(self: *Iterator, type_buf: []u8, str_buf: []u8) !?Result {
        var t = type_buf;
        var s = str_buf;

        var name = @ptrCast([*c][*c]u8, &t);
        var str = @ptrCast([*c][*c]u8, &s);

        var strlen: c_int = 0;
        var namelen: c_int = 0;

        var res = g.grok_match_walk_next(&self.match, name, &namelen, str, &strlen);
        if (res == 1) {
            // EOF
            return null;
        } else if (res > 1) {
            return get_error(res);
        }

        return Result{
            .name = t,
            .namelen = @intCast(usize, namelen),
            .str = s,
            .strlen = @intCast(usize, strlen),
        };
    }

    pub fn nextAlloc(self: *Iterator, alloc: *std.mem.Allocator) !?Result {
        var name_ = try alloc.alloc(u8, 50);
        var str_ = try alloc.alloc(u8, 50);

        const name = @ptrCast([*c][*c]u8, &name_);
        const str = @ptrCast([*c][*c]u8, &str_);

        var strlen: c_int = 0;
        var namelen: c_int = 0;

        const res = g.grok_match_walk_next(&self.match, name, &namelen, str, &strlen);
        if (res == 1) {
            // EOF
            return null;
        } else if (res > 1) {
            return get_error(res);
        }

        return Result{
            .name = name_,
            .namelen = @intCast(usize, namelen),
            .str = str_,
            .strlen = @intCast(usize, strlen),
        };
    }

    pub fn deinit(self: *Iterator) void {
        g.free(self.grok);
        // match is freed by the library
    }
};

fn getIterator(base_patterns: [*c]const u8, user_patterns: [*c]const u8, input_text: [*c]const u8) !Iterator {
    var mygrok = g.grok_new();

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

    return Iterator.init(match, mygrok);
}
