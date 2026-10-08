package RF::Data::IO::RC;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;
use Fcntl qw(SEEK_SET SEEK_END);
use POSIX ();
use RF::Data::RC;

use base qw(Data::IO);

use constant EOF => "\x5b\x65\x6f\x66\x72\x63\x5d";
use constant VERSION => 1;

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index          => undef,
                   buildindex     => 0,
                   mappedreads    => 0,
                   blockSize      => 10000,
                   noPreloadIndex => 0,
                   appendable     => 0,
                   _offsets       => {},
                   _lengths       => {},
                   _lastoffset    => 0,
                   _sortedIds     => undef,
                   _lastSeq       => { id       => undef,
                                       sequence => undef } }, \%parameters);

    $self->{binmode} = ":raw";

    $self->_openfh();
    $self->_validate();

    if ($self->mode() ne "w") { # r | w+

        $self->_getReadCount();
        $self->_loadindex() if (!$self->{noPreloadIndex});

    }

    return($self);

}

sub copyIndexFromObject {

    my $self = shift;
    my $obj = shift;

    $self->throw("Object is not a valid RF::Data::IO::RC object") if (blessed($obj) && ref($obj) ne "RF::Data::IO::RC");
    $self->throw("Object is not indexed") if (!keys %{$obj->{_offsets}});

    $self->{_offsets} = clonehashref($obj->{_offsets});
    $self->{_lengths} = clonehashref($obj->{_lengths});
    undef($self->{_sortedIds}); # the cached id order belongs to the previous table

}

sub _validate {

    my $self = shift;

    my ($fh, $eof);
    $fh = $self->{_fh};

    $self->SUPER::_validate();

    $self->throw("File \"" . $self->{file} . "\" is not an RC file") if (lc(substr($self->{file}, -3)) ne ".rc");

    if ($self->mode() =~ /^w/) {

        $self->throw("Total mapped reads must be a positive integer") if (!ispositive($self->{mappedreads}));

        if ($self->mode() eq "w+" && $self->{appendable}) {

            CORE::seek($fh, -7, SEEK_END);
            CORE::read($fh, $eof, 7);

            $self->throw("RC file is not appendable as it already has an EOF") unless ($eof eq EOF);

            $self->reset();

        }

    }
    $self->{index} = $self->{file} . ".rci" if ($self->{buildindex} && defined $self->{file} && !defined $self->{index});

}

sub _loadindex {

    my $self = shift;

    my ($fh, $n, @n);
    $fh = $self->{_fh};

    if (-e $self->{index}) {

        my ($data, $idlen, $id, $offset,
            $index, $size, $position);

        open(my $ih, "<:raw", $self->{index}) or $self->throw("Unable to read from RCI index file (" . $! . ")");

        CORE::read($ih, $index, -s $self->{index});
        CORE::close($ih);

        # The walk is bounded by what was actually read, not by the file size on
        # disk, and every record is bounds-checked before being decoded. A record
        # is 4 bytes of ID length, that many bytes of NUL-terminated ID, and an
        # 8-byte offset. Without these checks a single bad length desynchronizes
        # the walk, and substr() with a negative length then returns a smear of
        # the remaining index instead of an ID
        $size = CORE::length($index);
        $position = 0;

        while($position < $size) {

            $self->throw("Truncated record in RCI index file at byte $position") if ($position + 4 > $size);

            $idlen = unpack("L<", substr($index, $position, 4));
            $position += 4;

            $self->throw("Invalid ID length ($idlen) in RCI index file at byte " . ($position - 4)) if ($idlen < 1);
            $self->throw("Truncated record in RCI index file at byte $position") if ($position + $idlen + 8 > $size);

            $id = substr($index, $position, $idlen - 1); # Drops the "\x00" string terminator
            $position += $idlen;

            $offset = unpack("Q<", substr($index, $position, 8));
            $position += 8;

            $self->{_offsets}->{$id} = $offset; # Stores the offset for ID

            # Validates offset, and picks up the sequence length while there: both
            # sit next to each other, so a single read covers them
            CORE::seek($fh, $offset + 4, SEEK_SET);
            CORE::read($fh, $data, $idlen + 4);

            $self->throw("Invalid offset in RCI index file for transcript \"" . $id . "\"") if (substr($data, 0, $idlen - 1) ne $id);

            $self->{_lengths}->{$id} = unpack("L<", substr($data, $idlen, 4));

        }

    }
    else { # Builds missing index

        my ($data, $idlen, $id, $length);

        $self->_buildIndex();

        if ($self->{buildindex} &&
            defined $self->{index}) {

            open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write RCI index file (" . $! . ")");
            select((select($ih), $|=1)[0]);

            foreach my $id (keys %{$self->{_offsets}}) {

                print $ih pack("L<", length($id) + 1) .                 # len_transcript_id (uint32_t)
                          $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                          pack("Q<", $self->{_offsets}->{$id});         # offset in count table (uint64_t)

            }

            CORE::close($ih);

        }

    }

    $self->reset();

}

