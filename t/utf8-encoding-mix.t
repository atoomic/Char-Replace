#!/usr/bin/perl -w

# Tests for correct encoding handling when map entry encoding differs
# from input encoding (UTF-8 vs Latin-1/non-UTF-8 mismatches).
#
# Bug: prior to this fix, a UTF-8-flagged map entry (e.g., "é" from
# 'use utf8') used with a non-UTF-8 input would produce mojibake
# because raw UTF-8 bytes were copied into a non-UTF-8 output string.

use utf8;
use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# ---------------------------------------------------------------------------
# replace() — UTF-8 map entry + non-UTF-8 input
# ---------------------------------------------------------------------------

{
    note "replace: UTF-8 map entry 'é' + non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "é";

    my $input = "abc";
    utf8::downgrade($input);

    my $result = Char::Replace::replace( $input, \@map );
    is $result, "ébc",
        q[UTF-8 map entry correctly downgraded for non-UTF-8 input];
}

{
    note "replace: UTF-8 map entry 'ñ' + non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('n') ] = "ñ";

    my $input = "gnome";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "gñome",
        q[ñ correctly handled in non-UTF-8 context];
}

{
    note "replace: multiple UTF-8 map entries + non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "à";
    $map[ ord('e') ] = "è";
    $map[ ord('o') ] = "ò";

    my $input = "aeiou";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "àèiòu",
        q[multiple UTF-8 entries, all correctly downgraded];
}

# ---------------------------------------------------------------------------
# replace() — non-UTF-8 (Latin-1) map entry + UTF-8 input
# ---------------------------------------------------------------------------

{
    note "replace: Latin-1 map entry + UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "\xE9";  # Latin-1 é, no UTF-8 flag

    my $input = "abc";
    utf8::upgrade($input);

    my $result = Char::Replace::replace( $input, \@map );
    is $result, "ébc",
        q[Latin-1 map entry correctly upgraded for UTF-8 input];
    ok utf8::is_utf8($result), q[result has UTF-8 flag];
}

{
    note "replace: Latin-1 byte 0xFF + UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = "\xFF";  # Latin-1 ÿ

    my $input = "xyz";
    utf8::upgrade($input);

    my $result = Char::Replace::replace( $input, \@map );
    is $result, "ÿyz",
        q[Latin-1 0xFF correctly upgraded to UTF-8 ÿ];
}

# ---------------------------------------------------------------------------
# replace() — UTF-8 map entry + UTF-8 input (both match: no conversion)
# ---------------------------------------------------------------------------

{
    note "replace: UTF-8 map entry + UTF-8 input (same encoding)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "é";

    my $input = "abc";
    utf8::upgrade($input);

    my $result = Char::Replace::replace( $input, \@map );
    is $result, "ébc",
        q[UTF-8 entry + UTF-8 input: direct copy, no conversion];
    ok utf8::is_utf8($result), q[result is UTF-8];
}

# ---------------------------------------------------------------------------
# replace() — multi-char UTF-8 expansion + non-UTF-8 input
# ---------------------------------------------------------------------------

{
    note "replace: multi-char UTF-8 expansion with non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "àé";

    my $input = "abc";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "àébc",
        q[multi-char UTF-8 expansion correctly downgraded];
}

{
    note "replace: multi-char Latin-1 expansion with UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "\xE0\xE9";  # Latin-1 àé

    my $input = "abc";
    utf8::upgrade($input);

    is Char::Replace::replace( $input, \@map ), "àébc",
        q[multi-char Latin-1 expansion correctly upgraded to UTF-8];
}

# ---------------------------------------------------------------------------
# replace_inplace() — UTF-8 map entry + non-UTF-8 input
# ---------------------------------------------------------------------------

{
    note "replace_inplace: UTF-8 map entry + non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "é";

    my $str = "abcabc";
    utf8::downgrade($str);
    my $count = Char::Replace::replace_inplace( $str, \@map );

    is $str, "ébcébc", q[inplace: UTF-8 entry downgraded for non-UTF-8 string];
    is $count, 2, q[2 replacements made];
}

{
    note "replace_inplace: Latin-1 map entry (>127) + UTF-8 input croaks";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "\xE9";  # Latin-1 é, needs 2 bytes in UTF-8

    my $str = "abc";
    utf8::upgrade($str);

    # Non-UTF-8 byte > 127 in a UTF-8 string requires expansion (1→2 bytes)
    # which is not possible in-place. Should croak.
    my $died = !eval { Char::Replace::replace_inplace( $str, \@map ); 1 };
    ok $died, q[inplace: Latin-1 byte >127 + UTF-8 input correctly croaks];
    like $@, qr/cannot|wide|byte/i, q[error mentions encoding incompatibility];
}

# ---------------------------------------------------------------------------
# build_map() — UTF-8 values
# ---------------------------------------------------------------------------

{
    note "build_map: UTF-8 replacement values";
    my $map = Char::Replace::build_map( 'a' => 'à', 'e' => 'è' );

    my $input = "cafe";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, $map ), "càfè",
        q[build_map with UTF-8 values + non-UTF-8 input];
}

# ---------------------------------------------------------------------------
# coderef — encoding mismatch
# ---------------------------------------------------------------------------

{
    note "coderef returning UTF-8 + non-UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = sub { "é" };

    my $input = "abc";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "ébc",
        q[coderef UTF-8 return correctly downgraded for non-UTF-8 input];
}

{
    note "coderef returning Latin-1 + UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = sub { "\xE9" };  # Latin-1 é

    my $input = "abc";
    utf8::upgrade($input);

    is Char::Replace::replace( $input, \@map ), "ébc",
        q[coderef Latin-1 return correctly upgraded for UTF-8 input];
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

{
    note "replace: empty map entry (deletion) with encoding mismatch";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "";

    my $input = "abc";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "bc",
        q[deletion still works with encoding normalization];
}

{
    note "replace: identity map with UTF-8 input";
    my @map = @{ Char::Replace::identity_map() };

    my $input = "héllo";
    is Char::Replace::replace( $input, \@map ), "héllo",
        q[identity map preserves UTF-8 input];
}

{
    note "replace: ASCII-only UTF-8 map entries (no mismatch)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = "X";  # ASCII, no encoding issue regardless

    my $input = "abc";
    utf8::downgrade($input);

    is Char::Replace::replace( $input, \@map ), "Xbc",
        q[ASCII map entry: no encoding issue];
}

done_testing;
