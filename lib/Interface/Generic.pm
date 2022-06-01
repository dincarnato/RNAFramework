package Interface::Generic;

use strict;
use Core::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ tmpdir      => "/tmp/",
                   _madetmpdir => 0,
                   _randId     => randalphanum(0x16) }, \%parameters);

    $self->_makeTmpDir();

    return($self);

}

sub _makeTmpDir {

    my $self = shift;

    $self->throw("Provided path to temporary directory does not point to a folder") if (-e $self->{tmpdir} && !-d $self->{tmpdir});

    if (defined $self->{tmpdir} && !-e $self->{tmpdir}) {

        my $error = mktree($self->{tmpdir});

        $self->throw("Unable to create temporary directory (" . $error . ")") if (defined $error);

        $self->{_madetmpdir} = 1;

    }

    $self->{tmpdir} =~ s/\/?$/\//; # Adds the trailing /

}

sub DESTROY {

    my $self = shift;

    if ($self->{_madetmpdir}) {

        my $error = rmtree($self->{tmpdir});

        $self->throw("Failed to remove temporary directory (" . $error . ")") if (defined $error);

    }

}

1;
