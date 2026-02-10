#!/usr/bin/perl -w

# Stress tests: edge cases, large inputs, boundary conditions, and
# cross-function consistency checks for replace(), replace_inplace(),
# trim(), and trim_inplace().

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# ---------------------------------------------------------------------------
# replace() — boundary byte values
# ---------------------------------------------------------------------------

{
    note "replace: all 256 byte values round-trip through identity map";
    my @map = @{ Char::Replace::identity_map() };

    my $all = '';
    $all .= chr($_) for 0..255;
    utf8::downgrade($all);

    is Char::Replace::replace( $all, \@map ), $all,
        q[identity map preserves all 256 byte values];
}

{
    note "replace: swap byte 0 and byte 255";
    my @map = @{ Char::Replace::identity_map() };
    $map[0]   = chr(255);
    $map[255] = chr(0);

    my $input = "\x00\xFF";
    utf8::downgrade($input);

    my $got = Char::Replace::replace( $input, \@map );
    is $got, "\xFF\x00", q[swap byte 0 <-> 255];
}

{
    note "replace: map shorter than input byte range";
    # Map with only 10 entries — bytes above index 9 should pass through
    my @map;
    $map[$_] = chr($_) for 0..9;

    my $input = "Hello!";  # all bytes > 9
    is Char::Replace::replace( $input, \@map ), $input,
        q[short map: bytes above map_top pass through];
}

{
    note "replace: map with undef holes (sparse map)";
    my @map;
    $map[0]  = chr(0);
    $map[255] = 'X';
    # everything between 1..254 is undef

    my $input = "abc";
    is Char::Replace::replace( $input, \@map ), "abc",
        q[sparse map: undef entries preserve original];
}

# ---------------------------------------------------------------------------
# replace() — large expansion stress
# ---------------------------------------------------------------------------

{
    note "replace: massive expansion (1 byte -> 100 bytes)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = 'X' x 100;

    my $input  = 'x' x 50;
    my $expect = ('X' x 100) x 50;
    is Char::Replace::replace( $input, \@map ), $expect,
        q[50 chars expanding to 5000: buffer growth stress];
}

{
    note "replace: alternating expansion and deletion";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'AAAA';   # expand
    $map[ ord('b') ] = '';        # delete

    my $input  = 'ab' x 100;
    my $expect = 'AAAA' x 100;
    is Char::Replace::replace( $input, \@map ), $expect,
        q[alternating expand/delete: 200 chars -> 400];
}

{
    note "replace: all chars deleted (output is empty)";
    my @map = @{ Char::Replace::identity_map() };
    for my $c ( 'a'..'z' ) {
        $map[ ord($c) ] = '';
    }

    is Char::Replace::replace( "helloworld", \@map ), "",
        q[delete every char: empty output];
}

# ---------------------------------------------------------------------------
# replace() — UTF-8 edge cases
# ---------------------------------------------------------------------------

{
    note "replace: UTF-8 string containing only multi-byte chars";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';  # this shouldn't trigger

    my $input = "ééé日日😀😀";
    is Char::Replace::replace( $input, \@map ), $input,
        q[all-multibyte: no replacements, no corruption];
}

{
    note "replace: long UTF-8 string with scattered ASCII";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('.') ] = '!';

    my $input = ("café." x 100);
    my $expect = ("café!" x 100);
    is Char::Replace::replace( $input, \@map ), $expect,
        q[500-char UTF-8 with 100 dot replacements];
}

{
    note "replace: single-byte non-UTF-8 vs UTF-8 string behavior";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xE9] = 'X';  # 0xE9 is lead byte in UTF-8, but latin-1 'é'

    # non-UTF-8: should replace
    my $latin1 = "\xE9";
    utf8::downgrade($latin1);
    is Char::Replace::replace( $latin1, \@map ), "X",
        q[non-UTF-8: 0xE9 (latin1 é) replaced by map];

    # UTF-8: 0xE9 is a lead byte, should NOT be replaced
    my $utf8 = "é";  # é is 0xC3 0xA9 in UTF-8
    is Char::Replace::replace( $utf8, \@map ), "é",
        q[UTF-8: 0xE9 is not a raw byte, é unchanged];
}

# ---------------------------------------------------------------------------
# replace_inplace() — consistency with replace()
# ---------------------------------------------------------------------------

