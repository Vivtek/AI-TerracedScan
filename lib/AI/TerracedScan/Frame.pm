package AI::TerracedScan::Frame;

use 5.006;
use strict;
use warnings;

=head1 NAME

AI::TerracedScan::Frame - A subset of the Workspace (a set of units, with optional slots foregrounding/naming one or more)

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

A C<Frame> is used as a temporary structure to pull out subsets of the units in the Workspace and identify some by role. This is a useful abstraction for
codelet design. I suspect it's going to evolve into something more interesting over time, but right now its purpose is the simplification of codelet structure.

Right now, this overlaps a lot with C<SemUnit>; it's probable they'll merge into a single class at some point, but I'm not yet clear just how. I assume it will
get a lot clearer as I work through a few use cases.

=head1 SUBROUTINES/METHODS

=head2 new (workspace)

Creates a new frame.

=cut

sub new {
   my ($class, $ws) = @_;
   my $self = bless ({}, $class);
   $self->{ws} = $ws;
   $self->{units} = {};
   $self->{slots} = {};
   $self->{types} = {};
   $self;
}

=head2 add_unit (unit, [name])

Units can be referred to either by pointer or by Workspace ID. If a slot name is supplied, this is equivalent to calling C<identify_unit> after adding the unit
to the frame. A slot contains a list of units, even if it's just one unit in the list, or none. (It's actually stored as an id->unit hash to prevent duplication.)

Since units keep statistics on the types of units they contain and since units can appear in any of the name lists, there is no method to delete units from a frame,
because keeping all that straight would be a pain. If you need a frame without a given unit, just create a new frame and copy the rest of the units over to it.

=cut

sub normalize_unit {
   my ($self, $unit) = @_;
   my $id;
   if (ref $unit) {
      $id = $unit->get_id();
   } else {
      $id = $unit;
      $unit = $self->{ws}->get_unit($id);
   }
   return ($id, $unit);   
}
sub add_unit {
   my ($self, $unit, $name) = @_;
   my $id;
   ($id, $unit) = $self->normalize_unit ($unit);
   $self->{types}->{$unit->get_type()} += 1 unless $self->{units}->{$id};
   $self->{units}->{$id} = $unit;
   
   $self->identify_unit ($id, $name) if defined $name;
   return $id;
}
sub get_unit {
   my ($self, $unit) = @_;
   my $id;
   ($id, $unit) = $self->normalize_unit ($unit);
   return $unit;
}

=head2 identify_unit (unit, name), unidentify_unit (unit, name)

Adds a unit to a named slot, or removes it from that slot. Units can be in any number of slots, including zero.

=cut

sub identify_unit {
   my ($self, $unit, $name) = @_;
   my $id;
   ($id, $unit) = $self->normalize_unit ($unit);
   $self->{slots}->{$name}->{$id} = $unit;
   return $id;
}
sub unidentify_unit {
   my ($self, $unit, $name) = @_;
   my $id;
   ($id, $unit) = $self->normalize_unit ($unit);
   #$self->{slots}->{$name} = {} unless defined $self->{slots}->{$name};
   delete $self->{slots}->{$name}->{$id};
   return $id;
}

=head2 get (name), get_ids (name)

Returns a list of units that are in the C<name> slot, or a list of their IDs in the Workspace. Returns a list, not an arrayref. The order of the list is arbitrary.

=cut

sub get {
   my ($self, $name) = @_;
   #$self->{slots}->{$name} = {} unless defined $self->{slots}->{$name};
   return values %{$self->{slots}->{$name}};
}
sub get_ids {
   my ($self, $name) = @_;
   #$self->{slots}->{$name} = {} unless defined $self->{slots}->{$name};
   return keys %{$self->{slots}->{$name}};
}

=head2 units ([type]), list_ids ([type])

Returns a list of units (or their IDs) contained in the frame, optionally constraining the list to a specific unit type. The order of the list is arbitrary.

=cut

sub units {
   my ($self, $type) = @_;
   if (defined $type) {
      return grep { $_->get_type() eq $type } $self->units();
   } else {
      return values %{$self->{units}};
   }
}
sub list_ids {
   my ($self, $type) = @_;
   if (defined $type) {
      return map { $_->get_id() } $self->units($type);
   } else {
      return keys %{$self->{units}};
   }
}

=head2 list_types ()

Lists the types of units currently in the frame.

=cut

sub list_types {
   my $self = shift;
   return keys %{$self->{types}};
}

=head2 count ([type])

Returns the number of units in the frame, or the number of a given type.

=cut

sub count {
   my ($self, $type) = @_;
   return $self->{types}->{$type} if defined $type;
   return scalar keys %{$self->{units}};
}

=head2 names ()

Lists the names currently defined in the frame.

=cut

sub names {
   my $self = shift;
   keys %{$self->{slots}};
}

=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ai-terracedscan at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=AI-TerracedScan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AI::TerracedScan::SemUnit


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

1; # End of AI::TerracedScan::SemUnit
