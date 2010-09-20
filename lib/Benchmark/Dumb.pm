package Benchmark::Dumb;
use strict;
use warnings;
use Dumbbench;
use Carp ();

our @CARP_NOT = qw(
  Dumbbench
  Dumbbench::Instance
  Dumbbench::Instance::Cmd
  Dumbbench::Instance::PerlEval
  Dumbbench::Instance::PerlSub
  Dumbbench::Result
);

our $VERSION = '0.03';

require Exporter;

# TODO: cmpthese countit
#
our @ISA = qw(Exporter);
our @EXPORT = ();
our @EXPORT_OK = qw(
  timeit timethis timethese cmpthese countit
  timediff timestr timesum 
);
our %EXPORT_TAGS = (all => [@EXPORT, @EXPORT_OK]);

# strip out :hireswallclock
sub import {
  my $class = shift;
  my @args = grep $_ ne ':hireswallclock', @_;
  $class->export_to_level(1, $class, @args);
}

sub _dumbbench_from_count {
  my $count = shift;
  my %opt = @_;
  if ($count >= 1) {
    $opt{initial_runs} = int($count);
  }
  if (int($count) != $count) {
    $opt{target_rel_precision} = $count - int($count);
  }
  else { # $count < 0
    Carp::croak("The negative-value variant of COUNT in benchmarks is not supported by Benchmark::Dumb");
  }

  return Dumbbench->new(
    # TODO configurable default settings?
    %opt,
  );
}

sub _prepare {
  my $count = shift;
  my $code  = shift;
  my $name  = shift;
  my $bench = shift || _dumbbench_from_count($count); # FIXME %opt?
  $name = 'anon' if not defined $name;
  my $class = ref($code) ? "Dumbbench::Instance::PerlSub" : "Dumbbench::Instance::PerlEval";
  $bench->add_instances(
    $class->new(
      name => $name, code => $code,
    )
  );
  return $bench;
}

sub timeit {
  my $count = shift;
  my $code  = shift;
  my $bench = _prepare($count, $code);
  $bench->run;

  return __PACKAGE__->_new(
    instance => ($bench->instances)[0],
  );
}

sub timethis {
  my $count = shift;
  my $code = shift;
  my $title = shift;
  $title = 'timethis ' . $count if not defined $title;
  my $style = shift;
  my $res = timeit($count, $code);
  $res->{name} = $title;
  print "$title: ", $res->timestr($style), "\n";
  return $res;
}

sub _timethese_guts {
  my $count = shift;
  my $instances = shift;
  my $silent = shift;

  my $max_name_len = 1;
  my $bench = _dumbbench_from_count($count); # FIXME %opt?
  foreach my $name (sort keys %$instances) {
    _prepare($count, $instances->{$name}, $name, $bench);
    $max_name_len = length($name) if length($name) > $max_name_len;
  }

  $bench->run;
  $bench->verbosity(0) if $silent;

  if (not $silent) {
    print "Benchmark: ran ",
          join(', ', map $_->name, $bench->instances),
          ".\n";
  }

  my $result = {};
  foreach my $inst ($bench->instances) {
    my $r = $result->{$inst->name} = __PACKAGE__->_new(
      instance => $inst,
    );
    if (not $silent) {
      printf("%${max_name_len}s: ", $r->name);
      print $r->timestr(), "\n";
    }
  }
  return $result;
}

sub timethese {
  my $count = shift;
  my $instances = shift;
  Carp::croak("Need count and code-hashref as arguments")
    if not defined $count or not ref($instances) or not ref($instances) eq 'HASH';

  return _timethese_guts($count, $instances, 0);
}


sub cmpthese {
  my $count = shift;
  my $codehashref = shift;
  my $style = shift; # ignored unless 'none'

  my $results;
  if (ref($count)) {
    $results = $count;
  }
  else {
    $results = _timethese_guts($count, $codehashref, 'silent');
  }

  my @sort_res = map [$_, $results->{$_}, $results->{$_}->_rate], keys %$results;
  @sort_res = sort { $a->[2] <=> $b->[2] } @sort_res;

  my @cols = map $_->[0], @sort_res;
  my @rows = (
    ['', 'Rate', @cols]
  );

  foreach my $record (@sort_res) {
    my ($name, $bench, $rate) = @$record;
    my $rstr = $bench->_rate_str($rate) . '/s';
    $rstr =~ s/\s+//g;
    my @row;
    push @row, $name, $rstr;

    foreach my $cmp_record (@sort_res) {
      my ($cmp_name, $cmp_bench, $cmp_rate) = @$cmp_record;
      if ($cmp_name eq $name) {
        push @row, '--';
        next;
      }

      my $cmp = 100*$rate/$cmp_rate - 100;
      # skip the uncertainty if it's less than one permille
      # absolute or relative
      if ($cmp->raw_error->[0] < 1.e-1
          or ($cmp->raw_error->[0]+1.e-15)/$cmp->raw_number < 1.e-3)
      {
        my $rounded = Number::WithError::round_a_number($cmp->raw_number, -1);
        push @row, sprintf('%.1f', $rounded) . '%';
      }
      else {
        my $cmp_str = $bench->_rate_str($cmp).'%'; # abuse
        $cmp_str =~ s/\s+//g;
        push @row, $cmp_str;
      }
    }

    push @rows, \@row;
  }

  if (lc($style) ne 'none') {
    # find the max column lengths
    # could be done in the above iteration, too
    my $ncols = @{$rows[0]};
    my @col_len = ((0) x $ncols);
    foreach my $row (@rows) {
      foreach my $colno (0..$ncols-1) {
        $col_len[$colno] = length($row->[$colno])
          if length($row->[$colno]) > $col_len[$colno];
      }
    }

    my $format = join( ' ', map { "%${_}s" } @col_len) . "\n";
    substr( $format, 1, 0 ) = '-'; # right-align name

    foreach my $row (@rows) {
      printf($format,  @$row);
    }
  }

  return \@rows;
}


