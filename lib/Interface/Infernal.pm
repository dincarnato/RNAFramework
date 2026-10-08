package Interface::Infernal;

use strict;
use File::Copy;

use Core::Mathematics;
use Core::Utils;
use Data::IO::Sequence;
use Data::Sequence::Structure;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Interface::Generic);

my @programs = qw(cmscan cmpress cmbuild cmsearch cmcalibrate cmalign);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ (map { $_ => which($_) } @programs),
                   checkAllProgs => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    my $nProgs = 0;

    for (@programs) { 
        
        if (defined $self->{$_}) {

            $self->throw("$_ (" . $self->{$_} . ") is not executable") if (!-x $self->{$_});

            $nProgs++;

        }
        
    }

    $self->throw("No path provided to any Infernal suite's program") if (!$nProgs);
    $self->throw("Path missing for " . (@programs - $nProgs) . " Infernal suite's programs") if ($self->{checkAllProgs} && $nProgs != @programs);

}

sub cmbuild {

    my $self = shift;
    my ($alnFile, $parameters) = $self->_checkCmbuildParams(@_); # Alignment, parameters

    $self->throw("No path provided to cmbuild executable") if (!defined $self->{cmbuild});

    unlink($parameters->{cmFile});

    my ($command, $ret);
    $command = $self->{cmbuild} . " -F '" . $parameters->{cmFile} . "' '$alnFile'"; 
    $ret = `$command 2>&1`; 
    $self->_writeLogs("cmbuild.log", $ret);

    unlink(glob($self->{tmpdir} . "." . $self->{_randId} . "*"));

    if ($ret =~ m/(?:FATAL|Error): (.+?)\n/) { $self->throw("cmbuild threw an exception ($1)"); }

    $self->throw("Covariance model generation failed. Output from cmbuild:\n\n$ret") if (!-e $parameters->{cmFile});

}

sub cmpress {

    my $self = shift;
    my $cmFile = shift;

    $self->throw("No path provided to cmpress executable") if (!defined $self->{cmpress});
    $self->_checkCmFile($cmFile);

    my ($command, $ret);
    $command = $self->{cmpress} . " -F '$cmFile'";
    $ret = `$command 2>&1`;
    $self->_writeLogs("cmpress.log", $ret);

    if ($ret =~ m/(?:FATAL|Error): (.+?)\n/) { $self->throw("cmpress threw an exception ($1)"); }

    for (qw(f i m p)) { $self->throw("Covariance model pressing failed. Output from cmpress:\n\n$ret") if (!-e "$cmFile.i1$_"); }

}

sub cmcalibrate {

    my $self = shift;
    my ($cmFile, $parameters) = $self->_checkCmcalibrateParams(@_);

    $self->throw("No path provided to cmcalibrate executable") if (!defined $self->{cmcalibrate});

    my ($command, $ret);

    if ($parameters->{forecast}) { $command = $self->{cmcalibrate} . " --forecast --nforecast " . $parameters->{threads} . " '$cmFile'"; }
    else { $command = $self->{cmcalibrate} . " --cpu " . $parameters->{threads} . " '$cmFile'"; }

    $ret = `$command 2>&1`;
    $self->_writeLogs("cmcalibrate.log", $ret);

    if ($ret =~ m/(?:FATAL|Error): (.+?)\n/) { $self->throw("cmcalibrate threw an exception ($1)"); }

    if ($parameters->{forecast}) { 

        my @eta = $ret =~ m/(\d{2}):(\d{2}):(\d{2})/;
        
        return($eta[0] * 3600 + $eta[1] * 60 + $eta[2]); # Time in seconds

    }

}

