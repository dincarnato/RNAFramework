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
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::IO);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ format            => "AUTO",
                   nrows             => 100,
                   checkDuplicateIds => 1,
                   maskIUPAC         => 0,
                   _offsets          => [],
                   _pack             => undef,
                   _index            => {},
                   _lastid           => 1 }, \%parameters);

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

    $self->throw("Invalid format \"" . $self->{format} . "\"") unless ($self->{format} =~ m/^Fasta|Vienna|C(?:onnectivity)?T(?:able)?|AUTO$/i);
    $self->throw("Number of rows must be a positive integer > 0") if (!ispositive($self->{nrows}) ||
                                                                      !isint($self->{nrows}) ||
                                                                      !$self->{nrows});
    
}

sub _loadformat {
    
    my $self = shift;
    
    $self->_fixformat();
    $self->{format} = $self->_findformat() if ($self->{format} eq "AUTO");

    if (!defined $self->{format}) { $self->warn("Unable to guess file format. Falling back to generic text file."); }
    else {

        my $module = ref($self) . "::" . $self->{format};
        $self->throw("Unable to load module " . $module) unless($self->loadPackage($module));

    }

}

sub _findformat {
    
    my $self = shift;

    my ($format, $fastalike, @rows);
    $fastalike = 0;
    
    # Read nrows lines from the file
    open(my $fh, "<", $self->{data});
    while(my $line = <$fh>) {

        chomp($line);

        $self->throw("File contains unsupported line endings (\"\\r\")") if ($line =~ m/\r/);

        next unless($line);
        
        push(@rows, $line);

        last if (@rows > $self->{nrows});

    }
    close($fh);
    
    for(my $i = 0; $i < @rows; $i++) {
        
        my $line = $rows[$i];
        
        if ($fastalike) {
            
            if (isseq($line, "-")) {
                
                $format = "Fasta";
                
                if ($i + 1 < @rows) {
                    
                    my $line2 = $rows[$i+1];
                    $line2 =~ s/\s*\(\s*[\+-]?\d+\.\d+\)$//; # In case is Vienna format and free energy is appended to structure
                            
                    $format = "Vienna" if (isdotbracket($line2));
                
                }
                
            }
            else { $fastalike = 0; }

        }
        else {
            
            if ($line =~ m/^>/) { $fastalike = 1; }
            else {
                
                my @line = split(" ", $line);
                
                $format = "CT" if (@line == 6 && isna($line[1]) && length($line[1]) == 1 &&
                                   isint($line[0]) && ispositive($line[0]) && $line[0] >= 1 &&
                                   $line[2] == $line[0] - 1 && $line[3] == $line[0] + 1 && $line[5] == $line[0] &&
                                   isint($line[4]) && ispositive($line[4]));
                
            }
            
        }
        
        last if (defined $format);
        
    }

    # Unable to guess, falling back to guess from extension
    if (!defined $format &&
        defined $self->{file}) {

        my ($extension) = $self->{file} =~ m/\.([^\.]+)$/;

        if ($extension =~ m/^(?:fasta|fa|fna|ffn|faa|frn)$/i) { $format = "Fasta"; }
        elsif ($extension =~ m/^db$/i) { $format = "Vienna"; }
        elsif ($extension =~ m/^ct$/i) { $format = "CT"; }

    }

    return($format);
    
}

sub _fixformat {
    
    my $self = shift;
    
    $self->{format} = "Fasta" if ($self->{format} =~ m/^fasta$/i);
    $self->{format} = "Vienna" if ($self->{format} =~ m/^vienna$/i);
    $self->{format} = "CT" if ($self->{format} =~ m/^c(?:onnectivity)?t(?:able)?$/i);
    $self->{format} = "AUTO" if ($self->{format} =~ m/^auto$/i);
    
}

sub format {
    
    my $self = shift;
    
    return($self->{format});
    
}

1;
