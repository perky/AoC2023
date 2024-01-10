const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

pub fn process(allocator: std.mem.Allocator) !Solution {
    var map = try Map.init(allocator);
    var line_iter = try fs.LineIterator.init(allocator, "day03", false);
    while (line_iter.next()) |line| {
        var parser = LineParser.init(line);
        map.width = line.len;
        map.height += 1;
        while (!parser.isEnd()) {
            const char = parser.peekChar();
            if (char == '.') {
                try map.cells.append(Map.Cell{ .empty = {} });
                try parser.advanceCursor();
            } else if (std.ascii.isDigit(char)) {
                const cursor_start = parser.cursor;
                const whole_number = try parser.readNumber(i32);
                try map.numbers.append(Map.Number{ .value = whole_number });
                const whole_number_key = map.numbers.len - 1;
                const cursor_end = parser.cursor;
                for (cursor_start..cursor_end) |cursor| {
                    try map.cells.append(Map.Cell{ .digit = .{
                        .digit_char = line[cursor],
                        .whole_number_key = whole_number_key
                    }});
                }
            } else if (!std.ascii.isAlphabetic(char)) {
                if (char == '*') {
                    try map.cells.append(Map.Cell{ .symbol = .{
                        .symbol_char = char
                    }});
                    const symbol_index = map.cells.len - 1;
                    try map.symbol_indices.append(symbol_index);
                } else {
                    try map.cells.append(Map.Cell{ .empty = {} });
                }
                try parser.advanceCursor();
            } else {
                @panic("Unknown character in day03 puzzle input.");
            }
        }
    }

    var gear_ratio_sum: i32 = 0;
    const symbol_indices = map.symbol_indices.constSlice();
    for (symbol_indices) |symbol_index| {
        const symbol_x: i32 = @intCast(symbol_index % map.width);
        const symbol_y: i32 = @intCast(symbol_index / map.width);
        
        var gear_number_indices: [2]?usize = undefined;
        gear_number_indices[0] = null;
        gear_number_indices[1] = null;

        for (0..3) |rel_adj_y| outer_loop: {
            for (0..3) |rel_adj_x| {
                const abs_adj_x: i32 = symbol_x + @as(i32, @intCast(rel_adj_x)) - 1;
                const abs_adj_y: i32 = symbol_y + @as(i32, @intCast(rel_adj_y)) - 1;
                const is_middle_cell = (abs_adj_x == symbol_x and abs_adj_y == symbol_y);
                const is_off_map = (abs_adj_x < 0 or abs_adj_y < 0 or abs_adj_x >= map.width or abs_adj_y >= map.height);
                if (is_middle_cell or is_off_map) {
                    continue;
                }
                const adj_cell_i: usize = @as(usize, @intCast(abs_adj_y)) * map.width + @as(usize, @intCast(abs_adj_x));
                const adj_cell = map.cells.get(adj_cell_i);
                switch (adj_cell) {
                    .digit => |digit| {
                        if (gear_number_indices[0]) |gear_num_key| {
                            if (gear_num_key == digit.whole_number_key) {
                                break :outer_loop;
                            }
                        }
                        if (gear_number_indices[1]) |gear_num_key| {
                            if (gear_num_key == digit.whole_number_key) {
                                break :outer_loop;
                            }
                        }

                        if (gear_number_indices[0] == null) {
                            gear_number_indices[0] = digit.whole_number_key;
                        } else if (gear_number_indices[1] == null) {
                            gear_number_indices[1] = digit.whole_number_key;
                        } else {
                            gear_number_indices[0] = null;
                            gear_number_indices[1] = null;
                            break :outer_loop;
                        }
                    },
                    else => {}
                }
            }
        }

        if (gear_number_indices[0] != null and gear_number_indices[1] != null) {
            const gear_key_0 = gear_number_indices[0].?;
            const gear_key_1 = gear_number_indices[1].?;
            map.numbers.buffer[gear_key_0].is_part = true;
            map.numbers.buffer[gear_key_1].is_part = true;
            const gear_ratio = map.numbers.get(gear_key_0).value * map.numbers.get(gear_key_1).value;
            gear_ratio_sum += gear_ratio;
        }
    }

    // expected answer = 75805607
    // runtime answer  = 75805607
    var solution = Solution{ .answer = gear_ratio_sum, .map = map };
    return solution;
}

