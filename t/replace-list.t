#!/usr/bin/perl -w

# Tests for replace_list() — batch string replacement

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "basic: fast-path (1:1 replacements)";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';
    $map->[ord('b')] = 'Y';

    my @results = Char::Replace::replace_list( ["aaa", "bbb", "abc", "xyz"], $map );
    is scalar @results, 4, "4 results returned";
    is $results[0], "XXX",  "all a -> X";
    is $results[1], "YYY",  "all b -> Y";
    is $results[2], "XYc",  "mixed replacement";
    is $results[3], "xyz",  "no-match pass-through";
}

{
    note "equivalence: replace_list matches replace() for each element";
    my $map = Char::Replace::identity_map();
    $map->[ord('x')] = 'Z';
    $map->[ord(' ')] = '_';

    my @inputs = ("hello world", "xxx", "no match", "", "x x x");
    my @list_results = Char::Replace::replace_list( \@inputs, $map );
    for my $i (0 .. $#inputs) {
        my $single = Char::Replace::replace( $inputs[$i], $map );
        is $list_results[$i], $single,
            "replace_list matches replace for: " . quotemeta($inputs[$i]);
    }
}

{
    note "general path: multi-char expansion";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'XY';
    $map->[ord('b')] = 'ZZZ';

    my @results = Char::Replace::replace_list( ["abc", "bba"], $map );
    is $results[0], "XYZZZc", "multi-char expansion: abc";
    is $results[1], "ZZZZZZXY", "multi-char expansion: bba";
}

{
    note "general path: deletion (empty string)";
    my $map = Char::Replace::identity_map();
    $map->[ord('x')] = '';

    my @results = Char::Replace::replace_list( ["axbxc", "xxx", "abc"], $map );
    is $results[0], "abc",  "deletion: axbxc -> abc";
    is $results[1], "",     "deletion: all deleted";
    is $results[2], "abc",  "deletion: no match unchanged";
}

{
    note "general path: coderef callbacks";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = sub { uc $_[0] };

    my @results = Char::Replace::replace_list( ["abc", "aaa"], $map );
    is $results[0], "Abc",  "coderef: abc";
    is $results[1], "AAA",  "coderef: aaa";
}

{
    note "general path: IV replacement";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = ord('Z');

    my @results = Char::Replace::replace_list( ["abc", "axa"], $map );
    is $results[0], "Zbc",  "IV replacement: a -> Z";
    is $results[1], "ZxZ",  "IV replacement: axa";
}

{
    note "UTF-8 strings: fast path";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @results = Char::Replace::replace_list( ["café", "naïf", "abc"], $map );
    is $results[0], "cXfé", "UTF-8: café -> cXfé";
    is $results[1], "nXïf", "UTF-8: naïf -> nXïf";
    is $results[2], "Xbc",   "ASCII: abc -> Xbc";
}

{
    note "UTF-8 strings: general path";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'AA';

    my @results = Char::Replace::replace_list( ["café", "abc"], $map );
    is $results[0], "cAAfé", "UTF-8 general: café expansion";
    is $results[1], "AAbc",   "ASCII general: abc expansion";
}

{
    note "mixed UTF-8 and ASCII in same batch";
    my $map = Char::Replace::identity_map();
    $map->[ord('x')] = 'Y';

    my @results = Char::Replace::replace_list( ["fox", "hêllô", "box"], $map );
    is $results[0], "foY",    "ASCII: fox";
    is $results[1], "hêllô", "UTF-8: no match unchanged";
    is $results[2], "boY",    "ASCII: box";
}

{
    note "undef elements in input array";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @results = Char::Replace::replace_list( ["abc", undef, "xyz"], $map );
    is scalar @results, 3,     "3 results for 3 elements";
    is $results[0], "Xbc",    "first element replaced";
    is $results[1], undef,    "undef element -> undef";
    is $results[2], "xyz",    "third element unchanged";
}

{
    note "ref elements in input array (treated as invalid)";
    my $map = Char::Replace::identity_map();

    my @results = Char::Replace::replace_list( ["abc", [1,2], {a=>1}, "xyz"], $map );
    is scalar @results, 4,     "4 results";
    is $results[0], "abc",    "string: pass-through";
    is $results[1], undef,    "arrayref -> undef";
    is $results[2], undef,    "hashref -> undef";
    is $results[3], "xyz",    "string: pass-through";
}

{
    note "empty input array";
    my $map = Char::Replace::identity_map();
    my @results = Char::Replace::replace_list( [], $map );
    is scalar @results, 0, "empty array -> empty results";
}

{
    note "single element";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'Z';

    my @results = Char::Replace::replace_list( ["abc"], $map );
    is scalar @results, 1,   "single element array";
    is $results[0], "Zbc",   "single element replaced";
}

{
    note "empty strings in array";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @results = Char::Replace::replace_list( ["", "abc", ""], $map );
    is $results[0], "",     "empty string preserved";
    is $results[1], "Xbc",  "non-empty replaced";
    is $results[2], "",     "empty string preserved";
}

{
    note "no map or invalid map: pass-through";
    my @inputs = ("abc", "xyz");

    my @r1 = Char::Replace::replace_list( \@inputs, undef );
    is $r1[0], "abc", "undef map: pass-through";
    is $r1[1], "xyz", "undef map: pass-through";

    my @r2 = Char::Replace::replace_list( \@inputs, [] );
    is $r2[0], "abc", "empty map: pass-through";
    is $r2[1], "xyz", "empty map: pass-through";
}

