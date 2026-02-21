#!/usr/bin/perl -w

# Tests for trim() and trim_inplace() with custom charset parameter

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# --- trim($str, $chars) ---

{
    note "trim with custom chars: basic usage";
    is Char::Replace::trim("xxhelloxx", "x"), "hello",
        "trim x from both sides";
    is Char::Replace::trim("...hello...", "."), "hello",
        "trim dots from both sides";
    is Char::Replace::trim("00123400", "0"), "1234",
        "trim leading/trailing zeros";
}

{
    note "trim with multi-char charset";
    is Char::Replace::trim("xyhelloyx", "xy"), "hello",
        "trim x and y";
    is Char::Replace::trim(".-hello-.", ".-"), "hello",
        "trim dots and dashes";
    is Char::Replace::trim("abchelloabc", "abc"), "hello",
        "trim a, b, and c";
}

{
    note "trim with charset: only leading";
    is Char::Replace::trim("xxhello", "x"), "hello",
        "custom trim leading only";
}

{
    note "trim with charset: only trailing";
    is Char::Replace::trim("helloxx", "x"), "hello",
        "custom trim trailing only";
}

{
    note "trim with charset: no match";
    is Char::Replace::trim("hello", "x"), "hello",
        "no chars to trim: unchanged";
    is Char::Replace::trim("hello", "xyz"), "hello",
        "multi-char charset, no match: unchanged";
}

{
    note "trim with charset: entire string is trim chars";
    is Char::Replace::trim("xxxxx", "x"), "",
        "all-x string trimmed to empty";
    is Char::Replace::trim("xyxyxy", "xy"), "",
        "all trim chars -> empty";
}

{
    note "trim with charset: empty string input";
    is Char::Replace::trim("", "x"), "",
        "empty string with custom charset";
}

{
    note "trim with charset: empty charset string";
    is Char::Replace::trim("  hello  ", ""), "  hello  ",
        "empty charset: no trimming";
}

{
    note "trim with charset: preserves internal occurrences";
    is Char::Replace::trim("xxhexlloxx", "x"), "hexllo",
        "internal x preserved";
    is Char::Replace::trim("..a.b.c..", "."), "a.b.c",
        "internal dots preserved";
}

{
    note "trim with charset: whitespace in charset";
    is Char::Replace::trim("  hello  ", " "), "hello",
        "space as custom trim char";
    is Char::Replace::trim("\thello\t", "\t"), "hello",
        "tab as custom trim char";
    is Char::Replace::trim(" \thello\t ", " \t"), "hello",
        "space and tab in charset";
}

{
    note "trim with charset: default whitespace without second arg still works";
    is Char::Replace::trim("  hello  "), "hello",
        "no second arg: default whitespace trim";
    is Char::Replace::trim("\n\thello\r\f"), "hello",
        "no second arg: all whitespace chars";
}

{
    note "trim with charset: undef second arg = default behavior";
    is Char::Replace::trim("  hello  ", undef), "hello",
        "undef charset: falls back to default whitespace";
}

{
    note "trim with charset: original string preserved";
    my $str = "xxhelloxx";
    my $result = Char::Replace::trim($str, "x");
    is $result, "hello", "trim result correct";
    is $str, "xxhelloxx", "original string unchanged";
}

{
    note "trim with charset: UTF-8 content preserved";
    is Char::Replace::trim("xxhéllôxx", "x"), "héllô",
        "UTF-8 content preserved with custom charset";
    is Char::Replace::trim("xx日本語xx", "x"), "日本語",
        "CJK content preserved with custom charset";
    is Char::Replace::trim("xx😀xx", "x"), "😀",
        "emoji preserved with custom charset";
}

{
    note "trim with charset: single character string";
    is Char::Replace::trim("x", "x"), "",
        "single char that matches charset";
    is Char::Replace::trim("x", "y"), "x",
        "single char that doesn't match charset";
}

{
    note "trim with charset: null byte in charset";
    is Char::Replace::trim("\0hello\0", "\0"), "hello",
        "null byte as trim character";
}

