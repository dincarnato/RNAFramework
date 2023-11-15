package Interface::ViennaRNA;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Data::Sequence::Structure;
#use Data::Sequence::Structure::Ensemble;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Interface::Generic);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ RNAfold       => which("RNAfold"),
                   #RNAsubopt     => which("RNAsubopt"),
                   RNAalifold    => which("RNAalifold"),
                   ssPseudoknots => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    for (qw(RNAfold RNAsubopt RNAalifold)) { $self->throw($_ . " is not executable (" . $self->{$_} . ")") if (defined $self->{$_} && !-x $self->{$_}); }

}

sub fold {

    my $self = shift;
    my ($sequence, $parameters) = $self->_checkFoldParams(@_);

    $self->throw("No path provided to RNAfold executable") if (!defined $self->{RNAfold});

    my ($id, $command, $ret, $fold,
        $mea, $structure, $energy, $ensDiversity,
        %bpprobs);
    $id = "." . $self->{_randId}; # With the leading . the dp file will be hidden
    $command = $self->{RNAfold} . " --noPS -C --shape='" . $self->{tmpdir} . $id . ".shape' " .
               "--infile='" . $self->{tmpdir} . $id . ".fasta' -T " . $parameters->{temperature} . " " .
               "--shapeMethod='Dm" . $parameters->{slope} . "b" . $parameters->{intercept} . "'";
    $command .= " --maxBPspan=" . $parameters->{maxBPspan} if ($parameters->{maxBPspan});
    $command .= " --noClosingGU" if ($parameters->{noClosingGU});
    $command .= " --noLP" if ($parameters->{noLonelyPairs});
    $command .= " --enforceConstraint" if ($parameters->{enforceConstraint});
    $command .= " -p" if ($parameters->{partitionFunction});
    $command .= " --MEA" if ($parameters->{MEA});

    $self->_makeInputFile($sequence, $parameters->{constraint});
    $self->_makeShapeFile($parameters->{reactivity});

    $ret = `$command 2>&1`;

    unlink(glob($self->{tmpdir} . $id . "*"));

    while ($ret =~ m/^ERROR: (.+?)\n/g) { $self->throw("RNAfold threw an exception (" . $1 . ")"); }
    while ($ret =~ m/^WARNING: (.+?)\n/g) { $self->warn("RNAfold threw a warning (" . $1 . ")"); }

    for (split(/\n/, $ret)) {

        if ($_ =~ m/^([\.\(\)]+) \(\s*([\d\.-]+)\)$/) { ($structure, $energy) = ($1, $2); }
        elsif ($_ =~ m/^([\.\(\)]+) \{\s*[\d\.-]+ MEA=[\d\.]+\}$/) { $mea = $1; }
        elsif ($_ =~ m/ensemble diversity ([\d\.]+)/) { $ensDiversity = $1; }

    }

    %bpprobs = $self->_parseDpFile() if ($parameters->{partitionFunction} ||
                                         $parameters->{MEA});

    $fold = Data::Sequence::Structure->new( sequence          => dna2rna($sequence),
                                            structure         => $structure,
                                            mea               => $mea,
                                            bpprobabilities   => \%bpprobs,
                                            energy            => $energy,
                                            ensembleDiversity => $ensDiversity,
                                            lonelypairs       => $parameters->{noLonelyPairs} ? 0 : 1 );

    return($fold);

}

