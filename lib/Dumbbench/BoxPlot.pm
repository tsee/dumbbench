package Dumbbench::BoxPlot;
use strict;
use warnings;
use List::Util qw/min max sum/;
require Dumbbench;
use SOOT qw/:all/;

use Class::XSAccessor {
  getters => [qw/bench/],
};

# Yes, this is obscure.

sub new {
  my $class = shift;
  my $self = bless {
    bench => shift,
  } => $class;

  $gStyle->SetFrameFillColor(kWhite);
  $gStyle->SetPadColor(kWhite);
  $gStyle->SetCanvasColor(kWhite);
  $gStyle->SetFrameBorderMode(0);
  $gStyle->SetCanvasBorderMode(0);
  $gStyle->SetFillStyle(0);

  return $self;
}

sub show {
  my $self = shift;

  my @data;
  foreach my $instance ($self->bench->instances) {
    my $st = Dumbbench::Stats->new(
      data => $instance->timings,
      name => $instance->name,
    );
    push @data, $st;
  }

  my $keep = $self->_box_n_whisker(\@data);
  $gApplication->Run();
}

sub _box_n_whisker {
  my $self = shift;
  my $data = shift;
  my @names;
  $names[$_] = $data->[$_]->name || "set ".($_+1) for 0..$#$data;
  
  my $npop = @$data;
  my $min = min(map $_->min, @$data);
  my $max = max(map $_->max, @$data);
  my $range = $max-$min;

  my @obj;

  my $cv = TCanvas->new("box_plot");

  #$cv->SetStatistics(0);
  my $bg = TH1D->new("bg", "", $npop, 0.5, $npop+0.5)->keep;
  $bg->SetStats(kFALSE);
  $bg->GetYaxis()->SetRangeUser($min-$range*.05, $max+$range*.05);
  $bg->SetTitle(";;Time [s]");
  $bg->Fill($names[$_], 0.) for 0..$#names;
  $bg->Draw();

  push @obj, $cv, $bg;

  my $x_coord = 1.;
  my $dx = 0.07;
  foreach my $pop (@$data) {
    my $n = $pop->n;
    my $median = $pop->median;
    my $q1 = $pop->first_quartile;
    my $q3 = $pop->third_quartile;
    my ($wlow, $whigh) = find_whiskers($pop, $q1, $q3);
    my $x = $x_coord + 1.e-20;
    #print "$x $median $wlow $whigh\n";
    my $g = TGraphAsymmErrors->new(1, [$x], [$median*1.], [0.], [0.], [abs($median-$wlow)*1.], [abs($median-$whigh)*1.])->keep;
    $g->Draw("l");
    my $box = TGraphAsymmErrors->new(1, [$x], [$median*1.], [$dx], [$dx], [abs($q1-$median)*1.], [abs($q3-$median)*1.])->keep;
    $box->SetFillStyle(1001);
    $box->SetFillColor(17);
    $box->SetMarkerStyle(kBlue);
    $box->SetMarkerColor(1);
    $box->SetMarkerStyle(20);
    $box->SetMarkerSize(0.7);
    $box->Draw("2p");
    #$box->Draw("p");
    my @outliers = grep {$_ < $wlow or $_ > $whigh} @{$pop->data};
    $outliers[0] += 1.e-20;
    my $noutl = scalar(@outliers);
    my $outl = TGraph->new($noutl, [($x) x $noutl], \@outliers)->keep;
    $outl->SetMarkerColor(1);
    $outl->SetMarkerStyle(5);
    $outl->SetMarkerSize(0.7);
    $outl->Draw("p");

    push @obj, $g, $box, $outl;
    $x_coord++;
  }
  $cv->Update();
  return \@obj;
}

sub find_whiskers {
  my $pop = shift;
  my $q1 = shift;
  my $q3 = shift;
  my $iqr = abs($q3-$q1);
  my $lower_limit = $q1-$iqr*1.5;
  my $upper_limit = $q3+$iqr*1.5;
  my $sorted = $pop->sorted_data;

  my $low  = min(grep {$_ >= $lower_limit} @{$pop->data});
  my $high = max(grep {$_ <= $upper_limit} @{$pop->data});

  return($low, $high);
}

1;
