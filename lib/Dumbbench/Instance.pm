package Dumbbench::Instance;
use strict;
use warnings;
use Carp ();
use List::Util qw/min max/;

require Dumbbench::Instance::Cmd;

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw(
    name
    dry_result
    result
  )],
  getters => [qw(timings dry_timings)],
};

sub clone {
  my $self = shift;
  my $clone = bless({%$self} => ref($self));
  
  if (defined $clone->dry_result) {
    $clone->dry_result($clone->dry_result->new);
  }
  if (defined $clone->result) {
    $clone->result($clone->result->new);
  }
  return $clone;
}

sub single_dry_run {
  my $self = shift;
  Carp::croak("Can't single_dry_run Dumbbench::Instance: Choose a subclass that implements dry-running.");
}

sub single_run {
  my $self = shift;
  Carp::croak("Can't single_run Dumbbench::Instance: Choose a subclass that implements running.");
}

sub timings_as_histogram {
  my $self = shift;
  my $timings = $self->timings||[];
  return $self->_timings_as_histogram($timings);
}

sub dry_timings_as_histogram {
  my $self = shift;
  my $timings = $self->dry_timings||[];
  return $self->_timings_as_histogram($timings, 'dry');
}

sub _timings_as_histogram {
  my $self = shift;
  eval "require SOOT;";
  return() if $@;
  
  my $timings = shift;
  my $is_dry  = shift;
  my $min = (@$timings ? min(@$timings)*0.95 : 0);
  my $max = (@$timings ? max(@$timings)*1.05 : 1);
  my $n = 100; # min(100, @$timings/2);
  my $prefix = $is_dry ? 'dry_' : '';
  my $name = defined($self->name) ? "${prefix}timings_" . $self->name : "${prefix}timings";
  my $hist = TH1D->new($name, "distribution of benchmark ${prefix}timings", int($n), $min, $max);
  $hist->GetXaxis()->SetTitle("run time [s]");
  $hist->GetYaxis()->SetTitle("#");
  $hist->Fill($_) for @$timings;
  return $hist;
}

1;