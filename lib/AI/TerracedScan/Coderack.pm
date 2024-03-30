package AI::TerracedScan::Coderack;

use 5.006;
use strict;
use warnings;

use Data::Tab;
use AI::TerracedScan::Codelet;
use Data::Dumper;

=head1 NAME

AI::TerracedScan::Coderack - Implements the action queue for a terraced scan

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

The action queue of the terraced scan is called the Coderack. 

=head1 SUBROUTINES/METHODS

=head2 new (definition)

This is still in flux.

=cut

sub new {
   my ($class, $ts, $definition) = @_;
   my $self = bless ({}, $class);
   $self->{defn} = $definition;
   $self->{scan} = $ts;
   $self->{queue} = Data::Tab->new ([], headers => ['type', 'posted', 'urgency', 'codelet'], primary => 'codelet');
   $self->{enactment} = Data::Tab->new ([], headers => ['type', 'posted', 'run', 'urgency', 'outcome', 'codelet'], primary => 'codelet');
   $self->{top_id} = 0;
   $self;
}

=head2 post (codelet)

Given a parameterized codelet record, adds it to the "queue". Note that the queue returns things in a stochastic manner, so it's not really properly a queue.

=cut

sub post {
   my ($self, $codelet) = @_;
   $codelet->{posted} = $self->{scan}->ticks;
   $self->{top_id} += 1;
   $codelet->set_id($self->{top_id});
   $self->{queue}->add_row ([$codelet->{name}, $self->{scan}->ticks, $codelet->{urgency}, $codelet]);
}

=head2 choose_and_run ()

Chooses a codelet at random from the queue (with urgency or other bias according to our chosen strategy), removes it from the queue, then runs it
and places it into the enactment, along with its outcome and time of execution.

=cut

sub choose_and_run {
   my $self = shift;
   return unless $self->{queue}->rows(); # Do nothing if queue is empty
   my $row = $self->{queue}->take_row ($self->choose_codelet());
   $self->run_codelet ($row->[3]);
}

=head2 choose_codelet ()

The default Coderack asks the scan for its current global temperature, then selects a codelet with urgency bias depending on that.
To implement a different strategy, subclass this and override choose_codelet(). This returns the *row number* in the queue for the codelet to allow deletion.

=cut

sub choose_codelet {
   my $self = shift;
   
   my $uvals = {'musing' => 1, 'normal' => 2, 'asap' => 3, 'fire' => 4, 'agggh' => 5}; # Later, we'll warp this by global temperature.
   
   my $urgencies = [ map { $uvals->{$_} || 1 } @{$self->{queue}->get_col ('urgency')} ];
   my $winner = 0;
   my $sortkey = rand(1) ** (1/$urgencies->[0]);
   for (my $i = 1; $i < scalar @$urgencies; $i++) {
      my $newkey = rand(1) ** (1/$urgencies->[$i]);
      if ($newkey > $sortkey) {
         $winner = $i;
         $sortkey = $newkey;
      }
   }
   return $winner;
}

=head2 run_codelet (codelet)

Actually runs a codelet and logs its outcome to the enactment.

=cut

sub run_codelet {
   my ($self, $codelet) = @_;
   
   my $callback = $codelet->{callback};
   # if (not defined $callback) - this will happen in persistent runs, but can't yet
   my $outcome = $callback->();   # Side effects: possible unit creation
   # ['type', 'posted', 'run', 'urgency', 'outcome', 'codelet']
   $self->{enactment}->add_row ([$codelet->{name}, $codelet->{posted}, $self->{scan}->ticks, $codelet->{urgency}, $outcome, $codelet]);
}

=head2 iterate_current ()

Provides a convenient list of things yet to happen.

=cut

sub iterate_current {
   my $self = shift;
   return $self->{queue}->iterate()
          ->calc(sub { defined $_[0]->{origin} ? $_[0]->{origin} : '' }, 'origin', 'codelet')
          ->calc(sub { defined $_[0]->{desc}   ? $_[0]->{desc}   : '' }, 'desc',   'codelet');
}

=head2 iterate_enactment ()

Provides a convenient list of things that have happened so far.

=cut

sub iterate_enactment {
   my $self = shift;
   return $self->{enactment}->iterate()
          ->calc(sub { defined $_[0]->{origin} ? $_[0]->{origin} : '' }, 'origin', 'codelet')
          ->calc(sub { defined $_[0]->{desc}   ? $_[0]->{desc}   : '' }, 'desc',   'codelet')
          ->calc(sub { defined $_[0]->{rule}   ? $_[0]->{rule}   : '' }, 'rule',   'codelet');
}


=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ai-terracedscan at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=AI-TerracedScan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AI::TerracedScan::Coderack


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

1; # End of AI::TerracedScan::Coderack
