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

package Data::IO::Sequence::Fasta;

use strict;
use Fcntl qw(SEEK_SET);
use Core::Utils;
use Data::Sequence;
use Data::Sequence::Utils;

use base qw(Data::IO::Sequence);

sub read {
    
    my $self = shift;
    my $tsid = shift if (@_);
    
    my ($fh, $stream, $header, $id,
        $description, $gi, $accession, $version,
        $sequence, $object, $offset);
    
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
    
    local $/ = "\n>";
    $stream = <$fh>;

    chomp($stream);
    
    foreach my $line (split(/\n/, $stream)) {
        
        next if ($line =~ m/^\s*$/ ||
                 $line =~ m/^#/);
        
        if (!defined $header) {
            
            $header = $line;
            $header =~ s/^>//;
            $header = striptags($header);
            
            next;
            
        }
        
        $sequence .= $line;
        
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
    
    $sequence = striptags($sequence);
    $sequence =~ s/[\s\r>]//g;
    
    return($self->read()) if (!defined $sequence ||
                              !isseq($sequence, "-"));
    
    # Index building at runtime
    
    $self->throw("Duplicate sequence ID \"" . $id . "\" (Offsets: " . $self->{_index}->{$id} . ", " . $offset . ")") if (exists $self->{_index}->{$id} &&
                                                                                                                         $self->{_index}->{$id} != $offset);
    
    $self->{_index}->{$id} = $offset;
    push(@{$self->{_prev}}, $offset);
    
    $object = Data::Sequence->new( id          => $id,
                                   name        => $header,
                                   gi          => $gi,
                                   accession   => $accession,
                                   version     => $version,
                                   sequence    => $sequence,
                                   description => $description );
    
    return($object);
    
}

sub write {
    
    my $self = shift;
    my @sequences = @_ if (@_);
    
    $self->throw("Filehandle isn't in write/append mode") unless ($self->mode() =~ m/^w\+?$/);
    
    foreach my $sequence (@sequences) {
    
        if (!blessed($sequence) ||
            !$sequence->isa("Data::Sequence")) {
            
            $self->warn("Method requires a valid Data::Sequence object");
            
            next;
            
        }
    
        my ($fh, $id, $seq);
        $fh = $self->{_fh};
        $seq = $sequence->sequence();
    
        if (!defined $seq) {
            
            $self->warn("Empty Data::Sequence object");
            
            next;
            
        }
    
        $self->{_lastid} = 1 unless($self->{_lastid});
    
        if (!defined $sequence->id()) {
        
            if (defined $sequence->gi()) {
            
                $id = "gi|" . $sequence->gi();
                $id .= "|ref|" . $sequence->accession() if defined($sequence->accession());
                $id .= "." . $sequence->version() if defined($sequence->version() &&
                                                             $sequence->accession !~ m/\.\w+$/);
            
            }
            else {
            
                $id = "Sequence_" . $self->{_lastid};
                $self->{_lastid}++;
            
            }
        
        }
        else { $id = $sequence->id(); }
    
        $id .= " " . $sequence->description() if defined($sequence->description());
        $sequence =~ s/(\w{60})/$1\n/g;
    
        print $fh ">" . $id . "\n" .
                  $seq . "\n";
        
    }
    
}

1;