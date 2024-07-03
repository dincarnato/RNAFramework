package Term::Progress;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Term::Constants qw(:screen :colors);

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ max       => undef,
                   width     => 100,
                   colored   => 0,
                   _residual => undef,
                   _status   => undef,
                   _time     => time(),
                   _complete => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Maximum value must be a positive INT >= 1") if (!isint($self->{max}) || $self->{max} < 1);
    $self->throw("Width must be a positive INT >= 1") if (!isint($self->{width}) || $self->{width} < 1);
    $self->throw("Colored parameter must be BOOL") if (!isbool($self->{colored}));

    $self->{_residual} = $self->{max};

    binmode(STDOUT, "encoding(UTF-8)");
    select((select(STDOUT), $|=1)[0]);

}

sub init {

    my $self = shift;
    my $status = shift if (@_);

    $self->{_status} = " " . $status if (defined $status);

    print CLRRET . "|" . (" " x $self->{width}) . "|" . $self->{_status} . " (Done: 0.00\%)"; #; ETC: unknown)";

}

sub update {

    my $self = shift;
    my $increment = shift;
    my $status = shift if (@_);

    return if ($self->{_complete});

    $self->{_status} = " " . $status if (defined $status);

    my ($time, $timePerEvent, $timeLeft, $done,
        $blocks, $spaces, $percentage, $color);
    #$time = time();
    $self->{_residual} -= $increment;
    $done = $self->{max} - $self->{_residual};
    #$timePerEvent = $done ? ($time - $self->{_time}) / $done : 0;
    #$timeLeft = $self->{_residual} * $timePerEvent;
    $percentage = min(100, $done / $self->{max} * 100);
    $blocks = round(min($self->{width}, $done / $self->{max} * $self->{width}));
    $spaces = " " x ($self->{width} - round($blocks));
    $blocks = Term::Constants::BLOCK x $blocks;
    
    if ($self->{colored}) {

        if ($percentage <= 20) { $color = RED; }
        elsif ($percentage <= 40) { $color = BRED; }
        elsif ($percentage <= 60) { $color = BYELLOW; }
        elsif ($percentage <= 90) { $color = YELLOW; }
        elsif ($percentage < 100) { $color = BGREEN; }
        else { $color = GREEN; }

    }
    else { $color = WHITE; }

    print CLRRET . "|" . $color . $blocks . RESET . $spaces . "|" . $self->{_status} . " (Done: " . $color . sprintf("%.2f", $percentage) . "\%" . RESET . ")"; #\%; ETC: " . formatTime($timeLeft) . ")";

}

sub complete {

    my $self = shift;
    my $status = shift if (@_);

    return if ($self->{_complete});

    my $color = $self->{colored} ? GREEN : WHITE;
    $self->{_status} = " " . $status if (defined $status);
    $self->{_complete} = 1;

    print CLRRET . "|" . $color . (Term::Constants::BLOCK x $self->{width}) . RESET . "|" . $self->{_status} . " (Done: " . $color . "100.00\%" . RESET . ")"; #; ETC: 0s)";

}

sub max {

    my $self = shift;
    my $max = shift if (@_);

    if ($max) {

        $self->throw("Maximum value must be numeric") if (!isnumeric($max));

        $self->{max} = $max;
        $self->{_residual} = $max;

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