const Map = struct {
    width: usize = 0,
    height: usize = 0,
    cells: CellArray,
    numbers: NumberArray,
    symbol_indices: IndexArray,

    pub fn init(allocator: std.mem.Allocator) !*Map {
        var map = try allocator.create(Map);
        map.* = Map{
            .cells = try CellArray.init(0),
            .numbers = try NumberArray.init(0),
            .symbol_indices = try IndexArray.init(0)
        };
        return map;
    }

    const ARRAY_SIZE = 20_000;
    const CellArray = std.BoundedArray(Cell, ARRAY_SIZE);
    const NumberArray = std.BoundedArray(Number, ARRAY_SIZE);
    const IndexArray = std.BoundedArray(usize, ARRAY_SIZE);

    const Number = struct {
        value: i32,
        is_part: bool = false
    };

    const DigitCell = struct {
        digit_char: u8,
        whole_number_key: usize,
    };

    const SymbolCell = struct {
        symbol_char: u8
    };

    const Cell = union(enum) {
        empty: void,
        digit: DigitCell,
        symbol: SymbolCell
    };
};

var map_draw_x: usize = 0;
var map_draw_y: usize = 0;
const font_size = 10;

pub const Solution = struct {
    answer: i32,
    map: *Map,

    pub fn draw(self: *const Solution, allocator: std.mem.Allocator, dt: f32) void {
        _ = dt;

        const draw_width: usize = @min(self.map.width, 60);
        const draw_height: usize = @min(self.map.height, 40);
        const window_size_w = font_size * draw_width;
        const window_size_h = font_size * draw_height;
        const center_window_x = (raylib.screen_w - window_size_w) / 2;
        const center_window_y = (raylib.screen_h - window_size_h) / 2;

        const cam = c.Camera2D{
            .offset = c.Vector2{ .x = @floatFromInt(center_window_x), .y = @floatFromInt(center_window_y) },
            .target = c.Vector2{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = 1,
        };
        c.BeginMode2D(cam);
        defer c.EndMode2D();

        if (c.IsKeyDown(c.KEY_RIGHT) and (map_draw_x + draw_width) < self.map.width) {
            map_draw_x += 1;
        }
        if (c.IsKeyDown(c.KEY_LEFT) and map_draw_x > 0) {
            map_draw_x -= 1;
        }
        if (c.IsKeyDown(c.KEY_UP) and map_draw_y > 0) {
            map_draw_y -= 1;
        }
        if (c.IsKeyDown(c.KEY_DOWN) and (map_draw_y + draw_height) < self.map.height) {
            map_draw_y += 1;
        }

        const map_draw_end_x: usize = @min(self.map.width, map_draw_x + draw_width);
        const map_draw_end_y: usize = @min(self.map.height, map_draw_y + draw_height);

        c.DrawRectangle(0, 0, @intCast(draw_width * font_size), @intCast(draw_height * font_size), c.BLACK);

        for (map_draw_y..map_draw_end_y) |y| {
            for (map_draw_x..map_draw_end_x) |x| {
                const index = self.map.width * y + x;
                const cell = self.map.cells.get(index);
                switch (cell) {
                    .empty => {},
                    .symbol => |symbol| drawChar(x - map_draw_x, y - map_draw_y, symbol.symbol_char, c.WHITE),
                    .digit => |digit| {
                        const number = self.map.numbers.get(digit.whole_number_key);
                        const color = if (number.is_part) c.GREEN else c.RED;
                        drawChar(x - map_draw_x, y - map_draw_y, digit.digit_char, color);
                    }
                }
            }
        }

        raylib.drawAnswer(allocator, 0, -40, 30, c.WHITE, @intCast(self.answer));
    }

    fn drawChar(x: usize, y: usize, char: u8, color: c.Color) void {
        const pos = c.Vector2{
            .x = @as(f32, @floatFromInt(x)) * font_size, 
            .y = @as(f32, @floatFromInt(y)) * font_size 
        };
        c.DrawTextCodepoint(c.GetFontDefault(), char, pos, font_size, color);
    }
};