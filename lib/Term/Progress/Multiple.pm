package Term::Progress::Multiple;

use strict;
use Core::Mathematics;
use Core::Utils;
use Term::Progress;
use Term::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ width       => 100,
                   colored     => 0,
                   sets        => {},
                   _progresses => {},
                   _positions  => {},
                   _lastRow    => 0,
                   _lastCol    => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Width must be a positive INT >= 1") if (!isint($self->{width}) || $self->{width} < 1);
    $self->throw("Sets must be an HASH reference") if (ref($self->{sets}) ne "HASH");
    $self->throw("Colored parameter must be BOOL") if (!isbool($self->{colored}));

    for (keys %{$self->{sets}}) { $self->throw("Maximum value for set \"$_\" must be a positive INT >= 1") if (!isint($self->{sets}->{$_}) || $self->{sets}->{$_} < 1); }

}

sub init {

    my $self = shift;
    my $set = shift if (@_);
    my $status = shift || $set;

    if (defined $set) {

        if (exists $self->{sets}->{$set}) {

            if (!keys %{$self->{_progresses}} && -t STDOUT) {

                my ($rows, $cols, $curRow, $curCol);
                ($rows, $cols) = termsize();
                ($curRow, $curCol) = getCursorPos();

                if ($curRow + scalar(keys %{$self->{sets}}) - 1 > $rows) {

                    print "\n" for (keys %{$self->{sets}});
                    $self->{_lastRow} = $rows - scalar(keys %{$self->{sets}});
                    setCursorPos($self->{_lastRow}, 0);

                }
                else { $self->{_lastRow} = $curRow; }

            }
            else { $self->{_lastRow}++; }

            $self->{_positions}->{$set} = $self->{_lastRow};
            $self->{_progresses}->{$set} = Term::Progress->new( max     => $self->{sets}->{$set},
                                                                width   => $self->{width},
                                                                colored => $self->{colored} );
            $self->{_progresses}->{$set}->init($status);
            $self->{_lastCol} = (getCursorPos())[1] if (-t STDOUT);

            print "\n" if (keys %{$self->{sets}} > keys %{$self->{_progresses}} || !-t STDOUT);

        }
        else { $self->warn("Set \"$set\" does not exist"); }

    }
    else { $self->warn("No set specified"); }

}

sub initAll {

    my $self = shift;
    my $status = shift if (@_);

    $self->init($_, $status) for (sort keys %{$self->{sets}});

}

sub update {

    my $self = shift;
    my $set = shift if (@_);
    my $increment = shift if (@_);
    my $status = shift if (@_);

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            setCursorPos($self->{_positions}->{$set}, 0) if (-t STDOUT);    
            $self->{_progresses}->{$set}->update($increment, $status);
            setCursorPos($self->{_lastRow}, $self->{_lastCol} + 2) if (-t STDOUT);
            print "\n" if (!-t STDOUT);
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); } 

}

sub updateAll {

    my $self = shift;
    my $increment = shift if (@_);
    my $status = shift if (@_);

    $self->update($_, $increment, $status) for(sort keys %{$self->{_progresses}});

}

sub complete {

    my $self = shift;
    my $set = shift if (@_);
    my $status = shift if (@_);

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            setCursorPos($self->{_positions}->{$set}, 0) if (-t STDOUT);   
            $self->{_progresses}->{$set}->complete($status);
            setCursorPos($self->{_lastRow}, $self->{_lastCol} + 2) if (-t STDOUT);
            print "\n" if (!-t STDOUT);
            
        }
        else { $self->warn("Set \"$set\" does not exist or has not yet been initialized"); }

    }
    else { $self->warn("No set specified"); }

}

sub completeAll {

    my $self = shift;
    my $status = shift if (@_);

    $self->complete($_, $status) for (sort keys %{$self->{_progresses}});

}

sub reset {

    my $self = shift;
    my $set = shift if (@_);

    if (defined $set) {

        if (exists $self->{_progresses}->{$set}) { 

            setCursorPos($self->{_positions}->{$set}, 0) if (-t STDOUT);  
            $self->{_progresses}->{$set}->reset();
            print "\n" if (!-t STDOUT);
            
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