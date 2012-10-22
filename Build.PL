use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::Phlo',
    license             => 'perl',
    dist_author         => q{Arnaud (Arhuman) Assad <arhuman@gmail.com>},
    dist_version_from   => 'lib/App/Phlo.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'App-Phlo-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
