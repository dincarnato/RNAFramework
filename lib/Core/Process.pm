package Core::Process;

use strict;
use Core::Utils;
use Storable qw(store retrieve);
use POSIX;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ tmpDir       => "/tmp",
                   id           => undef,
                   stdout       => undef,
                   stderr       => undef,
                   onstart      => sub {},
                   onexit       => sub {},
                   _tmpId       => randalphanum(0xf),
                   _pid         => undef,
                   _exitcode    => undef,
                   _tmpDataFile => undef }, \%parameters);

    $self->{id} = $self->{_tmpId} if (!defined $self->{id});
    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    #$self->throw("Detached parameter value must be BOOL") if ($self->{detached} !~ m/^[01]$/);
    $self->throw("On start parameter value must be a CODE reference") if (ref($self->{onstart}) ne "CODE");
    $self->throw("On exit parameter value must be a CODE reference") if (ref($self->{onexit}) ne "CODE");
    $self->throw("Provided temporary directory does not exist") if (!-d $self->{tmpDir});

    $self->{tmpDir} =~ s/\/?$/\//;
    $self->{_tmpDataFile} = $self->{tmpDir} . $self->{_tmpId} . ".tmp";

    my $i = 0;

    while(-e $self->{_tmpDataFile}) { # To avoid clashes with other processes

        $self->{_tmpDataFile} = $self->{tmpDir} . $self->{_tmpId} . "_" . $i . ".tmp";
        $i++;

    }

}

sub start {

    my $self  = shift;
    my $command = shift if (@_);
    my @parameters = @_ if (@_);

    if (defined $command) {

        $self->{_pid} = fork();

        $self->throw("Unable to start process") unless (defined $self->{_pid});

        #setsid() if ($self->{detached});

        if (!$self->{_pid}) {

            $|++;

            my ($exitcode);

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

            local $Storable::Deparse = 1;

            if (ref($command) eq "CODE") { $exitcode = [$command->(@parameters)]; }
            else { $exitcode = [ system($command, @parameters) ]; }

            store($exitcode, $self->{_tmpDataFile});

            $self->{onexit}->($self->{id}, $$, $exitcode) if (defined $self->{onexit});

            exit(0);

        }

    }

}

sub tee {

    my $self = shift;

    ($self->{stdout}, $self->{stderr}) = @_ if (@_);

}

sub id { return($_[0]->{id}); }

sub pid { return($_[0]->{_pid}); }

sub _retrieveReturnData {

    my $self = shift;

    if (-e $self->{_tmpDataFile}) {

        local $Storable::Eval = 1;
        $self->{_exitcode} = retrieve($self->{_tmpDataFile});

        unlink($self->{_tmpDataFile});

    }

}

sub exitcode { return(wantarray() ? @{$_[0]->{_exitcode}} : $_[0]->{_exitcode}); }

sub wait {

    my $self = shift;

    #$self->throw("Cannot wait a detached process (PID: " . $self->{_pid} . ")") if ($self->{detached});

    local $SIG{CHLD} = "IGNORE";

    waitpid($self->{_pid}, 0);

    $self->_retrieveReturnData();

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

1;
