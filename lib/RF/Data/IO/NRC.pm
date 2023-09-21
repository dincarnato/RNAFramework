package RF::Data::IO::NRC;

use strict;
use Core::Mathematics;
use Core::Utils;
use Fcntl qw(SEEK_SET SEEK_END);
use RF::Data::NRC;

use base qw(Data::IO);

use constant EOF => "\x5b\x65\x6f\x66\x6e\x72\x63\x5d";
use constant VERSION => 1;

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index       => undef,
                   buildIndex  => 0,
                   dbSize      => 0,
                   blockSize   => 10000,
                   _offsets    => {},
                   _lengths    => {},
                   _lastSeq    => {},
                   _lastOffset => 0 }, \%parameters);

    $self->{binmode} = ":raw";

    $self->_openfh();
    $self->_validate();
    $self->_loadIndex() if ($self->mode() ne "w"); # r | w+

    return($self);

}

sub _validate {

    my $self = shift;

    my ($fh, $eof);
    $fh = $self->{_fh};

    $self->SUPER::_validate();

    if ($self->mode() eq "r") {

        seek($fh, -8, SEEK_END);
        read($fh, $eof, 8);

        $self->throw("Invalid NRC file (EOF marker is absent)") unless ($eof eq EOF);

        $self->reset();

    }
    else { $self->throw("NRC size must be a positive integer") if (!ispositive($self->{dbSize})); }

    $self->{index} = $self->{file} . ".rci" if ($self->{buildIndex} &&
                                                defined $self->{file} &&
                                                !defined $self->{index});

}

sub _loadIndex {

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

            if ($self->mode() eq "w+") {

                read($fh, $data, 4);
                $self->{_lengths}->{$id} = unpack("L<", $data);

            }

        }
        close($ih);

    }
    else { # Builds missing index

        my ($data, $offset, $idlen, $id,
            $length);
        $offset = 0;

        while($offset < (-s $self->{file}) - 18) { # While the 8 + 2 + 7 bytes of total mapped reads + RC version + EOF Marker are reached

            read($fh, $data, 4);
            $idlen = unpack("L<", $data);

            read($fh, $data, $idlen);
            $id = substr($data, 0, -1); # Removes the "\x00" string terminator

            read($fh, $data, 4);
            $length = unpack("L<", $data);

            $self->{_offsets}->{$id} = $offset;
            $self->{_lengths}->{$id} = $length;

            $offset += 8 * ($length + 1) + length($id) + 1 + ($length + ($length % 2)) / 2;

            seek($fh, $offset, SEEK_SET);

        }

        if ($self->{buildIndex} &&
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

    seek($fh, -18, SEEK_END);
    read($fh, $n, 8);

    # Unpack the 64bit int
    $self->dbSize(unpack("Q<", $n));

    $self->reset();

}

sub read {

    my $self = shift;
    my $seqid = shift if (@_);

    my ($fh, $data, $idlen, $id,
        $length, $sequence, $entry, $eightbytes,
        @reactivity);

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
    read($fh, $eightbytes, 18);
    seek($fh, tell($fh) - 18, SEEK_SET);

    # The first 4 bytes are the total size in nt of the db
    if (substr($eightbytes, -8) eq EOF) {

        $self->reset() if ($self->{autoreset});

        return;

    }

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

    read($fh, $data, 8 * $length);
    @reactivity = unpack("d*", $data);
    @reactivity = map { isnegative($_) ? "NaN" : $_ } @reactivity;

    $entry = RF::Data::NRC->new( id         => $id,
                                 sequence   => $sequence,
                                 reactivity => \@reactivity );

    return($entry);

}

sub readBytewise {

    my $self = shift;
    my ($id, @ranges) = @_ if (@_);

    return if (!exists $self->{_offsets}->{$id});

    my ($fh, $data, $entry, $length,
        $beginArray, $sequence, @reactivity);
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
        seek($fh, $beginArray + 8 * $range->[0], SEEK_SET);
        read($fh, $data, 8 * $rangeLen);
        push(@reactivity, unpack("d*", $data));

    }

    @reactivity = map { isnegative($_) ? "NaN" : $_ } @reactivity;
    $entry = RF::Data::NRC->new( id         => $id,
                                 sequence   => $sequence,
                                 reactivity => \@reactivity );

    return($entry);

}

