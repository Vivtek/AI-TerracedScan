#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

# Here we go.
use AI::TerracedScan::SemUnit;

# Create a new blank, anonymous unit with some payload data
my $su = AI::TerracedScan::SemUnit->new ('def', undef, undef, 'dummy data');
isa_ok ($su, 'AI::TerracedScan::SemUnit');
ok ($su->get_data() eq 'dummy data');
$su->set_data('different data');
ok ($su->get_data() eq 'different data');

# Create a new containing unit that holds that one
my $su2 = AI::TerracedScan::SemUnit->new ('def2', undef, { content => $su }, undef);
ok ($su2->get ('content') == $su);

# Create a new data node and add it to $su2
$su2->set ('content2', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#2 here'));
ok ($su2->get ('content2')->get_data() eq '#2 here');

# Exercise has_slot
ok ($su2->has_slot ('content2'));
ok (not $su2->has_slot ('list'));

# Create some new data nodes and add them to $su2 as a set value
$su2->add ('set', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#3 here'));
$su2->add ('set', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#4 here'));
$su2->add ('set', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#5 here'));
$su2->add ('set', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#6 here'));
$su2->add ('set', AI::TerracedScan::SemUnit->new ('def', undef, undef, '#7 here'));
#diag Dumper ($su2);
ok ($su2->has_slot ('set'));

my $list = $su2->get ('set');
ok (ref $list eq 'ARRAY');
ok (scalar @$list == 5);
isa_ok ($list->[0], 'AI::TerracedScan::SemUnit');
isa_ok ($list->[1], 'AI::TerracedScan::SemUnit');

my @data_list = sort map { $_->get_data(); } @$list; # Have to sort because the list order is undetermined
is_deeply (\@data_list, ['#3 here', '#4 here', '#5 here', '#6 here', '#7 here']);

ok ($list->[1]->is_in_slot ('set'));
is_deeply ($list->[1]->get_containers ('set'), [$su2]);

# Check set value deletion
$su2->del ('set', $list->[0]);
my $list2 = $su2->get ('set');
ok (scalar @$list2 == 4);

ok (not $list->[0]->is_in_slot ('set'));

# Check parent kill/resurrection
ok ($list->[1]->is_in_slot ('set'));
ok (scalar $list->[1]->list_in ());
$su2->kill;
ok (not $su2->is_live);
#ok (not $list->[1]->is_in_slot ('set')); -- the dead flag doesn't affect this level, which is kind of unavoidable but dangerous
ok (not scalar $list->[1]->list_in ());  # Here, the parent has been killed and so the list of containing units for any list item is *empty*.
my @dead = $list->[1]->list_in_dead ();
ok (scalar @dead);   # But the dead one's still there.
is ($dead[0], $su2); # And it's $su2.
$su2->unkill;
ok ($su2->is_live);
ok ($list->[1]->is_in_slot ('set'));
ok (scalar $list->[1]->list_in ());      # Now, the parent has been restored, and the contained unit again sees itself as contained.

# Exercise the IDs
ok (not defined $su2->get_id());
$su2->set_id ('id1');
ok ($su2->get_id() eq 'id1');


done_testing();