{
    note "replace_inplace: 1:1 map matches replace() for all printable ASCII";
    my @map = @{ Char::Replace::identity_map() };
    # ROT13
    for my $c ('a'..'z') {
        my $n = ord($c) - ord('a');
        $map[ ord($c) ] = chr( ord('a') + ($n + 13) % 26 );
    }
    for my $c ('A'..'Z') {
        my $n = ord($c) - ord('A');
        $map[ ord($c) ] = chr( ord('A') + ($n + 13) % 26 );
    }

    my $input = "The Quick Brown Fox Jumps Over The Lazy Dog 0123456789 !@#";
    my $expected = Char::Replace::replace( $input, \@map );

    my $str = $input;
    Char::Replace::replace_inplace( $str, \@map );
    is $str, $expected, q[ROT13 inplace matches replace()];
}

{
    note "replace_inplace: all 256 bytes through ROT128";
    my @map = @{ Char::Replace::identity_map() };
    for my $i (0..255) {
        $map[$i] = chr( ($i + 128) % 256 );
    }

    my $input = '';
    $input .= chr($_) for 0..255;
    utf8::downgrade($input);

    my $expected = Char::Replace::replace( $input, \@map );

    my $str = $input;
    Char::Replace::replace_inplace( $str, \@map );
    is $str, $expected, q[ROT128 on all 256 bytes: inplace matches replace()];
}

# ---------------------------------------------------------------------------
# replace_inplace() — COW string handling
# ---------------------------------------------------------------------------

{
    note "replace_inplace: COW string is properly de-COWed";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    my $original = "abcd";
    my $cow_copy = $original;  # shares buffer (COW)

    Char::Replace::replace_inplace( $cow_copy, \@map );
    is $cow_copy, "Xbcd",  q[COW copy was modified];
    is $original, "abcd",  q[original preserved after COW de-duplication];
}

# ---------------------------------------------------------------------------
# trim() and trim_inplace() — consistency
# ---------------------------------------------------------------------------

{
    note "trim vs trim_inplace: consistent results";
    my @cases = (
        "",
        "nowhitespace",
        "  leading",
        "trailing  ",
        "  both  ",
        "\t\n\r\f mixed \t\n\r\f",
        "   ",              # all whitespace
        "\t",               # single tab
        " a ",              # minimal
        " " x 1000,         # long whitespace
        " " . ("x" x 1000) . " ",  # long content with spaces
    );

    for my $input (@cases) {
        my $trimmed = Char::Replace::trim( $input );

        my $inplace = $input;
        Char::Replace::trim_inplace( $inplace );

        is $inplace, $trimmed,
            "trim_inplace matches trim for: " . _describe($input);
    }
}

{
    note "trim_inplace: return value is correct count";
    my $str = "  hello  ";
    my $n = Char::Replace::trim_inplace( $str );
    is $str, "hello", q[trimmed correctly];
    is $n,   4,       q[4 bytes removed (2 leading + 2 trailing)];
}

{
    note "trim_inplace: string of only whitespace";
    my $str = "   \t\n\r\f   ";
    my $n = Char::Replace::trim_inplace( $str );
    is $str, "",       q[all-whitespace becomes empty];
    is $n,   length("   \t\n\r\f   "), q[all bytes removed];
}

# ---------------------------------------------------------------------------
# trim() — UTF-8 edge cases
# ---------------------------------------------------------------------------

{
    note "trim: UTF-8 string with surrounding whitespace";
    is Char::Replace::trim( "  café  " ), "café",
        q[trim UTF-8: surrounding spaces removed, content preserved];
}

{
    note "trim: UTF-8 string with no whitespace";
    is Char::Replace::trim( "日本語" ), "日本語",
        q[trim UTF-8: no whitespace, CJK preserved];
}

# ---------------------------------------------------------------------------
# build_map() — edge cases
# ---------------------------------------------------------------------------

{
    note "build_map: empty hash";
    my $map = Char::Replace::build_map();
    my $input = "hello";
    is Char::Replace::replace( $input, $map ), $input,
        q[empty build_map: identity behavior];
}

