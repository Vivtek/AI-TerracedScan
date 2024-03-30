package AI::TerracedScan::Scene;

use 5.006;
use strict;
use warnings;

use Data::Tab;
use Carp;
use Data::Dumper;

=head1 NAME

AI::TerracedScan::Scene - Organizes selected Workspace objects into a geometrical layout

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

A scene is used to represent a diagram or other visual display of (some of) the semunits in the Workspace. A later functionality the scene might provide
would be the representation of geometrical or spatial or visual relationships for use in cognition, but that has yet to be explored.

A scene subscribes to change notifications from the Workspace so that it can represent them in the display output. How the semantic structure is converted into
a graphical representation is defined in a "scene specification" (a SceneSpec).

=head1 SUBROUTINES/METHODS

=head2 new (ws, spec)

A new scene is initialized on a Workspace and with a scene specification. It sets up a change notification subscription with the Workspace, and from that point
on does whatever the specification defines to represent the current state of the Workspace. Right now, the easiest way to deal with specifications is just to
subclass the Scene, but later we might have some more universal way of describing diagrams.

=cut

sub new {
   my ($class, $scan) = @_;
   my $self = bless ({}, $class);
   $self->{scan} = $scan;
   $self->{workspace} = $scan->{workspace};
   $self->{units} = {};
   $self->{workspace}->subscribe ( sub {
      $self->update (@_);
   });
   $self;
}

sub update {
   my ($self, $action, $id, $type, $unit) = @_;
   if ($action eq 'add') {
      $self->{units}->{$id} = {
         type => $type,
         unit => $unit,
         live => 1,
      };
   } elsif ($action eq 'kill') {
      $self->{units}->{$id}->{live} = 0;
   } elsif ($action eq 'unkill') {
      $self->{units}->{$id}->{live} = 1;
   } elsif ($action eq 'promote') {
      $self->{units}->{$id}->{type} = $type;
   }
   $self->display_action ($action, $id, $type, $unit);
}

sub display_action { }
#   my ($self, $action, $id, $type, $unit) = @_;

=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ai-terracedscan at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=AI-TerracedScan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AI::TerracedScan::Scene


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

1; # End of AI::TerracedScan::Scene
