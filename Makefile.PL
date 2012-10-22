use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::Phlo',
    AUTHOR              => q{Arnaud (Arhuman) Assad <arhuman@gmail.com>},
    VERSION_FROM        => 'lib/App/Phlo.pm',
    ABSTRACT_FROM       => 'lib/App/Phlo.pm',
    EXE_FILES           => [ 'bin/phlo' ],
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Carp' => 0,
        'Digest' => 0,
        'Digest::CRC' => 0,
        'Digest::SHA1' => 0,
        'Path::Class' => 0,
        'File::Copy' => 0,
        'File::Temp' => 0,
    },
    META_MERGE => {
        # recommends => {
        #             'LWP::UserAgent' => 0,
        # },
        resources => { 
                        repository => 'https://github.com/arhuman/App-Phlo',
                        bugtracker => 'https://github.com/arhuman/App-Phlo/issues'
        },
    },
    # BUILD_REQUIRES => { 'Test::Exception' => 0, },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-Phlo-*' },
);
