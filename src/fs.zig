const std = @import("std");

const MAX_PUZZLE_INPUT_SIZE = 1024 * 1024;
const NEWLINE_CHARACTERS = "\r\n";

pub fn readPuzzleInput(allocator: std.mem.Allocator, comptime day_name: []const u8) ![]const u8 {
    const filepath = "puzzle_input/" ++ day_name ++ ".txt";
    return try std.fs.cwd().readFileAlloc(allocator, filepath, MAX_PUZZLE_INPUT_SIZE);
}

pub const LineIterator = struct {
    puzzle_input: []const u8,
    token_iter: ?std.mem.TokenIterator(u8, .any) = null,
    split_iter: ?std.mem.SplitIterator(u8, .sequence) = null,

    pub fn init(allocator: std.mem.Allocator, comptime day_name: []const u8, include_empty_lines: bool) !LineIterator {
        const puzzle_input = try readPuzzleInput(allocator, day_name);
        if (include_empty_lines) {
            return LineIterator{
                .puzzle_input = puzzle_input,
                .split_iter = std.mem.splitSequence(u8, puzzle_input, NEWLINE_CHARACTERS)
            };
        } else {
            return LineIterator{
                .puzzle_input = puzzle_input,
                .token_iter = std.mem.tokenizeAny(u8, puzzle_input, NEWLINE_CHARACTERS)
            };
        }
    }

    pub fn deinit(self: *LineIterator, allocator: std.mem.Allocator) void {
        allocator.free(self.puzzle_input);
    }

    pub fn next(self: *LineIterator) ?[]const u8 {
        if (self.token_iter) |*token_iter| {
            return token_iter.next();
        }
        if (self.split_iter) |*split_iter| {
            return split_iter.next();
        }
        return null;
    }
};