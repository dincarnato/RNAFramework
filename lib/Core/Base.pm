#!/usr/bin/perl

##
# Chimaera Framework
# Epigenetics Unit @ HuGeF [Human Genetics Foundation]
#
# Author:  Danny Incarnato (danny.incarnato[at]hugef-torino.org)
#
# This program is free software, and can be redistribute  and/or modified
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# Please see <http://www.gnu.org/licenses/> for more informations.
##

package Core::Base;

use strict;
use Carp;
use Core::Utils;

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = {};

    bless($self, $class);

    $self->_init({verbosity => undef}, \%parameters);

    return($self);

}

sub _init {

    my $self = shift;
    my ($default, $provided) = @_ if (@_);

    if (my $parameters = checkparameters($default, $provided)) {

        $self->{$_} = $parameters->{$_} for (keys %{$parameters});
        $self->verbosity($self->{verbosity}) if (defined $self->{verbosity});

    }
    else { $self->throw("Default parameters must be provided as an HASH reference"); }

}

sub loadPackage {

    my $self = shift;
    my $package = shift if (@_);

    $self->throw("No package specified") if (!defined $package);

    my ($module, $eval);
    $module = $package;
    $module .= ".pm" unless ($module =~ m/\.pm$/);
    $module =~ s/::/\//g;

    return(1) if (exists $INC{$module});

    my $eval = do { local $@;
                    eval { require $module; };
                    $@; };

    return() if ($eval);

    return(1);

}

sub clone {

    my $self = shift;

    my $clone = clonehashref($self);

    bless($clone, ref($self));

    return($clone);

}

sub verbosity {

    my $self = shift;
    my $verbosity = shift if (@_);

    if (defined $verbosity) {

        if ($verbosity !~ m/^\-1|0|1$/) {

            $self->{verbosity} = 0 if ($self->{verbosity} !~ m/^\-1|0|1$/);
            $self->warn("Verbosity level must be comprised between -1 and 1");

        }
        else { $self->{verbosity} = $verbosity; }

    }

    return($self->{verbosity});

}

sub warn {

    my $self = shift;
    my $message = shift if (@_);

    return if ($self->{verbosity} < 0);

    Core::Utils::warn($message, $self->{verbosity});

}

sub throw {

    my $self = shift;
    my $message = shift if (@_);

    Core::Utils::throw($message, $self->{verbosity});

}

1;

=head1 NAME

Core::Base - Chimaera Framework Base Class

=head1 SYNOPSIS

# Template for Chimaera's compliant modules
use base qw(Core::Base);

sub new {

  my $class = shift;
  my %parameters = @_ if (@_);

  my $self = $class->SUPER::new(%parameters);
  $self->_init({ parameter1 => undef,
                 parameter2 => undef,
                 ...
                 parametern => undef}, \%parameters);

  return($self);

}

# Chimaera compliant objects universal methods
$clone = $object->clone();
$object->loadpackage(MODULE);
$object->verbosity(VALUE);
$object->throw(TEXT);
$object->warn(TEXT);

=head1 DESCRIPTION

This module provides the base class for any Chimaera Framework's
module. Provided methods should be available to any Chimaera
compliant object.

=head1 METHODS

=head2 new(verbosity => VALUE)

=over 4

Returns a new Core::Base object.
If the "verbosity" parameter isn't specified, B<warn()> method's
verbosity will be set automatically to 0 (low verbosity).

=back

=head2 _init(DEFAULT, PARAMETERS)

=over 4

Initializes the object's parameters.
DEFAULT should be an HASH reference containing all the parameters
required to the object, along with their default values. PARAMETERS should
be an HASH reference containing the user-defined parameters. Any parameter
not specified in DEFAULT will be ignored by B<_init()>. If the object
shares some parameters with a parent class (and such parameters are already
specified in the initialization phase of the parent object) they can be
avoided in DEFAULT.

=back

=head2 loadpackage(MODULE)

=over 4

Loads the specified MODULE at runtime. If any error occurs, it throws
an exception.

=back

=head2 clone

=over 4

Returns an independent clone of the object.

=back

=head2 verbosity(VALUE)

=over 4

Without any argument it returns the actual verbosity level. If VALUE is
specified, it sets the new verbosity level for the B<warn()> method:

  -1. Suppressed verbosity
   0. Low verbosity
   1. High verbosity (Stack trace-dump)

=back

=head2 warn(TEXT)

=over 4

Prints to the STDERR the specified warning message. If TEXT isn't specified,
it will print "Undefined error". The verbosity level can be specified
through the B<verbosity()> method.

=back

=head2 throw(TEXT)

=over 4

Throws the specified error message and exits. If TEXT isn't specified,
it will print "Undefined error".

=back

=head1 AUTHOR

Danny "nemesis" Incarnato <nemesis[at]chimaera-framework.com>

=head1 COPYRIGHT

Copyright 2011-2012 Chimaera Framework.  All rights reserved.

It's forbidden to modify or redistribute this software, or any
part of it without prior authorization.

=cut
