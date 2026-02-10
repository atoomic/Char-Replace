use strict;
use warnings;
use Test::More;

use Char::Replace qw(replace_multi replace build_map identity_map compile_map);

# -- basic usage with array ref map --

{
    my $map = identity_map();
    $map->[ ord('a') ] = 'X';

    my @results = replace_multi( [ "abc", "aaa", "xyz" ], $map );
    is( $results[0], "Xbc", "replace_multi: basic replacement first string" );
    is( $results[1], "XXX", "replace_multi: basic replacement second string" );
    is( $results[2], "xyz", "replace_multi: no match third string" );
    is( scalar @results, 3, "replace_multi: returns correct count" );
}

# -- empty array --

{
    my $map = identity_map();
    my @results = replace_multi( [], $map );
    is( scalar @results, 0, "replace_multi: empty array returns empty list" );
}

# -- single element --

{
    my $map = build_map( 'x' => 'Y' );
    my @results = replace_multi( [ "fox" ], $map );
    is( $results[0], "foY", "replace_multi: single element" );
}

# -- undef elements --

{
    my $map = build_map( 'a' => 'Z' );
    my @results = replace_multi( [ "abc", undef, "aaa" ], $map );
    is( $results[0], "Zbc", "replace_multi: first element replaced" );
    is( $results[1], undef, "replace_multi: undef element preserved" );
    is( $results[2], "ZZZ", "replace_multi: third element replaced" );
}

# -- compiled map --

{
    my $map = compile_map( build_map( 'e' => 'E', 'o' => 'O' ) );
    my @results = replace_multi( [ "hello", "world", "test" ], $map );
    is( $results[0], "hEllO", "replace_multi compiled: hello -> hEllO" );
    is( $results[1], "wOrld", "replace_multi compiled: world -> wOrld" );
    is( $results[2], "tEst",  "replace_multi compiled: test -> tEst" );
}

# -- character deletion (general path) --

{
    my $map = build_map( 'x' => '' );
    my @results = replace_multi( [ "fox", "box", "xxx" ], $map );
    is( $results[0], "fo",  "replace_multi deletion: fox -> fo" );
    is( $results[1], "bo",  "replace_multi deletion: box -> bo" );
    is( $results[2], "",    "replace_multi deletion: xxx -> empty" );
}

# -- multi-char expansion (general path) --

{
    my $map = build_map( '&' => '&amp;', '<' => '&lt;' );
    my @results = replace_multi( [ "a&b", "x<y", "no match" ], $map );
    is( $results[0], "a&amp;b", "replace_multi expansion: & -> &amp;" );
    is( $results[1], "x&lt;y",  "replace_multi expansion: < -> &lt;" );
    is( $results[2], "no match", "replace_multi expansion: no match" );
}

# -- coderef map (general path) --

{
    my $n = 0;
    my $map = build_map( 'x' => sub { ++$n } );
    my @results = replace_multi( [ "xax", "x" ], $map );
    is( $results[0], "1a2", "replace_multi coderef: stateful counter first" );
    is( $results[1], "3",   "replace_multi coderef: stateful counter second" );
    is( $n, 3, "replace_multi coderef: counter value correct" );
}

# -- IV map entries (fast path) --

{
    my $map = build_map( 'a' => ord('A'), 'b' => ord('B') );
    my @results = replace_multi( [ "abc", "bbb" ], $map );
    is( $results[0], "ABc", "replace_multi IV: abc -> ABc" );
    is( $results[1], "BBB", "replace_multi IV: bbb -> BBB" );
}

# -- UTF-8 strings --

{
    my $map = build_map( 'e' => 'E' );
    my $s1 = "caf\x{e9}";
    my $s2 = "r\x{e9}sum\x{e9}";
    my $s3 = "hello";
    utf8::upgrade($s1);
    utf8::upgrade($s2);
    utf8::upgrade($s3);
    my @results = replace_multi( [ $s1, $s2, $s3 ], $map );
    is( $results[0], "caf\x{e9}",        "replace_multi UTF-8: café unchanged (no ASCII e)" );
    is( $results[1], "r\x{e9}sum\x{e9}", "replace_multi UTF-8: résumé unchanged (no ASCII e)" );
    is( $results[2], "hEllo",             "replace_multi UTF-8: hello -> hEllo" );
}

