package Interface::Math::R;

use strict;
use IPC::Open3;
use IO::Select;
use POSIX qw(:sys_wait_h);
use Symbol qw(gensym);

use Core::Utils;
use Data::IO;
use Term::Constants qw(:colors);

use base qw(Interface::Generic);

use constant MAX_COMMAND_LEN => 1000;

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ R            => which("R"),
                   _promptReady => 0,
                   _pid         => undef,
                   _stdin       => undef,
                   _stdout      => undef,
                   _stderr      => gensym(),
                   _tmpCmdFile  => $self->{tmpdir} . "." . $self->{_randId} . ".command.tmp" }, \%parameters);

    $self->_validate() if ($class eq "Interface::Math::R");

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("No path provided to R executable") if (!defined $self->{R});
    $self->throw($self->{R} . " does not exist") if (!-e $self->{R});
    $self->throw($self->{R} . " is not executable") if (!-x $self->{R});

}

sub start {

    my $self = shift;

    my $eval = do { local $@;
                    eval { $self->{_pid} = open3($self->{_stdin}, $self->{_stdout}, $self->{_stderr}, $self->{R} . " --no-save --quiet --vanilla --interactive 2>&1"); };
                    $@; };

    chomp($eval);

    $self->throw("Error while spawning R process (" . $eval . ")") if ($eval);

    local $SIG{CHLD} = sub {

    	my ($child, $status);
        $child = waitpid($self->{_pid}, WNOHANG);
    	$status = $?;

    	$self->warn("R child process died with signal " . ($? & 127) . ", " . ($? & 128 ? "with" : "without") . " coredump") if ($status & 127 && $child > 0);

    };

    return($self->_read());

}

sub _read {

    my $self = shift;
    my $prompt = shift;

    $prompt ||= '> $';

    my ($select, $stdout, $stdin);
    $select = IO::Select->new();
    $select->add($self->{_stdout});
    $stdout = "";
    $stdin = $self->{_stdin};

    if (my @fh = $select->can_read()) {

        foreach my $fh (@fh) {

            next if (fileno($fh) != fileno($self->{_stdout}));

    		while (defined (my $len = sysread($fh, $stdout, 4096, length($stdout)))) {

    			if (!$len || $stdout =~ m/$prompt/) {

    				$select->remove($fh);

    				last;

    			}
                elsif ($stdout =~ /(?:\(.*(?:(?:yes|no)\/).*\)|:)\s*$/) { # Attempts to look for an input request

                    my ($input);
                    chomp($input = <STDIN>);
                    print $stdin $input . "\n";

                }

    		}

            if (!length($stdout)) {

                $self->warn("Filehandle closed for child's STDOUT");
                $self->_closeFh();

            }

        }

    }

    $self->{_promptReady} = $stdout =~ /$prompt/ ? 1 : (length($stdout) ? 0 : 1);

    $stdout =~ s/\n*$prompt//;

    return($stdout);

}

sub run {

    my $self = shift;
    my $command = shift;

    chomp($command);

    $self->throw("No command to be passed to R") if (!defined $command);
    $self->throw("Prompt string not found. R not ready to receive command") if (!$self->{_promptReady});

    my ($stdin, $stdout, $escape);
    $stdin = $self->{_stdin};

    if (length($command) <= MAX_COMMAND_LEN) { print $stdin "$command\n"; }
    else {

        $self->_writeTmpCommand($command);
        print $stdin "source('" . $self->{_tmpCmdFile} . "')\n";

    }

    $stdout = $self->_read();
    
    # Remove escapes and formattings
    $escape = BOLD;
    $escape = quotemeta($escape);
    $stdout =~ s/$escape//g;
    $escape = RESET;
    $escape = quotemeta($escape);
    $stdout =~ s/$escape//g;

    $command = quotemeta($command);
    $stdout =~ s/^$command\n//g;
    $stdout =~ s/\n*$//;

    $self->throw("R returned an error\n\n" . BOLD . $stdout . RESET) if ($stdout =~ /Error/);

    #unlink($self->{_tmpCmdFile}) if (length($command) > MAX_COMMAND_LEN);

    return($stdout);

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

sub chooseCRANmirror {

    my $self = shift;

    $self->throw("Prompt string not found. R not ready to receive command") if (!$self->{_promptReady});

    my ($stdin, $stdout, $n);
    $stdin = $self->{_stdin};
    print $stdin "chooseCRANmirror(graphics=FALSE)" . "\n";
    $stdout = $self->_read('Selection: $');
    $stdout =~ s/^chooseCRANmirror\(graphics=FALSE\)\n*//;
    print "\n" . $stdout;

    while(1) {

        print "\n\nSelect mirror: ";
        chomp($n = <STDIN>);
        print $stdin $n . "\n";
        $stdout = $self->_read('(?:Selection:|>) $');

        last if ($stdout !~ /Enter an item from the menu, or 0 to exit/);

    }

}

sub get {

    my $self = shift;
    my $variable = shift;

    $self->throw("No variable to get from R") if (!defined $variable);
    $self->throw("Prompt string not found. R not ready to receive command") if (!$self->{_promptReady});

    my ($stdin, $stdout, @variable);
    $stdin = $self->{_stdin};
    print $stdin $variable . "\n";
    $stdout = $self->_read();

    while ($stdout =~ m/^\s*\[\d+\] (.+)$/gm) { push(@variable, split(/ /, $1)); }

    return(@variable ? (@variable == 1 ? $variable[0] : (wantarray() ? @variable : \@variable)) : undef);

}

sub stop {

    my $self = shift;

    $self->run("q()") if (defined $self->{_pid});
    $self->_closeFh();

}

sub _closeFh {

    my $self = shift;

    if (defined $self->{_pid}) {

        close($self->{_stdin}) if (fileno($self->{_stdin}));
        close($self->{_stdout}) if (fileno($self->{_stdout}));
        close($self->{_stderr}) if (fileno($self->{_stderr}));

        undef($self->{_pid});

    }

}

sub DESTROY {

    my $self = shift;

    $self->_closeFh();
    $self->SUPER::DESTROY();

}

1;
