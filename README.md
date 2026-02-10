# NAME

Char::Replace - Perl naive XS character replacement as an alternate to substitute or transliterate

# VERSION

version 0.008

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

{ # trim XS helper
    # remove spaces at the beginning and end of a string - XS helper

    is Char::Replace::trim( qq[ Some spaces in this string.\n\r\n] ), q[Some spaces in this string.];    
}

{ # trim_inplace: modify string in place (zero allocation)
    my $str = qq[  Some spaces  \n];
    my $removed = Char::Replace::trim_inplace( $str );
    is $str, q[Some spaces], "trim_inplace modifies in place";
    is $removed, 5, "5 whitespace bytes removed";
}

done_testing;
```

# DESCRIPTION

Char::Replace

XS helpers to perform some basic character replacement on strings.

- replace: replace (transliterate) one or more ASCII characters
- replace\_inplace: fast in-place 1:1 character replacement (no allocation)
- trim: remove leading and trailing spaces of a string
- trim\_inplace: in-place whitespace trimming (no allocation)

# Available functions

## $output = replace( $string, $MAP )

Return a new string '$output' using the replacement map provided by $MAP (Array Ref).
Map entries can be:

- a string (PV) — replaces the character with that string
- an empty string — deletes the character from the output
- an integer (IV) — replaces the character with `chr(value)` (0–255)
- undef — keeps the original character unchanged
- a code ref — called with the character as argument; return value is the replacement
(return undef to keep original, empty string to delete)

    **Note:** Code ref callbacks are significantly slower than static replacements due to
    function call overhead. Avoid heavy computation inside callbacks. Callbacks receive
    a single-character string argument; for tainted input, the output string inherits the
    taint flag from the input (not from the callback return value).

view ["SYNOPSIS"](#synopsis) or example just after.

Setting a map entry to an empty string deletes the character from the output:

```
$map->[ ord('x') ] = q[];    # delete 'x'
Char::Replace::replace( "fox", $map ) eq "fo" or die;
```

Setting a map entry to an integer replaces the character with chr(value):

```
$map->[ ord('a') ] = ord('A');  # replace 'a' with 'A'
Char::Replace::replace( "abc", $map ) eq "Abc" or die;
```

Setting a map entry to a code ref enables dynamic replacement:

```perl
$map->[ ord('a') ] = sub { uc $_[0] };  # uppercase callback
Char::Replace::replace( "abc", $map ) eq "Abc" or die;

# stateful callback
my $n = 0;
$map->[ ord('x') ] = sub { ++$n };
Char::Replace::replace( "xyx", $map ) eq "1y2" or die;
```

## $map = identity\_map()

This is a convenient helper to initialize an ASCII mapping.
It returns an Array Ref, where every character will map to itself by default.

You can then adjust one or several characters.

```perl
my $map = Char::Replace::identity_map();
$map->[ ord('a') ] = q[XYZ]; # replace 'a' by 'XYZ'

# replaces all 'a' by 'XYZ'
Char::Replace::replace( "abcdabcd" ) eq "XYZbcdXYZbcd" or die;
```

## $map = build\_map( char => replacement, ... )

Convenience constructor: takes a hash of single-character keys and their
replacement values, and returns an array ref suitable for `replace()` or
`replace_inplace()`. Starts from an identity map, so unmapped characters
pass through unchanged.

```perl
my $map = Char::Replace::build_map(
    'a' => 'AA',
    'd' => '',       # delete
    'x' => ord('X'), # IV
    'z' => sub { uc $_[0] },  # callback
);
Char::Replace::replace( "abxd", $map ) eq "AAbX" or die;
```

Croaks if any key is not exactly one character.

## $count = replace\_inplace( $string, $MAP )

Modifies `$string` in place, applying 1:1 byte replacements from `$MAP`.
Returns the number of bytes actually changed.

Unlike `replace()`, this function does **not** allocate a new string — it
modifies the existing SV buffer directly. This makes it significantly faster
(up to 3.5x for long strings) but restricts map entries to single-character
replacements only:

- a single-character string (PV of length 1)
- an integer (IV) in range 0–255
- undef — keeps the original character unchanged

Multi-character strings, empty strings (deletion), and code refs will cause a croak.
Use `replace()` when you need expansion, deletion, or dynamic callbacks.

```perl
my $map = Char::Replace::identity_map();
$map->[ ord('a') ] = 'A';

my $str = "abcabc";
my $n = Char::Replace::replace_inplace( $str, $map );
# $str is now "AbcAbc", $n is 2
```

UTF-8 safety applies: multi-byte sequences are skipped, only ASCII bytes
are eligible for replacement.

## $string = trim( $string )

trim removes all trailing and leading characters of a string
Trailing and leading space characters  ' ', '\\r', '\\n', '\\t', '\\f' are removed.
A new string is returned.

The removal is performed in XS.
We only need to look at the beginning and end of the string.

The UTF-8 state of a string is preserved.

## $count = trim\_inplace( $string )

Modifies `$string` in place, removing leading and trailing whitespace.
Returns the total number of whitespace bytes removed.

Unlike `trim()`, this function does **not** allocate a new string — it
modifies the existing SV directly. Uses `sv_chop()` internally for
efficient leading-whitespace removal.

The same whitespace characters as `trim()` are recognized:
`' '`, `'\r'`, `'\n'`, `'\t'`, `'\f'`.

```perl
my $str = "  hello world  ";
my $n = Char::Replace::trim_inplace( $str );
# $str is now "hello world", $n is 4
```

The UTF-8 state of the string is preserved.

# Benchmarks

## char\_replace

```perl
#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Char::Replace;

