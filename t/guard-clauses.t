#!/usr/bin/perl -w

# Tests for input validation guard clauses and early-return paths.
#
# These cover the defensive code paths in Replace.xs that handle
# invalid or edge-case inputs (undef, refs, bad maps, croaks).
# Each test targets a specific guard clause in the XSUB wrappers
# or the internal C functions.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

sub id_map { @{ Char::Replace::identity_map() } }

# ===================================================================
# replace() — invalid string inputs (XSUB guard: SvOK && !SvROK)
# ===================================================================

subtest 'replace: undef string returns undef' => sub {
    my @map = id_map();
    my $result = Char::Replace::replace( undef, \@map );
    is $result, undef, "undef input -> undef output";
};

subtest 'replace: reference string returns undef' => sub {
    my @map = id_map();
    my $result = Char::Replace::replace( [1,2,3], \@map );
    is $result, undef, "arrayref input -> undef";

    $result = Char::Replace::replace( {a => 1}, \@map );
    is $result, undef, "hashref input -> undef";

    $result = Char::Replace::replace( \42, \@map );
    is $result, undef, "scalarref input -> undef";
};

# ===================================================================
# replace() — invalid/empty map inputs (internal guard)
# ===================================================================

subtest 'replace: undef map returns copy of input' => sub {
    my $result = Char::Replace::replace( "hello", undef );
    is $result, "hello", "undef map -> copy of input";
};

subtest 'replace: non-arrayref map returns copy of input' => sub {
    my $result = Char::Replace::replace( "hello", "not a ref" );
    is $result, "hello", "string map -> copy of input";

    $result = Char::Replace::replace( "hello", { a => 1 } );
    is $result, "hello", "hashref map -> copy of input";

    $result = Char::Replace::replace( "hello", \42 );
    is $result, "hello", "scalarref map -> copy of input";
};

subtest 'replace: empty arrayref map returns copy of input' => sub {
    my $result = Char::Replace::replace( "hello", [] );
    is $result, "hello", "empty arrayref -> copy of input";
};

# ===================================================================
# replace_inplace() — invalid string inputs (XSUB guard)
# ===================================================================

subtest 'replace_inplace: undef string returns 0' => sub {
    my @map = id_map();
    my $count = Char::Replace::replace_inplace( undef, \@map );
    is $count, 0, "undef string -> 0";
};

subtest 'replace_inplace: reference string returns 0' => sub {
    my @map = id_map();
    my $ref = [1,2,3];
    my $count = Char::Replace::replace_inplace( $ref, \@map );
    is $count, 0, "arrayref string -> 0 (no modification)";
};

# ===================================================================
# replace_inplace() — invalid/empty map inputs (internal guard)
# ===================================================================

subtest 'replace_inplace: undef map returns 0' => sub {
    my $str = "hello";
    my $count = Char::Replace::replace_inplace( $str, undef );
    is $count, 0, "undef map -> 0";
    is $str, "hello", "string unchanged";
};

subtest 'replace_inplace: non-arrayref map returns 0' => sub {
    my $str = "hello";
    my $count = Char::Replace::replace_inplace( $str, "not a ref" );
    is $count, 0, "string map -> 0";
    is $str, "hello", "string unchanged";
};

subtest 'replace_inplace: empty arrayref map returns 0' => sub {
    my $str = "hello";
    my $count = Char::Replace::replace_inplace( $str, [] );
    is $count, 0, "empty map -> 0";
    is $str, "hello", "string unchanged";
};

# ===================================================================
# replace_inplace() — croak on multi-char string entry
# ===================================================================

subtest 'replace_inplace: multi-char string entry croaks' => sub {
    my @map = id_map();
    $map[ ord('a') ] = 'XY';    # 2-char string -> croak

    my $str = "abc";
    like dies { Char::Replace::replace_inplace( $str, \@map ) },
        qr/replace_inplace.*2.*single-char/i,
        "multi-char string entry produces descriptive croak";
};

subtest 'replace_inplace: empty string entry croaks' => sub {
    my @map = id_map();
    $map[ ord('a') ] = '';    # deletion -> croak (slen=0)

    my $str = "abc";
    like dies { Char::Replace::replace_inplace( $str, \@map ) },
        qr/replace_inplace.*0.*single-char/i,
        "empty string (deletion) entry croaks in replace_inplace";
};

# ===================================================================
# replace_inplace() — IV/NV edge cases
# ===================================================================

subtest 'replace_inplace: IV replacement (basic)' => sub {
    my @map = id_map();
    $map[ ord('a') ] = ord('A');
    $map[ ord('b') ] = ord('B');

    my $str = "abcabc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "ABcABc", "IV replacement in-place";
    is $count, 4,        "4 bytes changed";
};

subtest 'replace_inplace: IV zero replaces with null byte' => sub {
    my @map = id_map();
    $map[ ord('a') ] = 0;

    my $str = "abc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is length($str), 3,    "length preserved";
    is $str, "\0bc",       "a replaced with null byte";
    is $count, 1,          "1 replacement";
};

