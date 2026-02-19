const std = @import("std");
const ArrayList = std.ArrayList;
const TokenList = ArrayList(Token);

const Self = @This();

line: usize = 1,
current: usize = 0,
start: usize = undefined,
source: []const u8 = undefined,
allocator: std.mem.Allocator = undefined,
lexing_error: ?LexError = null,
start_of_line: usize = 0,

var allocator_specific: std.heap.GeneralPurposeAllocator(.{}) = .init;
var token_list: TokenList = .empty;

pub const LexerErrors = error{
    UnexpectedEndOfFile,
    UnexpectedSymbol,
    InvalidEscapeCharacter,
    UnexpectedEndOfLine,
};

pub const LexError = struct {
    kind: LexerErrors,
    line: usize,
    col: usize,
};

pub const TokenType = enum {
    // operators
    BANG,
    EQUAL,
    LESS,
    MORE,
    BANG_EQ,
    EQUAL_EQ,
    LESS_EQ,
    MORE_EQ,
    PLUS,
    MINUS,
    DIV,
    MUL,
    MOD,
    PLUS_EQ,
    MINUS_EQ,
    DIV_EQ,
    MUL_EQ,
    MOD_EQ,
    INCREMENT,
    DECREMENT,

    // BW == Bitwise
    BW_AND,
    BW_OR,
    BW_XOR,
    BW_SHIFT_LEFT,
    BW_SHIFT_RIGHT,
    BW_AND_EQ,
    BW_OR_EQ,
    BW_XOR_EQ,
    BW_SHIFT_LEFT_EQ,
    BW_SHIFT_RIGHT_EQ,

    // basic data types
    INTEGER,
    DOUBLE,
    STRING,

    // identifier
    IDENTIFIER,

    // service things
    BACKSLASH,
    BRACKET_OPEN,
    BRACKET_CLOSE,
    SQUARE_BRACKET_OPEN,
    SQUARE_BRACKET_CLOSE,
    CURLY_BRACKET_OPEN,
    CURLY_BRACKET_CLOSE,
    DOT,
    COMMA,
    SEMICOLON,
    COLON,
    EOF,
};

pub const Token = struct {
    token_type: TokenType,
    line: usize,
    position_inside_file: [2]usize, // [start, current]
    lexem: ?[]u8,
};

pub fn init(source: []const u8) Self {
    token_list = .empty;
    return Self{
        .source = source,
        .allocator = allocator_specific.allocator(),
    };
}

inline fn atEnd(self: Self) bool {
    return self.current >= self.source.len;
}

inline fn atEndErr(self: *Self) !void {
    if (self.atEnd()) return self.fail(error.UnexpectedEndOfFile);
}

fn advance(self: *Self) !u8 {
    try self.atEndErr();
    const char: u8 = self.source[self.current];
    self.current += 1;
    return char;
}

fn peek(self: *Self) !u8 {
    try self.atEndErr();
    return self.source[self.current];
}

fn addToken(self: *Self, token_type: TokenType, line: usize, start: usize, current: usize, lexem: ?[]u8) !void {
    const token = Token{ .line = line, .position_inside_file = [_]usize{ start, current }, .token_type = token_type, .lexem = lexem };
    try token_list.append(self.allocator, token);
}

fn match(self: *Self, expected: u8) !bool {
    const next = self.peek() catch {
        return false;
    };
    const res = next == expected;
    if (res) _ = try self.advance();
    return res;
}

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn matchEqual(self: *Self, token_if_match: TokenType, token_if_not_match: TokenType) !TokenType {
    return if (try self.match('=')) token_if_match else token_if_not_match;
}

