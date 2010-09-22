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


sub sigma_truncated_gauss_variance {
  my ($mean, $var, $nsigma) = @_;
  my $sigma = sqrt($var);
  return truncated_gauss_variance($mean, $var, $mean-$nsigma*$sigma, $mean+$nsigma*$sigma);
}

sub truncated_gauss_variance {
  my ($mean, $var, $lower, $upper) = @_;
  
  #http://en.wikipedia.org/wiki/Truncated_normal_distribution
  my $sigma = sqrt($var);
  my $rlower = ($lower-$mean)/$sigma;
  my $rupper = ($upper-$mean)/$sigma;

  my $pdf_lower = gauss(0., 1., $rlower);
  my $pdf_upper = gauss(0., 1., $rupper);
  my $cdf_lower = gauss_cdf(0., 1., $rlower);
  my $cdf_upper = gauss_cdf(0., 1., $rupper);

  my $tr_var = $var * (
    1
    + ($rlower * $pdf_lower - $rupper * $pdf_upper) / ($cdf_upper - $cdf_lower)
    - ( ($pdf_lower-$pdf_upper) / ($cdf_upper-$cdf_lower) )**2
  );

  return $tr_var;
}

my $fun = TH1D->new("t3","t3", 1000, 0., 10.);

my $mean = 4.4;
my $sigma = 0.4;
my $var = $sigma**2;

foreach my $nsigmahalf (1..20) {
  my $nsigma = $nsigmahalf/2;
  print "$nsigma: " . sqrt(sigma_truncated_gauss_variance($mean, $var, $nsigma)) .  "\n";
}
foreach my $i (1..1000) {
  my $c = $fun->GetBinCenter($i);
  $fun->SetBinContent($i, sqrt(sigma_truncated_gauss_variance($mean, $var, $c)));
}

my $cv2 = TCanvas->new("c2");
$fun->Draw();


#my $trunc_sigma = 0.215;
#sub find_true_sigma {
#  my ($mean, $trunc_sigma, $nsigma) = @_;
#
#  my $trunc_var = $trunc_sigma**2;
#  # trunc_sigma <= sigma
#  my $var = $trunc_var;
#  while (1) {
#    my $tguess = sigma_truncated_gauss_variance($mean, $var, $nsigma);
#    $var*=1.01;
#    if ($tguess > $trunc_var)
#  }
#}
#print "TRUE=".find_true_sigma(4.4, $trunc_sigma, 1.)."\n",

$gApplication->Run();
