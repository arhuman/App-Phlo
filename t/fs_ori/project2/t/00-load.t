#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::Phlo' ) || print "Bail out!\n";
}

diag( "Testing App::Phlo $App::Phlo::VERSION, Perl $], $^X" );
