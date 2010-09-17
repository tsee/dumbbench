package Dumbbench::Stats;
use strict;
use warnings;
use List::Util 'sum';

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw/data/],
};

sub mean {
  my $self = shift;
  my $data = $self->data;
  return sum(@$data) / @$data;
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


1;