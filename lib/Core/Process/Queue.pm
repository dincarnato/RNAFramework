package Core::Process::Queue;

use strict;
use Core::Mathematics;
use Core::Process;
use Core::Utils;
use List::Util;
use POSIX qw(:sys_wait_h);

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ stdout       => undef,
                   stderr       => undef,
                   processors   => 1,
                   onstart      => sub {},
                   onexit       => sub {},
                   parentOnExit => sub {},
                   tmpDir       => "/tmp",
                   _children    => 0,
                   _processes   => {},
                   _queue       => [],
                   _done        => {},
                   _n           => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Number of processors must be a positive integer >= 1") if (!isint($self->{processors}) ||
                                                                          $self->{processors} < 1);
    $self->throw("On start parameter value must be a CODE reference") if (ref($self->{onstart}) ne "CODE");
    $self->throw("On exit parameter value must be a CODE reference") if (ref($self->{onexit}) ne "CODE");
    $self->throw("parentOnExit parameter value must be a CODE reference") if (ref($self->{parentOnExit}) ne "CODE");
    $self->throw("Provided temporary directory does not exist") if (!-d $self->{tmpDir});

}

sub stderr {

    my $self = shift;
    my $stderr = shift;

    $self->{stderr} = $stderr if (defined $stderr);

    return($self->{stderr});

}

# Enqueue:
# $queue->enqueue(command => $command, arguments => \@args, id => $processuniqueid, stdout => /dev/null, stdin => /dev/null)

sub enqueue {

    my $self = shift;
    my %parameters = @_;

    $self->throw("Enqueuing requires a command") if (!exists $parameters{command});
    $self->throw("Command arguments must be an ARRAY reference") if (exists $parameters{arguments} &&
                                                                     ref($parameters{arguments}) ne "ARRAY");

    my $parameters = checkparameters({ command   => undef,
                                       arguments => [],
                                       id        => undef,
                                       stderr    => undef,
                                       stdout    => undef,
                                       tmpDir    => $self->{tmpDir} }, \%parameters);

    push(@{$self->{_queue}}, $parameters);

}

sub start {

    my $self = shift;
    my $processors = shift || $self->{processors};
    my $cleanup = 0;

    $self->throw("Processors number must be a positive integer >= 1") if (!isint($processors) || $processors < 1);

    if (!@{$self->{_queue}}) { $self->warn("Empty queue"); } 
    else {
    
        $self->throw("Cannot start while executing another queue") if ($self->{_children});

        $self->{_processes} = {};
        $self->{_done} = {};
        $self->{_n} = 0;
        $self->{_children} = 0;

        $SIG{CHLD} = sub { $cleanup = 1; };

        my $nEnqueued = @{$self->{_queue}};

        while (@{$self->{_queue}}) {

            if ($cleanup) {

                while ((my $pid = waitpid(-1, WNOHANG)) > 0) {

                    if (exists $self->{_processes}->{$pid}) {

                        $self->{_children}--;
                        $self->{_processes}->{$pid}->wait();

                        # As PIDs get recycled, this can cause collisions. We avoid it with the following
                        my $id = join(".", $self->{_processes}->{$pid}->_tmpId(), $pid);
                        $self->{_processes}->{$id} = $self->{_processes}->{$pid};
                        delete($self->{_processes}->{$pid});
                        $self->{_done}->{$id} = 1;
                        $self->{_n}++;

                        $self->{parentOnExit}->($self->{_processes}->{$id}->id(), $pid, $id);

                    }
                
                }
                
                $cleanup = 0;

            }

            if ($self->{_children} < $self->{processors}) {

                my ($parameters, $process);
                $parameters = shift(@{$self->{_queue}});

                # Ensuring reaping of all children
                if (!@{$self->{_queue}} && $nEnqueued > $self->{_n}) { push(@{$self->{_queue}}, undef); }
                
                next if (!defined $parameters);

                $process = Core::Process->new( id      => $parameters->{id},
                                               stdout  => $parameters->{stdout} || $self->{stdout},
                                               stderr  => $parameters->{stderr} || $self->{stderr},
                                               onstart => $self->{onstart},
                                               onexit  => $self->{onexit},
                                               tmpDir  => $parameters->{tmpDir} );

                $process->start($parameters->{command}, @{$parameters->{arguments}});

                $self->{_processes}->{$process->pid()} = $process;
                $self->{_children}++;

            }

        }

    }

}

