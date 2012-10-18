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
      $cb = $cache->{$key} ||= $self->compile($meta);
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
  my $prfxs = $stash{prefixes} || [];
  if (@$prfxs) {
    $p .= 'my %fields;';
    $p .= 'for my $f (sort keys %{$_[0][0]}) {' . 'my ($p, $n) = $f =~ m/^(';
    $p .= join('|', sort @$prfxs);
    $p .= ')(.+)$/;next unless $p;' . 'push @{$fields{$p}}, { name => $n, col => $f};}';

    if (my $flds = $stash{fields}) {
      for my $prfx (sort keys %$flds) {
        $p .= "\$fields{'$prfx'} = [";
        $p .= join(',', map {"{col => '$_->{col}', name => '$_->{name}'}"} @{ $flds->{$prfx} });
        $p .= "];";
      }
    }
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
  my ($self, $meta, $stash, $p_id, $p_key) = @_;
  my ($is_top, $p_o_var, $p_s_var, $p_o_var_access, $p_s_var_access);
  if ($p_id) {
    $p_o_var        = "\$o${p_id}";
    $p_s_var        = "\$s${p_id}";
    $p_o_var_access = "${p_o_var}\->{'$p_key'}";
    $p_s_var_access = "${p_s_var}\->";
  }
  else {
    $is_top         = 1;
    $p_o_var_access = '@res';
    $p_s_var_access = '$seen';
  }

  my ($id, $flds, $key, $into, $type, $nest, $prfx, $filter, $builder) =
    @{$meta}{qw(id fields key into type nest prefix filter builder)};
  my $o_var = "\$o$id";
  my $s_var = "\$s$id";
  my $f_var = "\$f$id";
  my $r_var = '$r';

  ## Collect meta-meta for no fields support: collect prefixes, check for fields presence
  if ($prfx) {
    push @{ $stash->{prefixes} }, $prfx;
    $stash->{fields}{$prfx} = $flds if $flds;
  }

  ## Preamble: decl o_var and f_var if needed
  ## Also make sure parent vars exists: start of block
  my $p = "my ($o_var, $s_var);";
  $p .= "if ($p_s_var && $p_o_var) { " if $p_s_var && $p_o_var;
  $p .= "my $f_var = \$fields{'$prfx'};" if $prfx;

  ## Missing rows: if all fields are null, we most likely have a left join - deal in else below
  $p .= "if (grep {defined()} map ";
  $p .= $prfx ? "{ $r_var\->{\$_\->{col}} } \@$f_var" : "{ $r_var\->{\$_} } keys \%$r_var";
  $p .= ') {';

  ## Fetch seen data for this block, deal with dynamic key
  $p .= "$s_var = $p_s_var_access\{o$id} ||= {};";
  $p .= "$s_var = $s_var\->{(defined()? \"D\$_\" : 'Undef')} ||= {} for ";
  if ($key) {
    $p .= "map { $r_var\->{\$_} } ";
    $p .= '(';
    $p .= join(',', map {"'$_->{col}'"} @$key);
    $p .= ');';
  }
  else {
    $p .= "map { $r_var\->{\$_\->{col}} } \@$f_var;";
  }

  ## Check seen for first time o_var...
  $p .= "unless (\%$s_var) {";

  ## Not seen yet, so prep our o_var
  if ($prfx) {
    my $loop_var = '$f';
    $p .= "$o_var = {};" . "$o_var\->{\$_\->{name}} = $r_var\->{\$_\->{col}} for \@$f_var;";
  }
  else {
    $p .= "$o_var = {";
    $p .= "'$_->{name}'=>$r_var\->{'$_->{col}'}," for @$flds;
    $p .= "};";
  }
  $p .= "$o_var = { '$into' => $o_var };" if $into;

  ## per relation-type manipulation
  my $rel_p;    ## delay code insertion, decided based on filter presence
  if ($type eq 'multiple') {
    my $lp_o_var_access = $p_o_var_access;
    $lp_o_var_access = "\@{$lp_o_var_access}" unless substr($lp_o_var_access, 0, 1) eq '@';
    $rel_p = ($filter || $builder) ? 'unshift' : 'push';
    $rel_p .= " $lp_o_var_access, $o_var;";
  }
  elsif ($type eq 'single') {
    $rel_p = "$p_o_var_access = $o_var;";
  }
  else {
    die "Unkonwn relation type '$type'";
  }

  ## Filtering/Building
  if ($filter || $builder) {
    $stash->{filtering}++;    ## include filter storage and execution code in _emit_code

    my $n_var = "\$n$id";
    $p .= 'push @filter_cbs, sub {' . "local \$_ = $o_var;";
    if ($filter) {
      $p .= "DBIx::Nesting::_filter('$filter')->($o_var);";
    }
    if ($builder) {
      $p .= "my $n_var = DBIx::Nesting::_filter('$builder')->($o_var);$o_var = $n_var if defined $n_var;";
    }
    $p .= $rel_p . '};';
  }
  else {
    $p .= $rel_p;
  }

  ## .. and o_var is set now, so make sure we are using the correct one
  $p .= "$s_var\->{o} = $o_var;}"    # ends the unless (%$s_var)
    . " $o_var = $s_var\->{o};";

  ## End of logic if row really exists...
  $p .= '} ';

  ## ... now take care of left joins
  if (!$is_top and $type eq 'multiple') {
    $p .= "else { $p_o_var_access = [] unless exists $p_o_var_access } ";
  }

  ## Make sure parent vars exists: end of block
  $p .= "} " if $p_s_var && $p_o_var;

  ## Nesting...
  $p .= $self->_emit_meta_block($nest->{$_}, $stash, $id, $_) for sort keys %$nest;

  return $p;
}


########################################
# Meta cleanups and filter/builder cache

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

  # filters && builders
  for my $type (qw( filter builder )) {
    next unless exists $meta->{$type};
    $cm{$type} = _filter(add => $meta->{$type});
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
