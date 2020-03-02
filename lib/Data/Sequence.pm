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

package Data::Sequence;

use strict;
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ id          => undef,
                   gi          => undef,
                   gb          => undef,
                   name        => undef,
                   sequence    => undef,
                   accession   => undef,
                   start       => undef,
                   end         => undef,
                   version     => undef,
                   locus       => undef,
                   orientation => 5,
                   description => undef,
                   type        => "DNA",
                   circular    => 0,
                   references  => [],
                   _length     => undef }, \%parameters);
    
    if ($class =~ m/^Data::Sequence::\w+$/) { return($self); }
    else {
    
        $self->_validate();
        $self->_fixproperties();
        
    }
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->throw("Sequence contains invalid characters") if (defined $self->{sequence} &&
                                                             !isseq($self->{sequence}, "-"));
    $self->throw("Invalid sequence type \"" . $self->{type} . "\"") unless ($self->{type} =~ m/^((D|R)N|A)A$/i);

    
}

sub _fixproperties {
    
    my $self = shift;
    
    $self->{type} = uc($self->{type});
    $self->{orientation} = uc($self->{orientation});
    
    $self->{sequence} = uc($self->{sequence}) if ($self->{type} eq "AA");
    
    if (defined $self->{sequence}) {
        
        if (isdna($self->{sequence}, "-")) { $self->{type} = "DNA"; }
        elsif (isrna($self->{sequence}, "-")) { $self->{type} = "RNA"; }
        else { $self->{type} = "AA"; }
        
        if ($self->{type} eq "AA") {
            
            $self->{orientation} =~ tr/53/NC/ if (defined $self->{orientation});
            $self->{orientation} = "N" unless ($self->{orientation} =~ m/^[NC]$/);
            
        }
        else {
            
            $self->{orientation} =~ tr/NC/53/ if (defined $self->{orientation});
            $self->{orientation} = "5" unless ($self->{orientation} =~ m/^[53]$/);
            
        }
        
        $self->{_length} = length($self->{sequence});
        
    }
    
}

sub id {
    
    my $self = shift;
    my $id = shift if (@_);
    
    $self->{id} = $id if (defined $id);
    
    return($self->{id});
    
}

sub name {
    
    my $self = shift;
    my $name = shift if (@_);
    
    $self->{name} = $name if (defined $name);
    
    return($self->{name});
    
}

sub sequence {
    
    my $self = shift;
    my $sequence = shift if (@_);
    
    if (isseq($sequence, "-")) {
    
        $self->{sequence} = uc($sequence);    
        $self->_fixproperties();
        
    }
    
    return($self->{sequence});
    
}

sub accession {
    
    my $self = shift;
    my $accession = shift if (@_);
    
    $self->{accession} = $accession if (defined $accession);
    
    return($self->{accession});
    
}

sub gi {
    
    my $self = shift;
    my $gi = shift if (@_);
    
    $self->{gi} = $gi if (defined $gi);
    
    return($self->{gi});
    
}

sub gb {
    
    my $self = shift;
    my $gb = shift if (@_);
    
    $self->{gb} = $gb if (defined $gb);
    
    return($self->{gb});
    
}

sub start {
    
    my $self = shift;
    my $start = shift if (@_);
    
    $self->{start} = $start if (isreal($start));
    
    return($self->{start});
    
}

sub end {
    
    my $self = shift;
    my $end = shift if (@_);
    
    $self->{end} = $end if (isreal($end));
    
    return($self->{end});
    
}

sub version {
    
    my $self = shift;
    my $version = shift if (@_);
    
    $self->{version} = $version if (defined $version);
    
    return($self->{version});
    
}

sub locus {
    
    my $self = shift;
    my $locus = shift if (@_);
    
    $self->{locus} = $locus if (defined $locus);
    
    return($self->{locus});
    
}

sub orientation {
    
    my $self = shift;
    my $orientation = shift if (@_);
    
    if ($orientation =~ m/^[53NC]$/) {
        
        $self->_fixproperties();
        $self->{orientation} = uc($orientation);
        
    }
    
    return($self->{orientation});
    
}

sub description {
    
    my $self = shift;
    my $description = shift if (@_);
    
    $self->{description} = $description if (defined $description);
    
    return($self->{description});
    
}

sub type {
    
    my $self = shift;
    my $type = shift if (@_);
    
    if ($type =~ m/^([DR]NA|AA)$/i) {
    
        $self->{type} = uc($type);    
        $self->_fixproperties();
        
    }
    
    return($self->{type});
    
}

sub circular {
    
    my $self = shift;
    my $circular = shift if (@_);
    
    $self->{circular} = $circular if ($circular =~ m/^[01]$/);
    
    return($self->{circular});
    
}

sub length {
    
    my $self = shift;
    
    $self->{_length} = length($self->{sequence}) unless(defined $self->{_length});
    
    return($self->{_length});
    
}

sub extract {
    
    my $self = shift;
    my $start = shift || 1;
    my $end = shift || $self->length();
    
    my ($sequence);
    
    $self->throw("Start/end values must be positive integers") unless (ispositive($start) &&
                                                                       ispositive($end) &&
                                                                       isint($start) &&
                                                                       isint($end));
    
    if ($start > $self->length() ||
        $end > $self->length()) {
        
        $sequence = substr($self->sequence(), $start - 1, $end - $start + 1);
        
    }
    else { $self->warn("Out of range (Length: " . $self->length() . ")"); }
    
    return($sequence);
    
}

sub hardmask {
    
    my $self = shift;
    
    if ($self->{type} =~ m/^(D|R)NA$/) { $self->{sequence} =~ s/[acgtun]/N/g; }
    else { $self->warn("Unable to hardmask an amino acid sequence"); }
    
}

sub unmask {
    
    my $self = shift;
    
    $self->{sequence} = uc($self->{sequence});
    
}

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{sequence});
    
}

1;
