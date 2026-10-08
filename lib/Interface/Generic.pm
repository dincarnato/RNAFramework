package Interface::Generic;

use strict;
use Core::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ tmpdir       => "/tmp/",
                   logDir       => undef,
                   _pid         => $$,
                   _rmOnDestroy => [],
                   _randId      => "$$." . randalphanum(0x16) }, \%parameters);

    $self->_makeDir("tmpdir", 1);
    $self->_makeDir("logDir") if (defined $self->{logDir});

    return($self);

}

sub logDir {

    my $self = shift;
    my $logDir = shift;

    if (defined $logDir) {

        $self->{logDir} = $logDir;
        $self->_makeDir("logDir");

    }

    return($self->{logDir});

}

sub _makeDir {

    my $self = shift;
    my $dirId = shift;
    my $rmOnDestroy = shift;

    my $dir = $self->{$dirId};

    $self->throw("Provided path to temporary directory does not point to a folder") if (-e $dir && !-d $dir);

    if (defined $dir && !-e $dir) {

        my $error = mktree($dir, "755");

        $self->throw("Unable to create temporary directory ($error)") if (defined $error);

        push(@{$self->{_rmOnDestroy}}, $dir) if ($rmOnDestroy);

    }

    $self->{$dirId} =~ s/\/?$/\//; # Adds the trailing /

}

sub _writeLogs {

    my $self = shift;
    my $filename = shift;
    my $log = shift;

    if (defined $self->{logDir}) {

        open(my $lh, ">>", $self->{logDir} . $filename) or $self->throw("Unable to write \"$filename\" log file ($!)");
        print $lh "$log\n";
        close($lh);

    }

}

sub DESTROY {

    my $self = shift;

    return if ($self->{_pid} != $$);

    foreach my $dir (@{$self->{_rmOnDestroy}}) {

        my $error = rmtree($dir);

        $self->throw("Failed to remove directory \"$dir\" ($error)") if (defined $error);

    }

}

1;
