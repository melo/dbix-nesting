package DBIx::Nesting;

# ABSTRACT: Take multi-join DBI result and nest it into a tree
# VERSION
# AUTHORITY

use strict;
use warnings;

sub _emit_code {
  my ($self, $meta) = @_;
  $meta = $self->_expand_meta_with_defaults($meta);

  my $p = $self->_emit_block($meta);

  return 'sub {my(%seen, @res);for my $r (@{$_[0]}) {' . $p . '} return \@res;}';
}

sub _emit_block {
  my ($self, $m) = @_;
  my ($id, $flds, $pk, $nest) = @{$m}{qw(id fields pk nest)};

  ## decl field hash for this meta
  my $p = '$o' . $id . '={';
  $p .= "'$_->{name}'=>\$r->{'$_->{col}'}," for @$flds;
  $p .= '};';

  ## Top level is special
  if ($id == 1) {
    unless ($nest) {    ## shortcut: no nesting? just push result, done
      $p .= 'push @res,$o1;';
      return $p;
    }
  }
}

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
    $prefix = $meta->{prefix} . '_';
    $prefix =~ s/#/$id/g;

    $cm{prefix} = $prefix;
  }

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