sub _buildIndex {

    my $self = shift;

    my ($fh, $offset, $data, $id, 
        $idLen, $length, $size); 
    $fh = $self->{_fh};
    $offset = 0;

    # Computed once here rather than cached on the object: an index may be rebuilt
    # after the file has grown, so the size must be current
    $size = (-s $self->{file}) - 17; # The trailing 8 + 2 + 7 bytes of total mapped reads, RC version and EOF marker

    while($offset < $size) {

        CORE::read($fh, $data, 4);
        $idLen = unpack("L<", $data);

        CORE::read($fh, $data, $idLen);
        $id = substr($data, 0, -1); # Removes the "\x00" string terminator

        CORE::read($fh, $data, 4);
        $length = unpack("L<", $data);

        $self->{_offsets}->{$id} = $offset;
        $self->{_lengths}->{$id} = $length;

        $offset += 4 * ($length * 2 + 3) + length($id) + 1 + ($length + ($length % 2)) / 2;

        CORE::seek($fh, $offset, SEEK_SET);

    }

    $self->reset();

}

sub _getReadCount {

    my $self = shift;

    my ($fh, $n);
    $fh = $self->{_fh};
    CORE::seek($fh, -17, SEEK_END);
    CORE::read($fh, $n, 8);

    # Unpack the 64bit int
    $self->mappedreads(unpack("Q<", $n));

    $self->reset();

}

sub _dataOffsets {

    my $self = shift;
    my $id = shift;

    return if (!defined $id || !exists $self->{_offsets}->{$id});

    my ($start, $length, $seqOffset, $countsOffset);
    $start = $self->{_offsets}->{$id};
    $length = $self->{_lengths}->{$id};

    # Every address below is arithmetic on values already held in memory, so this
    # is cheaper to recompute than to cache: keeping a hashref per transcript costs
    # more in allocation than the arithmetic it saves
    # Record layout:
    #   +0                       len_transcript_id (uint32_t)
    #   +4                       transcript_id     (char[len_transcript_id])
    #   +4+idLen                 len_seq           (uint32_t)
    #   +8+idLen                 seq               (uint8_t[(len_seq+1)/2])
    #   +8+idLen+seqBytes        counts            (uint32_t[len_seq])
    #   +8+idLen+seqBytes+4*len  coverage          (uint32_t[len_seq])
    #   +8+idLen+seqBytes+8*len  mapped_reads      (uint32_t)
    $seqOffset = $start + 4 + CORE::length($id) + 1 + 4;
    $countsOffset = $seqOffset + ($length + ($length % 2)) / 2;

    # Returned as a list rather than a hashref: at one allocation per call this
    # is on the hot path of sequence() and readBytewise()
    return($seqOffset,                  # start of the packed sequence
           ($length + ($length % 2)) / 2, # its size in bytes
           $countsOffset,               # start of the counts array
           $countsOffset + 4 * $length, # start of the coverage array
           $countsOffset + 8 * $length, # position of the mapped read count
           $length);

}

