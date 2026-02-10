#!/usr/bin/perl -w

# Tests for replace_inplace() — in-place 1:1 byte replacement

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "basic in-place replacement";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    my $str = "abcd";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "Xbcd", q[a -> X in place];
    is $count, 1,      q[1 replacement made];
}

{
    note "multiple replacements";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'A';
    $map[ ord('b') ] = 'B';
    $map[ ord('c') ] = 'C';
    $map[ ord('d') ] = 'D';

    my $str = "abcd";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "ABCD", q[a->A, b->B, c->C, d->D in place];
    is $count, 4,      q[4 replacements];
}

{
    note "no-op map (identity): zero replacements";
    my @map = @{ Char::Replace::identity_map() };

    my $str = "hello world";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "hello world", q[identity map: string unchanged];
    is $count, 0,             q[0 replacements (identity)];
}

{
    note "IV entry: replace via ordinal value";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('Z');    # IV

    my $str = "abcabc";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "ZbcZbc", q[IV: a -> Z in place];
    is $count, 2,        q[2 IV replacements];
}

{
    note "mixed PV and IV entries";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';         # PV
    $map[ ord('d') ] = ord('!');    # IV

    my $str = "abcd";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "Xbc!", q[mixed PV/IV in place];
    is $count, 2,      q[2 replacements (mixed)];
}

{
    note "invalid map: undef";
    my $str = "hello";
    my $count = Char::Replace::replace_inplace( $str, undef );
    is $str,   "hello", q[undef map: unchanged];
    is $count, 0,       q[0 replacements with undef map];
}

{
    note "invalid map: empty array";
    my $str = "hello";
    my $count = Char::Replace::replace_inplace( $str, [] );
    is $str,   "hello", q[empty map: unchanged];
    is $count, 0,       q[0 replacements with empty map];
}

{
    note "non-string input: returns 0";
    my $count = Char::Replace::replace_inplace( undef, [] );
    is $count, 0, q[undef input: returns 0];

    my @arr = (1, 2, 3);
    $count = Char::Replace::replace_inplace( \@arr, [] );
    is $count, 0, q[ref input: returns 0];
}

{
    note "empty string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    my $str = "";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "",  q[empty string: unchanged];
    is $count, 0,   q[0 replacements on empty string];
}

{
    note "long string (buffer larger than 64)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    my $str = "a" x 200;
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "X" x 200, q[200 a's -> 200 X's];
    is $count, 200,       q[200 replacements];
}

{
    note "UTF-8 safety: multi-byte chars untouched";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('h') ] = 'H';
    $map[0xA9] = 'X';    # would corrupt é if applied

    my $str = "héllo";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "Héllo", q[UTF-8: h->H, multi-byte preserved];
    is $count, 1,       q[only ASCII 'h' replaced];
}

{
    note "UTF-8 safety: 3-byte CJK characters";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = 'X';

    my $str = "x日x";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "X日X", q[CJK 3-byte preserved, ASCII replaced];
    is $count, 2,      q[2 ASCII replacements around CJK];
}

{
    note "UTF-8 safety: 4-byte emoji";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'A';

    my $str = "a😀a";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "A😀A", q[emoji 4-byte preserved, ASCII replaced];
    is $count, 2,       q[2 replacements around emoji];
}

{
    note "multi-char PV entry: croaks";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'XYZ';    # would expand

    my $str = "abcd";
    my $died = !eval { Char::Replace::replace_inplace( $str, \@map ); 1 };
    ok $died, q[multi-char PV entry causes croak];
    like $@, qr/replace_inplace.*single-char/, q[error message mentions single-char];
}

{
    note "empty string PV entry: croaks";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = '';    # would delete

    my $str = "abcd";
    my $died = !eval { Char::Replace::replace_inplace( $str, \@map ); 1 };
    ok $died, q[empty PV entry causes croak];
    like $@, qr/replace_inplace.*single-char/, q[error message mentions single-char];
}

{
    note "IV out of range: keeps original";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = -1;
    $map[ ord('b') ] = 256;

    my $str = "abcd";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "abcd", q[out-of-range IVs: unchanged];
    is $count, 0,      q[0 replacements for out-of-range];
}

{
    note "NV entry: truncated to IV";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 65.9;    # truncates to 65 = 'A'

    my $str = "abcd";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "Abcd", q[NV 65.9 -> IV 65 = 'A'];
    is $count, 1,      q[1 NV replacement];
}

{
    note "null byte handling";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    my $str = "\0\0a\0\0";
    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "\0\0X\0\0", q[null bytes preserved, 'a' replaced];
    is $count, 1,            q[1 replacement among null bytes];
}

{
    note "replace_inplace vs replace: equivalent for 1:1 maps";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'A';
    $map[ ord('e') ] = 'E';
    $map[ ord('i') ] = 'I';
    $map[ ord('o') ] = 'O';
    $map[ ord('u') ] = 'U';

    my $input = "the quick brown fox jumps over the lazy dog";
    my $expected = Char::Replace::replace( $input, \@map );

    my $str = $input;
    Char::Replace::replace_inplace( $str, \@map );
    is $str, $expected, q[replace_inplace matches replace for 1:1 map];
}

{
    note "non-UTF-8 string: high bytes ARE replaced";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xA9] = 'X';

    my $str = "a\xA9b";
    utf8::downgrade($str);

    my $count = Char::Replace::replace_inplace( $str, \@map );
    is $str,   "aXb", q[non-UTF-8: raw 0xA9 byte IS replaced];
    is $count, 1,     q[1 replacement on non-UTF-8 high byte];
}

done_testing;
