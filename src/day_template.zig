const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

pub fn process(allocator: std.mem.Allocator) !Solution {
    var line_iter = try fs.LineIterator.init(allocator, "dayXX", false);
    while (line_iter.next()) |line| {
        var parser = LineParser.init(line);
        _ = parser;
    }
    
    var solution = Solution{ .answer = 0 };
    return solution;
}

pub const Solution = struct {
    answer: i32,

    pub fn draw(self: *const Solution, allocator: std.mem.Allocator, dt: f32) void {
        _ = dt;
        raylib.drawAnswer(allocator, 10, 10, 30, c.WHITE, @intCast(self.answer));
    }
};