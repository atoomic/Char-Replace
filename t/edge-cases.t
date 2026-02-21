#!/usr/bin/perl -w

# Tests for edge cases and untested code paths.
#
# These tests target specific XS code paths that exist on main but
# lack direct test coverage:
#   - replace_inplace() croak on code ref entries
#   - Malformed / truncated UTF-8 sequences (buffer clamping safety)
#   - Non-UTF-8 strings with high bytes vs UTF-8 strings (divergent paths)
#   - Fast path vs general path equivalence for mixed maps
#   - Sparse map arrays (AvFILL < 255)
#   - _build_fast_map boundary: map_top exactly 254 vs 255

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
sub id_map { @{ Char::Replace::identity_map() } }
sub utf8_str { my ($s) = @_; utf8::upgrade($s); $s }

# ---------------------------------------------------------------------------
# replace_inplace: coderef entry must croak
# ---------------------------------------------------------------------------
{
    note "replace_inplace: coderef entry causes croak";

    my @map = id_map();
    $map[ ord('a') ] = sub { uc $_[0] };

    my $str = "abcd";
    my $died = !eval { Char::Replace::replace_inplace( $str, \@map ); 1 };
    ok $died, q[coderef entry causes croak];
    like $@, qr/replace_inplace.*code ref/i,
        q[error message mentions code ref];
}

# ---------------------------------------------------------------------------
# Malformed UTF-8: truncated 2-byte sequence at end of string
# ---------------------------------------------------------------------------
{
    note "malformed UTF-8: truncated 2-byte sequence at end";

    # Construct a string with UTF-8 flag but ending with a lone lead byte.
    # Bytes: 'a' 'b' 0xC3 (lead byte expecting 1 continuation byte, but none)
    my $str = utf8_str("ab");
    # Force a raw lead byte at the end via pack
    my $raw = "ab\xC3";
    utf8::upgrade($raw);

    my @map = id_map();
    $map[ ord('a') ] = 'X';

    # Should not crash — clamping code handles truncated sequence
    my $result = eval { Char::Replace::replace( $raw, \@map ) };
    ok defined($result), q[truncated 2-byte UTF-8: replace does not crash];
    # The 'a' should be replaced, the trailing byte copied through
    like $result, qr/^X/, q[ASCII 'a' still replaced despite trailing truncated UTF-8];
}

# ---------------------------------------------------------------------------
# Malformed UTF-8: truncated 3-byte sequence at end of string
# ---------------------------------------------------------------------------
{
    note "malformed UTF-8: truncated 3-byte sequence at end";

    # 0xE2 expects 2 continuation bytes, but we only provide 1
    my $raw = "ab\xE2\x98";
    utf8::upgrade($raw);

    my @map = id_map();
    $map[ ord('a') ] = 'X';
    $map[ ord('b') ] = 'Y';

    my $result = eval { Char::Replace::replace( $raw, \@map ) };
    ok defined($result), q[truncated 3-byte UTF-8: replace does not crash];
    like $result, qr/^XY/, q[ASCII replacements work before truncated sequence];
}

# ---------------------------------------------------------------------------
# Malformed UTF-8: truncated 4-byte sequence at end of string
# ---------------------------------------------------------------------------
{
    note "malformed UTF-8: truncated 4-byte sequence at end";

    # 0xF0 expects 3 continuation bytes, only 2 given
    my $raw = "x\xF0\x9F\x98";
    utf8::upgrade($raw);

    my @map = id_map();
    $map[ ord('x') ] = 'Z';

    my $result = eval { Char::Replace::replace( $raw, \@map ) };
    ok defined($result), q[truncated 4-byte UTF-8: replace does not crash];
    like $result, qr/^Z/, q[ASCII 'x' replaced before truncated sequence];
}

# ---------------------------------------------------------------------------
# Malformed UTF-8: replace_inplace with truncated sequences
# ---------------------------------------------------------------------------
{
    note "malformed UTF-8: replace_inplace with truncated 2-byte";

    my $str = "a\xC3";
    utf8::upgrade($str);

    my @map = id_map();
    $map[ ord('a') ] = 'X';

    my $count = eval { Char::Replace::replace_inplace( $str, \@map ) };
    ok defined($count), q[replace_inplace: truncated 2-byte does not crash];
    is $count, 1,       q[replace_inplace: 1 ASCII byte replaced];
}

