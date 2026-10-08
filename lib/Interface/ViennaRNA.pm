package Interface::ViennaRNA;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::IO::Sequence;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Interface::Generic);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ RNAfold       => which("RNAfold"),
                   RNAsubopt     => which("RNAsubopt"),
                   RNAalifold    => which("RNAalifold"),
                   RNAplot       => which("RNAplot"),
                   ssPseudoknots => 0,
                   _version      => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    for (qw(RNAfold RNAsubopt RNAalifold RNAplot)) { $self->throw($_ . " is not executable (" . $self->{$_} . ")") if (defined $self->{$_} && !-x $self->{$_}); }
    $self->throw("Parameter ssPseudoknots must be BOOL") if (!isbool($self->{ssPseudoknots}));

}

##
#  Removes the temporary input files (the FASTA and SHAPE files we write
#  ourselves). The files the executables write themselves are not covered here:
#  they are removed by the call that generated them (see _outFile())
##

sub _cleanTmpFiles {

    my $self = shift;

    unlink(glob($self->{tmpdir} . "." . $self->{_randId} . "*"));

}

##
#  Reports the diagnostics an executable printed, raising an exception on the
#  fatal ones. ViennaRNA v2.7.0 replaced its logging API, changing the prefix of
#  these messages from "ERROR: " to "[ERROR]", so the severity is matched either
#  bracketed or followed by a colon. INFO and DEBUG messages are left alone
##
 
sub _checkRet {
 
    my $self = shift;
    my ($program, $ret) = @_;
 
    while ($ret =~ m/^\[?(ERROR|FATAL|WARNING)[\]:][ \t]*(.*)$/gm) {
 
        my ($level, $message) = ($1, $2);
        $message =~ s/^\s+|\s+$//g;

        next if (!length($message));
        next if ($program eq "RNAsubopt" && $level eq "ERROR" && $message =~ m/^Added \d+ bps$/);
 
        if ($level eq "WARNING") { $self->warn($program . " threw a warning (" . $message . ")"); }
        else { $self->throw($program . " threw an exception (" . $message . ")"); }
 
    }
 
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

    for (split(/\n/, $ret)) {

        if ($_ =~ m/^([\.\(\)]+) \(\s*([\d\.-]+)\)$/) { ($structure, $energy) = ($1, $2); }
        elsif ($_ =~ m/^([\.\(\)]+) \{\s*[\d\.-]+ MEA=[\d\.]+\}$/) { $mea = $1; }
        elsif ($_ =~ m/ensemble diversity ([\d\.]+)/) { $ensDiversity = $1; }

    }

    %bpprobs = $self->_parseDpFile() if (defined $structure &&
                                         ($parameters->{partitionFunction} ||
                                          $parameters->{MEA}));

    unlink($self->_outFile("_dp.ps"));
    $self->_cleanTmpFiles();

    $self->_checkRet("RNAfold", $ret);

    # RNAfold failed to backtrack a structure (this typically happens when a hard
    # constraint cannot be enforced), so there is nothing to return
    return() if (!defined $structure);

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
        $fold, $mea, $ensDiversity, @ret, %bpprobs);
    $id = "." . $self->{_randId}; # With the leading . the dp file will be hidden
    $shapeFiles = $self->{tmpdir} . $id . "_" . join(".shape," . $self->{tmpdir} . $id . "_", sort keys %{$alignment}) . ".shape";
    $command = $self->{RNAalifold} . " --noPS --shape='" . $shapeFiles . "' --id-prefix=" . $id . " -T " . $parameters->{temperature} .
               " --shapeMethod='Dm" . $parameters->{slope} . "b" . $parameters->{intercept} . "' --sci";
    $command .= " --maxBPspan=" . $parameters->{maxBPspan} if ($parameters->{maxBPspan});
    $command .= " --noClosingGU" if ($parameters->{noClosingGU});
    $command .= " --noLP" if ($parameters->{noLonelyPairs});