our ( $STR, @MAP );

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

ok 1 => 'done';

done_testing;
```

## trim

```perl
#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Char::Replace;
use Benchmark;

our ($STR);

{

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

            pp_naive_trim => sub {
                my $str = $STR;
                return pp_naive_trim($str);
            },
            pp_trim => sub {
                my $str = $STR;
                return pp_trim($str);
            },
            xs_trim => sub {
                my $str = $STR;
                return Char::Replace::trim($str);
            },
        };

        # sanity check
        note "a simple string";
        $STR = " abcd ";
        my @to_test = (
            "no-spaces",
            " leading-trailing ",
            "                  multiple spaces in front",
            " \t\r\n \t\r\n \t\r\n \t\r\nmultiple chars in front and end \t\r\n \t\r\n \t\r\n \t\r\n \t\r\n",
            " a long string $latin $latin $latin $latin $latin    ",
        );

        foreach my $t (@to_test) {
            note "Testing ", $t;
            $STR = $t;

            is $subs->{xs_trim}->(),       $subs->{pp_trim}->(), "xs_trim eq pp_trim"       or die;
            is $subs->{pp_naive_trim}->(), $subs->{pp_trim}->(), "pp_naive_trim eq pp_trim" or die;
            is $STR, $t, 'str preserved';

            note "Benchmark for string '$t'";
            Benchmark::cmpthese( -5 => $subs );
        }
    }

}

ok 1, 'done';

done_testing;

sub pp_naive_trim {
    my $s = shift;
    $s =~ s{^\s+}{};
    $s =~ s{\s+$}{};

    return $s;
}

my $ws_chars;

sub pp_trim {
    my ($str) = @_;

    return unless defined $str;
    $ws_chars //= { "\r" => undef, "\n" => undef, " " => undef, "\t" => undef, "\f" => undef };

    if ( $str =~ tr{\r\n \t\f}{} ) {
        $str =~ s/^\s+// if exists $ws_chars->{ substr( $str, 0,  1 ) };
        $str =~ s/\s+$// if exists $ws_chars->{ substr( $str, -1, 1 ) };
    }

    return $str;
}


__END__

Benchmark results from above


# Benchmark for string 'no-spaces'
                   Rate pp_naive_trim       pp_trim       xs_trim
pp_naive_trim 1522387/s            --          -11%          -57%
pp_trim       1705156/s           12%            --          -52%
xs_trim       3554380/s          133%          108%            --

# Benchmark for string ' leading-trailing '
                   Rate       pp_trim pp_naive_trim       xs_trim
pp_trim        328327/s            --          -41%          -90%
pp_naive_trim  558317/s           70%            --          -83%
xs_trim       3356254/s          922%          501%            --

# Benchmark for string '                  multiple spaces in front'
                   Rate       pp_trim pp_naive_trim       xs_trim
pp_trim        469042/s            --          -25%          -86%
pp_naive_trim  626328/s           34%            --          -81%
xs_trim       3369067/s          618%          438%            --

# Benchmark for string '
#
#
#
# multiple chars in front and end
#
#
#
#
# '
                   Rate       pp_trim pp_naive_trim       xs_trim
pp_trim        273091/s            --          -35%          -89%
pp_naive_trim  417669/s           53%            --          -83%
xs_trim       2463892/s          802%          490%            --

# Benchmark for string ' a long string Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
# Sumo temporibus ad vix, in veri urbanitas pri, rebum
# nusquam expetendis et eum. Et movet antiopam eum,
# an veri quas pertinax mea. Te pri propriae consequuntur,
# te solum aeque albucius ius.
# Ubique everti recusabo id sea, adhuc vitae quo ea.
#  Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
# Sumo temporibus ad vix, in veri urbanitas pri, rebum
# nusquam expetendis et eum. Et movet antiopam eum,
# an veri quas pertinax mea. Te pri propriae consequuntur,
# te solum aeque albucius ius.
# Ubique everti recusabo id sea, adhuc vitae quo ea.
#  Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
# Sumo temporibus ad vix, in veri urbanitas pri, rebum
# nusquam expetendis et eum. Et movet antiopam eum,
# an veri quas pertinax mea. Te pri propriae consequuntur,
# te solum aeque albucius ius.
# Ubique everti recusabo id sea, adhuc vitae quo ea.
#  Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
# Sumo temporibus ad vix, in veri urbanitas pri, rebum
# nusquam expetendis et eum. Et movet antiopam eum,
# an veri quas pertinax mea. Te pri propriae consequuntur,
# te solum aeque albucius ius.
# Ubique everti recusabo id sea, adhuc vitae quo ea.
#  Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
# Sumo temporibus ad vix, in veri urbanitas pri, rebum
# nusquam expetendis et eum. Et movet antiopam eum,
# an veri quas pertinax mea. Te pri propriae consequuntur,
# te solum aeque albucius ius.
# Ubique everti recusabo id sea, adhuc vitae quo ea.
#     '
                   Rate       pp_trim pp_naive_trim       xs_trim
pp_trim         12350/s            --          -37%          -99%
pp_naive_trim   19610/s           59%            --          -99%
xs_trim       1810099/s        14556%         9130%            --
```

# Warnings

Be aware, that this software is still in a very alpha state at this stage.
Use it as it, patches are welcome. 

# Todo

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