sub readBytewise {

    my $self = shift;
    my ($id, @ranges) = @_;

    return if (!exists $self->{_offsets}->{$id});

    my ($fh, $data, $entry, $length,
        $seqOffset, $seqBytes, $beginArray, $coverageOffset,
        $countOffset, $sequence, @counts, @coverage);
    $fh = $self->{_fh};
    ($seqOffset, $seqBytes, $beginArray, $coverageOffset, $countOffset, $length) = $self->_dataOffsets($id);
    @ranges = sort { $a->[0] <=> $b->[0] } @ranges;

    # There is no point at reading the sequence multiple times if several
    # calls have to be made to readBytewise(), so we save it
    if ($id ne $self->{_lastSeq}->{id}) {

        CORE::seek($fh, $seqOffset, SEEK_SET); # sets the fh to the position of sequence
        CORE::read($fh, $data, $seqBytes);
        $data = unpack("H*", $data);
        $data =~ tr/43210/NTGCA/;

        $self->{_lastSeq} = { id       => $id,
                              sequence => substr($data, 0, $length) };

        $self->throw("Sequence \"$id\" contains invalid characters") if (!isna($self->{_lastSeq}->{sequence}));

        undef($data);

    }

    foreach my $range (@ranges) {

        $self->throw("Ranges must be ARRAY refs") if (ref($range) ne "ARRAY");
        $self->throw("Range outside of sequence boundaries") if ($range->[0] >= $length || $range->[1] >= $length);

        my $rangeLen = $range->[1] - $range->[0] + 1;
        $sequence .= substr($self->{_lastSeq}->{sequence}, $range->[0], $rangeLen);
        CORE::seek($fh, $beginArray + 4 * $range->[0], SEEK_SET);
        CORE::read($fh, $data, 4 * $rangeLen);
        push(@counts, unpack("L<*", $data));
        CORE::seek($fh, $coverageOffset + 4 * $range->[0], SEEK_SET);
        CORE::read($fh, $data, 4 * $rangeLen);
        push(@coverage, unpack("L<*", $data));

    }

    # Reads mapped read count
    CORE::seek($fh, $countOffset, SEEK_SET);
    CORE::read($fh, $data, 4);

    $entry = RF::Data::RC->new( id         => $id,
                                sequence   => $sequence,
                                counts     => \@counts,
                                coverage   => \@coverage,
                                readscount => unpack("L<", $data) );

    return($entry);

}

sub read {

    my $self = shift;
    my $seqid = shift;

    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        $mappedreads, $offset, @stops, @coverage);

    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");

    $fh = $self->{_fh};

    if (defined $seqid) {

        if (exists $self->{_offsets}->{$seqid}) {

            CORE::seek($fh, $self->{_offsets}->{$seqid}, SEEK_SET);

            # The prev array is only needed if ->back() is called after seeking to
            # a specific sequence, so the offset is recorded here and the array is
            # materialized on demand, instead of re-sorting every offset on every seek
            $self->{_prevFrom} = $self->{_offsets}->{$seqid};
            $self->{_prev} = [];

        }
        else { return; }

    }

    $offset = tell($fh);

    if ($offset >= (-s $self->{file}) - 17) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    push(@{$self->{_prev}}, $offset) if (!defined $seqid);

    CORE::read($fh, $data, 4); #read id length
    $idlen = unpack("L<", $data);

    CORE::read($fh, $data, $idlen);
    $id = substr($data, 0, -1);

    CORE::read($fh, $data, 4);
    $length = unpack("L<", $data);

    CORE::read($fh, $data, ($length + ($length % 2)) / 2);
    $data = unpack("H*", $data);
    $data =~ tr/43210/NTGCA/;
    $sequence = substr($data, 0, $length);

    # Index was not loaded before, but we can build it at runtime
    if ($self->{noPreloadIndex}) {

        $self->{_offsets}->{$id} = $offset;
        $self->{_lengths}->{$id} = $length;

    }

    CORE::read($fh, $data, 4 * $length);
    @stops = unpack("L<*", $data);

    CORE::read($fh, $data, 4 * $length);
    @coverage = unpack("L<*", $data);

    CORE::read($fh, $data, 4);
    $mappedreads = unpack("L<", $data);

    $entry = RF::Data::RC->new( id         => $id,
                                sequence   => $sequence,
                                counts     => \@stops,
                                coverage   => \@coverage,
                                readscount => $mappedreads );

    return($entry);

}

