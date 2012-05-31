#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use DBIx::Nesting;

my $n  = 'DBIx::Nesting';
my $tc = _read_all_test_cases();

subtest 'meta utils' => sub {
  my $u = sub { $n->_expand_meta_with_defaults(@_) };    ## shortcut
  for my $t (@{ $tc->{_expand_meta_with_defaults} }) {
    cmp_deeply($u->($t->{meta}{data}), $t->{expected}{data}, $t->{msg}{desc});
  }
};


done_testing();


##################
# Test case loader

sub _read_all_test_cases {
  my %test_cases;

  while (my $tc = _read_next_test_case()) {
    push @{ $test_cases{ $tc->{for}{desc} } }, $tc;
  }

  return \%test_cases;
}

sub _read_next_test_case {
  my %tc;

  my ($cf, $e);
  while (<DATA>) {
    last if /^>+\s+end\s*$/;
    $cf = $2, $tc{$cf}{perl} = $1, $tc{$cf}{desc} = $3, next if /^>+(\+)?\s+(\w+)(?:\s+(.+))?\s*$/;
    $tc{$cf}{body} .= $_, next if $cf;
    next if /^\s+$/ && !$cf;
    next if /^#/    && !$cf;

    die "Unparsed line $_";
  }

  return unless %tc;

  $tc{$_}{body} =~ s/^\s+|\s+$//g for grep { exists $tc{$_}{body} } keys %tc;
  $tc{$_}{data} = eval $tc{$_}{body} for grep { $tc{$_}{perl} } keys %tc;

  return \%tc;
}

__DATA__

### Meta utils tests

> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, implicit pk
>+ meta

    { fields => [qw(k n)] }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      pk     => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      id     => 1,
    },

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, implicit pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }] }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      pk     => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      id     => 1,
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }], pk => 'k' }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      pk     => [{ name => 'k', col => 'k' }],
      id     => 1,
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit multi-col pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }, 's'], pk => [qw(k s)] }

>+ expected

    { fields => [
        { name => 'k', col => 'k' },
        { name => 'n', col => 'n', label => 'N' },
        { name => 's', col => 's' },
      ],
      pk => [{ name => 'k', col => 'k' }, { name => 's', col => 's' }],
      id => 1,
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }], pk => 'k', prefix => 'p1' }

>+ expected

    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n', label => 'N' },],
      pk     => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
    }

> end


