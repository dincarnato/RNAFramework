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
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::IO::Sequence::FastaLike);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ pseudoknots  => 0,
                   noncanonical => 0,
                   lonelypairs  => 0 }, \%parameters);

    $self->_validate();

    return($self);

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
    my $tsid = @_ ? shift : undef;

    my ($offset, $stream, $id, $fullId,
        $sequence, $structure, $energy, $entry,
        $description, @id);
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

        $line =~ s/^\s*|\s*$//g;

        if (isseq($line, "-")) { $sequence .= $line; }
        elsif (isdotbracket($line)) { $structure .= $line; }
        else {

            # In case free energy is appended to structure
            if ($line =~ m/\s*\(\s*([\+-]?[\d\.]+)\)$/) {

                $energy = $1;
                $line =~ s/\s*\(\s*[\+-]?[\d\.]+\)$//;
                $line =~ s/\s*$//;

                if (isdotbracket($line)) {

                    $structure .= $line;

                    last;

                }

            }

            return($self->read());

        }

    }

    @id = split(" ", $fullId);
    $id = shift(@id);
    $description = join(" ", @id);
    $sequence = striptags($sequence) if ($self->{_remote});
    $sequence =~ s/[\s\r>]//g;

    return($self->read()) if (!defined $sequence ||
                              !defined $structure ||
                              length($sequence) != length($structure) ||
                              !isdbbalanced($structure));

    $self->_buildIndex($id, $offset, length($sequence), $stream);

    $entry = Data::Sequence::Structure->new( id           => $id,
                                             fullId       => $fullId,
                                             description  => $description,
                                             sequence     => $sequence,
                                             structure    => $structure,
                                             energy       => $energy,
                                             pseudoknots  => $self->{pseudoknots},
                                             noncanonical => $self->{noncanonical},
                                             lonelypairs  => $self->{lonelypairs},
                                             maskIUPAC    => $self->{maskIUPAC} );

    return($entry);

}

sub write {

    my $self = shift;
    my @entries = @_;

    my (@valid);

    # entries are collected into a new list rather than spliced out of the one
    # being walked, which would skip the element following each removal
    foreach my $entry (@entries) {

        if (!blessed($entry) ||
            !$entry->isa("Data::Sequence::Structure")) {

            $self->warn("Entry is not a Data::Sequence::Structure object");

            next;

        }
        elsif (!defined $entry->structure()) {

            $self->warn("Entry misses structure");

            next;

        }

        push(@valid, $entry);

    }

    $self->SUPER::write(@valid);

}

1;
