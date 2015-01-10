use 5.0080005;
use strict;
use warnings;

use File::Spec::Functions qw(catfile);

my $module    = 'Dumbbench';
( my $dist = $module ) =~ s/::/-/g;

my $github    = 'https://github.com/briandfoy/dumbbench';
my $main_file = catfile( 'lib', split /::/, "$module.pm" );

my %WriteMakefile = (
	'NAME'	        => $module,
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'Steffen Mueller <smueller@cpan.org>',

    'EXE_FILES' => ['bin/dumbbench'],

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker'   => '6.64',
		'File::Spec::Functions' => '0',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '0.94',
		},

	'PREREQ_PM'     => {
		'Number::WithError' => '1.00',
		'Class::XSAccessor' => '1.05',
		'Carp'              => '0',
		'Time::HiRes'       => '0',
		'Capture::Tiny'     => '0',
		'Params::Util'      => '0',
		'parent'            => '0',
		'Statistics::CaseResampling' => '0.06',
		},

	'META_MERGE' => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => "$github.git",
				web  => $github,
				},
			bugtraker => {
				web    => "$github/issues",
				},
			homepage => $github,
			},
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
			||
		"$MM 6.64";
	eval "use $MM_version; 1" or die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
