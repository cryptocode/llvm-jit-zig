const std = @import("std");
const lib = @import("llvm");

// Test-driver for the jit function
pub fn main() !void {
    std.debug.print("1 + 2 = {d}\n", .{try lib.add(1, 2)});
}
