#!/usr/bin/perl

package Data::IO::Sequence::FastaLike;

use strict;
use Fcntl qw(SEEK_SET);
use Core::Mathematics;
use Core::Utils;
use Data::Sequence;
use Data::Sequence::Utils;

use base qw(Data::IO::Sequence);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ index        => undef,
                   charsPerLine => 0,
                   buildIndex   => 0,
                   _newlineLen  => 1,
                   _wantedId    => undef }, \%parameters);

    $self->throw("Data::IO::Sequence::FastaLike must not be invoked directly") if (ref($self) eq "Data::IO::Sequence::FastaLike");

    $self->{index} = $self->{file} . ".fai" if (!defined $self->{index} && ($self->{buildIndex} || ($self->{mode} eq "r" && -e $self->{file} . ".fai")));
    $self->_loadIndex() if ($self->{mode} eq "r" && defined $self->{index} && -e $self->{index});

    return ($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("charsPerLine must be a positive INT") if (!isint($self->{charsPerLine}) || !ispositive($self->{charsPerLine}));
    $self->throw("buildIndex must be BOOL") if (!isbool($self->{buildIndex}));

}

# Reads a samtools FASTA index file
sub _loadIndex {

    my $self = shift;

    $self->warn("Index \"" . $self->{index} . "\" is older than FASTA file \"" . $self->{file} . "\"") if ((stat($self->{index}))[9] < (stat($self->{file}))[9]);

    my ($newlineLen);

    open(my $ih, "<", $self->{index}) or $self->throw("Unable to read FASTA index \"" . $self->{index} . "\" ($!)");
    while(<$ih>) {

        chomp();

        next if (!$_);

        my (@row, $newline, $headerOffset);
        @row = split("\t", $_);

        $self->throw("Minimum 5 fields expected in FASTA index, " . scalar(@row) . " found") if (@row < 5);
        $self->throw("Maximum 6 fields expected in FASTA index, " . scalar(@row) . " found") if (@row > 6);
        $self->throw("Fields 2 to 6 in FASTA index must be numeric") if (!isnumeric(@row[1 .. $#row]));
        $self->throw("Duplicate sequence ID \"" . $row[0] . "\" in FASTA index") if (exists $self->{_index}->{$row[0]});

        $newline = $row[4] - $row[3];
        $newlineLen = $newline if (!defined $newlineLen);

        $self->throw("Possible mixed newline types in FASTA index") if ($newline != $newlineLen);

        # set before _headerOffset() below, which needs it
        $self->{_newlineLen} = $newlineLen;
        $headerOffset = $self->_headerOffset($row[2]);

        $self->{_index}->{$row[0]} = { offset     => $headerOffset,
                                       dataOffset => $row[2],
                                       length     => $row[1],
                                       lineBases  => $row[3],
                                       lineWidth  => $row[4] };

        $self->_indexOffset($headerOffset, $row[0], $self->{_index}->{$row[0]});

    }

    CORE::close($ih);

}

# Returns the offset of the header line that precedes $dataOffset (the offset of
# the first base, which is what a .fai records).
# A .fai does not store the header length, so the header start cannot be derived
# arithmetically whenever the header carries a description on top of the name.
# It is instead found by walking back from the first base to the newline that
# closes the header line: the header begins on the byte after it, or at 0.
sub _headerOffset {

    my $self = shift;
    my $dataOffset = shift;

    my ($fh, $saved, $chunk, $from, 
        $buffer, $eol);
    $fh = $self->{_fh};

    return(0) if (!defined $fh || $dataOffset <= 0);

    $saved = tell($fh);
    $chunk = 4096;

    # The newline closing the header sits just before the first base, but blank
    # and comment lines are allowed between the two, so the header is the last
    # line *starting with ">"* before the sequence, not simply the previous line
    my $end = $dataOffset - $self->{_newlineLen};

    return(0) if ($end <= 0);

    while (1) {

        $from = $end - $chunk;
        $from = 0 if ($from < 0);

        seek($fh, $from, SEEK_SET);
        read($fh, $buffer, $end - $from);

        $eol = rindex($buffer, "\n>");
        $eol += 1 if ($eol != -1); # move past the newline, onto the ">"
        $eol = 0 if ($eol == -1 && !$from && substr($buffer, 0, 1) eq ">");

        last if ($eol != -1 || !$from);

        $chunk *= 4;

    }

    seek($fh, $saved, SEEK_SET);

    return($eol == -1 ? 0 : $from + $eol);

}

# Reads one record and returns its offset together with the raw text.
# With $/ set to "\n>" the separator swallows the ">" of the following record,
# so tell() reports the position of the ">" only for the first record and the
# position just after it for every other one. The offset is normalized here, so
# that everything downstream (the index, the .fai, back()) sees the offset of
# the ">" itself.
sub read {

    my $self = shift;
    my $id = shift;

    my ($fh, $stream, $offset);

    $self->throw("Filehandle isn't in read mode") unless ($self->{mode} eq "r");

    $fh = $self->{_fh};

    if (defined $id) {

        if (exists $self->{_index}->{$id}) { seek($fh, $self->{_index}->{$id}->{offset}, SEEK_SET); }
        else {

            if (keys %{$self->{_index}}) {

                $self->warn("Cannot find sequence \"$id\" in file");

                return;

            }
            else { $self->throw("File is not indexed"); }

        }

    }

    if (eof($fh)) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    # Saved so that _buildIndex() can tell whether the record found at the
    # indexed offset is the one that was asked for
    $self->{_wantedId} = $id;

    local $/ = "\n>";

    # An empty line before the first header is itself consumed as a record separator,
    # yielding an empty stream that would otherwise be reported as end of file. Any
    # such empty record is skipped here, rather than handed to the caller
    while (!eof($fh)) {

        $offset = tell($fh);
        $stream = <$fh>;

        last if (!defined $stream);

        chomp($stream);

        last if ($stream =~ m/\S/);

        undef($stream);

    }

    if (!defined $stream || $stream !~ m/\S/) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    # Every record but the first begins after the ">" consumed by the separator
    $offset-- if (substr($stream, 0, 1) ne ">" && $offset);

    return($offset, $stream);

}

# Stores a record in the index. $stream is the raw record, needed to work out
# where the sequence starts and how it is wrapped, which the .fai records.
sub _buildIndex {

    my $self = shift;
    my ($id, $offset, $length, $stream) = @_;

    # A record was requested by ID but a different one was found at the offset
    # the index gave: the index does not match the file any more
    if (defined $self->{_wantedId} && $self->{_wantedId} ne $id) {

        $self->warn("Index does not match file: \"" . $self->{_wantedId} . "\" was requested but \"$id\" was found");

    }

    undef($self->{_wantedId});

    if (exists $self->{_index}->{$id} && $self->{_index}->{$id}->{offset} != $offset) {

        my $error = "Duplicate sequence ID \"$id\" (Offsets: " . $self->{_index}->{$id}->{offset} . ", $offset)";

        if ($self->{checkDuplicateIds}) { $self->throw($error); }
        else { $self->warn($error); }

    }

    my ($entry, $headerLen, $lineBases, $lineWidth, $skipped);
    $headerLen = index($stream, "\n");
    $headerLen = length($stream) if ($headerLen == -1);

    # The ">" is not part of $stream for any record but the first
    $headerLen++ if (substr($stream, 0, 1) ne ">");

    ($lineBases, $lineWidth, $skipped) = $self->_lineMetrics($stream);

    $entry = { offset     => $offset,
               dataOffset => $offset + $headerLen + $self->{_newlineLen} + $skipped,
               length     => $length,
               lineBases  => $lineBases,
               lineWidth  => $lineWidth };

    $self->{_pos} = $self->_indexOffset($offset, $id, $entry);

}

# Number of bases on the first sequence line, the number of bytes that line
# occupies including its newline, and the number of bytes skipped between the
# header and that line. A .fai can only describe uniformly wrapped records, so
# the first line is what gets recorded; the third value keeps the recorded
# offset pointing at that same line when blank or commented lines precede it.
sub _lineMetrics {

    my $self = shift;
    my $stream = shift;

    my ($skipped, @lines);
    $skipped = 0;
    @lines = split(/\n/, $stream);

    shift(@lines); # header

    foreach my $line (@lines) {

        if ($line =~ m/^\s*$/ || $line =~ m/^#/) {

            $skipped += length($line) + $self->{_newlineLen};

            next;

        }

        return(length($line), length($line) + $self->{_newlineLen}, $skipped);

    }

    return(0, $self->{_newlineLen}, $skipped);

}

sub write {

    my $self = shift;
    my @entries = @_;

    $self->throw("Filehandle is not in write/append mode") unless ($self->{mode} =~ m/^w\+?$/);

    my ($fh, $charsPerLine);
    $fh = $self->{_fh};
    $charsPerLine = $self->{charsPerLine};

    foreach my $entry (@entries) {

        if (!blessed($entry) || !$entry->isa("Data::Sequence")) {

            $self->warn("Entry is not a Data::Sequence object");

            next;

        }

        my ($id, $name, $sequence, $offset, $lineBases);
        $sequence = $entry->sequence();

        if (!defined $sequence) {

            $self->warn("Empty Data::Sequence object");

            next;

        }

        $self->{_lastid} = 1 unless($self->{_lastid});

        # fullId() falls back to the id when no description is set, so it is
        # always the right thing to write out
        if (!defined $entry->id()) {

            $id = "seq_" . $self->{_lastid};
            $self->{_lastid}++;

        }
        else { $id = $entry->fullId() || $entry->id(); }

        # A .fai records the length of the first sequence line, which is the
        # wrap width only when the sequence is longer than it
        # the index is keyed on the name written to the header, which is not
        # necessarily $entry->id(): entries with no id get a generated one
        ($name) = split(" ", $id);

        $lineBases = ($charsPerLine && length($sequence) > $charsPerLine) ? $charsPerLine : length($sequence);

        $self->SUPER::write(">$id\n");
        $offset = tell($fh);

        if ($charsPerLine) {

            $sequence =~ s/(.{$charsPerLine})/$1\n/g;
            # a sequence whose length is an exact multiple of charsPerLine ends
            # up with a trailing newline, which would emit a blank line
            $sequence =~ s/\n$//;

        }

        $self->SUPER::write("$sequence\n");

        # Builds the FASTA index
        $self->{_index}->{$name} = { offset     => $offset - length($id) - 2,
                                     dataOffset => $offset,
                                     length     => $entry->length(),
                                     lineBases  => $lineBases,
                                     lineWidth  => $lineBases + 1 } if ($self->{buildIndex});

        if ($entry->can("structure") && defined $entry->structure()) {

            my $structure = $entry->structure();

            if ($charsPerLine) {

                $structure =~ s/(.{$charsPerLine})/$1\n/g;
                $structure =~ s/\n$//;

            }

            $structure .= " (" . sprintf("%.2f", $entry->energy()) . ")";

            $self->SUPER::write("$structure\n");

        }

    }

}

sub close {

    my $self = shift;

    if ($self->{buildIndex}) {

        # Finishes reading the whole file, so that the index is complete
        if ($self->{mode} eq "r") {

            my ($fh, $currentOffset, $lastOffset);
            $fh = $self->{_fh};
            $currentOffset = tell($fh);
            $lastOffset = @{$self->{_offsets}} ? $self->{_offsets}->[-1] : 0;

            seek($fh, $lastOffset, SEEK_SET) if ($currentOffset < $lastOffset);

            while($self->read()) { }

        }

        open(my $ih, ">", $self->{index}) or $self->throw("Unable to write FASTA index (" . $! . ")");
        select((select($ih), $|=1)[0]);

        # samtools .fai: name, length, offset of the first base, bases per
        # line, bytes per line
        print $ih join("\t", $_,
                             $self->{_index}->{$_}->{length},
                             $self->{_index}->{$_}->{dataOffset},
                             $self->{_index}->{$_}->{lineBases},
                             $self->{_index}->{$_}->{lineWidth}) . "\n"
            for (sort {$self->{_index}->{$a}->{offset} <=> $self->{_index}->{$b}->{offset}} keys %{$self->{_index}});

        CORE::close($ih);

    }

    $self->SUPER::close();

}

1;
