package Dumbbench::Instance::Cmd;
use strict;
use warnings;
use Carp ();
use Time::HiRes ();

use Dumbbench::Instance;
use parent 'Dumbbench::Instance';

use Class::XSAccessor {
  getters => [qw(
    command
    dry_run_command
  )],
  accessors => [qw(
    use_shell
  )],
};

=head1 NAME

Dumbbench::Instance::Cmd - Benchmarks an external command

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

This class inherits from L<Dumbbench::Instance> and implements
benchmarking of external commands.

=head1 METHODS

=head2 new

Constructor that takes named arguments.

In addition to the properties of the base class, the
C<Dumbbench::Instance::Cmd> constructor requires a C<command>
parameter. C<command> can either be string specifying the
external command with its options or (preferably) a
reference to an array of command-name and options
(as with the ordinary C<system> builtin).

Optionally, you can provide a C<dry_run_command> option.
It has the same structure and purpose as the C<command>
option, but it is used for the dry-runs. If C<dry_run_command>
is not specified, the dry-run will consist of starting
another process that immediately exits.

=head2 command

Returns the command that was set on object construction.

=head2 dry_run_command

Returns the command that was set for dry-runs on object construction.

=cut


sub clone {
  my $self = shift;
  my $clone = $self->SUPER::clone(@_);
  if (defined $self->command) {
    $clone->{command} = [@{$self->command}];
  }
  return $clone;
}

sub single_run {
  my $self = shift;

  my @cmd = (ref($self->{command}) ? @{$self->{command}} : ($self->{command}));
  @cmd = ("") if not @cmd;
  #my $start;
  #my $tbase = Time::HiRes::time();
  #while ( ($start = Time::HiRes::time()) <= $tbase+1.e-15 ) {} # wait for clock tick. See discussion in Benchmark.pm comments
  my ($start, $end);
  if ($self->use_shell) {
    my $cmd = join ' ', @cmd;
    $start = Time::HiRes::time();
    system($cmd);
    $end = Time::HiRes::time();
  }
  else {
    my $cmd = $cmd[0];
    $start = Time::HiRes::time();
    system({$cmd} @cmd);
    $end = Time::HiRes::time();
  }

  my $duration = $end-$start;
  return $duration;
}

sub single_dry_run {
  my $self = shift;

  my @cmd;
  
  if (defined $self->{dry_run_command}) {
    @cmd = (ref($self->{dry_run_command}) ? @{$self->{dry_run_command}} : ($self->{dry_run_command}));
  }
  else {
    my @orig_cmd = (ref($self->{command}) ? @{$self->{command}} : ($self->{command}));
    if (@orig_cmd and $orig_cmd[0] =~ /(?:^|\b)perl(?:\d+\.\d+\.\d+)?/) {
      @cmd = ($orig_cmd[0], '-e', '1');
    }
  }
  if (!@cmd) {
    # FIXME For lack of a better dry run test, we always use perl for now as a fallback
    @cmd = ($^X, qw(-e 1));
  }

  my ($start, $end);
  if ($self->use_shell) {
    my $cmd = join ' ', @cmd;
    my $tbase = Time::HiRes::time();
    while ( ($start = Time::HiRes::time()) <= $tbase+1.e-15 ) {} # wait for clock tick. See discussion in Benchmark.pm comments
    system($cmd);
    $end = Time::HiRes::time();
  }
  else {
    my $cmd = $cmd[0];
    my $tbase = Time::HiRes::time();
    while ( ($start = Time::HiRes::time()) <= $tbase+1.e-15 ) {} # wait for clock tick. See discussion in Benchmark.pm comments
    system({$cmd} @cmd);
    $end = Time::HiRes::time();
  }

  my $duration = $end-$start;
  return $duration;
}
 

1;


__END__

=head1 SEE ALSO

L<Dumbbench>, L<Dumbbench::Instance>,
L<Dumbbench::Instance::PerlEval>,
L<Dumbbench::Instance::PerlSub>,
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
