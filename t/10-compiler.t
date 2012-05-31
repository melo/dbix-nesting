#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use DBIx::Nesting;

my $n = 'DBIx::Nesting';

subtest 'meta utils' => sub {
  my $t = sub { $n->_expand_meta_with_defaults(@_) };    ## shortcut

  cmp_deeply(
    $t->({ fields => [qw(k n)] }),
    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      pk     => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n' }],
      id     => 1,
    },
    'simple meta, single col set, no joins, implicit pk'
  );

  cmp_deeply(
    $t->({ fields => ['k', n => { label => 'N' }] }),
    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      pk     => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      id     => 1,
    },
    'simple meta, single col set, no joins, implicit pk, extra field meta'
  );

  cmp_deeply(
    $t->({ fields => ['k', n => { label => 'N' }], pk => 'k' }),
    { fields => [{ name => 'k', col => 'k' }, { name => 'n', col => 'n', label => 'N' }],
      pk     => [{ name => 'k', col => 'k' }],
      id     => 1,
    },
    'simple meta, single col set, no joins, explicit pk, extra field meta'
  );

  cmp_deeply(
    $t->({ fields => ['k', n => { label => 'N' }, 's'], pk => [qw(k s)] }),
    { fields => [
        { name => 'k', col => 'k' },
        { name => 'n', col => 'n', label => 'N' },
        { name => 's', col => 's' },
      ],
      pk => [{ name => 'k', col => 'k' }, { name => 's', col => 's' }],
      id => 1,
    },
    'simple meta, single col set, no joins, explicit multi-col pk, extra field meta'
  );

  cmp_deeply(
    $t->({ fields => ['k', n => { label => 'N' }], pk => 'k', prefix => 'p1' }),
    { fields => [{ name => 'k', col => 'p1_k' }, { name => 'n', col => 'p1_n', label => 'N' },],
      pk     => [{ name => 'k', col => 'p1_k' }],
      id     => 1,
    },
    'simple meta, single col set, no joins, explicit pk, extra field meta'
  );
};


done_testing();
