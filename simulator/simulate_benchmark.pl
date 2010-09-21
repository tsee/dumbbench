#!/usr/bin/perl
use strict;
use warnings;
use SOOT qw/:all/;
use Number::WithError 'witherror';
use Dumbbench;

$gRandom->SetSeed(rand()); # perl does this well enough

our $Runs = 200; # statistics

our $HistBins         = 10000; # histogramming options
our $HistMin          = -1.1e-5;
our $HistMax          = 5.1e-5;

our $ClockTick        = 1.e-7; # discretization options
our $WaitForTick      = 1; # bool

our $TrueTime         = 1.e-5; # true distribution center
our $GaussJitterSigma = 2.e-6;

our $OutlierFraction  = 0.1; # outlier distribution
our $OutlierOffset    = $TrueTime*1.2;
our $OutlierJitter    = $GaussJitterSigma * 4;

our $VariabilityMeasure = 'mad'; # analysis options
our $OutlierRejection   = 3.; # reject anything further away from median

# data storage
my $timings = [];


# Random number generators for the different distributions
our $OutlierDistribution = TF1->new("outliers", "gaus(0)", -10., 10.);
# we rescale manually due to the small numbers involved.
$OutlierDistribution->SetParameters(1., 0., 1.); # max, mean, sigma

our $DataDistribution = TF1->new("data", "gaus(0)", -10., 10.);
# we rescale manually due to the small numbers involved.
$DataDistribution->SetParameters(1., 0., 1.); # max, mean, sigma


sim_timing($timings) for 1..$Runs;

# Dumbbench data analysis
my $stats = Dumbbench::Stats->new(data => $timings);
my ($good, $outliers) = $stats->filter_outliers(
  variability_measure => $VariabilityMeasure,
  nsigma_outliers     => $OutlierRejection,
);

my $res_before = $stats->median;
my $err_before = $stats->$VariabilityMeasure() / sqrt(@{$timings});

my $good_stats = Dumbbench::Stats->new(data => $good);
my $res_after  = $good_stats->median;
my $err_after  = $good_stats->$VariabilityMeasure() / sqrt(@{$good});

print "before: " . witherror($res_before, $err_before) . "\n";
print "after:  " . witherror($res_after, $err_after) . "\n";
print "\n";

show_plots(
  $timings, $good, $outliers,
  $res_before, $err_before,
  $res_after, $err_after,
);


# simulates one run
sub sim_timing {
  my $timings = shift;

  # Simulate n levels of offsets with a probability of occurring $OutlierFraction^n
  my $offset = 0;
  while (rand() < $OutlierFraction) {
    $offset += $OutlierDistribution->GetRandom()*$OutlierJitter+$OutlierOffset;
  }
  
  # now add everything up to a result
  my $regular_time = $DataDistribution->GetRandom()*$GaussJitterSigma+$TrueTime; # rescale manuall
  my $time = $offset + $regular_time;

  # discretization
  # If we wait for a clock tick, it's the same as rounding
  # down the no. of clock ticks measured. That means, we
  # "lose" up to one clock tick of timing. 0.5 ticks on average.
  $time = int($time/$ClockTick)*$ClockTick;

  # If we don't wait, it's a bit more complicated than that.
  # We still get a time that does not include the fraction
  # into the last clock tick.
  # But we may overestimate the time by up to one clock tick due
  # to the start being somewhere half-way through the first tick
  # (and by definition, the time will be start-of-clock-tick until
  # the next tick). Thus we simply add a random time [0, ticklength).
  # That's probably useless: We might as well skip the discretization.
  $time += rand() * $ClockTick if not $WaitForTick;

  push @$timings, $time;
}


# This is just to create a pretty graph
sub show_plots {
  my ($timings, $good, $outliers,
      $res_before, $err_before,
      $res_after, $err_after) = @_;

  
  $gStyle->SetFrameFillColor(kWhite);
  $gStyle->SetPadColor(kWhite);
  $gStyle->SetCanvasColor(kWhite);
  $gStyle->SetFrameBorderMode(0);
  $gStyle->SetCanvasBorderMode(0);
  $gStyle->SetFillStyle(0);

  # display distributions
  my $hist = TH1D->new(
    "base_dist", "timing distribution MC",
    $HistBins, $HistMin, $HistMax
  );
  $hist->Fill($_) for @$timings;
  $hist->SetTitle("timing distribution MC;time [s];#");
  $hist->SetStats(kFALSE);

  my $good_hist = TH1D->new(
    "good_dist", "accepted",
    $HistBins, $HistMin, $HistMax
  );
  $good_hist->Fill($_) for @$good;
  $good_hist->SetLineColor(kRed);

  my $outlier_hist = TH1D->new(
    "outlier_dist", "rejected",
    $HistBins, $HistMin, $HistMax
  );
  $outlier_hist->Fill($_) for @$outliers;
  $outlier_hist->SetLineColor(kBlue);

  my $max_y = $hist->GetMaximum();
  my $before = TGraphErrors->new(1, [$res_before*1.0], [$max_y*0.5], [$err_before*1.0], [0.]);
  my $after  = TGraphErrors->new(1, [$res_after*1.0],  [$max_y*0.5], [$err_after*1.0],  [0.]);
  $before->SetTitle("Expect. Val (before)");
  $after->SetTitle("Expect. Val (after)");
  $before->SetMarkerColor(38);
  $before->SetLineColor(38);
  $after->SetMarkerColor(kCyan);
  $after->SetLineColor(kCyan);
  $_->SetMarkerStyle(21), $_->SetMarkerSize(0.8) for $before;
  $_->SetMarkerStyle(20), $_->SetMarkerSize(0.7) for $after;
  $_->SetFillColor(0), $_->SetFillStyle(0) for ($before, $after);
  
  my $cv = TCanvas->new("cv");
  $hist->Draw();
  $good_hist->Draw("SAME");
  $outlier_hist->Draw("SAME");
  
  $_->Draw("P") for ($before, $after);
  
  my $legend = $cv->BuildLegend();
  $legend->SetShadowColor(0);
  $legend->SetLineColor(0);
  $cv->Update();
  $gApplication->Run();
}
