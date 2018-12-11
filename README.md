# NAME

Char::Replace - Perl naive XS character replacement as an alternate to substitute or transliterate

# VERSION

version 0.001

# SYNOPSIS

Char::Replace sample usage

```perl
#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Char::Replace;

our ( $STR, @MAP );

=pod

 initialize a map:

    the map should be read as replace the characters X
    by the string stored at $MAP[ ord('X') ]
  
 Note: the value stored $MAP[ ord('X') ] can be a single char (string length=1) or a string
 at this time any other value is not handled: IVs, NVs, ...

=cut

BEGIN {    # not necessery but if you know your map, consider initializing it at compile time

    $MAP[$_] = chr($_) for 0 .. 255;

    # or you can also initialize the identity MAP like this
    @MAP = @{ Char::Replace::identity_map() };

=pod

Set your replacement characters

=cut

    $MAP[ ord('a') ] = 'AA';    # replace all 'a' characters by 'AA'
    $MAP[ ord('d') ] = '5';     # replace all 'd' characters by '5'
}

# we can now use our map to replace the string

is Char::Replace::replace( q[abcd], \@MAP ), q[AAbc5], "a -> AA ; d -> 5";

{
    note "benchmark";
    use Benchmark;

    # just a sample latin text
    my $latin = <<'EOS';
Lorem ipsum dolor sit amet, accumsan patrioque mel ei. 
Sumo temporibus ad vix, in veri urbanitas pri, rebum 
nusquam expetendis et eum. Et movet antiopam eum, 
an veri quas pertinax mea. Te pri propriae consequuntur, 
te solum aeque albucius ius. 
Ubique everti recusabo id sea, adhuc vitae quo ea.
EOS

    {
        note "transliterate like";
        my $subs = {

            transliteration => sub {
                my $str = $STR;
                $str =~ tr|abcd|ABCD|;
                return $str;
            },
            replace_xs => sub {
                return Char::Replace::replace( $STR, \@MAP );
            },
            substitute => sub {
                my $str = $STR;
                $str =~ s/(.)/$MAP[ord($1)]/og;
                return $str;
            },
        };

        # set our replacement map
        @MAP             = @{ Char::Replace::identity_map() };
        $MAP[ ord('a') ] = 'A';
        $MAP[ ord('b') ] = 'B';
        $MAP[ ord('c') ] = 'C';
        $MAP[ ord('d') ] = 'D';

        # sanity check
        $STR = $latin;
        is $subs->{replace_xs}->(), $subs->{transliteration}->(), "replace_xs eq transliteration" or die;
        is $subs->{substitute}->(), $subs->{transliteration}->(), "substitute eq transliteration" or die;

        Benchmark::cmpthese( -5 => $subs );

=pod
                    Rate      substitute transliteration      replace_xs
substitute        7245/s              --            -97%            -98%
transliteration 214237/s           2857%              --            -50%
replace_xs      431960/s           5862%            102%              --
=cut

    }

    {

        note "two substitutes 1 char => 3 char: a -> AAA; d -> DDD";
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
            substitute => sub {
                my $str = $STR;
                $str =~ s/(.)/$MAP[ord($1)]/og;
                return $str;
            },            
        };

        # sanity check
        @MAP             = @{ Char::Replace::identity_map() };
        $MAP[ ord('a') ] = 'AAA';
        $MAP[ ord('d') ] = 'DDD';

        $STR = $latin;

        is $subs->{replace_xs}->(), $subs->{substitute_x2}->(), "replace_xs eq substitute_x2" or die;
        is $subs->{substitute}->(), $subs->{substitute}->(), "replace_xs eq substitute_x2" or die;

        note "short string";
        $STR = q[abcdabcd];
        Benchmark::cmpthese( -5 => $subs );

=pod
                   Rate    substitute substitute_x2    replace_xs
substitute     207162/s            --          -70%          -93%
substitute_x2  685956/s          231%            --          -75%
replace_xs    2796596/s         1250%          308%            --
=cut

        note "latin string";
        $STR = $latin;
        Benchmark::cmpthese( -5 => $subs );

=pod
                  Rate    substitute substitute_x2    replace_xs
substitute      7229/s            --          -93%          -98%
substitute_x2 109237/s         1411%            --          -72%
replace_xs    395958/s         5377%          262%            --
=cut

        note "longer string: latin string x100";
        $STR = $latin x 100;
        Benchmark::cmpthese( -5 => $subs );

=pod
                Rate    substitute substitute_x2    replace_xs
substitute    74.0/s            --          -95%          -99%
substitute_x2 1518/s         1951%            --          -70%
replace_xs    5022/s         6685%          231%            --
=cut

    }

}

done_testing;
```

# DESCRIPTION

Char::Replace

XS helper to replace (transliterate) one or more ASCII characters

This right now pretty similar to a double split like this one

# Limitations

Be aware, that this software is in a very alpha state at this stage.
Use it as it, patches are welcome.

- do not handle UTF-8 characters (only ASCII at this stage)

# Available functions

## $output = replace( $string, $MAP )

Return a new string '$output' using the replacement map provided by $MAP (Array Ref).
Note: returns undef when '$string' is not a valid PV, return '$string' when the MAP is invalid

view synopsys or example just after.

## $map = identity\_map()

This is a convenient helper to initializee an ASCII mapping.
It returns an Array Ref, where every character will map to itself by default.

You can then adjust one or several characters.

```perl
my $map = Char::Replace::identity_map();
$map->[ ord('a') ] = q[XYZ]; # replace 'a' by 'XYZ'

# replaces all 'a' by 'XYZ'
Char::Replace::replace( "abcdabcd" ) eq "XYZbcdXYZbcd" or die;
```

# TODO

- support UTF-8 characters...
- handle IV in the map (at this time only PV are expected)

# LICENSE

This software is copyright (c) 2018 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming
language system itself.

# DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY
APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE
OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY
WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS
BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

# AUTHOR

Nicolas R <atoomic@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
