package Term::Progress;

use strict;
use Core::Mathematics;
use Core::Utils;
use Term::Constants qw(:screen :colors);
use Term::Utils;
use Time::HiRes qw(time);

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ max        => undef,
                   width      => 50,
                   colored    => 0,
                   showETA    => 0,
                   updateRate => 0,
                   updateTime => 0,
                   _residual  => undef,
                   _status    => undef,
                   _time      => time(),
                   _upTime    => 0,
                   _complete  => 0,
                   _updateN   => 0,
                   _lastRow   => undef,
                   _lastCol   => undef,
                   _isFg      => undef }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Width must be a positive INT >= 1") if (!isint($self->{width}) || $self->{width} < 1);
    $self->throw("Colored parameter must be BOOL") if (!isbool($self->{colored}));
    $self->throw("showETA parameter must be BOOL") if (!isbool($self->{showETA}));
    $self->throw("updateRate parameter must be comprised betwen 0 and 1") if (!inrange($self->{updateRate}, [0, 1]));
    $self->throw("updateTime parameter must be >= 0") if (!isnumeric($self->{updateTime}) || !ispositive($self->{updateTime}));

    if (defined $self->{max}) {

        $self->throw("Maximum value must be a positive INT >= 1") if (!isint($self->{max}) || $self->{max} < 1);
        $self->{_residual} = $self->{max};
        $self->{_updateN} = Core::Mathematics::max(1, int($self->{updateRate} * $self->{max}));

    }

    $self->{_isFg} = isForeground();

    binmode(STDOUT, "encoding(UTF-8)");
    select((select(STDOUT), $|=1)[0]);

}

sub init {

    my $self = shift;
    my $status = shift;

    $self->throw("Max value has not been defined") if (!defined $self->{max});

    $self->{_status} = " " . $status if (defined $status);

    print CLRRET . "|" . (" " x $self->{width}) . "|";
    ($self->{_lastRow}, $self->{_lastCol}) = getCursorPos() if ($self->{_isFg});
    print $self->{_status} . " (Done: 0.00\%" . ($self->{showETA} ? "; ETA: unknown)" : ")");

}

sub update {

    my $self = shift;
    my $increment = shift || 1;
    my $status = shift;

    return if ($self->{_complete});

    my ($time, $done, $blocks, $spaces, $color);
    $self->{_status} = " " . $status if (defined $status);
    $self->{_residual} -= $increment;
    $done = $self->{max} - $self->{_residual};

    return if (int($done / $self->{_updateN}) <= int(($done - $increment) / $self->{_updateN}));

    $time = time();

    return if ($time - $self->{_upTime} < $self->{updateTime} && $done < $self->{max});

    $blocks = round(min($self->{width}, $done / $self->{max} * $self->{width}));
    $spaces = " " x ($self->{width} - round($blocks));
    $blocks = Term::Constants::BLOCK x $blocks;
    $color = $self->_getColor();

    print CLRRET . "|" . $color . $blocks . RESET . $spaces . "|" . $self->{_status} . " (Done: " . $color . sprintf("%.2f", $self->_getPercentDone()) . "\%" . RESET . ($self->{showETA} ? "; ETA: " . formatTime($self->_getETA()) . ")" : ")");

    $self->{_upTime} = time();

}

sub _getColor {

    my $self = shift;

    my ($percentage, $color);
    $percentage = $self->_getPercentDone();
    $color = WHITE;

    if ($self->{colored}) {

        if ($percentage <= 20) { $color = RED; }
        elsif ($percentage <= 40) { $color = BRED; }
        elsif ($percentage <= 60) { $color = BYELLOW; }
        elsif ($percentage <= 90) { $color = YELLOW; }
        elsif ($percentage < 100) { $color = BGREEN; }
        else { $color = GREEN; }

    }

    return($color);

}

sub _getETA {

    my $self = shift;

    my ($done, $time, $timePerEvent, $timeLeft);
    $time = time();
    $done = $self->{max} - $self->{_residual};
    $timePerEvent = $done ? ($time - $self->{_time}) / $done : 0;
    $timeLeft = $self->{_residual} * $timePerEvent;

    return($timeLeft);

}

sub _getPercentDone {

    my $self = shift;

    my ($done, $percentage);
    $done = $self->{max} - $self->{_residual};
    $percentage = min(100, $done / $self->{max} * 100);

    return($percentage);

}

sub setValue {

    my $self = shift;
    my $value = shift;
    my $status = shift;

    return if ($self->{_complete} || !$value);

    my $toAdd = $value - ($self->{max} - $self->{_residual});
    
    return if ($toAdd < 0);

    $self->update($toAdd, $status);

}

sub complete {

    my $self = shift;
    my $status = shift;

    return if ($self->{_complete});

    my $color = $self->{colored} ? GREEN : WHITE;
    $self->{_status} = " " . $status if (defined $status);
    $self->{_complete} = 1;

    print CLRRET . "|" . $color . (Term::Constants::BLOCK x $self->{width}) . RESET . "|" . $self->{_status} . " (Done: " . $color . "100.00\%" . RESET . ($self->{showETA} ? "; ETA: 0s)" : ")");

}

sub status {

    my $self = shift;
    my $status = shift;

    if (defined $self->{_lastRow} && defined $self->{_lastCol}) {

        my $color = $self->_getColor();

        setCursorPos($self->{_lastRow}, $self->{_lastCol});

        print CLRTOEND;
        print " " . $status if (defined $status);
        print " (Done: " . $color . sprintf("%.2f", $self->_getPercentDone()) . "\%" . RESET . ($self->{showETA} ? "; ETA: " . formatTime($self->_getETA()) . ")" : ")");

    }

}

sub appendText {

    my $self = shift;
    my $text = shift;

    print " " . $text if (defined $text);

}

sub max {

    my $self = shift;
    my $max = shift;

    if ($max) {

        $self->throw("Maximum value must be numeric") if (!isnumeric($max));

        $self->{max} = $max;
        $self->{_residual} = $max;
        $self->{_updateN} = Core::Mathematics::max(1, int($self->{updateRate} * $self->{max}));

    }

    return($self->{max});

}

sub reset {

    my $self = shift;

    $self->{_residual} = $self->{max};
    $self->{time} = time();
    $self->{_complete} = 0;
    undef($self->{_status});

}

1;
