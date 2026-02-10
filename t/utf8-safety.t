#!/usr/bin/perl -w

# Tests for UTF-8 multi-byte character safety in replace()

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

{
    note "UTF-8 passthrough: identity map preserves multi-byte chars";
    my @map = @{ Char::Replace::identity_map() };

    is Char::Replace::replace( q[héllo],  \@map ), q[héllo],
        q[identity map: héllo unchanged];
    is Char::Replace::replace( q[café],   \@map ), q[café],
        q[identity map: café unchanged];
    is Char::Replace::replace( q[naïve],  \@map ), q[naïve],
        q[identity map: naïve unchanged];
}

{
    note "UTF-8 safety: map entry at high byte doesn't corrupt multi-byte chars";

    # é in UTF-8 is 0xC3 0xA9. If we set map[0xA9] = 'X', a byte-level
    # replace would corrupt the continuation byte. UTF-8-safe code should
    # skip the entire multi-byte sequence.
    my @map = @{ Char::Replace::identity_map() };
    $map[0xA9] = 'X';    # 0xA9 is a continuation byte of é

    is Char::Replace::replace( q[héllo], \@map ), q[héllo],
        q[map at 0xA9 does not corrupt UTF-8 continuation byte of é];
}

{
    note "UTF-8 safety: map entry at lead byte doesn't corrupt multi-byte chars";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xC3] = 'Z';    # 0xC3 is the lead byte of é (U+00E9)

    is Char::Replace::replace( q[héllo], \@map ), q[héllo],
        q[map at 0xC3 does not corrupt UTF-8 lead byte of é];
}

{
    note "UTF-8 safety: ASCII replacement still works in UTF-8 strings";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('h') ] = 'H';
    $map[ ord('l') ] = 'LL';

    is Char::Replace::replace( q[héllò], \@map ), q[HéLLLLò],
        q[ASCII chars replaced, UTF-8 chars preserved];
}

{
    note "UTF-8 safety: char deletion in UTF-8 string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('l') ] = '';    # delete 'l'

    is Char::Replace::replace( q[héllo], \@map ), q[héo],
        q[delete ASCII 'l' in UTF-8 string, accented chars intact];
}

{
    note "UTF-8 safety: IV replacement in UTF-8 string";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = ord('A');    # IV

    is Char::Replace::replace( q[café], \@map ), q[cAfé],
        q[IV replacement works in UTF-8 string];
}

{
    note "UTF-8 safety: 3-byte characters (e.g. CJK)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('x') ] = 'X';

    # 日 is U+65E5, encoded as 0xE6 0x97 0xA5
    is Char::Replace::replace( "x日x", \@map ), "X日X",
        q[3-byte CJK character preserved, ASCII replaced];
}

{
    note "UTF-8 safety: 4-byte characters (emoji)";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'A';

    # 😀 is U+1F600, encoded as 0xF0 0x9F 0x98 0x80
    is Char::Replace::replace( "a😀a", \@map ), "A😀A",
        q[4-byte emoji preserved, ASCII replaced];
}

{
    note "UTF-8 safety: mixed multi-byte widths";
    my @map = @{ Char::Replace::identity_map() };
    $map[ ord('a') ] = 'X';

    # Mix 2-byte (é), 3-byte (日), 4-byte (😀)
    is Char::Replace::replace( "aé日😀a", \@map ), "Xé日😀X",
        q[mixed 2/3/4-byte UTF-8, only ASCII 'a' replaced];
}

{
    note "UTF-8 safety: empty string";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xC3] = 'Z';

    is Char::Replace::replace( "", \@map ), "",
        q[empty UTF-8 string];
}

{
    note "UTF-8 safety: all-multibyte string";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xC3] = 'X';
    $map[0xA9] = 'Y';

    is Char::Replace::replace( "ééé", \@map ), "ééé",
        q[all-multibyte string: no bytes replaced despite map entries at lead/continuation];
}

{
    note "non-UTF-8 string: high bytes ARE replaced";
    my @map = @{ Char::Replace::identity_map() };
    $map[0xA9] = 'X';

    # Build a non-UTF-8 string with a raw 0xA9 byte (latin1 ©)
    my $str = "a\xA9b";
    utf8::downgrade($str);    # ensure no UTF-8 flag

    is Char::Replace::replace( $str, \@map ), "aXb",
        q[non-UTF-8: raw 0xA9 byte IS replaced by map];
}

done_testing;
