package Term::Progress;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Term::Constants qw(:screen);

use base qw(Core::Base);

use constant BLOCK => "\x{2588}";

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ max       => undef,
                   width     => 100,
                   _residual => undef,
                   _status   => undef,
                   _time     => time(),
                   _complete => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Maximum value must be numeric") if (!isnumeric($self->{max}));
    $self->throw("Width must be numeric") if (!isnumeric($self->{width}));

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
        $blocks, $spaces, $percentage);
    #$time = time();
    $self->{_residual} -= $increment;
    $done = $self->{max} - $self->{_residual};
    #$timePerEvent = $done ? ($time - $self->{_time}) / $done : 0;
    #$timeLeft = $self->{_residual} * $timePerEvent;
    $percentage = min(100, $done / $self->{max} * 100);
    $blocks = round(min($self->{width}, $done / $self->{max} * $self->{width}));
    $spaces = $self->{width} - round($blocks);

    print CLRRET . "|" . (BLOCK x $blocks) . (" " x $spaces) . "|" . $self->{_status} . " (Done: " . sprintf("%.2f", $percentage) . "\%)"; #\%; ETC: " . formatTime($timeLeft) . ")";

}

sub complete {

    my $self = shift;
    my $status = shift if (@_);

    return if ($self->{_complete});

    $self->{_status} = " " . $status if (defined $status);
    $self->{_complete} = 1;

    print CLRRET . "|" . (BLOCK x $self->{width}) . "|" . $self->{_status} . " (Done: 100.00\%)"; #; ETC: 0s)";

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
