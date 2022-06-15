package RF::Data::IO::MM;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use Fcntl qw(SEEK_SET SEEK_END);

use constant EOF => "\x5b\x6d\x6d\x65\x6f\x66\x5d";

use base qw(Data::IO);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index        => undef,
                   mode         => "w",
                   _mappedreads => 0,
                   _offsets     => {},
                   _lastoffset  => 0 }, \%parameters);

    $self->{binmode} = ":raw";

    $self->{mode} =~ s/\+$//; # Automatically change append mode to write
    #$self->throw("Filehandle isn't in write mode") if ($self->mode() ne "w");

    $self->_openfh();
    $self->_validate();
    $self->_loadindex();

    return($self);

}

sub _validate {

    my $self = shift;

    my ($fh, $eof);
    $fh = $self->{_fh};

    $self->SUPER::_validate();

    $self->{index} = $self->{file} . ".mmi" if (defined $self->{file} &&
                                                !defined $self->{index} &&
                                                $self->{mode} eq "r");

}

sub _loadindex {

    my $self = shift;

    my $fh = $self->{_fh};

    if ($self->{mode} eq "r" && defined $self->{index} && -e $self->{index}) {

        my ($data, $idlen, $id, $offset);

        open(my $ih, "<:raw", $self->{index}) or $self->throw("Unable to read from MMI index file (" . $! . ")");
        while(!eof($ih)) {

            read($ih, $data, 2);
            $idlen = unpack("S<", $data);

            read($ih, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            read($ih, $data, 8);
            $offset = unpack("Q<", $data);
            $self->{_offsets}->{$id} = $offset; # Stores the offset for ID

            # Uncomment these to validates offset (slow)
            #seek($fh, $offset + 2, SEEK_SET);
            #read($fh, $data, $idlen);

            #$self->throw("Invalid offset in MMI index file for transcript \"" . $id . "\"") if (substr($data, 0, -1) ne $id);

        }
        close($ih);

    }

}

sub read {

    my $self = shift;
    my $seqid = shift if (@_);

    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        $mappedreads, $offset, @reads);

    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");

    $fh = $self->{_fh};

    if (defined $seqid) {

        if (exists $self->{_offsets}->{$seqid}) { seek($fh, $self->{_offsets}->{$seqid}, SEEK_SET); }
        else { return; }

    }

    $offset = tell($fh);

    # Checks whether MMEOF marker has been reached
    read($fh, $eightbytes, 7);
    seek($fh, $offset, SEEK_SET);

    if ($eightbytes eq EOF) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    read($fh, $data, 2); #read id length
    $idlen = unpack("S<", $data);

    read($fh, $data, $idlen);
    $id = substr($data, 0, -1);

    $self->{_offsets}->{$id} = $offset;

    read($fh, $data, 4);
    $length = unpack("L<", $data);

    read($fh, $data, ($length + ($length % 2)) / 2);
    $data = unpack("H*", $data);
    $data =~ tr/43210/NTGCA/;
    $sequence = substr($data, 0, $length);

    read($fh, $data, 4);
    $mappedreads = unpack("L<", $data);

    for (1 .. $mappedreads) {

        my ($start, $end, $nMutations, @mutations);
        read($fh, $data, 12);
        ($start, $end, $nMutations) = unpack("L<*", $data);
        read($fh, $data, 4 * $nMutations);
        @mutations = unpack("L<*", $data);

        push(@reads, [ $start, $end, \@mutations ]);

    }

    return($id, $sequence, \@reads);

}

sub append_transcript {

    my $self = shift;
    my ($id, $sequence) = @_ if (@_);

    $self->throw("No transcript ID provided") if (!$id);
    $self->throw("No transcript's sequence provided") if (!$sequence);
    $self->throw("Transcript's sequence contains invalid characters") if (!isna($sequence));

    my $fh = $self->{_fh};
    $sequence = rna2dna($sequence);

    $self->throw("Filehandle isn't in write\/append mode") unless ($self->mode() =~ m/^w/);

    $self->_updatereadscount();

    $self->{_offsets}->{$id} = tell($fh);  # Saves offset for index generation
    $sequence =~ tr/NTGCA/43210/;

    print $fh pack("S<", length($id) + 1) .             # len_transcript_id (uint16_t)
              $id . "\0" .                              # transcript_id (char[len_transcript_id])
              pack("L<", length($sequence)) .           # len_seq (uint32_t)
              pack("H*", $sequence);                    # seq (uint8_t[(len_seq+1)/2])

    $self->{_lastoffset} = tell($fh); # Saves offset for updating number of reads

    print $fh pack("L<", 0); # Sets number of mapped reads to 0 for the moment

}

sub append_read {

    my $self = shift;
    my ($start, $end, $n, $indexes) = @_ if (@_);

    $self->throw("Read's start mapping position must be a positive integer") if (!isint($start));
    $self->throw("Read's end mapping position must be a positive integer") if (!isint($end));
    $self->throw("Number of read's mismatches must be a positive integer") if (!isint($n));
    $self->throw("Read's mismatch indexes must be provided as an ARRAY reference") if (ref($indexes) ne "ARRAY");
    $self->throw("Number of read's mismatches differs from indexes count") if ($n != @{$indexes});

    my ($fh, @indexes);
    $fh = $self->{_fh};
    @indexes = sort {$a <=> $b} @{$indexes};

    print $fh pack("L<*", $start, $end, $n);
    print $fh pack("L<*", @indexes) if ($n);

    $self->{_mappedreads}++;    # Increases count of reads mapping on transcript

}

sub _updatereadscount {

    my $self = shift;

    my $fh = $self->{_fh};

    if ($self->{_lastoffset}) {

        seek($fh, $self->{_lastoffset}, SEEK_SET);
        print $fh pack("L<", $self->{_mappedreads});
        seek($fh, 0, SEEK_END);

        $self->{_mappedreads} = 0;

    }

}

sub close {

    my $self = shift;

    my $fh = $self->{_fh};

    $self->_updatereadscount();

    print $fh EOF; # EOF Marker

    if (defined $self->{index} && !-e $self->{index}) {

        open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write MMI index (" . $! . ")");
        select((select($ih), $|=1)[0]);

        foreach my $id (sort {$self->{_offsets}->{$a} <=> $self->{_offsets}->{$b}} keys %{$self->{_offsets}}) {

            print $ih pack("S<", length($id) + 1) .                 # len_transcript_id (uint16_t)
                      $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                      pack("Q<", $self->{_offsets}->{$id});         # offset in count table (uint64_t)

        }

        close($ih);

    }

    $self->SUPER::close();

}

1;
