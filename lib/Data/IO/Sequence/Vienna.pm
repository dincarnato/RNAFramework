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

}

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

            if (keys %{$self->{_index}}) {

                $self->warn("Cannot find sequence \"" . $tsid . "\" in file");

                return;

            }
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

    chomp($stream);

    foreach my $line (split(/\n/, $stream)) {

        next if ($line =~ m/^\s*$/ ||
                 $line =~ m/^#/);

        if (!defined $header) {

            $header = $line;
            $header =~ s/^>//;

            next;

        }

        last if ($line =~ m/^>$/);

        if (isseq($line, "-")) { $sequence .= $line; }
        elsif (isdotbracket($line)) { $structure .= $line; }
        else {

            # In case free energy is appended to structure
            if ($line =~ m/\s*\(\s*([\+-]?\d+\.\d+)\)$/) {

                $energy = $1;
                $line =~ s/\s*\(\s*[\+-]?\d+\.\d+\)$//;

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

    if (exists $self->{_index}->{$id}) {

        my @offsets = map { $self->{_index}->{$_} } sort {$self->{_index}->{$a} <=> $self->{_index}->{$b}} keys %{$self->{_index}};
        @{$self->{_prev}} = grep { $_ <= $offset } @offsets;

    }
    else {

        $self->{_index}->{$id} = $offset;
        push(@{$self->{_prev}}, $offset);

    }

    $object = Data::Sequence::Structure->new( id           => $id,
                                              name         => $header,
                                              gi           => $gi,
                                              accession    => $accession,
                                              version      => $version,
                                              sequence     => $sequence,
                                              description  => $description,
                                              structure    => $structure,
                                              energy       => $energy,
                                              pseudoknots  => $self->{pseudoknots},
                                              noncanonical => $self->{noncanonical},
                                              lonelypairs  => $self->{lonelypairs} );

    return($object);

}

sub write {

    my $self = shift;
    my @sequences = @_ if (@_);

    $self->throw("Filehandle isn't in write/append mode") unless ($self->mode() =~ m/^w\+?$/);

    foreach my $sequence (@sequences) {

        if (!blessed($sequence) ||
            !$sequence->isa("Data::Sequence::Structure")) {

            $self->warn("Method requires a valid Data::Sequence::Structure object");

            next;

        }

        my ($fh, $id, $seq, $db,
            $energy);
        $fh = $self->{_fh};
        $seq = $sequence->sequence();
        $db = $sequence->structure() || "." x length($seq);
        $energy = $sequence->energy() || 0;

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

        $self->SUPER::write(join("\n", ">" . $id, $seq, $db . " (" . sprintf("%.2f", $energy) . ")") . "\n");

    }

}

1;