{
    note "trim with charset: binary values";
    is Char::Replace::trim("\x01hello\x01", "\x01"), "hello",
        "binary 0x01 as trim character";
    is Char::Replace::trim("\xFF hello \xFF", "\xFF"), " hello ",
        "0xFF as trim character (whitespace inside preserved)";
}

{
    note "trim with charset: ref as second arg = default behavior";
    is Char::Replace::trim("  hello  ", []), "hello",
        "arrayref charset: falls back to default";
    is Char::Replace::trim("  hello  ", {}), "hello",
        "hashref charset: falls back to default";
}

# --- trim_inplace($str, $chars) ---

{
    note "trim_inplace with custom chars: basic";
    my $str = "xxhelloxx";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "trim_inplace custom chars: string modified";
    is $count, 4, "4 x characters removed";
}

{
    note "trim_inplace with multi-char charset";
    my $str = "xyhelloyx";
    my $count = Char::Replace::trim_inplace($str, "xy");
    is $str, "hello", "trim_inplace xy charset";
    is $count, 4, "4 chars removed";
}

{
    note "trim_inplace with custom chars: leading only";
    my $str = "xxhello";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "leading x removed in-place";
    is $count, 2, "2 leading x removed";
}

{
    note "trim_inplace with custom chars: trailing only";
    my $str = "helloxx";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "trailing x removed in-place";
    is $count, 2, "2 trailing x removed";
}

{
    note "trim_inplace with custom chars: no match";
    my $str = "hello";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "no-op when no match";
    is $count, 0, "0 chars removed";
}

{
    note "trim_inplace with custom chars: all match";
    my $str = "xxxxx";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "", "all-x -> empty";
    is $count, 5, "5 chars removed";
}

{
    note "trim_inplace with custom chars: empty string";
    my $str = "";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "", "empty string unchanged";
    is $count, 0, "0 chars removed on empty";
}

{
    note "trim_inplace with custom chars: empty charset";
    my $str = "  hello  ";
    my $count = Char::Replace::trim_inplace($str, "");
    is $str, "  hello  ", "empty charset: no trimming";
    is $count, 0, "0 chars removed with empty charset";
}

{
    note "trim_inplace: default behavior without charset arg";
    my $str = "  hello  ";
    my $count = Char::Replace::trim_inplace($str);
    is $str, "hello", "no charset: default whitespace trim";
    is $count, 4, "4 spaces removed";
}

{
    note "trim_inplace with custom chars: undef = default";
    my $str = "  hello  ";
    my $count = Char::Replace::trim_inplace($str, undef);
    is $str, "hello", "undef charset: default trim";
    is $count, 4, "4 spaces removed";
}

{
    note "trim_inplace with custom chars: preserves internal";
    my $str = "xxhexlloxx";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hexllo", "internal x preserved in-place";
    is $count, 4, "4 outer x removed";
}

{
    note "trim_inplace with custom chars: UTF-8 content";
    my $str = "xxhéllôxx";
    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "héllô", "UTF-8 preserved in-place with custom charset";
    is $count, 4, "4 x removed around UTF-8";
}

{
    note "trim_inplace with custom chars: UTF-8 CJK";
    my $str = "..日本語..";
    my $count = Char::Replace::trim_inplace($str, ".");
    is $str, "日本語", "CJK preserved in-place";
    is $count, 4, "4 dots removed around CJK";
}

{
    note "trim_inplace with custom chars: spaces as custom trim char";
    my $str = "  hello  ";
    my $count = Char::Replace::trim_inplace($str, " ");
    is $str, "hello", "space as custom trim char in-place";
    is $count, 4, "4 spaces removed";
}

{
    note "trim_inplace with custom chars: only trim specified, not other ws";
    my $str = " \thello\t ";
    my $count = Char::Replace::trim_inplace($str, " ");
    is $str, "\thello\t", "only spaces trimmed, not tabs";
    is $count, 2, "2 spaces removed, tabs preserved";
}