{
    note "build_map: all printable ASCII remapped";
    my %pairs;
    for my $c (32..126) {
        $pairs{ chr($c) } = chr( 32 + (126 - $c) );  # reverse printable range
    }
    my $map = Char::Replace::build_map( %pairs );

    my $input = "Hello";
    my $got = Char::Replace::replace( $input, $map );
    # H=72 -> chr(32+126-72)=chr(86)=V, etc.
    isnt $got, $input, q[all printable remapped: output differs];
    is length($got), length($input), q[same length (1:1 map)];
}

{
    note "build_map: multi-char key croaks";
    my $died = !eval { Char::Replace::build_map( 'ab' => 'X' ); 1 };
    ok $died, q[multi-char key in build_map croaks];
    like $@, qr/single character/, q[error mentions single character];
}

# ---------------------------------------------------------------------------
# Coderef — edge cases
# ---------------------------------------------------------------------------

{
    note "coderef: callback returning very long string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = sub { 'A' x 10_000 };

    my $got = Char::Replace::replace( "x", \@map );
    is length($got), 10_000, q[coderef: 10k char expansion works];
    is $got, 'A' x 10_000,  q[content correct];
}

{
    note "coderef: callback called for every byte in long string";
    my $calls = 0;
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = sub { $calls++; 'Y' };

    my $input = 'x' x 500;
    my $got = Char::Replace::replace( $input, \@map );
    is $got,   'Y' x 500, q[500 chars replaced via coderef];
    is $calls, 500,        q[coderef called 500 times];
}

{
    note "coderef: die in middle of string doesn't corrupt state";
    my @map = @{ Char::Replace::identity_map() };
    my $n = 0;
    $map[ ord('x') ] = sub {
        $n++;
        die "boom at call $n" if $n == 3;
        return 'Y';
    };

    eval { Char::Replace::replace( "xxxxxx", \@map ) };
    like $@, qr/boom at call 3/, q[die in middle propagates];

    # subsequent calls should work fine (no corruption)
    $n = 0;
    $map[ ord('x') ] = sub { 'Z' };
    my $got = Char::Replace::replace( "xxx", \@map );
    is $got, "ZZZ", q[replace works normally after coderef die];
}

# ---------------------------------------------------------------------------
# Mixed edge cases
# ---------------------------------------------------------------------------

{
    note "replace: string with embedded nulls and expansion";
    my @map = @{ Char::Replace::identity_map() };
    $map[0] = 'NULL';

    my $input = "\0a\0b\0";
    my $got = Char::Replace::replace( $input, \@map );
    is $got, "NULLaNULLbNULL", q[null bytes expanded to 'NULL'];
}

{
    note "replace: single char string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'XYZ';

    is Char::Replace::replace( "a", \@map ), "XYZ",
        q[single char expanded];
}

{
    note "replace: single char deleted";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';

    is Char::Replace::replace( "a", \@map ), "",
        q[single char deleted -> empty string];
}

{
    note "replace_inplace: same char mapped to itself -> 0 changes";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'a';  # explicit identity

    my $str = "aaaa";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "aaaa", q[explicit self-map: unchanged];
    is $count, 0,      q[0 changes when map entry equals original];
}

# ---------------------------------------------------------------------------
# Large-scale stress: replace on 1MB string
# ---------------------------------------------------------------------------

{
    note "replace: 1MB string with scattered replacements";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'A';

    my $input = 'a' . ('b' x 999) . ('a' . ('b' x 999)) x 999;
    # 1000 'a' chars scattered in ~1MB of 'b'
    my $got = Char::Replace::replace( $input, \@map );
    my $a_count = () = $got =~ /A/g;
    is $a_count, 1000, q[1MB: all 1000 'a' replaced with 'A'];
    ok index($got, 'a') == -1, q[no lowercase 'a' remains];
}

{
    note "replace_inplace: 1MB string performance (no crash)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = 'X';

    my $str = 'x' x 1_000_000;
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $count, 1_000_000, q[1M in-place replacements];
    ok $str eq ('X' x 1_000_000), q[1MB string correctly replaced];
}

done_testing;

# Helper to describe a string for test names
sub _describe {
    my ($s) = @_;
    return '(empty)' if length($s) == 0;
    $s =~ s/\t/\\t/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\r/\\r/g;
    $s =~ s/\f/\\f/g;
    return length($s) > 30 ? substr($s, 0, 27) . '...' : $s;
}
