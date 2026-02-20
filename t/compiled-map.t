use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# === compile_map basic functionality ===

subtest 'compile_map returns a CompiledMap object' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'b';

    my $compiled = Char::Replace::compile_map($map);
    ok( defined $compiled, "compile_map returns defined value" );
    ok( ref $compiled, "compile_map returns a reference" );
    is( ref $compiled, 'Char::Replace::CompiledMap',
        "compile_map returns blessed CompiledMap" );
};

subtest 'compile_map with identity map' => sub {
    my $map = Char::Replace::identity_map();
    my $compiled = Char::Replace::compile_map($map);
    ok( defined $compiled, "identity map compiles" );
};

subtest 'compile_map with build_map' => sub {
    my $map = Char::Replace::build_map( 'a' => 'b', 'c' => 'd' );
    my $compiled = Char::Replace::compile_map($map);
    ok( defined $compiled, "build_map result compiles" );
};

# === compile_map error cases ===

subtest 'compile_map croaks on invalid input' => sub {
    like( dies { Char::Replace::compile_map("not a ref") },
          qr/argument must be an array reference/,
          "croaks on string" );
    like( dies { Char::Replace::compile_map({}) },
          qr/argument must be an array reference/,
          "croaks on hashref" );
    like( dies { Char::Replace::compile_map(undef) },
          qr/argument must be an array reference/,
          "croaks on undef" );
};

subtest 'compile_map croaks on empty map' => sub {
    like( dies { Char::Replace::compile_map([]) },
          qr/empty map/,
          "croaks on empty arrayref" );
};

subtest 'compile_map croaks on coderef entries' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = sub { 'x' };
    like( dies { Char::Replace::compile_map($map) },
          qr/not eligible for compilation/,
          "croaks on coderef in map" );
};

subtest 'compile_map croaks on multi-char string entries' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'XYZ';
    like( dies { Char::Replace::compile_map($map) },
          qr/not eligible for compilation/,
          "croaks on multi-char string in map" );
};

subtest 'compile_map croaks on deletion (empty string) entries' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = '';
    like( dies { Char::Replace::compile_map($map) },
          qr/not eligible for compilation/,
          "croaks on empty string (deletion) in map" );
};

# === replace() with compiled map ===

subtest 'replace with compiled map — basic' => sub {
    my $map = Char::Replace::build_map( 'a' => 'b', 'c' => 'd' );
    my $compiled = Char::Replace::compile_map($map);

    is( Char::Replace::replace( "abc", $compiled ), "bbd",
        "compiled map replacement works" );
    is( Char::Replace::replace( "hello", $compiled ), "hello",
        "unmapped chars pass through" );
    is( Char::Replace::replace( "", $compiled ), "",
        "empty string returns empty" );
};

subtest 'replace with compiled map matches regular map' => sub {
    my $map = Char::Replace::build_map(
        'a' => 'A', 'e' => 'E', 'i' => 'I', 'o' => 'O', 'u' => 'U',
    );
    my $compiled = Char::Replace::compile_map($map);
    my $input = "the quick brown fox jumps over the lazy dog";

    is( Char::Replace::replace( $input, $compiled ),
        Char::Replace::replace( $input, $map ),
        "compiled and regular map produce identical output" );
};

subtest 'replace with compiled map — IV entries' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = ord('A');
    $map->[ord('b')] = ord('B');
    my $compiled = Char::Replace::compile_map($map);

    is( Char::Replace::replace( "abc", $compiled ), "ABc",
        "IV entries in compiled map work" );
};

subtest 'replace with compiled map — mixed PV and IV' => sub {
    my $map = Char::Replace::identity_map();
    $map->[ord('x')] = 'Y';
    $map->[ord('y')] = ord('Z');
    my $compiled = Char::Replace::compile_map($map);

    is( Char::Replace::replace( "xyz", $compiled ), "YZz",
        "mixed PV/IV compiled map works" );
};

# === replace_inplace() with compiled map ===

subtest 'replace_inplace with compiled map — basic' => sub {
    my $map = Char::Replace::build_map( 'a' => 'b', 'c' => 'd' );
    my $compiled = Char::Replace::compile_map($map);

    my $str = "abcabc";
    my $n = Char::Replace::replace_inplace( $str, $compiled );
    is( $str, "bbdbbd", "in-place compiled replacement works" );
    is( $n, 4, "correct count of changed bytes" );
};

