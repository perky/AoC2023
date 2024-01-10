const std = @import("std");
const raylib = @import("raylib.zig");
const c = raylib.c;

const day01 = @import("day01.zig");
const day02 = @import("day02.zig");
const day03 = @import("day03.zig");
const day04 = @import("day04.zig");

pub fn main() !void {
    c.SetConfigFlags(c.FLAG_MSAA_4X_HINT);
    c.InitWindow(raylib.screen_w, raylib.screen_h, "Advent of Code 2023");
    c.SetTargetFPS(60);

    const allocator = std.heap.c_allocator;
    var days = try std.ArrayList(IDay).initCapacity(allocator, 3);

    const start_process_time = c.GetTime();

    var day01_solution = try day01.process(allocator);
    try days.append(IDay.init(&day01_solution));

    var day02_solution = try day02.process(allocator);
    try days.append(IDay.init(&day02_solution));

    var day03_solution = try day03.process(allocator);
    try days.append(IDay.init(&day03_solution));

    var day04_solution = try day04.process(allocator);
    try days.append(IDay.init(&day04_solution));

    const end_process_time = c.GetTime();
    std.debug.print("process duration: {d:.3}s\n", .{ end_process_time - start_process_time });
    
    var active_day: usize = 0;
    const num_days = days.items.len;

    var snow_particles: [700]raylib.Particle = undefined;
    for (&snow_particles, 0..) |*p, i| {
        const radius = 1.0 + (raylib.randomWholeFloat(0, 100) * 0.01); 
        p.* = raylib.Particle{
            .id = i,
            .lifetime = raylib.randomWholeFloat(0, 100) * 0.01,
            .pos = .{ .x = raylib.randomWholeFloat(0, raylib.screen_w), .y = raylib.randomWholeFloat(0, raylib.screen_h) },
            .vel = .{ .x = 0, .y = 50.0 + (radius * 10.0) },
            .radius = radius
        };
        p.init_pos = p.pos;
        p.init_vel = p.vel;
    }

    const background_img = c.GenImageGradientLinear(raylib.screen_w, raylib.screen_h, 1, c.BLACK, c.GetColor(0x144096));
    const background_tex = c.LoadTextureFromImage(background_img);

    c.InitAudioDevice();
    defer c.CloseAudioDevice();
    var background_music = c.LoadMusicStream("assets/winter_reflections.mp3");
    defer c.UnloadMusicStream(background_music);

    while (!c.WindowShouldClose()) {
        if (c.IsMusicReady(background_music) and !c.IsMusicStreamPlaying(background_music)) {
            c.SetMusicVolume(background_music, 0.05);
            c.PlayMusicStream(background_music);
        }
        c.UpdateMusicStream(background_music);

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.BLACK);
        c.DrawTexture(background_tex, 0, 0, c.WHITE);
        const dt: f32 = c.GetFrameTime();

        if (c.IsKeyPressed(c.KEY_BACKSPACE)) {
            active_day = 0;
        }

        if (active_day != 0 and active_day <= days.items.len) {
            days.items[active_day - 1].draw(allocator, dt);
        } else {
            const contents_w = (100 * 5);
            const contents_h = (50 * 5);
            const buttons_x0: f32 = @floatFromInt((raylib.screen_w - contents_w)/2);
            const buttons_y0: f32 = @floatFromInt((raylib.screen_h - contents_h)/2);
            raylib.beginOffset2D(buttons_x0, buttons_y0);
            for (0..5) |column| {
                for ((column*5 + 1)..(column*5 + 6)) |day| {
                    var buf: [8]u8 = undefined;
                    const label = try std.fmt.bufPrint(&buf, "Day {d}", .{ day });
                    const button_x = (column * 100);
                    const button_y = (day - 1 - (column * 5)) * 50;
                    const text_col = if (day <= num_days) c.WHITE else c.BLACK;
                    if (raylib.button(allocator, label, @intCast(button_x), @intCast(button_y), 90, text_col)) {
                        active_day = day;
                    }
                }
            }
            raylib.endOffset2D();

            // Draw snow.
            var shelfs: [5]raylib.Rect = undefined;
            for (&shelfs, 0..) |*shelf, i| {
                shelf.* = raylib.Rect{
                    .pos = .{ .x = buttons_x0 + (@as(f32, @floatFromInt(i)) * 100), .y = buttons_y0 },
                    .size = .{ .x = 90, .y = 1 }
                };
            }
            raylib.simulateSnow(dt, snow_particles[0..], shelfs[0..]);
            for (snow_particles) |p| {
                c.DrawCircle(@intFromFloat(p.pos.x), @intFromFloat(p.pos.y), p.radius, c.RAYWHITE);
            }
        }
    }

    c.CloseWindow();
}

const IDay = struct {
    ptr: *anyopaque,
    draw_fn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, dt: f32) void,

    pub fn init(ptr: anytype) IDay {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn draw(pointer: *anyopaque, allocator: std.mem.Allocator, dt: f32) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.draw(self, allocator, dt);
            }
        };

        return .{
            .ptr = ptr,
            .draw_fn = gen.draw,
        };
    }
    
    pub fn draw(self: IDay, allocator: std.mem.Allocator, dt: f32) void {
        return self.draw_fn(self.ptr, allocator, dt);
    }
};

