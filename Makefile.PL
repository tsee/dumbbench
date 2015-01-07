use 5.0080005;
use strict;
use warnings;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $github    = 'https://github.com/briandfoy/';
my $main_file = 'lib/';

my %WriteMakefile = (
    NAME              => 'Dumbbench',
    VERSION_FROM      => 'lib/Dumbbench.pm', # finds $VERSION
    PREREQ_PM         => {
      'Number::WithError' => '1.00',
      'Class::XSAccessor' => '1.05',
      'Carp'              => '0',
      'Time::HiRes'       => '0',
      'Capture::Tiny'     => '0',
      'Params::Util'      => '0',
      'parent'            => '0',
      'Statistics::CaseResampling' => '0.06',
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Dumbbench.pm', # retrieve abstract from module
       AUTHOR         => 'Steffen Mueller <smueller@cpan.org>') : ()),
    EXE_FILES => ['bin/dumbbench'],
    META_MERGE => {
      no_index => {
        directory => [qw(t inc simulator xt)],
      },
    },
);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			//
		"$MM 6.64";
	eval "use $MM_version" || die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
