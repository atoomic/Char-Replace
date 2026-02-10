#!/usr/bin/env perl

use strict;
use warnings;
use Benchmark qw(cmpthese);
use Char::Replace qw(replace replace_multi build_map compile_map);

print "Char::Replace — replace_multi() batch benchmark\n";
print "=" x 55, "\n\n";

my $map = build_map(
    'a' => 'A', 'e' => 'E', 'i' => 'I', 'o' => 'O', 'u' => 'U',
);

my $compiled = compile_map($map);

# Generate test data
my @short  = map { "hello world $_" } 1 .. 1000;
my @medium = map { "the quick brown fox jumps over the lazy dog $_" x 3 } 1 .. 1000;
my @long   = map { "abcdefghijklmnopqrstuvwxyz " x 20 . $_ } 1 .. 1000;

for my $label_data (
    [ '1000 short strings (~15 chars)'  => \@short  ],
    [ '1000 medium strings (~150 chars)' => \@medium ],
    [ '1000 long strings (~540 chars)'   => \@long   ],
) {
    my ($label, $data) = @$label_data;
    print "--- $label ---\n";

    cmpthese( -2, {
        'loop+replace' => sub {
            my @out = map { replace($_, $map) } @$data;
        },
        'loop+replace(compiled)' => sub {
            my @out = map { replace($_, $compiled) } @$data;
        },
        'replace_multi(array)' => sub {
            my @out = replace_multi($data, $map);
        },
        'replace_multi(compiled)' => sub {
            my @out = replace_multi($data, $compiled);
        },
    });
    print "\n";
}
