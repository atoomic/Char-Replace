use strict;
use warnings;

use Test2::Bundle::Extended;

# Thread safety tests for Char::Replace XS functions.
# Validates that PERL_NO_GET_CONTEXT + pTHX_ calling convention
# works correctly under concurrent threads.
#
# Skipped when Perl is not built with ithreads.

BEGIN {
    my $can_thread = eval {
        require Config;
        $Config::Config{useithreads}
    };
    unless ($can_thread) {
        skip_all('Perl not built with ithreads');
    }
}

use threads;
use threads::shared;

use Char::Replace;

my $NUM_THREADS = 4;
my $ITERATIONS  = 200;

# ========================================================
# replace() under threads — fast path (1:1 map)
# ========================================================

subtest 'replace() fast path: concurrent threads produce correct results' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            my $map = Char::Replace::identity_map();
            $map->[ ord('a') ] = 'A';
            $map->[ ord('b') ] = 'B';
            $map->[ ord('c') ] = 'C';
            $map->[ ord('d') ] = 'D';

            for my $i (1 .. $ITERATIONS) {
                my $input  = "abcdabcd" x 10;
                my $expect = "ABCDABCDAbcdabcd" x 0;  # placeholder
                $expect = "ABCDABCD" x 10;

                my $got = Char::Replace::replace($input, $map);
                unless (defined $got && $got eq $expect) {
                    push @errors, "thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef')
                        . " expected='$expect'";
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "no errors across $NUM_THREADS threads x $ITERATIONS iterations";
};

# ========================================================
# replace() under threads — general path (expansion map)
# ========================================================

subtest 'replace() general path: concurrent expansion maps' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            my $map = Char::Replace::identity_map();
            $map->[ ord('x') ] = "XX";   # expansion → forces general path
            $map->[ ord('y') ] = '';      # deletion

            for my $i (1 .. $ITERATIONS) {
                my $input  = "axbyc";
                my $expect = "aXXc";      # x→XX, y→deleted, rest identity

                my $got = Char::Replace::replace($input, $map);
                unless (defined $got && $got eq $expect) {
                    push @errors, "thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef')
                        . " expected='$expect'";
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "expansion path: no errors across $NUM_THREADS threads";
};

# ========================================================
# replace_inplace() under threads
# ========================================================

subtest 'replace_inplace() concurrent threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            my $map = Char::Replace::identity_map();
            $map->[ ord('a') ] = 'X';
            $map->[ ord('b') ] = 'Y';

            for my $i (1 .. $ITERATIONS) {
                my $str    = "aabb" x 25;
                my $expect = "XXYY" x 25;

                my $count = Char::Replace::replace_inplace($str, $map);
                unless ($str eq $expect && $count == 100) {
                    push @errors, "thread=$tid iter=$i: str='$str' count=$count";
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "replace_inplace: no errors across $NUM_THREADS threads";
};

# ========================================================
# trim() under threads
# ========================================================

subtest 'trim() concurrent threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            for my $i (1 .. $ITERATIONS) {
                my $input  = "   hello world   ";
                my $expect = "hello world";

                my $got = Char::Replace::trim($input);
                unless (defined $got && $got eq $expect) {
                    push @errors, "thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef');
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "trim: no errors across $NUM_THREADS threads";
};

# ========================================================
# trim_inplace() under threads
# ========================================================

subtest 'trim_inplace() concurrent threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            for my $i (1 .. $ITERATIONS) {
                my $str    = "\t\n  hello  \r\n";
                my $expect = "hello";

                my $count = Char::Replace::trim_inplace($str);
                unless ($str eq $expect && $count == 7) {
                    push @errors, "thread=$tid iter=$i: str='$str' count=$count";
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "trim_inplace: no errors across $NUM_THREADS threads";
};

# ========================================================
# Mixed operations: different functions in different threads
# ========================================================

subtest 'mixed operations: replace + trim + inplace concurrently' => sub {
    my @threads;
    my @errors :shared;

    # Thread 1: replace (fast path)
    push @threads, threads->create(sub {
        my $map = Char::Replace::build_map('a' => 'Z');
        for my $i (1 .. $ITERATIONS) {
            my $got = Char::Replace::replace("banana", $map);
            unless (defined $got && $got eq "bZnZnZ") {
                push @errors, "replace: iter=$i got=" . (defined $got ? "'$got'" : 'undef');
                last;
            }
        }
    });

    # Thread 2: replace_inplace
    push @threads, threads->create(sub {
        my $map = Char::Replace::build_map('o' => '0');
        for my $i (1 .. $ITERATIONS) {
            my $str = "foobar";
            Char::Replace::replace_inplace($str, $map);
            unless ($str eq "f00bar") {
                push @errors, "replace_inplace: iter=$i got='$str'";
                last;
            }
        }
    });

    # Thread 3: trim
    push @threads, threads->create(sub {
        for my $i (1 .. $ITERATIONS) {
            my $got = Char::Replace::trim("  x  ");
            unless (defined $got && $got eq "x") {
                push @errors, "trim: iter=$i got=" . (defined $got ? "'$got'" : 'undef');
                last;
            }
        }
    });

    # Thread 4: trim_inplace
    push @threads, threads->create(sub {
        for my $i (1 .. $ITERATIONS) {
            my $str = "\thello\n";
            Char::Replace::trim_inplace($str);
            unless ($str eq "hello") {
                push @errors, "trim_inplace: iter=$i got='$str'";
                last;
            }
        }
    });

    $_->join() for @threads;
    is \@errors, [], "mixed operations: no errors across 4 threads";
};

# ========================================================
# UTF-8 strings under threads
# ========================================================

subtest 'replace() with UTF-8 strings under threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            my $map = Char::Replace::identity_map();
            $map->[ ord('h') ] = 'H';

            for my $i (1 .. $ITERATIONS) {
                my $input  = "héllo wörld";
                my $expect = "Héllo wörld";

                my $got = Char::Replace::replace($input, $map);
                unless (defined $got && $got eq $expect) {
                    push @errors, "thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef');
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "UTF-8 replace: no errors across $NUM_THREADS threads";
};

# ========================================================
# Coderef callbacks under threads
# ========================================================

subtest 'replace() with coderef under threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            my $map = Char::Replace::identity_map();
            $map->[ ord('a') ] = sub { uc $_[0] };

            for my $i (1 .. $ITERATIONS) {
                my $got = Char::Replace::replace("abcabc", $map);
                unless (defined $got && $got eq "AbcAbc") {
                    push @errors, "thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef');
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "coderef replace: no errors across $NUM_THREADS threads";
};

# ========================================================
# build_map() and identity_map() under threads
# ========================================================

subtest 'identity_map() and build_map() under threads' => sub {
    my @threads;
    my @errors :shared;

    for my $tid (1 .. $NUM_THREADS) {
        push @threads, threads->create(sub {
            for my $i (1 .. $ITERATIONS) {
                my $imap = Char::Replace::identity_map();
                unless (ref $imap eq 'ARRAY' && scalar @$imap == 256) {
                    push @errors, "identity_map: thread=$tid iter=$i: wrong shape";
                    last;
                }

                my $bmap = Char::Replace::build_map('x' => 'Y', 'z' => '');
                my $got = Char::Replace::replace("xyz", $bmap);
                unless (defined $got && $got eq "Yy") {
                    push @errors, "build_map: thread=$tid iter=$i: got="
                        . (defined $got ? "'$got'" : 'undef');
                    last;
                }
            }
        });
    }

    $_->join() for @threads;
    is \@errors, [], "map construction: no errors across $NUM_THREADS threads";
};

done_testing;
