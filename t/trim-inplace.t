#!/usr/bin/perl -w

# Tests for trim_inplace() — in-place whitespace trimming

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "basic in-place trim: leading and trailing spaces";
    my $str = "  hello world  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello world", q[both sides trimmed];
    is $count, 4,             q[4 spaces removed];
}

{
    note "leading whitespace only";
    my $str = "   hello";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[leading spaces removed];
    is $count, 3,       q[3 spaces];
}

{
    note "trailing whitespace only";
    my $str = "hello   ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[trailing spaces removed];
    is $count, 3,       q[3 spaces];
}

{
    note "no whitespace: no-op";
    my $str = "hello";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[no-op: string unchanged];
    is $count, 0,       q[0 bytes removed];
}

{
    note "empty string: no-op";
    my $str = "";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "", q[empty string unchanged];
    is $count, 0,  q[0 bytes removed on empty];
}

{
    note "all whitespace: becomes empty";
    my $str = "     ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "", q[all-space -> empty];
    is $count, 5,  q[5 spaces removed];
}

{
    note "mixed whitespace characters";
    my $str = "\t\n\r\f hello \t\n\r\f";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[mixed ws trimmed];
    is $count, 10,      q[10 whitespace bytes removed];
}

{
    note "single space on each side";
    my $str = " x ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "x", q[single space each side];
    is $count, 2,   q[2 spaces removed];
}

{
    note "single character, no whitespace";
    my $str = "x";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "x", q[single char unchanged];
    is $count, 0,   q[0 removed];
}

{
    note "single space";
    my $str = " ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "", q[single space -> empty];
    is $count, 1,  q[1 space removed];
}

{
    note "tab characters";
    my $str = "\thello\t";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[tabs trimmed];
    is $count, 2,       q[2 tabs];
}

{
    note "newlines";
    my $str = "\nhello\n";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[newlines trimmed];
    is $count, 2,       q[2 newlines];
}

{
    note "carriage return + newline";
    my $str = "\r\nhello\r\n";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[CRLF trimmed];
    is $count, 4,       q[4 bytes (2x CRLF)];
}

{
    note "form feed";
    my $str = "\fhello\f";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[form feed trimmed];
    is $count, 2,       q[2 form feeds];
}

{
    note "internal whitespace preserved";
    my $str = "  hello   world  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello   world", q[internal spaces preserved];
    is $count, 4,               q[4 outer spaces removed];
}

{
    note "UTF-8 string: accented characters";
    my $str = "  héllo  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "héllo", q[UTF-8 accented chars preserved];
    is $count, 4,       q[4 spaces removed around UTF-8];
}

{
    note "UTF-8 string: CJK characters";
    my $str = "  日本語  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "日本語", q[CJK preserved];
    is $count, 4,        q[4 spaces removed around CJK];
}

{
    note "UTF-8 string: emoji";
    my $str = "\t😀\n";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "😀", q[emoji preserved];
    is $count, 2,     q[tab + newline removed];
}

{
    note "UTF-8 string: no whitespace";
    my $str = "café";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "café", q[UTF-8 no-op];
    is $count, 0,       q[0 removed from UTF-8 no-ws string];
}

{
    note "long string with whitespace";
    my $content = "x" x 10000;
    my $str = "  $content  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   $content, q[long string trimmed];
    is $count, 4,        q[4 spaces on long string];
}

{
    note "non-string input: returns 0";
    my $count = Char::Replace::trim_inplace(undef);
    is $count, 0, q[undef input: returns 0];

    my @arr = (1, 2, 3);
    $count = Char::Replace::trim_inplace(\@arr);
    is $count, 0, q[ref input: returns 0];
}

{
    note "consistency: trim_inplace matches trim result";
    my @tests = (
        "  hello  ",
        "\t\n\r\f test \r\n\t",
        "no-spaces",
        "   ",
        "",
        " a b c ",
        "  héllo wörld  ",
    );

    for my $input (@tests) {
        my $expected = Char::Replace::trim($input);
        my $str = $input;
        Char::Replace::trim_inplace($str);
        is $str, $expected,
            "trim_inplace matches trim for: " . quotemeta($input);
    }
}

{
    note "null bytes in string";
    my $str = "  \0hello\0  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str,   "\0hello\0", q[null bytes preserved];
    is $count, 4,           q[4 spaces removed around null bytes];
}

{
    note "repeated calls";
    my $str = "  hello  ";
    Char::Replace::trim_inplace($str);
    is $str, "hello", q[first trim];

    my $count = Char::Replace::trim_inplace($str);
    is $str,   "hello", q[second trim: no-op];
    is $count, 0,       q[0 on second trim];
}

done_testing;
