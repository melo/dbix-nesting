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

subtest 'code emiter' => sub {
  my $u = sub { $n->_emit_code(@_) };
  for my $t (@{ $tc->{_emit_code} }) {
    is($u->($t->{meta}{data}), $t->{expected}{body}, $t->{msg}{desc});
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

  for my $f (grep { exists $tc{$_}{body} } keys %tc) {
    $tc{$f}{body} =~ s/^\s+|\s+$//g;
    $tc{$f}{body} =~ s/\\\s*\n\s*//gs;
  }
  $tc{$_}{data} = eval $tc{$_}{body} for grep { $tc{$_}{perl} } keys %tc;

  return \%tc;
}

__DATA__

### _expand_meta_with_defaults basic tests

> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, implicit pk
>+ meta

    { fields => [qw(k n)] }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      pk     => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      id     => 1,
      nest   => {},
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
      nest   => {},
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
      nest   => {},
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
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta, explicit prefix
>+ meta

    { fields => ['k', n => { label => 'N' }], pk => 'k', prefix => 'p' }

>+ expected

    { fields => [{ name => 'k', col => 'p_k' }, { name => 'n', col => 'p_n', label => 'N' },],
      pk     => [{ name => 'k', col => 'p_k' }],
      id     => 1,
      prefix => 'p_',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta, prefix template
>+ meta

    { fields => ['k', n => { label => 'N' }], pk => 'k', prefix => 'p#' }

>+ expected

    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n', label => 'N' },],
      pk     => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      nest   => {},
    }

> end


### _expand_meta_with_defaults complex

> for _expand_meta_with_defaults
> msg two col set, 1:M relation, explicit pk, automatic prefix
>+ meta

    { fields => [qw(k n)],
      pk     => 'k',
      nest   => {
        s => {
          fields => [qw(k t)],
          pk     => 'k',
        },
      },
    }

>+ expected

    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n' }],
      pk     => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      nest   => {
        s => {
          fields => [{ name => 'k', col => 'p2_k' }, { name => 't', col => 'p2_t' }],
          pk     => [{ name => 'k', col => 'p2_k' }],
          id     => 2,
          prefix => 'p2_',
          nest   => {},
        },
      },
    }

> end


> for _expand_meta_with_defaults
> msg several col set, 1:M relations, several levels, explicit pk, automatic prefix
>+ meta

    { fields => [qw(k n)],
      pk     => 'k',
      nest   => {
        s => {
          fields => [qw(k s)],
          pk     => 'k',
        },
        t => {
          fields => [qw(tid t)],
          pk     => 'tid',
          nest   => {
            z => {
              fields => [qw(zid z)],
              nest   => { w => { fields => [qw(wid w)] } },
            },
            x => { fields => [qw(xid x)] },
            y => { fields => [qw(yid y)] },
          },
        },
      },
    }

>+ expected

    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n' }],
      pk     => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      nest   => {
        s => {
          fields => [{ name => 'k', col => 'p2_k' }, { name => 's', col => 'p2_s' }],
          pk     => [{ name => 'k', col => 'p2_k' }],
          id     => 2,
          prefix => 'p2_',
          nest   => {},
        },
        t => {
          fields => [{ name => 'tid', col => 'p3_tid' }, { name => 't', col => 'p3_t' }],
          pk     => [{ name => 'tid', col => 'p3_tid' }],
          id     => 3,
          prefix => 'p3_',
          nest   => {
            x => {
              fields => [{ name => 'xid', col => 'p4_xid' }, { name => 'x', col => 'p4_x' }],
              pk     => [{ name => 'xid', col => 'p4_xid' }, { name => 'x', col => 'p4_x' }],
              id     => 4,
              prefix => 'p4_',
              nest   => {},
            },
            y => {
              fields => [{ name => 'yid', col => 'p5_yid' }, { name => 'y', col => 'p5_y' }],
              pk     => [{ name => 'yid', col => 'p5_yid' }, { name => 'y', col => 'p5_y' }],
              id     => 5,
              prefix => 'p5_',
              nest   => {},
            },
            z => {
              fields => [{ name => 'zid', col => 'p6_zid' }, { name => 'z', col => 'p6_z' }],
              pk     => [{ name => 'zid', col => 'p6_zid' }, { name => 'z', col => 'p6_z' }],
              id     => 6,
              prefix => 'p6_',
              nest   => {
                w => {
                  fields => [{ name => 'wid', col => 'p7_wid' }, { name => 'w', col => 'p7_w' }],
                  pk     => [{ name => 'wid', col => 'p7_wid' }, { name => 'w', col => 'p7_w' }],
                  id     => 7,
                  prefix => 'p7_',
                  nest   => {},
                },
              },
            },
          },
        },
      },
    }

> end


### Emit simple code test cases

> for _emit_code
> msg simple meta, single col set
>+ meta

    { fields => [qw(k n)] }

> expected

    sub {\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1; \
        my $s1 = $seen{o1}{$r->{'k'}}{$r->{'n'}}||= {}; \
        unless (%$s1) {\
          push @res, $o1 = $s1->{o} = {\
            'k'=>$r->{'k'},\
            'n'=>$r->{'n'},\
          };\
        } \
        $o1 = $s1->{o};\
      } \
      return \@res;\
    }

> end


