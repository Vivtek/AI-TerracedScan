package AI::TerracedScan::Codelet;

use 5.006;
use strict;
use warnings;
use Carp;

=head1 NAME

AI::TerracedScan::Codelet - A base class for actions taken in a terraced scan

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS


=head1 SUBROUTINES/METHODS

=head2 post_new (scan, parameters)

Creates a new codelet action record on the Coderack with the given parameters.

=cut

sub post_new {
   my ($class, $ts, $parms) = @_;
   my $rack = $ts->{coderack};
   my $self = bless ({}, $class);
   
   $self->{posted} = $ts->ticks;
   $self->{type} = $parms->{type} || croak "attempt to post codelet without type";
   $self->{name} = $parms->{name} || croak "attempt to post codelet without name";
   unless (defined $parms->{callback}) { croak "attempt to post codelet without callback"; } # Which will be fine, later, with persistent scans
   $self->{callback} = $parms->{callback}->($self);
   $self->{frame} = $parms->{frame} || {};
   $self->{desc}  = $parms->{desc}  || '';
      
   $self->{urgency} = $parms->{urgency} || 'musing';
   
   $rack->post ($self);
   
   $self;
}

sub fizzle {
   my ($self, $rule) = @_;
   $self->{rule} = $rule;
   return 'fizzle';
}
sub fail {
   my ($self, $rule) = @_;
   $self->{rule} = $rule;
   return 'fail';
}
sub fire {
   my ($self, $rule) = @_;
   $self->{rule} = $rule;
   return 'fire';
}



=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ai-terracedscan at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=AI-TerracedScan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AI::TerracedScan


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

1; # End of AI::TerracedScan::Codelet
