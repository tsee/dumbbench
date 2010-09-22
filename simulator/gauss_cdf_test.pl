use strict;
use warnings;
use Math::Complex ':pi';
use SOOT qw/:all/;

sub gauss {
  my ($mean, $var, $x) = @_;
  return (1./sqrt(2*pi()*$var))
         * exp(-($x-$mean)**2 / (2*$var));
}

sub gauss_cdf {
  my ($mean, $var, $x) = @_;

  # cdf from: Weisstein, Eric W. "Normal Distribution." From MathWorld--A Wolfram Web Resource. http://mathworld.wolfram.com/NormalDistribution.html 

  $x = ($x-$mean)/$var;

  my $y = $x/sqrt(2);

  # erf approximation:  ^ Winitzki, Sergei (6 February 2008). "A handy approximation for the error function and its inverse" (PDF). http://homepages.physik.uni-muenchen.de/~Winitzki/erf-approx.pdf. 
  use constant a => 8*(pi()-3)/(3*pi()*(4-pi()));
  my $ysq = $y*$y;
  my $erf = ($y/abs($y)) * sqrt(1. - exp( -$ysq * (4/pi() + a()*$ysq) / (1+a()*$ysq) ));

  return 0.5 * (1+$erf);
}


my $h = TH1D->new("t","t", 1000, -10., 10.);
my $h2 = TH1D->new("t2","t2", 1000, -10., 10.);

foreach my $i (1..1000) {
  my $c = $h->GetBinCenter($i);
  $h->SetBinContent($i, gauss(2., 1.5, $c));
  $h2->SetBinContent($i, gauss_cdf(2., 1.5, $c));
}

my $cv = TCanvas->new("c1");
$h->SetLineColor(kRed);
$h->Draw();
$h2->Draw("SAME");
$gApplication->Run();
