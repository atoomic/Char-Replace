#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Char::Replace;
use Benchmark;

our ( $STR );

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

            pp_trim => sub {
                my $str = $STR;
                return pp_naive_trim($str);
            },
            xs_trim => sub {                    
                my $str = $STR;
                return Char::Replace::trim( $str );
            },
        };

        # sanity check
        $STR = " abcd ";
        is $subs->{xs_trim}->(), 'abcd', "xs_trim check" or die;
        note ":$STR:";
        is $subs->{pp_trim}->(), 'abcd', "pp_trim check" or die;

        Benchmark::cmpthese( -5 => $subs );

=pod
                    Rate      substitute transliteration      replace_xs
substitute        7245/s              --            -97%            -98%
transliteration 214237/s           2857%              --            -50%
replace_xs      431960/s           5862%            102%              --
=cut

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

my %ws_chars = ( "\r" => undef, "\n" => undef, " " => undef, "\t" => undef, "\f" => undef );
     sub pp_trim {
         my ($this) = @_;

         my $fix = ref $this eq 'SCALAR' ? $this : \$this;
         return unless defined $$fix;

         if ( $$fix =~ tr{\r\n \t\f}{} ) {
             ${$fix} =~ s/^\s+// if exists $ws_chars{ substr( $$fix, 0,  1 ) };
             ${$fix} =~ s/\s+$// if exists $ws_chars{ substr( $$fix, -1, 1 ) };
         }
         
         return ${$fix};
     } 