sub writeBytewise {

    my $self = shift;
    my ($id, $pos, $counts) = @_ if (@_);

    $self->throw("Filehandle isn't in append mode") unless ($self->mode() eq "w+");

    my ($fh, $length, $beginArray, @undef);
    $fh = $self->{_fh};
    $length = $self->{_lengths}->{$id} if (exists $self->{_lengths}->{$id});

    # An undefined issue exists with Perl's threads, that sometimes causes
    # failure in index loading, thus we make a check and reload the index (just in case)
    if (!keys %{$self->{_offsets}}) { $self->_loadindex(); }

    $self->throw("Sequence ID \"" . $id . "\" is absent in file \"" . $self->{file} . "\"") if (!$length);
    $self->throw("Position exceeds sequence's length (" . $pos . " >= " . $self->{_lengths}->{$id} . ")") if ($pos >= $length);
    $self->throw("Data exceeds sequence's length") if ($pos + @$counts - 1 >= $length);

    # If there are missing values, we will set them to -999 (these will be re-read as NaNs)
    @undef = grep { !defined $counts->[$_] } 0 .. $#{$counts};
    @{$counts}[@undef] = (-999) x scalar(@undef) if (@undef);

    $beginArray = $self->{_offsets}->{$id} + 8 + length($id) + 1 + ($length + ($length % 2)) / 2;
    seek($fh, $beginArray + 8 * $pos, SEEK_SET);
    print $fh pack("d*", @{$counts});

}

sub write {

    my $self = shift;
    my @entries = @_ if (@_);

    my ($fh, @offsets);
    $fh = $self->{_fh};

    $self->throw("Filehandle isn't in write\/append mode") unless ($self->mode() =~ m/^w/);

    foreach my $entry (@entries) {

        if (!blessed($entry) ||
            !$entry->isa("RF::Data::NRC")) {

            $self->warn("Method requires a valid RF::Data::NRC object");

            next;

        }

        my ($id, $seq, $length, @reactivity);
        $id = $entry->id();
        $seq = $entry->sequence;
        $seq =~ tr/NTGCA/43210/;
        $length = $entry->length();
        @reactivity = map { isnan($_) ? -999 : $_ } $entry->reactivity();

        if (!$length || !defined $id) {

            $self->warn("Empty RF::Data::NRC object");

            next;

        }

        if ($self->mode() eq "w+") {

            # An undefined issue exists with Perl's threads, that sometimes causes
            # failure in index loading, thus we make a check and reload the index (just in case)
            if (!keys %{$self->{_offsets}}) { $self->_loadIndex(); }

            $self->throw("Sequence ID \"" . $id . "\" is absent in file \"" . $self->{file} . "\"") if (!exists $self->{_lengths}->{$id});
            $self->throw("Sequence \"" . $id . "\" length differs from sequence in file \"" . $self->{file} . "\"") if ($length != $self->{_lengths}->{$id});

            seek($fh, $self->{_offsets}->{$id}, SEEK_SET);

        }

        print $fh pack("L<", length($id) + 1) .             # len_transcript_id (uint32_t)
                  $id . "\0" .                              # transcript_id (char[len_transcript_id])
                  pack("L<", length($seq)) .                # len_seq (uint32_t)
                  pack("H*", $seq);                         # seq (uint8_t[(len_seq+1)/2])

        if (@reactivity) { print $fh pack("d*", @reactivity); }
        else {

            # This is meant for very large sequences (i.e. an entire chromosome)
            if ($length > $self->{blockSize}) {

                my ($nBlocks, $left);
                $nBlocks = POSIX::floor($length / $self->{blockSize});
                $left = $length - ($self->{blockSize} * $nBlocks);

                print $fh pack("d*", (-999) x $self->{blockSize}) for (1 .. $nBlocks);
                print $fh pack("d*", (-999) x $left);

            }
            else {

                @reactivity = (-999) x $length;
                print $fh pack("d*", @reactivity);

            }

        }

        $self->{dbSize} += $length;

        if ($self->{buildIndex} &&
            $self->{mode} ne "w+") {

            $self->{_offsets}->{$id} = $self->{_lastOffset};
            push(@offsets, $self->{_lastOffset});
            $self->{_lastOffset} += 8 * ($length + 1) + length($id) + 1 + ($length + ($length % 2)) / 2;

        }

    }

    return(wantarray() ? @offsets : \@offsets) if ($self->{buildIndex});

}

sub dbSize {

    my $self = shift;
    my $n = shift if (@_);

    $self->throw("NRC size must be a positive integer") if (defined $n &&
                                                           !ispositive($n));

    $self->{dbSize} = $n if (defined $n);

    return($self->{dbSize});

}

sub close {

    my $self = shift;

    if ($self->mode() =~ m/^w/) {

        my $fh = $self->{_fh};

        seek($fh, -18, SEEK_END) if ($self->mode() eq "w+");

        print $fh pack("Q<", $self->{dbSize}) .  # Total mapped reads (64bit int)
                  pack("S<", VERSION) .
                  EOF; # EOF Marker

        if ($self->{buildIndex} &&
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

1;
