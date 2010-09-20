package Dumbbench::Result;
use strict;
use warnings;
use Carp ();

use Number::WithError;
use parent 'Number::WithError';

use Class::XSAccessor {
  getters => {
    nsamples => '_dbr_nsamples',
   },
};


sub new {
  my $proto = shift;
  my $class = ref($proto)||$proto;

  my $self;
  if (not grep {$_ eq 'timing'} @_) {
    push @_, 0 if @_ == 1;
    $self = $proto->SUPER::new(@_);
    $self->{_dbr_nsamples} = $proto->nsamples;
    return $self;
  }

  my %opt = @_;
  if (not defined $opt{timing} or not defined $opt{uncertainty}
      or not defined $opt{nsamples}) {
    Carp::croak("Need 'timing', 'uncertainty', and 'nsamples' parameters");
  }
  $self = $class->SUPER::new($opt{timing}, $opt{uncertainty});
  $self->{_dbr_nsamples} = $opt{nsamples};
  
  return $self;
}



  

1;
