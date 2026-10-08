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

use base qw(Data::IO::Sequence::FastaLike);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ }, \%parameters);

    $self->_validate();

    return($self);

}

sub read {

    my $self = shift;
    my $tsid = @_ ? shift : undef;

    my ($offset, $stream, $id, $fullId,
        $sequence, $entry, $description, @id);
    ($offset, $stream) = $self->SUPER::read($tsid);

    return unless($stream);

    foreach my $line (split(/\n/, $stream)) {

        next if ($line =~ m/^\s*$/ ||
                 $line =~ m/^#/);

        if (!defined $fullId) {

            $fullId = $line;
            $fullId =~ s/^>//;
            $fullId = striptags($fullId) if ($self->{_remote});

            next;

        }

        $sequence .= $line;

    }

    @id = split(" ", $fullId);
    $id = shift(@id);
    $description = join(" ", @id);
    $sequence = striptags($sequence) if ($self->{_remote});
    $sequence =~ s/[\s\r>]//g;

    return($self->read()) if (!defined $sequence ||
                              !isseq($sequence, "-"));

    $self->_buildIndex($id, $offset, length($sequence), $stream);

    $entry = Data::Sequence->new( id          => $id,
                                  fullId      => $fullId,
                                  description => $description,
                                  sequence    => $sequence,
                                  maskIUPAC   => $self->{maskIUPAC} );

    return($entry);

}

1;
