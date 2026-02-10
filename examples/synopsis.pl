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
  
 Note: the value stored $MAP[ ord('X') ] can be a single char (string length=1), a string,
 an integer (IV — treated as character ordinal), or an empty string (deletes the character).

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

{ # build_map: convenient map construction from key-value pairs
    my $map = Char::Replace::build_map(
        'a' => 'AA',
        'd' => '',       # delete character
        'x' => ord('X'), # integer ordinal
    );
    is Char::Replace::replace( q[abxd], $map ), q[AAbX], "build_map convenience constructor";
}

{ # replace_inplace: fast in-place 1:1 byte replacement
    my $str = "hello world";
    my $map = Char::Replace::build_map( 'o' => '0', 'l' => '1' );
    my $count = Char::Replace::replace_inplace( $str, $map );
    is $str, "he110 w0r1d", "replace_inplace modifies in place";
    is $count, 5, "5 bytes changed";
}

done_testing;