sub alifold {

    my $self = shift;
    my ($alignment, $parameters) = $self->_checkAliFoldParams(@_);

    $self->throw("No path provided to RNAalifold executable") if (!defined $self->{RNAalifold});

    my ($id, $shapeFiles, $command, $ret,
        $sequence, $structure, $sci, $energy,
        $fold, @ret);
    $id = "." . $self->{_randId}; # With the leading . the dp file will be hidden
    $shapeFiles = $self->{tmpdir} . $id . "_" . join(".shape," . $self->{tmpdir} . $id . "_", sort keys %{$alignment}) . ".shape";
    $command = $self->{RNAalifold} . " --noPS --shape='" . $shapeFiles . "' --id-prefix=" . $id . " -T " . $parameters->{temperature} .
               " --shapeMethod='Dm" . $parameters->{slope} . "b" . $parameters->{intercept} . "' --sci";
    $command .= " --maxBPspan=" . $parameters->{maxBPspan} if ($parameters->{maxBPspan});
    $command .= " --noClosingGU" if ($parameters->{noClosingGU});
    $command .= " --noLP" if ($parameters->{noLonelyPairs});
#    $command .= " --mis" if ($parameters->{mostInformativeSeq}); # this needs data::sequence::Structure to be adjusted to take iupac characters
    $command .= " -p" if ($parameters->{partitionFunction});
    $command .= " --ribosum_scoring" if ($parameters->{ribosumScoring});
    $command .= " " . $self->{tmpdir} . $id . ".fasta";

    $self->_makeAliInputFile($alignment);
    $self->_makeAliShapeFile($alignment, $parameters->{reactivity});

    $ret = `$command 2>&1`;
    @ret = split(/\n/, $ret);

    unlink(glob($self->{tmpdir} . $id . "*"));

    while ($ret =~ m/^ERROR: (.+?)\n/g) { $self->throw("RNAalifold threw an exception (" . $1 . ")"); }
    while ($ret =~ m/^WARNING: (.+?)\n/g) { $self->warn("RNAalifold threw a warning (" . $1 . ")"); }

    for (0 .. $#ret) {

        if ($ret[$_] =~ m/^>$id/) {

            $sequence = $ret[$_ + 1];
            $sequence =~ s/_/-/g;
            ($structure, $energy, $sci) = $ret[$_ + 2] =~ m/^([.\(\)]+)\s\(\s*([-\d\.]+).+?\[sci = ([\d\.]+)\]/;

        }

    }

    $fold = Data::Sequence::Structure->new( sequence     => $sequence,
                                            structure    => $structure,
                                            energy       => $energy,
                                            sci          => $sci,
                                            noncanonical => 1 );

    return($fold);

}

# sub subopt {
#
#     my $self = shift;
#     my ($sequence, $parameters) = $self->_checkFoldParams(@_);
#
#     $self->throw("No path provided to RNAsubopt executable") if (!defined $self->{RNAsubopt});
#
#     my ($id, $command, $ret, $ensemble,
#         @structures, @energies, @probs);
#     $id = "." . $self->{_randId}; # With the leading . the dp file will be hidden
#     $command = $self->{RNAsubopt} . " -C --shape='" . $self->{tmpdir} . $id . ".shape'" .
#                " --infile='" . $self->{tmpdir} . $id . ".fasta' -T " . $parameters->{temperature} .
#                " --shapeMethod='Dm" . $parameters->{slope} . "b" . $parameters->{intercept} . "'" .
#                " --stochBT_en=" . $parameters->{sampleSize};
#     $command .= " --maxBPspan=" . $parameters->{maxBPspan} if ($parameters->{maxBPspan});
#     $command .= " --noClosingGU" if ($parameters->{noClosingGU});
#     $command .= " --noLP" if ($parameters->{noLonelyPairs});
#     $command .= " --enforceConstraint" if ($parameters->{enforceConstraint});
#     $command .= " -N" if ($parameters->{nonRedundant});
#     $command .= " --sorted" if ($parameters->{sorted});
#
#     $self->_makeInputFile($sequence, $parameters->{constraint});
#     $self->_makeShapeFile($parameters->{reactivity});
#
#     $ret = `$command 2>&1`;
#
#     unlink(glob($self->{tmpdir} . $id . "*"));
#
#     while ($ret =~ m/^ERROR: (.+?)\n/g) { $self->throw("RNAsubopt threw an exception (" . $1 . ")"); }
#     while ($ret =~ m/^WARNING: (.+?)\n/g) { $self->warn("RNAsubopt threw a warning (" . $1 . ")"); }
#
#     for (split(/\n/, $ret)) {
#
#         my @line = split(" ", $_);
#
#         next if (@line < 3);
#
#         push(@structures, $line[0]);
#         push(@energies, $line[1]);
#         push(@probs, $line[2]);
#
#     }
#
#     $ensemble = Data::Sequence::Structure::Ensemble->new( sequence      => dna2rna($sequence),
#                                                           structures    => \@structures,
#                                                           energies      => \@energies,
#                                                           probabilities => \@probs );
#
#     return($ensemble);
#
# }

sub _checkFoldParams {

    my $self = shift;
    my $sequence = shift if (@_);
    my $parameters = shift || {};

    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    $parameters = checkparameters({ reactivity        => [ ("NaN") x length($sequence) ],
                                    constraint        => "." x length($sequence),
                                    maxBPspan         => undef,
                                    enforceConstraint => 0,
                                    noLonelyPairs     => 0,
                                    noClosingGU       => 0,
                                    partitionFunction => 0,
                                    MEA               => 0,
                                    sorted            => 0,
                                    nonRedundant      => 0,
                                    sampleSize        => 1000,
                                    slope             => 1.8,
                                    intercept         => -0.6,
                                    temperature       => 37 }, $parameters);

    $self->throw("No sequence provided") if (!defined $sequence);
    $self->throw("Sequence contains invalid characters") if (!isna($sequence));
    $self->throw("Parameter maxBPspan span must be a positive INT") if ($parameters->{maxBPspan} &&
                                                                        (!isint($parameters->{maxBPspan}) ||
                                                                         !ispositive($parameters->{maxBPspan})));

    for (qw(slope intercept temperature sampleSize)) { $self->throw("Parameter " . $_ . " must be numeric") if (!isnumeric($parameters->{$_})); }
    for (qw(enforceConstraint noLonelyPairs noClosingGU
            partitionFunction nonRedundant sorted MEA)) { $self->throw("Parameter " . $_ . " must be BOOL") if (!isbool($parameters->{$_})); }

    $self->throw("Constraint and sequence have different lengths") if (length($parameters->{constraint}) != length($sequence));
    $self->throw("Constraint contains invalid characters") if (!_isConstraint($parameters->{constraint}));
    $self->throw("Reactivity and sequence have different lengths") if (@{$parameters->{reactivity}} != length($sequence));

    return($sequence, $parameters);

}

sub _checkAliFoldParams {

    my $self = shift;
    my $alignment = shift;
    my $parameters = shift || {};

    my ($length, %alignment, %reactivity);

    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    $parameters->{reactivity} = ref($alignment) eq "ARRAY" ? [] : {} if (!exists $parameters->{reactivity});

    $self->throw("Alignment must be an ARRAY or HASH reference") if (ref($alignment) ne "ARRAY" && ref($alignment) ne "HASH");
    $self->throw("Reactivity must be an ARRAY or HASH reference") if (ref($parameters->{reactivity}) ne "ARRAY" && ref($parameters->{reactivity}) ne "HASH");
    $self->throw("Alignment and reactivity reference type must match") if (ref($alignment) ne ref($parameters->{reactivity}));

    if (ref($alignment) eq "ARRAY") {

        $self->throw("Alignment and reactivity must have the same number of elements") if (@{$parameters->{reactivity}} && @{$alignment} != @{$parameters->{reactivity}});

        for (0 .. $#{$alignment}) {

            $alignment{$_ + 1} = dna2rna($alignment->[$_]);
            $reactivity{$_ + 1} = $parameters->{reactivity}->[$_] if (@{$parameters->{reactivity}});

        }

    }
    else {

        %alignment = map { $_ => dna2rna($alignment->{$_}) } keys %{$alignment};
        %reactivity = %{$parameters->{reactivity}};

    }

    $self->throw("No alignment provided") if (!keys %alignment);

    foreach my $id (sort keys %alignment) {

        my ($niceId, $sequence, $realLen);
        $niceId = ref($alignment) eq "ARRAY" ? "#" . $id : "\"" . $id . "\"";
        $sequence = $alignment{$id};
        $length = length($sequence) if (!$length);

        $self->throw("Sequence " . $niceId . " contains invalid characters") if (!isna($sequence, "-"));
        $self->throw("Different length for sequence " . $niceId . " in alignment") if (length($sequence) != $length);

        $sequence =~ s/-//g;
        $realLen = length($sequence);

        if (exists $reactivity{$id}) { $self->throw("Reactivity and sequence length differ for sequence " . $niceId) if ($realLen != @{$reactivity{$id}}); }
        else { $reactivity{$id} = [("NaN") x $realLen]; }

    }

    # Prunes reactivity profiles that do not have a match in alignment
    %reactivity = map { $_ => $reactivity{$_} } grep { exists $alignment{$_} } keys %reactivity;

    $parameters = checkparameters({ maxBPspan          => undef,
                                    mostInformativeSeq => 0,
                                    noLonelyPairs      => 0,
                                    noClosingGU        => 0,
                                    partitionFunction  => 0,
                                    slope              => 1.8,
                                    intercept          => -0.6,
                                    temperature        => 37,
                                    ribosumScoring     => 0 }, $parameters);

    $self->throw("Parameter maxBPspan span must be a positive INT") if ($parameters->{maxBPspan} &&
                                                                        (!isint($parameters->{maxBPspan}) ||
                                                                         !ispositive($parameters->{maxBPspan})));

    for (qw(slope intercept temperature)) { $self->throw("Parameter " . $_ . " must be numeric") if (!isnumeric($parameters->{$_})); }
    for (qw(noLonelyPairs noClosingGU
            partitionFunction mostInformativeSeq)) { $self->throw("Parameter " . $_ . " must be BOOL") if (!isbool($parameters->{$_})); }

    $parameters->{reactivity} = \%reactivity;

    return(\%alignment, $parameters);

}

sub _makeInputFile {

    my $self = shift;
    my ($sequence, $constraint) = @_;

    my ($id, $nestedbp, $pkpairs, @unpaired);
    push(@unpaired, $-[0]) while ($constraint =~ m/x/g);
    $constraint =~ s/x/./g;
    ($nestedbp, $pkpairs) = rmpseudoknots($sequence, $constraint);
    $id = "." . $self->{_randId};

    if ($self->{ssPseudoknots}) {

        for (@{$pkpairs}) {

            substr($nestedbp, $_->[0], 1) = "x";
            substr($nestedbp, $_->[1], 1) = "x";

        }

    }

    substr($nestedbp, $_, 1) = "x" for (@unpaired);

    open(my $wh, ">", $self->{tmpdir} . $id . ".fasta") or $self->throw("Unable to write temporary input FASTA file (" . $! . ")");
    select((select($wh), $|=1)[0]);
    print $wh ">" . $id . "\n" . $sequence . "\n" . $nestedbp . "\n";
    close($wh);

}

sub _makeAliInputFile {

    my $self = shift;
    my $alignment = shift;

    my $id = "." . $self->{_randId};

    open(my $wh, ">", $self->{tmpdir} . $id . ".fasta") or $self->throw("Unable to write temporary input alignment file (" . $! . ")");
    select((select($wh), $|=1)[0]);
    print $wh ">" . $_ . "\n" . $alignment->{$_} . "\n" for (sort keys %{$alignment});
    close($wh);

}

sub _makeShapeFile {

    my $self = shift;
    my $reactivity = shift;

    my $id = "." . $self->{_randId};
    @{$reactivity} = map { isnan($_) ? -999 : $_ } @{$reactivity};

    open(my $wh, ">", $self->{tmpdir} . $id . ".shape") or $self->throw("Unable to write temporary SHAPE file (" . $! . ")");
    select((select($wh), $|=1)[0]);

    print $wh ($_ + 1) . " " . $reactivity->[$_] . "\n" for (0 .. $#{$reactivity});

    close($wh);

}

sub _makeAliShapeFile {

    my $self = shift;
    my ($alignment, $reactivity) = @_;

    my $id = "." . $self->{_randId};

    foreach my $seqId (keys %{$alignment}) {

        my ($sequence, @reactivity);
        $sequence = $alignment->{$seqId};
        $sequence =~ s/-//g;
        @reactivity = map { sprintf("%.3f", isnan($_) ? -999 : $_) } @{$reactivity->{$seqId}};

        open(my $wh, ">", $self->{tmpdir} . $id . "_" . $seqId . ".shape") or $self->throw("Unable to write temporary SHAPE file (" . $! . ")");
        select((select($wh), $|=1)[0]);

        print $wh ($_ + 1) . " " . substr($sequence, $_, 1) . " " . $reactivity[$_] . "\n" for (0 .. $#reactivity);

        close($wh);

    }

}

sub _parseDpFile {

    my $self = shift;

    my ($id, %bpprobs);
    $id = "." . $self->{_randId};

    open(my $fh, "<", $id . "_dp.ps") or $self->throw("Unable to read base-pairing probabilities file (" . $! . ")");
    while(<$fh>) {

        if ($_ =~ m/^(\d+) (\d+) ([\d\.]+(?:e-\d+)?) ubox$/) {

            my ($i, $j, $p) = ($1, $2, $3);

            $i -= 1;         # Base numbering is 1-based
            $j -= 1;
            $p = $p ** 2;    # ViennaRNA returns sqrt(p(i,j))

            $bpprobs{$i}->{$j} = $p;
            $bpprobs{$j}->{$i} = $p;

        }

    }
    close($fh);

    unlink($id . "_dp.ps");

    return(%bpprobs);

}

sub _isConstraint { return(1) if ($_[0] =~ m/^[\.<>\(\)x]+$/); }

1;