{
    note "invalid first argument: croaks";
    my $map = Char::Replace::identity_map();

    like dies { Char::Replace::replace_list( "not_a_ref", $map ) },
        qr/replace_list.*array reference/,
        "string arg croaks";

    like dies { Char::Replace::replace_list( {a => 1}, $map ) },
        qr/replace_list.*array reference/,
        "hashref arg croaks";

    like dies { Char::Replace::replace_list( undef, $map ) },
        qr/replace_list.*array reference/,
        "undef arg croaks";
}

{
    note "large batch: correctness check";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'Z';

    my @inputs = map { "a" x $_ } 1 .. 100;
    my @results = Char::Replace::replace_list( \@inputs, $map );
    is scalar @results, 100, "100 results";

    for my $i (0 .. 99) {
        is $results[$i], "Z" x ($i + 1),
            "batch element $i: " . ($i + 1) . " replacements";
    }
}

{
    note "build_map integration";
    my $map = Char::Replace::build_map( 'a' => 'X', 'b' => 'Y' );
    my @results = Char::Replace::replace_list( ["abc", "bca", "xyz"], $map );
    is $results[0], "XYc", "build_map + replace_list: abc";
    is $results[1], "YcX", "build_map + replace_list: bca";
    is $results[2], "xyz", "build_map + replace_list: xyz";
}

{
    note "numeric string coercion";
    my $map = Char::Replace::identity_map();
    $map->[ord('1')] = 'X';

    my @results = Char::Replace::replace_list( [123, 456, "1ab"], $map );
    is $results[0], "X23",  "integer 123 coerced to string";
    is $results[1], "456",  "integer 456 no match";
    is $results[2], "Xab",  "string 1ab replaced";
}

# === Compiled map support ===

{
    note "compiled map: fast-path (1:1 replacements)";
    my $map = Char::Replace::build_map( 'a' => 'X', 'b' => 'Y' );
    my $compiled = Char::Replace::compile_map($map);

    my @results = Char::Replace::replace_list( ["aaa", "bbb", "abc", "xyz"], $compiled );
    is scalar @results, 4, "4 results returned";
    is $results[0], "XXX",  "compiled: all a -> X";
    is $results[1], "YYY",  "compiled: all b -> Y";
    is $results[2], "XYc",  "compiled: mixed replacement";
    is $results[3], "xyz",  "compiled: no-match pass-through";
}

{
    note "compiled map: equivalence with regular map";
    my $map = Char::Replace::build_map(
        'a' => 'A', 'e' => 'E', 'i' => 'I', 'o' => 'O', 'u' => 'U',
    );
    my $compiled = Char::Replace::compile_map($map);

    my @inputs = ("hello world", "the quick brown fox", "aeiou", "", "no vowels");
    my @list_compiled = Char::Replace::replace_list( \@inputs, $compiled );
    my @list_regular  = Char::Replace::replace_list( \@inputs, $map );
    for my $i (0 .. $#inputs) {
        is $list_compiled[$i], $list_regular[$i],
            "compiled matches regular for: " . quotemeta($inputs[$i]);
    }
}

{
    note "compiled map: UTF-8 strings";
    my $map = Char::Replace::build_map( 'a' => 'X' );
    my $compiled = Char::Replace::compile_map($map);

    my @results = Char::Replace::replace_list( ["café", "naïf", "abc"], $compiled );
    is $results[0], "cXfé", "compiled UTF-8: café -> cXfé";
    is $results[1], "nXïf", "compiled UTF-8: naïf -> nXïf";
    is $results[2], "Xbc",   "compiled ASCII: abc -> Xbc";
}

{
    note "compiled map: undef and ref elements";
    my $map = Char::Replace::build_map( 'a' => 'X' );
    my $compiled = Char::Replace::compile_map($map);

    my @results = Char::Replace::replace_list( ["abc", undef, [1,2], "xyz"], $compiled );
    is scalar @results, 4,     "4 results";
    is $results[0], "Xbc",    "string replaced";
    is $results[1], undef,    "undef -> undef";
    is $results[2], undef,    "ref -> undef";
    is $results[3], "xyz",    "pass-through";
}

{
    note "compiled map: empty array";
    my $map = Char::Replace::build_map( 'a' => 'X' );
    my $compiled = Char::Replace::compile_map($map);

    my @results = Char::Replace::replace_list( [], $compiled );
    is scalar @results, 0, "compiled + empty array -> empty results";
}

{
    note "compiled map: large batch";
    my $map = Char::Replace::build_map( 'a' => 'Z' );
    my $compiled = Char::Replace::compile_map($map);

    my @inputs = map { "a" x $_ } 1 .. 50;
    my @results = Char::Replace::replace_list( \@inputs, $compiled );
    is scalar @results, 50, "50 results";
    for my $i (0 .. 49) {
        is $results[$i], "Z" x ($i + 1),
            "compiled batch element $i" or last;
    }
}

{
    note "compiled map: IV entries";
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = ord('Z');
    my $compiled = Char::Replace::compile_map($map);

    my @results = Char::Replace::replace_list( ["abc", "axa"], $compiled );
    is $results[0], "Zbc",  "compiled IV: a -> Z";
    is $results[1], "ZxZ",  "compiled IV: axa";
}

done_testing;
