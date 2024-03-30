package AI::TerracedScan::SemUnit;

use 5.006;
use strict;
use warnings;

=head1 NAME

AI::TerracedScan::SemUnit - A semantic unit, a component of short-term memory

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS


=head1 SUBROUTINES/METHODS

=head2 new (type, id, [frame], [data])

Creates a new unit of the named type, and optionally assigns its content. You will almost never need to do this; normally you'll parse a descriptive language into
a workspace structure. If the unit is a sensory unit, it represents data outside the memory, and C<data> is used to specify it.

=cut

sub new {
   my ($class, $type, $id, $frame, $data) = @_;
   my $self = bless ({}, $class);
   $self->{type} = $type;
   $self->{frame} = {};
   $self->{frames_in} = {};
   $self->set_data ($data) if defined $data;
   $self->{id} = ref $id ? $id->get_id() : $id if defined $id;
   $self->{deleted} = 0;
   
   if (defined $frame) {
      while (my ($key, $value) = each (%$frame)) {
         $self->set ($key, $value);
      }
   }
   $self;
}

=head2 kill (), is_live (), unkill ()

These do the expected manipulation of the "deleted" flag. Dead units do not appear in containment lists.

=cut

sub kill    { $_[0]->{deleted} = 1; }
sub unkill  { $_[0]->{deleted} = 0; }
sub is_live { not $_[0]->{deleted}; }

=head2 set (slot, value), add (slot, value), del (slot, value)

A named slot can have one or more values (if the latter, they're just a list). The C<set> method sets a single value; C<add> adds a value to the list and
C<del> removes an existing value from the list. Values are other units, so there is always exact identity.

Slot-value assignments are bidirectional, in that the unit sitting in a slot knows it's in the slot. 

If the type prohibits the value named, this should croak.

=cut

sub set {
   my ($self, $slot, $value) = @_;
   if (ref $value eq 'ARRAY') {
      foreach my $v (@$value) {
         $self->add ($slot, $v);
      }
   } else {
      $self->{frame}->{$slot} = $value;
      $value->add_in ($slot, $self);
   }
}
sub add {
   my ($self, $slot, $value) = @_;
   if (not $self->has_slot ($slot)) {
      $self->{frame}->{$slot} = { $value => $value };
   } elsif (ref ($self->{frame}->{$slot}) eq 'HASH') {
      $self->{frame}->{$slot}->{$value} = $value;
   } else {
      $self->{frame}->{$slot} = { $self->{frame}->{$slot} => $self->{frame}->{$slot}, $value => $value };
   }
   $value->add_in ($slot, $self);
}
sub add_in {
   my ($self, $slot, $value) = @_;
   if (not $self->is_in_slot ($slot)) {
      $self->{frames_in}->{$slot} = { $value => $value };
   } elsif (ref ($self->{frames_in}->{$slot}) eq 'HASH') {
      $self->{frames_in}->{$slot}->{$value} = $value;
   } else {
      $self->{frames_in}->{$slot} = { $self->{frames_in}->{$slot} => $self->{frames_in}->{$slot}, $value => $value };
   }
}
sub del {
   my ($self, $slot, $value) = @_;
   $value->del_in ($slot, $self);
   return unless $self->has_slot ($slot);
   delete $self->{frame}->{$slot}->{"$value"};
}
sub del_in {
   my ($self, $slot, $value) = @_;
   return unless $self->is_in_slot ($slot);
   delete $self->{frames_in}->{$slot}->{"$value"};
}

=head2 get (slot), has_slot (slot)

Gets either the single value or the arrayref of values for the named slot. Returns undef if the unit does not have this slot.

=cut

sub get {
   my ($self, $slot) = @_;
   return undef unless $self->has_slot ($slot);
   if (ref ($self->{frame}->{$slot}) eq 'HASH') {
      return [ values %{$self->{frame}->{$slot}} ];
   }
   return $self->{frame}->{$slot};
}
sub get_containers {
   my ($self, $slot) = @_;
   return undef unless $self->is_in_slot ($slot);
   if (ref ($self->{frames_in}->{$slot}) eq 'HASH') {
      return [ values %{$self->{frames_in}->{$slot}} ];
   }
   return $self->{frames_in}->{$slot};
}
sub has_slot {
   my ($self, $slot) = @_;
   defined ($self->{frame}->{$slot});
}
sub is_in_slot {
   my ($self, $slot) = @_;
   return 0 unless defined ($self->{frames_in}->{$slot});
   return scalar values %{$self->{frames_in}->{$slot}};
}

=head2 get_type(), set_type()

Gets the type of the unit, or sets it (for promotion).

=cut

sub get_type {
   my ($self) = @_;
   $self->{type};
}
sub set_type {
   my ($self, $newtype) = @_;
   $self->{type} = $newtype;
}

=head2 get_data(), set_data()

If this is a sensory unit (if it points to external data), this returns that data.

=cut

sub get_data {
   my ($self) = @_;
   $self->{data};
}
sub set_data {
   my ($self, $data) = @_;
   $self->{data} = $data;
}

=head2 get_id(), set_id()

Gets or sets the ID of the unit.

=cut

sub get_id {
   my ($self) = @_;
   $self->{id};
}
sub set_id {
   my ($self, $data) = @_;
   $self->{id} = $data;
}

=head2 list_in (units), list_in_dead (units)

Returns a list of the frames that contain this unit. If a list of units is given, returns a list of the frames that contain all of them at the same time.
Containment does not look at which slot the contained unit occupies, just whether it's there at all. It is not recursive. It does not list dead units.
The alternative list_in_dead lists I<only> dead units, so they can be unkilled when appropriate.

=cut

sub _list_in {
   my ($self, $unit) = @_;
   my $collector = {};
   foreach my $slot (values %{$self->{frames_in}}) {
      foreach my $p (values %$slot) {
         next if $p->{deleted};
         $collector->{$p} = $p;
      }
   }
   return $collector;
}
sub list_in {
   my $self = shift;
   my $c = $self->_list_in ($self);
   my @list = values %$c;
   return () unless @list;
   while (my $other = shift) {
      my $c2 = $other->_list_in ();
      @list = grep { defined $c2->{$_} } @list;
      return () unless @list;
   }
   return @list;
}
sub _list_in_dead {
   my ($self, $unit) = @_;
   my $collector = {};
   foreach my $slot (values %{$self->{frames_in}}) {
      foreach my $p (values %$slot) {
         next unless $p->{deleted};
         $collector->{$p} = $p;
      }
   }
   return $collector;
}
sub list_in_dead {
   my $self = shift;
   my $c = $self->_list_in_dead ($self);
   my @list = values %$c;
   return () unless @list;
   while (my $other = shift) {
      my $c2 = $other->_list_in_dead ();
      @list = grep { defined $c2->{$_} } @list;
      return () unless @list;
   }
   return @list;
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
