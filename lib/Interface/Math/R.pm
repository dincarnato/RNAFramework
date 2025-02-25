package Interface::Math::R;

use strict;

use Core::Utils;
use Data::IO;
use Term::Constants qw(:colors);

use base qw(Interface::Generic);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ R           => which("R"),
                   _tmpCmdFile => $self->{tmpdir} . "." . $self->{_randId} . ".command.tmp" }, \%parameters);

    $self->_validate() if ($class eq "Interface::Math::R");

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("No path provided to R executable") if (!defined $self->{R});
    $self->throw($self->{R} . " does not exist") if (!-e $self->{R});
    $self->throw($self->{R} . " is not executable") if (!-x $self->{R});

}

sub isPackageInstalled {

    my $self = shift;
    my @packages = @_;

    my (%packages);

    if (!@packages) { $self->warn("No package name specified"); }
    else {

        my $R = $self->{R};

        foreach my $package (@packages) {

            my $output = `$R --no-save -e 'library($package)' 2>&1`;

            if ($output =~ /there is no package called/) { $packages{$package} = 0; }
            else { $packages{$package} = 1; }

        }

    }

    return(wantarray() ? %packages : \%packages);

}

sub run {

    my $self = shift;
    my $command = shift;

    chomp($command);

    $self->throw("No command to be passed to R") if (!defined $command);

    my ($R, $tmpCmdFile, $output);
    $R = $self->{R};
    $tmpCmdFile = $self->{_tmpCmdFile};
    $self->_writeTmpCommand($command);
    
    $output = `$R --no-save --slave --vanilla 2>&1 < '$tmpCmdFile'`;
    chomp($output);

    $self->throw("R returned an error\n\n" . BOLD . $output . RESET) if ($output =~ /Error/);

    unlink($tmpCmdFile);

    return($output);

}

sub _writeTmpCommand {

    my $self = shift;
    my $command = shift;

    my $io = Data::IO->new( file      => $self->{_tmpCmdFile},
                            mode      => "w",
                            overwrite => 1 );
    $io->write($command);
    $io->close();

}

1;

