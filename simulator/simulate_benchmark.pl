#!/usr/bin/perl
use strict;
use warnings;
use SOOT;
use Number::WithError 'witherror';
use FindBin '$Bin';
use File::Spec;

use lib 'lib';
use lib File::Spec->catdir($Bin, 'lib');

use Dumbbench;
use Dumbbench::Sim;

$SOOT::gRandom->SetSeed(rand()); # perl does this well enough

my $cfg_file = shift;
my $runs = shift || 200;

my $sim = Dumbbench::Sim->from_yaml($cfg_file);

$sim->run($runs);

$sim->show_plots;
