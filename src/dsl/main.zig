const std = @import("std");
const Lexer = @import("lexer.zig");

pub fn main() !void {
    const source =
        \\ pub fn meow(arg1: i32) void {
        \\     if (arg1 != 3.1415 and 3 | 2 == 7) {
        \\         print("nya");
        \\     }
        \\     print("{}", arg1);
        \\ }
    ;
    var lexer: Lexer = .init(source[0..]);
    const res = lexer.lex() catch {
        var buf: [1024]u8 = undefined;
        var writer_specific = std.fs.File.stdout().writer(&buf);
        const writer: *std.Io.Writer = &writer_specific.interface;

        try lexer.formatError(writer);
        return error.LexerFailed;
    };
    for (res.items) |token| {
        std.debug.print("{s} on line {d} in pos {d}-{d} {s} {s}\n", .{ @tagName(token.token_type), token.line, token.position_inside_file[0], token.position_inside_file[1], source[token.position_inside_file[0] - 1 .. token.position_inside_file[1]], token.lexem orelse "null" });
    }
}
