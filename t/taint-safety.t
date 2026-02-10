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

done_testing;
