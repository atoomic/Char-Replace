#!/usr/bin/perl -w

# Tests for Char::Replace::build_map() convenience constructor

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "basic build_map: single-char replacement";
    my $map = Char::Replace::build_map( 'a' => 'X' );
    is ref($map), 'ARRAY', q[returns array ref];
    is scalar @$map, 256, q[256 entries];
    is Char::Replace::replace( "abcd", $map ), "Xbcd",
        q[a -> X via build_map];
}

{
    note "build_map: multi-char expansion";
    my $map = Char::Replace::build_map( 'a' => 'AAA', 'd' => 'DDD' );
    is Char::Replace::replace( "abcd", $map ), "AAAbcDDD",
        q[a -> AAA, d -> DDD];
}

{
    note "build_map: deletion via empty string";
    my $map = Char::Replace::build_map( 'b' => '', 'c' => '' );
    is Char::Replace::replace( "abcd", $map ), "ad",
        q[b and c deleted];
}

{
    note "build_map: IV entry";
    my $map = Char::Replace::build_map( 'a' => ord('A') );
    is Char::Replace::replace( "abc", $map ), "Abc",
        q[IV via build_map];
}

{
    note "build_map: unmapped chars pass through";
    my $map = Char::Replace::build_map( 'z' => 'Z' );
    is Char::Replace::replace( "hello", $map ), "hello",
        q[no z in input: unchanged];
}

{
    note "build_map: empty hash = identity";
    my $map = Char::Replace::build_map();
    is Char::Replace::replace( "hello", $map ), "hello",
        q[empty build_map = identity];
}

{
    note "build_map: works with replace_inplace";
    my $map = Char::Replace::build_map( 'a' => 'X', 'b' => 'Y' );
    my $str = "abcabc";
    my $count = Char::Replace::replace_inplace( $str, $map );
    is $str,   "XYcXYc", q[build_map + replace_inplace];
    is $count, 4,        q[4 replacements];
}

{
    note "build_map: multi-char key croaks";
    my $died = !eval { Char::Replace::build_map( 'ab' => 'X' ); 1 };
    ok $died, q[multi-char key causes croak];
    like $@, qr/single character/, q[error mentions single character];
}

{
    note "build_map: empty key croaks";
    my $died = !eval { Char::Replace::build_map( '' => 'X' ); 1 };
    ok $died, q[empty key causes croak];
}

done_testing;
