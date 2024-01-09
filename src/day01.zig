const std = @import("std");
const fs = @import("fs.zig");
const LineParser = @import("LineParser.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

const word_numbers = [_][]const u8{
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine"
};

const digits = [_][]const u8{
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9"
};

pub const Solution = struct {
    sum: i32 = 0,
    puzzle_input: []const u8,
    steps: std.ArrayList(Step),
    
    sim_speed: f32 = 0,
    current_info: InfoStep = InfoStep{ .line_number = 0 },
    current_result: ResultStep = ResultStep{ .extracted_number = 0, .sum = 0 },
    last_step_i: usize = 0,

    const Step = union(enum) {
        line: LineStep,
        info: InfoStep,
        result: ResultStep
    };

    const LineStep = struct {
        line: []const u8,
        bHighlight: bool,
        highlight_start: usize,
        highlight_end: usize
    };

    const InfoStep = struct {
        line_number: usize,
    };

    const ResultStep = struct {
        extracted_number: i32,
        sum: i32
    };

    pub fn addInfoStep(self: *Solution, line_number: usize) !void {
        const step = Solution.InfoStep{ .line_number = line_number };
        try self.steps.append(.{ .info = step });
    }

    pub fn addLineStep(self: *Solution, line: []const u8, bHighlight: bool, start: usize, end: usize) !void {
        if (!bHighlight or ((line.len - 1) >= end and start < end)) {
            const step = Solution.LineStep{
                .line = line[0..line.len - 1],
                .bHighlight = bHighlight,
                .highlight_start = start,
                .highlight_end = end
            };
            try self.steps.append(.{ .line = step });
        }
    }

    pub fn addResultStep(self: *Solution, extracted_number: i32, sum: i32) !void {
        const step = Solution.ResultStep{ .extracted_number = extracted_number, .sum = sum };
        try self.steps.append(.{ .result = step });
    }

    pub fn draw(self: *Solution, allocator: std.mem.Allocator, dt: f32) void {
        const font_size: usize = 40;
        const background_color = c.Color{ .r = 100, .g = 0, .b = 0, .a = 255 };
        const font_color = c.WHITE;
        const highlight_color = c.GREEN;
        c.ClearBackground(background_color);

        self.sim_speed += (dt * 4.2);
        const step_i = blk: {
            const time: f64 = c.GetTime();
            const i: usize = @intFromFloat(std.math.floor(time * self.sim_speed));
            break :blk @min(i, self.steps.items.len - 1);
        };

        // Run any steps that have been skipped due to sim_speed being faster than framerate.
        if (step_i > (self.last_step_i + 1)) {
            for ((self.last_step_i + 1)..step_i) |skipped_step_i| {
                const step_union = self.steps.items[skipped_step_i];
                switch (step_union) {
                    .line => |_| {},
                    .info => |step| self.current_info = step,
                    .result => |step| self.current_result = step
                }
            }
        }

        // Run step for this frame.
        const step_union = self.steps.items[step_i];
        switch (step_union) {
            .info => |step| self.current_info = step,
            .result => |step| self.current_result = step,
            .line => |*step| {
                const x_pos = 32;
                const y_pos = 64;
                if (step.bHighlight) {
                    const pre_width = raylib.getTextWidth(allocator, step.line[0..step.highlight_start], font_size);
                    const width = raylib.getTextWidth(allocator, step.line[step.highlight_start..step.highlight_end], font_size);
                    c.DrawRectangle(x_pos + pre_width, y_pos, width + 6, font_size, highlight_color);
                }
                raylib.drawText(allocator, step.line, x_pos, y_pos, font_size, font_color);
            }
        }

        raylib.drawTextAllocPrint(
            allocator, 
            "line {d}:", .{ self.current_info.line_number }, 
            32, 64 - font_size, font_size, font_color
        );
        raylib.drawTextAllocPrint(
            allocator, 
            "previous number: {d}, sum: {d}", .{ self.current_result.extracted_number, self.current_result.sum }, 
            32, 64 + font_size, font_size/2, font_color
        );

        raylib.drawAnswer(allocator, 32, 200, font_size, font_color, self.sum);
    }
};

fn processLine(line: []const u8, bReverse: bool, solution: *Solution) !i32 {
    if (line.len == 0) {
        return error.InvalidLine;
    }

    for (0..line.len) |i| {
        const char_i = if (bReverse) (line.len - i - 1) else i;
        // Check for single digit.
        try solution.addLineStep(line, true, char_i, char_i + 1);
        if (std.ascii.isDigit(line[char_i])) {
            return (line[char_i] - '0');
        }
        // Check for english number word.
        const line_slice = line[char_i..];
        for (word_numbers, 0..) |word, word_i| {
            if (word.len > line_slice.len) {
                continue;
            }
            try solution.addLineStep(line, true, char_i, char_i + word.len);
            if (std.mem.startsWith(u8, line_slice, word)) {
                return @intCast(word_i + 1);
            }
        }
    }

    return error.InvalidLine;
}

pub fn process(allocator: std.mem.Allocator) !Solution {
    var line_iter = try fs.LineIterator.init(allocator, "day01", false);
    // defer line_iter.deinit(allocator); NOTE: Don't deinit as we refer to the puzzle input in the draw routine.

    var solution = Solution{
        .sum = 0,
        .puzzle_input = line_iter.puzzle_input,
        .steps = std.ArrayList(Solution.Step).init(allocator)
    };
    
    var line_i: usize = 0;
    while (line_iter.next()) |line| {
        try solution.addInfoStep(line_i + 1);
        try solution.addLineStep(line, false, 0, 0);
        const first_digit: i32 = try processLine(line, false, &solution);
        const last_digit: i32 = try processLine(line, true, &solution);
        const number: i32 = (first_digit * 10) + last_digit;
        solution.sum = solution.sum + number;
        try solution.addResultStep(number, solution.sum);
        line_i = line_i + 1;
    }

    return solution;
}