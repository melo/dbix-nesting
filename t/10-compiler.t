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
      key    => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      id     => 1,
      type   => 'multiple',
      nest   => {},
    },

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, implicit pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }] }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      key    => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      id     => 1,
      type   => 'multiple',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta, filter
>+ meta

    { fields => ['k', n => { label => 'N' }], key => 'k', filter => sub { } }

>+ expected

    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      key    => [{ name => 'k', col => 'k' }],
      id     => 1,
      filter => Test::Deep::re(qr{^CODE\(0x[0-9a-f]+\)$}),
      type   => 'multiple',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit multi-col pk, extra field meta
>+ meta

    { fields => ['k', n => { label => 'N' }, 's'], key => [qw(k s)] }

>+ expected

    { fields => [
        { name => 'k', col => 'k' },
        { name => 'n', col => 'n', label => 'N' },
        { name => 's', col => 's' },
      ],
      key  => [{ name => 'k', col => 'k' }, { name => 's', col => 's' }],
      id   => 1,
      type   => 'multiple',
      nest => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no joins, explicit pk, extra field meta, explicit prefix
>+ meta

    { fields => ['k', n => { label => 'N' }], key => 'k', prefix => 'p', into => 't' }

>+ expected

    { fields => [{ name => 'k', col => 'p_k' }, { name => 'n', col => 'p_n', label => 'N' },],
      key    => [{ name => 'k', col => 'p_k' }],
      id     => 1,
      prefix => 'p_',
      into   => 't',
      type   => 'multiple',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no fields, explicit pk
>+ meta

    { key => 'k' }

>+ expected

    { key    => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      type   => 'multiple',
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
      type   => 'multiple',
      nest   => {},
    }

> end


> for _expand_meta_with_defaults
> msg simple meta, single col set, no fields, no explicit pk
>+ meta

    { nest => { x => {} } }

>+ expected

    { id     => 1,
      prefix => 'p1_',
      type   => 'multiple',
      nest   => {
        x => {
          id     => 2,
          prefix => 'p2_',
          type   => 'multiple',
          nest   => {},
        },
      },
    }

> end


### _expand_meta_with_defaults complex

> for _expand_meta_with_defaults
> msg two col set, multiple relation, explicit pk, automatic prefix
>+ meta

    { fields => [qw(k n)],
      key    => 'k',
      nest   => {
        s => {
          fields => [qw(k t)],
          key    => 'k',
        },
      },
    }

>+ expected

    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n' }],
      key    => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      type   => 'multiple',
      nest   => {
        s => {
          fields => [{ name => 'k', col => 'p2_k' }, { name => 't', col => 'p2_t' }],
          key    => [{ name => 'k', col => 'p2_k' }],
          id     => 2,
          prefix => 'p2_',
          type   => 'multiple',
          nest   => {},
        },
      },
    }

> end


> for _expand_meta_with_defaults
> msg several col set, multiple relations, several levels, explicit pk, automatic prefix
>+ meta

    { fields => [qw(k n)],
      key    => 'k',
      nest   => {
        s => {
          fields => [qw(k s)],
          key    => 'k',
        },
        t => {
          fields => [qw(tid t)],
          key    => 'tid',
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
      key    => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      type   => 'multiple',
      nest   => {
        s => {
          fields => [{ name => 'k', col => 'p2_k' }, { name => 's', col => 'p2_s' }],
          key    => [{ name => 'k', col => 'p2_k' }],
          id     => 2,
          prefix => 'p2_',
          type   => 'multiple',
          nest   => {},
        },
        t => {
          fields => [{ name => 'tid', col => 'p3_tid' }, { name => 't', col => 'p3_t' }],
          key    => [{ name => 'tid', col => 'p3_tid' }],
          id     => 3,
          prefix => 'p3_',
          type   => 'multiple',
          nest   => {
            x => {
              fields => [{ name => 'xid', col => 'p4_xid' }, { name => 'x', col => 'p4_x' }],
              key    => [{ name => 'xid', col => 'p4_xid' }, { name => 'x', col => 'p4_x' }],
              id     => 4,
              prefix => 'p4_',
              type   => 'multiple',
              nest   => {},
            },
            y => {
              fields => [{ name => 'yid', col => 'p5_yid' }, { name => 'y', col => 'p5_y' }],
              key    => [{ name => 'yid', col => 'p5_yid' }, { name => 'y', col => 'p5_y' }],
              id     => 5,
              prefix => 'p5_',
              type   => 'multiple',
              nest   => {},
            },
            z => {
              fields => [{ name => 'zid', col => 'p6_zid' }, { name => 'z', col => 'p6_z' }],
              key    => [{ name => 'zid', col => 'p6_zid' }, { name => 'z', col => 'p6_z' }],
              id     => 6,
              prefix => 'p6_',
              type   => 'multiple',
              nest   => {
                w => {
                  fields => [{ name => 'wid', col => 'p7_wid' }, { name => 'w', col => 'p7_w' }],
                  key    => [{ name => 'wid', col => 'p7_wid' }, { name => 'w', col => 'p7_w' }],
                  id     => 7,
                  prefix => 'p7_',
                  type   => 'multiple',
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
> msg several col set, multiple relations, several levels, no fields, some pk, automatic prefix
>+ meta

    { key  => 'k',
      nest => {
        s => { key => 'k' },
        t => {
          key  => 'tid',
          nest => {
            z => { nest => { w => {} }, },
            x => {},
            y => {},
          },
        },
      },
    }

>+ expected

    { key    => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
      prefix => 'p1_',
      type  => 'multiple',
      nest   => {
        s => {
          key    => [{ name => 'k', col => 'p2_k' }],
          id     => 2,
          prefix => 'p2_',
          type   => 'multiple',
          nest   => {},
        },
        t => {
          key    => [{ name => 'tid', col => 'p3_tid' }],
          id     => 3,
          prefix => 'p3_',
          type   => 'multiple',
          nest   => {
            x => {
              id     => 4,
              prefix => 'p4_',
              type   => 'multiple',
              nest   => {},
            },
            y => {
              id     => 5,
              prefix => 'p5_',
              type   => 'multiple',
              nest   => {},
            },
            z => {
              id     => 6,
              prefix => 'p6_',
              type   => 'multiple',
              nest   => {
                w => {
                  id     => 7,
                  prefix => 'p7_',
                  type   => 'multiple',
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
        my ($o1, $s1);\
        $s1 = $seen{o1} ||= {};\
        $s1 = $s1->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('k','n');\
        unless (%$s1) {\
          $o1 = {\
            'k'=>$r->{'k'},\
            'n'=>$r->{'n'},\
          };\
          push @res, $o1;\
          $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
      } \
      return \@res;\
    }

> end


> for _emit_code
> msg single col set, explicit prefix and pk
>+ meta

    { fields => [qw(k n)], prefix => 'x', key => 'n' }

> expected

    sub {\
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      my %fields;\
      for my $f (sort keys %{$_[0][0]}) {\
        my ($p, $n) = $f =~ m/^(x_)(.+)$/;\
        next unless $p;\
        push @{$fields{$p}}, { name => $n, col => $f};\
      }\
      $fields{'x_'} = [{col => 'x_k', name => 'k'},{col => 'x_n', name => 'n'}];\
      \
      for my $r (@{$_[0]}) {\
        my ($o1, $s1);\
        my $f1 = $fields{'x_'};\
        $s1 = $seen{o1} ||= {};\
        $s1 = $s1->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('x_n');\
        unless (%$s1) {\
          $o1 = {};\
          $o1->{$_->{name}} = $r->{$_->{col}} for @$f1;\
          push @res, $o1;\
          $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
      } \
      return \@res;\
  }

> end


> for _emit_code
> msg double col set, explicit pk
>+ meta

    { fields => [qw(k n)], key => 'k', nest => { o => { fields => [qw(k o)] } } }

> expected

    sub {\
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      my %fields;\
      for my $f (sort keys %{$_[0][0]}) {\
        my ($p, $n) = $f =~ m/^(p1_|p2_)(.+)$/;\
        next unless $p;\
        push @{$fields{$p}}, { name => $n, col => $f};\
      }\
      $fields{'p1_'} = [{col => 'p1_k', name => 'k'},{col => 'p1_n', name => 'n'}];\
      $fields{'p2_'} = [{col => 'p2_k', name => 'k'},{col => 'p2_o', name => 'o'}];\
      \
      for my $r (@{$_[0]}) {\
        my ($o1, $s1);\
        my $f1 = $fields{'p1_'};\
        $s1 = $seen{o1} ||= {};\
        $s1 = $s1->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p1_k');\
        unless (%$s1) {\
          $o1 = {};\
          $o1->{$_->{name}} = $r->{$_->{col}} for @$f1;\
          push @res, $o1;\
          $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        \
        my ($o2, $s2);\
        if ($s1 && $o1) { \
          my $f2 = $fields{'p2_'};\
          $s2 = $s1->{o2} ||= {};\
          $s2 = $s2->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p2_k','p2_o');\
          unless (%$s2) {\
            $o2 = {};\
            $o2->{$_->{name}} = $r->{$_->{col}} for @$f2;\
            push @{$o1->{'o'}}, $o2;\
            $s2->{o} = $o2;\
          } \
          $o2 = $s2->{o};\
        } \
      } \
      return \@res;\
  }

> end


> for _emit_code
> msg complex multi-nested meta
>+ meta

    { fields => [qw(k n)],
      key    => 'k',
      nest   => {
        s => {
          fields => [qw(k s)],
          key    => 'k',
        },
        t => {
          fields => [qw(tid t)],
          key    => 'tid',
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
      my %fields;\
      for my $f (sort keys %{$_[0][0]}) {\
        my ($p, $n) = $f =~ m/^(p1_|p2_|p3_|p4_|p5_|p6_|p7_)(.+)$/;\
        next unless $p;\
        push @{$fields{$p}}, { name => $n, col => $f};\
      }\
      $fields{'p1_'} = [{col => 'p1_k', name => 'k'},{col => 'p1_n', name => 'n'}];\
      $fields{'p2_'} = [{col => 'p2_k', name => 'k'},{col => 'p2_s', name => 's'}];\
      $fields{'p3_'} = [{col => 'p3_tid', name => 'tid'},{col => 'p3_t', name => 't'}];\
      $fields{'p4_'} = [{col => 'p4_xid', name => 'xid'},{col => 'p4_x', name => 'x'}];\
      $fields{'p5_'} = [{col => 'p5_yid', name => 'yid'},{col => 'p5_y', name => 'y'}];\
      $fields{'p6_'} = [{col => 'p6_zid', name => 'zid'},{col => 'p6_z', name => 'z'}];\
      $fields{'p7_'} = [{col => 'p7_wid', name => 'wid'},{col => 'p7_w', name => 'w'}];\
      \
      for my $r (@{$_[0]}) {\
        my ($o1, $s1);\
        my $f1 = $fields{'p1_'};\
        $s1 = $seen{o1} ||= {};\
        $s1 = $s1->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p1_k');\
        unless (%$s1) {\
          $o1 = {};\
          $o1->{$_->{name}} = $r->{$_->{col}} for @$f1;\
          push @res, $o1;\
          $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        \
        my ($o2, $s2);\
        if ($s1 && $o1) { \
          my $f2 = $fields{'p2_'};\
          $s2 = $s1->{o2} ||= {};\
          $s2 = $s2->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p2_k');\
          unless (%$s2) {\
            $o2 = {};\
            $o2->{$_->{name}} = $r->{$_->{col}} for @$f2;\
            push @{$o1->{'s'}}, $o2;\
            $s2->{o} = $o2;\
          } \
          $o2 = $s2->{o};\
        } \
        \
        my ($o3, $s3);\
        if ($s1 && $o1) { \
          my $f3 = $fields{'p3_'};\
          $s3 = $s1->{o3} ||= {};\
          $s3 = $s3->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p3_tid');\
          unless (%$s3) {\
            $o3 = {};\
            $o3->{$_->{name}} = $r->{$_->{col}} for @$f3;\
            push @{$o1->{'t'}}, $o3;\
            $s3->{o} = $o3;\
          } \
          $o3 = $s3->{o};\
        } \
        \
        my ($o4, $s4);\
        if ($s3 && $o3) { \
          my $f4 = $fields{'p4_'};\
          $s4 = $s3->{o4} ||= {};\
          $s4 = $s4->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p4_xid','p4_x');\
          unless (%$s4) {\
            $o4 = {};\
            $o4->{$_->{name}} = $r->{$_->{col}} for @$f4;\
            push @{$o3->{'x'}}, $o4;\
            $s4->{o} = $o4;\
          } \
          $o4 = $s4->{o};\
        } \
        \
        my ($o5, $s5);\
        if ($s3 && $o3) { \
          my $f5 = $fields{'p5_'};\
          $s5 = $s3->{o5} ||= {};\
          $s5 = $s5->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p5_yid','p5_y');\
          unless (%$s5) {\
            $o5 = {};\
            $o5->{$_->{name}} = $r->{$_->{col}} for @$f5;\
            push @{$o3->{'y'}}, $o5;\
            $s5->{o} = $o5;\
          } \
          $o5 = $s5->{o};\
        } \
        \
        my ($o6, $s6);\
        if ($s3 && $o3) { \
          my $f6 = $fields{'p6_'};\
          $s6 = $s3->{o6} ||= {};\
          $s6 = $s6->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p6_zid','p6_z');\
          unless (%$s6) {\
            $o6 = {};\
            $o6->{$_->{name}} = $r->{$_->{col}} for @$f6;\
            push @{$o3->{'z'}}, $o6;\
            $s6->{o} = $o6;\
          } \
          $o6 = $s6->{o};\
        } \
        \
        my ($o7, $s7);\
        if ($s6 && $o6) { \
          my $f7 = $fields{'p7_'};\
          $s7 = $s6->{o7} ||= {};\
          $s7 = $s7->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p7_wid','p7_w');\
          unless (%$s7) {\
            $o7 = {};\
            $o7->{$_->{name}} = $r->{$_->{col}} for @$f7;\
            push @{$o6->{'w'}}, $o7;\
            $s7->{o} = $o7;\
          } \
          $o7 = $s7->{o};\
        } \
      } \
      return \@res;\
    }

> end


> for _emit_code
> msg complex multi-nested meta, without fields, mixed relation types, with into
>+ meta

    { key  => 'k',
      into => 'm',
      nest => {
        s => { type => 'single', key => 'k' },
        t => {
          key  => 'tid',
          nest => {
            z => { nest   => { w => {} }, },
            x => { fields => [qw(xid x)] },
            ## real code would use a sub { ... } below but this is easier to test
            y => { filter => 'CODE(0x00000000)' },
          },
        },
      },
    }


> expected

    sub {\
	    return [] unless @{$_[0]};\
      my(%seen, @res);\
      my @filter_cbs;\
      my %fields;\
      for my $f (sort keys %{$_[0][0]}) {\
        my ($p, $n) = $f =~ m/^(p1_|p2_|p3_|p4_|p5_|p6_|p7_)(.+)$/;\
        next unless $p;\
        push @{$fields{$p}}, { name => $n, col => $f};\
      }\
      $fields{'p4_'} = [{col => 'p4_xid', name => 'xid'},{col => 'p4_x', name => 'x'}];\
      \
      for my $r (@{$_[0]}) {\
        my ($o1, $s1);\
        my $f1 = $fields{'p1_'};\
        $s1 = $seen{o1} ||= {};\
        $s1 = $s1->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p1_k');\
        unless (%$s1) {\
	        $o1 = {};\
		      $o1->{$_->{name}} = $r->{$_->{col}} for @$f1;\
		      $o1 = { 'm' => $o1 };\
          push @res, $o1;\
          $s1->{o} = $o1;\
        } \
        $o1 = $s1->{o};\
        \
        my ($o2, $s2);\
        if ($s1 && $o1) { \
          my $f2 = $fields{'p2_'};\
          $s2 = $s1->{o2} ||= {};\
          $s2 = $s2->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p2_k');\
          unless (%$s2) {\
            $o2 = {};\
	          $o2->{$_->{name}} = $r->{$_->{col}} for @$f2;\
            $o1->{'s'} = $o2;\
            $s2->{o} = $o2;\
          } \
          $o2 = $s2->{o};\
        } \
        \
        my ($o3, $s3);\
        if ($s1 && $o1) { \
          my $f3 = $fields{'p3_'};\
          $s3 = $s1->{o3} ||= {};\
          $s3 = $s3->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p3_tid');\
          unless (%$s3) {\
            $o3 = {};\
	          $o3->{$_->{name}} = $r->{$_->{col}} for @$f3;\
            push @{$o1->{'t'}}, $o3;\
            $s3->{o} = $o3;\
          } \
          $o3 = $s3->{o};\
        } \
          \
        my ($o4, $s4);\
        if ($s3 && $o3) { \
          my $f4 = $fields{'p4_'};\
          $s4 = $s3->{o4} ||= {};\
          $s4 = $s4->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_} } ('p4_xid','p4_x');\
          unless (%$s4) {\
            $o4 = {};\
            $o4->{$_->{name}} = $r->{$_->{col}} for @$f4;\
            push @{$o3->{'x'}}, $o4;\
            $s4->{o} = $o4;\
          } \
          $o4 = $s4->{o};\
        } \
        \
        my ($o5, $s5);\
        if ($s3 && $o3) { \
          my $f5 = $fields{'p5_'};\
          $s5 = $s3->{o5} ||= {};\
          $s5 = $s5->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_->{col}} } @$f5;\
          unless (%$s5) {\
            $o5 = {};\
            $o5->{$_->{name}} = $r->{$_->{col}} for @$f5;\
            push @filter_cbs, sub {\
              local $_ = $o5;\
              my $n5 = DBIx::Nesting::_filter('CODE(0x00000000)')->($o5);\
              $o5 = $n5 if defined $n5;\
              unshift @{$o3->{'y'}}, $o5;\
            };\
            $s5->{o} = $o5;\
          } \
          $o5 = $s5->{o};\
        } \
        \
        my ($o6, $s6);\
        if ($s3 && $o3) { \
          my $f6 = $fields{'p6_'};\
          $s6 = $s3->{o6} ||= {};\
          $s6 = $s6->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_->{col}} } @$f6;\
          unless (%$s6) {\
            $o6 = {};\
            $o6->{$_->{name}} = $r->{$_->{col}} for @$f6;\
            push @{$o3->{'z'}}, $o6;\
            $s6->{o} = $o6;\
          } \
          $o6 = $s6->{o};\
        } \
        \
        my ($o7, $s7);\
        if ($s6 && $o6) { \
          my $f7 = $fields{'p7_'};\
          $s7 = $s6->{o7} ||= {};\
          $s7 = $s7->{(defined()? "D$_" : 'Undef')} ||= {} for map { $r->{$_->{col}} } @$f7;\
          unless (%$s7) {\
            $o7 = {};\
            $o7->{$_->{name}} = $r->{$_->{col}} for @$f7;\
            push @{$o6->{'w'}}, $o7;\
            $s7->{o} = $o7;\
          } \
          $o7 = $s7->{o};\
        } \
      } \
      $_->() for reverse @filter_cbs; \
      return \@res;\
    }

> end
