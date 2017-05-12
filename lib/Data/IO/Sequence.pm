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

package Data::IO::Sequence;

use strict;
use Core::Utils;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::IO);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ format   => "AUTO",
                   _offsets => [],
                   _pack    => undef,
                   _index   => {},
                   _lastid  => 1 }, \%parameters);
    
    if ($class =~ m/^Data::IO::Sequence::\w+$/) {
    
        $self->_openfh();
        
        return($self);
        
    }
    else {
        
        my ($module, $object);
        
        $self->_validate();
        $self->_loadformat();
        $module = ref($self) . "::" . $self->{format};
        $object = $module->new(%parameters);
        
        return($object);
        
    }
    
}

sub _validate {
    
    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Invalid format \"" . $self->{format} . "\"") unless ($self->{format} =~ m/^Fasta|AUTO$/i);
    
}

sub _loadformat {
    
    my $self = shift;
    
    if ($self->{format} eq "AUTO") { $self->{format} = $self->_findformat(); }
    else { $self->_fixformat(); }
    
    $self->loadpackage(ref($self) . "::" . $self->{format});
    
}

sub _findformat {
    
    my $self = shift;
    
    my ($format, $index, $fastalike);
    $index = 0;
    $fastalike = 0;
    
    open(my $fh, "<", $self->{data});
    foreach my $line (<$fh>) {
        
        chomp($line);
        
        if ($fastalike) {
            
            # In case is Vienna format and free energy is appended to structure
            $line =~ s/\s*\([\+-]?\d+\.\d+\)$//;
            
            $format = "Fasta" if (isseq($line, "-") &&
                                  !defined $format);
            $format = "Vienna" if (isdotbracket($line));
            
        }
        else { $fastalike = 1 if ($line =~ m/^>/); }
        
        last if ($index > 100); # Just parse the first 100 rows to guess format
        
        $index++;
        
    }
    close($fh);
    
    return($format);
    
}

sub _fixformat {
    
    my $self = shift;
    
    $self->{format} = "Fasta" if ($self->{format} =~ m/^fasta$/i);
    $self->{format} = "AUTO" if ($self->{format} =~ m/^auto$/i);
    
}

sub format {
    
    my $self = shift;
    
    return($self->{format});
    
}

1;