use 5.0080005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
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
      'Devel::CheckOS'    => '0',
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