sub waitall {

    my $self = shift;

    if (values %{$self->{_processes}}) {

        for (values %{$self->{_processes}}) {

            my ($pid, $jobId, $id);
            $pid = $_->pid();
            $jobId = $_->id();
            $id = join(".", $_->_tmpId(), $pid);

            next if (exists $self->{_done}->{$id});  # Skip already completed processes
            
            $_->wait();

            $self->{_children}--;

            $self->{_processes}->{$id} = $self->{_processes}->{$pid};
            $self->{_done}->{$id} = 1;
            $self->{_n}++;
            delete($self->{_processes}->{$pid});

            $self->{parentOnExit}->($jobId, $pid, $id);
        
        }
        
        $self->{_children} = 0;
    
    }

}

sub killById {

    my $self = shift;
    my @ids = @_;

    if (@ids) {

        my %ids = map { $_ => 1 } @ids;

        $self->{_processes}->{$_}->kill() for (grep { exists $ids{$self->{_processes}->{$_}->id()} } keys %{$self->{_processes}});

    }

}

sub shuffleQueue {

    my $self = shift;
    my @q = @{$self->{_queue}};

    @q = List::Util::shuffle(@q);
    $self->{_queue} = \@q;

}

sub listQueue {

    my $self = shift;
    my @ids = @_;

    my (@queue);

    if (@ids) {

        my %ids = map { $_ => 1 } @ids;
        for (0 .. $#{$self->{_queue}}) { push(@queue, $self->{_queue}->[$_]) if (exists $ids{$self->{_queue}->[$_]->{id}}); }

    }
    else { @queue = @{$self->{_queue}}; }

    return(@queue);

}

sub deleteQueue {

    my $self = shift;
    my @ids = @_;

    if (@ids) {

        my %ids = map { $_ => 1 } @ids;

        for (my $i = 0; $i < @{$self->{_queue}}; $i++) {

            if (exists $ids{$self->{_queue}->[$i]->{id}}) {

                splice(@{$self->{_queue}}, $i, 1);
                $i--;

            }

        }

    }
    else { $self->{_queue} = []; }

}

sub queueSize { return(scalar(@{$_[0]->{_queue}})); }

sub dequeue {

    my $self = shift; 
    my $id = shift;

    my $pid = (split /\./, $id)[-1];

    if (defined $id && defined $pid) {

        $self->throw("Invalid Job ID/PID ($id/$pid)") if (!exists $self->{_processes}->{$id} && !exists $self->{_processes}->{$pid});
        
        if (!exists $self->{_done}->{$id} && exists $self->{_processes}->{$pid}) {

            $self->warn("Process $pid is still running");
            
            return();

        }

    }

    if (keys %{$self->{_done}}) {

        my ($p, $process);
        $p = $id || (keys %{$self->{_done}})[0];
        $process = $self->{_processes}->{$p};

        delete($self->{_processes}->{$p});
        delete($self->{_done}->{$p});

        return($process);

    }

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

sub parentOnExit {

    my $self = shift;
    my $code = shift;

    if (defined $code) {

        $self->throw("parentOnExit parameter value must be a CODE reference") if (ref($code) ne "CODE");

        $self->{parentOnExit} = $code;

    }

}

sub processors {

    my $self = shift;
    my $processors = shift;

    $self->throw("Number of processors must be an integer >= 1") if (defined $processors &&
                                                                     (!isint($processors) ||
                                                                      $processors < 1));

    $self->{processors} = $processors if ($processors);

    return($self->{processors});

}

1;

