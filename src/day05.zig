const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

const CATEGORIES = [_][]const u8 {
    "seed-to-soil",
    "soil-to-fertilizer",
    "fertilizer-to-water",
    "water-to-light",
    "light-to-temperature",
    "temperature-to-humidity",
    "humidity-to-location"
};

const Almanac = struct {
    seeds: SeedRangeArray,
    id_ranges: IdRangeArray,
    highest_id: usize = 0,
    category_count: usize = 0,
    map_lines: MapLineArray,

    const SeedRange = struct {
        category_id: usize,
        initial_seed_id: usize,
        id_begin: usize,
        range_len: usize,
    };

    const IdRange = struct {
        category: []const u8 = "n/a",
        category_id: usize = 0,
        destination_id_begin: usize,
        source_id_begin: usize,
        range_len: usize,

        pub fn sourceIdEnd(self: *const IdRange) usize {
            return self.source_id_begin + self.range_len;
        }

        pub fn destinationIdEnd(self: *const IdRange) usize {
            return self.destination_id_begin + self.range_len;
        }

        pub fn destinationIdFromSourceId(self: *const IdRange, source_id: usize) ?usize {
            const source_id_end = self.sourceIdEnd();
            if (source_id >= self.source_id_begin and source_id < source_id_end) {
                const source_id_offset = source_id - self.source_id_begin;
                return self.destination_id_begin + source_id_offset;
            } else {
                return null;
            }
        }
    };

    const MapLine = struct {
        category_id: usize,
        initial_seed_id: usize,
        from: usize,
        to: usize,
    };

    const IdArray = std.BoundedArray(usize, 64);
    const IdRangeArray = std.BoundedArray(IdRange, 1024);
    const SeedRangeArray = std.BoundedArray(SeedRange, 1024);
    const MapLineArray = std.BoundedArray(MapLine, 2048);

    pub fn init(self: *Almanac) !void {
        self.* = .{
            .seeds = try SeedRangeArray.init(0),
            .id_ranges = try IdRangeArray.init(0),
            .map_lines = try MapLineArray.init(0),
        };
    }
};