sub writeBytewise {

    my $self = shift;
    my ($id, $pos, $counts, $coverage, $readCount) = @_;

    $self->throw("Filehandle isn't in append mode") unless ($self->mode() eq "w+");

    my ($fh, $length, $beginArray, @undef);
    $fh = $self->{_fh};
    $length = $self->{_lengths}->{$id} if (exists $self->{_lengths}->{$id});

    # An undefined issue exists with Perl's threads, that sometimes causes
    # failure in index loading, thus we make a check and reload the index (just in case)
    if (!keys %{$self->{_offsets}}) { $self->_loadindex(); }

    $self->throw("Sequence ID \"" . $id . "\" is absent in file \"" . $self->{file} . "\"") if (!$length);
    $self->throw("Position is negative") if ($pos < 0);
    $self->throw("Position exceeds sequence's length (" . $pos . " >= " . $self->{_lengths}->{$id} . ")") if ($pos >= $length);
    $self->throw("Data exceeds sequence's length") if ($pos + @$counts - 1 >= $length);
    $self->throw("Counts and coverage arrays have unequal lengths") if (@$counts != @$coverage);

    # If there are missing values, we will set them to 0
    @undef = grep { !defined $counts->[$_] } 0 .. $#{$counts};
    @{$counts}[@undef] = (0) x scalar(@undef) if (@undef);
    @undef = grep { !defined $coverage->[$_] } 0 .. $#{$coverage};
    @{$coverage}[@undef] = (0) x scalar(@undef) if (@undef);

    my (undef, undef, $countsOffset, $coverageOffset, $countOffset) = $self->_dataOffsets($id);
    CORE::seek($fh, $countsOffset + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @{$counts});
    CORE::seek($fh, $coverageOffset + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @{$coverage});

    if (defined $readCount) {

        CORE::seek($fh, $countOffset, SEEK_SET);
        print $fh pack("L<", $readCount);

    }

}

