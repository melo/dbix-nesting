#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use Test::Fatal;
use Test::LongString;
use DBIx::Nesting;
use DBIx::Nesting::t::Utils;

my $n  = 'DBIx::Nesting';
my $tc = read_all_test_cases(\*DATA);

subtest 'meta utils' => sub {
  my $u = sub { $n->_expand_meta_with_defaults(@_) };    ## shortcut
  for my $t (@{ $tc->{_expand_meta_with_defaults} }) {
    cmp_deeply($u->($t->{meta}{data}), $t->{expected}{data}, $t->{msg}{desc});
  }
};

subtest 'code emiter' => sub {
  my $u = sub { $n->_emit_code(@_) };
  for my $t (@{ $tc->{_emit_code} }) {
    my $desc = $t->{msg}{desc};
    my $meta = $t->{meta}{data};
    is_string($u->($meta), $t->{expected}{body}, "$desc ok");

    my $cb;
    is(exception { $cb = $n->compile($meta) }, undef, "... compiles ok too");
    is(ref($cb), 'CODE', '... outputs CodeRef');
  }
};


done_testing();

###########################################
# Test data

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


> for _emit_code
> msg single col set, explicit prefix and pk
>+ meta

    { fields => [qw(k n)], prefix => 'x', pk => 'n' }

> expected

    sub {\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1; \
        my $s1 = $seen{o1}{$r->{'x_n'}}||= {}; \
        unless (%$s1) {\
          push @res, $o1 = $s1->{o} = {\
            'k'=>$r->{'x_k'},\
            'n'=>$r->{'x_n'},\
          };\
        } \
        $o1 = $s1->{o};\
      } \
      return \@res;\
  }

> end


> for _emit_code
> msg double col set, explicit pk
>+ meta

    { fields => [qw(k n)], pk => 'k', nest => { o => { fields => [qw(k o)] } } }

> expected

    sub {\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1; \
        my $s1 = $seen{o1}{$r->{'p1_k'}}||= {}; \
        unless (%$s1) {\
          push @res, $o1 = $s1->{o} = {\
            'k'=>$r->{'p1_k'},\
            'n'=>$r->{'p1_n'},\
          };\
        } \
        $o1 = $s1->{o};\
        my $o2; \
        my $s2 = $s1->{o2}{$r->{'p2_k'}}{$r->{'p2_o'}}||= {}; \
        unless (%$s2) {\
          push @{$o1->{'o'}}, $o2 = $s2->{o} = {\
            'k'=>$r->{'p2_k'},\
            'o'=>$r->{'p2_o'},\
          };\
        } \
        $o2 = $s2->{o};\
      } \
      return \@res;\
  }

> end


> for _emit_code
> msg complex multi-nested meta
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


> expected

    sub {\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1; \
        my $s1 = $seen{o1}{$r->{'p1_k'}}||= {}; \
        unless (%$s1) {\
          push @res, $o1 = $s1->{o} = {\
            'k'=>$r->{'p1_k'},\
            'n'=>$r->{'p1_n'},\
          };\
        } \
        $o1 = $s1->{o};\
        \
        my $o2; \
        my $s2 = $s1->{o2}{$r->{'p2_k'}}||= {}; \
        unless (%$s2) {\
          push @{$o1->{'s'}}, $o2 = $s2->{o} = {\
            'k'=>$r->{'p2_k'},\
            's'=>$r->{'p2_s'},\
          };\
        } \
        $o2 = $s2->{o};\
        \
        my $o3; \
        my $s3 = $s1->{o3}{$r->{'p3_tid'}}||= {}; \
        unless (%$s3) {\
          push @{$o1->{'t'}}, $o3 = $s3->{o} = {\
            'tid'=>$r->{'p3_tid'},\
            't'=>$r->{'p3_t'},\
          };\
        } \
        $o3 = $s3->{o};\
        \
        my $o4; \
        my $s4 = $s3->{o4}{$r->{'p4_xid'}}{$r->{'p4_x'}}||= {}; \
        unless (%$s4) {\
          push @{$o3->{'x'}}, $o4 = $s4->{o} = {\
            'xid'=>$r->{'p4_xid'},\
            'x'=>$r->{'p4_x'},\
          };\
        } \
        $o4 = $s4->{o};\
        \
        my $o5; \
        my $s5 = $s3->{o5}{$r->{'p5_yid'}}{$r->{'p5_y'}}||= {}; \
        unless (%$s5) {\
          push @{$o3->{'y'}}, $o5 = $s5->{o} = {\
            'yid'=>$r->{'p5_yid'},\
            'y'=>$r->{'p5_y'},\
          };\
        } \
        $o5 = $s5->{o};\
        \
        my $o6; \
        my $s6 = $s3->{o6}{$r->{'p6_zid'}}{$r->{'p6_z'}}||= {}; \
        unless (%$s6) {\
          push @{$o3->{'z'}}, $o6 = $s6->{o} = {\
            'zid'=>$r->{'p6_zid'},\
            'z'=>$r->{'p6_z'},\
          };\
        } \
        $o6 = $s6->{o};\
        \
        my $o7; \
        my $s7 = $s6->{o7}{$r->{'p7_wid'}}{$r->{'p7_w'}}||= {}; \
        unless (%$s7) {\
          push @{$o6->{'w'}}, $o7 = $s7->{o} = {\
            'wid'=>$r->{'p7_wid'},\
            'w'=>$r->{'p7_w'},\
          };\
        } \
        $o7 = $s7->{o};\
      } \
      return \@res;\
    }

> end
