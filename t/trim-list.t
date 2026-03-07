#!/usr/bin/perl -w

# Tests for trim_list() — batch string trimming

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# === Default whitespace trimming ===

{
    note "basic: default whitespace trimming";
    my @results = Char::Replace::trim_list( ["  hello  ", "\tfoo\n", "bar", "  "] );
    is scalar @results, 4, "4 results returned";
    is $results[0], "hello",  "spaces trimmed";
    is $results[1], "foo",    "tab and newline trimmed";
    is $results[2], "bar",    "no whitespace unchanged";
    is $results[3], "",       "all whitespace -> empty";
}

{
    note "equivalence: trim_list matches trim() for each element";
    my @inputs = ("  hello  ", "\t\n", "no ws", "", " x ");
    my @list_results = Char::Replace::trim_list( \@inputs );
    for my $i (0 .. $#inputs) {
        my $single = Char::Replace::trim( $inputs[$i] );
        is $list_results[$i], $single,
            "trim_list matches trim for: " . quotemeta($inputs[$i]);
    }
}

{
    note "all whitespace types";
    my @results = Char::Replace::trim_list( [" a ", "\ta\t", "\na\n", "\ra\r", "\fa\f", "\x0ba\x0b"] );
    for my $r (@results) {
        is $r, "a", "whitespace char trimmed";
    }
}

# === Custom charset trimming ===

{
    note "custom charset: single char";
    my @results = Char::Replace::trim_list( ["xxhelloxx", "xfoo", "barx", "xxx"], "x" );
    is $results[0], "hello",  "x trimmed from both ends";
    is $results[1], "foo",    "x trimmed from left";
    is $results[2], "bar",    "x trimmed from right";
    is $results[3], "",       "all x -> empty";
}

{
    note "custom charset: multiple chars";
    my @results = Char::Replace::trim_list( ["xyzhellozyx", "xfoo", "bary"], "xyz" );
    is $results[0], "hello",  "xyz trimmed from both ends";
    is $results[1], "foo",    "x trimmed from left";
    is $results[2], "bar",    "y trimmed from right";
}

{
    note "custom charset equivalence with trim()";
    my $chars = "abc";
    my @inputs = ("aahellobb", "cccfooccc", "nothing", "abc");
    my @list_results = Char::Replace::trim_list( \@inputs, $chars );
    for my $i (0 .. $#inputs) {
        my $single = Char::Replace::trim( $inputs[$i], $chars );
        is $list_results[$i], $single,
            "trim_list matches trim with charset for: " . quotemeta($inputs[$i]);
    }
}

# === Edge cases ===

{
    note "empty input array";
    my @results = Char::Replace::trim_list( [] );
    is scalar @results, 0, "empty array -> empty results";
}

{
    note "single element";
    my @results = Char::Replace::trim_list( ["  hello  "] );
    is scalar @results, 1,      "single element array";
    is $results[0], "hello",    "single element trimmed";
}

{
    note "empty strings in array";
    my @results = Char::Replace::trim_list( ["", "  hello  ", ""] );
    is $results[0], "",       "empty string preserved";
    is $results[1], "hello",  "non-empty trimmed";
    is $results[2], "",       "empty string preserved";
}

{
    note "undef elements in input array";
    my @results = Char::Replace::trim_list( ["  abc  ", undef, "  xyz  "] );
    is scalar @results, 3,     "3 results for 3 elements";
    is $results[0], "abc",     "first element trimmed";
    is $results[1], undef,     "undef element -> undef";
    is $results[2], "xyz",     "third element trimmed";
}

{
    note "ref elements in input array (treated as invalid)";
    my @results = Char::Replace::trim_list( ["  abc  ", [1,2], {a=>1}, "  xyz  "] );
    is scalar @results, 4,     "4 results";
    is $results[0], "abc",     "string trimmed";
    is $results[1], undef,     "arrayref -> undef";
    is $results[2], undef,     "hashref -> undef";
    is $results[3], "xyz",     "string trimmed";
}

{
    note "invalid first argument: croaks";
    like dies { Char::Replace::trim_list( "not_a_ref" ) },
        qr/trim_list.*array reference/,
        "string arg croaks";

    like dies { Char::Replace::trim_list( {a => 1} ) },
        qr/trim_list.*array reference/,
        "hashref arg croaks";

    like dies { Char::Replace::trim_list( undef ) },
        qr/trim_list.*array reference/,
        "undef arg croaks";
}

# === UTF-8 safety ===

{
    note "UTF-8 strings: default whitespace";
    my @results = Char::Replace::trim_list( ["  café  ", "  naïf  ", " abc "] );
    is $results[0], "café",  "UTF-8: café trimmed";
    is $results[1], "naïf",  "UTF-8: naïf trimmed";
    is $results[2], "abc",   "ASCII: abc trimmed";
}

{
    note "UTF-8 strings: custom charset (ASCII only)";
    my @results = Char::Replace::trim_list( ["xxcaféxx", "xxnaïfxx"], "x" );
    is $results[0], "café",  "UTF-8 custom trim: café";
    is $results[1], "naïf",  "UTF-8 custom trim: naïf";
}

# === Charset edge cases ===

{
    note "undef charset -> default whitespace";
    my @results = Char::Replace::trim_list( ["  hello  "], undef );
    is $results[0], "hello", "undef charset falls back to whitespace";
}

{
    note "ref charset -> default whitespace";
    my @results = Char::Replace::trim_list( ["  hello  "], [1,2,3] );
    is $results[0], "hello", "ref charset falls back to whitespace";
}

# === Large batch ===

{
    note "large batch: correctness check";
    my @inputs = map { "  " . ("a" x $_) . "  " } 1 .. 100;
    my @results = Char::Replace::trim_list( \@inputs );
    is scalar @results, 100, "100 results";

    for my $i (0 .. 99) {
        is $results[$i], "a" x ($i + 1),
            "batch element $i trimmed" or last;
    }
}

{
    note "large batch with custom charset";
    my @inputs = map { "xx" . ("a" x $_) . "xx" } 1 .. 50;
    my @results = Char::Replace::trim_list( \@inputs, "x" );
    is scalar @results, 50, "50 results";

    for my $i (0 .. 49) {
        is $results[$i], "a" x ($i + 1),
            "custom batch element $i trimmed" or last;
    }
}

# === Numeric coercion ===

{
    note "numeric string coercion";
    my @results = Char::Replace::trim_list( [123, 456] );
    is $results[0], "123",  "integer 123 no whitespace to trim";
    is $results[1], "456",  "integer 456 no whitespace to trim";
}

done_testing;
