const std = @import("std");
const Lexer = @import("lexer.zig");

pub fn main() !void {
    const source =
        \\+++
        \\--+
        \\!!=
        \\<<<<<<<<
        \\>>>>=>>>>=>>>^^==|||&&===<<====
        \\<><><>><><>==<><<<>><<><>===
        \\ \\\\\\\
        \\ 67 67 67 67 67 67.676767 67.67.67
    ;
    var lexer: Lexer = .init(source[0..]);
    const res = try lexer.lex();
    for (res.items) |token| {
        std.debug.print("{any} on line {d} in pos {d}-{d}\n", .{ token.token_type, token.line, token.position_inside_file[0], token.position_inside_file[1] });
    }
}