fn number(self: *Self) !TokenType {
    var dot_seen = false;
    while (true) {
        const char: u8 = self.peek() catch 0;
        if (char == '.') {
            if (dot_seen) {
                try self.fail(error.UnexpectedSymbol);
                return .EOF;
            }
            _ = try self.advance();
            dot_seen = true;
            continue;
        }
        if (!isDigit(char)) {
            if (isAlphaNumericUnderscore(char)) {
                try self.fail(error.UnexpectedSymbol);
            }
            return if (dot_seen) .DOUBLE else .INTEGER;
        } else {
            _ = try self.advance();
        }
    }
}

fn string(self: *Self, str: *?[]u8) !TokenType {
    var str_inner: ArrayList(u8) = .empty;
    while (try self.peek() != '"') {
        var c: u8 = try self.advance();
        if (c == '\n') {
            self.current -= 1;
            try self.fail(error.UnexpectedEndOfLine);
        }
        if (c == '\\') {
            const char = try self.advance();
            c = switch (char) {
                'a' => 0x07,
                'b' => 0x08,
                'e' => 0x1B,
                'f' => 0x0C,
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'v' => 0x0B,
                '\\' => '\\',
                '\'' => '\'',
                '\"' => '\"',
                '?' => 0x3F,
                else => blk: {
                    try self.fail(error.InvalidEscapeCharacter);
                    break :blk 0x00;
                },
            };
        }
        try str_inner.append(self.allocator, c);
    }
    _ = try self.advance();
    str.* = str_inner.items;
    return .STRING;
}