sub updateBytewise {

    my $self = shift;
    my ($id, $pos, $counts, $coverage, $code) = @_;

    $self->throw("Filehandle isn't in append mode") unless ($self->mode() eq "w+");

    my ($fh, $length, $beginArray, $entry,
        @undef, @counts, @coverage);
    $fh = $self->{_fh};
    $length = $self->{_lengths}->{$id} if (exists $self->{_lengths}->{$id});
    $code ||= sub { return(sum(@_)); };

    # An undefined issue exists with Perl's threads, that sometimes causes
    # failure in index loading, thus we make a check and reload the index (just in case)
    if (!keys %{$self->{_offsets}}) { $self->_loadindex(); }

    $self->throw("Sequence ID \"" . $id . "\" is absent in file \"" . $self->{file} . "\"") if (!$length);
    $self->throw("Position is negative") if ($pos < 0);
    $self->throw("Position exceeds sequence's length (" . $pos . " >= " . $self->{_lengths}->{$id} . ")") if ($pos >= $length);
    $self->throw("Data exceeds sequence's length") if ($pos + @$counts - 1 >= $length);
    $self->throw("Counts and coverage arrays have unequal lengths") if (@$counts != @$coverage);
    $self->throw("Code is not a CODE reference") if (ref($code) ne "CODE");

    # If there are missing values, we will set them to 0
    @undef = grep { !defined $counts->[$_] } 0 .. $#{$counts};
    @{$counts}[@undef] = (0) x scalar(@undef) if (@undef);
    @undef = grep { !defined $coverage->[$_] } 0 .. $#{$coverage};
    @{$coverage}[@undef] = (0) x scalar(@undef) if (@undef);

    $entry = $self->readBytewise($id, [$pos, $pos + $#{$counts}]);
    @counts = $entry->counts();
    @coverage = $entry->coverage();
    @counts = map { $code->($counts[$_], $counts->[$_]) } 0 .. $#counts;
    @coverage = map { $code->($coverage[$_], $coverage->[$_]) } 0 .. $#coverage;

    my (undef, undef, $countsOffset, $coverageOffset) = $self->_dataOffsets($id);
    CORE::seek($fh, $countsOffset + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @counts);
    CORE::seek($fh, $coverageOffset + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @coverage);

}

sub write {

    my $self = shift;
    my @entries = @_;

    my ($fh, @offsets);
    $fh = $self->{_fh};

    $self->throw("Filehandle isn't in write\/append mode") unless ($self->mode() =~ m/^w/);

    foreach my $entry (@entries) {

        if (!blessed($entry) ||
            !$entry->isa("RF::Data::RC")) {

            $self->warn("Method requires a valid RF::Data::RC object");

            next;

        }

        my ($id, $length, $mappedreads, @counts,
            @coverage);
        $id = $entry->id();
        $length = $entry->length();
        $mappedreads = $entry->readscount();
        @counts = $entry->counts();
        @coverage = $entry->coverage();

        $self->throw("Counts and coverage arrays have different lengths (" . scalar(@counts) . " != " . scalar(@coverage) . ")") if (@counts != @coverage);
        $self->throw("Counts/coverage array length differs from sequence length (" . scalar(@counts) . " != " . $length . ")") if (@counts && @counts != $length);

        if (!$length || !defined $id) {

            $self->warn("Empty RF::Data::RC object");

            next;

        }

        if ($self->mode() eq "w+") {

            # An undefined issue exists with Perl's threads, that sometimes causes
            # failure in index loading, thus we make a check and reload the index (just in case)
            if (!keys %{$self->{_offsets}}) { $self->_loadindex(); }

            $self->throw("Sequence ID \"" . $id . "\" is absent in file \"" . $self->{file} . "\"") if (!exists $self->{_lengths}->{$id});
            $self->throw("Sequence \"" . $id . "\" length differs from sequence in file \"" . $self->{file} . "\"") if ($length != $self->{_lengths}->{$id});

            CORE::seek($fh, ($self->_dataOffsets($id))[2], SEEK_SET);

        }
        else {

            my $compressedSeq = $entry->sequence;
            $compressedSeq =~ tr/NTGCA/43210/;

            print $fh pack("L<", length($id) + 1) .             # len_transcript_id (uint32_t)
                      $id . "\0" .                              # transcript_id (char[len_transcript_id])
                      pack("L<", $length) .                     # len_seq (uint32_t)
                      pack("H*", $compressedSeq);               # seq (uint8_t[(len_seq+1)/2])

        }

        if (@counts) {

            print $fh pack("L<*", @counts, @coverage);          # stops, cov (uint32_t[len_seq x 2])

        }
        else {

            # This is meant for very large sequences (i.e. an entire chromosome)
            if ($length > $self->{blockSize}) {

                my ($nBlocks, $left);
                $nBlocks = POSIX::floor($length / $self->{blockSize});
                $left = $length - ($self->{blockSize} * $nBlocks);

                for (0 .. 1) {

                    print $fh pack("L<*", (0) x $self->{blockSize}) for (1 .. $nBlocks);
                    print $fh pack("L<*", (0) x $left);

                }

            }
            else {

                @counts = (0) x ($length * 2);
                print $fh pack("L<*", @counts);

            }

        }

        print $fh pack("L<", $mappedreads);                     # mapped_reads (uint32_t)

        if ($self->{buildindex} &&
            $self->{mode} ne "w+") {

            $self->{_offsets}->{$id} = $self->{_lastoffset};
            push(@offsets, $self->{_lastoffset});
            $self->{_lastoffset} += 4 * ($length * 2 + 3) + length($id) + 1 + ($length + ($length % 2)) / 2;

        }

    }

    return(wantarray() ? @offsets : \@offsets) if ($self->{buildindex});

}

sub mappedreads {

    my $self = shift;
    my $n = shift;

    $self->throw("Total mapped reads must be a positive integer") if (defined $n &&
                                                                      !ispositive($n));

    $self->{mappedreads} = $n if (defined $n);

    return($self->{mappedreads});

}

sub close {

    my $self = shift;

    if ($self->mode() =~ m/^w/) {

        my ($fh, $eof);
        $fh = $self->{_fh};

        if ($self->{mode} eq "w+") {

            CORE::seek($fh, -7, SEEK_END);
            CORE::read($fh, $eof, 7);
            CORE::seek($fh, 0, SEEK_END);

        }

        if ($eof ne EOF && !$self->{appendable}) {

            print $fh pack("Q<", $self->{mappedreads}) .  # Total mapped reads (64bit int)
                      pack("S<", VERSION) .
                      EOF; # EOF Marker

        }
        elsif ($eof eq EOF) {

            CORE::seek($fh, -17, SEEK_END);
            print $fh pack("Q<", $self->{mappedreads});

        }

        if ($self->{buildindex} &&
            defined $self->{index}) {

            open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write RCI index (" . $! . ")");
            select((select($ih), $|=1)[0]);

            foreach my $id (sort {$self->{_offsets}->{$a} <=> $self->{_offsets}->{$b}} keys %{$self->{_offsets}}) {

                print $ih pack("L<", length($id) + 1) .                 # len_transcript_id (uint32_t)
                          $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                          pack("Q<", $self->{_offsets}->{$id});         # offset in count table (uint64_t)

            }

            CORE::close($ih);

        }

    }

    $self->SUPER::close();

}

sub ids {

    my $self = shift;

    if (!keys %{$self->{_offsets}}) {

        if (!$self->{noPreloadIndex}) { $self->_buildIndex(); }
        else { $self->throw("Method requires an indexed file, but noPreloadIndex is TRUE"); }

    }

    # The sorted id list only changes when the offset table does, so it is cached
    # instead of being re-sorted on every call
    if (!defined $self->{_sortedIds} ||
        @{$self->{_sortedIds}} != keys %{$self->{_offsets}}) {

        $self->{_sortedIds} = [ sort {$self->{_offsets}->{$a} <=> $self->{_offsets}->{$b}} keys %{$self->{_offsets}} ];

    }

    return(wantarray() ? @{$self->{_sortedIds}} : [ @{$self->{_sortedIds}} ]);

}

sub length {

    my $self = shift;
    my $id = shift;

    if (!keys %{$self->{_offsets}}) {

        if (!$self->{noPreloadIndex}) { $self->_buildIndex(); }
        else { $self->throw("Method requires an indexed file, but noPreloadIndex is TRUE"); }

    }

    return() if (!defined $id || !exists $self->{_lengths}->{$id});

    return($self->{_lengths}->{$id});

}

sub sequence {

    my $self = shift;
    my ($id, $start, $end) = @_;

    if (!keys %{$self->{_offsets}}) {

        if (!$self->{noPreloadIndex}) { $self->_buildIndex(); }
        else { $self->throw("Method requires an indexed file, but noPreloadIndex is TRUE"); }

    }

    return if (!defined $id || !exists $self->{_lengths}->{$id} ||
               (defined $start && $start >= $self->{_lengths}->{$id}) ||
               (defined $end && $end >= $self->{_lengths}->{$id}));

    my ($fh, $length, $sequence);
    $fh = $self->{_fh};
    $start ||= 0;
    $length = $self->{_lengths}->{$id};
    $end ||= $length - 1;
    my ($seqOffset, $seqBytes) = $self->_dataOffsets($id);
    CORE::seek($fh, $seqOffset, SEEK_SET); # sets the fh to the position of sequence
    CORE::read($fh, $sequence, $seqBytes);
    $sequence = unpack("H*", $sequence);
    $sequence =~ tr/43210/NTGCA/;

    return(substr($sequence, $start, $end - $start + 1));

}

1;
