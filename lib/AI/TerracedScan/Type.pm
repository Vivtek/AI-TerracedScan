package AI::TerracedScan::Type;

use 5.006;
use strict;
use warnings;

=head1 NAME

AI::TerracedScan::Type - Base class for a type of semantic unit

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

# Default values for various type-specific things. These will be overridden by domain-specific types.

our $name = 'default';
our @codelets = ();

=head1 SUBROUTINES/METHODS

A unit type is not actually instantiated as an object (right now) - it's just a place to group constants and codelet definitions.

=head2 name(), codelets()

Retrieves some constants pertaining to the type.

=cut

sub name { return $name; }
sub codelets { return @codelets; }

=head2 propose_scouts (scan)

Given the current scan state, optionally propose some scout codelets. (We're allowed to check anything about the current run - workspace, coderack, etc.)

=cut

sub propose_scouts {
   return ();
}

=head2 post (scan, codelet-type, [parameters])

Posts a codelet of the named type in the context of the scan. (Does nothing in base class.)

=cut

sub post { }

=head2 describe_unit (unit)

Provides a brief descriptive string for a unit. The default is to return the unit's type and ID.

=cut

sub describe_unit {
   my ($self, $unit) = @_;
   return $unit->{type} . '-' . $unit->{id};
}


=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by Michael Roberts.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of AI::TerracedScan::Type
