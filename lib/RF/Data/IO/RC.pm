package RF::Data::IO::RC;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Fcntl qw(SEEK_SET SEEK_END);
use POSIX ();
use RF::Data::RC;

use base qw(Data::IO);

use constant EOF => "\x5b\x65\x6f\x66\x72\x63\x5d";
use constant VERSION => 1;

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index          => undef,
                   buildindex     => 0,
                   mappedreads    => 0,
                   blockSize      => 10000,
                   noPreloadIndex => 0,
                   _offsets       => {},
                   _lengths       => {},
                   _lastoffset    => 0,
                   _lastSeq       => { id       => undef,
                                       sequence => undef } }, \%parameters);

    $self->{binmode} = ":raw";

    $self->_openfh();
    $self->_validate();
    $self->_loadindex() if ($self->mode() ne "w" && !$self->{noPreloadIndex}); # r | w+

    return($self);

}

sub _validate {

    my $self = shift;

    my ($fh, $eof);
    $fh = $self->{_fh};

    $self->SUPER::_validate();

    if ($self->mode() eq "r") {

        seek($fh, -7, SEEK_END);
        read($fh, $eof, 7);

        $self->throw("Invalid RC file (EOF marker is absent)") unless ($eof eq EOF);

        $self->reset();

    }
    else { $self->throw("Total mapped reads must be a positive integer") if (!ispositive($self->{mappedreads})); }

    $self->{index} = $self->{file} . ".rci" if ($self->{buildindex} &&
                                                defined $self->{file} &&
                                                !defined $self->{index});

}

