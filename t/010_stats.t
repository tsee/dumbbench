use strict;
use warnings;
use Test::More tests => 15;
use Dumbbench;
use Dumbbench::Stats;

my $data = [1..5];
my $s = Dumbbench::Stats->new(data => $data);

isa_ok($s, 'Dumbbench::Stats');
is_deeply($s->data, $data);

is_approx($s->mean, 3);
is_approx($s->median, 3);

push @$data, 12;
is_approx($s->mean, (1+2+3+4+5+12)/6);
is_approx($s->median, 3.5);

my $mean = $s->mean;
my $variance = 0;
$variance += ($_-$mean)**2 for @$data;
$variance /= @$data-1;
my $std_dev = sqrt($variance);
is_approx($s->std_dev, $std_dev);

my $median = $s->median;
my @dev = map {abs($_-$median)} @$data;
my $mad = Dumbbench::Stats->new(data=>\@dev)->median;
is_approx($s->mad, $mad);
is_approx($s->mad_dev, $mad*1.4826);


SKIP: {
  eval "use SOOT qw/:all/;";
  skip "Skipping extra tests since SOOT is not available", 1 if $@;
  my $fun = TF1->new("g","gaus(0)");
  $fun->SetParameters(1., 20., 5.);
  my $hist = TH1D->new("gaus", "", 1000, 0, 100);
  $hist->FillRandom("g", 1e5);
  #$hist->Draw();
  #$SOOT::gApplication->Run();
  
  my @d;
  foreach (1..1e4) {
    push @d, $hist->GetRandom();
  }
  
  my $s = Dumbbench::Stats->new(data => \@d);
  is_approx($s->mean, 20, 0.1);
  is_approx($s->median, 20, 0.1);
  is_approx($s->std_dev, 5, 0.2);
  is_approx($s->mad_dev, 5, 0.2);

  push @d, 100, 120, 130, 1000, 200;
  is_approx($s->mad_dev, 5, 0.2);
  my $sd = $s->std_dev;
  ok(not($sd+0.2 > 5 and $sd-0.2 < 5));
}



sub is_approx {
  my $d = $_[2] || 1.e-9;
  ok($_[0]+$d > $_[1] && $_[0]-$d < $_[1]);
}