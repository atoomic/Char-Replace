use strict;
use warnings;

use Test2::Bundle::Extended;
use Char::Replace;

# Test that replace(), trim(), replace_inplace(), and trim_inplace()
# accept non-string inputs (integers, floats) by coercing them to strings.
# Previously, only SvPOK scalars were accepted; non-PV SVs silently
# returned undef/0.

my $map = Char::Replace::identity_map();
$map->[ ord('2') ] = 'X';    # replace '2' with 'X'
$map->[ ord(' ') ] = '_';    # replace space with underscore

# ========================================================
# replace() input coercion
# ========================================================

subtest 'replace() accepts integer input' => sub {
    my $n = 42;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '4X', 'integer 42 → "4X" (2→X applied)' );
};

subtest 'replace() accepts float input' => sub {
    my $n = 3.14;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '3.14', 'float 3.14 unchanged (no map entry for digits except 2)' );

    my $n2 = 12.5;
    my $result2 = Char::Replace::replace( $n2, $map );
    is( $result2, '1X.5', 'float 12.5 → "1X.5" (2→X applied)' );
};

subtest 'replace() accepts zero' => sub {
    my $n = 0;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '0', 'integer 0 → "0" (no map entry for 0)' );
};

subtest 'replace() accepts negative number' => sub {
    my $n = -42;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '-4X', 'negative -42 → "-4X" (2→X applied)' );
};

subtest 'replace() accepts string result of arithmetic' => sub {
    my $n = 10 + 12;   # Pure IV, no PV representation yet
    my $result = Char::Replace::replace( $n, $map );
    is( $result, 'XX', '10+12=22 → "XX" (both 2s replaced)' );
};

subtest 'replace() still rejects undef' => sub {
    my $result = Char::Replace::replace( undef, $map );
    is( $result, undef, 'undef → undef' );
};

subtest 'replace() still rejects references' => sub {
    is( Char::Replace::replace( [], $map ), undef, 'arrayref → undef' );
    is( Char::Replace::replace( {}, $map ), undef, 'hashref → undef' );
    is( Char::Replace::replace( sub {}, $map ), undef, 'coderef → undef' );
    is( Char::Replace::replace( \42, $map ), undef, 'scalar ref → undef' );
};

subtest 'replace() input not mutated' => sub {
    my $n = 42;
    Char::Replace::replace( $n, $map );
    is( $n, 42, 'original integer variable unchanged' );
};

# ========================================================
# trim() input coercion
# ========================================================

subtest 'trim() accepts integer input' => sub {
    my $n = 42;
    my $result = Char::Replace::trim( $n );
    is( $result, '42', 'integer 42 → "42" (no whitespace to trim)' );
};

subtest 'trim() accepts float input' => sub {
    my $n = 3.14;
    my $result = Char::Replace::trim( $n );
    is( $result, '3.14', 'float 3.14 → "3.14"' );
};

subtest 'trim() accepts zero' => sub {
    my $n = 0;
    my $result = Char::Replace::trim( $n );
    is( $result, '0', 'integer 0 → "0"' );
};

subtest 'trim() still rejects references' => sub {
    is( Char::Replace::trim( [] ), undef, 'arrayref → undef' );
    is( Char::Replace::trim( {} ), undef, 'hashref → undef' );
};

# ========================================================
# replace_inplace() input coercion
# ========================================================

subtest 'replace_inplace() accepts integer input' => sub {
    my $n = 42;
    my $count = Char::Replace::replace_inplace( $n, $map );
    is( $count, 1, 'one replacement made' );
    is( $n, '4X', 'integer stringified and replaced in place' );
};

subtest 'replace_inplace() accepts float input' => sub {
    my $n = 12.5;
    my $count = Char::Replace::replace_inplace( $n, $map );
    is( $count, 1, 'one replacement made' );
    is( $n, '1X.5', 'float stringified and replaced in place' );
};

subtest 'replace_inplace() accepts zero' => sub {
    my $n = 0;
    my $count = Char::Replace::replace_inplace( $n, $map );
    is( $count, 0, 'no replacements for "0"' );
};

subtest 'replace_inplace() still rejects references' => sub {
    my $ref = [];
    is( Char::Replace::replace_inplace( $ref, $map ), 0, 'arrayref → 0' );
};

# ========================================================
# trim_inplace() input coercion
# ========================================================

subtest 'trim_inplace() accepts integer input' => sub {
    my $n = 42;
    my $count = Char::Replace::trim_inplace( $n );
    is( $count, 0, 'no whitespace to trim from "42"' );
    is( $n, '42', 'value unchanged' );
};

subtest 'trim_inplace() accepts float input' => sub {
    my $n = 3.14;
    my $count = Char::Replace::trim_inplace( $n );
    is( $count, 0, 'no whitespace to trim from "3.14"' );
};

subtest 'trim_inplace() still rejects references' => sub {
    my $ref = {};
    is( Char::Replace::trim_inplace( $ref ), 0, 'hashref → 0' );
};

# ========================================================
# Edge cases: stringified values
# ========================================================

subtest 'replace() with large integer' => sub {
    my $n = 1234567890;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '1X34567890', 'large integer coerced and replaced' );
};

subtest 'replace() with scientific notation' => sub {
    my $n = 1e10;
    my $result = Char::Replace::replace( $n, $map );
    # Perl stringifies 1e10 to "10000000000"
    ok( defined $result, 'scientific notation accepted' );
    # The exact string depends on perl's stringification
};

subtest 'replace() with negative float' => sub {
    my $n = -2.5;
    my $result = Char::Replace::replace( $n, $map );
    is( $result, '-X.5', 'negative float coerced and replaced' );
};

# ========================================================
# Edge case: empty string (falsy but defined)
# ========================================================

subtest 'replace() with empty string' => sub {
    my $s = '';
    my $result = Char::Replace::replace( $s, $map );
    is( $result, '', 'empty string → empty string' );
};

subtest 'trim() with empty string' => sub {
    my $s = '';
    my $result = Char::Replace::trim( $s );
    is( $result, '', 'empty string → empty string' );
};

subtest 'replace_inplace() with empty string' => sub {
    my $s = '';
    my $count = Char::Replace::replace_inplace( $s, $map );
    is( $count, 0, 'no replacements on empty string' );
    is( $s, '', 'empty string unchanged' );
};

subtest 'trim_inplace() with empty string' => sub {
    my $s = '';
    my $count = Char::Replace::trim_inplace( $s );
    is( $count, 0, 'no whitespace trimmed from empty string' );
    is( $s, '', 'empty string unchanged' );
};

# ========================================================
# Edge case: string "0" (falsy but defined)
# ========================================================

subtest 'replace() with string "0"' => sub {
    my $s = "0";
    my $result = Char::Replace::replace( $s, $map );
    is( $result, '0', 'string "0" passes through' );
};

subtest 'trim() with string "0"' => sub {
    my $s = "0";
    my $result = Char::Replace::trim( $s );
    is( $result, '0', 'string "0" not trimmed away' );
};

# ========================================================
# Map reuse: verify map is not mutated between calls
# ========================================================

subtest 'map not mutated across calls' => sub {
    my $m = Char::Replace::build_map( 'a' => 'X' );

    my $r1 = Char::Replace::replace( "abc", $m );
    my $r2 = Char::Replace::replace( "aaa", $m );
    my $r3 = Char::Replace::replace( "xyz", $m );

    is( $r1, 'Xbc', 'first call correct' );
    is( $r2, 'XXX', 'second call correct' );
    is( $r3, 'xyz', 'third call correct (no matching chars)' );
};

done_testing;
