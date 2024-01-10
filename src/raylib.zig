const std = @import("std");
pub const c = @cImport({
    @cInclude("raylib.h");
});

pub const screen_w = 1080;
pub const screen_h = 720;

const null_cam = c.Camera2D{
    .offset = c.Vector2{ .x = 0, .y = 0 },
    .target = c.Vector2{ .x = 0, .y = 0 },
    .rotation = 0,
    .zoom = 1
};
var current_cam = null_cam;

pub fn beginOffset2D(x: f32, y: f32) void {
    var cam = c.Camera2D{
        .offset = c.Vector2{ .x = x, .y = y },
        .target = c.Vector2{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1
    };
    c.BeginMode2D(cam);
    current_cam = cam;
}

pub fn endOffset2D() void {
    c.EndMode2D();
    current_cam = null_cam;
}

pub fn drawText(allocator: std.mem.Allocator, text: []const u8, x: c_int, y: c_int, size: c_int, color: c.Color) void {
    const c_text = allocator.dupeZ(u8, text) catch {
        c.DrawText("MEMORY ALLOC ERROR", x, y, size, color);
        return;
    };
    defer allocator.free(c_text);
    c.DrawText(c_text, x, y, size, color);
}

pub fn getTextWidth(allocator: std.mem.Allocator, text: []const u8, font_size: c_int) c_int {
    const c_text = allocator.dupeZ(u8, text) catch {
        return 0;
    };
    defer allocator.free(c_text);
    return c.MeasureText(c_text, font_size);
}

pub fn drawTextAllocPrint(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype, x: c_int, y: c_int, size: c_int, color: c.Color) void {
    const text = std.fmt.allocPrintZ(allocator, fmt, args) catch {
        c.DrawText("MEMORY ALLOC ERROR", x, y, size, color);
        return;
    };
    defer allocator.free(text);
    c.DrawText(text, x, y, size, color);
}

pub const RectDrawMode = enum {
    fill, stroke
};

pub fn drawRectangle(x: usize, y: usize, w: usize, h: usize, col: c.Color, draw_mode: RectDrawMode) void {
    switch (draw_mode) {
        .fill => c.DrawRectangle(@intCast(x), @intCast(y), @intCast(w), @intCast(h), col),
        .stroke => c.DrawRectangleLines(@intCast(x), @intCast(y), @intCast(w), @intCast(h), col)
    }
}

pub fn drawCodepoint(x: usize, y: usize, codepoint: u8, size: usize, col: c.Color) void {
    const font = c.GetFontDefault();
    const pos = c.Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
    c.DrawTextCodepoint(font, codepoint, pos, @floatFromInt(size), col);
}

pub fn button(allocator: std.mem.Allocator, label: []const u8, x: c_int, y: c_int, w: c_int, text_col: c.Color) bool {
    const font_size = 20;
    const padding = 10;
    const text_width = getTextWidth(allocator, label, font_size);
    const button_width = @max(text_width + (padding*2), w);
    const button_height = font_size + (padding*2);
    const mouse_x = c.GetMouseX() - @as(c_int, @intFromFloat(current_cam.offset.x));
    const mouse_y = c.GetMouseY() - @as(c_int, @intFromFloat(current_cam.offset.y));
    const b_hover = (mouse_x >= x and mouse_x <= x + button_width and mouse_y >= y and mouse_y <= y + button_height);
    const b_click = c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT);
    if (b_hover) {
        c.DrawRectangle(x, y, button_width, button_height, c.GREEN);
    } else {
        c.DrawRectangleLines(x, y, button_width, button_height, c.GREEN);
    }
    drawText(allocator, label, x + padding, y + padding, font_size, text_col);
    return (b_hover and b_click);
}

pub fn drawAnswer(allocator: std.mem.Allocator, x: c_int, y: c_int, font_size: c_int, font_color: c.Color, answer: c_int) void {
    if (c.IsKeyDown(c.KEY_SPACE)) {
            drawTextAllocPrint(
                allocator, 
                "The answer is {d}.", .{ answer }, 
                x, y, font_size, font_color
            );
        }
        if (c.IsKeyReleased(c.KEY_SPACE)) {
            const sum_text = std.fmt.allocPrintZ(allocator, "{d}", .{ answer }) catch "";
            defer allocator.free(sum_text);
            c.SetClipboardText(sum_text);
        }
}

pub fn randomWholeFloat(min: c_int, max: c_int) f32 {
    return @floatFromInt(c.GetRandomValue(min, max));
}

pub const Vec2 = struct{ x: f32 = 0, y: f32 = 0 };

pub const Particle = struct {
    id: usize = 0,
    lifetime: f32 = 0,
    vel: Vec2 = Vec2{},
    init_vel: Vec2 = Vec2{},
    pos: Vec2 = Vec2{},
    init_pos: Vec2 = Vec2{},
    radius: f32 = 1,
};

pub const Rect = struct {
    pos: Vec2 = Vec2{},
    size: Vec2 = Vec2{},

    pub fn isPointInside(self: *const Rect, p: Vec2) bool {
        return (p.x > self.pos.x and p.x < (self.pos.x + self.size.x) 
            and p.y > self.pos.y and p.y < (self.pos.y + self.size.y));
    }
};

pub fn simulateSnow(dt: f32, particles: []Particle, shelfs: []Rect) void {
    for (particles) |*p| {
        p.lifetime += dt;
        p.pos.x += p.vel.x * dt;
        p.pos.y += p.vel.y * dt;

        var b_on_shelf = false;
        for (shelfs) |shelf| {
            if (shelf.isPointInside(p.pos)) {
                b_on_shelf = true;
                p.vel.x = 0;
                p.vel.y = 0;
                break;
            }
        }

        if (!b_on_shelf) {
            const phase: f32 = @as(f32, @floatFromInt(p.id)) * 0.3;
            p.vel.x = std.math.sin(p.lifetime + phase) * 30.0;
        }

        if (p.pos.y > 730 or p.lifetime > 35) {
            p.pos.x = p.init_pos.x;
            p.pos.y = -10;
            p.vel.y = p.init_vel.y;
            p.lifetime = 0;
        }
    }
}