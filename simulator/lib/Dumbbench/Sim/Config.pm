package Dumbbench::Sim::Config;
use strict;
use warnings;
use Carp 'croak';
use YAML::Tiny;

use Class::XSAccessor {
  constructor => 'new',
  accessors   => [qw(
    hist_bins
    hist_min
    hist_max

    clock_tick
    wait_for_tick

    true_time
    gauss_jitter_sigma
    duration_lower_limit

    outlier_fraction
    outlier_offset
    outlier_jitter

    variability_measure
    outlier_rejection

  )],
};

sub from_yaml {
  my $class = shift;
  my $file = shift;
  my $yaml = YAML::Tiny->read($file);
  defined($yaml) or croak("Invalid config file");
  my $self = $class->new(%{$yaml->[0]});
  return $self;
}


1;
