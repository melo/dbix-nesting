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

  ## gen code and collect meta-meta from out meta
  my %stash;
  my $pmb = $self->_emit_meta_block($meta, \%stash);

  ## generate final code
  my $p = 'sub {return [] unless @{$_[0]};my(%seen, @res);';
  if ($stash{fscan}) {
    $p .= 'my %prfxs;for my $f (sort keys %{$_[0][0]}) {' . 'my ($p, $n) = $f =~ m/^(';
    $p .= join('|', sort @{ $stash{prefixes} });
    $p .= ')(.+)$/;next unless $p;' . 'push @{$prfxs{$p}}, { name => $n, col => $f};}';
  }
  $p .= 'for my $r (@{$_[0]}) {';
  $p .= $pmb;
  $p .= '} return \@res;}';

  return $p;
}

sub _emit_meta_block {
  my ($self, $meta, $stash, $p_o_var, $p_s_var) = @_;
  $p_o_var = '@res'  unless $p_o_var;
  $p_s_var = '$seen' unless $p_s_var;

  my ($id, $flds, $pk, $nest, $prfx) = @{$meta}{qw(id fields pk nest prefix)};
  my $o_var = "\$o$id";
  my $s_var = "\$s$id";
  my $f_var = "\$f$id";
  my $r_var = '$r';

  ## Collect meta-meta for no fields support: collect prefixes, check for fields presence
  push @{ $stash->{prefixes} }, $prfx;
  $stash->{fscan}++ unless $flds;

  ## Preamble: decl o_var and f_var if needed
  my $p = "my $o_var;";
  $p .= "my $f_var = \$prfxs{'$prfx'};" unless $flds;

  ## Fetch seen data for this block, deal with dynamic pk
  if ($pk) {
    $p .= "my $s_var = $p_s_var\{o$id}";
    $p .= "{$r_var\->{'$_->{col}'}}" for @$pk;
    $p .= "||= {};";
  }
  else {    # Dynammic pk: all fields will be key
    $p .= "my $s_var = $p_s_var\{o$id} ||= {};";
    $p .= "$s_var = $s_var\->{ $r_var\->{\$_->{col}} } ||= {} for \@$f_var;";
  }

  ## Check seen for first time o_var...
  $p .= "unless (\%$s_var) {";

  ## Not seen yet, so prep our o_var
  $p_o_var = "\@{$p_o_var}" unless substr($p_o_var, 0, 1) eq '@';
  if ($flds) {
    $p .= "$o_var = {";
    $p .= "'$_->{name}'=>$r_var\->{'$_->{col}'}," for @$flds;
    $p .= "};";
  }
  else {
    my $loop_var = '$f';
    $p
      .= "$o_var = {};"
      . "for my $loop_var (\@$f_var) {"
      . "$o_var\->{$loop_var\->{name}} = $r_var\->{$loop_var\->{col}};" . '}';
  }

  ## per relation-type manipulation: 1:m only for now
  $p .= "push $p_o_var, $s_var\->{o} = $o_var;";

  ## .. and o_var is set now, so make sure we are using the correct one
  $p .= '}'    # ends the unless (%$s_var)
    . " $o_var = $s_var\->{o};";

  ## Nesting...
  $p .= $self->_emit_meta_block($nest->{$_}, $stash, "$o_var\->{'$_'}", "$s_var\->") for sort keys %$nest;

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
  elsif ($id > 1 || exists $meta->{nest} || !exists $meta->{fields}) {
    $cm{prefix} = $prefix = "p${id}_";
  }

  ## Expand fields with prefix
  my (%fm, $ef);
  if (exists $meta->{fields}) {
    $ef = $cm{fields} = [];
    my @mf = @{ $meta->{fields} };
    while (@mf) {
      my $f = shift @mf;
      my $i = @mf && ref($mf[0]) ? shift @mf : {};
      $i->{name} = $f;
      $i->{col}  = "$prefix$f";
      push @$ef, $fm{$f} = $i;
    }
  }

  ## Define PK
  my $pk = $ef;
  if (exists $meta->{pk}) {
    $pk = $meta->{pk};
    $pk = [$pk] unless ref($pk) eq 'ARRAY';
    $pk = [map { exists $fm{$_} ? $fm{$_} : { name => $_, col => "$prefix$_" } } @$pk];
  }
  $cm{pk} = $pk if $pk;

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
