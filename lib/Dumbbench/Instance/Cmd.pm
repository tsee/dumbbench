package Dumbbench::Instance::Cmd;
use strict;
use warnings;
use Carp ();
use Time::HiRes ();

use Dumbbench::Instance;
use parent 'Dumbbench::Instance';

use Class::XSAccessor {
  getters => [qw(
    command
    dry_run_command
  )],
};

sub clone {
  my $self = shift;
  my $clone = $self->SUPER::clone(@_);
  if (defined $self->command) {
    $clone->{command} = [@{$self->command}];
  }
  return $clone;
}

sub single_run {
  my $self = shift;

  my @cmd = (ref($self->{command}) ? @{$self->{command}} : ($self->{command}));
  @cmd = ("") if not @cmd;
  my $start = Time::HiRes::time();
  system({$cmd[0]} @cmd);
  my $end = Time::HiRes::time();

  my $duration = $end-$start;
  return $duration;
}

sub single_dry_run {
  my $self = shift;

  my @cmd;
  
  if (defined $self->{dry_run_command}) {
    @cmd = (ref($self->{dry_run_command}) ? @{$self->{dry_run_command}} : ($self->{dry_run_command}));
  }
  else {
    @cmd = (ref($self->{command}) ? @{$self->{command}} : ($self->{command}));
    if (@cmd and $cmd[0] =~ /(?:^|\b)perl(?:\d+\.\d+\.\d+)?/) {
      @cmd = ($cmd[0], '-e', '1');
    }
  }
  if (!@cmd) {
    #@cmd = ("");
    # FIXME For lack of a better dry run test, we always use perl for now
    @cmd = ($^W, qw(-e 1));
  }
  my $start = Time::HiRes::time();
  system({$cmd[0]} @cmd);
  my $end = Time::HiRes::time();

  my $duration = $end-$start;
  return $duration;
}
 

1;