sub fakeCmcalibrate {

    my $self = shift;
    my $cmFile = shift;

    $self->_checkCmFile($cmFile);

    my $tmpCmFile = $self->{tmpdir} . "." . $self->{_randId} . ".cm";

    open(my $fh, "<", $cmFile) or $self->throw("Unable to read \"$cmFile\" CM file ($!)");
    open(my $wh, ">", $tmpCmFile) or $self->throw("Unable to write \"$tmpCmFile\" temporary CM file ($!)");
    select((select($wh), $|=1)[0]);
    while(<$fh>) {

        if ($_ =~ m/^CM/) { 

            # Fake parameters to trick cmsearch into believing that model has been calibrated
            # Note: these can be from any covariance model previously calibrated with cmcalibrate
            print $wh "ECMLC    0.5   -10     5     1000000	  100000  0.005\n" .
                      "ECMGC    0.5   -10    -5     1000000	  100000  0.005\n" .
                      "ECMLI    0.5   -10     5     1000000	  100000  0.005\n" .
                      "ECMGI    0.5   -10    -5     1000000	  100000  0.005\n";

        }

        print $wh $_;

    }
    close($wh);
    close($fh);

    copy($tmpCmFile, $cmFile) or $self->throw("Unable to overwrite CM file ($!)");
    unlink($tmpCmFile);

}

sub cmalign {

    my $self = shift;
    my ($cmFile, $seqFile, $parameters) = $self->_checkCmalignParams(@_);

    my ($command, $ret);
    $command = $self->{cmalign} . " -o " . $parameters->{output} . " --cpu " . $parameters->{threads};
    $command .= " --noprob" if ($parameters->{noProb});
    $ret = `$command '$cmFile' '$seqFile' 2>&1`; 
    $self->_writeLogs("cmalign.log", $ret);

    if ($ret =~ m/(?:FATAL|Error): (.+?)\n/) { $self->throw("cmalign threw an exception ($1)"); }

    $self->throw("Alignment to covariance model failed. Output from cmalign:\n\n$ret") if (!-e $parameters->{output});

    return($parameters->{output});

}

sub cmscan {

    my $self = shift;
    
    return($self->_cms("cmscan", @_));

}

sub cmsearch {

    my $self = shift;
    
    return($self->_cms("cmsearch", @_));

}

