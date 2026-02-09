package Term::Progress::Multiple;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Term::Progress;
use Term::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ width       => 50,
                   colored     => 0,
                   showETA     => 0,
                   updateRate  => 0,
                   updateTime  => 0,
                   sets        => {},
                   _progresses => {},
                   _positions  => {},
                   _lastRow    => 0,
                   _lastCol    => 0,
                   _maxIdLen   => 0,
                   _termSize   => -t STDOUT ? [ termsize() ] : [0, 0] }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Sets must be an HASH reference") if (ref($self->{sets}) ne "HASH");

    for (keys %{$self->{sets}}) { 
        
        $self->throw("Maximum value for set \"$_\" must be a positive INT >= 1") if (!isint($self->{sets}->{$_}) || $self->{sets}->{$_} < 1); 
        
        $self->{_maxIdLen} = max($self->{_maxIdLen}, length($_));

    }

}

sub init {

    my $self = shift;
    my $set = shift;
    my $status = shift || $set . (" " x ($self->{_maxIdLen} - length($set)));

    if (defined $set) {

        if (exists $self->{sets}->{$set}) {

            if (!keys %{$self->{_progresses}} && -t STDOUT) {

                my ($curRow, $curCol);
                ($curRow, $curCol) = getCursorPos();

                if ($curRow + scalar(keys %{$self->{sets}}) - 1 > $self->{_termSize}->[0]) {

                    print "\n" for (keys %{$self->{sets}});
                    $self->{_lastRow} = $self->{_termSize}->[0] - scalar(keys %{$self->{sets}});
                    setCursorPos($self->{_lastRow}, 0);

                }
                else { $self->{_lastRow} = $curRow; }

            }
            else { $self->{_lastRow}++; }

            $self->{_progresses}->{$set} = Term::Progress->new( max        => $self->{sets}->{$set},
                                                                width      => $self->{width},
                                                                colored    => $self->{colored},
                                                                showETA    => $self->{showETA},
                                                                updateRate => $self->{updateRate},
                                                                updateTime => $self->{updateTime} );
            $self->{_progresses}->{$set}->init($status);
            $self->{_positions}->{$set} = [$self->{_lastRow}, -t STDOUT ? (getCursorPos())[1] : 0];
            $self->{_lastCol} = $self->{_positions}->{$set}->[1];

            if (-t STDOUT) { print "\n" if (keys %{$self->{sets}} > keys %{$self->{_progresses}}); }
            else { print CLRRET; }

        }
        else { $self->warn("Set \"$set\" does not exist"); }

    }
    else { $self->warn("No set specified"); }

}

sub initAll {

    my $self = shift;
    my $status = shift;

    $self->init($_, $status) for (sort keys %{$self->{sets}});

}

sub update {

    my $self = shift;
    my $set = shift;
    my $increment = shift;
    my $status = shift;

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            if (-t STDOUT) { setCursorPos($self->{_positions}->{$set}->[0], 0); }
            else { print CLRRET; }

            $self->{_progresses}->{$set}->update($increment, $status);
            setCursorPos($self->{_lastRow}, $self->{_termSize}->[1]) if (-t STDOUT);
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); } 

}

sub updateAll {

    my $self = shift;
    my $increment = shift;
    my $status = shift;

    $self->update($_, $increment, $status) for(sort keys %{$self->{_progresses}});

}

sub complete {

    my $self = shift;
    my $set = shift;
    my $status = shift;

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            if (-t STDOUT) { setCursorPos($self->{_positions}->{$set}->[0], 0); }
            else { print CLRRET; }

            $self->{_progresses}->{$set}->complete($status);
            setCursorPos($self->{_lastRow}, $self->{_termSize}->[1]) if (-t STDOUT);
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); }

}

sub completeAll {

    my $self = shift;
    my $status = shift;

    $self->complete($_, $status) for (sort keys %{$self->{_progresses}});

}

sub appendText {

    my $self = shift;
    my $set = shift;
    my $text = shift;

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            if (-t STDOUT) { setCursorPos($self->{_positions}->{$set}->[0], $self->{_positions}->{$set}->[1] + 2); }
            else { print CLRRET; }

            $self->{_progresses}->{$set}->appendText($text);
            setCursorPos($self->{_lastRow}, $self->{_termSize}->[1]) if (-t STDOUT);
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); } 

}

sub reset {

    my $self = shift;
    my $set = shift;

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            if (-t STDOUT) { setCursorPos($self->{_positions}->{$set}->[0], 0); }
            else { print CLRRET; }

            $self->{_progresses}->{$set}->reset();
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); } 

}

sub resetAll {

    my $self = shift;

    $self->reset($_) for (sort keys %{$self->{_progresses}});

}

1;