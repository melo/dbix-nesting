package    # Hide from PAUSE
  DBIx::Nesting::t::Utils;

use strict;
use warnings;
use base 'Exporter';

our @EXPORT = ('read_all_test_cases');

sub read_all_test_cases {
  my ($fh) = @_;
  my %test_cases;

  while (my $tc = _read_next_test_case($fh)) {
    push @{ $test_cases{ $tc->{for}{desc} } }, $tc;
  }

  return \%test_cases;
}

sub _read_next_test_case {
  my ($fh) = @_;
  my %tc;

  my ($cf, $e);
  while (<$fh>) {
    last if /^>+\s+end\s*$/;
    $cf = $2, $tc{$cf}{perl} = $1, $tc{$cf}{desc} = $3, next
      if /^>+(\+)?\s+(\w+)(?:\s+(.+))?\s*$/;
    $tc{$cf}{body} .= $_, next if $cf;
    next if /^\s+$/ && !$cf;
    next if /^#/    && !$cf;

    die "Unparsed line $_";
  }

  return unless %tc;

  for my $f (grep { exists $tc{$_}{body} } keys %tc) {
    $tc{$f}{body} =~ s/^\s+|\s+$//g;
    $tc{$f}{body} =~ s/\\\s*\n\s*//gs;
  }
  $tc{$_}{data} = eval $tc{$_}{body} for grep { $tc{$_}{perl} } keys %tc;

  return \%tc;
}

1;
