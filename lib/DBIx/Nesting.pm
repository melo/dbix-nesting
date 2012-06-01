package DBIx::Nesting;

# ABSTRACT: Take multi-join DBI result and nest it into a tree
# VERSION
# AUTHORITY

use strict;
use warnings;

sub compile {
  my ($self, $meta) = @_;

  return eval $self->_emit_code($meta);
}

sub _emit_code {
  my ($self, $meta) = @_;
  $meta = $self->_expand_meta_with_defaults($meta);

  my $p = $self->_emit_meta_block($meta);

  return 'sub {return [] unless @{$_[0]};my(%seen, @res);for my $r (@{$_[0]}) {' . $p
    . '} return \@res;}';
}

sub _emit_meta_block {
  my ($self, $meta, $p_o_var, $p_s_var) = @_;
  $p_o_var = '@res'  unless $p_o_var;
  $p_s_var = '$seen' unless $p_s_var;

  my ($id, $flds, $pk, $nest) = @{$meta}{qw(id fields pk nest)};
  my $o_var = "\$o$id";
  my $s_var = "\$s$id";

  ## Preamble: decl o_var, fetch seen data for this block
  my $p = "my $o_var; my $s_var = $p_s_var\{o$id}";
  $p .= "{\$r->{'$_->{col}'}}" for @$pk;
  $p .= "||= {}; unless (\%$s_var) {";

  ## per relation-type manipulation: 1:m only for now
  $p_o_var = "\@{$p_o_var}" unless substr($p_o_var, 0, 1) eq '@';
  $p .= "push $p_o_var, $o_var = $s_var\->{o} = {";
  $p .= "'$_->{name}'=>\$r->{'$_->{col}'}," for @$flds;
  $p .= "};} $o_var = $s_var\->{o};";

  ## Nesting...
  $p .= $self->_emit_meta_block($nest->{$_}, "$o_var\->{'$_'}", "$s_var\->") for sort keys %$nest;

  return $p;
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
  elsif ($id > 1 || exists $meta->{nest}) {
    $cm{prefix} = $prefix = "p${id}_";
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

  # Cleanup nested meta
  $cm{nest} = {};
  if (exists $meta->{nest}) {
    my $n = $meta->{nest};
    ## The sort is not required, but gives stability to the output, easier to test :)
    $cm{nest}{$_} = $self->_expand_meta_with_defaults($n->{$_}, $idx) for sort keys %$n;
  }

  return \%cm;
}

1;
