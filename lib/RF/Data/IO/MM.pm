package RF::Data::IO::MM;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);

use constant EOF => "\x5b\x6d\x6d\x65\x6f\x66\x5d";

use base qw(Data::IO);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index          => undef,
                   appendable     => 0,
                   _mappedreads   => 0,
                   _offsets       => {},
                   _lengths       => {},
                   _lastoffset    => 0,
                   _lastId        => undef,
                   _streamOffsets => {},
                   _streamStarts  => {} }, \%parameters);

    $self->{binmode} = ":raw";

    $self->_openfh();
    $self->_validate();
    $self->_loadindex() if ($self->{mode} ne "w");

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("File \"" . $self->{file} . "\" is not an MM file") if (lc(substr($self->{file}, -3)) ne ".mm");

    if ($self->{mode} eq "w+") {

        my ($fh, $eof);
        $fh = $self->{_fh};

        CORE::seek($fh, -7, SEEK_END);
        CORE::read($fh, $eof, 7);
        CORE::seek($fh, 0, SEEK_END);

        $self->throw("EOF already present") if ($eof eq EOF);

    }

     $self->SUPER::_validate();

}

sub _loadindex {

    my $self = shift;

    my $fh = $self->{_fh};

    if ($self->{mode} eq "r" && defined $self->{index} && -e $self->{index}) {

        my ($data, $idlen, $id, $offset);

        open(my $ih, "<:raw", $self->{index}) or $self->throw("Unable to read from MMI index file (" . $! . ")");
        while(!eof($ih)) {

            CORE::read($ih, $data, 2);
            $idlen = unpack("S<", $data);

            CORE::read($ih, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            CORE::read($ih, $data, 8);
            $offset = unpack("Q<", $data);
            $self->{_offsets}->{$id}->{start} = $offset; # Stores the start offset for ID

            CORE::read($ih, $data, 8);
            $offset = unpack("Q<", $data);
            $self->{_offsets}->{$id}->{end} = $offset; # Stores the end offset for ID

        }
        CORE::close($ih);

    }

}

sub _header {

    my $self = shift;
    my $id = shift;

    my $entry = $self->{_offsets}->{$id};

    return($entry) if (defined $entry && exists $entry->{seqOffset});
    return if (!defined $id || !defined $entry);

    my ($fh, $data, $start, $idLen,
        $length, $seqOffset, $seqBytes);
    $fh = $self->{_fh};
    $start = $entry->{start};

    # Record layout:
    # +0                     len_transcript_id (uint16_t)
    # +2                     transcript_id     (char[len_transcript_id])
    # +2+idLen               len_seq           (uint32_t)
    # +2+idLen+4             seq               (uint8_t[(len_seq+1)/2])
    # +2+idLen+4+seqBytes    n_reads           (uint32_t)
    # +2+idLen+4+seqBytes+4  reads
    # Only the two variable-length fields have to be read; every other address is
    # arithmetic, so this is done once per transcript and the addresses are kept
    CORE::seek($fh, $start, SEEK_SET);
    CORE::read($fh, $data, 2);
    $idLen = unpack("S<", $data);

    CORE::seek($fh, $idLen, SEEK_CUR);
    CORE::read($fh, $data, 4);
    $length = unpack("L<", $data);

    $seqOffset = $start + 2 + $idLen + 4;
    $seqBytes = ($length + ($length % 2)) / 2;

    $entry->{length} = $length;
    $entry->{seqOffset} = $seqOffset;
    $entry->{seqBytes} = $seqBytes;
    $entry->{countOffset} = $seqOffset + $seqBytes;
    $entry->{readsOffset} = $seqOffset + $seqBytes + 4;

    $self->{_lengths}->{$id} = $length;

    return($entry);

}

sub read {

    my $self = shift;
    my $seqid = shift;

    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        $mappedreads, $offset, @reads);

    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");

    $fh = $self->{_fh};

    if (defined $seqid) {

        if (exists $self->{_offsets}->{$seqid}->{start}) { CORE::seek($fh, $self->{_offsets}->{$seqid}->{start}, SEEK_SET); }
        else { return; }

    }

    $offset = tell($fh);

    # Checks whether MMEOF marker has been reached
    CORE::read($fh, $eightbytes, 7);
    CORE::seek($fh, $offset, SEEK_SET);

    if ($eightbytes eq EOF || eof($fh)) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    CORE::read($fh, $data, 2); #read id length
    $idlen = unpack("S<", $data);

    CORE::read($fh, $data, $idlen);
    $id = substr($data, 0, -1);

    # A duplicate ID re-assigns the start offset, so any addresses previously
    # derived from the old one must be dropped
    if (exists $self->{_offsets}->{$id} &&
        exists $self->{_offsets}->{$id}->{seqOffset} &&
        $self->{_offsets}->{$id}->{start} != $offset) {

        delete(@{$self->{_offsets}->{$id}}{qw(length seqOffset seqBytes countOffset readsOffset)});
        delete($self->{_lengths}->{$id});
        delete($self->{_streamOffsets}->{$id});
        delete($self->{_streamStarts}->{$id});

    }

    $self->{_offsets}->{$id}->{start} = $offset;

    CORE::read($fh, $data, 4);
    $length = unpack("L<", $data);

    CORE::read($fh, $data, ($length + ($length % 2)) / 2);
    $data = unpack("H*", $data);
    $data =~ tr/43210/NTGCA/;
    $sequence = substr($data, 0, $length);

    CORE::read($fh, $data, 4);
    $mappedreads = unpack("L<", $data);

    for (1 .. $mappedreads) {

        my ($start, $end, $nMutations, @mutations);
        CORE::read($fh, $data, 12);
        ($start, $end, $nMutations) = unpack("L<*", $data);
        CORE::read($fh, $data, 4 * $nMutations);
        @mutations = unpack("L<*", $data);

        push(@reads, [ $start, $end, \@mutations ]);

    }

    $self->{_offsets}->{$id}->{end} = tell($fh);

    return($id, $sequence, \@reads);

}