#####################################
# the fake-OO stuff
use Class::XSAccessor {
  getters => {
    _result => 'result',
    name    => 'name',
  },
};
# No. Users aren't meant to create new objects at this point.
sub _new {
  my $class = shift;
  $class = ref($class) if ref($class);
  my %args = @_;
  my $self = bless {} => $class;
  if (defined $args{instance}) {
    my $inst = $args{instance};
    $self->{name} = $inst->name;
    $self->{result} = $inst->result->new;
  }
  else {
    %$self = %args;
  }
  return $self;
}

sub iters {
  my $self = shift;
  return $self->_result->nsamples;
}

sub timesum {
  my $self = shift;
  my $other = shift;
  my $result = $self->_result + $other->_result;
  return $self->_new(result => $result, name => '');
}


sub timediff {
  my $self = shift;
  my $other = shift;
  my $result = $self->_result - $other->_result;
  return $self->_new(result => $result, name => '');
}

sub timestr {
  my $self = shift;
  my $style = shift || '';
  my $format = shift || '5.2f';

  $style = lc($style);
  return("") if $style eq 'none'; # what's the point?

  my $res = $self->_result;
  my $time = $res->number;
  my $err = $res->error->[0];
  my $rel = ($time > 0 ? $err/$time : 1) * 100;
  my $digits;
  if ($rel =~ /^([0\.]*)/) { # quick'n'dirty significant digits
    $digits = length($1) + 1;
  }
  $rel = sprintf("\%.${digits}f", $rel);
  
  my $rate = $self->_rate_str;
  my $str = "$time +- $err wallclock secs ($rel%) @ ($rate)/s (n=" . $res->nsamples . ")";

  return $str;
}

sub _rate_str {
  my $self = shift;
  my $per_sec = shift || $self->_rate;

  # The joys of people-not-enjoying-scientific-notation
  my $digit = $per_sec->significant_digit;
  $digit = "." . -$digit if $digit < 0;
  my $ps_format = "%${digit}f";
  my $ps_string = sprintf("$ps_format +- $ps_format", $per_sec->number*1., $per_sec->error->[0]);
  return $ps_string;
}

sub _rate {
  my $self = shift;
  my $res = $self->_result;
  my $per_sec = 1./($res+1.e-20); # the joys of overloading. See Number::WithError.
  return $per_sec;
}



1;

__END__

=head1 NAME

Benchmark::Dumb - Benchmark.pm compatibility layer for Dumbbench

=head1 SYNOPSIS

  use Benchmark::Dumb qw(:all);
  cmpthese(
    0.05, # 5% precision
    {
      fast => 'fast code',
      slow => 'slow code',
    }
  );
  # etc

=head1 DESCRIPTION

This module implements an interface that is B<similar> to the functional
interface of the L<Benchmark> module. This module, however, uses the
L<Dumbbench> benchmarking tool under the hood. For various reasons,
the interface and the output of the benchmark runs are B<not exactly>
the same. Among other reasons, you would lose out on some of
C<Dumbbench>'s advantages.

Understanding this documentation requires some familiarity of how
C<Benchmark.pm> works since it mostly explains how this module
is different.

Please read the following section carefully to understand the most
important differences:

=head2 Differences to Benchmark.pm

This is a list of differences to the interface and behaviour
of the C<Benchmark> module. It may not be complete.
If so, please let me know.

=over 2

=item *

B<The C<$count> parameter is interpreted very differently!>

With C<Benchmark.pm>, specifying a positive integer meant that the
benchmark should be run exactly C<$count> times. A negative value
indicated that the code should be run until C<$count> seconds of
cumulated run-time have elapsed.

With C<Benchmark::Dumb>, we can do better. A positive integer
specifies the I<minimum> number of iterations. C<Dumbbench> may choose
to run more iterations to arrive at the necessary precision.

Specifying a certain target run-time (via a negative number for C<$count>)
may seem like a tempting idea, but if you care at all about the precision
of your result, it's quite useless.
B<This usage is not supported by C<Benchmark::Dumb>!>

Instead, if you pass a positive floating point number as C<$count>,
the fractional part of the number willbe interpreted as the target
I<relative precision> that you expect from the result.

Finally, supplying a C<0> as C<$count> means that C<Dumbbench> will
be invoked with the default settings. This is good enough for most cases.

=item *

There are no exported functions I<by default>!

=item *

The C<:hireswallclock> option is ignored. We always use the hi-res wallclock!
While on the topic: We also I<only> use wallclock times.

=item *

The cache-related functions aren't implemented because we don't use a cache.

=item *

The original C<Benchmark.pm> implementation provides a rudimentary
object-oriented interface. We do not faithfully copy that. See
L<"/METHODS"> below.

=item *

The benchmark code will be run in a special package. It will B<not> be
run in the caller package (at this time). If you need access to
previously-set-up package variables, you will need to include a
C<package> statement in your code.

=item *

The C<debug> method is not implemented.

=back

=head1 FUNCTIONS

=head1 METHODS

Please note that while the original C<Benchmark> objects
practically asked for manual introspection since the API
didn't provide convenient access to all information,
that practice is frowned upon with C<Benchmark::Dumb> objects.
You have been warned.

=head1 SEE ALSO

L<Dumbbench>

L<Benchmark>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
