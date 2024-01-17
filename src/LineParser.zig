const std = @import("std");
const LineParser = @This();

line: []const u8,
cursor: usize = 0,

pub fn init(line: []const u8) LineParser {
    return LineParser{
        .line = line,
    };
}

pub fn setLine(self: *LineParser, line: []const u8) void {
    self.line = line;
    self.cursor = 0;
}

pub fn advanceCursor(self: *LineParser) !void {
    if (self.isEnd()) {
        return error.ReachedEnd;
    }
    self.cursor += 1;
}

pub fn isEnd(self: *const LineParser) bool {
    return self.cursor == self.line.len;
}

pub fn peekRemaining(self: *const LineParser) ![]const u8 {
    if (self.isEnd()) {
        return error.ReachedEnd;
    }
    return self.line[self.cursor..];
}

pub fn peekChar(self: *const LineParser) u8 {
    if (self.isEnd()) {
        return 0;
    } else {
        return self.line[self.cursor];
    }
}

pub fn skipWord(self: *LineParser, word: []const u8) !void {
    const remaining = try self.peekRemaining();
    if (std.mem.startsWith(u8, remaining, word)) {
        self.cursor += word.len;
    } else {
        return error.InvalidSkipWord;
    }
}

pub fn skipChar(self: *LineParser, char: u8) !void {
    if (self.peekChar() == char) {
        self.cursor += 1;
    } else {
        return error.InvalidSkipChar;
    }
}

pub fn skipWhitespace(self: *LineParser) !void {
    if (self.isEnd()) {
        return error.ReachedEnd;
    }
    if (!std.ascii.isWhitespace(self.line[self.cursor])) {
        return error.InvalidSkipWhitespace;
    }
    while (!self.isEnd() and std.ascii.isWhitespace(self.line[self.cursor]))
    {
        self.cursor += 1;
    }
}

pub fn readNumber(self: *LineParser, comptime T: type) !T {
    var start_cursor = self.cursor;
    while (!self.isEnd() and std.ascii.isDigit(self.line[self.cursor]))
    {
        self.cursor += 1;
    }
    const number_slice = self.line[start_cursor..self.cursor];
    return try std.fmt.parseInt(T, number_slice, 10);
}

pub fn readNumberList(self: *LineParser, comptime T: type, end_char: ?u8, list: anytype) !void {
    while (!self.isEnd()) {
        const number = try self.readNumber(T);
        try list.append(number);

        self.skipWhitespace() catch {};
        if (end_char) |char| {
            if (self.peekChar() == char) {
                break;
            }
        }
    }
}

pub fn readEnum(self: *LineParser, comptime T: type, words: []const []const u8, tags: []const T) !T {
    if (words.len != tags.len) {
        return error.WordsTagsLenMismatch;
    }

    const remaining = try self.peekRemaining();
    for (words, 0..) |word, i| {
        if (std.mem.startsWith(u8, remaining, word)) {
            self.cursor += word.len;
            return tags[i];
        }
    }

    return error.TagNotFound;
}

pub fn nextLine(self: *LineParser) !void {
    if (self.isEnd()) {
        return error.ReachedEnd;
    } else {
        while (self.line[self.cursor] == '\r' or self.line[self.cursor] == '\n') {
            self.cursor += 1;
            if (self.isEnd()) {
                return;
            }
        }
    }
}