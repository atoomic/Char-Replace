#!/usr/bin/perl -T -w

# Tests for taint propagation: replace() and trim() must propagate
# the taint flag from input to output.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;
use Scalar::Util qw(tainted);

# Taint propagation requires Perl 5.18+ due to internal taint handling differences
if ($] < 5.018) {
    plan skip_all => 'Taint propagation tests require Perl 5.18+';
}

sub taint { substr($ENV{PATH}, 0, 0) . $_[0] }
sub fresh_map { @{ Char::Replace::identity_map() } }

{
    note "replace(): taint propagation";

    my $t = taint("abcdef");
    ok tainted($t), q[input is tainted];

    # Fast path (identity map, 1:1)
    my @map = fresh_map();
    my $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: fast path (identity) preserves taint];

    # Fast path with actual replacement
    $map[ ord('a') ] = 'X';
    $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: fast path (a->X) preserves taint];

    # General path (expansion)
    $map[ ord('a') ] = 'XXX';
    $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: general path (expansion) preserves taint];

    # General path (deletion)
    $map[ ord('a') ] = '';
    $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: general path (deletion) preserves taint];

    # Early return: invalid map
    $r = Char::Replace::replace($t, undef);
    ok tainted($r), q[replace: early return (undef map) preserves taint];

    $r = Char::Replace::replace($t, []);
    ok tainted($r), q[replace: early return (empty map) preserves taint];
}

{
    note "replace(): non-tainted input stays clean";

    my @map = fresh_map();
    $map[ ord('a') ] = 'X';

    my $r = Char::Replace::replace("abcdef", \@map);
    ok !tainted($r), q[replace: non-tainted input => non-tainted output];
}

{
    note "trim(): taint propagation";

    my $t_ws = taint("  hello  ");
    ok tainted($t_ws), q[tainted with whitespace];

    my $r = Char::Replace::trim($t_ws);
    ok tainted($r), q[trim: with whitespace preserves taint];

    my $t_no_ws = taint("hello");
    $r = Char::Replace::trim($t_no_ws);
    ok tainted($r), q[trim: no whitespace (no-op) preserves taint];

    my $t_empty = taint("");
    $r = Char::Replace::trim($t_empty);
    ok tainted($r), q[trim: empty string preserves taint];

    my $t_all_ws = taint("   ");
    $r = Char::Replace::trim($t_all_ws);
    ok tainted($r), q[trim: all-whitespace preserves taint];
}

{
    note "trim(): non-tainted input stays clean";

    my $r = Char::Replace::trim("  hello  ");
    ok !tainted($r), q[trim: non-tainted input => non-tainted output];
}

{
    note "replace_inplace(): taint preserved (was already correct)";

    my @map = fresh_map();
    $map[ ord('a') ] = 'X';

    my $t = taint("abcabc");
    Char::Replace::replace_inplace($t, \@map);
    ok tainted($t), q[replace_inplace: taint preserved on modified string];
}

{
    note "trim_inplace(): taint preserved (was already correct)";

    my $t = taint("  hello  ");
    Char::Replace::trim_inplace($t);
    ok tainted($t), q[trim_inplace: taint preserved on modified string];
}

{
    note "replace(): taint with UTF-8 string";

    my @map = fresh_map();
    $map[ ord('h') ] = 'H';

    my $t = taint("héllo");
    my $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: taint preserved with UTF-8 input];
}

{
    note "trim(): taint with UTF-8 string";

    my $t = taint("  café  ");
    my $r = Char::Replace::trim($t);
    ok tainted($r), q[trim: taint preserved with UTF-8 input];
}

{
    note "replace(): taint with code ref map entry";

    my @map = fresh_map();
    $map[ ord('a') ] = sub { uc $_[0] };

    my $t = taint("abcd");
    my $r = Char::Replace::replace($t, \@map);
    ok tainted($r), q[replace: taint preserved with code ref entry];
}

{
    note "replace(): callback receives tainted argument";

    my @map = fresh_map();
    my $arg_was_tainted;
    $map[ ord('a') ] = sub { 
        $arg_was_tainted = tainted($_[0]);
        return uc $_[0];
    };

    my $t = taint("abcd");
    my $r = Char::Replace::replace($t, \@map);
    ok $arg_was_tainted, q[callback argument inherits taint from source];
    ok tainted($r), q[result is also tainted];
}

{
    note "replace(): callback with untainted input receives untainted argument";

    my @map = fresh_map();
    my $arg_was_tainted;
    $map[ ord('a') ] = sub {
        $arg_was_tainted = tainted($_[0]);
        return uc $_[0];
    };

    my $r = Char::Replace::replace("abcd", \@map);
    ok !$arg_was_tainted, q[callback argument is clean for clean input];
    ok !tainted($r), q[result is also clean];
}

# ---------------------------------------------------------------------------
# Compiled maps: taint propagation
# ---------------------------------------------------------------------------
{
    note "replace() with compiled map: taint propagation";

    my $map = Char::Replace::build_map( 'a' => 'X', 'b' => 'Y' );
    my $compiled = Char::Replace::compile_map($map);

    my $t = taint("abcabc");
    my $r = Char::Replace::replace($t, $compiled);
    ok tainted($r), q[replace: compiled map preserves taint];
    is $r, "XYcXYc", q[replace: compiled map produces correct output];
}

