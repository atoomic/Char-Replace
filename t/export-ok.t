use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

# Verify that @EXPORT_OK lists all 8 public functions
{
    require Char::Replace;
    my @expected = sort qw(
        replace replace_inplace replace_list
        trim trim_inplace trim_list
        identity_map build_map compile_map
    );
    is(
        [ sort @Char::Replace::EXPORT_OK ],
        \@expected,
        '@EXPORT_OK contains all 9 public functions'
    );
}

# Verify selective import works
{
    package Test::Import::Selective;
    use Char::Replace qw(replace trim identity_map);

    ::can_ok(__PACKAGE__, 'replace');
    ::can_ok(__PACKAGE__, 'trim');
    ::can_ok(__PACKAGE__, 'identity_map');
}

# Verify imported functions actually work
{
    package Test::Import::Functional;
    use Char::Replace qw(replace identity_map build_map trim compile_map);

    my $map = identity_map();
    $map->[ ord('a') ] = 'X';
    Test2::Bundle::Extended::is(replace("abc", $map), "Xbc", "imported replace() works");

    my $map2 = build_map('x' => 'Y');
    Test2::Bundle::Extended::is(replace("xyz", $map2), "Yyz", "imported build_map() works");

    Test2::Bundle::Extended::is(trim("  hello  "), "hello", "imported trim() works");

    my $compiled = compile_map($map);
    Test2::Bundle::Extended::is(replace("abc", $compiled), "Xbc", "imported compile_map() works");
}

# Verify that nothing is exported by default
{
    package Test::Import::Default;
    use Char::Replace;

    Test2::Bundle::Extended::ok(!__PACKAGE__->can('replace'), 'replace not exported by default');
    Test2::Bundle::Extended::ok(!__PACKAGE__->can('trim'), 'trim not exported by default');
}

done_testing;
