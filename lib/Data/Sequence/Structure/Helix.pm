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

package Data::Sequence::Structure::Helix;

use strict;
use Core::Mathematics;
use Core::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ h5start => 0,
                   h5end   => 0,
                   h3start => 0,
                   h3end   => 0,
                   parents => [],
                   h5bases => [],
                   h3bases => [] }, \%parameters);
    
    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->throw("5' helix start position must be a positive integer") if (!isint($self->{h5start}) ||
                                                                           !ispositive($self->{h5start}));
    $self->throw("5' helix end position must be a positive integer") if (!isint($self->{h5end}) ||
                                                                         !ispositive($self->{h5end}));
    $self->throw("3' helix start position must be a positive integer") if (!isint($self->{h3start}) ||
                                                                           !ispositive($self->{h3start}));
    $self->throw("3' helix end position must be a positive integer") if (!isint($self->{h3end}) ||
                                                                         !ispositive($self->{h3end}));
    $self->throw("5' helix bases must be provided as an ARRAY reference") if (ref($self->{h5bases}) ne "ARRAY");
    $self->throw("3' helix bases must be provided as an ARRAY reference") if (ref($self->{h3bases}) ne "ARRAY");
    $self->throw("5' and 3' helices have different base counts") if (@{$self->{h5bases}} != @{$self->{h3bases}});
    $self->throw("Parents must be provided as an ARRAY reference") if (ref($self->{parents}) ne "ARRAY");
    
    for (@{$self->{parents}}) { $self->throw("Parents must be positive integers (Parent: " . $_ . ")") if (!isint($_) ||
                                                                                                           !ispositive($_)); }
    
    for (@{$self->{h5bases}}) { $self->throw("5' helix bases must be positive integers (Position: " . $_ . ")") if (!isint($_) ||
                                                                                                                   !ispositive($_));}
    for (@{$self->{h3bases}}) { $self->throw("3' helix bases must be positive integers (Position: " . $_ . ")") if (!isint($_) ||
                                                                                                                   !ispositive($_));}
    @{$self->{h5bases}} = sort {$a <=> $b} @{$self->{h5bases}};
    @{$self->{h3bases}} = sort {$b <=> $a} @{$self->{h3bases}};

    $self->throw("The first value of 5' helix bases differs from 5' helix start position") if ($self->{h5bases}->[0] != $self->{h5start});
    $self->throw("The last value of 5' helix bases differs from 5' helix end position") if ($self->{h5bases}->[-1] != $self->{h5end});
    $self->throw("The first value of 3' helix bases differs from 3' helix start position") if ($self->{h3bases}->[0] != $self->{h3start});
    $self->throw("The last value of 3' helix bases differs from 3' helix end position") if ($self->{h3bases}->[-1] != $self->{h3end});
                                                                                                                 
}

sub h5start { return($_[0]->{h5start}); }

sub h5end { return($_[0]->{h5end}); }

sub h3start { return($_[0]->{h3start}); }

sub h3end { return($_[0]->{h3end}); }

sub h5bases { return(wantarray() ? @{$_[0]->{h5bases}} : $_[0]->{h5bases}); }

sub h3bases { return(wantarray() ? @{$_[0]->{h3bases}} : $_[0]->{h3bases}); }

sub parents { return(wantarray() ? @{$_[0]->{parents}} : $_[0]->{parents}); }

sub basepairs {
    
    my $self = shift;
    
    my (@pairs);
    
    for (0 .. $#{$self->{h5bases}}) { push(@pairs, [$self->{h5bases}->[$_], $self->{h3bases}->[$_]]); }
    
    return(wantarray() ? @pairs : \@pairs);
    
}

1;