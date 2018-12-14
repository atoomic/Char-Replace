# NAME

Char::Replace - Perl naive XS character replacement as an alternate to substitute or transliterate

# VERSION

version 0.003

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