sub _loadindex {

    my $self = shift;

    my ($fh, $n, @n);
    $fh = $self->{_fh};

    if (-e $self->{index}) {

        my ($data, $idlen, $id, $offset);

        open(my $ih, "<:raw", $self->{index}) or $self->throw("Unable to read from RCI index file (" . $! . ")");
        while(!eof($ih)) {

            read($ih, $data, 4);
            $idlen = unpack("L<", $data);

            read($ih, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            read($ih, $data, 8);
            $offset = unpack("Q<", $data);
            $self->{_offsets}->{$id} = $offset; # Stores the offset for ID

            # Validates offset
            seek($fh, $offset + 4, SEEK_SET);
            read($fh, $data, $idlen);

            $self->throw("Invalid offset in RCI index file for transcript \"" . $id . "\"") if (substr($data, 0, -1) ne $id);

            read($fh, $data, 4);
            $self->{_lengths}->{$id} = unpack("L<", $data);

        }
        close($ih);

    }
    else { # Builds missing index

        my ($data, $offset, $idlen, $id,
            $length);
        $offset = 0;

        while($offset < (-s $self->{file}) - 17) { # While the 8 + 2 + 7 bytes of total mapped reads + RC version + EOF Marker are reached

            read($fh, $data, 4);
            $idlen = unpack("L<", $data);

            read($fh, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            read($fh, $data, 4);
            $length = unpack("L<", $data);

            $self->{_offsets}->{$id} = $offset;
            $self->{_lengths}->{$id} = $length;

            $offset += 4 * ($length * 2 + 3) + length($id) + 1 + ($length + ($length % 2)) / 2;

            seek($fh, $offset, SEEK_SET);

        }

        if ($self->{buildindex} &&
            defined $self->{index}) {

            open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write RCI index file (" . $! . ")");
            select((select($ih), $|=1)[0]);

            foreach my $id (keys %{$self->{_offsets}}) {

                print $ih pack("L<", length($id) + 1) .                 # len_transcript_id (uint32_t)
                          $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                          pack("Q<", $self->{_offsets}->{$id});         # offset in count table (uint64_t)

            }

            close($ih);

        }

    }

    seek($fh, -17, SEEK_END);
    read($fh, $n, 8);

    # Unpack the 64bit int
    $self->mappedreads(unpack("Q<", $n));

    $self->reset();

}

sub readBytewise {

    my $self = shift;
    my ($id, @ranges) = @_ if (@_);

    return if (!exists $self->{_offsets}->{$id});

    my ($fh, $data, $entry, $length,
        $beginArray, $sequence, @counts, @coverage);
    $fh = $self->{_fh};
    $length = $self->{_lengths}->{$id};
    $beginArray = $self->{_offsets}->{$id} + 8 + length($id) + 1 + ($length + ($length % 2)) / 2;
    @ranges = sort { $a->[0] <=> $b->[0] } @ranges;

    # There is no point at reading the sequence multiple times if several
    # calls have to be made to readBytewise(), so we save it
    if ($id ne $self->{_lastSeq}->{id}) {

        seek($fh, $self->{_offsets}->{$id} + 4 + length($id) + 1 + 4, SEEK_SET); # sets the fh to the position of sequence
        read($fh, $data, ($length + ($length % 2)) / 2);
        $data = unpack("H*", $data);
        $data =~ tr/43210/NTGCA/;

        $self->{_lastSeq} = { id       => $id,
                              sequence => substr($data, 0, $length) };

        undef($data);

    }

    foreach my $range (@ranges) {

        $self->throw("Ranges must be ARRAY refs") if (ref($range) ne "ARRAY");
        $self->throw("Range outside of sequence boundaries") if ($range->[0] >= $length || $range->[1] >= $length);

        my $rangeLen = $range->[1] - $range->[0] + 1;
        $sequence .= substr($self->{_lastSeq}->{sequence}, $range->[0], $rangeLen);
        seek($fh, $beginArray + 4 * $range->[0], SEEK_SET);
        read($fh, $data, 4 * $rangeLen);
        push(@counts, unpack("L<*", $data));
        seek($fh, $beginArray + 4 * $length + 4 * $range->[0], SEEK_SET);
        read($fh, $data, 4 * $rangeLen);
        push(@coverage, unpack("L<*", $data));

    }

    # Reads mapped read count
    seek($fh, $beginArray + 4 * $length * 2, SEEK_SET);
    read($fh, $data, 4);

    $entry = RF::Data::RC->new( id         => $id,
                                sequence   => $sequence,
                                counts     => \@counts,
                                coverage   => \@coverage,
                                readscount => unpack("L<", $data) );

    return($entry);

}

sub read {

    my $self = shift;
    my $seqid = shift if (@_);

    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        $mappedreads, $offset, @stops, @coverage);

    $self->throw("Filehandle isn't in read mode") unless ($self->mode() eq "r");

    $fh = $self->{_fh};

    if (defined $seqid) {

        if (exists $self->{_offsets}->{$seqid}) {

            seek($fh, $self->{_offsets}->{$seqid}, SEEK_SET);

            # Re-build the prev array to allow ->back() call after seeking to a specific sequence
            my @prev = grep {$_ <= $self->{_offsets}->{$seqid}} sort {$a <=> $b} values %{$self->{_offsets}};
            $self->{_prev} = \@prev;

        }
        else { return; }

    }

    # Checks whether RTCEOF marker has been reached
    read($fh, $eightbytes, 17);
    seek($fh, tell($fh) - 17, SEEK_SET);

    # The first 4 bytes are the number of mapped reads in the experiment
    if (substr($eightbytes, -7) eq EOF) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    $offset = tell($fh);
    push(@{$self->{_prev}}, tell($fh)) if (!defined $seqid);

    read($fh, $data, 4); #read id length
    $idlen = unpack("L<", $data);

    read($fh, $data, $idlen);
    $id = substr($data, 0, -1);

    read($fh, $data, 4);
    $length = unpack("L<", $data);

    read($fh, $data, ($length + ($length % 2)) / 2);
    $data = unpack("H*", $data);
    $data =~ tr/43210/NTGCA/;
    $sequence = substr($data, 0, $length);

    # Index was not loaded before, but we can build it at runtime
    if ($self->{noLoadIndex}) {

        $self->{_offsets}->{$id} = $offset;
        $self->{_lengths}->{$id} = $length;

    }

    read($fh, $data, 4 * $length);
    @stops = unpack("L<*", $data);

    read($fh, $data, 4 * $length);
    @coverage = unpack("L<*", $data);

    read($fh, $data, 4);
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
    my ($id, $pos, $counts, $coverage, $readCount) = @_ if (@_);

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

    $beginArray = $self->{_offsets}->{$id} + 8 + length($id) + 1 + ($length + ($length % 2)) / 2;
    seek($fh, $beginArray + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @{$counts});
    seek($fh, $beginArray + 4 * $length + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @{$coverage});
    seek($fh, $beginArray + 4 * $length * 2, SEEK_SET);
    print $fh pack("L<", $readCount);

}

sub updateBytewise {

    my $self = shift;
    my ($id, $pos, $counts, $coverage, $code) = @_ if (@_);

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

    $beginArray = $self->{_offsets}->{$id} + 8 + length($id) + 1 + ($length + ($length % 2)) / 2;
    seek($fh, $beginArray + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @counts);
    seek($fh, $beginArray + 4 * $length + 4 * $pos, SEEK_SET);
    print $fh pack("L<*", @coverage);

}

sub write {

    my $self = shift;
    my @entries = @_ if (@_);

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

            seek($fh, $self->{_offsets}->{$id} + 8 + length($id) + 1 + ($length + ($length % 2)) / 2, SEEK_SET);

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
    my $n = shift if (@_);

    $self->throw("Total mapped reads must be a positive integer") if (defined $n &&
                                                                      !ispositive($n));

    $self->{mappedreads} = $n if (defined $n);

    return($self->{mappedreads});

}

sub close {

    my $self = shift;

    if ($self->mode() =~ m/^w/) {

        my $fh = $self->{_fh};

        seek($fh, -17, SEEK_END) if ($self->mode() eq "w+");

        print $fh pack("Q<", $self->{mappedreads}) .  # Total mapped reads (64bit int)
                  pack("S<", VERSION) .
                  EOF; # EOF Marker

        if ($self->{buildindex} &&
            defined $self->{index}) {

            open(my $ih, ">:raw", $self->{index}) or $self->throw("Unable to write RCI index (" . $! . ")");
            select((select($ih), $|=1)[0]);

            foreach my $id (sort {$self->{_offsets}->{$a} <=> $self->{_offsets}->{$b}} keys %{$self->{_offsets}}) {

                print $ih pack("L<", length($id) + 1) .                 # len_transcript_id (uint32_t)
                          $id . "\0" .                                  # transcript_id (char[len_transcript_id])
                          pack("Q<", $self->{_offsets}->{$id});         # offset in count table (uint64_t)

            }

            close($ih);

        }

    }

    $self->SUPER::close();

}

sub ids {

    my $self = shift;

    my @ids = sort keys %{$self->{_offsets}};

    return(wantarray() ? @ids : \@ids);

}

sub length {

    my $self = shift;
    my $id = shift if (@_);

    return() if (!defined $id || !exists $self->{_lengths}->{$id});

    return($self->{_lengths}->{$id});

}

sub sequence {

    my $self = shift;
    my $id = shift if (@_);

    return() if (!defined $id || !exists $self->{_lengths}->{$id});

    my ($fh, $length, $sequence);
    $fh = $self->{_fh};
    $length = $self->{_lengths}->{$id};
    seek($fh, $self->{_offsets}->{$id} + 4 + length($id) + 1 + 4, SEEK_SET); # sets the fh to the position of sequence
    read($fh, $sequence, ($length + ($length % 2)) / 2);
    $sequence = unpack("H*", $sequence);
    $sequence =~ tr/43210/NTGCA/;

    return(substr($sequence, 0, $length));

}

1;
