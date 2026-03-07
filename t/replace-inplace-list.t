use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Char::Replace;

# =============================================================
# replace_inplace_list — batch in-place replacement
# =============================================================

# --- Basic functionality ---

{
    my @strings = ("aaa", "bbb", "abc");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);

    is $strings[0], "XXX",  "first string modified in place";
    is $strings[1], "bbb",  "second string unchanged";
    is $strings[2], "Xbc",  "third string partially modified";
    is \@counts, [3, 0, 1], "per-element counts returned";
}

# --- Empty array ---

{
    my @strings;
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is \@counts, [], "empty array returns empty list";
}

# --- Single element ---

{
    my @strings = ("hello");
    my $map = Char::Replace::identity_map();
    $map->[ord('h')] = 'H';
    $map->[ord('l')] = 'L';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "HeLLo", "single element modified correctly";
    is $counts[0], 3,        "count is 3";
}

# --- Identity map (no changes) ---

{
    my @strings = ("abc", "def", "ghi");
    my $map = Char::Replace::identity_map();

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is \@strings, ["abc", "def", "ghi"], "identity map leaves strings unchanged";
    is \@counts, [0, 0, 0],             "all counts are 0";
}

# --- IV map entries ---

{
    my @strings = ("abc", "xyz");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = ord('A');
    $map->[ord('x')] = ord('X');

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "Abc", "IV map entry works";
    is $strings[1], "Xyz", "IV map entry works on second string";
    is \@counts, [1, 1],   "counts correct for IV entries";
}

# --- undef and ref elements produce 0 count ---

{
    my @strings = ("abc", undef, \"ref", "def");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';
    $map->[ord('d')] = 'Y';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "Xbc", "normal string modified";
    is $counts[1], 0,      "undef element returns 0";
    is $counts[2], 0,      "ref element returns 0";
    is $strings[3], "Yef", "string after undef/ref still processed";
    is $counts[3], 1,      "count correct after undef/ref";
}

# --- Empty strings ---

{
    my @strings = ("", "a", "");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "",  "empty string unchanged";
    is $strings[1], "X", "non-empty string modified";
    is $strings[2], "",  "second empty string unchanged";
    is \@counts, [0, 1, 0], "counts correct for empty strings";
}

# --- build_map convenience ---

{
    my @strings = ("hello world", "foo bar");
    my $map = Char::Replace::build_map(
        'o' => 'O',
        ' ' => '_',
    );

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "hellO_wOrld", "build_map with replace_inplace_list";
    is $strings[1], "fOO_bar",    "second string with build_map";
    is \@counts, [3, 3],          "counts match";
}

# --- Compiled map ---

{
    my @strings = ("aaa", "bbb", "abc");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';
    my $compiled = Char::Replace::compile_map($map);

    my @counts = Char::Replace::replace_inplace_list(\@strings, $compiled);
    is $strings[0], "XXX", "compiled map: first string modified";
    is $strings[1], "bbb", "compiled map: second string unchanged";
    is $strings[2], "Xbc", "compiled map: third string modified";
    is \@counts, [3, 0, 1], "compiled map: counts correct";
}

# --- Large batch ---

{
    my @strings = map { "abcdef" } 1..1000;
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'A';
    $map->[ord('c')] = 'C';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is scalar @counts, 1000,    "large batch returns 1000 counts";
    is $strings[0],    "AbCdef", "first element of large batch correct";
    is $strings[999],  "AbCdef", "last element of large batch correct";
    ok(( grep { $_ == 2 } @counts ) == 1000, "all counts are 2");
}

# --- UTF-8 safety ---

{
    my @strings = ("café", "naïve");
    utf8::upgrade($strings[0]);
    utf8::upgrade($strings[1]);
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "cXfé",  "UTF-8: ASCII bytes replaced, multi-byte preserved";
    is $strings[1], "nXïve", "UTF-8: second string correct";
    ok utf8::is_utf8($strings[0]), "UTF-8 flag preserved on first string";
    ok utf8::is_utf8($strings[1]), "UTF-8 flag preserved on second string";
}

