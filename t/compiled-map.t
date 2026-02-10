#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Char::Replace;

subtest 'compile_map returns blessed CompiledMap' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = 'X';
    my $compiled = Char::Replace::compile_map($map);
    ok $compiled, 'compile_map returns a value';
    is ref($compiled), 'Char::Replace::CompiledMap', 'blessed into correct class';
};

subtest 'replace() with compiled map' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = 'A';
    $map->[ ord('b') ] = 'B';
    my $compiled = Char::Replace::compile_map($map);

    is Char::Replace::replace( 'abcabc', $compiled ), 'ABcABc',
        'basic 1:1 replacement';
    is Char::Replace::replace( 'xyz', $compiled ), 'xyz',
        'no matching chars';
    is Char::Replace::replace( '', $compiled ), '',
        'empty string';
};

subtest 'replace_inplace() with compiled map' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('x') ] = 'X';
    $map->[ ord('y') ] = 'Y';
    my $compiled = Char::Replace::compile_map($map);

    my $str = 'xyz';
    my $count = Char::Replace::replace_inplace( $str, $compiled );
    is $str, 'XYz', 'in-place replacement';
    is $count, 2, 'correct count';

    $str = 'abc';
    $count = Char::Replace::replace_inplace( $str, $compiled );
    is $str, 'abc', 'no changes when no match';
    is $count, 0, 'count is 0';
};

subtest 'compiled map with IV entries' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = ord('Z');
    my $compiled = Char::Replace::compile_map($map);

    is Char::Replace::replace( 'abc', $compiled ), 'Zbc',
        'IV entry compiled correctly';
};

subtest 'compiled map with identity (all unchanged)' => sub {
    my $map = Char::Replace::identity_map();
    my $compiled = Char::Replace::compile_map($map);

    is Char::Replace::replace( 'hello', $compiled ), 'hello',
        'identity map returns input unchanged';
};

subtest 'compiled map rejects non-eligible maps' => sub {
    # Code ref
    {
        my $map = Char::Replace::identity_map();
        $map->[ ord('x') ] = sub { 'X' };
        like dies { Char::Replace::compile_map($map) },
            qr/not eligible for compilation/,
            'rejects code ref entries';
    }

    # Multi-char string
    {
        my $map = Char::Replace::identity_map();
        $map->[ ord('x') ] = 'XYZ';
        like dies { Char::Replace::compile_map($map) },
            qr/not eligible for compilation/,
            'rejects multi-char string entries';
    }

    # Empty string (deletion)
    {
        my $map = Char::Replace::identity_map();
        $map->[ ord('x') ] = '';
        like dies { Char::Replace::compile_map($map) },
            qr/not eligible for compilation/,
            'rejects empty string entries (deletion)';
    }

    # Non-array ref
    {
        like dies { Char::Replace::compile_map('not a ref') },
            qr/must be a non-empty array ref/,
            'rejects non-reference';
    }

    # Empty array
    {
        like dies { Char::Replace::compile_map([]) },
            qr/must be a non-empty array ref/,
            'rejects empty array ref';
    }
};

subtest 'compiled map with UTF-8 input' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = 'A';
    my $compiled = Char::Replace::compile_map($map);

    # UTF-8 string with multi-byte chars
    my $utf8_str = "café";
    utf8::upgrade($utf8_str);
    my $result = Char::Replace::replace( $utf8_str, $compiled );
    # 'a' should be replaced, 'é' should be preserved
    my $expected = "cAfé";
    utf8::upgrade($expected);
    is $result, $expected, 'ASCII replacement works with UTF-8 input';
    ok utf8::is_utf8($result), 'UTF-8 flag preserved';
};

subtest 'compiled map with build_map' => sub {
    my $map = Char::Replace::build_map(
        'h' => 'H',
        'w' => 'W',
    );
    my $compiled = Char::Replace::compile_map($map);
    is Char::Replace::replace( 'hello world', $compiled ), 'Hello World',
        'works with build_map output';
};

subtest 'compiled map produces same results as array map' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = 'X';
    $map->[ ord('z') ] = 'Q';
    $map->[ ord(' ') ] = '_';
    $map->[ ord("\n") ] = ' ';

    my $compiled = Char::Replace::compile_map($map);

    my @test_strings = (
        '',
        'hello world',
        "line one\nline two\n",
        'aaa zzz',
        'no replacements here!',
        'a' x 1000,
        join('', map { chr($_) } 0..127),
    );

    for my $str (@test_strings) {
        my $from_array = Char::Replace::replace($str, $map);
        my $from_compiled = Char::Replace::replace($str, $compiled);
        is $from_compiled, $from_array,
            'compiled matches array for: ' . (length($str) > 40 ? substr($str, 0, 40) . '...' : $str);
    }
};

subtest 'compiled map with all ASCII replacements' => sub {
    # Build a map that swaps case for all letters
    my $map = Char::Replace::identity_map();
    for my $c ('a'..'z') {
        $map->[ ord($c) ] = uc($c);
    }
    for my $c ('A'..'Z') {
        $map->[ ord($c) ] = lc($c);
    }
    my $compiled = Char::Replace::compile_map($map);

    is Char::Replace::replace( 'Hello World', $compiled ), 'hELLO wORLD',
        'case swap with compiled map';
};

done_testing;
