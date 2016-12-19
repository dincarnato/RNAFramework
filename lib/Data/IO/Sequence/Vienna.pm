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

package Data::IO::Sequence::Vienna;

use strict;
use Fcntl qw(SEEK_SET);
use Core::Utils;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::IO::Sequence);

sub read {
    
    my $self = shift;
    my $tsid = shift if (@_);
    
    my ($fh, $stream, $header, $id,
        $description, $gi, $accession, $version,
        $sequence, $structure, $energy, $object,
        $offset);
    
    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");
    
    $fh = $self->{_fh};
    
    if (defined $tsid) {
        
        if (exists $self->{_index}->{$tsid}) { seek($fh, $self->{_index}->{$tsid}, SEEK_SET); }
        else {
            
            if (keys %{$self->{_index}}) { $self->throw("Cannot find sequence \"" . $tsid . "\" in file"); }
            else { $self->throw("File is not indexed"); }
            
        }
        
    }
    
    if (eof($fh)) {
        
        $self->reset() if ($self->{autoreset});
        
        return;
        
    }
    
    $offset = tell($fh);
    #push(@{$self->{_prev}}, tell($fh));
    
    local $/ = "\n>";
    $stream = <$fh>;
    
    foreach my $line (split(/\n/, $stream)) {
        
        $line = striptags($line);
        $line =~ s/[\s\r]//g;
        
        next if ($line =~ m/^\s*$/ ||
                 $line =~ m/^#/);
        
        if (!defined $header) {
            
            # First seq header must start with >
            next if (!@{$self->{_prev}} &&
                     $line !~ m/^>/);
            
            $header = $line;
            $header =~ s/^>//;
            
            next;
            
        }
        
        last if ($line =~ m/^>$/);
        
        if (isseq($line)) { $sequence .= $line; }
        elsif (isdotbracket($line)) { $structure .= $line; }
        else {
        
            # In case free energy is appended to structure
            if ($line =~ m/\s*\(([\+-]?\d+\.\d+)\)$/) {
                
                $energy = $1;
                $line =~ s/\s*\([\+-]?\d+\.\d+\)$//;
                
                if (isdotbracket($line)) {
                    
                    $structure .= $line;
                    
                    last;
                    
                }
                
            }
            
            return($self->read());
            
        }
        
    }
    
    if ($header =~ m/^\s*?(\S+)\s+?(.+)$/) {
        
        ($id, $description) = ($1, $2);
        $id = $description unless ($id);
    
    }
    else { $id = $header; }
    
    if ($id =~ m/gi\|(\d+)\|/) { $gi = $1; }
    if ($id =~ m/ref\|([\w\.]+)\|/) {
        
        $accession = $1;
        
        if ($accession =~ m/\.(\w+)$/) {
            
            $version = $1;
            $accession =~ s/\.$version$//;
            
        }
        
    }
    
    return($self->read()) if (!defined $sequence ||
                              !defined $structure ||
                              length($sequence) != length($structure) ||
                              !isdbbalanced($structure));
    
    # Index building at runtime

    $self->throw("Duplicate sequence ID \"" . $id . "\" (Offsets: " . $self->{_index}->{$id} . ", " . $offset . ")") if (exists $self->{_index}->{$id} &&
                                                                                                                         $self->{_index}->{$id} != $offset);
    
    $self->{_index}->{$id} = $offset;
    push(@{$self->{_prev}}, $offset);
    
    $object = Data::Sequence::Structure->new( id          => $id,
                                              name        => $header,
                                              gi          => $gi,
                                              accession   => $accession,
                                              version     => $version,
                                              sequence    => $sequence,
                                              description => $description,
                                              structure   => $structure );
    
    return($object);
    
}

sub write {
    
    my $self = shift;
    my @sequences = @_ if (@_);
    
    $self->throw("Not implemented");
    
}

1;