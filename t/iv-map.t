#!/usr/bin/perl -w

# Tests for IV/NV (integer/float) entries in the replacement map

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "IV entry: replace via ordinal value";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');    # IV 65

    is Char::Replace::replace( "abcd", \@map ), "Abcd",
        q[IV ord('A') replaces 'a' with 'A'];
}

{
    note "multiple IV entries";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');
    $map[ ord('b') ] = ord('B');
    $map[ ord('c') ] = ord('C');
    $map[ ord('d') ] = ord('D');

    is Char::Replace::replace( "abcd", \@map ), "ABCD",
        q[IV: a->A, b->B, c->C, d->D];
    is Char::Replace::replace( "aabbccdd", \@map ), "AABBCCDD",
        q[IV: repeated chars];
    is Char::Replace::replace( "efgh", \@map ), "efgh",
        q[IV: unmapped chars unchanged];
}

{
    note "IV zero: replace with null character";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 0;

    my $result = Char::Replace::replace( "abc", \@map );
    is length($result), 3, q[IV 0: result length is 3];
    is $result, "\0bc", q[IV 0: 'a' replaced with null byte];
}

{
    note "IV boundary values";
    my @map = @{ Char::Replace::identity_map() };

    # IV = 255 (max valid byte)
    $map[ ord('a') ] = 255;
    my $r1 = Char::Replace::replace( "abc", \@map );
    is $r1, chr(255) . "bc", q[IV 255: max valid byte];

    # IV = 1 (min non-zero)
    $map[ ord('b') ] = 1;
    my $r2 = Char::Replace::replace( "abc", \@map );
    is $r2, chr(255) . chr(1) . "c", q[IV 1: min non-zero byte];
}

{
    note "IV out of range: keeps original character";
    my @map = @{ Char::Replace::identity_map() };

    $map[ ord('a') ] = -1;
    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[IV -1: out of range, unchanged];

    $map[ ord('a') ] = 256;
    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[IV 256: out of range, unchanged];

    $map[ ord('a') ] = 1000;
    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[IV 1000: out of range, unchanged];

    $map[ ord('a') ] = -100;
    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[IV -100: out of range, unchanged];
}

{
    note "NV (float) entry: truncated to IV";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 65.9;    # should truncate to 65 = 'A'

    is Char::Replace::replace( "abcd", \@map ), "Abcd",
        q[NV 65.9 truncated to 65 = 'A'];
}

{
    note "mixed IV and PV entries";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');      # IV
    $map[ ord('b') ] = 'BB';          # PV (expansion)
    $map[ ord('c') ] = '';            # PV (deletion)
    $map[ ord('d') ] = ord('D');      # IV

    # a -> A(IV), b -> BB(PV), c -> deleted, d -> D(IV)
    is Char::Replace::replace( "abcd", \@map ), "ABBD",
        q[mixed IV/PV/deletion: abcd -> ABBD];
}

{
    note "IV on empty string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');

    is Char::Replace::replace( "", \@map ), "",
        q[IV on empty string];
}

{
    note "IV with long string (buffer growth)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');

    my $input  = "a" x 200;
    my $expect = "A" x 200;

    is Char::Replace::replace( $input, \@map ), $expect,
        q[IV: 200 chars, no buffer growth needed (1:1 replacement)];
}

done_testing;
