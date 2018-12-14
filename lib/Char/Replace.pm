# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

package Char::Replace;

use strict;
use warnings;

# ABSTRACT: Perl naive XS character replacement as an alternate to substitute or transliterate


BEGIN {

    # VERSION: generated by DZP::OurPkgVersion

    require XSLoader;
    XSLoader::load(__PACKAGE__);
}

sub identity_map {
    my $MAP = [];
    $MAP->[ $_ ] = chr($_) for 0..255;
    return $MAP; 
}

1;

=pod

=encoding utf-8

=head1 SYNOPSIS

Char::Replace sample usage

# EXAMPLE: examples/synopsis.pl

=head1 DESCRIPTION

Char::Replace

XS helpers to perform some basic character replacement on strings.

=over

=item replace: replace (transliterate) one or more ASCII characters

=item trim: remove leading and trailing spaces of a string

=back

=head1 Available functions

=head2 $output = replace( $string, $MAP )

Return a new string '$output' using the replacement map provided by $MAP (Array Ref).
Note: returns undef when '$string' is not a valid PV, return '$string' when the MAP is invalid

view synopsys or example just after.

=head2 $map = identity_map()

This is a convenient helper to initializee an ASCII mapping.
It returns an Array Ref, where every character will map to itself by default.

You can then adjust one or several characters.

    my $map = Char::Replace::identity_map();
    $map->[ ord('a') ] = q[XYZ]; # replace 'a' by 'XYZ'

    # replaces all 'a' by 'XYZ'
    Char::Replace::replace( "abcdabcd" ) eq "XYZbcdXYZbcd" or die;

=head2 $string = trim( $string )

trim removes all trailing and leading characters of a string
Trailing and leading space characters  ' ', '\r', '\n', '\t', '\f' are removed.
A new string is returned.

The removal is performed in XS.
We only need to look at the beginning and end of the string.

The UTF-8 state of a string is preserved.

=head1 Benchmarks

=head2 char_replace

# EXAMPLE: examples/benchmark-replace.pl

=head2 trim

# EXAMPLE: examples/benchmark-trim.pl


=head1 TODO

=over

=item handle IV in the map (at this time only PV are expected)

=back

=head1 Warnings

Be aware, that this software is still in a very alpha state at this stage.
Use it as it, patches are welcome. 

=head1 LICENSE

This software is copyright (c) 2018 by cPanel, Inc.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming
language system itself.

=head1 DISCLAIMER OF WARRANTY

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