{
    note "trim_inplace with custom chars: selective whitespace";
    my $str = "\t\nhello\n\t";
    my $count = Char::Replace::trim_inplace($str, "\t");
    is $str, "\nhello\n", "only tabs trimmed, not newlines";
    is $count, 2, "2 tabs removed";
}

{
    note "trim_inplace with numeric-like chars";
    my $str = "000123000";
    my $count = Char::Replace::trim_inplace($str, "0");
    is $str, "123", "trim leading/trailing zeros in-place";
    is $count, 6, "6 zeros removed";
}

{
    note "consistency: trim_inplace matches trim with custom charset";
    my @tests = (
        ["xxhelloxx",     "x"],
        ["..a.b.c..",     "."],
        ["  hello  ",     " "],
        ["xyzhelloyzx",   "xyz"],
        ["000100",        "0"],
        ["hello",         "x"],
        ["",              "x"],
        ["xxxxx",         "x"],
        ["xxhéllôxx",   "x"],
    );

    for my $test (@tests) {
        my ($input, $charset) = @$test;
        my $expected = Char::Replace::trim($input, $charset);
        my $str = $input;
        Char::Replace::trim_inplace($str, $charset);
        is $str, $expected,
            "trim_inplace matches trim for: " . quotemeta($input) . " charset=" . quotemeta($charset);
    }
}

{
    note "trim with charset: repeated calls";
    my $str = "xxhelloxx";
    Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "first custom trim";

    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, "hello", "second custom trim: no-op";
    is $count, 0, "0 on second trim";
}

# --- UTF-8 safety: non-ASCII bytes in custom charset ---

{
    note "trim: UTF-8 safety with non-ASCII custom charset";

    # "ã" (U+00E3) = \xC3\xA3 in UTF-8
    # "é" (U+00E9) = \xC3\xA9 in UTF-8
    # They share lead byte \xC3 but are different characters.
    # Trimming "é" from a string starting with "ã" must NOT corrupt
    # the multi-byte sequence by stripping the shared \xC3 byte.

    my $str = "\xC3\xA3hello\xC3\xA3";
    utf8::decode($str);
    my $charset = "\xC3\xA9";
    utf8::decode($charset);

    is Char::Replace::trim($str, $charset), $str,
        "non-matching non-ASCII charset: UTF-8 string unchanged";
}

{
    note "trim: UTF-8 safety - matching non-ASCII trim char skipped";

    # Even when the trim char matches, individual bytes >= 0x80
    # must not be trimmed to avoid splitting multi-byte sequences.
    my $str = "\xC3\xA9hello\xC3\xA9";  # éhelloé
    utf8::decode($str);
    my $charset = "\xC3\xA9";  # é
    utf8::decode($charset);

    is Char::Replace::trim($str, $charset), $str,
        "matching non-ASCII charset: not trimmed (UTF-8 safety)";
}

{
    note "trim: ASCII charset on UTF-8 string still works";

    my $str = "xx\xC3\xA9helloxx";  # xxéhelloxx
    utf8::decode($str);
    my $expected = "\xC3\xA9hello";
    utf8::decode($expected);

    is Char::Replace::trim($str, "x"), $expected,
        "ASCII trim chars work correctly on UTF-8 string";
}

{
    note "trim: non-ASCII edges with ASCII charset";

    my $str = "\xC3\xA9hello\xC3\xA9";  # éhelloé
    utf8::decode($str);

    is Char::Replace::trim($str, "x"), $str,
        "non-ASCII edges untouched by ASCII charset";
}

{
    note "trim: mixed ASCII and non-ASCII at edges";

    # "xéhellox" — only the ASCII 'x' should be trimmed
    my $str = "x\xC3\xA9hellox";
    utf8::decode($str);
    my $expected = "\xC3\xA9hello";
    utf8::decode($expected);

    is Char::Replace::trim($str, "x"), $expected,
        "leading ASCII trimmed, trailing ASCII trimmed, non-ASCII preserved";
}

{
    note "trim: default whitespace on UTF-8 string with non-ASCII content";

    my $str = "  \xC3\xA9hello\xC3\xA3  ";
    utf8::decode($str);
    my $expected = "\xC3\xA9hello\xC3\xA3";
    utf8::decode($expected);

    is Char::Replace::trim($str), $expected,
        "default whitespace trim preserves interior non-ASCII";
}