sub readStream {

    my $self = shift;
    my $id = shift;

    $self->throw("No transcript ID specified") if (!defined $id);

    return if (!$id || !exists $self->{_offsets}->{$id});

    my ($fh, $data);
    $fh = $self->{_fh};

    if (!exists $self->{_streamOffsets}->{$id}) {

        my $entry = $self->_header($id);

        return if (!defined $entry);

        $self->{_streamStarts}->{$id} = $entry->{readsOffset};
        $self->{_streamOffsets}->{$id} = $entry->{readsOffset};

    }

    # Consecutive reads on the same transcript are already sequential, so
    # seeking every time only flushes the PerlIO buffer for nothing
    CORE::seek($fh, $self->{_streamOffsets}->{$id}, SEEK_SET) if (tell($fh) != $self->{_streamOffsets}->{$id});

    if (tell($fh) < $self->{_offsets}->{$id}->{end}) {

        my ($start, $end, $nMutations, @mutations);
        CORE::read($fh, $data, 12);
        ($start, $end, $nMutations) = unpack("L<*", $data);
        CORE::read($fh, $data, 4 * $nMutations);
        @mutations = unpack("L<*", $data);

        $self->{_streamOffsets}->{$id} = tell($fh);

        return($start, $end, \@mutations);

    }
    else {

        $self->{_streamOffsets}->{$id} = $self->{_streamStarts}->{$id};

        return;

    }

}

sub resetStream {

    my $self = shift;
    my $id = shift;

    if (defined $id) { $self->{_streamOffsets}->{$id} = $self->{_streamStarts}->{$id} if (exists $self->{_streamStarts}->{$id}); }
    else { 

        undef($self->{_streamOffsets});
        %{$self->{_streamOffsets}} = map { $_ => $self->{_streamStarts}->{$_} } keys %{$self->{_streamStarts}}; 
        
    }

}

sub append_transcript {

    my $self = shift;
    my ($id, $sequence) = @_;

    $self->throw("Filehandle isn't in write\/append mode") unless ($self->mode() =~ /^w/);
    $self->throw("No transcript ID provided") if (!$id);
    $self->throw("No transcript's sequence provided") if (!$sequence);
    $self->throw("Transcript's sequence contains invalid characters") if (!isna($sequence));

    my $fh = $self->{_fh};
    $sequence = rna2dna($sequence);

    $self->_updatereadscount();

    $self->{_lastId} = $id;
    $self->{_offsets}->{$id}->{start} = tell($fh);  # Saves offset for index generation
    $sequence =~ tr/NTGCA/43210/;

    print $fh pack("S<", length($id) + 1) .             # len_transcript_id (uint16_t)
              $id . "\0" .                              # transcript_id (char[len_transcript_id])
              pack("L<", length($sequence)) .           # len_seq (uint32_t)
              pack("H*", $sequence);                    # seq (uint8_t[(len_seq+1)/2])

    $self->{_lastoffset} = tell($fh); # Saves offset for updating number of reads

    print $fh pack("L<", 0); # Sets number of mapped reads to 0 for the moment

    $self->{_offsets}->{$id}->{end} = tell($fh); 

}

sub append_read {

    my $self = shift;
    my ($start, $end, $n, $indexes) = @_;

    $self->throw("A transcript must be appended before reads can") if (!defined $self->{_lastId});
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

    $self->{_offsets}->{$self->{_lastId}}->{end} = tell($fh);

    $self->{_mappedreads}++;    # Increases count of reads mapping on transcript

}

sub _updatereadscount {

    my $self = shift;

    my $fh = $self->{_fh};

    if ($self->{_lastoffset}) {

        CORE::seek($fh, $self->{_lastoffset}, SEEK_SET);
        print $fh pack("L<", $self->{_mappedreads});
        CORE::seek($fh, 0, SEEK_END);

        $self->{_mappedreads} = 0;

    }

}

