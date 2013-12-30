package Dumbbench::CPUFrequencyPinner;
use strict;
use warnings;

use Devel::CheckOS qw(os_is);
use constant OS_SUPPORTED => os_is('Linux');

sub new {
  my $class = shift;

  my $self = bless(
    {
      ncpus => undef,
      base_path => '/sys/devices/system/cpu',
      @_
    } => $class
  );

  $self->_min_max_frequencies;

  return $self;
}

sub supported {
  return OS_SUPPORTED;
}

sub ncpus {
  my $self = shift;
  die "OS not supported!" if not OS_SUPPORTED;
  return $self->{ncpus} if $self->{ncpus};

  my $list = `ls -1 $self->{base_path}`;
  chomp $list;
  my $count = scalar( grep /\bcpu[0-9]+$/, split /\n/, $list );
  $self->{ncpus} = $count;

  return $count;
}

sub _min_max_frequencies {
  my $self = shift;
  return if not OS_SUPPORTED;

  my $ncpus = $self->ncpus;

  my (@min_freq, @max_freq);
  $self->{min_frequencies} = \@min_freq;
  $self->{max_frequencies} = \@max_freq;
  foreach my $i (0..$ncpus-1) {
    my ($file, $fh, $freq);

    $file = "$self->{base_path}/cpu$i/cpufreq/scaling_min_freq";
    open $fh, "<", $file
      or die "Failed to open '$file' for reading: $!";
    $freq = <$fh>;
    chomp $freq;
    close $fh;
    push @min_freq, 0+$freq;

    $file = "$self->{base_path}/cpu$i/cpufreq/scaling_max_freq";
    open $fh, "<", $file
      or die "Failed to open '$file' for reading: $!";
    $freq = <$fh>;
    chomp $freq;
    close $fh;
    push @max_freq, 0+$freq;
  }

  $self->{orig_min_frequencies} = [@min_freq];
  $self->{orig_max_frequencies} = [@max_freq];
}

sub min_frequencies { $_[0]->{min_frequencies} }
sub max_frequencies { $_[0]->{max_frequencies} }

sub set_min_frequencies {
  my ($self, $freq) = @_;
  die "OS not supported!" if not OS_SUPPORTED;

  my $min_freq = $self->min_frequencies;

  foreach my $i (0..$#{$min_freq}) {
    if ($freq != $min_freq->[$i]) {
      system("sudo sh -c \"echo $freq > $self->{base_path}/cpu$i/cpufreq/scaling_min_freq\"");
      $min_freq->[$i] = $freq;
    }
  }
}

sub set_max_frequencies {
  my ($self, $freq) = @_;
  die "OS not supported!" if not OS_SUPPORTED;

  my $max_freq = $self->max_frequencies;

  foreach my $i (0..$#{$max_freq}) {
    if ($freq != $max_freq->[$i]) {
      system("sudo sh -c \"echo $freq > $self->{base_path}/cpu$i/cpufreq/scaling_max_freq\"");
      $max_freq->[$i] = $freq;
    }
  }
}

sub reset_frequencies {
  my ($self) = @_;
  die "OS not supported!" if not OS_SUPPORTED;

  my $min_freq = $self->min_frequencies;
  my $max_freq = $self->max_frequencies;

  my $orig_min_freq = $self->{orig_min_frequencies};
  my $orig_max_freq = $self->{orig_max_frequencies};

  foreach my $i (0..$#{$max_freq}) {
    if ($orig_max_freq->[$i] != $max_freq->[$i]) {
      my $freq = $orig_max_freq->[$i];
      system("sudo sh -c \"echo $freq > $self->{base_path}/cpu$i/cpufreq/scaling_max_freq\"");
      $max_freq->[$i] = $freq;
    }
  }

  foreach my $i (0..$#{$min_freq}) {
    if ($orig_min_freq->[$i] != $min_freq->[$i]) {
      my $freq = $orig_min_freq->[$i];
      system("sudo sh -c \"echo $freq > $self->{base_path}/cpu$i/cpufreq/scaling_min_freq\"");
      $min_freq->[$i] = $freq;
    }
  }
}

sub DESTROY {
  my ($self) = @_;
  return if not OS_SUPPORTED;
  $self->reset_frequencies;
}

1;
