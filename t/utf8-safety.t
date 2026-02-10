#!/usr/bin/perl -w

# Tests for UTF-8 safety in replace()
#
# When a string has the UTF-8 flag, multi-byte sequences must be
# copied through unchanged.  Only ASCII bytes (0x00–0x7F) should
# be eligible for map replacement.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# ---------------------------------------------------------------------------
# Helper: build an identity map with specific overrides
# ---------------------------------------------------------------------------
sub map_with {
    my (%overrides) = @_;
    my @m = @{ Char::Replace::identity_map() };
    while ( my ($k, $v) = each %overrides ) {
        $m[$k] = $v;
    }
    return \@m;
}

sub utf8_str {
    my ($s) = @_;
    utf8::upgrade($s);
    return $s;
}

# ---------------------------------------------------------------------------
# 2-byte UTF-8 sequences (Latin accented characters, U+0080–U+07FF)
# ---------------------------------------------------------------------------
{
    note "2-byte UTF-8: map on continuation byte must not corrupt";

    # é = U+00E9 = bytes C3 A9
    my $map = map_with( 0xA9 => "REPLACED" );
    is Char::Replace::replace( utf8_str("héllo"), $map ), utf8_str("héllo"),
        q[map[0xA9] does not corrupt é in UTF-8 string];

    # map on the leading byte
    $map = map_with( 0xC3 => "X" );
    is Char::Replace::replace( utf8_str("héllo"), $map ), utf8_str("héllo"),
        q[map[0xC3] does not corrupt é in UTF-8 string];

    # ñ = U+00F1 = bytes C3 B1
    $map = map_with( 0xB1 => "Z" );
    is Char::Replace::replace( utf8_str("señor"), $map ), utf8_str("señor"),
        q[map[0xB1] does not corrupt ñ];
}

# ---------------------------------------------------------------------------
# 3-byte UTF-8 sequences (U+0800–U+FFFF)
# ---------------------------------------------------------------------------
{
    note "3-byte UTF-8: snowman ☃ (U+2603 = E2 98 83)";

    my $map = map_with( 0xE2 => "BAD", 0x98 => "BAD", 0x83 => "BAD" );
    my $input    = utf8_str("a\x{2603}b");
    my $expected = utf8_str("a\x{2603}b");

    is Char::Replace::replace( $input, $map ), $expected,
        q[3-byte UTF-8 snowman is not corrupted by map on its bytes];
}

# ---------------------------------------------------------------------------
# 4-byte UTF-8 sequences (U+10000–U+10FFFF)
# ---------------------------------------------------------------------------
{
    note "4-byte UTF-8: emoji 😀 (U+1F600 = F0 9F 98 80)";

    my $map = map_with( 0xF0 => "X", 0x9F => "X", 0x98 => "X", 0x80 => "X" );
    my $input    = utf8_str("a\x{1F600}b");
    my $expected = utf8_str("a\x{1F600}b");

    is Char::Replace::replace( $input, $map ), $expected,
        q[4-byte UTF-8 emoji is not corrupted];
}

# ---------------------------------------------------------------------------
# ASCII replacement still works on UTF-8 strings
# ---------------------------------------------------------------------------
{
    note "ASCII replacement in UTF-8 context";

    my $map = map_with( ord('l') => "LL" );
    is Char::Replace::replace( utf8_str("héllo"), $map ), utf8_str("héLLLLo"),
        q[ASCII 'l' replaced in UTF-8 string];

    $map = map_with( ord('a') => "AA", ord('d') => "5" );
    is Char::Replace::replace( utf8_str("abcd"), $map ), utf8_str("AAbc5"),
        q[ASCII replacement on upgraded string];
}

# ---------------------------------------------------------------------------
# Deletion still works in UTF-8 context
# ---------------------------------------------------------------------------
{
    note "deletion of ASCII chars in UTF-8 string";

    my $map = map_with( ord('l') => "" );
    is Char::Replace::replace( utf8_str("héllo"), $map ), utf8_str("héo"),
        q[delete 'l' from UTF-8 string];

    $map = map_with( ord(' ') => "" );
    is Char::Replace::replace( utf8_str("hello wörld"), $map ), utf8_str("hellowörld"),
        q[delete space from UTF-8 string with ö];
}

# ---------------------------------------------------------------------------
# Non-UTF-8 strings: high-byte replacement must still work
# ---------------------------------------------------------------------------
{
    note "non-UTF-8: high byte replacement works as before";

    my $map = map_with( 0xA9 => "COPYRIGHT" );
    my $str = "a" . chr(0xA9) . "b";    # Latin-1, no UTF-8 flag
    is Char::Replace::replace( $str, $map ), "aCOPYRIGHTb",
        q[high byte replaced in non-UTF-8 string];

    $map = map_with( 255 => "END" );
    is Char::Replace::replace( chr(255), $map ), "END",
        q[byte 255 replaced in non-UTF-8 string];
}

# ---------------------------------------------------------------------------
# Mixed: string with many multi-byte chars and ASCII replacements
# ---------------------------------------------------------------------------
{
    note "mixed multi-byte and ASCII replacements";

    my $map = map_with( ord('a') => "A", ord('z') => "Z" );
    my $input    = utf8_str("aéèêëàâ z ñüöäîïôûù");
    my $expected = utf8_str("Aéèêëàâ Z ñüöäîïôûù");

    is Char::Replace::replace( $input, $map ), $expected,
        q[ASCII replaced, all accented chars preserved];
}

# ---------------------------------------------------------------------------
# Edge case: empty string with UTF-8 flag
# ---------------------------------------------------------------------------
{
    note "empty UTF-8 string";
    my $map = map_with( ord('a') => "X" );
    is Char::Replace::replace( utf8_str(""), $map ), utf8_str(""),
        q[empty UTF-8 string returns empty];
}

# ---------------------------------------------------------------------------
# Edge case: string that is entirely multi-byte
# ---------------------------------------------------------------------------
{
    note "entirely multi-byte UTF-8 string";
    my $map = map_with( ord('a') => "X" );
    my $input    = utf8_str("éàü");
    my $expected = utf8_str("éàü");

    is Char::Replace::replace( $input, $map ), $expected,
        q[fully multi-byte string unchanged with ASCII-only map];
}

# ---------------------------------------------------------------------------
# Buffer growth with UTF-8 content
# ---------------------------------------------------------------------------
{
    note "buffer growth with mixed UTF-8 and expansion";
    my $map = map_with( ord('x') => "XXXXX" );
    my $input    = utf8_str( ("x\x{e9}" x 50) );    # 50 × (x + é)
    my $expected = utf8_str( ("XXXXX\x{e9}" x 50) );

    is Char::Replace::replace( $input, $map ), $expected,
        q[buffer grows correctly with interleaved UTF-8 and expansion];
}

done_testing;
