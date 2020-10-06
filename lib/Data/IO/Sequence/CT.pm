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

package Data::IO::Sequence::CT;

use strict;
use Fcntl qw(SEEK_SET);
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::IO::Sequence);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ pseudoknots  => 0,
                   noncanonical => 0,
                   lonelypairs  => 0 }, \%parameters);
    
    $self->_validate();
    
    return ($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->SUPER::_validate();
    
    $self->throw("Pseudoknots parameter must be BOOL") if (!isbool($self->{pseudoknots}));
    $self->throw("Non canonical parameter must be BOOL") if (!isbool($self->{noncanonical}));
    $self->throw("Lonely pairs parameter must be BOOL") if (!isbool($self->{lonelypairs}));

}

sub read {
    
    my $self = shift;
    my $sid = shift if (@_);
    
    my ($fh, $stream, $header, $id,
        $sequence, $energy, $object, $offset,
        $i, $length, @pairs);

    $self->throw("Filehandle is not in read mode") unless ($self->{mode} eq "r");
    $self->throw("Structure ID must be an integer >= 0") if (defined $sid &&
                                                             (!isint($sid) ||
                                                              !ispositive($sid)));
    
    $fh = $self->{_fh};
    $i = @{$self->{_prev}};
    $header = 0;
    
    if (defined $sid) {
        
        if (exists $self->{_index}->{$sid}) {
        
            seek($fh, $self->{_index}->{$sid}, SEEK_SET);
            $i = $sid;
            
        }
        
    }
    
    if (eof($fh)) {
        
        $self->reset() if ($self->{autoreset});
        
        return;
        
    }
    
    $offset = tell($fh);
 
    #push(@{$self->{_prev}}, tell($fh));

    while(<$fh>) {
        
        chomp();
        
        my @line = split(" ");
        
        if ($_ =~ m/ = / || # If the structure has no base-pairs, no ENERGY = field is present
            (@line &&       # Additional control needed for structures with no base-pairs
             @line < 6)) {
            
            $length = $line[0];
                
            next if (!isnumeric($length) ||
                     !ispositive($length) ||
                     !isint($length));
            
            # Index building at runtime

            $self->throw("Non-matching offsets (Offsets: " . $self->{_index}->{$i} . ", " . $offset . ")") if (exists $self->{_index}->{$i} &&
                                                                                                               $self->{_index}->{$i} != $offset &&
                                                                                                               $self->{checkDuplicateIds});

            if (exists $self->{_index}->{$i}) {
    
                my @offsets = map { $self->{_index}->{$_} } sort {$self->{_index}->{$a} <=> $self->{_index}->{$b}} keys %{$self->{_index}};
                @{$self->{_prev}} = grep { $_ <= $offset } @offsets;
                
            }
            else {
                
                $self->{_index}->{$i} = $offset;
                push(@{$self->{_prev}}, $offset);
                
            }
            
            # End of index building block
            
            if ((defined $sid && $i == $sid) ||
                !defined $sid) {
                
                $id = ($_ =~ m/ = / ? $line[4] : $line[1]) || "Structure_" . $i;
                $energy = $line[3] || 0;
                $header = 1;
                    
            }
            else {
                
                $i++;
                
                next;
                
            }
            
        }
        
        if ($header) {
            
            for (0 .. $length - 1) {
                
                my ($sline, @sline);
                chomp($sline = <$fh>);
                @sline = split(" ", $sline);
                
                $sequence .= $sline[1];
                push(@pairs, [$sline[0] - 1, $sline[4] - 1]) if ($sline[4] > $sline[0]);
            
            }
            
            last;
            
        }
    
        $offset = tell($fh);
    
    }
    
    return($self->read()) if (!defined $sequence);
    
    $object = Data::Sequence::Structure->new( id           => $id,
                                              sequence     => $sequence,
                                              energy       => $energy,
                                              basepairs    => \@pairs,
                                              pseudoknots  => $self->{pseudoknots},
                                              noncanonical => $self->{noncanonical},
                                              lonelypairs  => $self->{lonelypairs} );
    
    return($object);
    
}

sub write {
    
    my $self = shift;
    my @sequences = @_ if (@_);

    $self->throw("Filehandle isn't in write/append mode") unless ($self->{mode} =~ m/^w\+?$/);

    foreach my $sequence (@sequences) {
    
        if (!blessed($sequence) ||
            !$sequence->isa("Data::Sequence::Structure")) {
            
            $self->warn("Method requires a valid Data::Sequence::Structure object");
            
            next;
            
        }
    
        my ($fh, $id, $seq, $energy,
            $length, %pairs);
        $fh = $self->{_fh};
        $seq = $sequence->sequence();
        $length = length($seq);
        $energy = $sequence->energy() || 0;
        %pairs = map { $_->[0] => $_->[1],
                       $_->[1] => $_->[0] } $sequence->basepairs();
    
        if (!defined $seq) {
            
            $self->warn("Empty Data::Sequence::Structure object");
            
            next;
            
        }
    
        $self->{_lastid} = 1 unless($self->{_lastid});
    
        if (!defined $sequence->id()) {
            
            $id = "Structure_" . $self->{_lastid};
            $self->{_lastid}++;
        
        }
        else { $id = $sequence->id(); }
    
        $self->SUPER::write(sprintf("%6d", $length) . " ENERGY = " . sprintf("%.2f", $energy) . " " . $id . "\n");
        $self->SUPER::write(sprintf("%6d %s %6d %6d %6d %6d\n", ($_ + 1), substr($seq, $_, 1), $_, ($_ + 2), (exists $pairs{$_} ? $pairs{$_} + 1 : 0), ($_ + 1))) for (0 .. $length - 1);
        
    }
    
}

1;
