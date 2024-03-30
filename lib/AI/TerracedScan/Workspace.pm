package AI::TerracedScan::Workspace;

use 5.006;
use strict;
use warnings;

use Data::Tab;
use AI::TerracedScan::SemUnit;
use Carp;
use List::Util qw(uniq);
use Data::Dumper;

=head1 NAME

AI::TerracedScan::Workspace - Implements a network of semantic units for use in a terraced scan

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

The short-term memory of a terraced scan is called a workspace, and it's basically just a pile of semantic units, each of which is a slot-and-filler Minsky frame.
The values of the fillers are other units, resulting in a tangled network of units.

For now I'm drawing a sharp line between "data" units, perceptual units that relate to some aspect of the input information, and "link" units, which are everything
else that we build ourselves (but some of which can also be provided as initial input if that structure is already available). A link unit has slots that point to
other units, but no data; a data unit has a data item but no slots and fillers.

=head1 CREATING THE WORKSPACE

=head2 new (definition)

I'm not even sure yet what parameters a Workspace will have, aside from its definition, which is still unspecified.

=cut

sub new {
   my ($class, $definition) = @_;
   my $self = bless ({}, $class);
   $self->{defn} = $definition;
   $self->{units} = Data::Tab->new ([], headers => ['id', 'type', 'unit'], hashkey => 'id', primary => 'unit');
   $self->{top_id} = 0;
   $self->{subscribers} = [];
   $self;
}

=head2 load_iterator (iterator)

