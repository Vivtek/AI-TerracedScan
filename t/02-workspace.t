#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Here we go.
use AI::TerracedScan;

# Test an initialization with only data units
my $ts = AI::TerracedScan->new ({init => <<"EOF"});
letter . a
letter . t
letter . o
letter . b
EOF

isa_ok ($ts, 'AI::TerracedScan');
my $ws = $ts->{workspace};
isa_ok ($ws, 'AI::TerracedScan::Workspace');
isa_ok ($ws->{units}, 'Data::Tab');

is_deeply ([ $ws->list_types() ], ['letter']);
is_deeply ([ sort $ws->list_ids() ], ['0', '1', '2', '3']);

my $su = $ws->get_unit ('1');
isa_ok ($su, 'AI::TerracedScan::SemUnit');
is ($su->get_data(), 't');

is ($ws->iterate_units()->select('id', 'type', 'desc')->table->show_decl, <<EOF);
id type   desc    
0  letter letter-0
1  letter letter-1
2  letter letter-2
3  letter letter-3
EOF

# Test an initialization with a containing unit whose frame contains only single values
$ts = AI::TerracedScan->new ({init => <<"EOF"});
letter ul1 a
letter ul2 b
letter ul3 c
letter-string ul . from ul1 to ul2
EOF

$ws = $ts->{workspace};
is_deeply ([ $ws->list_types() ], ['letter', 'letter-string']);
is_deeply ([ sort $ws->list_ids() ], ['ul', 'ul1', 'ul2', 'ul3']);

#diag "\n" . $ws->iterate_units()->select('id', 'type', 'desc')->table->show_decl;
#diag Dumper ($ws->get_unit ('ul'));

# Test an initialization with a containing unit whose frame has a multiple value
$ts = AI::TerracedScan->new ({init => <<"EOF"});
letter ul1 a
letter ul2 b
letter ul3 c
letter ul4 d
letter-string ul . l ul1 l ul2 l ul3
EOF

$ws = $ts->{workspace};
is_deeply ([ $ws->list_types() ], ['letter', 'letter-string']);
is_deeply ([ sort $ws->list_ids() ], ['ul', 'ul1', 'ul2', 'ul3', 'ul4']);

#diag "\n" . $ws->iterate_units()->select('id', 'type', 'desc')->table->show_decl;
#diag Dumper ($ws->get_unit ('ul'));
is_deeply ([ map { $_->get_id() } $ws->get_unit ('ul1')->list_in ], ['ul']);
is_deeply ([ map { $_->get_id() } $ws->get_unit ('ul1')->list_in($ws->get_unit('ul2')) ], ['ul']);
is_deeply ([ map { $_->get_id() } $ws->get_unit ('ul1')->list_in($ws->get_unit('ul4')) ], []);

# Now the same tests at the Workspace level
is_deeply ([ $ws->container ('ul1') ], ['ul']);
is_deeply ([ $ws->container ('ul1', 'ul2') ], ['ul']);
is_deeply ([ $ws->container ('ul1', 'ul4') ], []);

is_deeply ([ $ws->container_types ('ul1', 'ul2') ], ['letter-string']);

# Set up a subscriber that will save changes to a log structure
my $log = [];
$ws->subscribe (sub {
   my ($action, $id, $type, $unit) = @_;
   push @$log, [$action, $id, $type];
});

# Make a spark between two letters, kill and see that it no longer shows, then resurrect it and see that it reappears.
my $spark = $ws->add_link ('spark', {from=>'ul1', to=>'ul2'});
my @c = sort ($ws->container ('ul1', 'ul2'));
is_deeply (\@c, [$spark->get_id(), 'ul']);  # Our new spark gets a numeric ID, since we didn't specify any explicit ID, and thus sorts before 'ul'
#$spark->kill;
$ws->kill_unit ($spark->get_id);
@c = $ws->container ('ul1', 'ul2');
is_deeply (\@c, ['ul']);
#$spark->unkill;
$ws->unkill_unit ($spark->get_id);
@c = sort ($ws->container ('ul1', 'ul2'));
is_deeply (\@c, [$spark->get_id(), 'ul']);

# Promote the type of a unit to "special-letter"
$ws->promote_unit ('ul4', 'special-letter');
is ($ws->get_unit('ul4')->get_type, 'special-letter');

#diag Dumper ($log);
is_deeply ($log, [
  ['add', 0, 'spark'],
  ['kill', 0, 'spark'],
  ['unkill', 0, 'spark'],
  ['promote', 'ul4', 'special-letter'],
]);

done_testing();


