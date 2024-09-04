#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Here we go.
use AI::TerracedScan;
use AI::TerracedScan::Framelet;

my $ts = AI::TerracedScan->new ({init => <<"EOF"});
letter ul1 a
letter ul2 b
letter ul3 c
letter-string ul . from ul1 to ul2
EOF

my $ws = $ts->{workspace};
is_deeply ([ $ws->list_types() ], ['letter', 'letter-string']);
is_deeply ([ sort $ws->list_ids() ], ['ul', 'ul1', 'ul2', 'ul3']);

# Make a frame and put some of our units into it.
my $f = AI::TerracedScan::Framelet->new($ws);
$f->add_unit ('ul', 'string');
$f->add_unit ('ul2');
is_deeply ([ sort $f->list_types() ], ['letter', 'letter-string']);
is_deeply ([ sort $f->list_ids() ], ['ul', 'ul2']);
is_deeply ([ $f->get_ids ('string') ], ['ul']);
is_deeply ([ $f->get ('string') ], [$ws->get_unit ('ul')]);

is ($f->get_one_id ('string'), 'ul');
is ($f->get_one ('string'), $ws->get_unit ('ul'));

is_deeply ([ $f->list_ids ('letter') ], ['ul2']);

is ($f->count(), 2);
is ($f->count('letter'), 1);

# Make a neighborhood frame
$f = $ws->get_neighborhood ('ul1');
is_deeply ([ sort $f->list_ids() ], ['ul', 'ul1', 'ul2']);
is_deeply ([ sort $f->list_types() ], ['letter', 'letter-string']);
is ($f->count(), 3);
is ($f->count('letter'), 2);

done_testing();


