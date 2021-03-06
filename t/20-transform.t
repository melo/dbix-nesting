#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use DBIx::Nesting;
use DBIx::Nesting::t::Utils;
use DateTime;
use DateTime::Format::MySQL;

my $n  = 'DBIx::Nesting';
my $tc = read_all_test_cases(\*DATA);

my $s  = DBIx::Nesting->new;
my $ic = sub { $s->transform(@_) };
my $gc = sub { $n->transform(@_) };

for my $t (@{ $tc->{all} }) {
  my $in   = $t->{in}{data};
  my $out  = $t->{out}{data};
  my $desc = $t->{msg}{desc};
  my $meta = $t->{meta}{data};

  ## normal run
  cmp_deeply($gc->($meta, $in), $out, "Doing $desc");

  ## caching run - global cache
  cmp_deeply($gc->($meta, $in, $desc), $out, "... first run, init cache for $desc");
  cmp_deeply($gc->($meta, $in, $desc), $out, "...... second run from cache for $desc");
  cmp_deeply($gc->($meta, $in, $desc), $out, "...... third run from cache for $desc");

  ## caching run - per-instance cache
  cmp_deeply($ic->($meta, $in, $desc), $out, "... first run, init cache for $desc");
  cmp_deeply($ic->($meta, $in, $desc), $out, "...... second run from cache for $desc");
  cmp_deeply($ic->($meta, $in, $desc), $out, "...... third run from cache for $desc");
}


done_testing();

__DATA__

### Simple cases

> msg simple case, single table
>+ meta

    { prefix => 'p1' }

>+ in

    [{ p1_k => 1, p1_n => "a" }, { p1_k => 2, p1_n => "b" }, { p1_k => 3, p1_n => "c" }]

>+ out

    [{ k => 1, n => "a" }, { k => 2, n => "b" }, { k => 3, n => "c" }]

> end


> msg simple case, single table, with a primary key definition
>+ meta

    { prefix => 'p1', key => 'k' }

>+ in

    [{ p1_k => 1, p1_n => "a" }, { p1_k => 1, p1_n => "b" }, { p1_k => 3, p1_n => "c" }]

>+ out

    [{ k => 1, n => "a" }, { k => 3, n => "c" }]

> end


> msg single table, with a key definition, null fields
>+ meta

    { prefix => 'p1', key => ['k1', 'k2'] }

>+ in

    [ { p1_k1 => 1,     p1_k2 => 1,     p1_n => "a" },
      { p1_k1 => 1,     p1_k2 => 1,     p1_n => "b" },
      { p1_k1 => 3,     p1_k2 => 1,,    p1_n => "c" },
      { p1_k1 => 3,     p1_k2 => undef, p1_n => "d" },
      { p1_k1 => undef, p1_k2 => undef, p1_n => "u1" },
      { p1_k1 => undef, p1_k2 => undef, p1_n => "u2" },
      { p1_k1 => undef, p1_k2 => undef, p1_n => undef },
    ]

>+ out

    [ { k1 => 1,     k2 => 1,     n => "a" },
      { k1 => 3,     k2 => 1,     n => "c" },
      { k1 => 3,     k2 => undef, n => "d" },
      { k1 => undef, k2 => undef, n => "u1" },
    ]

> end


> msg simple case, single table, with a primary key definition, with into level
>+ meta

    { prefix => 'p1', into => 't' }

>+ in

    [{ p1_k => 1, p1_n => "a" }, { p1_k => 2, p1_n => "b" }, { p1_k => 3, p1_n => "c" }]

>+ out

    [{ t => { k => 1, n => "a" } }, { t => { k => 2, n => "b" } }, { t => { k => 3, n => "c" } }]

> end


> msg two tables implicit prefixes, into on top level
>+ meta

    { into => 't', nest => { x => {} } }

>+ in

    [
      { p1_k => 1, p1_n => 'a', p2_k => 1, p2_x => 'x1' },
      { p1_k => 1, p1_n => 'a', p2_k => 2, p2_x => 'x2' },
      { p1_k => 2, p1_n => 'b', p2_k => 1, p2_x => 'x1' },
    ]

>+ out

    [ { t => { k => 1, n => 'a' }, x => [{ k => 1, x => 'x1' }, { k => 2, x => 'x2' }] },
      { t => { k => 2, n => 'b' }, x => [{ k => 1, x => 'x1' }] },
    ]

> end


> msg two tables implicit prefixes, into on top level, left join
>+ meta

    { into => 't', nest => { x => {} } }

>+ in

    [
      { p1_k => 1, p1_n => 'a', p2_k => 1, p2_x => 'x1' },
      { p1_k => 1, p1_n => 'a', p2_k => 2, p2_x => 'x2' },
      { p1_k => 2, p1_n => 'b', p2_k => undef, p2_x => undef },
    ]

>+ out

    [ { t => { k => 1, n => 'a' }, x => [{ k => 1, x => 'x1' }, { k => 2, x => 'x2' }] },
      { t => { k => 2, n => 'b' }, x => [] },
    ]

> end


