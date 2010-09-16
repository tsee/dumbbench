package Dumbbench;
use strict;
use warnings;
use Carp ();
use Time::HiRes ();

our $VERSION = '0.01';

require Dumbbench::Result;
require Dumbbench::Stats;
require Dumbbench::Instance;

use Params::Util '_INSTANCE';

use Class::XSAccessor {
  getters => [qw(
    target_rel_precision
    target_abs_precision
    initial_runs
    max_iterations
    variability_measure
    started
  )],
  accessors => [qw(verbosity)],
};


sub new {
  my $proto = shift;
  my $class = ref($proto)||$proto;
  my $self;
  if (not ref($proto)) {
    $self = bless {
      target_rel_precision => 0.10,
      target_abs_precision => 0,
      intial_runs          => 10,
      max_iterations       => 10000,
      variability_measure  => 'mad',
      instances            => [],
      started              => 0,
      @_,
    } => $class;
  }
  else {
    $self = bless {%$proto, @_} => $class;
    my @inst = $self->instances;
    $self->{instances} = [];
    foreach my $instance (@inst) {
      push @{$self->{instances}}, $instance->new;
    }
  }
  
  if ($self->target_abs_precision <= 0 and $self->target_rel_precision <= 0) {
    Carp::croak("Need either target_rel_precision or target_abs_precision > 0");
  }
  if ($self->initial_runs < 6) {
    Carp::carp("Number of initial runs is very small (<6). Precision will be off.");
  }
  
  return $self;
}

sub add_instances {
  my $self = shift;
  
  if ($self->started) {
    Carp::croak("Can't add instances after the benchmark has been started");
  }
  foreach my $instance (@_) {
    if (not _INSTANCE($instance, 'Dumbbench::Instance')) {
      Carp::croak("Argument to add_instances is not a Dumbbench::Instance");
    }
  }
  push @{$self->{instances}}, @_;
}

sub instances {
  my $self = shift;
  return @{$self->{instances}};
}

sub run {
  my $self = shift;
  $self->{started} = 1;
  foreach my $instance ($self->instances) {
    next if $instance->dry_result;
    $self->_run($instance);
  }
}

sub _run {
  my $self = shift;
  my $instance = shift;
  my $dry = shift;

  # for overriding in case of dry-run mode
  my $V = $self->verbosity || 0;
  my $initial_timings = $self->initial_runs;
  my $abs_precision = $self->target_abs_precision;
  my $rel_precision = $self->target_rel_precision;
  my $max_iterations = $self->max_iterations;

  if ($dry) {
    $V--; $V = 0 if $V < 0;
    $initial_timings *= 5;
    $abs_precision    = 0;
    $rel_precision   /= 2;
    $max_iterations  *= 10;
  }

  print "Running initial timing for warming up the cache...\n" if $V;
  if ($dry) {
    # be generous, this is fast
    $instance->single_dry_run();
    $instance->single_dry_run();
    $instance->single_dry_run();
  }
  else {
    $instance->single_run();
  }
  
  my @timings;
  print "Running $initial_timings initial timings...\n" if $V;
  foreach (1..$initial_timings) {
    print "Running timing $_...\n" if $V > 1;
    push @timings, ($dry ? $instance->single_dry_run() : $instance->single_run());
  }

  print "Iterating until target precision reached...\n" if $V;

  my $stats = Dumbbench::Stats->new(data => \@timings);
  my $sigma;
  my $mean;

  my $variability_measure = $self->variability_measure;
  while (1) {
    $sigma = $stats->$variability_measure() / sqrt(scalar(@timings));
    $mean  = $stats->mean();

    # stop condition
    my $need_iter = 0;
    if ($rel_precision > 0) {
      my $rel = $sigma/$mean;
      print "Reached relative precision $rel (neeed $rel_precision).\n" if $V > 1;
      $need_iter++ if $rel > $rel_precision;
    }
    if ($abs_precision > 0) {
      print "Reached absolute precision $sigma (neeed $abs_precision).\n" if $V > 1;
      $need_iter++ if $sigma > $abs_precision;
    }
    last if not $need_iter or @timings == $max_iterations;

    push @timings, ($dry ? $instance->single_dry_run() : $instance->single_run());
  }

  if (@timings == $max_iterations and not $dry) {
    print "Reached maximum number of iterations. Stopping. Precision not reached.\n";
  }

  $instance->{timings} = \@timings;
  if ($dry) {
    $instance->dry_result(Dumbbench::Result->new($mean, $sigma));
  }
  else {
    my $result = Dumbbench::Result->new(timing => $mean, uncertainty => $sigma);
    $result -= $instance->dry_result if defined $instance->dry_result;
    $instance->result($result);
  }
}

sub dry_run {
  my $self = shift;
  $self->{started} = 1;

  foreach my $instance ($self->instances) {
    next if $instance->dry_result;
    $self->_run($instance, 'dry');
  }
}


1;

__END__

=head1 NAME

Dumbbench - Perl extension more reliable benchmarking

=head1 SYNOPSIS

  use Dumbbench;

=head1 DESCRIPTION

=head1 SEE ALSO

L<Benchmark>

L<http://en.wikipedia.org/wiki/Median_absolute_deviation>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
