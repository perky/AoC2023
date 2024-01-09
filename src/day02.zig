const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

const Game = struct {
    pub const RunArray = std.BoundedArray(Run, 32);

    id: usize = 0,
    runs: RunArray,

    pub const Run = struct {
        reds: usize = 0,
        greens: usize = 0,
        blues: usize = 0,
    };
};

const Solution = struct {
    
    answer: usize,
    steps: StepArray,
    sim_speed: f32 = 1.0,

    pub const StepArray = std.BoundedArray(Step, 1000);
    pub const Step = struct {
        game_id: usize,
        run_id: usize,
        reds: usize = 0,
        greens: usize = 0,
        blues: usize = 0,
        max_reds: usize = 0,
        max_greens: usize = 0,
        max_blues: usize = 0,
        game_power: usize = 0,
        total_power: usize = 0,
    };

    pub fn draw(self: *Solution, allocator: std.mem.Allocator, dt: f32) void {
        const background_color = c.Color{ .r = 80, .g = 50, .b = 0, .a = 255 };
        const font_size = 40;
        const font_color = c.WHITE;
        c.ClearBackground(background_color);

        self.sim_speed += (dt * 1.5);
        const step_i = blk: {
            const time: f64 = c.GetTime();
            const i: usize = @intFromFloat(std.math.floor(time * self.sim_speed));
            break :blk @min(i, self.steps.len - 1);
        };

        const step: *const Step = &self.steps.constSlice()[step_i];
        raylib.drawTextAllocPrint(
            allocator, 
            "Game {d} run {d}:", .{ step.game_id, step.run_id }, 
            32, 32, font_size, font_color
        );

        raylib.drawTextAllocPrint(
            allocator, 
            "{d} max", .{ step.max_reds }, 
            32, 100, font_size/2, font_color
        );

        raylib.drawTextAllocPrint(
            allocator, 
            "{d} max", .{ step.max_greens }, 
            32, 120, font_size/2, font_color
        );

        raylib.drawTextAllocPrint(
            allocator, 
            "{d} max", .{ step.max_blues }, 
            32, 140, font_size/2, font_color
        );

        raylib.drawTextAllocPrint(
            allocator, 
            "game power: {d}, total power: {d}", .{ step.game_power, step.total_power }, 
            32, 200, font_size, font_color
        );

        for (0..@intCast(step.reds)) |i| {
            const k: i32 = @intCast(i);
            c.DrawRectangle(132 + (k * 15), 100, 10, 10, c.RED);
        }

        for (0..@intCast(step.greens)) |i| {
            const k: i32 = @intCast(i);
            c.DrawRectangle(132 + (k * 15), 120, 10, 10, c.GREEN);
        }

        for (0..@intCast(step.blues)) |i| {
            const k: i32 = @intCast(i);
            c.DrawRectangle(132 + (k * 15), 140, 10, 10, c.BLUE);
        }

        raylib.drawAnswer(allocator, 32, 250, font_size, font_color, @intCast(self.answer));
    }
};

pub fn process(allocator: std.mem.Allocator) !Solution {
    const CubeColour = enum {
        Red, Green, Blue
    };
    var games = try std.BoundedArray(Game, 1000).init(0);

    // Parse input.
    var line_iter = try fs.LineIterator.init(allocator, "day02", false);
    defer line_iter.deinit(allocator);
    while (line_iter.next()) |line| {
        var parser = LineParser.init(line);
        try parser.skipWord("Game");
        try parser.skipWhitespace();
        const game_id = try parser.readNumber(usize);
        try parser.skipChar(':');

        var game = Game{ .id = game_id, .runs = try Game.RunArray.init(0) };
        var game_run = Game.Run{};

        while (!parser.isEnd()) {
            try parser.skipWhitespace();
            const quantity = try parser.readNumber(usize);
            try parser.skipWhitespace();
            const colour_tag = try parser.readEnum(
                CubeColour, 
                &.{ "red", "green", "blue" }, 
                &.{ .Red, .Green, .Blue }
            );
            
            switch (colour_tag) {
                .Red => {
                    game_run.reds += quantity;
                },
                .Green => {
                    game_run.greens += quantity;
                },
                .Blue => {
                    game_run.blues += quantity;
                }
            }

            var b_game_end = false;
            
            if (parser.peekChar() == ',') {
                try parser.skipChar(',');
            } else if (parser.peekChar() == ';') {
                try parser.skipChar(';');
                b_game_end = true;
            } else if (parser.isEnd()) {
                b_game_end = true;
            }

            if (b_game_end) {
                try game.runs.append(game_run);
                game_run = Game.Run{};
            }
        }

        try games.append(game);
    }

    // Solve problem.
    var steps = try Solution.StepArray.init(0);

    var power_sum: usize = 0;
    for (games.constSlice()) |*game| {
        var max_reds: usize = 0;
        var max_greens: usize = 0;
        var max_blues: usize = 0;
        for (game.runs.constSlice(), 0..) |*game_run, game_run_id| {
            max_reds = @max(game_run.reds, max_reds);
            max_greens = @max(game_run.greens, max_greens);
            max_blues = @max(game_run.blues, max_blues);
            const game_power = max_reds * max_greens * max_blues;
            try steps.append(Solution.Step{
                .game_id = game.id,
                .run_id = game_run_id,
                .reds = game_run.reds,
                .greens = game_run.greens,
                .blues = game_run.blues,
                .max_reds = max_reds,
                .max_greens = max_greens,
                .max_blues = max_blues,
                .game_power = game_power,
                .total_power = power_sum + game_power
            });
        }
        const game_power = max_reds * max_greens * max_blues;
        power_sum += game_power;
    }

    return Solution{
        .answer = power_sum,
        .steps = steps
    };
}