# ---------------------------------------------------------------------------
# Non-UTF-8 vs UTF-8: high bytes take different paths
# ---------------------------------------------------------------------------
{
    note "high byte behavior diverges between UTF-8 and non-UTF-8";

    my @map = id_map();
    $map[0xC3] = 'X';    # 0xC3 is a UTF-8 lead byte for é

    # Non-UTF-8: 0xC3 is just a raw byte, should be replaced
    my $non_utf8 = "\xC3";
    utf8::downgrade($non_utf8);
    is Char::Replace::replace( $non_utf8, \@map ), 'X',
        q[non-UTF-8: raw 0xC3 IS replaced];

    # UTF-8: 0xC3 is a lead byte, must NOT be replaced
    my $utf8 = utf8_str("é");    # é = 0xC3 0xA9
    my $result = Char::Replace::replace( $utf8, \@map );
    is $result, utf8_str("é"),
        q[UTF-8: 0xC3 lead byte NOT replaced (multi-byte preserved)];
}

# ---------------------------------------------------------------------------
# Sparse map: only a few entries set, rest are undef
# ---------------------------------------------------------------------------
{
    note "sparse map: only high indices populated";

    my @map;
    $map[200] = 'X';
    # indices 0-199 are undef, 201-255 don't exist

    my $str = "abc" . chr(200) . "def";
    utf8::downgrade($str);

    my $result = Char::Replace::replace( $str, \@map );
    is $result, "abcXdef", q[sparse map: only entry at index 200 applied];
}

{
    note "sparse map: AvFILL < 128 (below ASCII printable)";

    my @map;
    $map[32] = '_';    # space -> underscore

    is Char::Replace::replace( "a b c", \@map ), "a_b_c",
        q[sparse map with only space entry works];
}

# ---------------------------------------------------------------------------
# _build_fast_map boundary: map_top = 254 (255 entries, missing byte 255)
# ---------------------------------------------------------------------------
{
    note "fast_map boundary: map_top exactly 254";

    my @map;
    $map[$_] = chr($_) for 0..254;
    $map[ ord('x') ] = 'Z';
    # index 255 does not exist — AvFILL is 254

    my $str = "xyz" . chr(255);
    utf8::downgrade($str);
    my $result = Char::Replace::replace( $str, \@map );
    is $result, "Zyz" . chr(255),
        q[map_top=254: byte 255 passed through unchanged (identity)];

    # Same test for replace_inplace
    my $str2 = "xyz" . chr(255);
    utf8::downgrade($str2);
    Char::Replace::replace_inplace( $str2, \@map );
    is $str2, "Zyz" . chr(255),
        q[replace_inplace: map_top=254 boundary correct];
}

# ---------------------------------------------------------------------------
# _build_fast_map boundary: map_top = 255 (full 256 entries)
# ---------------------------------------------------------------------------
{
    note "fast_map boundary: map_top exactly 255 (full map)";

    my @map = id_map();
    $map[0]   = 'N';    # NUL -> N
    $map[255] = 'E';    # 0xFF -> E

    my $str = "\x00hello\xFF";
    utf8::downgrade($str);
    my $result = Char::Replace::replace( $str, \@map );
    is $result, "NhelloE",
        q[full 256-entry map: both boundary bytes replaced];
}

# ---------------------------------------------------------------------------
# Fast path vs general path: verify equivalence
# ---------------------------------------------------------------------------
{
    note "fast path vs general path equivalence";

    # Fast-path-eligible map (all 1:1)
    my @fast_map = id_map();
    $fast_map[ ord('a') ] = 'A';
    $fast_map[ ord('e') ] = 'E';
    $fast_map[ ord('o') ] = 'O';
    $fast_map[0]   = 'N';       # IV-like (stored as PV after assignment)
    $fast_map[255] = 'X';

    # General-path map: same replacements but with one coderef to force general
    my @gen_map = id_map();
    $gen_map[ ord('a') ] = 'A';
    $gen_map[ ord('e') ] = 'E';
    $gen_map[ ord('o') ] = 'O';
    $gen_map[0]   = 'N';
    $gen_map[255] = 'X';
    $gen_map[ ord('z') ] = sub { 'z' };    # identity coderef forces general path

    my @test_strings = (
        "the quick brown fox",
        "",
        "aaaa",
        "\x00\xFF" . "hello" . "\x00",
        "no replaceable chars here: !@#\$%",
    );

    for my $input (@test_strings) {
        utf8::downgrade($input);
        my $fast_result = Char::Replace::replace( $input, \@fast_map );
        my $gen_result  = Char::Replace::replace( $input, \@gen_map );
        is $fast_result, $gen_result,
            q[fast path == general path for: ] . explain($input);
    }
}

