use strict;
use warnings;
use Test::More tests => 27;
use Benchmark::Dumb qw/:all/;
use Capture::Tiny qw/capture/;

my $obj;
my ($stdout, $stderr) = capture {
  $obj = timeit(1, 'for(1..1e1){}');
};
ok($stdout eq '', 'timeit has no output');
ok($stderr =~ /Precision will be off/, "low count warns about precision");

isa_ok($obj, 'Benchmark::Dumb');
can_ok($obj, 'timesum');
can_ok($obj, 'timediff');
can_ok($obj, 'timestr');
can_ok($obj, 'name');

ok($obj->timestr =~ /wallclock/); # err, yeah. Need a better test

# don't do this at home.
my $first = $obj->_new(
  result => $obj->_result->new(timing => 5, uncertainty => 2, nsamples => 2),
  name => 'first',
);
my $second = $obj->_new(
  result => $obj->_result->new(timing => 3, uncertainty => 1, nsamples => 2),
  name => 'second',
);

my $diff = $first->timediff($second);
isa_ok($diff, 'Benchmark::Dumb');

cmp_ok($diff->_result->number, '<=', 2 + 1.e-9);
cmp_ok($diff->_result->number, '>=', 2 - 1.e-9);

cmp_ok($diff->_result->raw_error->[0], '<=', sqrt(5) + 1.e-6);
cmp_ok($diff->_result->raw_error->[0], '>=', sqrt(5) - 1.e-6);

my $sum = $first->timesum($second);
isa_ok($sum, 'Benchmark::Dumb');

cmp_ok($sum->_result->number, '<=', 8 + 1.e-9);
cmp_ok($sum->_result->number, '>=', 8 - 1.e-9);

cmp_ok($sum->_result->raw_error->[0], '<=', sqrt(5) + 1.e-6);
cmp_ok($sum->_result->raw_error->[0], '>=', sqrt(5) - 1.e-6);


($stdout, $stderr) = capture {
  $obj = timethis(1, 'for(1..1e1){}');
};
ok($stdout =~ /wallclock/, "timethis prints a timestr");
ok($stderr =~ /Precision will be off/, "low count warns about precision");

my $hashr;
($stdout, $stderr) = capture {
  $hashr = timethese(1, { foo => 'for(1..1e1){}', bar => sub {for(1..1e1){}} } );
};

my $n_wallclock_mentions =()= $stdout =~ /wallclock/g;
is($n_wallclock_mentions, 2, "two benchmarks run");
ok($stdout =~ /Benchmark.*bar.*foo/);
ok($stderr =~ /Precision will be off/);

ok(ref($hashr) && ref($hashr) eq 'HASH', "returns hashref");
is(scalar(keys %$hashr), 2, "two results");

foreach my $r (qw(foo bar)) {
  isa_ok($hashr->{$r}, 'Benchmark::Dumb');
}

