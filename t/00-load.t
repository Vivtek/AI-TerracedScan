#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'AI::TerracedScan' ) || print "Bail out!\n";
    use_ok( 'AI::TerracedScan::SemUnit' ) || print "Bail out!\n";
    use_ok( 'AI::TerracedScan::Workspace' ) || print "Bail out!\n";
}

diag( "Testing AI::TerracedScan $AI::TerracedScan::VERSION, Perl $], $^X" );
