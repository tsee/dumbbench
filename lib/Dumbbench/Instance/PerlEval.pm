package # hide from PAUSE
  Dumbbench::Instance::PerlEval::_Lexical;
# clean lexical scope
sub doeval {
  local $_ = shift;
  for (1..$_) {
    local $_;
    eval ${shift()};
  }
}

package Dumbbench::Instance::PerlEval;
use strict;
use warnings;
use Carp ();
use Time::HiRes ();

use Dumbbench::Instance;
use parent 'Dumbbench::Instance';

use Class::XSAccessor {
  getters => [qw(
    code
    dry_run_code
  )],
  accessors => [qw(
    _n_loop_timings
    _n_dry_loop_timings
  )],
};

use constant TOO_SMALL => 1.e-4;

=head1 NAME

Dumbbench::Instance::PerlEval - Benchmarks a string of Perl code

=head1 SYNOPSIS

  use Dumbbench;
  
  my $bench = Dumbbench->new(
    target_rel_precision => 0.005, # seek ~0.5%
    initial_runs         => 20,    # the higher the more reliable
  );
  $bench->add_instances(
    Dumbbench::Instance::PerlEval->new(name => 'mauve', code => 'for(1..1e9){$i++}'), 
    # ... more things to benchmark ...
  );
  $bench->run();
  # ...

=head1 DESCRIPTION

This class inherits from L<Dumbbench::Instance> and implements
benchmarking of strings of Perl code using C<eval "">.

=head1 METHODS

=head2 new

Constructor that takes named arguments.

In addition to the properties of the base class, the
C<Dumbbench::Instance::PerlEval> constructor requires a
C<code> parameter. The C<code> needs to be a string that
is suitable for passing repeatedly to string-C<eval>.

Optionally, you can provide a C<dry_run_code> option.
It has the same structure and purpose as the C<code>
option, but it is used for the dry-runs. By default, a simple
C<eval> is used for this, so it's unlikely you will need the dry-run
unless you want to strip out the compile-time overhead of your code.

=head2 code

Returns the code string that was set during construction.

=head2 dry_run_code

Returns the dry-run code string that was set during construction.

=cut

# Note: We don't need to override clone() since we don't have composite attributes

sub single_run {
  my $self = shift;
  return $self->_run(0);
}

sub single_dry_run {
  my $self = shift;
  return $self->_run(1);
}

sub _run {
  my $self = shift;
  my $dry = shift;
  my $code_acc   = $dry ? 'dry_run_code' : 'code';
  my $n_loop_acc = $dry ? '_n_dry_loop_timings' : '_n_loop_timings';

  my $code = $self->$code_acc;
  $code = '' if not defined $code;
  
  my $duration;
  my $n = $self->$n_loop_acc || 1;
  while (1) {
    #my $start;
    #my $tbase = Time::HiRes::time();
    #while ( ($start = Time::HiRes::time()) <= $tbase+1.e-15 ) {} # wait for clock tick. See discussion in Benchmark.pm comments
    my $start = Time::HiRes::time();
    Dumbbench::Instance::PerlEval::_Lexical::doeval($n, \$code);
    my $end = Time::HiRes::time();

    $duration = $end-$start;
    if ($duration > TOO_SMALL) {
      last;
    }
    $n *= 2;
  }
  $self->$n_loop_acc($n);

  return $duration / $n;
}

 

1;


__END__

=head1 SEE ALSO

L<Dumbbench>, L<Dumbbench::Instance>,
L<Dumbbench::Instance::Cmd>, L<Dumbbench::Result>

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
