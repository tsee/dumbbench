package Dumbbench::Stats;
use strict;
use warnings;
use List::Util ();

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw/data name/],
};

# note: This is entirely unoptimized. There is a lot of unnecessary
#       sorting going on. This is to allow the user to modify the data
#       set in flight. If this comes back to haunt us at some point,
#       we can still optimize.

sub sorted_data {
  my $self = shift;
  my $sorted = [sort { $a <=> $b } @{$self->data}];
  return $sorted;
}

sub first_quartile {
  my $self = shift;
  my @data = sort { $a <=> $b } @{$self->data}; # would be much faster to cache the order...
  # inlined median to avoid really silly re-sorting.
  return() if not @data;

  my $n = @data;
  splice(@data, int($n/2));
  #splice(@data, 0, int($n/2));
  $n = @data;
  if ($n % 2) { # odd
    return $data[int($n/2)];
  }
  else {
    my $half = $n/2;
    return 0.5*($data[$half]+$data[$half-1]);
  }
}

sub second_quartile { return $_[0]->median }

sub third_quartile {
  my $self = shift;
  my @data = sort { $a <=> $b } @{$self->data}; # would be much faster to cache the order...
  # inlined median to avoid really silly re-sorting.
  return() if not @data;

  my $n = @data;
  #splice(@data, int($n/2));
  splice(@data, 0, int($n/2));
  $n = @data;
  if ($n % 2) { # odd
    return $data[int($n/2)];
  }
  else {
    my $half = $n/2;
    return 0.5*($data[$half]+$data[$half-1]);
  }
}

sub n {
  return scalar(@{$_[0]->data});
}

sub sum {
  my $self = shift;
  return List::Util::sum(@{$self->data});
}

sub min {
  my $self = shift;
  return List::Util::min(@{$self->data});
}

sub max {
  my $self = shift;
  return List::Util::max(@{$self->data});
}

sub mean {
  my $self = shift;
  return $self->sum / $self->n;
}

sub median {
  my $self = shift;
  my @data = sort { $a <=> $b } @{$self->data}; # would be much faster to cache the order...
  #@$data = sort { $a <=> $b } @$data;
  return() if not @data;
  my $n = @data;
  if ($n % 2) { # odd
    return $data[int($n/2)];
  }
  else {
    my $half = $n/2;
    return 0.5*($data[$half]+$data[$half-1]);
  }
}

sub mad {
  my $self = shift;
  my $median = $self->median;
  my @val = map {abs($_ - $median)} @{$self->data};
  return ref($self)->new(data => \@val)->median();
}

sub mad_dev {
  my $self = shift;
  return $self->mad()*1.4826;
}

sub std_dev {
  my $self = shift;
  my $data = $self->data;
  my $mean = $self->mean();
  my $var = 0;
  $var += ($_-$mean)**2 for @$data;
  $var /= @$data - 1;
  return sqrt($var);
}

sub filter_outliers {
  my $self = shift;
  my %opt = @_;
  my $var_measure = $opt{variability_measure} || 'mad';
  my $n_sigma = $opt{nsigma_outliers} || 2.5;
  my $data = $self->data;

  if ($n_sigma == 0) {
    return([@$data], []); # special case: no filtering
  }

  my $median = $self->median;
  my $variability = $self->$var_measure;
  my @good;
  my @outliers;
  foreach my $x (@$data) {
    if (abs($x-$median) < $variability*$n_sigma) {
      push @good, $x;
    }
    else {
      push @outliers, $x;
    }
  }

  return(\@good, \@outliers);
}


1;