sub _cms {

    my $self = shift;
    my $tool = shift; 
    my ($cmFile, $dbFile, $parameters) = $self->_checkCmsParams(@_);

    $self->throw("Invalid tool $tool") if ($tool !~ /^cms(?:can|earch)$/);
    $self->throw("No path provided to $tool executable") if (!defined $self->{$tool});

    my ($command, $ret, @results);
    $command = $self->{$tool} . " --notextw --cpu " . $parameters->{threads} . " --tblout " . $parameters->{tableOut};
    $command .= " -E " . $parameters->{evalue} if (defined $parameters->{evalue});
    $command .= " --incE " . $parameters->{incEvalue} if (defined $parameters->{incEvalue});
    $command .= " -T " . $parameters->{bitScore} if (defined $parameters->{bitScore});
    $command .= " --incT " . $parameters->{incbitScore} if (defined $parameters->{incbitScore});
    $command .= " --toponly" if ($parameters->{topOnly});
    $command .= " --nohmmonly" if ($parameters->{noHMMOnly});
    $command .= " --rfam" if ($parameters->{Rfam});
    $command .= " --notrunc" if ($parameters->{noTruncated});

    if ($parameters->{noAlignment}) { $command .= " --noali"; }
    else { $command .= " -o " . $parameters->{output}; }

    $ret = `$command '$cmFile' '$dbFile' 2>&1`; 
    $self->_writeLogs("$tool.log", $ret);

    if ($ret =~ m/(?:FATAL|Error): (.+?)\n/) { $self->throw("$tool threw an exception ($1)"); }

    $self->throw("Covariance model search failed. Output from $tool:\n\n$ret") if (!-e $parameters->{tableOut});

    @results = $self->_parseTable($parameters->{tableOut});

    if (!$parameters->{noAlignment}) { 
       
        my @aln = $self->_parseAln($parameters->{output});
        
        $self->throw("Different number of matches and alignments (" . scalar(@results) . " matches, " . scalar(@aln) . " alignments)") if (@aln != @results);
        
        # Merges the features parsed from the alignments into the results table
        for my $i (0 .. $#results) { @{$results[$i]}{keys %{$aln[$i]}} = values %{$aln[$i]}; }

    }

    unlink(glob($self->{tmpdir} . "." . $self->{_randId} . "*"));

    return(@results);

}

sub _checkCmbuildParams {

    my $self = shift;
    my $alignment = shift;
    my $parameters = shift || {};

    my ($length, $file, $structure, $tmpBasename,
        %alignment);
    $tmpBasename = $self->{tmpdir} . "." . $self->{_randId};
    
    $structure = exists $parameters->{structure} ? $parameters->{structure} : undef;

    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    if (ref($alignment) =~ /^ARRAY|HASH$/) {

        $length = length($structure);
        
        $self->throw("No structure provided") if (!$length);
        $self->throw("Invalid structure") if (!isdbbalanced($structure));

        if (ref($alignment) eq "ARRAY") { $alignment{"seq#" . ($_ + 1)} = dna2rna($alignment->[$_]) for (0 .. $#{$alignment}); }
        else { %alignment = map { $_ => dna2rna($alignment->{$_}) } keys %{$alignment}; }

        $self->throw("No alignment provided") if (!keys %alignment);

        foreach my $id (sort keys %alignment) {

            my $sequence = $alignment{$id};

            $self->throw("Sequence \"$id\" contains invalid characters") if (!isna($sequence, "-"));
            $self->throw("Length for sequence \"$id\" does not match length of structure") if (length($sequence) != $length);

        }

        $file = "$tmpBasename.sto";
        $self->_writeStockholmFile($file, $alignment, $structure);

    }
    else {

        if (!defined $alignment) { $self->throw("No alignment provided"); }
        elsif (!-e $alignment) { $self->throw("Alignment must be a file, ARRAY or HASH reference"); }

    }

    $parameters = checkparameters({ cmFile => "$tmpBasename.cm" }, $parameters);

    return($file || $alignment, $parameters);

}

sub _checkCmcalibrateParams {

    my $self = shift;
    my $cmFile = shift;
    my $parameters = shift || {};

    $self->_checkCmFile($cmFile);

    $parameters = checkparameters({ threads  => 1,
                                    forecast => 0 }, $parameters);

    $self->throw("Number of threads must be a positive INT >= 1") if (!isint($parameters->{threads}) || $parameters->{threads} < 1);

    return($cmFile, $parameters);

}

sub _checkCmsParams {

    my $self = shift;
    my $cmFile = shift;
    my $dbFile = shift;
    my $parameters = shift || {}; 

    $self->_checkCmFile($cmFile);
    $self->throw("No sequence database file specified") if (!defined $dbFile);
    $self->throw("Provided sequence database file does not exist") if (!-e $dbFile);

    my $tmpBasename = $self->{tmpdir} . "." . $self->{_randId};
    $parameters = checkparameters({ threads     => 1,
                                    topOnly     => 0,
                                    evalue      => undef,
                                    bitScore    => undef,
                                    incEvalue   => undef,
                                    incBitScore => undef,
                                    noHMMOnly   => 0,
                                    Rfam        => 0,
                                    noAlignment => 0,
                                    noTruncated => 0,
                                    tableOut    => "$tmpBasename.tab",
                                    output      => "$tmpBasename.out" }, $parameters);

    $self->throw("Number of threads must be a positive INT >= 1") if (!isint($parameters->{threads}) || $parameters->{threads} < 1);
    for (qw(evalue bitScore incEvalue incBitScore)) { $self->throw("Parameter $_ must be >= 0") if (defined $parameters->{$_} && !ispositive($parameters->{$_})); }
    for (qw(Rfam noAlignment topOnly noTruncated)) { $self->throw("Parameter $_ must be BOOL") if (!isbool($parameters->{$_})); }

    my ($useEvalue, $useBitScore);
    $useEvalue = 1 if ($parameters->{evalue} || $parameters->{incEvalue});
    $useBitScore = 1 if ($parameters->{bitScore} || $parameters->{incBitScore});

    $self->throw("E-value and bit score thresholds are mutually exclusive") if ($useEvalue && $useBitScore);

    return($cmFile, $dbFile, $parameters);

}

sub _checkCmalignParams {

    my $self = shift;
    my $cmFile = shift;
    my $seqFile = shift;
    my $parameters = shift || {};

    $self->_checkCmFile($cmFile);
    $self->throw("No sequence file specified") if (!defined $seqFile);
    $self->throw("Provided sequence file does not exist") if (!-e $seqFile);

    my $tmpBasename = $self->{tmpdir} . "." . $self->{_randId};
    $parameters = checkparameters({ threads => 1,
                                    noProb  => 0,
                                    output  => "$tmpBasename.sto" }, $parameters);
    
    $self->throw("Number of threads must be a positive INT >= 1") if (!isint($parameters->{threads}) || $parameters->{threads} < 1);
    for (qw(noProb)) { $self->throw("Parameter $_ must be BOOL") if (!isbool($parameters->{$_})); }

    return($cmFile, $seqFile, $parameters);

}

sub _writeStockholmFile {

    my $self = shift;
    my ($file, $alignment, $structure) = @_;

    open(my $wh, ">", $file) or $self->throw("Unable to write temporary input Stockholm file ($!)");
    select((select($wh), $|=1)[0]);

    print $wh "# STOCKHOLM 1.0\n" .
              join("\n", map { join(" ", $_, $alignment->{$_}) } keys %$alignment) . "\n" .
              "#=GC SS_cons $structure\n" .
              "//";
    close($wh);

}

sub _checkCmFile {

    my $self = shift;
    my $cmFile = shift;

    $self->throw("No CM file specified") if (!defined $cmFile);
    $self->throw("Provided CM file does not exist") if (!-e $cmFile);

}

sub _parseAln {

    my $self = shift;
    my $outFile = shift;

    my (@aln);

    open(my $fh, "<", $outFile) or $self->throw("Unable to read output file \"$outFile\" ($!)");
    local $/ = "//";

    while(my $block = <$fh>) {

        foreach my $entry (split(/^>>/m, (split(/Hit alignments:/, $block))[1])) {

            next if ($entry =~ /No hits detected that satisfy reporting thresholds/ || $entry !~ /\w/);

            # 6 - Structure
            # 9 - Sequence of match
            my ($modelGaps, @entry);
            $modelGaps = 0;
            @entry = split /\n/, $entry;

            if ($entry[7] =~ /\*\[\s*\d+\]\*/) { # Sequence of model

                my $i = 0;

                while($entry[7] =~ /\*\[\s*(\d+)\]\*/g) {

                    my $len = $1;
                    $modelGaps += $len;

                }

            }
            
            # To finish implementing
            # if ($entry[9] =~ /\*\[\s*\d+\]\*/) { # Sequence of match

            #     my ($i, @gaps);
            #     $i = 0;

            #     while($entry[9] =~ /(\*\[\s*(\d+)\]\*)/g) {

            #         my ($gap, $len) = ($1, $2);
            #         $i = index($entry[9], $gap, $i);
                    
            #         $i += $gaps[-1]->[1] - $gaps[-1]->[0] if (@gaps);

            #         push(@gaps, [length($gap), $len, $i]);
            #         $i++;

            #     }

            #     foreach my $gap (@gaps) { substr($entry[6], $gap->[2], $gap->[0]) = "." x $gap->[1]; }
                
            #     $entry[6] =~ s/^\s+|(?:\s+CS)$//g;

            #     # Now the large gaps in structure are filled with dots, but there might still be gaps in the sequence
            #     # so that has to be handled as well. Will implement when needed.

            # }

            push(@aln, { modelGaps => $modelGaps });

        }

    }

    close($fh);

    return(@aln);

}

sub _parseTable {

    my $self = shift;
    my $outFile = shift;

    my (@table);

    open(my $fh, "-|", "grep -v '^#' $outFile") or $self->throw("Unable to read output table file \"$outFile\" ($!)");
    while(<$fh>) {

        chomp;
        my @line = split " ";

        next if (@line < 17);

        push(@table, { target     => $line[0],
                       accession  => $line[1] eq "-" ? undef : $line[1],
                       query      => $line[2],
                       accession  => $line[3] eq "-" ? undef : $line[3],
                       model      => $line[4],
                       modelFrom  => $line[5] - 1, # Bring to 0-based
                       modelTo    => $line[6] - 1, # Bring to 0-based
                       targetFrom => ($line[9] eq "+" ? $line[7] : $line[8]) - 1, # Bring to 0-based
                       targetTo   => ($line[9] eq "+" ? $line[8] : $line[7]) - 1, # Bring to 0-based
                       strand     => $line[9],
                       truncated  => $line[10] eq "no" ? 0 : 1,
                       bitScore   => $line[14],
                       evalue     => $line[15] });

    }
    close($fh);

    return(@table);

}

1;