pub fn process(allocator: std.mem.Allocator) !Solution {
    var almanac = try allocator.create(Almanac);
    try almanac.init();

    // Parse seed ids.
    var line_iter = try fs.LineIterator.init(allocator, "day05", false);
    if (line_iter.next()) |line| {
        var parser = LineParser.init(line);
        try parser.skipWord("seeds:");
        
        var seed_i: usize = 0;
        var seed_id_begin: usize = 0;
        while (!parser.isEnd()) : (seed_i += 1) {
            try parser.skipWhitespace();
            const number = try parser.readNumber(usize);
            if (seed_i % 2 == 0) {
                seed_id_begin = number;
            } else {
                const seed_range_len = number;
                var seed_range = Almanac.SeedRange{
                    .category_id = 0,
                    .initial_seed_id = seed_id_begin,
                    .id_begin = seed_id_begin,
                    .range_len = seed_range_len
                };
                try almanac.seeds.append(seed_range);
            }
        }
    }

    // Parse category maps.
    var next_category_id: usize = 0;
    var current_category_id: usize = 0;
    var current_category_name: []const u8 = undefined;
    var map_title_buffer: [64]u8 = undefined;
    while (line_iter.next()) |line| {
        var parser = LineParser.init(line);
        if (std.ascii.isAlphabetic(line[0])) {
            current_category_id = next_category_id;
            current_category_name = CATEGORIES[next_category_id];
            const map_title = try std.fmt.bufPrint(&map_title_buffer, "{s} map:", .{ current_category_name });
            try parser.skipWord(map_title);
            next_category_id += 1;
        } else if (std.ascii.isDigit(line[0])) {
            const destination_id = try parser.readNumber(usize);
            try parser.skipWhitespace();
            const source_id = try parser.readNumber(usize);
            try parser.skipWhitespace();
            const range_len = try parser.readNumber(usize);
            var id_range = Almanac.IdRange{
                .category = current_category_name,
                .category_id = current_category_id,
                .destination_id_begin = destination_id,
                .source_id_begin = source_id,
                .range_len = range_len
            };
            try almanac.id_ranges.append(id_range);
        } else {
            return error.InvalidPuzzleInput;
        }
    }
    almanac.category_count = next_category_id;

    // Compute the lowest location id.
    var lowest_location_id: usize = std.math.maxInt(usize);
    var seeds = almanac.seeds;
    while (seeds.popOrNull()) |seed_range| {
        const initial_seed_id = seed_range.initial_seed_id;

        var seed_begin = seed_range.id_begin;
        var seed_len = seed_range.range_len;
        var seed_end = seed_begin + seed_len;

        for (seed_range.category_id..almanac.category_count) |category_id| {
            for (almanac.id_ranges.constSlice()) |id_range| {
                if (id_range.category_id != category_id) {
                    continue;
                }
                
                const source_id_begin = id_range.source_id_begin;
                const source_id_end = id_range.sourceIdEnd();
                const seed_begin_inside = (seed_begin >= source_id_begin and seed_begin < source_id_end);
                const seed_end_inside = (seed_end >= source_id_begin and seed_end < source_id_end);

                const prev_seed_begin = seed_begin;
                const prev_seed_end = seed_end;
                var chop_front = false;
                var chop_end = false;

                if ((seed_begin < source_id_begin and seed_end <= source_id_begin) 
                or  (seed_begin >= source_id_end and seed_end >= source_id_end)) {
                    // Case 0: the entire seed range is outside the source range.
                    continue;
                } else if (seed_begin_inside and seed_end_inside) {
                    // Case 1: the entire seed range fits inside source range.
                    seed_begin = id_range.destinationIdFromSourceId(seed_begin) orelse seed_begin;
                } else if (!seed_begin_inside and seed_end_inside) {
                    // Case 2: only end portion of seed range overlaps source range.
                    seed_len = seed_end - source_id_begin;
                    seed_begin = id_range.destinationIdFromSourceId(source_id_begin) orelse source_id_begin;
                    chop_front = true;
                } else if (seed_begin_inside and !seed_end_inside) {
                    // Case 3: only front portion of seed range overlaps source range.
                    seed_len = source_id_end - seed_begin;
                    seed_begin = id_range.destinationIdFromSourceId(seed_begin) orelse seed_begin;
                    chop_end = true;
                } else if (!seed_begin_inside and !seed_end_inside) {
                    // Case 4: only middle portion of seed range overlaps source range.
                    seed_len = id_range.range_len;
                    seed_begin = id_range.destinationIdFromSourceId(source_id_begin) orelse source_id_begin;
                    chop_front = true;
                    chop_end = true;
                } else {
                    unreachable;
                }

                seed_end = seed_begin + seed_len;

                if (chop_front) {
                    const chop_range_begin = prev_seed_begin;
                    const chop_range_end = source_id_begin;
                    const chop_range = Almanac.SeedRange{
                        .category_id = category_id,
                        .initial_seed_id = initial_seed_id,
                        .id_begin = chop_range_begin,
                        .range_len = chop_range_end - chop_range_begin
                    };
                    try seeds.append(chop_range);
                }
                if (chop_end) {
                    const chop_range_begin = source_id_end;
                    const chop_range_end = prev_seed_end;
                    const chop_range = Almanac.SeedRange{
                        .category_id = category_id,
                        .initial_seed_id = initial_seed_id,
                        .id_begin = chop_range_begin,
                        .range_len = chop_range_end - chop_range_begin
                    };
                    try seeds.append(chop_range);
                }
                
                try almanac.map_lines.append(.{
                    .category_id = category_id,
                    .initial_seed_id = initial_seed_id,
                    .from = prev_seed_begin,
                    .to = seed_begin
                });
                break;
            }
        }

        const location_id = seed_begin;
        if (location_id < lowest_location_id) {
            lowest_location_id = location_id;
        }
    }

    // Compute the highest id.
    for (almanac.id_ranges.constSlice()) |id_range| {
        const dst_end = id_range.destination_id_begin + id_range.range_len;
        const src_end = id_range.source_id_begin + id_range.range_len;
        if (dst_end > almanac.highest_id) {
            almanac.highest_id = dst_end;
        }
        if (src_end > almanac.highest_id) {
            almanac.highest_id = src_end;
        }
    }
    
    var solution = Solution{ 
        .answer = @intCast(lowest_location_id),
        .almanac = almanac
    };
    return solution;
}

