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

{
    note "invalid cases";
    is Char::Replace::trim_spaces(undef), undef, "trim_spaces(undef)";
    is Char::Replace::trim_spaces( [] ), undef, "trim_spaces( [] )";
    is Char::Replace::trim_spaces( {} ), undef, "trim_spaces( {} )";
}

{
    note "string without trailing/leading spaces: plain and utf8";
    is Char::Replace::trim_spaces('hello'),          'hello',          "trim_spaces( 'hello' )";
    is Char::Replace::trim_spaces('hêllô'),        'hêllô',        "trim_spaces( 'hêllô )";
    is Char::Replace::trim_spaces('hello world'),    'hello world',    "trim_spaces( 'hello world' )";
    is Char::Replace::trim_spaces('hėllõ wòrld'), 'hėllõ wòrld', "trim_spaces( 'hėllõ wòrld' )";
}

{
    note "trailing / leading spaces: plain";
    is Char::Replace::trim_spaces('   hello'),         'hello', "trim_spaces( '  hello' )";
    is Char::Replace::trim_spaces(qq[\n\t\r\f hello]), 'hello', q[\n\t\r\f hello];
    is Char::Replace::trim_spaces('hello   '),         'hello', "trim_spaces( 'hello  ' )";
    is Char::Replace::trim_spaces(qq[hello\n\t\r\f ]), 'hello', q[hello\n\t\r\f ];
}

{
    note "trailing / leading spaces: utf8";
    is Char::Replace::trim_spaces('   hėllõ wòrld'),         'hėllõ wòrld', "trim_spaces( '  hėllõ wòrld' )";
    is Char::Replace::trim_spaces(qq[\n\t\r\f hėllõ wòrld]), 'hėllõ wòrld', q[\n\t\r\f hėllõ wòrld];
    is Char::Replace::trim_spaces('hėllõ wòrld   '),         'hėllõ wòrld', "trim_spaces( 'hėllõ wòrld  ' )";
    is Char::Replace::trim_spaces(qq[hėllõ wòrld\n\t\r\f ]), 'hėllõ wòrld', q[hėllõ wòrld\n\t\r\f ];
}

done_testing;