sub buildIndex {

    my $self = shift;

    $self->throw("Index building requires read or append mode") if ($self->{mode} !~ /^(?:r|w\+)$/);

    $self->{index} = $self->{file} . ".mmi" if (!defined $self->{index});

    my ($fh, $eightbytes);
    $fh = $self->{_fh};

    CORE::seek($fh, 0, SEEK_SET);

    while ($eightbytes ne EOF && !eof($fh)) {

        my ($offset, $data, $idLen, $id,
            $length, $nReads);
        $offset = tell($fh);

        CORE::read($fh, $data, 2); #read id length
        $idLen = unpack("S<", $data);

        CORE::read($fh, $data, $idLen);
        $id = substr($data, 0, -1);

        if (exists $self->{_offsets}->{$id} &&
            exists $self->{_offsets}->{$id}->{seqOffset} &&
            $self->{_offsets}->{$id}->{start} != $offset) {

            delete(@{$self->{_offsets}->{$id}}{qw(length seqOffset seqBytes countOffset readsOffset)});
            delete($self->{_lengths}->{$id});
            delete($self->{_streamOffsets}->{$id});
            delete($self->{_streamStarts}->{$id});

        }

        $self->{_offsets}->{$id}->{start} = $offset;

        CORE::read($fh, $data, 4);
        $length = unpack("L<", $data);

        CORE::seek($fh, ($length + ($length % 2)) / 2, SEEK_CUR);

        CORE::read($fh, $data, 4);
        $nReads = unpack("L<", $data);

        for (1 .. $nReads) {

            my ($start, $end, $nMutations);
            CORE::read($fh, $data, 12);
            ($start, $end, $nMutations) = unpack("L<*", $data);
            CORE::seek($fh, 4 * $nMutations, SEEK_CUR);

        }

        $self->{_offsets}->{$id}->{end} = tell($fh); 

        if (!eof($fh)) {

            CORE::read($fh, $eightbytes, 7);
            CORE::seek($fh, -7, SEEK_CUR);

        }

    }

    $self->_writeIndex() if (keys %{$self->{_offsets}});

}

sub _writeIndex {

    my $self = shift;

    open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write MMI index (" . $! . ")");
    select((select($ih), $|=1)[0]);

    foreach my $id (sort {$self->{_offsets}->{$a}->{start} <=> $self->{_offsets}->{$b}->{start}} keys %{$self->{_offsets}}) {

        print $ih pack("S<", length($id) + 1) .                            # len_transcript_id (uint16_t)
                  $id . "\0" .                                            # transcript_id (char[len_transcript_id])
                  pack("Q<", $self->{_offsets}->{$id}->{start}) .         # offset start (uint64_t)
                  pack("Q<", $self->{_offsets}->{$id}->{end});            # offset end (uint64_t)

    }

    CORE::close($ih);

}

sub close {

    my $self = shift;

    my $fh = $self->{_fh};

    if ($self->{mode} ne "r") {

        my ($eof);

        $self->_updatereadscount();

        if ($self->{mode} eq "w+") {

            CORE::seek($fh, -7, SEEK_END);
            CORE::read($fh, $eof, 7);
            CORE::seek($fh, 0, SEEK_END);

        }

        print $fh EOF if ($eof ne EOF && !$self->{appendable});

    }

    $self->_writeIndex() if (defined $self->{index} && keys %{$self->{_offsets}});

    $self->SUPER::close();

}

sub ids {

    my $self = shift;

    my @ids = sort keys %{$self->{_offsets}};

    return(wantarray() ? @ids : \@ids);

}

sub length {

    my $self = shift;
    my $id = shift;

    return if (!defined $id || !exists $self->{_offsets}->{$id});

    return($self->{_lengths}->{$id}) if (exists $self->{_lengths}->{$id});

    my $entry = $self->_header($id);

    return if (!defined $entry);

    return($entry->{length});

}

sub sequence {

    my $self = shift;
    my $id = shift;

    return if (!defined $id || !exists $self->{_offsets}->{$id});

    my ($fh, $data, $entry, $cached);
    $cached = exists $self->{_offsets}->{$id}->{seqOffset};
    $entry = $self->_header($id);

    return if (!defined $entry);

    # _header() leaves the filehandle on the sequence block, so a seek is only
    # needed when the addresses came from the cache
    $fh = $self->{_fh};
    CORE::seek($fh, $entry->{seqOffset}, SEEK_SET) if ($cached);

    CORE::read($fh, $data, $entry->{seqBytes});
    $data = unpack("H*", $data);
    $data =~ tr/43210/NTGCA/;

    return(substr($data, 0, $entry->{length}));

}

sub readCount {

    my $self = shift;
    my $id = shift;

    return if (!defined $id || !exists $self->{_offsets}->{$id});

    my ($fh, $data, $entry, $cached);
    $cached = exists $self->{_offsets}->{$id}->{seqOffset};
    $entry = $self->_header($id);

    return if (!defined $entry);

    $fh = $self->{_fh};

    # Cached addresses allow seeking straight to the read count, otherwise the
    # filehandle already sits on the sequence block, which is cheaper to read
    # through than to seek past
    if ($cached) { CORE::seek($fh, $entry->{countOffset}, SEEK_SET); }
    else { CORE::read($fh, $data, $entry->{seqBytes}); }

    CORE::read($fh, $data, 4);

    return(unpack("L<", $data));

}

1;