subtest 'replace_inplace with compiled map — no changes' => sub {
    my $map = Char::Replace::build_map( 'z' => 'Z' );
    my $compiled = Char::Replace::compile_map($map);

    my $str = "hello";
    my $n = Char::Replace::replace_inplace( $str, $compiled );
    is( $str, "hello", "string unchanged when no map hits" );
    is( $n, 0, "count is zero" );
};

subtest 'replace_inplace with compiled map matches regular map' => sub {
    my $map = Char::Replace::build_map( 'a' => 'A', 'e' => 'E' );
    my $compiled = Char::Replace::compile_map($map);

    my $str1 = "abcdef";
    my $str2 = "abcdef";
    Char::Replace::replace_inplace( $str1, $compiled );
    Char::Replace::replace_inplace( $str2, $map );
    is( $str1, $str2, "compiled and regular in-place produce identical output" );
};

# === UTF-8 safety with compiled maps ===

subtest 'replace with compiled map — UTF-8 string' => sub {
    my $map = Char::Replace::build_map( 'a' => 'A' );
    my $compiled = Char::Replace::compile_map($map);

    my $input = "caf\x{e9} au lait";
    utf8::encode($input) unless utf8::is_utf8($input);
    utf8::decode($input);

    my $result = Char::Replace::replace( $input, $compiled );
    like( $result, qr/cAf/, "ASCII chars replaced in UTF-8 string" );
};

subtest 'replace_inplace with compiled map — UTF-8 string' => sub {
    my $map = Char::Replace::build_map( 'c' => 'C' );
    my $compiled = Char::Replace::compile_map($map);

    my $str = "caf\x{e9}";
    utf8::encode($str) unless utf8::is_utf8($str);
    utf8::decode($str);

    Char::Replace::replace_inplace( $str, $compiled );
    like( $str, qr/^Caf/, "ASCII char replaced in-place in UTF-8 string" );
};

# === Reuse of compiled map ===

subtest 'compiled map can be reused across multiple calls' => sub {
    my $map = Char::Replace::build_map( 'x' => 'Y' );
    my $compiled = Char::Replace::compile_map($map);

    for my $i (1..100) {
        is( Char::Replace::replace( "x" x $i, $compiled ), "Y" x $i,
            "iteration $i" ) or last;
    }
};

subtest 'compiled map works with replace and replace_inplace interleaved' => sub {
    my $map = Char::Replace::build_map( 'a' => 'Z' );
    my $compiled = Char::Replace::compile_map($map);

    is( Char::Replace::replace( "aaa", $compiled ), "ZZZ", "replace" );

    my $str = "banana";
    Char::Replace::replace_inplace( $str, $compiled );
    is( $str, "bZnZnZ", "replace_inplace after replace" );

    is( Char::Replace::replace( "java", $compiled ), "jZvZ",
        "replace again after replace_inplace" );
};

# === Edge cases ===

subtest 'compiled map — all 256 entries identity' => sub {
    my $map = Char::Replace::identity_map();
    my $compiled = Char::Replace::compile_map($map);

    my $input = join('', map { chr($_) } 0..127);
    is( Char::Replace::replace( $input, $compiled ), $input,
        "pure identity compiled map returns identical string" );
};

subtest 'compiled map — long string performance smoke test' => sub {
    my $map = Char::Replace::build_map( 'a' => 'b' );
    my $compiled = Char::Replace::compile_map($map);

    my $long = "a" x 100_000;
    my $result = Char::Replace::replace( $long, $compiled );
    is( length($result), 100_000, "output length matches" );
    is( substr($result, 0, 10), "b" x 10, "first 10 chars correct" );
    is( substr($result, -10), "b" x 10, "last 10 chars correct" );
};

subtest 'compiled map — single char string' => sub {
    my $map = Char::Replace::build_map( 'x' => 'y' );
    my $compiled = Char::Replace::compile_map($map);

    is( Char::Replace::replace( "x", $compiled ), "y", "single char replaced" );
    is( Char::Replace::replace( "z", $compiled ), "z", "single char identity" );
};

done_testing;
