use strict;
use warnings;
use Test::More tests => 7;
use Benchmark::Dumb qw/:all/;
use Capture::Tiny qw/capture/;

my $obj;
my ($stdout, $stderr) = capture {
  $obj = timeit(1, 'for(1..1e1){}');
};
ok($stderr =~ /Precision will be off/);

isa_ok($obj, 'Benchmark::Dumb');
can_ok($obj, 'timesum');
can_ok($obj, 'timediff');
can_ok($obj, 'timestr');
can_ok($obj, 'name');

ok($obj->timestr =~ /wallclock/); # err, yeah. Need a better test

