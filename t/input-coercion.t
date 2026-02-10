#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

=pod

Test that all public functions accept non-PV inputs: integers, floats,
tied scalars, and overloaded objects — not just raw PV strings.

Previously, the XS stubs used SvPOK() which only accepts SVs with the
string flag already set.  This excluded integers (IOK), floats (NOK),
tied variables (MAGICAL), and overloaded objects (ROK + AMAGIC).

=cut

my $map = Char::Replace::identity_map();
$map->[ ord('1') ] = 'ONE';
$map->[ ord('h') ] = 'H';

# === Integer input ===

{
    note "integer input";

    is Char::Replace::replace( 12345, $map ),
       'ONE2345', "replace() stringifies integer input";

    is Char::Replace::trim( 42 ),
       '42', "trim() accepts integer (no whitespace to trim)";

    {
        my $m = Char::Replace::identity_map();
        $m->[ ord('1') ] = '9';  # 1:1 replacement only

        my $n = 12345;
        my $count = Char::Replace::replace_inplace( $n, $m );
        is $n, '92345', "replace_inplace() stringifies integer input";
        is $count, 1, "replace_inplace() returns correct count for integer";
    }
}

# === Float input ===

{
    note "float input";

    is Char::Replace::replace( 3.14, $map ),
       '3.ONE4', "replace() stringifies float input";

    is Char::Replace::trim( 2.5 ),
       '2.5', "trim() accepts float";
}

# === Tied scalar ===

{
    note "tied scalar";

    {
        package TiedStr;
        sub TIESCALAR { bless { val => $_[1] }, $_[0] }
        sub FETCH     { $_[0]->{val} }
        sub STORE     { $_[0]->{val} = $_[1] }
    }

    {
        tie my $tied, 'TiedStr', 'hello';
        is Char::Replace::replace( $tied, $map ),
           'Hello', "replace() triggers FETCH on tied scalar";
    }

    {
        tie my $tied, 'TiedStr', '  world  ';
        is Char::Replace::trim( $tied ),
           'world', "trim() triggers FETCH on tied scalar";
    }

    {
        tie my $tied, 'TiedStr', '  trimme  ';
        my $n = Char::Replace::trim_inplace( $tied );
        is $tied, 'trimme', "trim_inplace() works on tied scalar";
        is $n, 4, "trim_inplace() returns correct count for tied scalar";
    }

    {
        my $m = Char::Replace::identity_map();
        $m->[ ord('o') ] = '0';
        tie my $tied, 'TiedStr', 'hello';
        my $c = Char::Replace::replace_inplace( $tied, $m );
        is $tied, 'hell0', "replace_inplace() works on tied scalar";
        is $c, 1, "replace_inplace() returns correct count for tied scalar";
    }
}

# === Overloaded object ===

{
    note "overloaded object";

    {
        package OverStr;
        use overload '""' => sub { ${ $_[0] } }, fallback => 1;
        sub new { my $s = $_[1]; bless \$s, $_[0] }
    }

    {
        my $obj = OverStr->new('hello');
        is Char::Replace::replace( $obj, $map ),
           'Hello', "replace() invokes stringify overload";
    }

    {
        my $obj = OverStr->new('  spaced  ');
        is Char::Replace::trim( $obj ),
           'spaced', "trim() invokes stringify overload";
    }
}

# === References still rejected ===

{
    note "plain references still return undef/0";

    is Char::Replace::replace( [], $map ), undef,
       "replace() returns undef for arrayref";

    is Char::Replace::replace( {}, $map ), undef,
       "replace() returns undef for hashref";

    is Char::Replace::trim( [] ), undef,
       "trim() returns undef for arrayref";

    is Char::Replace::trim( {} ), undef,
       "trim() returns undef for hashref";

    is Char::Replace::replace_inplace( [], $map ), 0,
       "replace_inplace() returns 0 for arrayref";

    is Char::Replace::trim_inplace( [] ), 0,
       "trim_inplace() returns 0 for arrayref";
}

# === Undef still rejected ===

{
    note "undef still returns undef/0";

    is Char::Replace::replace( undef, $map ), undef,
       "replace(undef) returns undef";

    is Char::Replace::trim( undef ), undef,
       "trim(undef) returns undef";

    is Char::Replace::replace_inplace( undef, $map ), 0,
       "replace_inplace(undef) returns 0";

    is Char::Replace::trim_inplace( undef ), 0,
       "trim_inplace(undef) returns 0";
}

done_testing;