Loads a Workspace from an iterator that returns semunits, or rather, returns C<[type, id, data, frame]>, where C<frame> is a hashref of named slots containing the
IDs of units already appearing in the Workspace. (If not, it's an error.)

=cut

sub load_iterator {
   my ($self, $iterator) = @_;
   
   my $it = $iterator->iter;
   while (my $row = $it->()) {
      my ($type, $id, $data, $frame) = @$row;
      if (defined $data) {
         if (defined $id) {
            $self->add_data_by_id ($id, $type, $data);
         } else {
            $self->add_data ($type, $data);
         }
      } else {
         if (defined $id) {
            $self->add_link_by_id ($id, $type, $frame);
         } else {
            $self->add_link ($type, $frame);
         }
      }
   }
}

=head2 load_defn (definition text)

Sets up an entire Workspace based on the definition language defined in [pending]. This hasn't actually been implemented yet.

=cut

sub load_defn {
}

=head1 UPDATING WORKSPACE CONTENTS

Once set up, the Workspace is expected to change by the addition of new units, killing (and possible unkilling) of old units, and the promotion of units to different types.

=head2 add_data (type, data), add_data_by_id (ID, type, data)

Adds a data unit. The data is an arbitrary scalar value, but will often be or inherit from AI::TerracedScan::Data so that it can specify value-specific semantics.
If an explicit unique ID is needed, use C<add_data_by_id>; otherwise, a unique ID will be supplied by the workspace.

=cut

sub add_data {
   my ($self, $type, @data) = @_;
   my $data = $data[0];
   
   # TODO: if $data is a scalar, check whether $type has a registered constructor and call it to get a ::Data object
   
   my $id = $self->{top_id};
   $self->{top_id} += 1;
   my $unit = AI::TerracedScan::SemUnit->new ($type, $id, undef, $data);
   
   $self->{units}->add_row ([$id, $type, $unit]);
   $self->notify ('add', $id, $type, $unit);
   $unit;
}
sub add_data_by_id {
   my ($self, $id, $type, @data) = @_;
   croak 'null id when adding by id' unless defined $id;

   my $data = $data[0];
   
   # TODO: if $data is a scalar, check whether $type has a registered constructor and call it to get a ::Data object
   
   my $unit = AI::TerracedScan::SemUnit->new ($type, $id, undef, $data);
   
   $self->{units}->add_row ([$id, $type, $unit]);
   $self->notify ('add', $id, $type, $unit);
   $unit;
}

=head2 add_link (type, content frame), add_link_by_id (ID, type, content frame)

Adds a non-data unit, one which contains (and therefore links) other units.

=cut

sub _unit_lookup {
   my $self = shift;
   my $id = shift;
   my $u = $self->get_unit ($id);
   croak "unit id '$id' not found" unless defined $u;
   return $u;
}

sub _frame_lookup {
   my $self = shift;
   my $frame = shift;

   foreach my $k (keys %$frame) {
      if (not ref $frame->{$k}) {
         $frame->{$k} = $self->_unit_lookup ($frame->{$k});
      } else {
         $frame->{$k} = [ map { $self->_unit_lookup ($_) } @{$frame->{$k}} ];
      }
   }
   #print STDERR "frame:\n" . Dumper($frame);
}

sub add_link {
   my ($self, $type, $frame) = @_;
   $self->_frame_lookup ($frame);

   my $id = $self->{top_id};
   $self->{top_id} += 1;
   my $unit = AI::TerracedScan::SemUnit->new ($type, $id, $frame);
   
   $self->{units}->add_row ([$id, $type, $unit]);
   $self->notify ('add', $id, $type, $unit);
   $unit;
}
sub add_link_by_id {
   my ($self, $id, $type, $frame) = @_;
   croak 'null id when adding by id' unless defined $id;
   $self->_frame_lookup ($frame);

   my $unit = AI::TerracedScan::SemUnit->new ($type, $id, $frame);
   
   $self->{units}->add_row ([$id, $type, $unit]);
   $self->notify ('add', $id, $type, $unit);
   $unit;
}


=head2 kill_unit (id), unkill_unit (id)

Given an ID, kills or unkills the corresponding unit. There is no garbage collection in the Workspace; persistence will take care of eliminating the ashes of killed units
between active sessions. In the meantime, killed units can optionally be used as an indication that a particular move has been tried before and failed. Codelets can also
resurrect existing units instead of creating new ones, if it makes sense in context.

If the actual unit is passed in, instead of its ID, it will be killed/unkilled directly.

=cut

sub kill_unit {
   my ($self, $unit) = @_;
   if (not ref $unit) {
      $unit = $self->get_unit_checked($unit);
   }
   $self->notify ('kill', $unit->get_id, $unit->get_type, $unit);
   $unit->kill;
}
sub unkill_unit {
   my ($self, $unit) = @_;
   if (not ref $unit) {
      $unit = $self->get_unit_checked($unit);
   }
   $unit->unkill;
   $self->notify ('unkill', $unit->get_id, $unit->get_type, $unit);
}

=head2 promote_unit (id, new-type)

Changes the semunit type of a given unit. Types are often defined in chains, with different stages in the chain getting different types of processing codelets.

=cut

sub promote_unit {
   my ($self, $unit, $type) = @_;
   if (not ref $unit) {
      $unit = $self->get_unit_checked($unit);
   }
   $self->notify ('promote', $unit->get_id, $type, $unit);
   $unit->set_type ($type);
}

=head1 NOTIFICATIONS

Subscription callbacks can be registered with the Workspace, after which the subscriber will be notified of each change to the Workspace.

=head2 subscribe (callback)

Adds a callback to the subscription list; this callback will be called on each change to the Workspace with the parameters C<(action, id, type, unit)>, where the action
is C<add>, C<promote>, C<kill>, or C<unkill> and C<unit> is the unit object itself.

=cut

sub subscribe {
   my ($self, $callback) = @_;
   push @{$self->{subscribers}}, $callback;
}

sub notify {
   my $self = shift;
   foreach my $s (@{$self->{subscribers}}) {
      $s->(@_);
   }
}

=head1 STATISTICS AND LISTS

=head2 list_types ()

Lists all the types used by units currently in the Workspace.

=cut

sub list_types {
   my $self = shift;
   uniq (@{$self->{units}->get_col('type')});
}

=head2 list_ids ()

Lists the IDs of the units in the Workspace.

=cut

sub list_ids {
   my $self = shift;
   @{$self->{units}->get_col('id')}; # TODO: select for type, etc. - this will need some movement of Data::Tab along the roadmap
}

=head2 get_unit (id)

Gets a semunit by ID.

=cut

sub get_unit {
   my $self = shift;
   $self->{units}->indexed_get($_[0]);
}
sub get_unit_checked {
   my $self = shift;
   my $id = shift;
   croak "No semunit specified" unless defined $id;
   $self->{units}->indexed_get($id) || croak "Semunit '$id' not found in Workspace";
}

=head2 container (unit, [units]), container_types (unit, [units])

Takes the IDs of units. If passed a single unit, returns the IDs (or types) of its containers; for multiple units, returns the IDs (or types) of all mutual containers.
(This is the same as C<list_in> at the SemUnit level, only using IDs instead of object handles.)

=cut

sub container {
   my $self = shift;
   my $unit = $self->get_unit_checked (shift);
   my @others = map { $self->get_unit ($_) } @_;
   map { $_->get_id() } $unit->list_in (@others);
}
sub container_types {
   my $self = shift;
   my $unit = $self->get_unit_checked (shift);
   my @others = map { $self->get_unit ($_) } @_;
   map { $_->get_type() } $unit->list_in (@others);
}

=head2 choose_units ([type], [number])

Randomly selects one or units at random from the Workspace; if the type is specified it restricts the search. If the number is not specified, it defaults to 1.

=cut

sub choose_units {
   my ($self, $type, $number) = @_;
   
   my $iter = $self->{units}->iterate();
   if (defined $type) {
      $iter = $iter->where (sub {$_[0] eq $type}, 'type');
   } else {
      $iter = $iter->where (sub {$_[0] ne '<dead>'}, 'type'); # The '<dead>' doesn't actually do anything, because deletion flags are kept only at the semunit level right now.
   }
   my $it = $iter->iter();

   $number = 1 if not defined $number;
   
   my @winners = map { [undef, -1] } (1 .. $number);
   
   while (my $unit = $it->()) {
      my $newkey = rand(1);
      #print STDERR "new key $newkey\n";
      if ($newkey > $winners[0]->[1]) {
         @winners = sort { $a->[1] <=> $b->[1] } (@winners, [$unit, $newkey]);
         @winners = splice (@winners, -$number);
      }
      #print STDERR Dumper (\@winners);
   }
   return map { $_->[0] } @winners;

}

=head2 iterate_units(descriptor)

Provides a convenient list of the units currently in the workspace, mostly for debugging. If C<descriptor> is provided, it must be a callback that evaluates each unit
to provide a descriptive text. This iterator returns the fields 'id', 'type', 'unit', and 'desc'. Dead units do not appear in the iterated list.

=cut

sub iterate_units {
   my $self = shift;
   my $descriptor = shift;
   if (not defined $descriptor) {
      $descriptor = sub {
         my $unit = shift;
         return $unit->{type} . '-' . $unit->{id};
      };
   }
   return $self->{units}->iterate()
          ->where(sub { $_[0]->is_live() }, 'unit')
          ->calc($descriptor, 'desc', 'unit');
}

=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ai-terracedscan at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=AI-TerracedScan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AI::TerracedScan::Workspace


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=AI-TerracedScan>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/AI-TerracedScan>

=item * Search CPAN

L<https://metacpan.org/release/AI-TerracedScan>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by Michael Roberts.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of AI::TerracedScan::Workspace