# ---------------------------------------------------------------------------
# replace_inplace: identity map returns count=0 (no SvSETMAGIC call)
# ---------------------------------------------------------------------------
{
    note "replace_inplace: identity map, verify zero count";

    my @map = id_map();
    my $str = "hello world 12345";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $count, 0, q[identity map: exactly 0 replacements];
    is $str, "hello world 12345", q[string completely unchanged];
}

# ---------------------------------------------------------------------------
# Single-byte string edge cases
# ---------------------------------------------------------------------------
{
    note "single-byte strings";

    my @map = id_map();
    $map[ ord('x') ] = 'Y';

    is Char::Replace::replace( "x", \@map ), "Y",
        q[replace: single char string];

    my $str = "x";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str, "Y",   q[replace_inplace: single char string];
    is $count, 1,    q[replace_inplace: 1 replacement on single char];

    is Char::Replace::trim( " " ), "",
        q[trim: single space -> empty];

    $str = " ";
    $count = Char::Replace::trim_inplace( $str );
    is $str, "",     q[trim_inplace: single space -> empty];
    is $count, 1,    q[trim_inplace: 1 byte removed from single space];
}

# ---------------------------------------------------------------------------
# Whitespace-only strings in trim/trim_inplace (all 6 whitespace chars)
# ---------------------------------------------------------------------------
{
    note "trim: all whitespace characters individually";

    for my $pair (
        [" ",    "space"],
        ["\t",   "tab"],
        ["\n",   "newline"],
        ["\r",   "carriage return"],
        ["\f",   "form feed"],
        ["\x0B", "vertical tab"],
    ) {
        my ($ws, $name) = @$pair;
        is Char::Replace::trim( $ws x 5 ), "",
            "trim: 5x $name -> empty";

        my $str = $ws x 3;
        my $count = Char::Replace::trim_inplace( $str );
        is $str, "",     "trim_inplace: 3x $name -> empty";
        is $count, 3,    "trim_inplace: 3 bytes removed from $name string";
    }
}

# ---------------------------------------------------------------------------
# NV entries in _build_fast_map (fast path)
# ---------------------------------------------------------------------------
{
    note "NV entries in fast path";

    my @map = id_map();
    $map[ ord('a') ] = 65.7;     # truncates to 65 = 'A'
    $map[ ord('b') ] = 98.0;     # truncates to 98 = 'b' (identity, no change)

    my $result = Char::Replace::replace( "abcabc", \@map );
    is $result, "AbcAbc", q[NV 65.7 -> chr(65) = 'A' in fast path];
}

# ---------------------------------------------------------------------------
# NV out-of-range in fast path (keeps identity)
# ---------------------------------------------------------------------------
{
    note "NV out-of-range in fast path";

    my @map = id_map();
    $map[ ord('a') ] = 256.5;    # out of range, identity kept
    $map[ ord('b') ] = -1.0;     # negative, identity kept

    my $result = Char::Replace::replace( "abcd", \@map );
    is $result, "abcd", q[out-of-range NVs: identity preserved];
}

# ---------------------------------------------------------------------------
# Weakened references: SvTYPE becomes SVt_PVMG, but SvROK still true
# ---------------------------------------------------------------------------
{
    note "weakened map references";

    eval { require Scalar::Util; Scalar::Util->import('weaken') };
    my $have_weaken = !$@;

    SKIP: {
        skip "Scalar::Util::weaken not available", 6 unless $have_weaken;

        my $map_arr = Char::Replace::build_map( 'a' => 'X', 'b' => 'Y' );

        # Keep a strong ref so the AV doesn't get collected
        my $strong = $map_arr;

        # Weaken the reference — upgrades SV type to SVt_PVMG
        weaken($map_arr);

        # replace() should still work with weakened ref
        my $r1 = Char::Replace::replace( "abc", $map_arr );
        is $r1, "XYc", q[replace: weakened map ref works];

        # replace_inplace() should still work with weakened ref
        my $str = "aabb";
        my $count = Char::Replace::replace_inplace( $str, $map_arr );
        is $count, 4,      q[replace_inplace: weakened map ref, 4 replacements];
        is $str,   "XXYY", q[replace_inplace: weakened map ref, correct result];

        # replace_list() should still work (already uses SvROK)
        my @results = Char::Replace::replace_list( ["ab", "ba", "cc"], $map_arr );
        is $results[0], "XY", q[replace_list: weakened map ref, first string];
        is $results[1], "YX", q[replace_list: weakened map ref, second string];
        is $results[2], "cc", q[replace_list: weakened map ref, third string];
    }
}

done_testing;
