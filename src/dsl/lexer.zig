const std = @import("std");
const ArrayList = std.ArrayList;
const TokenList = ArrayList(Token);

const Self = @This();

line: usize = 1,
current: usize = 0,
start: usize = undefined,
source: []const u8 = undefined,
allocator: std.mem.Allocator = undefined,

var allocator_specific: std.heap.GeneralPurposeAllocator(.{}) = .init;
var token_list: TokenList = .empty;

pub const LexerErrors = error{
    EndOfFile,
    UnexpectedSymbol,
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
    return Self{
        .source = source,
        .allocator = allocator_specific.allocator(),
    };
}

fn atEnd(self: Self) bool {
    return self.current >= self.source.len;
}

inline fn atEndErr(self: Self) LexerErrors!void {
    if (self.atEnd()) return error.EndOfFile;
}

fn advance(self: *Self) LexerErrors!u8 {
    try self.atEndErr();
    const char: u8 = self.source[self.current];
    self.current += 1;
    return char;
}

fn peek(self: Self) LexerErrors!u8 {
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

const LexFuncErrors = LexerErrors || std.mem.Allocator.Error;

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn matchEqual(self: *Self, token_if_match: TokenType, token_if_not_match: TokenType) !TokenType {
    return if (try self.match('=')) token_if_match else token_if_not_match;
}

fn number(self: *Self) LexerErrors!TokenType {
    var dot_seen = false;
    while (true) {
        const char: u8 = self.peek() catch 0;
        if (char == '.') {
            if (dot_seen) {
                return error.UnexpectedSymbol;
            }
            _ = try self.advance();
            dot_seen = true;
            continue;
        }
        if (!isDigit(char)) {
            return if (dot_seen) .DOUBLE else .INTEGER;
        } else {
            _ = try self.advance();
        }
    }
}

fn string(self: *Self, str: *?[]u8) LexFuncErrors!TokenType {
    var str_inner: ArrayList(u8) = .empty;
    while (try self.peek() != '"') {
        var c: u8 = try self.advance();
        if (c == '\\') c = try self.advance();
        try str_inner.append(self.allocator, c);
    }
    _ = try self.advance();
    str.* = str_inner.items;
    return .STRING;
}

pub fn lex(self: *Self) LexFuncErrors!TokenList {
    while (!self.atEnd()) {
        var lexem: ?[]u8 = null;
        const c: u8 = try self.advance();
        self.start = self.current;
        const newToken = switch (c) {
            ' ', '\t', '\r' => {
                continue;
            },
            '\n' => {
                self.line += 1;
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
            // TODO: make identifiers work
            else => {
                break;
            },
        };
        try self.addToken(newToken, self.line, self.start, self.current, lexem);
    }
    try self.addToken(.EOF, self.line, self.current, self.current, null);
    return token_list;
}
