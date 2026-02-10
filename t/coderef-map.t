#!/usr/bin/perl -w

# Tests for code ref (callback) entries in the replacement map

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

sub fresh_map { @{ Char::Replace::identity_map() } }

{
    note "basic code ref: uppercase via callback";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { uc $_[0] };

    is Char::Replace::replace( "abcd", \@map ), "Abcd",
        q[code ref: a -> uc(a) = A];
}

{
    note "code ref returning multi-char string (expansion)";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "[$_[0]]" };

    is Char::Replace::replace( "abcd", \@map ), "[a]bcd",
        q[code ref expansion: a -> [a]];
}

{
    note "code ref returning empty string (deletion)";
    my @map = fresh_map();
    $map[ ord('b') ] = sub { "" };

    is Char::Replace::replace( "abcd", \@map ), "acd",
        q[code ref deletion: b -> empty];
}

{
    note "code ref returning undef (keep original)";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { undef };

    is Char::Replace::replace( "abcd", \@map ), "abcd",
        q[code ref returning undef: keep original];
}

{
    note "multiple code ref entries";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { uc $_[0] };
    $map[ ord('d') ] = sub { uc $_[0] };

    is Char::Replace::replace( "abcd", \@map ), "AbcD",
        q[two code ref entries: a->A, d->D];
}

{
    note "code ref mixed with PV and IV entries";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "X" };      # code ref
    $map[ ord('b') ] = 'Y';              # PV
    $map[ ord('c') ] = ord('Z');          # IV
    $map[ ord('d') ] = sub { '' };        # code ref (delete)

    is Char::Replace::replace( "abcd", \@map ), "XYZ",
        q[mixed code ref + PV + IV + deletion];
}

{
    note "code ref on every character";
    my @map = fresh_map();
    for my $c ( 'a' .. 'z' ) {
        $map[ ord($c) ] = sub { uc $_[0] };
    }

    is Char::Replace::replace( "hello world", \@map ), "HELLO WORLD",
        q[code ref on every letter: full uppercase];
}

{
    note "code ref receives correct character";
    my @seen;
    my @map = fresh_map();
    $map[ ord('x') ] = sub { push @seen, $_[0]; $_[0] };

    Char::Replace::replace( "xyx", \@map );
    is \@seen, ['x', 'x'], q[callback called twice with 'x'];
}

{
    note "code ref on empty string";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "X" };

    is Char::Replace::replace( "", \@map ), "",
        q[code ref on empty string: empty result];
}

{
    note "code ref with long string (buffer growth)";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "AAAA" };

    my $input  = "a" x 100;
    my $expect = "AAAA" x 100;

    is Char::Replace::replace( $input, \@map ), $expect,
        q[code ref: 100 expansions cause buffer growth];
}

{
    note "code ref with UTF-8 string: ASCII chars replaced, multi-byte preserved";
    my @map = fresh_map();
    $map[ ord('h') ] = sub { uc $_[0] };

    is Char::Replace::replace( "héllo", \@map ), "Héllo",
        q[code ref: h->H in UTF-8 string, é preserved];
}

{
    note "code ref with build_map";
    my $map = Char::Replace::build_map( 'a' => sub { "X" } );
    is Char::Replace::replace( "abcd", $map ), "Xbcd",
        q[build_map accepts code ref value];
}

{
    note "replace_inplace: code ref entry croaks";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "X" };

    my $str = "abcd";
    my $died = !eval { Char::Replace::replace_inplace( $str, \@map ); 1 };
    ok $died, q[code ref in replace_inplace causes croak];
    like $@, qr/code ref/, q[error message mentions code ref];
}

{
    note "code ref returning single char (1:1 replacement)";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { "X" };

    is Char::Replace::replace( "aaa", \@map ), "XXX",
        q[code ref: single-char return on repeated chars];
}

{
    note "stateful code ref (counter)";
    my $count = 0;
    my @map = fresh_map();
    $map[ ord('a') ] = sub { ++$count; "A$count" };

    is Char::Replace::replace( "abab", \@map ), "A1bA2b",
        q[stateful code ref: counter increments];
}

{
    note "code ref with no map entries (identity behavior)";
    my @map = fresh_map();

    is Char::Replace::replace( "hello", \@map ), "hello",
        q[no code ref entries: identity];
}

{
    note "code ref at boundary: map index 0 (null byte)";
    my @map = fresh_map();
    $map[0] = sub { "NULL" };

    my $input = "a\0b";
    is Char::Replace::replace( $input, \@map ), "aNULLb",
        q[code ref at index 0: null byte replaced];
}

{
    note "code ref at boundary: map index 255";
    my @map = fresh_map();
    $map[255] = sub { "FF" };

    my $input = "a" . chr(255) . "b";
    utf8::downgrade($input);
    is Char::Replace::replace( $input, \@map ), "aFFb",
        q[code ref at index 255: high byte replaced];
}

{
    note "code ref that dies propagates error cleanly";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { die "callback error" };

    my $died = !eval { Char::Replace::replace( "abc", \@map ); 1 };
    ok $died, q[die in callback propagates to caller];
    like $@, qr/callback error/, q[original error message preserved];
}

{
    note "code ref die does not leak memory (no crash after many iterations)";
    my @map = fresh_map();
    $map[ ord('a') ] = sub { die "leak test" };

    for (1..1000) {
        eval { Char::Replace::replace( "abc", \@map ) };
    }
    pass q[1000 die-in-callback iterations: no crash or corruption];
}

done_testing;
