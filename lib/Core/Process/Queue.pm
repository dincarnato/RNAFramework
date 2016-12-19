package Core::Process::Queue;

use strict;
use Core::Mathematics;
use Core::Process;
use Core::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ stdout     => undef,
                   stderr     => undef,
                   processors => 1,
                   onstart    => sub {},
                   onexit     => sub {},
                   _children  => 0,
                   _processes => {},
                   _queue     => [] }, \%parameters);
    
    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->throw("Number of processors must be a positive integer >= 1") if (!isint($self->{processors}) ||
                                                                          $self->{processors} < 1);
    $self->throw("On start parameter value must be a CODE reference") if (ref($self->{onstart}) ne "CODE");
    $self->throw("On exit parameter value must be a CODE reference") if (ref($self->{onexit}) ne "CODE");
    
}

# Enqueue:
# $queue->enqueue(command => $command, arguments => \@args, id => $processuniqueid, stdout => /dev/null, stdin => /dev/null)

sub enqueue {
    
    my $self = shift;
    my %parameters = @_ if (@_);
    
    $self->throw("Enqueuing requires a command") if (!exists $parameters{command});
    $self->throw("Command arguments must be an ARRAY reference") if (exists $parameters{arguments} &&
                                                                     ref($parameters{arguments}) ne "ARRAY");
    
    my $parameters = checkparameters({ command   => undef,
                                       arguments => [],
                                       id        => undef,
                                       stderr    => undef,
                                       stdout    => undef }, \%parameters);
    
    push(@{$self->{_queue}}, $parameters);
    
}

sub start {
    
    my $self = shift;
    my $processors = shift || $self->{processors};
    
    $self->throw("Processors number must be a positive integer >= 1") if (!isint($processors) ||
                                                                          $processors < 1);
    
    if (!@{$self->{_queue}}) { $self->warn("Empty queue"); }
    else {
    
        $self->throw("Cannot start while executing another queue") if ($self->{_children});
        
        undef($self->{processes});
        
        while (my $parameters = shift(@{$self->{_queue}})) {
    
            if ($self->{_children} == $processors) {
            
                my $pid = wait();
                $self->{_children}--;
                
            } 
           
            my $process = Core::Process->new( id      => $parameters->{id},
                                              stdout  => $parameters->{stdout} || $self->{stdout},
                                              stderr  => $parameters->{stderr} || $self->{stderr},
                                              onstart => $self->{onstart},
                                              onexit  => $self->{onexit} ); 
            $process->start($parameters->{command}, @{$parameters->{arguments}});
            
            $self->{_processes}->{$process->pid()} = $process;
            
            $self->{_children}++;
          
        }
        
    }
    
}

sub waitall {
    
    my $self = shift;
    
    if (values %{$self->{_processes}}) {
    
        $_->wait() for (values %{$self->{_processes}});
        
        $self->{_children} = 0;
        
    }
    
}

sub dequeue {
    
    my $self = shift;
    
    if (values %{$self->{_processes}}) {
    
        my ($process, $pid);
        $pid = (keys %{$self->{_processes}})[0]; 
        $process = $self->{_processes}->{$pid};
        
        delete($self->{_processes}->{$pid});
        
        return($process);
        
    }
    
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

sub tee {

    my $self = shift;
  
    ($self->{stdout}, $self->{stderr}) = @_ if (@_);

}

sub processors {
    
    my $self = shift;
    my $processors = shift if (@_);
    
    $self->throw("Number of processors must be an integer >= 1") if (defined $processors &&
                                                                     (!isint($processors) ||
                                                                      $processors < 1));
    
    $self->{processors} = $processors if ($processors);
    
    return($self->{processors});
    
}

1;