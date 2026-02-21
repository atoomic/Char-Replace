#!perl

use strict;
use warnings;

use Char::Replace;
use Benchmark;

# Compare regular map (rebuilds fast_map every call) vs compiled map (precomputed)

my $latin = <<'EOS';
Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
Sumo temporibus ad vix, in veri urbanitas pri, rebum
nusquam expetendis et eum. Et movet antiopam eum,
an veri quas pertinax mea. Te pri propriae consequuntur,
te solum aeque albucius ius.
Ubique everti recusabo id sea, adhuc vitae quo ea.
EOS

my $map = Char::Replace::build_map(
    'a' => 'A', 'b' => 'B', 'c' => 'C', 'd' => 'D',
);
my $compiled = Char::Replace::compile_map($map);

# Sanity check
my $check1 = Char::Replace::replace( $latin, $map );
my $check2 = Char::Replace::replace( $latin, $compiled );
die "mismatch!" unless $check1 eq $check2;

print "=== replace(): regular map vs compiled map ===\n\n";

for my $label ( "short (8 chars)", "medium (~300 chars)", "long (~30K chars)" ) {
    my $input = $label =~ /short/  ? "abcdabcd"
              : $label =~ /medium/ ? $latin
              :                      $latin x 100;

    print "--- $label ---\n";

    Benchmark::cmpthese( -3 => {
        'regular map' => sub {
            return Char::Replace::replace( $input, $map );
        },
        'compiled map' => sub {
            return Char::Replace::replace( $input, $compiled );
        },
    });
    print "\n";
}

print "=== replace_inplace(): regular map vs compiled map ===\n\n";

for my $label ( "short (8 chars)", "medium (~300 chars)", "long (~30K chars)" ) {
    my $input = $label =~ /short/  ? "abcdabcd"
              : $label =~ /medium/ ? $latin
              :                      $latin x 100;

    print "--- $label ---\n";

    Benchmark::cmpthese( -3 => {
        'regular map' => sub {
            my $s = $input;
            Char::Replace::replace_inplace( $s, $map );
        },
        'compiled map' => sub {
            my $s = $input;
            Char::Replace::replace_inplace( $s, $compiled );
        },
    });
    print "\n";
}