> msg complex example for transform
>+ meta

    { key  => 'k',
      into => 'm',
      nest => {
        s => { prefix => 's', type => 'single', key => 'k' },
        t => {
          key  => 'tid',
          nest => {
            z => {
              nest   => { w => { prefix => 'w', builder => sub { return { W => $_ } } } },
              prefix => 'z',
            },
            x => {
              prefix => 'x',
              key    => 'q',
              filter => sub {$_->{t} = DateTime::Format::MySQL->parse_date($_->{t})},
            },
          },
          prefix => 't',
        },
      },
      prefix => 'p',
    }

>+ in

    [ { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 1,

        z_k => 1,
        z_n => 'z1',

        w_k => 1,
        w_n => 'w1',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 1,

        z_k => 1,
        z_n => 'z1',

        w_k => 2,
        w_n => 'w2',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 1,

        z_k => 1,
        z_n => 'z1',

        w_k => 1,
        w_n => 'w1',

        x_q => 2,
        x_n => 'x q2',
        x_t => '2012-01-01',
      },

      { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 1,

        z_k => 1,
        z_n => 'z1',

        w_k => 2,
        w_n => 'w2',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2012-01-01',
      },

      { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 2,

        z_k => 1,
        z_n => 'z1',

        w_k => 2,
        w_n => 'w2',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 1,
        p_n => 'np1',

        s_k => 1,
        s_n => 'sn p1',

        t_tid => 2,

        z_k => 2,
        z_n => 'z2',

        w_k => 2,
        w_n => 'w2',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 2,
        p_n => 'np2',

        s_k => 1,
        s_n => 'sn p2',

        t_tid => 3,

        z_k => 4,
        z_n => 'z4',

        w_k => 5,
        w_n => 'w5',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 2,
        p_n => 'np2',

        s_k => 1,
        s_n => 'sn p2',

        t_tid => 4,

        z_k => 4,
        z_n => 'z4',

        w_k => 6,
        w_n => 'w6',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 2,
        p_n => 'np2',

        s_k => 1,
        s_n => 'sn p2',

        t_tid => 11,

        z_k => undef,
        z_n => undef,

        w_k => 6,
        w_n => 'w6',

        x_q => 1,
        x_n => 'x q1',
        x_t => '2011-01-01',
      },

      { p_k => 2,
        p_n => 'np2',

        s_k => 1,
        s_n => 'sn p2',

        t_tid => 12,

        z_k => 1212,
        z_n => 'tid 12',

        w_k => undef,
        w_n => undef,

        x_q => undef,
        x_n => undef,
        x_t => undef,
      },

      { p_k => 2,
        p_n => 'np2',

        s_k => 1,
        s_n => 'sn p2',

        t_tid => 13,

        z_k => undef,
        z_n => undef,

        w_k => 6,
        w_n => 'w6',

        x_q => undef,
        x_n => undef,
        x_t => undef,
      },

      { p_k => 9,
        p_n => 'np9',

        s_k => 9,
        s_n => 'sn p9',

        t_tid => undef,

        z_k => 999,
        z_n => 'z999',

        w_k => 999,
        w_n => 'w999',

        x_q => 999,
        x_n => 'x q999',
        x_t => '2099-09-09',
      },
    ]

>+ out

    [ { m => {
          k => 1,
          n => 'np1'
        },
        s => { k => 1, n => 'sn p1' },
        t => [
          { tid => 1,
            z   => [
              { k => 1,
                n => 'z1',
                w => [{ W => {k => 1, n => 'w1'} }, { W => {k => 2, n => 'w2'} },],
              },
            ],
            x => [
              { q => 1,
                n => 'x q1',
                t => DateTime->new(year => 2011, month => 1, day => 1),
              },
              { q => 2,
                n => 'x q2',
                t => DateTime->new(year => 2012, month => 1, day => 1),
              },
            ],
          },
          { tid => 2,
            z   => [
              { k => 1,
                n => 'z1',
                w => [{ W => {k => 2, n => 'w2'} }],
              },
              { k => 2,
                n => 'z2',
                w => [{ W => {k => 2, n => 'w2'} }],
              },
            ],
            x => [
              { q => 1,
                n => 'x q1',
                t => DateTime->new(year => 2011, month => 1, day => 1),
              },
            ],
          },
        ],
      },
      { m => {
          k => 2,
          n => 'np2',
        },
        s => {
          k => 1,
          n => 'sn p2',
        },
        t => [
          { tid => 3,
            z   => [
              { k => 4,
                n => 'z4',
                w => [{ W => {k => 5, n => 'w5'} }],
              },
            ],
            x => [{ q => 1, n => 'x q1', t => DateTime->new(year => 2011, month => 1, day => 1) }],
          },
          { tid => 4,
            z   => [
              { k => 4,
                n => 'z4',
                w => [{ W => {k => 6, n => 'w6'} }],
              },
            ],
            x => [{ q => 1, n => 'x q1', t => DateTime->new(year => 2011, month => 1, day => 1) }],
          },
          { tid => 11,
            z   => [],
            x   => [{ q => 1, n => 'x q1', t => DateTime->new(year => 2011, month => 1, day => 1) }],
          },
          { tid => 12,
            z   => [
              { k => 1212,
                n => 'tid 12',
                w => [],
              },
            ],
            x => [],
          },
          { tid => 13, z => [], x => [] },
        ],
      },
      { m => {
          k => 9,
          n => 'np9',
        },
        s => {
          k => 9,
          n => 'sn p9',
        },
        t => [],
      },
    ]

> end