{
    note "replace() with compiled map: non-tainted stays clean";

    my $map = Char::Replace::build_map( 'a' => 'X' );
    my $compiled = Char::Replace::compile_map($map);

    my $r = Char::Replace::replace("abc", $compiled);
    ok !tainted($r), q[replace: compiled map, non-tainted => clean];
}

{
    note "replace_inplace() with compiled map: taint preserved";

    my $map = Char::Replace::build_map( 'a' => 'X' );
    my $compiled = Char::Replace::compile_map($map);

    my $t = taint("abcabc");
    Char::Replace::replace_inplace($t, $compiled);
    ok tainted($t), q[replace_inplace: compiled map preserves taint];
    is $t, "XbcXbc", q[replace_inplace: compiled map correct result];
}

{
    note "replace() with compiled map + UTF-8: taint propagation";

    my $map = Char::Replace::build_map( 'c' => 'C' );
    my $compiled = Char::Replace::compile_map($map);

    my $t = taint("café");
    my $r = Char::Replace::replace($t, $compiled);
    ok tainted($r), q[replace: compiled map + UTF-8 preserves taint];
}

# ---------------------------------------------------------------------------
# replace_list: taint propagation
# ---------------------------------------------------------------------------
{
    note "replace_list(): taint propagation (fast path)";

    my $map = Char::Replace::build_map( 'a' => 'X' );

    my @inputs = ( taint("abc"), taint("aaa"), taint("xyz") );
    ok tainted($inputs[0]), q[input 0 is tainted];

    my @results = Char::Replace::replace_list( \@inputs, $map );
    ok tainted($results[0]), q[replace_list: fast path taint preserved (elem 0)];
    ok tainted($results[1]), q[replace_list: fast path taint preserved (elem 1)];
    ok tainted($results[2]), q[replace_list: fast path taint preserved (elem 2)];
    is $results[0], "Xbc", q[replace_list: correct replacement];
}

{
    note "replace_list(): taint propagation (general path — expansion)";

    my $map = Char::Replace::build_map( 'a' => 'XYZ' );

    my @inputs = ( taint("abc") );
    my @results = Char::Replace::replace_list( \@inputs, $map );
    ok tainted($results[0]),
        q[replace_list: general path (expansion) taint preserved];
}

{
    note "replace_list(): taint propagation (general path — coderef)";

    my @map = fresh_map();
    $map[ ord('a') ] = sub { uc $_[0] };

    my @inputs = ( taint("abc") );
    my @results = Char::Replace::replace_list( \@inputs, \@map );
    ok tainted($results[0]),
        q[replace_list: general path (coderef) taint preserved];
}

{
    note "replace_list(): non-tainted stays clean";

    my $map = Char::Replace::build_map( 'a' => 'X' );
    my @results = Char::Replace::replace_list( ["abc", "xyz"], $map );
    ok !tainted($results[0]), q[replace_list: non-tainted => clean (elem 0)];
    ok !tainted($results[1]), q[replace_list: non-tainted => clean (elem 1)];
}

{
    note "replace_list(): mixed tainted and non-tainted";

    my $map = Char::Replace::build_map( 'a' => 'X' );
    my @inputs = ( taint("abc"), "abc" );
    my @results = Char::Replace::replace_list( \@inputs, $map );
    ok  tainted($results[0]), q[replace_list: tainted element stays tainted];
    ok !tainted($results[1]), q[replace_list: clean element stays clean];
}

# ---------------------------------------------------------------------------
# Custom trim characters: taint propagation
# ---------------------------------------------------------------------------
{
    note "trim() with custom chars: taint propagation";

    my $t = taint("xxhelloxx");
    my $r = Char::Replace::trim($t, "x");
    ok tainted($r), q[trim: custom chars preserves taint];
    is $r, "hello", q[trim: custom chars correct result];
}

{
    note "trim() with custom chars: empty result preserves taint";

    my $t = taint("xxx");
    my $r = Char::Replace::trim($t, "x");
    ok tainted($r), q[trim: custom chars all-trimmed preserves taint];
    is $r, "", q[trim: custom chars all-trimmed is empty];
}

{
    note "trim() with custom chars: no-op preserves taint";

    my $t = taint("hello");
    my $r = Char::Replace::trim($t, "x");
    ok tainted($r), q[trim: custom chars no-op preserves taint];
    is $r, "hello", q[trim: custom chars no-op unchanged];
}

{
    note "trim_inplace() with custom chars: taint preserved";

    my $t = taint("..hello..");
    Char::Replace::trim_inplace($t, ".");
    ok tainted($t), q[trim_inplace: custom chars preserves taint];
    is $t, "hello", q[trim_inplace: custom chars correct result];
}

{
    note "trim() with multi-char trim set: taint propagation";

    my $t = taint("xyzhellozyx");
    my $r = Char::Replace::trim($t, "xyz");
    ok tainted($r), q[trim: multi-char trim set preserves taint];
    is $r, "hello", q[trim: multi-char trim set correct result];
}

done_testing;
