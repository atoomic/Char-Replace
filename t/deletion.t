#!/usr/bin/perl -w

# Tests for character deletion via empty string in map

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "single character deletion";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';

    is Char::Replace::replace( "abcd", \@map ), "bcd",
        q[delete 'a' from "abcd"];
    is Char::Replace::replace( "aaaa", \@map ), "",
        q[delete all 'a' from "aaaa"];
    is Char::Replace::replace( "bcde", \@map ), "bcde",
        q[no 'a' in string, unchanged];
}

{
    note "multiple character deletion";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';
    $map[ ord('c') ] = '';

    is Char::Replace::replace( "abcd", \@map ), "bd",
        q[delete 'a' and 'c'];
    is Char::Replace::replace( "aaccbb", \@map ), "bb",
        q[delete repeated 'a' and 'c'];
}

{
    note "delete all characters";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';
    $map[ ord('b') ] = '';
    $map[ ord('c') ] = '';
    $map[ ord('d') ] = '';

    is Char::Replace::replace( "abcd", \@map ), "",
        q[delete all chars yields empty string];
    is Char::Replace::replace( "aabbccdd", \@map ), "",
        q[delete all repeated chars];
}

{
    note "mixed deletion and replacement";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';      # delete
    $map[ ord('b') ] = 'BB';   # expand
    $map[ ord('c') ] = 'X';    # replace 1:1

    is Char::Replace::replace( "abcd", \@map ), "BBXd",
        q[delete 'a', expand 'b', replace 'c'];
    is Char::Replace::replace( "dcba", \@map ), "dXBB",
        q[reverse order: same result logic];
}

{
    note "deletion of whitespace characters";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord(' ') ]  = '';
    $map[ ord("\t") ] = '';
    $map[ ord("\n") ] = '';

    is Char::Replace::replace( "hello world", \@map ), "helloworld",
        q[delete spaces];
    is Char::Replace::replace( "a\tb\nc", \@map ), "abc",
        q[delete tabs and newlines];
    is Char::Replace::replace( "  \t\n  ", \@map ), "",
        q[all whitespace deleted];
}

{
    note "deletion with high-byte characters";
    my @map = @{ Char::Replace::identity_map() };
    $map[255] = '';

    is Char::Replace::replace( chr(255), \@map ), "",
        q[delete char 255];
    is Char::Replace::replace( "a" . chr(255) . "b", \@map ), "ab",
        q[delete char 255 in context];

    $map[128] = '';
    is Char::Replace::replace( chr(128) . "x" . chr(255), \@map ), "x",
        q[delete chars 128 and 255];
}

{
    note "deletion preserves UTF-8 flag";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('l') ] = '';

    is Char::Replace::replace( "héllo", \@map ), "héo",
        q[delete 'l' from UTF-8 string];
}

{
    note "deletion on empty string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';

    is Char::Replace::replace( "", \@map ), "",
        q[delete from empty string];
}

{
    note "deletion with string growth needed";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';           # delete
    $map[ ord('b') ] = 'BBBBB';     # expand

    my $input  = ("ab" x 50);       # 100 chars, will need growth from expansion
    my $expect = ("BBBBB" x 50);    # 250 chars after deleting 'a' and expanding 'b'

    is Char::Replace::replace( $input, \@map ), $expect,
        q[deletion + expansion with buffer growth];
}

{
    note "undef in map does NOT delete (keeps original char)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = undef;

    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[undef in map keeps original character];
}

done_testing;
