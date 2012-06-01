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
> msg simple meta, single col set, no fields, explicit pk
>+ meta

    {pk => 'k'}

>+ expected

    { pk     => [{name => 'k', col => 'p1_k'}],
      id     => 1,
      prefix => 'p1_',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no fields, no explicit pk
>+ meta

    {}

>+ expected

    { id     => 1,
      prefix => 'p1_',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no fields, no explicit pk
>+ meta

    {nest => {x => {}}}

>+ expected

    { id     => 1,
      prefix => 'p1_',
      nest   => {
        x => {
          id     => 2,
          prefix => 'p2_',
          nest   => {},
        },
      },
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


> for _expand_meta_with_defaults
> msg several col set, 1:M relations, several levels, no fields, some pk, automatic prefix
>+ meta

    { pk   => 'k',
      nest => {
        s => {pk => 'k'},
        t => {
          pk   => 'tid',
          nest => {
            z => {nest => {w => {}},},
            x => {},
            y => {},
          },
        },
      },
    }

>+ expected

    { pk     => [{name => 'k', col => 'p1_k'}],
      id     => 1,
      prefix => 'p1_',
      nest   => {
        s => {
          pk     => [{name => 'k', col => 'p2_k'}],
          id     => 2,
          prefix => 'p2_',
          nest   => {},
        },
        t => {
          pk     => [{name => 'tid', col => 'p3_tid'}],
          id     => 3,
          prefix => 'p3_',
          nest   => {
            x => {
              id     => 4,
              prefix => 'p4_',
              nest   => {},
            },
            y => {
              id     => 5,
              prefix => 'p5_',
              nest   => {},
            },
            z => {
              id     => 6,
              prefix => 'p6_',
              nest   => {
                w => {
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
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1;\
        my $s1 = $seen{o1}{$r->{'k'}}{$r->{'n'}}||= {};\
        unless (%$s1) {\
          $o1 = {\
            'k'=>$r->{'k'},\
            'n'=>$r->{'n'},\
          };\
          push @res, $s1->{o} = $o1;\
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
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1;\
        my $s1 = $seen{o1}{$r->{'x_n'}}||= {};\
        unless (%$s1) {\
          $o1 = {\
            'k'=>$r->{'x_k'},\
            'n'=>$r->{'x_n'},\
          };\
          push @res, $s1->{o} = $o1;\
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
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1;\
        my $s1 = $seen{o1}{$r->{'p1_k'}}||= {};\
        unless (%$s1) {\
          $o1 = {\
            'k'=>$r->{'p1_k'},\
            'n'=>$r->{'p1_n'},\
          };\
          push @res, $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        my $o2;\
        my $s2 = $s1->{o2}{$r->{'p2_k'}}{$r->{'p2_o'}}||= {};\
        unless (%$s2) {\
          $o2 = {\
            'k'=>$r->{'p2_k'},\
            'o'=>$r->{'p2_o'},\
          };\
          push @{$o1->{'o'}}, $s2->{o} = $o2;\
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
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      for my $r (@{$_[0]}) {\
        my $o1;\
        my $s1 = $seen{o1}{$r->{'p1_k'}}||= {};\
        unless (%$s1) {\
          $o1 = {\
            'k'=>$r->{'p1_k'},\
            'n'=>$r->{'p1_n'},\
          };\
          push @res, $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        \
        my $o2;\
        my $s2 = $s1->{o2}{$r->{'p2_k'}}||= {};\
        unless (%$s2) {\
          $o2 = {\
            'k'=>$r->{'p2_k'},\
            's'=>$r->{'p2_s'},\
          };\
          push @{$o1->{'s'}}, $s2->{o} = $o2;\
        } \
        $o2 = $s2->{o};\
        \
        my $o3;\
        my $s3 = $s1->{o3}{$r->{'p3_tid'}}||= {};\
        unless (%$s3) {\
          $o3 = {\
            'tid'=>$r->{'p3_tid'},\
            't'=>$r->{'p3_t'},\
          };\
          push @{$o1->{'t'}}, $s3->{o} = $o3;\
        } \
        $o3 = $s3->{o};\
        \
        my $o4;\
        my $s4 = $s3->{o4}{$r->{'p4_xid'}}{$r->{'p4_x'}}||= {};\
        unless (%$s4) {\
          $o4 = {\
            'xid'=>$r->{'p4_xid'},\
            'x'=>$r->{'p4_x'},\
          };\
          push @{$o3->{'x'}}, $s4->{o} = $o4;\
        } \
        $o4 = $s4->{o};\
        \
        my $o5;\
        my $s5 = $s3->{o5}{$r->{'p5_yid'}}{$r->{'p5_y'}}||= {};\
        unless (%$s5) {\
          $o5 = {\
            'yid'=>$r->{'p5_yid'},\
            'y'=>$r->{'p5_y'},\
          };\
          push @{$o3->{'y'}}, $s5->{o} = $o5;\
        } \
        $o5 = $s5->{o};\
        \
        my $o6;\
        my $s6 = $s3->{o6}{$r->{'p6_zid'}}{$r->{'p6_z'}}||= {};\
        unless (%$s6) {\
          $o6 = {\
            'zid'=>$r->{'p6_zid'},\
            'z'=>$r->{'p6_z'},\
          };\
          push @{$o3->{'z'}}, $s6->{o} = $o6;\
        } \
        $o6 = $s6->{o};\
        \
        my $o7;\
        my $s7 = $s6->{o7}{$r->{'p7_wid'}}{$r->{'p7_w'}}||= {};\
        unless (%$s7) {\
          $o7 = {\
            'wid'=>$r->{'p7_wid'},\
            'w'=>$r->{'p7_w'},\
          };\
          push @{$o6->{'w'}}, $s7->{o} = $o7;\
        } \
        $o7 = $s7->{o};\
      } \
      return \@res;\
    }

> end


> for _emit_code
> msg complex multi-nested meta, without fields
>+ meta

    { pk   => 'k',
      nest => {
        s => { pk => 'k' },
        t => {
          pk   => 'tid',
          nest => {
            z => { nest   => { w => {} }, },
            x => { fields => [qw(xid x)] },
            y => {},
          },
        },
      },
    }


> expected

    sub {\
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      my %prfxs;\
      for my $f (sort keys %{$_[0][0]}) {\
	      my ($p, $n) = $f =~ m/^(p1_|p2_|p3_|p4_|p5_|p6_|p7_)(.+)$/;\
	      next unless $p;\
	      push @{$prfxs{$p}}, { name => $n, col => $f};\
	    }\
      for my $r (@{$_[0]}) {\
        my $o1;\
        my $f1 = $prfxs{'p1_'};\
        my $s1 = $seen{o1}{$r->{'p1_k'}}||= {};\
        unless (%$s1) {\
	        $o1 = {};\
		      for my $f (@$f1) {\
		        $o1->{$f->{name}} = $r->{$f->{col}};\
		      }\
          push @res, $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        \
        my $o2;\
        my $f2 = $prfxs{'p2_'};\
        my $s2 = $s1->{o2}{$r->{'p2_k'}}||= {};\
        unless (%$s2) {\
          $o2 = {};\
	        for my $f (@$f2) {\
	          $o2->{$f->{name}} = $r->{$f->{col}};\
	        }\
          push @{$o1->{'s'}}, $s2->{o} = $o2;\
        } \
        $o2 = $s2->{o};\
        \
        my $o3;\
        my $f3 = $prfxs{'p3_'};\
        my $s3 = $s1->{o3}{$r->{'p3_tid'}}||= {};\
        unless (%$s3) {\
          $o3 = {};\
	        for my $f (@$f3) {\
	          $o3->{$f->{name}} = $r->{$f->{col}};\
	        }\
          push @{$o1->{'t'}}, $s3->{o} = $o3;\
        } \
        $o3 = $s3->{o};\
        \
        my $o4;\
        my $s4 = $s3->{o4}{$r->{'p4_xid'}}{$r->{'p4_x'}}||= {};\
        unless (%$s4) {\
          $o4 = {\
            'xid'=>$r->{'p4_xid'},\
            'x'=>$r->{'p4_x'},\
          };\
          push @{$o3->{'x'}}, $s4->{o} = $o4;\
        } \
        $o4 = $s4->{o};\
        \
        my $o5;\
        my $f5 = $prfxs{'p5_'};\
        my $s5 = $s3->{o5} ||= {};\
        $s5 = $s5->{ $r->{$_->{col}} } ||= {} for @$f5;\
        unless (%$s5) {\
          $o5 = {};\
          for my $f (@$f5) {\
	          $o5->{$f->{name}} = $r->{$f->{col}};\
	        }\
          push @{$o3->{'y'}}, $s5->{o} = $o5;\
        } \
        $o5 = $s5->{o};\
        \
        my $o6;\
        my $f6 = $prfxs{'p6_'};\
        my $s6 = $s3->{o6} ||= {};\
        $s6 = $s6->{ $r->{$_->{col}} } ||= {} for @$f6;\
        unless (%$s6) {\
          $o6 = {};\
          for my $f (@$f6) {\
            $o6->{$f->{name}} = $r->{$f->{col}};\
          }\
          push @{$o3->{'z'}}, $s6->{o} = $o6;\
        } \
        $o6 = $s6->{o};\
        \
        my $o7;\
        my $f7 = $prfxs{'p7_'};\
        my $s7 = $s6->{o7} ||= {};\
        $s7 = $s7->{ $r->{$_->{col}} } ||= {} for @$f7;\
        unless (%$s7) {\
          $o7 = {};\
          for my $f (@$f7) {\
            $o7->{$f->{name}} = $r->{$f->{col}};\
          }\
          push @{$o6->{'w'}}, $s7->{o} = $o7;\
        } \
        $o7 = $s7->{o};\
      } \
      return \@res;\
    }

> end