fn isAlphaNumericUnderscore(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn fail(self: *Self, kind: LexerErrors) !void {
    self.lexing_error = .{ .col = self.current - self.start_of_line + 1, .kind = kind, .line = self.line };
    return kind;
}

fn identifier(self: *Self) !TokenType {
    while (true) {
        const c = self.peek() catch 0;
        if (!isAlphaNumericUnderscore(c)) break;
        _ = try self.advance();
    }
    return .IDENTIFIER;
}

fn goToEndOfLine(self: *Self) void {
    while (self.peek() catch '\n' != '\n') {
        _ = self.advance() catch 0;
    }
}

pub fn formatError(self: *Self, writer: *std.Io.Writer) !void {
    if (self.lexing_error == null) return error.NoErrorProduced;
    const err = self.lexing_error.?;

    const spaces = try self.allocator.alloc(u8, 7 + err.col - 1);
    @memset(spaces, ' ');

    self.goToEndOfLine();

    const error_message = try std.fmt.allocPrint(self.allocator,
        \\{any} at {d}:{d}
        \\{d: >5}| {s}
        \\{s}^
        \\
        \\
        \\
    , .{ err.kind, err.line, err.col, err.line, self.source[self.start_of_line..self.current], spaces });
    try writer.writeAll(error_message[0..]);
    try writer.flush();
}

pub fn lex(self: *Self) !TokenList {
    while (!self.atEnd()) {
        // Only string has such thing cause "\\\\" != \\\\; "\\\\" == \\
        var lexem: ?[]u8 = null;
        const c: u8 = try self.advance();
        self.start = self.current;
        const newToken = switch (c) {
            ' ', '\t', '\r' => {
                continue;
            },
            '\n' => {
                self.line += 1;
                self.start_of_line = self.current;
                continue;
            },
            '!' => try self.matchEqual(.BANG_EQ, .BANG),
            '<' => if (try self.match('<'))
                try self.matchEqual(.BW_SHIFT_LEFT_EQ, .BW_SHIFT_LEFT)
            else
                try self.matchEqual(.LESS_EQ, .LESS),
            '>' => if (try self.match('>'))
                try self.matchEqual(.BW_SHIFT_RIGHT_EQ, .BW_SHIFT_RIGHT)
            else
                try self.matchEqual(.MORE_EQ, .MORE),
            '=' => try self.matchEqual(.EQUAL_EQ, .EQUAL),
            '+' => if (try self.match('+')) .INCREMENT else try self.matchEqual(.PLUS_EQ, .PLUS),
            '-' => if (try self.match('-')) .DECREMENT else try self.matchEqual(.MINUS_EQ, .MINUS),
            '/' => try self.matchEqual(.DIV_EQ, .DIV),
            '*' => try self.matchEqual(.MUL_EQ, .MUL),
            '%' => try self.matchEqual(.MOD_EQ, .MOD),
            '&' => try self.matchEqual(.BW_AND_EQ, .BW_AND),
            '|' => try self.matchEqual(.BW_OR_EQ, .BW_OR),
            '^' => try self.matchEqual(.BW_XOR_EQ, .BW_XOR),
            '\\' => .BACKSLASH,
            '(' => .BRACKET_OPEN,
            ')' => .BRACKET_CLOSE,
            '[' => .SQUARE_BRACKET_OPEN,
            ']' => .SQUARE_BRACKET_CLOSE,
            '{' => .CURLY_BRACKET_OPEN,
            '}' => .CURLY_BRACKET_CLOSE,
            '.' => .DOT,
            ',' => .COMMA,
            ';' => .SEMICOLON,
            ':' => .COLON,
            '0'...'9' => try self.number(),
            '"' => try self.string(&lexem),
            'a'...'z', 'A'...'Z', '_' => try self.identifier(),
            else => blk: {
                self.current -= 1;
                try self.fail(error.UnexpectedSymbol);
                break :blk .EOF;
            },
        };
        try self.addToken(newToken, self.line, self.start, self.current, lexem);
    }
    try self.addToken(.EOF, self.line, self.current, self.current, null);
    return token_list;
}

fn expectTokens(source: []const u8, expected: []const TokenType) !void {
    var lexer: Self = .init(source);
    const tokens = try lexer.lex();
    // std.debug.print("{any}", .{tokens.items});
    try std.testing.expectEqual(expected.len + 1, tokens.items.len); // +1 for EOF
    for (expected, 0..) |expected_type, i| {
        try std.testing.expectEqual(expected_type, tokens.items[i].token_type);
    }
}

test "operators" {
    try expectTokens("+ - * /", &.{ .PLUS, .MINUS, .MUL, .DIV });
    try expectTokens("++ --", &.{ .INCREMENT, .DECREMENT });
    try expectTokens("+= -= *= /=", &.{ .PLUS_EQ, .MINUS_EQ, .MUL_EQ, .DIV_EQ });
}

test "comparison operators" {
    try expectTokens("< > <= >= == !=", &.{ .LESS, .MORE, .LESS_EQ, .MORE_EQ, .EQUAL_EQ, .BANG_EQ });
}

test "bitwise shift" {
    try expectTokens("<< >> <<= >>=", &.{ .BW_SHIFT_LEFT, .BW_SHIFT_RIGHT, .BW_SHIFT_LEFT_EQ, .BW_SHIFT_RIGHT_EQ });
}

test "string with escape sequences" {
    try expectTokens("\"hello\\nworld\"", &.{.STRING});

    var lexer: Self = .init("\"hello\\nworld\"");
    const tokens = try lexer.lex();
    try std.testing.expectEqualStrings("hello\nworld", tokens.items[0].lexem.?);
}

test "number types" {
    try expectTokens("42", &.{.INTEGER});
    try expectTokens("3.14", &.{.DOUBLE});
}

test "error cases" {
    var lexer: Self = .init("\"unterminated");
    try std.testing.expectError(error.UnexpectedEndOfFile, lexer.lex());

    var lexer2: Self = .init("\"bad\\ escape\"");
    try std.testing.expectError(error.InvalidEscapeCharacter, lexer2.lex());

    var lexer3: Self = .init("1.2.3");
    try std.testing.expectError(error.UnexpectedSymbol, lexer3.lex());
}

test "line tracking" {
    var lexer: Self = .init("a\nb");
    const tokens = try lexer.lex();
    try std.testing.expectEqual(@as(usize, 1), tokens.items[0].line);
    try std.testing.expectEqual(@as(usize, 2), tokens.items[1].line);
}
