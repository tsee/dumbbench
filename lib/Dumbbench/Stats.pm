package Dumbbench::Stats;
use strict;
use warnings;
use List::Util ();
use Statistics::CaseResampling ();

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw/data name/],
};

# Note: This is entirely unoptimized. There is a lot of unnecessary
#       stuff going on. This is to allow the user to modify the data
#       set in flight. If this comes back to haunt us at some point,
#       we can still optimize, but at this point, convenience still wins.

sub sorted_data {
  my $self = shift;
  my $sorted = [sort { $a <=> $b } @{$self->data}];
  return $sorted;
}

sub first_quartile { Statistics::CaseResampling::first_quartile($_[0]->data) }
sub second_quartile { return $_[0]->median }
sub third_quartile { Statistics::CaseResampling::third_quartile($_[0]->data) }


sub n { scalar(@{$_[0]->data}) }

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

sub median { Statistics::CaseResampling::median($_[0]->data) } # O(n)!

sub median_confidence_limits {
  my $self = shift;
  my $nsigma = shift;
  my $alpha = Statistics::CaseResampling::nsigma_to_alpha($nsigma);
  # note: The 1000 here is kind of a lower limit for reasonable accuracy.
  #       But if the data set is small, that's more significant. If the data
  #       set is VERY large, then running much more than 1k resamplings
  #       is VERY expensive. So 1k is probably a reasonable default.
  return Statistics::CaseResampling::median_simple_confidence_limits($self->data, 1-$alpha, 1000)
}

sub mad {
  my $self = shift;
  my $median = $self->median;
  my @val = map {abs($_ - $median)} @{$self->data};
  return ref($self)->new(data => \@val)->median;
}

sub mad_dev {
  my $self = shift;
  return $self->mad()*1.4826;
}

sub std_dev {
  my $self = shift;
  my $data = $self->data;
  my $mean = $self->mean;
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
