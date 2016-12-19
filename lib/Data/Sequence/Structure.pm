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

package Data::Sequence::Structure;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::Sequence);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    $parameters{type} = "RNA";
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ structure => undef,
                   energy    => 0 }, \%parameters);
    
    $self->_validate();
    $self->_fixproperties();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->SUPER::_validate();

    $self->throw("Energy value must be real") if (!isreal($self->{energy}));
    $self->throw("Sequence and structure have different lengths") if (defined $self->{sequence} &&
                                                                      defined $self->{structure} &&
                                                                      length($self->{sequence}) != length($self->{structure}));
    $self->throw("Invalid dot-bracket structure") if (defined $self->{structure} &&
                                                      !isdotbracket($self->{structure}));
    $self->throw("Dot-bracket structure is not balanced") if (defined $self->{structure} &&
                                                              !isdbbalanced($self->{structure}));

}

sub _fixproperties {
    
    my $self = shift;
    
    $self->{sequence} = dna2rna($self->{sequence}) if (isna($self->{sequence}));
    
    $self->SUPER::_fixproperties();
    
    $self->throw("Data::Sequence::Structure objects type must be RNA") if ($self->{type} ne "RNA");
    
}

sub structure {
    
    my $self = shift;
    
    return($self->{structure});
    
}

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{structure});
    
    $self->SUPER::DESTROY();
    
}

1;