# -- UTF-8 with actual ASCII replacement targets --

{
    my $map = build_map( 'a' => 'A' );
    my @strings = ( "na\x{ef}ve", "fa\x{e7}ade" );
    utf8::upgrade($_) for @strings;
    my @results = replace_multi( \@strings, $map );
    is( $results[0], "nA\x{ef}ve", "replace_multi UTF-8: naïve -> nAïve" );
    is( $results[1], "fA\x{e7}Ade", "replace_multi UTF-8: façade -> fAçAde" );
}

# -- mixed UTF-8/non-UTF-8 strings with high-byte map entry --
# Regression: replace_multi must produce the same output as replace()
# when the batch contains UTF-8 strings and the map has a non-UTF-8
# entry with a high byte (>= 0x80).  Previously, the batch fast path
# used is_utf8=0 for _build_fast_map, inserting a raw high byte into
# UTF-8 output and producing malformed UTF-8.

{
    my @map;
    $map[ord('a')] = chr(0xE9);  # Latin-1 é (non-UTF-8 byte)

    my $plain = "abc";
    my $utf8  = "abc";
    utf8::upgrade($utf8);

    # Single replace handles this correctly via _normalize_encoding
    my $expect_plain = replace($plain, \@map);
    my $expect_utf8  = replace($utf8, \@map);

    my @results = replace_multi([$plain, $utf8], \@map);
    is( $results[0], $expect_plain,
        "replace_multi high-byte map: non-UTF-8 string matches replace()" );
    is( $results[1], $expect_utf8,
        "replace_multi high-byte map: UTF-8 string matches replace()" );
    ok( utf8::is_utf8($results[1]),
        "replace_multi high-byte map: UTF-8 flag preserved" );
}

# -- consistency with replace() --

{
    my $map = build_map( 'a' => 'X', 'z' => 'Z' );
    my @strings = ( "abcxyz", "", "zzz", "hello" );
    my @multi  = replace_multi( \@strings, $map );
    my @single = map { replace( $_, $map ) } @strings;

    for my $i ( 0 .. $#strings ) {
        is( $multi[$i], $single[$i],
            "replace_multi consistency[$i]: matches replace()" );
    }
}

# -- consistency with compiled map --

{
    my $base_map = build_map( 'a' => 'A', 'e' => 'E', 'i' => 'I' );
    my $compiled = compile_map( $base_map );
    my @strings = ( "aeiou", "testing", "apple" );

    my @multi_array    = replace_multi( \@strings, $base_map );
    my @multi_compiled = replace_multi( \@strings, $compiled );

    for my $i ( 0 .. $#strings ) {
        is( $multi_array[$i], $multi_compiled[$i],
            "replace_multi array vs compiled[$i]: same result" );
    }
}

# -- no valid map: strings returned as-is --

{
    my @results = replace_multi( [ "abc", "xyz" ], undef );
    is( $results[0], "abc", "replace_multi no map: abc unchanged" );
    is( $results[1], "xyz", "replace_multi no map: xyz unchanged" );
}

# -- error: non-arrayref first argument --

{
    eval { replace_multi( "not an array", build_map( 'a' => 'b' ) ) };
    like( $@, qr/array ref/, "replace_multi: croaks on non-arrayref" );
}

# -- large batch --

{
    my $map = build_map( 'a' => 'Z' );
    my @strings = map { "aaa" . $_ } 0 .. 999;
    my @results = replace_multi( \@strings, $map );
    is( scalar @results, 1000, "replace_multi large batch: 1000 results" );
    is( $results[0], "ZZZ0", "replace_multi large batch: first correct" );
    is( $results[999], "ZZZ999", "replace_multi large batch: last correct" );
}

# -- taint propagation --

SKIP: {
    skip "Taint mode tests require -T", 2 unless ${^TAINT};

    my $tainted = substr( $ENV{PATH}, 0, 0 ) . "hello";
    my $map = build_map( 'h' => 'H' );
    my @results = replace_multi( [ $tainted ], $map );
    ok( Scalar::Util::tainted( $results[0] ), "replace_multi: taint propagated" );
}

done_testing();
