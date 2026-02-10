#!perl

use strict;
use warnings;

use Char::Replace;
use Benchmark;

# Compare replace() with 1:1 maps (fast path) vs tr// and replace_inplace()

my $latin = <<'EOS';
Lorem ipsum dolor sit amet, accumsan patrioque mel ei.
Sumo temporibus ad vix, in veri urbanitas pri, rebum
nusquam expetendis et eum. Et movet antiopam eum,
an veri quas pertinax mea. Te pri propriae consequuntur,
te solum aeque albucius ius.
Ubique everti recusabo id sea, adhuc vitae quo ea.
EOS

my @map = @{ Char::Replace::identity_map() };
$map[ ord('a') ] = 'A';
$map[ ord('b') ] = 'B';
$map[ ord('c') ] = 'C';
$map[ ord('d') ] = 'D';

# Sanity check
my $str = $latin;
my $tr_result = do { my $s = $str; $s =~ tr/abcd/ABCD/; $s };
my $xs_result = Char::Replace::replace( $str, \@map );
die "mismatch!" unless $tr_result eq $xs_result;

print "=== 1:1 map (fast path eligible): a->A, b->B, c->C, d->D ===\n\n";

for my $label ( "short (8 chars)", "medium (~300 chars)", "long (~30K chars)" ) {
    my $input = $label =~ /short/  ? "abcdabcd"
              : $label =~ /medium/ ? $latin
              :                      $latin x 100;

    print "--- $label ---\n";

    Benchmark::cmpthese( -3 => {
        'tr///' => sub {
            my $s = $input;
            $s =~ tr/abcd/ABCD/;
            return $s;
        },
        'replace()' => sub {
            return Char::Replace::replace( $input, \@map );
        },
        'replace_inplace()' => sub {
            my $s = $input;
            Char::Replace::replace_inplace( $s, \@map );
            return $s;
        },
    });
    print "\n";
}

# Now test with expansion map (forces general path)
print "=== expansion map (general path): a->AAA, d->DDD ===\n\n";
my @emap = @{ Char::Replace::identity_map() };
$emap[ ord('a') ] = 'AAA';
$emap[ ord('d') ] = 'DDD';

for my $label ( "short (8 chars)", "medium (~300 chars)" ) {
    my $input = $label =~ /short/ ? "abcdabcd" : $latin;

    print "--- $label ---\n";

    Benchmark::cmpthese( -3 => {
        's///' => sub {
            my $s = $input;
            $s =~ s/a/AAA/g;
            $s =~ s/d/DDD/g;
            return $s;
        },
        'replace()' => sub {
            return Char::Replace::replace( $input, \@emap );
        },
    });
    print "\n";
}
