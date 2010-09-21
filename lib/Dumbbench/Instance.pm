package Dumbbench::Instance;
use strict;
use warnings;
use Carp ();
use List::Util qw/min max/;

require Dumbbench::Instance::Cmd;
require Dumbbench::Instance::PerlEval;
require Dumbbench::Instance::PerlSub;

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw(
    name
    dry_result
    result
  )],
  getters => [qw(timings dry_timings)],
};

=head1 NAME

Dumbbench::Instance - A benchmark instance within a Dumbbench

=head1 SYNOPSIS

  use Dumbbench;
  
  my $bench = Dumbbench->new(
    target_rel_precision => 0.005, # seek ~0.5%
    initial_runs         => 20,    # the higher the more reliable
  );
  $bench->add_instances(
    Dumbbench::Instance::Cmd->new(name => 'mauve', command => [qw(perl -e 'something')]), 
    # ... more things to benchmark ...
  );
  $bench->run();
  # ...

=head1 DESCRIPTION

This module is the base class for all benchmark instances. For example,
for benchmarking external commands, you should use L<Dumbbench::Instance::Cmd>.

The synopsis shows how instances of subclasses of
C<Dumbbench::Instance> are added to a benchmark run.

=head1 METHODS

=head2 new

Constructor that takes named arguments. In this base class,
the only recognized argument is an instance C<name>.

=head2 timings

Returns the internal array reference of timings or undef if
there aren't any.

=head2 dry_timings

Same as C<timings> but for dry-run timings.

=head2 name

Returns the name of the instance.

=head2 clone

Returns a full (deep) copy of the object. May have to be
augmented in subclasses.

=cut

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

=head2 single_run

Needs to be implemented in subclasses:
A method that performs a single benchmark run and returns the
duration of the run in seconds.

=cut

sub single_run {
  my $self = shift;
  Carp::croak("Can't single_run Dumbbench::Instance: Choose a subclass that implements running.");
}

=head2 single_dry_run

Needs to be implemented in subclasses:
A method that performs a single dry-run and returns the
duration of the run in seconds.

=cut

sub single_dry_run {
  my $self = shift;
  Carp::croak("Can't single_dry_run Dumbbench::Instance: Choose a subclass that implements dry-running.");
}

=head2 timings_as_histogram

If the optional L<SOOT> module is installed,
C<Dumbbench> can generate histograms of the timing distributions.

This method creates such a histogram object (of type C<TH1D>)
and returns it. If C<SOOT> is not available, this method
returns the empty list.

=cut

sub timings_as_histogram {
  my $self = shift;
  my $timings = $self->timings||[];
  return $self->_timings_as_histogram($timings);
}

=head2 dry_timings_as_histogram

Same as C<timings_as_histogram>, but for the timings
from dry-runs.

=cut

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
  my $n = max(@$timings/8, 100);
  my $prefix = $is_dry ? 'dry_' : '';
  my $name = defined($self->name) ? "${prefix}timings_" . $self->name : "${prefix}timings";
  my $hist = TH1D->new($name, "distribution of benchmark ${prefix}timings", int($n), $min, $max);
  $hist->GetXaxis()->SetTitle("run time [s]");
  $hist->GetYaxis()->SetTitle("#");
  $hist->Fill($_) for @$timings;
  return $hist;
}

1;

__END__

=head1 SEE ALSO

L<Dumbbench>

L<Dumbbench::Instance::Cmd>,
L<Dumbbench::Instance::PerlEval>,
L<Dumbbench::Instance::PerlSub>

L<Dumbbench::Result>

L<Benchmark>

L<Number::WithError> does the Gaussian error propagation.

L<SOOT> can optionally generate histograms from the
timing distributions.

L<http://en.wikipedia.org/wiki/Median_absolute_deviation>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
