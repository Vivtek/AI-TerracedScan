package AI::TerracedScan;

use 5.006;
use strict;
use warnings;

use AI::TerracedScan::Workspace;
use AI::TerracedScan::Coderack;
use Iterator::Records;
use Data::Dumper;

=head1 NAME

AI::TerracedScan - Instantiates a problem in a terraced scan domain

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 INSTANTIATING THE TERRACED SCAN

=head2 new (parms)

The C<parms> are a hash of the following values, all of which are optional:
=over
=item C<workspace>: A prebuilt workspace object
=item C<typereg>: A hash mapping type names to AI::TerracedScan::Type classes
=item C<coderack>: A prebuilt coderack object
=item C<init>: An iterator returning semunits to initialize into the workspace, or a string on which a domain-specific parser can be run to produce such an iterator
=item C<responses>: A callback function for responses, if the problem defines them
=back

Any parameter that is missing, will be filled in with a default version. 

=cut

sub new {
   my ($class, $definition) = @_;
   my $self = bless ({}, $class);
   $self->_init_($definition);
}

sub _init_ {
   my ($self, $definition) = @_;
   
   $self->{workspace} = $definition->{workspace} ? $definition->{workspace} : AI::TerracedScan::Workspace->new();
   $self->{typereg}   = $definition->{typereg}   ? $definition->{typereg}   : {};
   $self->{codelets}  = {};
   $self->{coderack}  = $definition->{coderack}  ? $definition->{coderack}  : AI::TerracedScan::Coderack->new($self);
   
   # Register the codelet types for each type class. By convention, the codelet type starts with its type name, but let's not trust that.
   foreach my $type (keys %{$self->{typereg}}) {
      my $type_class = $self->{typereg}->{$type};
      #require $type_class;
      foreach my $codelet_type ($type_class->codelets()) {
         $self->{codelets}->{$codelet_type} = $type;
      }
   }
   
   my $iterator = $definition->{init};
   if (defined $iterator and not ref $iterator) {
      $iterator = $self->parse_setup ($iterator);
   }
   $self->{workspace}->load_iterator ($iterator) if defined ($iterator);
   
   $self->{responses} = $definition->{responses};
   
   $self->{ticks} = 0;
   
   $self->post_scouts();

   $self;
}

=head1 PARSING THE PROBLEM SETUP

AI::TerracedScan provides an extremely simple-minded parser to get from a problem setup text to an iterator suitable for loading the initial Workspace.
In most cases, you'll want to replace this parser in your domain-specific subclass, but this one's good enough for testing and good enough for a domain you're
just starting to figure out.

=head2 parse_setup (string)

=cut

sub parse_setup {
   my $self = shift;
   my $units = [];
   foreach (split /\n/, $_[0]) {
      my ($type, $id, $data, @fields) = split (/\s+/);
      $id   = undef if $id eq '.';
      $data = undef if $data eq '.';
      $data = '.'   if defined $data and $data eq '\.';
      my $frame = {};
      while (@fields) {
         my $key = shift @fields;
         my $val = shift @fields;
         if (exists $frame->{$key}) {
            if (ref $frame->{$key}) {
               push @{$frame->{$key}}, $val;
            } else {
               $frame->{$key} = [$frame->{$key}, $val];
            }
         } else {
            $frame->{$key} = $val;
         }
      }
      push @$units, [$type, $id, $data, $frame];
   }
   return Iterator::Records->new ($units, ['type', 'id', 'data', 'frame']);
}

sub ticks { $_[0]->{ticks}; }

=head1 RUNNING THE TERRACED SCAN

The main loop is defined on page 87 of Melanie Mitchell's 1990 thesis:
- Choose a codelet and remove it from the Coderack
- Run that codelet
- Every now and then ("if N codelets have run"):
  - Take care of administrative tasks (update the Slipnet, recalculate global temperature, etc.)
  - Post some bottom-up codelets
  - Post some top-down codelets

The Slipnet and top-down codelets are irrelevant for Jombu, but we'll get to slipnetted models soon enough.

=head2 step()

Runs the terraced scan for one step.

=cut

sub step {
   my $self = shift;
   my $count = shift || 1;
   while ($count) {
      $self->{ticks} += 1;
      $self->{coderack}->choose_and_run();
      $self->post_scouts();
      $count -= 1;
   }
}

=head2 run()

Runs the terraced scan until the response callback is called.

=cut

sub run {
   my $self = shift;
   until ($self->{response}) {
      #last if $self->ticks() > 5;
      $self->step();
   }
}

=head1 USEFUL FUNCTIONS

=head2 post_scouts ()

This is called periodically when we want to introduce new musing codelets into the mix. Copycat calls this after every N=15 codelet ticks. It iterates over the list of
types registered, then calls C<propose_scouts> for each type.

=cut

sub post_scouts {
   my $self = shift;
   foreach my $class (values %{$self->{typereg}}) {
      $class->propose_scouts($self);
   }
}

=head2 post_codelet (codelet-type, [parameters])

Post a codelet of the named type, with an optional set of parameters which will generally be units bound to the codelet.

=cut

sub post_codelet {
   my $self = shift;
   my $codelet = shift;
   my $parent = shift;
   my $type_class = $self->{typereg}->{$self->{codelets}->{$codelet}};
   if (not $type_class) {
      # Log a warning, possibly by telling the Coderack to put it in the enactment (which will also include logging), but continue the run
      return;
   }
   $type_class->post ($self, $codelet, $parent, @_);
}

=head2 describe_unit (semunit)

Given a semantic unit, ask its type class for a brief descriptive string.

=cut

sub describe_unit {
   my ($self, $unit) = @_;
   my $type_class = $self->{typereg}->{$unit->get_type()} || return $unit->{type} . '-' . $unit->{id};
   $type_class->describe_unit ($unit, $self);
}

=head2 iterate_workspace ()

Iterates over the units in the workspace and describes each of them in the way that their registered type specifies

=cut

sub iterate_workspace {
   my $self = shift;
   $self->{workspace}->iterate_units(sub { $self->describe_unit ($_[0]); });
}

=head2 decide_failure (p), decide_success (p), decide_yesno (p)

These each return true or false based on the probability "p" provided, but they each skew differently based on the temperature of the Workspace.
A failure is *less* probable as temperature rises (C<p> skews down), a success is *more* probable (C<p> skews up), and a yes/no decision is more 
evenly balanced ((C<p> skews closer to 50%).

The probability is given as a percentage, just to make things easier to read in the caller.

=cut

sub decide_failure {
   my ($self, $p) = @_;
   return (rand() * 100 > $p);  # Note: since we don't have temperature implemented yet, this is just provisionally a straight random decision.
}

sub decide_success {
   my ($self, $p) = @_;
   return (rand() * 100 > $p);
}

sub decide_yesno {
   my ($self, $p) = @_;
   return (rand() * 100 > $p);
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

1; # End of AI::TerracedScan
