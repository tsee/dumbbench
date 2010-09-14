package Dumbbench::Result;
use strict;
use warnings;
use Carp ();

use Number::WithError;
use parent 'Number::WithError';

use Class::XSAccessor;


sub new {
  my $proto = shift;
  my $class = ref($proto)||$proto;
  my %opt = @_;
  my $self;
  if (not ref($proto) or defined $opt{timing} && defined $opt{uncertainty}) {
    if (not defined $opt{timing} or not defined $opt{uncertainty}) {
      Carp::croak("Need 'timing' and 'uncertainty' parameters");
    }
    $self = $class->SUPER::new($opt{timing}, $opt{uncertainty});
  }
  else {
    $self = $proto->SUPER::new();
  }
  
  return $self;
}



  

1;