#   $command .= " --mis" if ($parameters->{mostInformativeSeq}); # this needs data::sequence::Structure to be adjusted to take iupac characters
    $command .= " -p" if ($parameters->{partitionFunction});
    $command .= " --MEA" if ($parameters->{MEA});
    $command .= " --ribosum_scoring" if ($parameters->{ribosumScoring});
    $command .= " " . $self->{tmpdir} . $id . ".fasta";

    $self->_makeAliInputFile($alignment);
    $self->_makeAliShapeFile($alignment, $parameters->{reactivity});

    # Note: unlike RNAfold, RNAalifold takes the hard constraint on STDIN and the
    # alignment as a file argument. Neither -C=<file> nor --constraint=<file> work:
    # the constraint is silently ignored
    if (defined $parameters->{constraint}) {

        $command .= " -C";
        $command .= " --enforceConstraint" if ($parameters->{enforceConstraint});

        $self->_makeAliConstraintFile($alignment, $parameters->{constraint});

        $command .= " < '" . $self->{tmpdir} . $id . ".constraint'";

    }

    $ret = `$command 2>&1`;
    @ret = split(/\n/, $ret);

    for (0 .. $#ret) {

        if ($ret[$_] =~ m/^>$id/) {

            $sequence = $ret[$_ + 1];
            $sequence =~ s/_/-/g;
            ($structure, $energy, $sci) = $ret[$_ + 2] =~ m/^([.\(\)]+)\s\(\s*([-\d\.]+).+?\[sci = ([-\d\.]+)\]/;

        }
        elsif ($ret[$_] =~ m/^([\.\(\)]+) \{.+? MEA=[\d\.]+\}$/) { $mea = $1; }
        elsif ($_ =~ m/ensemble diversity ([\d\.]+)/) { $ensDiversity = $1; }

    }

    %bpprobs = $self->_parseAliDpFile() if (defined $structure &&
                                            ($parameters->{partitionFunction} || $parameters->{MEA}));

    unlink($self->_outFile("_0001_dp.ps"), $self->_outFile("_0001_ali.out"));
    $self->_cleanTmpFiles();

    $self->_checkRet("RNAalifold", $ret);

    return() if (!defined $structure);

    $fold = Data::Sequence::Structure->new( sequence          => $sequence,
                                            structure         => $structure,
                                            mea               => $mea,
                                            bpprobabilities   => \%bpprobs,
                                            energy            => $energy,
                                            ensembleDiversity => $ensDiversity,
                                            sci               => $sci,
                                            noncanonical      => 1,
                                            lonelypairs       => $parameters->{noLonelyPairs} ? 0 : 1 );

    return($fold);

}

