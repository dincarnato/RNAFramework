package Core::Process;

use strict;
use Core::Utils;
use Socket;
use POSIX;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ #detached  => 0,
                   id        => randalphanum(0xf), # Random generated alphanumeric ID if not specified
                   stdout    => undef,
                   stderr    => undef,
                   onstart   => sub {},
                   onexit    => sub {},
                   _pid      => undef,
                   _child    => undef,
                   _exitcode => undef }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    #$self->throw("Detached parameter value must be BOOL") if ($self->{detached} !~ m/^[01]$/);
    $self->throw("On start parameter value must be a CODE reference") if (ref($self->{onstart}) ne "CODE");
    $self->throw("On exit parameter value must be a CODE reference") if (ref($self->{onexit}) ne "CODE");

}

sub start {

    my $self  = shift;
    my $command = shift if (@_);
    my @parameters = @_ if (@_);

    if (defined $command) {

        my ($fchild, $tparent);

        pipe($fchild,  $tparent) or $self->throw("Unable to create pipe from child to child parent (" . $! . ")");
        select((select($tparent), $| = 1)[0]);

        #$SIG{CHLD} = sub { while (waitpid(-1, WNOHANG) == 0) {} };

        $self->{_pid} = fork();

        $self->throw("Unable to start process") unless (defined $self->{_pid});

        #setsid() if ($self->{detached});

        if (!$self->{_pid}) {

            $|++;

            my ($exitcode);

            close($fchild);

            $self->{onstart}->($self->{id}, $$) if (defined $self->{onstart});

            if ($self->{stdout} &&
                $self->{stdout} !~ m/^STDOUT$/i) {

                open(STDOUT, ">", $self->{stdout}) or $self->throw("Unable to tee STDOUT to \"" . $self->{stdout} . "\" (" . $! . ")");
                select((select(STDOUT), $|=1)[0]);

            }

            if ($self->{stderr} &&
                $self->{stderr} !~ m/^STDERR$/i) {

                open(STDERR, ">", $self->{stderr}) or $self->throw("Unable to tee STDERR to \"" . $self->{stderr} . "\" (" . $! . ")");
                select((select(STDERR), $|=1)[0]);

            }

            if (ref($command) eq "CODE") { $exitcode = $command->(@parameters); }
            else { $exitcode = system($command, @parameters); }

            print $tparent $exitcode;
            close($tparent);

            $self->{onexit}->($self->{id}, $$, $exitcode) if (defined $self->{onexit});

            exit(0);

        }

        close($tparent);

        $self->{_child} = $fchild;

    }

}

sub tee {

    my $self = shift;

    ($self->{stdout}, $self->{stderr}) = @_ if (@_);

}

sub id { return($_[0]->{id}); }

sub pid { return($_[0]->{_pid}); }

sub _closepair {

    my $self = shift;

    my ($child, $exitcode);
    $child = $self->{_child};

    if (fileno($child)) {

        while(my $read = <$child>) {

            chomp($read);
            $self->{_exitcode} .= $read;

        }

        close($child);

    }

}

sub exitcode { return($_[0]->{_exitcode}); }

sub wait {

    my $self = shift;

    #$self->throw("Cannot wait a detached process (PID: " . $self->{_pid} . ")") if ($self->{detached});

    local $SIG{CHLD} = "IGNORE";

    waitpid($self->{_pid}, 0);

    $self->_closepair();

}

sub onstart {

    my $self = shift;
    my $code = shift if (@_);

    if (defined $code) {

        $self->throw("On start parameter value must be a CODE reference") if (ref($code) ne "CODE");

        $self->{onstart} = $code;

    }

}

sub onexit {

    my $self = shift;
    my $code = shift if (@_);

    if (defined $code) {

        $self->throw("On exit parameter value must be a CODE reference") if (ref($code) ne "CODE");

        $self->{onexit} = $code;

    }

}

sub kill {

    my $self = shift;
    my $signal = shift || 9;

    CORE::kill($signal, $self->{_pid}) if (defined $self->{_pid});

}

sub DESTROY {

    local $SIG{__DIE__};

    close($_[0]->{_child});

}

1;
