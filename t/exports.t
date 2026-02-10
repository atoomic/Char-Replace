#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;

# Test 1: default — nothing exported
{
    package T::NoImport;
    use Char::Replace;

    ::ok( !defined(&replace), 'replace() not exported by default' );
    ::ok( !defined(&trim),    'trim() not exported by default' );
}

# Test 2: individual imports
{
    package T::Individual;
    use Char::Replace qw(replace trim identity_map);

    ::ok( defined(&replace),      'replace() imported individually' );
    ::ok( defined(&trim),         'trim() imported individually' );
    ::ok( defined(&identity_map), 'identity_map() imported individually' );
    ::ok( !defined(&compile_map), 'compile_map() not imported when not requested' );

    my $map = identity_map();
    $map->[ ord('a') ] = 'A';
    ::is( replace( 'abc', $map ), 'Abc', 'imported replace() works' );
    ::is( trim( '  hi  ' ),      'hi',  'imported trim() works' );
}

# Test 3: :all tag
{
    package T::All;
    use Char::Replace ':all';

    ::ok( defined(&replace),          'replace exported via :all' );
    ::ok( defined(&replace_multi),     'replace_multi exported via :all' );
    ::ok( defined(&replace_inplace),   'replace_inplace exported via :all' );
    ::ok( defined(&trim),             'trim exported via :all' );
    ::ok( defined(&trim_inplace),     'trim_inplace exported via :all' );
    ::ok( defined(&identity_map),     'identity_map exported via :all' );
    ::ok( defined(&build_map),        'build_map exported via :all' );
    ::ok( defined(&compile_map),      'compile_map exported via :all' );

    my $map = build_map( 'x' => 'Y' );
    ::is( replace( 'fox', $map ), 'foY', 'imported build_map + replace work together' );

    my $compiled = compile_map($map);
    ::is( replace( 'fox', $compiled ), 'foY', 'imported compile_map works' );

    my $str = '  hello  ';
    my $n = trim_inplace($str);
    ::is( $str, 'hello', 'imported trim_inplace works' );
    ::is( $n, 4, 'trim_inplace returns correct count' );

    $str = 'abcabc';
    $map = build_map( 'a' => 'A' );
    $n = replace_inplace( $str, $map );
    ::is( $str, 'AbcAbc', 'imported replace_inplace works' );
    ::is( $n, 2, 'replace_inplace returns correct count' );
}

done_testing;