sub plot {

    my $self = shift;
    my ($input, $output, $reactivity) = @_;

    if (!$self->{_version}) {

        $self->throw("No path provided to RNAplot executable") if (!defined $self->{RNAplot});

        my $ver = `$self->{RNAplot} --version`;
        chomp($ver);

        if ($ver =~ /^RNAplot (\d+)\.(\d+)\.(\w+)/) {

            my @v = ($1, $2, $3);

            if (($v[0] == 2 && $v[1] < 7) || $v[0] < 2) {

                $self->warn("RNAplot v2.7.0 or greater is required"); 
                $self->{_version} = -1;
                
            }
            else { $self->{_version} = 1; }

        }
        else { 
            
            $self->warn("Unable to determine RNAplot version"); 
            $self->{_version} = -1;


        }

    }

    return if ($self->{_version} == - 1);

    if (ref($input) ne "Data::Sequence::Structure") {

        if (-e $input) {

            my ($io, $entry);
            $io = Data::IO::Sequence->new(file => $input);
            $entry = $io->read();

            if (!defined $entry) { $self->throw("Invalid structure file \"$input\""); }
            else {

                $self->throw("No structure found in file \"$input\"") if (!$entry->can("structure"));

                $input = $entry;

            }

        }
        else { $self->throw("Input must either be a structure file or a Data::Sequence::Structure object"); }

    }

    if ($reactivity) {

        $self->throw("Reactivity must be an ARRAY ref") if (ref($reactivity) ne "ARRAY");
        $self->throw("Reactivity and sequence have different lengths") if (@$reactivity != $input->length());

    }
    else { $reactivity = [ ("NaN") x $input->length() ]; }

    my ($id, $command, $ret, $height, $width, 
        @ret, @reactivity, %colors);
    @reactivity = @$reactivity;
    %colors = ( high => "#9A2322", 
                mid  => "#FFCD2F", 
                low  => "#000000",
                none => "#B1B3B6");
    $id = "." . $self->{_randId};
    $self->_writeFastaFile($id, $input->sequence(), $input->structure());
    $command = $self->{RNAplot} . " -f svg -i " . $self->{tmpdir} . $id . ".fasta";
    $ret = `$command 2>&1`;
    @ret = split(/\n/, $ret);

    $self->_checkRet("RNAplot", $ret);

    my $svgFile = $self->_outFile("_ss.svg");

    open(my $fh, "<", $svgFile) or $self->throw("Unable to open RNAplot's SVG file ($!)");
    open(my $wh, ">", $output) or $self->throw("Unable to write output SVG file ($!)");
    select((select($wh), $|=1)[0]);

    while (my $row = <$fh>) {

        if ($row =~ /<svg xmlns="http:\/\/www.w3.org\/2000\/svg" height="(\d+)" width="(\d+)">/) { ($height, $width) = ($1, $2); }
        elsif ($row =~ /\.nucleotide \{/) {

            print $wh <<SVG;
      .nucleotide-white {
        font-family: Arial, Helvetica, sans-serif;
        fill: white;
        color: white;
      }
SVG

        }
        elsif ($row =~ /SansSerif/) { $row =~ s/SansSerif/Arial, Helvetica, sans-serif/; }
        elsif ($row  =~ /stroke: red;/) { $row  =~ s/red/grey/; }
        elsif ($row =~ /<text\s+([^>]*class="nucleotide"[^>]*)>([acgtuACGTU])<\/text>/) {
            
            my ($attrs, $base, $x, $y);
            ($attrs, $base) = ($1, $2);
            ($x) = $attrs =~ /\bx\s*=\s*"([\d\.\-]+)"/;
            ($y) = $attrs =~ /\by\s*=\s*"([\d\.\-]+)"/;

            if (defined $x && defined $y) {

                my ($react, $color);
                $react = shift(@reactivity);
                $color = isnan($react) ? $colors{"none"} : ($react <= 0.4 ? $colors{"low"} : ($react < 0.8 ? $colors{"mid"} : $colors{"high"})); 
                
                $x += 4;
                $y -= 4;

                $row =~ s/"nucleotide"/"nucleotide-white"/ if ($color eq $colors{"high"} || $color eq $colors{"low"});
                
                print $wh "  <circle cx=\"$x\" cy=\"$y\" r=\"8\" fill=\"$color\" fill-opacity=\"0.75\" stroke=\"$color\" stroke-width=\"0.8\"/>\n";

            }

        }
        elsif ($row =~ /<\/svg>/) {

            my ($scale, $tx, $ty);
            $scale = 0.75;
            $tx = $width - 80 * $scale - 5;
            $ty = $height - 54 * $scale - 10;

        print $wh <<SVG;
<g transform="translate($tx, $ty) scale($scale)" class="legend">
  <rect x="0" y="0" width="12" height="12" fill="$colors{high}" stroke="black" />
  <text x="18" y="10" class="nucleotide">0.8+</text>
  <rect x="0" y="14" width="12" height="12" fill="$colors{mid}" stroke="black" />
  <text x="18" y="24" class="nucleotide">0.4 - 0.8</text>
  <rect x="0" y="28" width="12" height="12" fill="$colors{low}" stroke="black" />
  <text x="18" y="38" class="nucleotide">0 - 0.4</text>
  <rect x="0" y="42" width="12" height="12" fill="$colors{none}" stroke="black" />
  <text x="18" y="52" class="nucleotide">No data</text>
</g>
SVG

        }

        print $wh $row;
    }

    close($wh);
    close($fh);

    unlink($svgFile);
    $self->_cleanTmpFiles();

}

##
#  Suboptimal/sampled structures prediction (RNAsubopt)
#
#  subopt( <sequence>, { sampleSize        => <INT>,   # -p            (stochastic backtracking, 0 to disable)
#                        deltaEnergy       => <REAL>,  # -e            (energy range, kcal/mol)
#                        zuker             => <BOOL>,  # -z            (Zuker's suboptimal structures)
#                        withProbabilities => <BOOL>,  # --stochBT_en  (also report energies/probabilities)
#                        ... } )
#
#  Returns an ARRAY (or an ARRAY ref in scalar context) of HASH refs:
#
#  { structure   => <dot-bracket structure>,
#    energy      => <REAL, or undef if not reported by RNAsubopt>,
#    probability => <REAL, or undef if not reported by RNAsubopt> }
##

sub subopt {

    my $self = shift;
    my ($sequence, $parameters) = $self->_checkFoldParams(@_);

    $self->throw("No path provided to RNAsubopt executable") if (!defined $self->{RNAsubopt});

    my ($id, $command, $ret, @structures);
    $id = "." . $self->{_randId};
    $command = $self->{RNAsubopt} . " -C --shape='" . $self->{tmpdir} . $id . ".shape'" .
               " --infile='" . $self->{tmpdir} . $id . ".fasta' -T " . $parameters->{temperature} .
               " --shapeMethod='Dm" . $parameters->{slope} . "b" . $parameters->{intercept} . "'";
    $command .= " --maxBPspan=" . $parameters->{maxBPspan} if ($parameters->{maxBPspan});
    $command .= " --noClosingGU" if ($parameters->{noClosingGU});
    $command .= " --noLP" if ($parameters->{noLonelyPairs});
    $command .= " --enforceConstraint" if ($parameters->{enforceConstraint});
    $command .= " -e " . $parameters->{deltaEnergy} if (defined $parameters->{deltaEnergy});
    $command .= " -z" if ($parameters->{zuker});
    $command .= $parameters->{withProbabilities} ? " --stochBT_en=" . $parameters->{sampleSize} : " -p " . $parameters->{sampleSize} if ($parameters->{sampleSize});
    $command .= " -N" if ($parameters->{nonRedundant});
    $command .= " --sorted" if ($parameters->{sorted});

    $self->_makeInputFile($sequence, $parameters->{constraint});
    $self->_makeShapeFile($parameters->{reactivity});

    $ret = `$command 2>&1`;

    $self->_cleanTmpFiles();

    $self->_checkRet("RNAsubopt", $ret);

    foreach my $line (split(/\n/, $ret)) {

        my @line = split(" ", $line);
        @line = grep { $_ ne "[" && $_ ne "]" } map { my $f = $_; $f =~ s/^\[|\]$//g; $f } @line;

        next if (!@line || length($line[0]) != length($sequence) || !isdotbracket($line[0]));

        # In Zuker's mode energies are reported within square brackets
        for (@line[1 .. $#line]) {

            s/^[\[\(\{]//;
            s/[\]\)\}]$//;

        }

        push(@structures, { structure   => $line[0],
                            energy      => @line > 1 && isnumeric($line[1]) ? $line[1] : undef,
                            probability => @line > 2 && isnumeric($line[2]) ? $line[2] : undef });

    }

    return(wantarray() ? @structures : \@structures);

}

sub _checkFoldParams {

    my $self = shift;
    my $sequence = shift;
    my $parameters = shift || {};

    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    $self->throw("No sequence provided") if (!defined $sequence);

    $parameters = checkparameters({ reactivity        => undef,
                                    constraint        => undef,
                                    maxBPspan         => undef,
                                    deltaEnergy       => undef,
                                    enforceConstraint => 0,
                                    noLonelyPairs     => 0,
                                    noClosingGU       => 0,
                                    partitionFunction => 0,
                                    MEA               => 0,
                                    sorted            => 0,
                                    nonRedundant      => 0,
                                    zuker             => 0,
                                    withProbabilities => 0,
                                    sampleSize        => 1000,
                                    slope             => 1.8,
                                    intercept         => -0.6,
                                    temperature       => 37 }, $parameters);

    # Both reactivity and constraint can be explicitly passed as undef, in which
    # case they default to an unconstrained folding with no experimental data
    $parameters->{reactivity} = [ ("NaN") x length($sequence) ] if (!defined $parameters->{reactivity});
    $parameters->{constraint} = "." x length($sequence) if (!defined $parameters->{constraint});

    $self->throw("Reactivity must be an ARRAY ref") if (ref($parameters->{reactivity}) ne "ARRAY");
    $self->throw("Sequence contains invalid characters") if (!isna($sequence));
    $self->throw("Parameter maxBPspan span must be a positive INT") if ($parameters->{maxBPspan} &&
                                                                        (!isint($parameters->{maxBPspan}) ||
                                                                         !ispositive($parameters->{maxBPspan})));
    $self->throw("Parameter deltaEnergy must be a positive REAL") if (defined $parameters->{deltaEnergy} &&
                                                                      (!isreal($parameters->{deltaEnergy}) ||
                                                                       !ispositive($parameters->{deltaEnergy})));
    $self->throw("Parameter sampleSize must be a positive INT") if (!isint($parameters->{sampleSize}) ||
                                                                    !ispositive($parameters->{sampleSize}));

    for (qw(slope intercept temperature)) { $self->throw("Parameter " . $_ . " must be numeric") if (!isnumeric($parameters->{$_})); }
    for (qw(enforceConstraint noLonelyPairs noClosingGU partitionFunction
            nonRedundant sorted MEA zuker withProbabilities)) { $self->throw("Parameter " . $_ . " must be BOOL") if (!isbool($parameters->{$_})); }

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

    $parameters->{reactivity} = ref($alignment) eq "ARRAY" ? [] : {} if (!defined $parameters->{reactivity});

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
                                    constraint         => undef,
                                    mostInformativeSeq => 0,
                                    noLonelyPairs      => 0,
                                    noClosingGU        => 0,
                                    enforceConstraint  => 0,
                                    partitionFunction  => 0,
                                    slope              => 1.8,
                                    intercept          => -0.6,
                                    temperature        => 37,
                                    ribosumScoring     => 0,
                                    MEA                => 0 }, $parameters);

    $self->throw("Parameter maxBPspan span must be a positive INT") if ($parameters->{maxBPspan} && (!isint($parameters->{maxBPspan}) || !ispositive($parameters->{maxBPspan})));

    if (defined $parameters->{constraint}) {

        $self->throw("Constraint and alignment have different lengths") if (length($parameters->{constraint}) != $length);
        $self->throw("Constraint contains invalid characters") if (!_isConstraint($parameters->{constraint}));

    }

    for (qw(slope intercept temperature)) { $self->throw("Parameter " . $_ . " must be numeric") if (!isnumeric($parameters->{$_})); }
    for (qw(noLonelyPairs noClosingGU MEA enforceConstraint
            partitionFunction mostInformativeSeq)) { $self->throw("Parameter " . $_ . " must be BOOL") if (!isbool($parameters->{$_})); }

    $parameters->{reactivity} = \%reactivity;

    return(\%alignment, $parameters);

}

sub _makeInputFile {

    my $self = shift;
    my ($sequence, $constraint) = @_;

    my $id = "." . $self->{_randId};

    $self->_writeFastaFile($id, $sequence, $self->_nestedConstraint($sequence, $constraint));

}

##
#  ViennaRNA cannot handle pseudoknotted hard constraints, so crossing pairs are
#  removed (and, if ssPseudoknots is set, their bases are forced single-stranded).
#  Bases already marked as single-stranded ("x") are preserved
##

sub _nestedConstraint {

    my $self = shift;
    my ($sequence, $constraint) = @_;

    my ($nestedbp, $pkpairs, @unpaired);
    push(@unpaired, $-[0]) while ($constraint =~ m/x/g);
    $constraint =~ s/x/./g;
    ($nestedbp, $pkpairs) = rmpseudoknots($sequence, $constraint);

    if ($self->{ssPseudoknots}) {

        for (@{$pkpairs}) {

            substr($nestedbp, $_->[0], 1) = "x";
            substr($nestedbp, $_->[1], 1) = "x";

        }

    }

    substr($nestedbp, $_, 1) = "x" for (@unpaired);

    return($nestedbp);

}

sub _writeFastaFile {

    my $self = shift;
    my ($id, $sequence, $structure) = @_;

    open(my $wh, ">", $self->{tmpdir} . $id . ".fasta") or $self->throw("Unable to write temporary input FASTA file (" . $! . ")");
    select((select($wh), $|=1)[0]);
    print $wh ">$id\n$sequence\n$structure\n";
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

    my ($id, @reactivity);
    $id = "." . $self->{_randId};
    @reactivity = map { isnan($_) ? -999 : $_ } @{$reactivity}; # We work on a copy, to avoid altering the caller's reactivity profile

    open(my $wh, ">", $self->{tmpdir} . $id . ".shape") or $self->throw("Unable to write temporary SHAPE file (" . $! . ")");
    select((select($wh), $|=1)[0]);

    print $wh ($_ + 1) . " " . $reactivity[$_] . "\n" for (0 .. $#reactivity);

    close($wh);

}

sub _makeAliConstraintFile {

    my $self = shift;
    my ($alignment, $constraint) = @_;

    my ($id, $sequence);
    $id = "." . $self->{_randId};
    $sequence = $alignment->{(sort keys %{$alignment})[0]}; # Any sequence will do, they are all the same length

    open(my $wh, ">", $self->{tmpdir} . $id . ".constraint") or $self->throw("Unable to write temporary constraint file (" . $! . ")");
    select((select($wh), $|=1)[0]);
    print $wh $self->_nestedConstraint($sequence, $constraint) . "\n";
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

##
#  Returns the path of a file the executables name themselves (dot plots, ali.out,
#  SVGs). These are always written relative to the current working directory, and
#  never next to the --infile/--outfile paths, so they do not live in the
#  interface's temporary directory unless the caller happens to be running there.
#
#  Their names only depend on the interface's random ID, so they are reused by
#  every call on the same object. Each one is therefore an intermediate, to be
#  consumed and then removed by the very call that generated it: a leftover would
#  be silently mistaken for the output of a later call that failed to produce its own
##

sub _outFile {

    my $self = shift;
    my $suffix = shift;

    return("." . $self->{_randId} . $suffix);

}

sub _parseDpFile {

    my $self = shift;

    my ($file, %bpprobs);
    $file = $self->_outFile("_dp.ps");

    open(my $fh, "<", $file) or $self->throw("Unable to read base-pairing probabilities file (" . $! . ")");
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

    return(%bpprobs);

}

sub _parseAliDpFile {

    my $self = shift;

    my ($file, %bpprobs);
    $file = $self->_outFile("_0001_dp.ps");

    open(my $fh, "<", $file) or $self->throw("Unable to read base-pairing probabilities file (" . $! . ")");
    while(<$fh>) {

        if ($_ =~ m/hsb (\d+) (\d+) ([\d\.]+(?:e-\d+)?) ubox$/) {

            my ($i, $j, $p) = ($1, $2, $3);

            $i -= 1;         # Base numbering is 1-based
            $j -= 1;
            $p = $p ** 2;    # ViennaRNA returns sqrt(p(i,j))

            $bpprobs{$i}->{$j} = $p;
            $bpprobs{$j}->{$i} = $p;

        }

    }
    close($fh);

    return(%bpprobs);

}

sub _isConstraint { return(1) if ($_[0] =~ m/^[\.<>\(\)x]+$/); }

1;
