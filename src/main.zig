const console = @import("console.zig");
const std = @import("std");

const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

const MultibootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32,
    checksum: i32,
};

export var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};
export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
const stack_bytes_slice = stack_bytes[0..];

export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\ movl %[stk], %esp
        \\ movl %esp, %ebp
        \\ call kmain
        :
        : [stk] "{ecx}" (@intFromPtr(&stack_bytes_slice) + @sizeOf(@TypeOf(stack_bytes_slice))),
    );

    while (true) {}
}

export fn kmain() void {
    console.init();
    console.puts("Hello World!");

    for (0..100) |i| {
        console.printf("{}\n", .{i});
    }
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, size: ?usize) noreturn {
    _ = error_return_trace; // autofix
    _ = size;
    @setCold(true);

    //error_return_trace.?.format(comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype)
    console.setColor(@intFromEnum(console.ConsoleColors.Red));
    console.printf("\nCRITICAL PANIC OCCURED: {s}", .{msg});

    while (true) {}
}