pub const Solution = struct {
    answer: i32,
    almanac: *Almanac,

    const line_thickness = 8;
    const outer_spacing = 80;
    const inner_spacing = 25;

    const BaseLines = struct {
        src_begin: c.Vector2,
        src_end: c.Vector2,
        dst_begin: c.Vector2,
        dst_end: c.Vector2
    };

    fn getBaseLinesForCategory(category_id: usize) BaseLines {
        const line_y_offset = 20;
        const y: f32 = (@as(f32, @floatFromInt(category_id)) * outer_spacing) + outer_spacing;
        return .{
            .src_begin = c.Vector2{ .x = 0, .y = y + line_y_offset },
            .src_end = c.Vector2{ .x = raylib.screen_w, .y = y + line_y_offset },
            .dst_begin = c.Vector2{ .x = 0, .y = inner_spacing + y + line_y_offset },
            .dst_end = c.Vector2{ .x = raylib.screen_w, .y = inner_spacing + y + line_y_offset }
        };
    }

    fn getScreenXForId(id: usize, id_width: f32) f32 {
        const id_begin: f32 = @floatFromInt(id);
        return (id_begin / id_width) * raylib.screen_w;
    }

    pub fn draw(self: *const Solution, allocator: std.mem.Allocator, dt: f32) void {
        _ = dt;

        const background_color = c.Color{ .r = 80, .g = 50, .b = 0, .a = 255 };
        c.ClearBackground(background_color);

        raylib.drawAnswer(allocator, 10, 10, 30, c.WHITE, @intCast(self.answer));

        raylib.beginOffset2D(0, 10);
        defer raylib.endOffset2D();

        const mouse_pos = raylib.mousePosition();
        const id_width: f32 = @floatFromInt(self.almanac.highest_id);

        for (CATEGORIES, 0..) |category_name, category_id| {
            const y: f32 = (@as(f32, @floatFromInt(category_id)) * outer_spacing) + outer_spacing;
            raylib.drawText(allocator, category_name, 10, @intFromFloat(y), 10, c.WHITE);
            
            const base_lines = getBaseLinesForCategory(category_id);
            c.DrawLineEx(base_lines.src_begin, base_lines.src_end, 1, c.WHITE);
            c.DrawLineEx(base_lines.dst_begin, base_lines.dst_end, 1, c.WHITE);

            var highlight_src_begin: ?c.Vector2 = null;
            var highlight_src_end: ?c.Vector2 = null;
            var highlight_dst_begin: ?c.Vector2 = null;
            var highlight_dst_end: ?c.Vector2 = null;

            for (self.almanac.id_ranges.constSlice()) |id_range| {
                if (id_range.category_id != category_id) {
                    continue;
                }

                const src_line_begin = c.Vector2{
                    .x = getScreenXForId(id_range.source_id_begin, id_width),
                    .y = base_lines.src_begin.y
                };
                const src_line_end = c.Vector2{
                    .x = getScreenXForId(id_range.sourceIdEnd(), id_width),
                    .y = base_lines.src_begin.y
                };
                const dst_line_begin = c.Vector2{
                    .x = getScreenXForId(id_range.destination_id_begin, id_width),
                    .y = base_lines.dst_begin.y
                };
                const dst_line_end = c.Vector2{
                    .x = getScreenXForId(id_range.destinationIdEnd(), id_width),
                    .y = base_lines.dst_begin.y
                };

                const line_check_threshold = 6;
                const is_on_line = (
                    c.CheckCollisionPointLine(mouse_pos, src_line_begin, src_line_end, line_check_threshold)
                    or
                    c.CheckCollisionPointLine(mouse_pos, dst_line_begin, dst_line_end, line_check_threshold)
                );
                const src_color = if (is_on_line) c.ORANGE else c.GREEN;
                c.DrawLineEx(src_line_begin, src_line_end, line_thickness, src_color);

                const dst_color = if (is_on_line) c.RED else c.BLUE;
                c.DrawLineEx(dst_line_begin, dst_line_end, line_thickness, dst_color);

                if (is_on_line) {
                    highlight_src_begin = src_line_begin;
                    highlight_src_end = src_line_end;
                    highlight_dst_begin = dst_line_begin;
                    highlight_dst_end = dst_line_end;
                    
                }
            }

            if (highlight_src_begin != null) {
                c.DrawLineEx(highlight_src_begin.?, highlight_dst_begin.?, 1, c.ORANGE);
                c.DrawLineEx(highlight_src_end.?, highlight_dst_end.?, 1, c.ORANGE);
            }
        }

        for (self.almanac.seeds.constSlice()) |seed_range| {
            const seed_id = seed_range.id_begin;
            const seed_len = seed_range.range_len;

            raylib.drawText(allocator, "seeds", 10, 0, 10, c.WHITE);

            const y: f32 = 20;
            const seed_line_begin = c.Vector2{
                .x = getScreenXForId(seed_id, id_width),
                .y = y
            };
            const seed_line_end = c.Vector2{
                .x = getScreenXForId(seed_id + seed_len, id_width),
                .y = y
            };

            const is_on_seed = c.CheckCollisionPointLine(
                mouse_pos, 
                seed_line_begin, 
                seed_line_end, 
                10
            );

            const seed_color = if (is_on_seed) c.ORANGE else c.YELLOW;
            c.DrawLineEx(seed_line_begin, seed_line_end, line_thickness, seed_color);

            if (is_on_seed) {
                { // Draw initial seed line.
                    const base = getBaseLinesForCategory(0);
                    const to_src_begin = c.Vector2{ 
                        .x = getScreenXForId(seed_id, id_width), 
                        .y = seed_line_begin.y
                    };
                    const to_src_end = c.Vector2{
                        .x = getScreenXForId(seed_id, id_width), 
                        .y = base.src_begin.y
                    };
                    c.DrawLineEx(to_src_begin, to_src_end, 1, c.ORANGE);
                }

                for (self.almanac.map_lines.constSlice()) |map_line| {
                    if (map_line.initial_seed_id != seed_id) {
                        continue;
                    }

                    const base = getBaseLinesForCategory(map_line.category_id);
                    const to_dst_begin = c.Vector2{ 
                        .x = getScreenXForId(map_line.from, id_width), 
                        .y = base.src_begin.y
                    };
                    const to_dst_end = c.Vector2{
                        .x = getScreenXForId(map_line.to, id_width), 
                        .y = base.dst_begin.y
                    };
                    c.DrawLineEx(to_dst_begin, to_dst_end, 1, c.ORANGE);

                    const base_1 = getBaseLinesForCategory(map_line.category_id + 1);
                    const to_src_begin = to_dst_end;
                    const to_src_end = c.Vector2{
                        .x = to_dst_end.x, 
                        .y = base_1.src_begin.y
                    };
                    c.DrawLineEx(to_src_begin, to_src_end, 1, c.ORANGE);
                }
            }
        }

    }
};