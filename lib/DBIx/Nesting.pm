package DBIx::Nesting;

# ABSTRACT: Take multi-join DBI result and nest it into a tree
# VERSION
# AUTHORITY

use strict;
use warnings;

sub _expand_meta_with_defaults {
  my ($self, $meta, $idx) = @_;
  my %cm;

  ## Unique suffix id per meta block
  unless ($idx) {
    my $i = 1;
    $idx = \$i;
  }
  my $id = $cm{id} = $$idx++;

  ## Prefix to use
  my $prefix = '';
  if (exists $meta->{prefix}) {
    $prefix = $meta->{prefix}.'_';
    $prefix =~ s/#/$id/g;

    $cm{prefix} = $prefix;
  };

  ## Expand fields with prefix
  my %fm;
  my $ef = $cm{fields} = [];
  my @mf = @{ $meta->{fields} };
  while (@mf) {
    my $f = shift @mf;
    my $i = @mf && ref($mf[0]) ? shift @mf : {};
    $i->{name} = $f;
    $i->{col}  = "$prefix$f";
    push @$ef, $fm{$f} = $i;
  }

  ## Define PK
  my $pk = $ef;
  if (exists $meta->{pk}) {
    $pk = $meta->{pk};
    $pk = [$pk] unless ref($pk) eq 'ARRAY';
    $pk = [map { exists $fm{$_} ? $fm{$_} : die "Pk '$_' not found in field list" } @$pk];
  }
  $cm{pk} = $pk;

  return \%cm;
}

1;
