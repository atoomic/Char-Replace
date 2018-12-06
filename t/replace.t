#!/usr/bin/perl -w

# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

#use Devel::Peek

{
    note "invalid cases";
    is Char::Replace::replace( undef, undef ), undef, "replace(undef, undef)";
    is Char::Replace::replace( undef, [] ), undef, "replace(undef, [])";
    is Char::Replace::replace( [], [] ), undef, "replace([]], [])";
}

{
    note "invalid map";
    is Char::Replace::replace( "abcd", undef ), "abcd", "replace( q[abcd], undef)";
    is Char::Replace::replace( "abcd", [] ), "abcd", "replace( q[abcd], [] )";
}

note "string replacement";

our @MAP;
our $STR;
$MAP[$_] = chr($_) for 0 .. 255;
$MAP[ ord('a') ] = 'X';

is Char::Replace::replace( "abcd", \@MAP ), "Xbcd", "a -> X";

$MAP[ ord('b') ] = 'Y';
is Char::Replace::replace( "abcd", \@MAP ), "XYcd", "a -> X ; b => Y";

$MAP[ ord('b') ] = 'ZZ';
is Char::Replace::replace( "abcd", \@MAP ), "XZZcd", "a -> X ; b => ZZ";

$MAP[$_] = chr($_) for 0 .. 255;
$MAP[ ord('a') ] = 'AAAA';
$MAP[ ord('c') ] = 'CCCC';

my $got = Char::Replace::replace( "abcd" x 20, \@MAP );
my $expect = "AAAAbCCCCd" x 20;
is $got, $expect, "need to grow the string" or diag ":$got:\n", ":$expect:\n";

if ( $ENV{BENCHMARK} ) {
    note "running benchmark";
    require Benchmark;

    my $latin = <<'EOS';
Lorem ipsum dolor sit amet, accumsan patrioque mel ei. Sumo temporibus ad vix, in veri urbanitas pri, rebum nusquam expetendis et eum. Et movet antiopam eum, an veri quas pertinax mea. Te pri propriae consequuntur, te solum aeque albucius ius. Ubique everti recusabo id sea, adhuc vitae quo ea.

Dolorem ocurreret et quo, et sed propriae ocurreret. Per eu magna epicuri, ei duo alienum intellegebat. Te velit partem quo, constituam dissentiet ad nam. Eam paulo regione ut, ad sed modo oblique iracundia. Mea mucius mediocrem pertinacia te. Ex quo errem repudiandae
EOS

    # transliteration
    {
        note "ransliteration like";
        my $subs = {

            transliteration => sub {
                my $str = $STR;
                $str =~ tr|abcd|ABCD|;
                return $str;
            },
            replace_xs => sub {
                return Char::Replace::replace( $STR, \@MAP );
            },
        };

        # sanity check
        $MAP[$_] = chr($_) for 0 .. 255;
        $MAP[ ord('a') ] = 'A';
        $MAP[ ord('b') ] = 'B';
        $MAP[ ord('c') ] = 'C';
        $MAP[ ord('d') ] = 'D';

        $STR = $latin;

        is $subs->{replace_xs}->(), $subs->{transliteration}->(), "replace_xs eq transliteration" or die;

        Benchmark::cmpthese( -5 => $subs );

=pod
                    Rate transliteration      replace_xs
transliteration 112349/s              --            -55%
replace_xs      247327/s            120%              --        
=cut

    }

    {

        note "two substitute 1 char => 3 char";
        my $subs = {

            substitute_x2 => sub {
                my $str = $STR;

                $str =~ s|a|AAA|og;
                $str =~ s|d|DDD|og;

                return $str;
            },
            replace_xs => sub {
                return Char::Replace::replace( $STR, \@MAP );
            },
        };

        # sanity check
        $MAP[$_] = chr($_) for 0 .. 255;
        $MAP[ ord('a') ] = 'AAA';
        $MAP[ ord('d') ] = 'DDD';

        $STR = $latin;

        is $subs->{replace_xs}->(), $subs->{substitute_x2}->(), "replace_xs eq substitute_x2" or die;

        note "short string";
        $STR = q[abcdabcd];
        Benchmark::cmpthese( -5 => $subs );

=pod
                   Rate substitute_x2    replace_xs
substitute_x2  691771/s            --          -76%
replace_xs    2841630/s          311%            --
=cut

        note "latin string";
        $STR = $latin;
        Benchmark::cmpthese( -5 => $subs );

=pod
                  Rate substitute_x2    replace_xs
substitute_x2  60107/s            --          -72%
replace_xs    217351/s          262%            --
=cut

        note "longer string: latin string x100";
        $STR = $latin x 100;
        Benchmark::cmpthese( -5 => $subs );

=pod
                Rate substitute_x2    replace_xs
substitute_x2  719/s            --          -68%
replace_xs    2224/s          209%            --
=cut

    }

}

done_testing;
