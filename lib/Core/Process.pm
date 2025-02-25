package Core::Process;

use strict;
use Carp;
use Core::Utils;
use Storable qw(lock_store lock_retrieve);
use POSIX;
use Time::HiRes qw(time);

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

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

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("On start parameter value must be a CODE reference") if (ref($self->{onstart}) ne "CODE");
    $self->throw("On exit parameter value must be a CODE reference") if (ref($self->{onexit}) ne "CODE");
    $self->throw("Provided temporary directory does not exist") if (!-d $self->{tmpDir});

    $self->{tmpDir} =~ s/\/?$/\//;

}

sub _getUniqueTmpId {

    my $self = shift;

    my ($tmpDataFile);

    while(!defined $self->{_tmpDataFile}) {

        $tmpDataFile = $self->{tmpDir} . "." . $self->{_tmpId} . "." . time();

        if (glob("$tmpDataFile*")) { $self->{_tmpId} = randalphanum(0xf); }
        else { 
            
            $self->{_tmpDataFile} = $tmpDataFile; 
            $self->{id} = $self->{_tmpId} if (!defined $self->{id});

        }

    }

}

sub start {

    my $self  = shift;
    my $command = shift;
    my @parameters = @_;

    $self->_getUniqueTmpId();

    if (defined $command) {

        $self->{_pid} = fork();

        $self->throw("Unable to start process") unless (defined $self->{_pid});

        if (!$self->{_pid}) {

            $|++;

            my ($exitcode);

            $self->{onstart}->($self->{id}, $$) if (defined $self->{onstart});

            if ($self->{stdout} &&
                $self->{stdout} !~ m/^STDOUT$/i) {

                open(STDOUT, ">>", $self->{stdout}) or $self->throw("Unable to tee STDOUT to \"" . $self->{stdout} . "\" (" . $! . ")");
                select((select(STDOUT), $|=1)[0]);

            }

            if ($self->{stderr} &&
                $self->{stderr} !~ m/^STDERR$/i) {

                open(STDERR, ">>", $self->{stderr}) or $self->throw("Unable to tee STDERR to \"" . $self->{stderr} . "\" (" . $! . ")");
                select((select(STDERR), $|=1)[0]);

            }

            local $Storable::Deparse = 1;

            if (ref($command) eq "CODE") { $exitcode = [ $command->(@parameters) ]; }
            else { $exitcode = [ system($command, @parameters) ]; }

            $self->{_tmpDataFile} .= "." . $$ . ".tmp";
            lock_store($exitcode, $self->{_tmpDataFile});

            $self->{onexit}->($self->{id}, $$, $exitcode) if (defined $self->{onexit});

            exit(0);

        }
        else { $self->{_tmpDataFile} .= "." . $self->{_pid} . ".tmp"; }

    }

}

sub tee {

    my $self = shift;

    ($self->{stdout}, $self->{stderr}) = @_;

}

sub id { return($_[0]->{id}); }

sub pid { return($_[0]->{_pid}); }

sub _tmpId { return($_[0]->{_tmpId}); }

sub _retrieveReturnData {

    my $self = shift;

    if (-e $self->{_tmpDataFile}) {

        local $Storable::Eval = 1;
        $self->{_exitcode} = lock_retrieve($self->{_tmpDataFile});
        unlink($self->{_tmpDataFile});

    }
    elsif (!defined $self->{_exitcode}) { $self->{_exitcode} = [ "Unable to open child process temporary data file \"" . $self->{_tmpDataFile} . "\"" ]; }

}

sub exitcode { return(wantarray() ? @{$_[0]->{_exitcode}} : $_[0]->{_exitcode}); }

sub wait {

    my $self = shift;

    waitpid($self->{_pid}, 0);

    $self->_retrieveReturnData();

}

sub onstart {

    my $self = shift;
    my $code = shift;

    if (defined $code) {

        $self->throw("On start parameter value must be a CODE reference") if (ref($code) ne "CODE");

        $self->{onstart} = $code;

    }

}

sub onexit {

    my $self = shift;
    my $code = shift;

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

