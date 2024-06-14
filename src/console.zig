const fmt = @import("std").fmt;
const Writer = @import("std").io.GenericWriter;

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

pub const ConsoleColors = enum(u8) {
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    LightBrown,
    White,
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(ConsoleColors.LightGray, ConsoleColors.Black);
var buffer = @as([*]volatile u16, @ptrFromInt(0xB8000));

fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
    return @intFromEnum(fg) | (@intFromEnum(bg) << 4);
}

fn vgaEntry(uc: u8, new_color: u8) u16 {
    const c: u16 = new_color;

    return uc | (c << 8);
}

pub fn init() void {
    clear();
}

pub fn setColor(new_color: u8) void {
    color = new_color;
}

pub fn clear() void {
    @memset(buffer[0..VGA_SIZE], vgaEntry(' ', color));
}

pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    buffer[index] = vgaEntry(c, new_color);
}

pub fn putChar(c: u8) void {
    if (c != '\n') {
        putCharAt(c, color, column, row);
    }
    column += 1;

    if (column == VGA_WIDTH or c == '\n') {
        column = 0;
        row += 1;
        if (row == VGA_HEIGHT) {
            scroll();
            row -= 1;
        }
    }
}

pub fn puts(data: []const u8) void {
    for (data) |c|
        putChar(c);
}

pub fn scroll() void {
    for (0..VGA_HEIGHT - 1) |i| {
        const start_line = i * VGA_WIDTH;
        const line_after = (i + 1) * VGA_WIDTH;
        @memcpy(buffer[start_line .. start_line + VGA_WIDTH], buffer[line_after .. line_after + VGA_WIDTH]);
    }
}

pub const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    puts(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
