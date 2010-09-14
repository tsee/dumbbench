package Dumbbench::Instance;
use strict;
use warnings;
use Carp ();

require Dumbbench::Instance::Cmd;

use Class::XSAccessor {
  constructor => 'new',
  accessors => [qw(
    dry_result
    result
  )],
  getters => [qw(timings)],
};

sub clone {
  my $self = shift;
  my $clone = bless({%$self} => ref($self));
  
  if (defined $clone->dry_result) {
    $clone->dry_result($clone->dry_result->new);
  }
  if (defined $clone->result) {
    $clone->result($clone->result->new);
  }
  return $clone;
}

sub single_dry_run {
  my $self = shift;
  Carp::croak("Can't single_dry_run Dumbbench::Instance: Choose a subclass that implements dry-running.");
}

sub single_run {
  my $self = shift;
  Carp::croak("Can't single_run Dumbbench::Instance: Choose a subclass that implements running.");
}

1;