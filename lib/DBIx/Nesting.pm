package DBIx::Nesting;

# ABSTRACT: Take multi-join DBI result and nest it into a tree
# VERSION
# AUTHORITY

use strict;
use warnings;
use Eval::Closure ();

sub new { bless {}, shift }

{
  my %cache;

  sub transform {
    my ($self, $meta, $in, $key) = @_;

    my $cb;
    if ($key) {
      my $cache = \%cache;
      $cache = $self->{cache} ||= {} if ref($self);
      $cb    = $cache->{$key} ||= $self->compile($meta);
    }
    else {
      $cb = $self->compile($meta);
    }

    return $cb->($in);
  }
}

sub compile {
  my ($self, $meta) = @_;

  return Eval::Closure::eval_closure(source => $self->_emit_code($meta));
}


################
# Code generator

sub _emit_code {
  my ($self, $meta) = @_;
  $meta = $self->_expand_meta_with_defaults($meta);

  ## gen code and collect meta-meta from out meta
  my %stash;
  my $pmb = $self->_emit_meta_block($meta, \%stash);

  ## generate anon sub + shortcut exit + state vars
  my $p = 'sub {return [] unless @{$_[0]};my(%seen, @res);';
  $p .= 'my @filter_cbs;' if $stash{filtering};

  ## generate code to cache fields per prefix
  if ($stash{fscan}) {
    $p .= 'my %prfxs;for my $f (sort keys %{$_[0][0]}) {' . 'my ($p, $n) = $f =~ m/^(';
    $p .= join('|', sort @{ $stash{prefixes} });
    $p .= ')(.+)$/;next unless $p;' . 'push @{$prfxs{$p}}, { name => $n, col => $f};}';
  }

  ## row iterator....
  $p .= 'for my $r (@{$_[0]}) {';
  $p .= $pmb;
  $p .= '}';

  ## Execute cached filters if any
  $p .= ' $_->() for reverse @filter_cbs;' if $stash{filtering};

  ## and finish with our return
  $p .= ' return \@res;}';

  return $p;
}

sub _emit_meta_block {
  my ($self, $meta, $stash, $p_o_var, $p_s_var) = @_;
  $p_o_var = '@res'  unless $p_o_var;
  $p_s_var = '$seen' unless $p_s_var;

  my ($id, $flds, $key, $into, $type, $nest, $prfx, $filter) =
    @{$meta}{qw(id fields key into type nest prefix filter)};
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

  ## Fetch seen data for this block, deal with dynamic key
  if ($key) {
    $p .= "my $s_var = $p_s_var\{o$id}";
    $p .= "{$r_var\->{'$_->{col}'}}" for @$key;
    $p .= "||= {};";
  }
  else {    # Dynammic key: all fields will be key
    $p .= "my $s_var = $p_s_var\{o$id} ||= {};";
    $p .= "$s_var = $s_var\->{ $r_var\->{\$_->{col}} } ||= {} for \@$f_var;";
  }

  ## Check seen for first time o_var...
  $p .= "unless (\%$s_var) {";

  ## Not seen yet, so prep our o_var
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
  $p .= "$o_var = { '$into' => $o_var };" if $into;

  ## per relation-type manipulation
  my $rel_p;    ## delay code insertion, decided based on filter presence
  if ($type eq 'multiple') {
    $p_o_var = "\@{$p_o_var}" unless substr($p_o_var, 0, 1) eq '@';
    $rel_p = $filter ? 'unshift' : 'push';
    $rel_p .= " $p_o_var, $o_var;";
  }
  elsif ($type eq 'single') {
    $rel_p = "$p_o_var = $o_var;";
  }
  else {
    die "Unkonwn relation type '$type'";
  }

  ## Filtering
  if ($filter) {
    $stash->{filtering}++;    ## include filter storage and execution code in _emit_code

    my $n_var = "\$n$id";
    $p
      .= 'push @filter_cbs, sub {'
      . "local \$_ = $o_var;"
      . "my $n_var = DBIx::Nesting::_filter('$filter')->($o_var);"
      . "$o_var = $n_var if defined $n_var;"
      . $rel_p . '};';
  }
  else {
    $p .= $rel_p;
  }

  ## .. and o_var is set now, so make sure we are using the correct one
  $p .= "$s_var\->{o} = $o_var;}"    # ends the unless (%$s_var)
    . " $o_var = $s_var\->{o};";

  ## Nesting...
  $p .= $self->_emit_meta_block($nest->{$_}, $stash, "$o_var\->{'$_'}", "$s_var\->")
    for sort keys %$nest;

  return $p;
}


################################
# Meta cleanups and filter cache

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

  ## Define key
  my $key = $ef;
  if (exists $meta->{key}) {
    $key = $meta->{key};
    $key = [$key] unless ref($key) eq 'ARRAY';
    $key = [map { exists $fm{$_} ? $fm{$_} : { name => $_, col => "$prefix$_" } } @$key];
  }
  $cm{key} = $key if $key;

  # into elevation
  $cm{into} = $meta->{into} if exists $meta->{into};

  # filters
  if (exists $meta->{filter}) {
    my $filter_cb = $meta->{filter};
    $cm{filter} = _filter(add => $filter_cb);

  }

  # Relation type
  my $type = 'multiple';
  if (exists $meta->{type}) {
    $type = $meta->{type};
  }
  $cm{type} = $type;

  # Cleanup nested meta
  $cm{nest} = {};
  if (exists $meta->{nest}) {
    my $n = $meta->{nest};
    ## The sort is not required, but gives stability to the output, easier to test :)
    $cm{nest}{$_} = $self->_expand_meta_with_defaults($n->{$_}, $idx) for sort keys %$n;
  }

  return \%cm;
}

{
  ## I love state...
  my %filters_cb_reg;

  sub _filter {
    my $filter_id = shift;

    unless (@_) {
      die "Filter ID '$filter_id' not found," unless exists $filters_cb_reg{$filter_id};
      return $filters_cb_reg{$filter_id};
    }

    my $filter_cb = shift;
    $filter_id = "$filter_cb";
    $filters_cb_reg{$filter_id} = $filter_cb;
    return $filter_id;
  }
}
1;
