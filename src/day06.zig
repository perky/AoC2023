const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

const U64Array = std.BoundedArray(u64, 16);
const RaceArray = std.BoundedArray(Race, 16);

const Race = struct {
    time: u64,
    distance: u64,
    ways_to_win: i32 = 0,
    button_time_lower_bound: u64 = std.math.maxInt(u64),
    button_time_upper_bound: u64 = 0,
};

pub fn process(allocator: std.mem.Allocator) !Solution {
    // Parsing the input.
    var line_iter = try fs.LineIterator.init(allocator, "day06", false);
    var time_list = try U64Array.init(0);
    var distance_list = try U64Array.init(0);
    var race_list = try RaceArray.init(0);

    if (line_iter.next()) |line_1| {
        var parser = LineParser.init(line_1);
        try parser.skipWord("Time:");
        try parser.skipWhitespace();
        const number = try readNumberIgnoringWhitespace(&parser, u64);
        try time_list.append(number);
    }

    if (line_iter.next()) |line_2| {
        var parser = LineParser.init(line_2);
        try parser.skipWord("Distance:");
        try parser.skipWhitespace();
        const number = try readNumberIgnoringWhitespace(&parser, u64);
        try distance_list.append(number);
    }

    for (time_list.constSlice(), distance_list.constSlice()) |time_val, distance_val| {
        const race = Race{
            .time = time_val,
            .distance = distance_val
        };
        try race_list.append(race);
    }

    // Compute the solution.
    for (race_list.slice()) |*race| {
        for (1..race.time) |i| {
            const button_time: u64 = @intCast(i);
            const move_time = race.time - button_time;
            const distance_traveled = button_time * move_time;
            if (distance_traveled > race.distance) {
                race.ways_to_win += 1;
                if (button_time < race.button_time_lower_bound) {
                    race.button_time_lower_bound = button_time;
                } else if (button_time > race.button_time_upper_bound) {
                    race.button_time_upper_bound = button_time;
                }
            }
        }
    }

    var answer: i32 = 1;
    for (race_list.constSlice()) |race| {
        answer *= race.ways_to_win;
    }
    
    var solution = Solution{ 
        .answer = answer,
        .race_list = race_list,
    };
    return solution;
}

fn readNumberIgnoringWhitespace(parser: *LineParser, comptime T: type) !T {
    var char_buf: [32]u8 = undefined;
    var char_cursor: usize = 0;
    while (!parser.isEnd()) {
        const char = parser.peekChar();
        if (std.ascii.isDigit(char)) {
            char_buf[char_cursor] = char;
            char_cursor += 1;
        }
        try parser.advanceCursor();
    }
    return try std.fmt.parseInt(T, char_buf[0..char_cursor], 10);
}

pub const Solution = struct {
    answer: i32,
    race_list: RaceArray,

    boat_tex: c.Texture2D = undefined,
    race_timer_ms: f32 = 0,
    boat_x: [10]f32 = undefined,

    pub fn load(self: *Solution, _: std.mem.Allocator) void {
        const boat_file = "assets/boat/blue.png";
        var boat_img = c.LoadImage(boat_file);
        c.ImageFlipHorizontal(&boat_img);
        self.boat_tex = c.LoadTextureFromImage(boat_img);

        for (0..self.boat_x.len) |i| {
            self.boat_x[i] = 0;
        }
    }

    pub fn draw(self: *Solution, allocator: std.mem.Allocator, dt: f32) void {
        raylib.drawAnswer(allocator, 400, 10, 30, c.WHITE, @intCast(self.answer));

        const race = self.race_list.buffer[0];
        const race_time: f32 = @floatFromInt(race.time);
        const is_race_on = (self.race_timer_ms < race_time);
        if (is_race_on) {
            self.race_timer_ms += (dt * 5000000);
        }

        raylib.drawTextAllocPrint(
            allocator, 
            "Race time: {d}ms/{d}ms", 
            .{ @trunc(self.race_timer_ms), race.time }, 
            10, 
            10, 
            20, 
            c.GREEN
        );

        if (c.IsKeyReleased(c.KEY_SPACE)) {
            self.race_timer_ms = 0;
            for (0..self.boat_x.len) |i| {
                self.boat_x[i] = 0;
            }
        }

        for (self.boat_x, 0..) |x_pos, i| {
            const y_index: f32 = @floatFromInt(i);
            const y_pos = (y_index * 65) + 30;

            const boat_button_time = (race_time / self.boat_x.len) * y_index;
            const is_boat_moving = (self.race_timer_ms >= boat_button_time) and is_race_on;
            const boat_color = if (is_boat_moving) c.RED else c.WHITE;

            if (is_boat_moving) {
                self.boat_x[i] += (dt * boat_button_time) / 100_000;
            }

            const final_x_pos = x_pos + 10;
            c.DrawTextureEx(self.boat_tex, c.Vector2{.x = final_x_pos, .y = y_pos}, 0, 0.05, boat_color);

            raylib.drawTextAllocPrint(
                allocator, 
                "{d}ms", 
                .{ boat_button_time }, 
                @intFromFloat(final_x_pos), 
                @intFromFloat(y_pos + 50), 
                10, 
                c.WHITE
            );
        }

    }
};