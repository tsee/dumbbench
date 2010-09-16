#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw/time/;
use Getopt::Long qw/GetOptions/;
use List::Util qw/sum/;
use Number::WithError;

sub usage {
  my $msg = shift;
  print "$msg\n\n" if defined $msg;

  print <<USAGE;
Usage: $0 [options] -- command with arguments

Options:
 -p=X
 --precision=X     Set the target precision (default: 0.10=10%)
                   Set to 0 to disable.
 -a=x
 --absprecision=X  Set the target absolute precision (default: 0)
                   Set to 0 to disable.

 -v|--verbose      Increase verbosity. Increases up to three times.
 -i=X|--initial=X  Set number of initial timing runs (default: 10)
                   Increase, not decrease this number if possible.
 -m=X|--maxiter=X  Set a hard maximum number of iterations (default:100)
                   If this hard limit is hit, the precision is off.
 --raw             Set raw output mode. Only the final count will be
                   printed to stdout.
 -s|--std          Use the standard deviation instead of the MAD as a
                   measure of variability.
USAGE
  exit(1);
}


our $RelPrecision    = 0.10;
our $AbsPrecision    = 0;
our $V               = 0;
our $InitialTimings  = 10; # more or less arbitrary but can't be much smaller than 6-7
our $DryRunCmd       = '';
our $MaxIter         = 100;
our $RawOutput       = 0;
our $UseStdDeviation = 0;

Getopt::Long::Configure('bundling');
GetOptions(
  'h|help'           => \&usage,
  'p|precision=f'    => \$RelPrecision,
  'a|absprecision=f' => \$AbsPrecision,
  'v|verbose+'       => \$V,
  'i|initial=i'      => \$InitialTimings,
  'm|maxiter=i'      => \$MaxIter,
  'raw'              => \$RawOutput,
  's|std'            => \$UseStdDeviation,
);

if ($RawOutput) {
  $V = 0;
}

if ($RelPrecision <= 0 and $AbsPrecision <= 0) {
  die "Need either --precision (-p) or --absprecision (-a) set to positive value\n";
}
elsif ($InitialTimings < 6) {
  warn "Number of initial timings is VERY low. Result will be unreliable.\n";
}

@ARGV or usage();

my @CMD = @ARGV;



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

if (not $RawOutput) {
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

  # for overriding in case of dry-run mode
  local $V = $V;
  local $InitialTimings = $InitialTimings;
  local $AbsPrecision = $AbsPrecision;
  local $RelPrecision = $RelPrecision;
  local $MaxIter = $MaxIter;

  if ($dry) {
    $V--; $V = 0 if $V < 0;
    $InitialTimings *= 5;
    $AbsPrecision    = 0;
    $RelPrecision   /= 2;
    $MaxIter        *= 10;
  }

  my @timings;
  print "Running $InitialTimings initial timings...\n" if $V;
  foreach (1..$InitialTimings) {
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
    if ($RelPrecision > 0) {
      my $rel = $sigma/$mean;
      print "Reached relative precision $rel (neeed $RelPrecision).\n" if $V > 1;
      $need_iter++ if $rel > $RelPrecision;
    }
    if ($AbsPrecision > 0) {
      print "Reached absolute precision $sigma (neeed $AbsPrecision).\n" if $V > 1;
      $need_iter++ if $sigma > $AbsPrecision;
    }
    last if not $need_iter or @timings == $MaxIter;

    push @timings, ($dry ? run_dry($cmd) : run($cmd));
  }

  if (@timings == $MaxIter and not $dry) {
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
  if ($UseStdDeviation) {
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