# --- Mixed UTF-8 and non-UTF-8 ---

{
    my @strings = ("abc", "café");
    utf8::upgrade($strings[1]);
    my $map = Char::Replace::identity_map();
    $map->[ord('c')] = 'C';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "abC",  "non-UTF-8 string modified";
    is $strings[1], "Café", "UTF-8 string modified correctly";
    is \@counts, [1, 1],    "counts correct for mixed encoding";
}

# --- Equivalence with per-element replace_inplace ---

{
    my @originals = ("hello", "world", "test123", "", "aaa", undef);
    my $map = Char::Replace::build_map(
        'l' => 'L',
        't' => 'T',
        'a' => 'A',
    );

    # batch path
    my @batch = map { defined $_ ? "$_" : undef } @originals;
    my @batch_counts = Char::Replace::replace_inplace_list(\@batch, $map);

    # per-element path
    my @single_counts;
    my @single = map { defined $_ ? "$_" : undef } @originals;
    for my $i (0..$#single) {
        if (defined $single[$i] && !ref $single[$i]) {
            push @single_counts, Char::Replace::replace_inplace($single[$i], $map);
        } else {
            push @single_counts, 0;
        }
    }

    is \@batch, \@single,             "batch matches per-element results";
    is \@batch_counts, \@single_counts, "batch counts match per-element counts";
}

# --- Croak on non-arrayref ---

like(
    dies { Char::Replace::replace_inplace_list("not an array", Char::Replace::identity_map()) },
    qr/first argument must be an array reference/,
    "croaks on string argument"
);

like(
    dies { Char::Replace::replace_inplace_list({}, Char::Replace::identity_map()) },
    qr/first argument must be an array reference/,
    "croaks on hashref argument"
);

like(
    dies { Char::Replace::replace_inplace_list(undef, Char::Replace::identity_map()) },
    qr/first argument must be an array reference/,
    "croaks on undef argument"
);

# --- No map / invalid map = no changes ---

{
    my @strings = ("abc", "def");
    my @counts = Char::Replace::replace_inplace_list(\@strings, undef);
    is \@strings, ["abc", "def"], "undef map: strings unchanged";
    is \@counts, [0, 0],         "undef map: all counts 0";
}

{
    my @strings = ("abc", "def");
    my @counts = Char::Replace::replace_inplace_list(\@strings, []);
    is \@strings, ["abc", "def"], "empty arrayref map: strings unchanged";
    is \@counts, [0, 0],         "empty arrayref map: all counts 0";
}

# --- Numeric coercion ---

{
    my @strings = (42, 3.14);
    my $map = Char::Replace::identity_map();
    $map->[ord('4')] = 'X';
    $map->[ord('3')] = 'Y';

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "X2",   "integer coerced to string and modified";
    is $strings[1], "Y.1X", "float coerced to string and modified";
    is \@counts, [1, 2],    "counts correct for coerced values";
}

# --- Compiled map with undef/ref elements ---

{
    my @strings = (undef, "abc", \"ref");
    my $map = Char::Replace::identity_map();
    $map->[ord('a')] = 'X';
    my $compiled = Char::Replace::compile_map($map);

    my @counts = Char::Replace::replace_inplace_list(\@strings, $compiled);
    is $counts[0], 0,      "compiled map: undef element returns 0";
    is $strings[1], "Xbc", "compiled map: normal string modified";
    is $counts[2], 0,      "compiled map: ref element returns 0";
}

# --- All-replacement map ---

{
    my @strings = ("abc");
    my $map = Char::Replace::identity_map();
    for my $c (0..127) {
        $map->[$c] = chr(($c + 1) % 128);
    }

    my @counts = Char::Replace::replace_inplace_list(\@strings, $map);
    is $strings[0], "bcd", "all-replacement map shifts all bytes";
    is $counts[0], 3,      "count matches string length";
}

done_testing;
