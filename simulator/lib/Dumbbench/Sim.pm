package Dumbbench::Sim;
use strict;
use warnings;
use Dumbbench;
use Carp 'croak';
require Dumbbench::Sim::Config;

use SOOT qw/:all/;
use Number::WithError 'witherror';

use Class::XSAccessor {
  constructor => 'new',
  accessors   => [qw(
    config
    stats
    stats_good
    stats_outliers
    outlier_distribution
    data_distribution
    ev_before
    ev_after
    iterations_per_run
  )],
};

sub from_yaml {
  my $class = shift;
  my $file = shift;

  my $self = $class->new(
    config => Dumbbench::Sim::Config->from_yaml($file)
  );
  return $self;
}


sub run {
  my $self = shift;
  my $runs = shift || 200;
  my $cfg = $self->config;
  my $timings = [];
  $self->stats(Dumbbench::Stats->new(data => $timings));

  # Random number generators for the different distributions
  # we rescale manually due to the small numbers involved.
  if (not $self->outlier_distribution) {
    $self->outlier_distribution(
      TF1->new("outliers", "gaus(0)", -10., 10.)
    );
    $self->outlier_distribution->SetParameters(1., 0., 1.); # max, mean, sigma
  }

  if (not $self->data_distribution) {
    $self->data_distribution(
      TF1->new("data", "gaus(0)", -10., 10.)
    );
    $self->data_distribution->SetParameters(1., 0., 1.); # max, mean, sigma
  }

  $self->_sim_single_timing(setup => 1);
  $self->_sim_single_timing for 1..$runs;

  # Dumbbench data analysis
  my $stats = $self->stats;
  my ($good, $outliers) = $stats->filter_outliers(
    variability_measure => $cfg->variability_measure,
    nsigma_outliers     => $cfg->outlier_rejection,
  );

  my $variability_measure = $cfg->variability_measure;
  my $res_before = $stats->median;
  my $err_before = $stats->$variability_measure() / sqrt(@{$timings});
  $self->ev_before(witherror($res_before, $err_before));

  my $good_stats = Dumbbench::Stats->new(data => $good);
  $self->stats_good($good_stats);
  $self->stats_outliers(Dumbbench::Stats->new(data => $outliers));


  my $res_after  = $good_stats->median;
  my $err_after  = $good_stats->$variability_measure() / sqrt(@{$good});
  $self->ev_after(witherror($res_after, $err_after));

  print "before: " . $self->ev_before . "\n";
  print "after:  " . $self->ev_after . "\n";
  print "\n";
}




# simulates one run
sub _sim_single_timing {
  my $self = shift;
  my %opts = @_;
  my $cfg = $self->config;

  # The logic behind $opts{setup}, the while(1) loop and $n is that Dumbbench will
  # first run a training run of your benchmark. If the run time is below some value
  # (currently 1.e-4), then it puts a loop around your code and keeps doubling
  # the loop count until the total time is above the limit.
  # THEN, it keeps that N fixed for the real iterations. Here, $opts{setup} indicates
  # the test run.

  my $time = 0;
  my $n = 1;
  my $iloop = 0;
  while (1) {
    # Simulate n levels of offsets with a probability of occurring $outlier_fraction^n
    my $offset = 0;
    while (rand() < $cfg->outlier_fraction) {
      $offset += $self->outlier_distribution->GetRandom()
                 * $cfg->outlier_jitter + $cfg->outlier_offset;
    }

    # now add everything up to a result
    my $regular_time = $self->data_distribution->GetRandom()
                       * $cfg->gauss_jitter_sigma + $cfg->true_time; # rescale manually
    $time += $offset + $regular_time;
    $iloop++;

    # end condition
    if ($iloop == $n) {
      # increase $n until we're above the limit
      if ($opts{setup}) {
        $n *= 2, next if $time < $cfg->duration_lower_limit;
      }
      last;
    }
  }

  # save the required no. of iterations for the actual runs
  $self->iterations_per_run($n) if $opts{setup};

  # discretization
  # If we wait for a clock tick, it's the same as rounding
  # down the no. of clock ticks measured. That means, we
  # "lose" up to one clock tick of timing. 0.5 ticks on average.
  my $ctick = $cfg->clock_tick;
  $time = int($time/$ctick)*$ctick;

  # If we don't wait, it's a bit more complicated than that.
  # We still get a time that does not include the fraction
  # into the last clock tick.
  # But we may overestimate the time by up to one clock tick due
  # to the start being somewhere half-way through the first tick
  # (and by definition, the time will be start-of-clock-tick until
  # the next tick). Thus we simply add a random time [0, ticklength).
  # That's probably useless: We might as well skip the discretization.
  $time += rand() * $ctick if not $cfg->wait_for_tick;

  push @{$self->stats->data}, $time/$n if not $opts{setup};
}



# This is just to create a pretty graph
sub show_plots {
  my $self = shift;
  my $cfg = $self->config;

  $gStyle->SetFrameFillColor(kWhite);
  $gStyle->SetPadColor(kWhite);
  $gStyle->SetCanvasColor(kWhite);
  $gStyle->SetFrameBorderMode(0);
  $gStyle->SetCanvasBorderMode(0);
  $gStyle->SetFillStyle(0);

  # display distributions
  my $hist = TH1D->new(
    "base_dist", "timing distribution MC",
    $cfg->hist_bins+0., $cfg->hist_min+0., $cfg->hist_max+0.
  );
  $hist->Fill($_) for @{$self->stats->data};
  $hist->SetTitle("timing distribution MC;time [s];#");
  $hist->SetStats(kFALSE);

  my $good_hist = TH1D->new(
    "good_dist", "accepted",
    $cfg->hist_bins+0., $cfg->hist_min+0., $cfg->hist_max+0.
  );
  $good_hist->Fill($_) for @{$self->stats_good->data};
  $good_hist->SetLineColor(kRed);

  my $outlier_hist = TH1D->new(
    "outlier_dist", "rejected",
    $cfg->hist_bins+0., $cfg->hist_min+0., $cfg->hist_max+0.
  );
  $outlier_hist->Fill($_) for @{$self->stats_outliers->data};
  $outlier_hist->SetLineColor(kBlue);

  my $res_before = $self->ev_before->raw_number;
  my $err_before = $self->ev_before->raw_error->[0];
  my $res_after  = $self->ev_after->raw_number;
  my $err_after  = $self->ev_after->raw_error->[0];

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


1;
