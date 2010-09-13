#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw/time/;
use Getopt::Long qw/GetOptions/;
use List::Util qw/sum/;
use Number::WithError;

our $precision       = 0.10;
our $abs_precision   = 0;
our $V               = 0;
our $initial_timings = 10; # more or less arbitrary but can't be much smaller than 6-7
our $dryrun_cmd      = '';
our $max_iter        = 100;
our $raw             = 0;
our $use_std_dev     = 0;

Getopt::Long::Configure('bundling');
GetOptions(
  'p|precision=f'    => \$precision,
  'a|absprecision=f' => \$abs_precision,
  'v|verbose+'       => \$V,
  'i|initial=i'      => \$initial_timings,
  'm|maxiter=i'      => \$max_iter,
  'raw'              => \$raw,
  's|std'            => \$use_std_dev,
);

if ($raw) {
  $V = 0;
}

if ($precision <= 0 and $abs_precision <= 0) {
  die "Need either --precision (-p) or --absprecision (-a) set to positive value\n";
}
elsif ($initial_timings < 6) {
  warn "Number of initial timings is VERY low. Result will be unreliable.\n";
}

my @CMD = @ARGV or die;



print "Running initial dry timing for warming up the cache...\n" if $V;
run_dry(\@CMD);

print "Running dry timing...\n" if $V;
my ($dry_timings, $dry_result) = run_timing(\@CMD, 'dry');
if ($V > 1) {
  print "Ran " . scalar(@$dry_timings) . " dry runs.\n";
  print "Results: $dry_result" . sprintf(" (%.1f%%)\n", ($dry_result->raw_error->[0]/$dry_result->raw_number)*100);
}

print "Running initial timing for warming up the cache...\n" if $V;
run(\@CMD) for 1..10;

my ($timings, $result) = run_timing(\@CMD);

$result = $result - $dry_result;
my $mean = $result->raw_number;
my $sigma = $result->raw_error->[0];

if (not $raw) {
  print "Ran " . scalar(@$timings) . " iterations of the command.\n";
  print "Rounded run time per iteration: $result" . sprintf(" (%.1f%%)\n", $sigma/$mean*100);
  print "Raw:                            $mean +/- $sigma\n" if $V;
}
else {
  print $result, "\n";
}

sub run_timing {
  my $cmd = shift;
  my $dry = shift;

  local $V = $V;
  local $initial_timings = $initial_timings;
  local $abs_precision = $abs_precision;
  local $precision = $precision;
  local $max_iter = $max_iter;

  if ($dry) {
    $V--; $V = 0 if $V < 0;
    $initial_timings *= 5;
    $abs_precision = 0;
    $precision /= 2;
    $max_iter *= 10;
  }

  my @timings;
  print "Running $initial_timings initial timings...\n" if $V;
  foreach (1..$initial_timings) {
    print "Running timing $_...\n" if $V > 1;
    push @timings, ($dry ? run_dry($cmd) : run($cmd));
  }

  print "Iterating until target precision reached...\n" if $V;

  my $sigma;
  my $mean;

  while (1) {
    $sigma = mean_dev(\@timings);
    $mean  = mean(\@timings);

    # stop condition
    my $need_iter = 0;
    if ($precision > 0) {
      my $rel = $sigma/$mean;
      print "Reached relative precision $rel (neeed $precision).\n" if $V > 1;
      $need_iter++ if $rel > $precision;
    }
    if ($abs_precision > 0) {
      print "Reached absolute precision $sigma (neeed $abs_precision).\n" if $V > 1;
      $need_iter++ if $sigma > $abs_precision;
    }
    last if not $need_iter or @timings == $max_iter;

    push @timings, ($dry ? run_dry($cmd) : run($cmd));
  }

  if (@timings == $max_iter and not $dry) {
    print "Reached maximum number of iterations. Stopping. Precision not reached.\n";
  }

  return(\@timings, Number::WithError->new($mean, $sigma));
}

sub run {
  my $cmd = shift;

  my $start = time();
  system(@$cmd) and die $!;
  my $end = time();

  my $duration = $end-$start;
  return $duration;
}

# virtually exact clone of run()
sub run_dry {
  my $cmd = shift;

  # if the command involves running perl, we can get a better estimate this way:
  if (@$cmd and $cmd->[0] =~ /\bperl/) {
    my $cmd = [$cmd->[0], qw(-e 1)];
    my $start = time();
    system(@$cmd) and die $!;
    my $end = time();
    my $duration = $end-$start;
    return $duration;
  }
  else { # since there's no portable way to do this
    my $cmd = [""];
    my $start = time();
    system(@$cmd) and 1; # damn compiler will kill the and
    my $end = time();

    my $duration = $end-$start;
    return $duration;
  }
}


sub mean {
  my $data = shift;
  return sum(@$data) / @$data;
}

# note: we allow this to sort the input as an optimization
sub median {
  my $data = shift;
  @$data = sort { $a <=> $b } @$data;
  my $n = @$data;
  if ($n % 2) { # odd
    return $data->[int($n/2)];
  }
  else {
    my $half = $n/2;
    return 0.5*($data->[$half]+$data->[$half-1]);
  }
}

sub mad {
  my $data = shift;
  my $median = median($data);
  my @val = map {abs($_ - $median)} @$data;
  return median(\@val);
}

sub mean_dev {
  my $data = shift;

  my $s;
  if ($use_std_dev) {
    $s = std_dev($data);
  }
  else {
    $s = mad($data) * 1.4826;
  }
  return $s / sqrt(@$data);
}

sub std_dev {
  my $data = shift;
  my $mean = mean($data);
  my $var = 0;
  $var += ($_-$mean)**2 for @$data;
  $var /= @$data - 1;
  return sqrt($var);
}

