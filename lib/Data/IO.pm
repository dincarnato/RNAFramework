package Data::IO;

use strict;
use Fcntl qw(SEEK_END SEEK_SET);
use HTTP::Tiny;
use Core::Mathematics;
use Core::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ file       => undef,
                   data       => undef,
                   mode       => "r",
                   flush      => 0,
                   autoreset  => 0,
                   timeout    => 10,
                   retries    => 3,
                   overwrite  => 0,
                   binmode    => undef,
                   iseparator => "\n",
                   _prev      => [],
                   _fh        => undef }, \%parameters);

    $self->_checkfile();
    $self->flush($self->{flush});

    # Open filehandle if creating a generic object
    $self->_openfh() if ($class =~ m/^Data::IO$/);

    return($self);

}

sub _validate {

    my $self = shift;

    $self->{file} =~ s/^\s+|\s+$//g;

    $self->{mode} = lc($self->{mode});

    $self->throw("Invalid mode \"" . $self->{mode} . "\"") unless ($self->{mode} =~ m/^(r|w\+?)$/i);
    $self->throw("No file or data provided") if ($self->{mode} =~ m/^r$/i &&
                                                 !defined $self->{file} &&
                                                 !defined $self->{data});
    $self->throw("No output file has been specified") if ($self->{mode} =~ m/^w\+?$/i &&
                                                          !defined $self->{file});
    $self->throw("Flush parameter's allowed values are 0 or 1") if ($self->{flush} !~ m/^[01]$/);
    $self->throw("Overwrite parameter's allowed values are 0 or 1") if ($self->{overwrite} !~ m/^[01]$/);
    $self->throw("Timeout parameter must be an integer greater than 0") if (!isint($self->{timeout}) &&
                                                                            $self->{timeout} <= 0);
    $self->throw("Retries parameter must be an integer greater than 0") if (!isint($self->{retries}) &&
                                                                            $self->{retries} <= 0);
    $self->{binmode} =~ s/^:?/:/ if (defined $self->{binmode});

}

sub _checkfile {

    my $self = shift;

    my ($file, $data);
    $file = $self->{file};
    $data = $self->{data};

    if ($self->{mode} eq "r") {

        if (defined $data) { $self->{data} = \$data; }
        else {

            if ($file =~ m/^(https?|ftp):\/\//) {

                for (1 .. $self->{retries}) {

                    my ($useragent, $reply);
                    $useragent = HTTP::Tiny->new(timeout => $self->{timeout});
                    $reply = $useragent->get($file);

                    if (!$reply->{success}) { $self->warn($reply->{status} . " (" . $reply->{reason} . ")"); }
                    else {

                        $data = $reply->{content};

                        last;

                    }

                }

                if (defined $data) { $self->{data} = \$data; }
                else { $self->throw("Unable to retrieve data file after " . $self->{retries} . " attemps"); }

            }
            else {

                $self->throw("Provided file \"" . $file . "\" doesn't exist") unless (-e $file);
                $self->{data} = $file;

            }

        }

    }
    elsif ($self->{mode} eq "w") {

        $self->throw("Specified file \"" . $file . "\" already exists.\n" .
                     "Change IO mode to append, or enable overwrite parameter.") if (-e $file &&
                                                                                     !$self->{overwrite});

    }

}

sub _openfh {

    my $self = shift;

    my $mode = $self->{mode};
    $self->{data} = $self->{file} if ($mode =~ m/w/);
    $mode =~ tr/rw+/<>>/;

    $mode =~ s/^>>/+</ if ($self->{binmode} eq ":raw"); # The file format is binary so
                                                        # we change to read/write for append in binary mode

    open(my $fh, $mode, $self->{data}) or $self->throw($!);
    binmode($fh, $self->{binmode});

    $self->{_fh} = $fh;

    $self->flush();

}

sub forceReopenFh {

    my $self = shift;

    $self->close();
    $self->_openfh();

}

sub iseparator {

    my $self = shift;

    $self->warn("Setting the input record separator has no effect on a write/append filehandle") if ($self->{mode} ne "r");
    $self->throw("Unable to change input record separator on a non-generic Data::IO object") if (ref($self) ne "Data::IO");

    $self->{iseparator} = $_[0] if (@_);

    return($self->{iseparator});

}

sub read {

    my $self = shift;

    $self->throw("Unable to read from a write/append filehandle") if ($self->{mode} ne "r");

    my ($fh, $row);
    $fh = $self->{_fh};

    if (eof($fh)) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    local $/ = $self->{iseparator};

    $row = <$fh>;
    chomp($row);

    return($row ? $row : $self->read());

}

sub write {

    my $self = shift;
    my $string = shift if (@_);

    $self->throw("Unable to write on a read-only filehandle") if ($self->{mode} eq "r");

    my $fh = $self->{_fh};

    print $fh $string;

}

sub back {

    my $self = shift;
    my $index = @_ ? shift : 0;

    $self->throw("Backward index must be a positive integer") unless (isint($index) &&
                                                                      ispositive($index));

    #if (ref($self) =~ m/^Data::IO::(?:Track|Sequence)::\w+$/) {
    if (ref($self) =~ m/^Data::IO::\w+/) {

        splice(@{$self->{_prev}}, (@{$self->{_prev}} - $index), $index);

        push(@{$self->{_prev}}, 0) unless (@{$self->{_prev}});
        seek($self->{_fh}, pop(@{$self->{_prev}}), SEEK_SET);

    }
    else { $self->throw("Unable to call method on a generic object"); }

}

sub mode {

    my $self = shift;

    return($self->{mode});

}

sub binmode {

    my $self = shift;
    my $binmode = shift if (@_);

    if ($binmode) {

        $binmode =~ s/^:?/:/;
        $self->{binmode} = $binmode;

        binmode($self->{_fh}, $binmode) if (fileno($self->{_fh}));

    }

    return($self->{binmode});

}

sub format {

    my $self = shift;

    return($self->{format});

}

sub file {

    my $self = shift;

    return($self->{file});

}

sub flush {

    my $self = shift;
    my $flush = shift if (@_);

    $self->{flush} = $flush if ($flush =~ m/^[01]$/);

    if (defined $self->{_fh}) { select((select($self->{_fh}), $| = 1)[0]) if ($self->{flush} &&
                                                                              fileno($self->{_fh}) &&
                                                                              $self->mode() ne "r"); }

}

sub tell {

    my $self = shift;

    return(tell($self->{_fh})) if (fileno($self->{_fh}));

}

sub seek {

    my $self = shift;
    my $offset = shift || 0;

    $self->throw("Offset must be a positive INT") if (!ispositive($offset) || !isint($offset));

    return(seek($self->{_fh}, $offset, SEEK_SET)) if (fileno($self->{_fh}));

}

sub reset {

    my $self = shift;

    # Reinitialize the prev array for back() calls
    undef(@{$self->{_prev}});
    seek($self->{_fh}, 0, SEEK_SET) if (fileno($self->{_fh}));

}

sub goToEof {

    my $self = shift;

    seek($self->{_fh}, 0, SEEK_END) if (fileno($self->{_fh}));

}

sub eof {

    my $self = shift;

    return(1) if (fileno($self->{_fh}) && eof($self->{_fh}));

}

sub close {

    my $self = shift;

    if (defined $self->{_fh}) { CORE::close($self->{_fh}) if (fileno($self->{_fh})); }

}

sub DESTROY {

    my $self = shift;

    delete($self->{file});
    delete($self->{data});

    $self->close();

}

1;