{
    note "trim: CJK characters not affected by non-ASCII charset";

    # "日" (U+65E5) = \xE6\x97\xA5 in UTF-8 (3 bytes)
    my $str = "\xE6\x97\xA5hello\xE6\x97\xA5";
    utf8::decode($str);
    my $charset = "\xC3\xA9";  # é
    utf8::decode($charset);

    is Char::Replace::trim($str, $charset), $str,
        "CJK edges unchanged by unrelated non-ASCII charset";
}

{
    note "trim: 4-byte emoji at edges";

    # Emoji "😀" (U+1F600) = \xF0\x9F\x98\x80 in UTF-8
    my $str = "\xF0\x9F\x98\x80hello\xF0\x9F\x98\x80";
    utf8::decode($str);
    my $charset = "\xC3\xA9";
    utf8::decode($charset);

    is Char::Replace::trim($str, $charset), $str,
        "emoji edges unchanged by non-ASCII charset";
}

# --- trim_inplace: UTF-8 safety ---

{
    note "trim_inplace: UTF-8 safety with non-ASCII custom charset";

    my $str = "\xC3\xA3hello\xC3\xA3";  # ãhelloã
    utf8::decode($str);
    my $original = $str;
    my $charset = "\xC3\xA9";  # é
    utf8::decode($charset);

    my $count = Char::Replace::trim_inplace($str, $charset);
    is $str, $original, "non-matching non-ASCII charset: string unchanged in-place";
    is $count, 0, "zero bytes removed";
}

{
    note "trim_inplace: matching non-ASCII charset skipped";

    my $str = "\xC3\xA9hello\xC3\xA9";  # éhelloé
    utf8::decode($str);
    my $original = $str;
    my $charset = "\xC3\xA9";  # é
    utf8::decode($charset);

    my $count = Char::Replace::trim_inplace($str, $charset);
    is $str, $original, "matching non-ASCII charset: not trimmed in-place (UTF-8 safety)";
    is $count, 0, "zero bytes removed";
}

{
    note "trim_inplace: ASCII charset on UTF-8 string";

    my $str = "xx\xC3\xA9helloxx";
    utf8::decode($str);
    my $expected = "\xC3\xA9hello";
    utf8::decode($expected);

    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, $expected, "ASCII trim works on UTF-8 string in-place";
    is $count, 4, "4 ASCII bytes removed";
}

{
    note "trim_inplace: mixed edges";

    my $str = "x\xC3\xA9hellox";
    utf8::decode($str);
    my $expected = "\xC3\xA9hello";
    utf8::decode($expected);

    my $count = Char::Replace::trim_inplace($str, "x");
    is $str, $expected, "mixed edges: ASCII trimmed, non-ASCII preserved in-place";
    is $count, 2, "2 ASCII bytes removed";
}

{
    note "consistency: trim and trim_inplace agree on UTF-8 + non-ASCII charset";

    my @tests = (
        ["\xC3\xA3hello\xC3\xA3", "\xC3\xA9"],  # ãhelloã / é
        ["\xC3\xA9hello\xC3\xA9", "\xC3\xA9"],  # éhelloé / é
        ["xx\xC3\xA9helloxx",     "x"],           # ASCII charset
        ["x\xC3\xA9hellox",       "x"],           # mixed edges
        ["\xE6\x97\xA5hello\xE6\x97\xA5", "\xC3\xA9"],  # CJK / é
    );

    for my $test (@tests) {
        my ($raw, $raw_charset) = @$test;
        my $input = $raw;
        utf8::decode($input);
        my $cs = $raw_charset;
        utf8::decode($cs);

        my $expected = Char::Replace::trim($input, $cs);
        my $str = $input;
        Char::Replace::trim_inplace($str, $cs);
        is $str, $expected,
            "trim_inplace matches trim for UTF-8 string with non-ASCII charset";
    }
}

done_testing;
