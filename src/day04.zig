const std = @import("std");
const LineParser = @import("LineParser.zig");
const fs = @import("fs.zig");
const raylib = @import("raylib.zig");
const c = raylib.c;

const Card = struct {
    id: usize,
    winning_numbers: [MAX_NUM]bool = undefined,
    matched_numbers: [MAX_NUM]bool = undefined,
    played_numbers: NumberArray,
    matches: usize = 0,
    instances: usize = 1,

    const MAX_NUM = 100;
    const NumberArray = std.BoundedArray(u32, 50);

    pub fn init(id: usize) !Card {
        return Card{
            .id = id,
            .winning_numbers = std.mem.zeroes([MAX_NUM]bool),
            .matched_numbers = std.mem.zeroes([MAX_NUM]bool),
            .played_numbers = try NumberArray.init(0),
        };
    }
};

pub fn process(allocator: std.mem.Allocator) !Solution {
    var solution = Solution{ 
        .answer = 0,
        .cards = try Solution.CardArray.init(0)
    };

    // Parses the input.
    var line_iter = try fs.LineIterator.init(allocator, "day04", false);
    while (line_iter.next()) |line| {
        var parser = LineParser.init(line);

        try parser.skipWord("Card");
        try parser.skipWhitespace();
        const card_id = try parser.readNumber(usize);
        var card = try Card.init(card_id);

        try parser.skipChar(':');
        try parser.skipWhitespace();

        while (parser.peekChar() != '|') {
            const number = try parser.readNumber(u32);
            card.winning_numbers[number] = true;
            parser.skipWhitespace() catch {};
        }

        try parser.skipChar('|');
        try parser.skipWhitespace();

        while (!parser.isEnd()) {
            const number = try parser.readNumber(u32);
            try card.played_numbers.append(number);
            parser.skipWhitespace() catch {};
        }

        try solution.cards.append(card);
    }

    // Check each card.
    for (solution.cards.slice(), 0..) |*card, card_i| {
        solution.answer += @intCast(card.instances);

        for (card.played_numbers.constSlice()) |played_number| {
            const is_match = card.winning_numbers[played_number];
            card.matched_numbers[played_number] = is_match;
            if (is_match) {
                card.matches += 1;
            }
        }

        if (card.matches > 0) {
            for (0..card.matches) |i| {
                const next_card_i = card_i + i + 1;
                solution.cards.buffer[next_card_i].instances += card.instances;
            }
        }
    }
    
    return solution;
}

var time: f32 = 0.0;

pub const Solution = struct {
    answer: i32,
    cards: CardArray,

    const CardArray = std.BoundedArray(Card, 256);

    pub fn draw(self: *const Solution, allocator: std.mem.Allocator, dt: f32) void {
        const font_size = 20;
        const font_size_small = 10;
        time += dt;

        raylib.drawAnswer(allocator, 10, 10, 10, c.WHITE, @intCast(self.answer));

        raylib.beginOffset2D(300, -(time*100.0));
        defer raylib.endOffset2D();

        for (self.cards.constSlice(), 0..) |card, y| {
            const y_pos: usize = (y * font_size * 4) + 10;
            raylib.drawTextAllocPrint(
                allocator, 
                "{d}x Card {d}.    {d} matches.", 
                .{ card.instances, card.id, card.matches }, 
                10, 
                @intCast(y_pos), 
                font_size, 
                c.WHITE
            );

            var x_i: usize = 0;
            for (card.winning_numbers, 0..) |is_winning, number| {
                if (!is_winning) {
                    continue;
                }

                const x_pos: usize = (x_i * (font_size_small + 20)) + 10;
                x_i += 1;
                const color = if (card.matched_numbers[number]) c.GREEN else c.RED;
                raylib.drawTextAllocPrint(
                    allocator, 
                    "{d}", 
                    .{ number }, 
                    @intCast(x_pos), 
                    @intCast(y_pos + font_size), 
                    font_size_small, 
                    color
                );
            }

            for (card.played_numbers.constSlice(), 0..) |number, i| {
                const x_pos: usize = (i * (font_size_small + 20)) + 10;
                const color = if (card.matched_numbers[number]) c.GREEN else c.RED;
                raylib.drawTextAllocPrint(
                    allocator, 
                    "{d}", 
                    .{ number }, 
                    @intCast(x_pos), 
                    @intCast(y_pos + font_size + font_size_small), 
                    font_size_small, 
                    color
                );
            }
        }
    }
};