subtest 'replace_inplace: IV 255 (max valid byte)' => sub {
    my @map = id_map();
    $map[ ord('a') ] = 255;

    my $str = "abc";
    utf8::downgrade($str);
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str, chr(255) . "bc", "IV 255 replaces correctly";
    is $count, 1, "1 replacement";
};

subtest 'replace_inplace: out-of-range IV keeps original' => sub {
    my @map = id_map();
    $map[ ord('a') ] = -1;

    my $str = "abc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "abc", "IV -1: unchanged";
    is $count, 0,     "0 replacements";

    $str = "abc";
    $map[ ord('a') ] = 256;
    $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "abc", "IV 256: unchanged";
    is $count, 0,     "0 replacements";

    $str = "abc";
    $map[ ord('a') ] = 99999;
    $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "abc", "IV 99999: unchanged";
    is $count, 0,     "0 replacements";
};

subtest 'replace_inplace: NV (float) truncated to IV' => sub {
    my @map = id_map();
    $map[ ord('a') ] = 65.9;    # truncates to 65 = 'A'

    my $str = "abcabc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "AbcAbc", "NV 65.9 -> chr(65) = 'A'";
    is $count, 2,        "2 replacements";
};

subtest 'replace_inplace: NV out-of-range keeps original' => sub {
    my @map = id_map();
    $map[ ord('a') ] = 256.5;

    my $str = "abc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "abc", "NV 256.5: unchanged";
    is $count, 0,     "0 replacements";
};

# ===================================================================
# replace_inplace() — UTF-8 safety with IV/NV entries
# ===================================================================

subtest 'replace_inplace: IV on UTF-8 string skips multibyte' => sub {
    my @map = id_map();
    $map[ ord('a') ] = ord('A');

    my $str = "café";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    like $str, qr/^cAfé$/, "ASCII 'a' replaced, multibyte preserved";
    is $count, 1, "1 replacement";
};

# ===================================================================
# trim() — invalid inputs (XSUB guard)
# ===================================================================

subtest 'trim: undef returns undef' => sub {
    my $result = Char::Replace::trim( undef );
    is $result, undef, "undef -> undef";
};

subtest 'trim: reference returns undef' => sub {
    my $result = Char::Replace::trim( [1,2,3] );
    is $result, undef, "arrayref -> undef";

    $result = Char::Replace::trim( {a => 1} );
    is $result, undef, "hashref -> undef";
};

# ===================================================================
# trim_inplace() — invalid inputs (XSUB guard)
# ===================================================================

subtest 'trim_inplace: undef returns 0' => sub {
    my $count = Char::Replace::trim_inplace( undef );
    is $count, 0, "undef -> 0";
};

subtest 'trim_inplace: reference returns 0' => sub {
    my $ref = [1,2,3];
    my $count = Char::Replace::trim_inplace( $ref );
    is $count, 0, "arrayref -> 0";
};

# ===================================================================
# trim() — custom chars: ref/undef second arg falls back to default
# ===================================================================

subtest 'trim: ref as custom chars falls back to default whitespace' => sub {
    my $result = Char::Replace::trim( "  hello  ", [1,2,3] );
    is $result, "hello", "ref as chars -> default whitespace trim";
};

subtest 'trim: undef as custom chars falls back to default whitespace' => sub {
    my $result = Char::Replace::trim( "  hello  ", undef );
    is $result, "hello", "undef as chars -> default whitespace trim";
};

subtest 'trim_inplace: ref as custom chars falls back to default' => sub {
    my $str = "  hello  ";
    my $count = Char::Replace::trim_inplace( $str, [1,2,3] );
    is $str,   "hello", "ref as chars -> default whitespace trim";
    is $count, 4,       "4 bytes trimmed";
};

# ===================================================================
# replace_inplace() — no bytes changed means no SvSETMAGIC call
# ===================================================================

subtest 'replace_inplace: mapped char not in input -> zero count' => sub {
    my @map = id_map();
    $map[ ord('z') ] = 'Z';

    my $str = "abc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $count, 0,     "no matching bytes -> 0 count";
    is $str,   "abc", "string unchanged";
};

# ===================================================================
# replace_inplace() — same byte in map (identity entry, no change)
# ===================================================================

subtest 'replace_inplace: identity entry counted as no-change' => sub {
    my @map = id_map();
    # 'a' maps to 'a' (identity) — should NOT count as a replacement
    $map[ ord('a') ] = 'a';

    my $str = "aaa";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $count, 0,     "identity mapping -> 0 count";
    is $str,   "aaa", "string unchanged";
};

# ===================================================================
# compile_map edge: IV-only map compiles correctly
# ===================================================================

subtest 'compile_map: all-IV map compiles and works' => sub {
    my @map;
    $map[ ord('a') ] = ord('A');
    $map[ ord('b') ] = ord('B');

    my $compiled = Char::Replace::compile_map(\@map);
    ok defined $compiled, "IV-only sparse map compiles";

    is Char::Replace::replace( "abc", $compiled ), "ABc",
        "compiled IV map: a->A, b->B";

    my $str = "aabb";
    Char::Replace::replace_inplace( $str, $compiled );
    is $str, "AABB", "compiled IV map works in-place";
};

done_testing;
