package Interface::Rscape;

use strict;
use File::Copy;

use Core::Mathematics;
use Core::Utils;
use Data::IO::Sequence;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use Interface::Rscape::Results;
use RNA::Utils;

use base qw(Interface::Generic);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ Rscape => which("R-scape"),
                   imgDir => undef }, \%parameters);

    $self->_validate();
    $self->_makeDir("imgDir") if (defined $self->{imgDir});

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("No path provided to R-scape executable") if (!defined $self->{Rscape});
    $self->throw("R-scape (" . $self->{Rscape} . ") is not executable") if (defined $self->{Rscape} && !-x $self->{Rscape});

}

sub imgDir {

    my $self = shift;
    my $imgDir = shift;

    if (defined $imgDir) {

        $self->{imgDir} = $imgDir;
        $self->_makeDir("imgDir");

    }

    return($self->{imgDir});

}

sub Rscape {

    my $self = shift;
    my ($alnFile, $parameters) = $self->_checkRscapeParams(@_);

    my ($tmpBasename, $command, $ret, $results);
    $tmpBasename = $self->{tmpdir} . "." . $self->{_randId};
    $command = $self->{Rscape} . " --outdir '" . $self->{tmpdir} . "' --outname ." . $self->{_randId} .
               " -E " . $parameters->{evalue} .  " --E_hlx " . $parameters->{helixEvalue};
    $command .= " --" . $parameters->{helixMethod} if (defined $parameters->{helixMethod});
    $command .= " -s" if ($parameters->{twoSet});
    for (qw(Rfam cacofold)) { $command .= " --$_" if ($parameters->{$_}); }

    $ret = `$command '$alnFile' 2>&1`;
    $self->_writeLogs("Rscape.log", $ret);

    for (qw(cov helixcov power)) { 
        
        $self->throw("Covariation analysis failed. Output from R-scape:\n\n$ret") if (!-e "$tmpBasename.$_" || ($parameters->{cacofold} && !-e "$tmpBasename.cacofold.$_"));

    }

    $results = Interface::Rscape::Results->new( covFile              => "$tmpBasename.cov",
                                                helixCovFile         => "$tmpBasename.helixcov",
                                                cacofoldCovFile      => $parameters->{cacofold} ? "$tmpBasename.cacofold.cov" : undef,
                                                cacofoldHelixCovFile => $parameters->{cacofold} ? "$tmpBasename.cacofold.helixcov" : undef );

    if (defined $self->{imgDir}) {

        my $img = -e "$tmpBasename.RFview.sto.pdf" ? "$tmpBasename.RFview.sto.pdf" : (-e "$tmpBasename.R2R.sto.pdf" ? "$tmpBasename.R2R.sto.pdf" : undef);
        
        if (defined $img) {
            
            my ($imgFile) = $alnFile =~ /([^\/]+)$/;
            $imgFile =~ s/\.(?:sto(?:ckholm)?|stk)?$/.pdf/;
            copy($img, $self->{imgDir} . $imgFile);

        }

    }

    unlink(glob("$tmpBasename*"));

    return($results);

}

sub _checkRscapeParams {

    my $self = shift;
    my $cmFile = shift;
    my $parameters = shift || {};

    $self->_checkCmFile($cmFile);

    $parameters = checkparameters({ evalue      => 0.05,
                                    twoSet      => 0,
                                    cacofold    => 0,
                                    Rfam        => 0,
                                    helixMethod => undef,
                                    helixEvalue => 0.05 }, $parameters);

    $parameters->{helixMethod} = lc($parameters->{helixMethod}) if (defined $parameters->{helixMethod});

    $self->throw("Invalid helix p-value aggregation method \"" . $parameters->{helixMethod} . "\"") if (defined $parameters->{helixMethod} && $parameters->{helixMethod} !~ /^(?:(?:wfisher|lancaster)(?:_join|_double)?|fisher|sidak)$/);

    for (qw(evalue helixEvalue)) { $self->throw("Parameter $_ must be >= 0") if (defined $parameters->{$_} && !ispositive($parameters->{$_})); }
    for (qw(Rfam cacofold twoSet)) { $self->throw("Parameter $_ must be BOOL") if (!isbool($parameters->{$_})); }

    if ($parameters->{Rfam} && !$parameters->{cacofold}) {

        $self->warn("Enabling cacofold as Rfam was specified");
        $parameters->{cacofold} = 1;

    }

    return($cmFile, $parameters);

}

sub _checkCmFile {

    my $self = shift;
    my $cmFile = shift;

    $self->throw("No CM file specified") if (!defined $cmFile);
    $self->throw("Provided CM file does not exist") if (!-e $cmFile);

}

1;