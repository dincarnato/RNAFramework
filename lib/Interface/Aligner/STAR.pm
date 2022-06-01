package Interface::Aligner::STAR;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Data::IO::Sequence;
use Data::Sequence::Utils;

use base qw(Interface::Generic);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ STAR          => which("STAR"),
                   genomeDir     => undef,
                   threads       => 1,
                   _genomeLoaded => 0,
                   _alignStats   => {} }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("No path provided to STAR executable") if (!defined $self->{STAR});
    $self->throw("Provided path to STAR does not exist") if (!-e $self->{STAR});

    if (-d $self->{STAR}) {

        if (-e $self->{STAR} . "/STAR") { $self->{STAR} .= "/STAR"; }
        else { $self->throw("STAR not found inside the provided directory"); }

    }

    $self->throw("STAR is not executable (" . $self->{STAR} . ")") if (!-x $self->{STAR});
    $self->throw("No path provided to genome directory") if (!defined $self->{genomeDir});
    $self->throw("Provided path to genome directory does not point to a folder") if (-e $self->{genomeDir} && !-d $self->{genomeDir});
    $self->throw("Number of threads must be a positive INT >= 1") if (!isint($self->{threads}) || $self->{threads} < 1);

    $self->{genomeDir} =~ s/\/?$/\// if (defined $self->{genomeDir});

}

sub buildGenomeIndex {

    my $self = shift;
    my ($genomeFiles, $parameters) = $self->_checkIndexParams(@_);

    if (!-e $self->{genomeDir}) {

        my $error = mktree($self->{genomeDir});

        $self->throw("Unable to create genome directory (" . $error . ")") if (defined $error);

        $self->{genomeDir} =~ s/\/?$/\//;

    }
    else {

        $self->warn("A STAR genome index already exists in the provided directory.\n" .
                    "Skipping genome index building (to force rebuild, set the \"overwrite\" parameter to 1)") if ($self->_checkValidIndex() && !$parameters->{overwrite});

        return;

    }

    my ($id, $command, $ret);
    $id = "." . $self->{_randId} . "_";
    $command = $self->{STAR} . " --runThreadN " . $self->{threads} . " --runMode genomeGenerate --genomeDir " . $self->{genomeDir} .
               " --genomeFastaFiles " . $genomeFiles . " --outFileNamePrefix " . $self->{tmpdir} . $id;
    for (sort keys %$parameters) { $command .= " --" . $_ . " " . $parameters->{$_} if (defined $parameters->{$_}); }

    $ret = `$command 2>&1`;

    unlink(glob($self->{tmpdir} . $id . "*"));

    if ($ret =~ m/ERROR/) {

        # Attempts to provide a decently formatted error output
        if ($ret =~ m/ERROR: (.+?)\n/ig) { $self->throw("STAR threw an exception (" . $1 . ")"); }
        else { $self->throw("STAR threw an exception. Output:\n" . $ret); }

    }

    while ($ret =~ m/WARNING: (.+?)\n/g) { $self->warn("STAR threw a warning (" . $1 . ")"); }

}

sub loadGenomeIndex { $_[0]->_loadAndRemoveIndex("LoadAndExit"); }

sub removeGenomeIndex { $_[0]->_loadAndRemoveIndex("Remove"); }

sub alignReads {

    my $self = shift;
    my ($readFiles, $parameters) = $self->_checkAlignParams(@_);

    $self->_checkValidIndex() if (!$self->{_genomeLoaded});

    undef($self->{_alignStats});

    my ($command, $ret);
    $command = $self->{STAR} . " --runThreadN " . $self->{threads} . " --readFilesIn " . $readFiles . " --genomeDir " . $self->{genomeDir} .
               " --outSAMattributes All --outSAMtype BAM Unsorted";
    for (sort keys %$parameters) { $command .= " --" . $_ . " " . $parameters->{$_} if (defined $parameters->{$_}); }

    $ret = `$command 2>&1`;

    if ($ret =~ m/ERROR/) {

        # Attempts to provide a decently formatted error output
        if ($ret =~ m/ERROR: (.+?)\n/ig) { $self->throw("STAR threw an exception (" . $1 . ")"); }
        else { $self->throw("STAR threw an exception. Output:\n" . $ret); }

    }

    while ($ret =~ m/WARNING: (.+?)\n/g) { $self->warn("STAR threw a warning (" . $1 . ")"); }

    $self->_readAlignStats($parameters->{outFileNamePrefix});

}

sub alignStats {

    my $self = shift;
    my $stat = shift if (@_);

    if (!keys %{$self->{_alignStats}}) { $self->warn("No statistics available. No alignment has been performed yet."); }
    else {

        if (defined $stat) {

            if (exists $self->{_alignStats}->{$stat}) { return($self->{_alignStats}->{$stat}); }
            else { $self->warn("No available statistics \"" . $stat . "\""); }

        }
        else { return(wantarray() ? %{$self->{_alignStats}} : $self->{_alignStats}); }

    }

}

sub _loadAndRemoveIndex {

    my $self = shift;
    my $mode = shift if (@_);

    $self->_checkValidIndex(1);

    my ($id, $command, $ret);
    $id = "." . $self->{_randId} . "_";
    $command = $self->{STAR} . " --genomeLoad " . $mode . " --genomeDir " . $self->{genomeDir} .
               " --outFileNamePrefix " . $self->{tmpdir} . $id;

    $ret = `$command 2>&1`;

    if ($ret =~ m/ERROR/) {

        # Attempts to provide a decently formatted error output
        if ($ret =~ m/ERROR: (.+?)\n/ig) { $self->throw("STAR threw an exception (" . $1 . ")"); }
        else { $self->throw("STAR threw an exception. Output:\n" . $ret); }

    }

    while ($ret =~ m/WARNING: (.+?)\n/g) { $self->warn("STAR threw a warning (" . $1 . ")"); }

    unlink(glob($self->{tmpdir} . $id . "*"));

    $self->{_genomeLoaded} = $mode eq "Remove" ? 0 : 1;

}

sub _checkValidIndex {

    my $self = shift;
    my $throw = shift if (@_);

    for (qw(chrLength.txt  chrNameLength.txt  chrName.txt  chrStart.txt
            Genome  genomeParameters.txt  SA  SAindex)) {

        if (!-e $self->{genomeDir} . $_) {

            if ($throw) { $self->throw("Provided genome directory does not look like a valid STAR index (\"" . $_ . "\" is missing)"); }
            else { return; }

        }

    }

    return(1);

}

sub _checkIndexParams {

    my $self = shift;
    my $genomeFiles = shift if (@_);
    my $parameters = shift || {};

    $self->throw("No reference FASTA file provided") if (!$genomeFiles);
    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    $genomeFiles = [ split(" ", $genomeFiles) ] if (ref($genomeFiles) ne "ARRAY");

    for (@$genomeFiles) { $self->throw("Genome file \"" . $_ . "\" does not exist") if (!-e $_); }

    $parameters = checkparameters({ overwrite                      => 0,
                                    genomeChrBinNbits              => 18,
                                    genomeSAindexNbases            => 14,
                                    genomeSAsparseD                => 1,
                                    genomeSuffixLengthMax          => -1,
                                    sjdbFileChrStartEnd            => undef,
                                    sjdbGTFfile                    => undef,
                                    sjdbGTFchrPrefix               => undef,
                                    sjdbGTFfeatureExon             => "exon",
                                    sjdbGTFtagExonParentTranscript => "transcript_id",
                                    sjdbGTFtagExonParentGene       => "gene_id",
                                    sjdbGTFtagExonParentGeneName   => "gene_name",
                                    sjdbGTFtagExonParentGeneType   => "gene_type",
                                    sjdbOverhang                   => 100,
                                    sjdbScore                      => 2,
                                    sjdbInsertSave                 => "Basic" }, $parameters);

    # We will estimate the parameter automatically based on the reference genome
    if ($parameters->{genomeSAindexNbases} =~ m/^auto$/i) {

        my $genomeSize = 0;

        foreach my $genomeFile (@$genomeFiles) {

            my $genomeIO = Data::IO::Sequence->new(file => $genomeFile);
            while(my $chr = $genomeIO->read()) { $genomeSize += $chr->length(); }

        }

        $self->throw("Empty genome file(s)") if (!$genomeSize);

        $parameters->{genomeSAindexNbases} = min(14, logarithm($genomeSize, 2) / 2 - 1);

    }

    for (qw(genomeChrBinNbits genomeSAindexNbases
            genomeSAsparseD sjdbOverhang sjdbScore)) { $self->throw($_ . " must be a positive INT") if (!isint($parameters->{$_}) || !ispositive($parameters->{$_})); }
    $self->throw("genomeSuffixLengthMax must be an INT >= -1") if (!isint($parameters->{genomeSuffixLengthMax}) || $parameters->{genomeSuffixLengthMax} < -1);
    $self->throw("Overwrite must be BOOL") if (!isbool($parameters->{overwrite}));

    $parameters = $self->_checkSjdbParams($parameters);
    $genomeFiles = join(" ", @$genomeFiles);

    return($genomeFiles, $parameters);

}

sub _checkAlignParams {

    my $self = shift;
    my $readFiles = shift if (@_);
    my $parameters = shift || {};

    $self->throw("No read file provided") if (!$readFiles);
    $self->throw("Parameters must be an HASH reference") if (ref($parameters) ne "HASH");

    $readFiles = [ split(" ", $readFiles) ] if (ref($readFiles) ne "ARRAY");

    my ($nFiles, $nGzipped, $isPairedEnd);

    foreach my $readFile (@$readFiles) {

        my @files = split(",", $readFile);
        $nFiles += @files;

        for (@files) {

            $self->throw("Reads file \"" . $_ . "\" does not exist") if (!-e $_);

            $nGzipped++ if (isGzipped($_));

        }

    }

    $self->throw("Mixed read files (plain-text and gzipped) provided") if ($nGzipped && $nGzipped != $nFiles);

    $isPairedEnd = 1 if (@$readFiles == 2);
    $readFiles = join(" ", @$readFiles);
    $parameters = checkparameters({ genomeLoad                       => $self->{_genomeLoaded} ? "LoadAndKeep" : "NoSharedMemory",
                                    outFileNamePrefix                => $self->{tmpdir} . "." . $self->{_randId},
                                    readFilesCommand                 => $nGzipped ? "zcat" : undef,
                                    quantMode                        => undef,
                                    quantTranscriptomeBan            => "Singleend",
                                    clipAdapterType                  => "Hamming",
                                    clip3pNbases                     => 0,
                                    clip3pAdapterSeq                 => undef,
                                    clip3pAdapterMMp                 => 0.1,
                                    clip3pAfterAdapterNbases         => 0,
                                    clip5pNbases                     => 0,
                                    outReadsUnmapped                 => "None",
                                    outSAMprimaryFlag                => "AllBestScore",
                                    outSAMmultNmax                   => -1,
                                    outFilterType                    => "Normal",
                                    outFilterMultimapScoreRange      => 1,
                                    outFilterMultimapNmax            => 10,
                                    outFilterMismatchNmax            => 10,
                                    outFilterMismatchNoverLmax       => 0.3,
                                    outFilterMismatchNoverReadLmax   => 1,
                                    outFilterScoreMin                => 0,
                                    outFilterScoreMinOverLread       => 0.66,
                                    outFilterMatchNmin               => 0,
                                    outFilterMatchNminOverLread      => 0.66,
                                    outFilterIntronMotifs            => "None",
                                    outFilterIntronStrands           => "RemoveInconsistentStrands",
                                    scoreGap                         => 0,
                                    scoreGenomicLengthLog2scale      => -0.25,
                                    scoreGapNoncan                   => -8,
                                    scoreGapGCAG                     => -4,
                                    scoreGapATAC                     => -8,
                                    scoreDelOpen                     => -2,
                                    scoreDelBase                     => -2,
                                    scoreInsOpen                     => -2,
                                    scoreInsBase                     => -2,
                                    scoreStitchSJshift               => 1,
                                    alignIntronMin                   => 21,
                                    alignIntronMax                   => 0,
                                    alignMatesGapMax                 => 0,
                                    alignSJoverhangMin               => 5,
                                    alignSJstitchMismatchNmax        => "0 -1 0 0",
                                    alignSJDBoverhangMin             => 3,
                                    alignSplicedMateMapLmin          => 0,
                                    alignSplicedMateMapLminOverLmate => 0.66,
                                    alignEndsType                    => "Local",
                                    alignEndsProtrude                => "0 ConcordantPair",
                                    alignSoftClipAtReferenceEnds     => "Yes",
                                    alignInsertionFlush              => "None",
                                    peOverlapNbasesMin               => 0,
                                    peOverlapMMp                     => 0.01,
                                    chimOutType                      => undef,
                                    chimSegmentMin                   => 0,
                                    sjdbFileChrStartEnd              => undef,
                                    sjdbGTFfile                      => undef,
                                    sjdbGTFchrPrefix                 => undef,
                                    sjdbGTFfeatureExon               => "exon",
                                    sjdbGTFtagExonParentTranscript   => "transcript_id",
                                    sjdbGTFtagExonParentGene         => "gene_id",
                                    sjdbGTFtagExonParentGeneName     => "gene_name",
                                    sjdbGTFtagExonParentGeneType     => "gene_type gene_biotype",
                                    sjdbOverhang                     => 100,
                                    sjdbScore                        => 2,
                                    sjdbInsertSave                   => "Basic"}, $parameters);

    # Validation of string parameters
    $self->throw("Invalid value for clipAdapterType") if ($parameters->{clipAdapterType} !~ m/^(?:None|Hamming)$/);
    if (defined $parameters->{clip3pAdapterSeq}) { for(split(" ", $parameters->{clip3pAdapterSeq})) { $self->throw("clip3pAdapterSeq sequence contains invalid characters") if (!isna($_)); } }
    $self->throw("Invalid value for outReadsUnmapped") if ($parameters->{outReadsUnmapped} !~ m/^(?:None|Fastx)$/);
    $self->throw("Invalid value for outSAMprimaryFlag") if ($parameters->{outSAMprimaryFlag} !~ m/^(?:One|All)BestScore$/);
    $self->throw("Invalid value for outFilterType") if ($parameters->{outFilterType} !~ m/^(?:Normal|BySJout)$/);
    $self->throw("Invalid value for outFilterIntronMotifs") if ($parameters->{outFilterIntronMotifs} !~ m/^(?:None|RemoveNoncanonical(?:Unannotated)?)$/);
    $self->throw("Invalid value for outFilterIntronStrands") if ($parameters->{outFilterIntronStrands} !~ m/^(?:None|RemoveInconsistentStrands)$/);
    $self->throw("Invalid value for alignEndsType") if ($parameters->{alignEndsType} !~ m/^(?:Local|EndToEnd|Extend5pOfRead12?)$/);
    $self->throw("Invalid value for alignSoftClipAtReferenceEnds") if ($parameters->{alignSoftClipAtReferenceEnds} !~ m/^(?:Yes|No)$/);
    $self->throw("Invalid value for alignInsertionFlush") if ($parameters->{alignInsertionFlush} !~ m/^(?:None|Right)$/);
    $self->throw("Invalid value for quantMode") if (defined $parameters->{quantMode} && $parameters->{quantMode} !~ m/^(?:(?:TranscriptomeSAM|GeneCounts)\s?){1,2}$/);
    $self->throw("Invalid value for quantTranscriptomeBan") if (defined $parameters->{quantTranscriptomeBan} && $parameters->{quantTranscriptomeBan} !~ m/^(?:IndelSoftclip)?Singleend$/);
    $self->throw("Invalid value for chimOutType") if (defined $parameters->{chimOutType} && $parameters->{chimOutType} !~ m/^(?:Junctions|WithinBAM(?: (?:Hard|Soft)Clip))$/);

    # Greedy validation of numeric parameters
    # We don't check the exact values, anyway STAR will throw an exception in case something is wrong
    $self->throw("scoreGenomicLengthLog2scale must be numeric") if (!isnumeric($parameters->{scoreGenomicLengthLog2scale}));

    foreach my $param (qw(clip3pNbases clip3pAfterAdapterNbases clip5pNbases outFilterMultimapScoreRange
                          outFilterMultimapNmax outFilterMismatchNmax outFilterScoreMin outFilterMatchNmin
                          alignIntronMin alignIntronMax alignMatesGapMax peOverlapNbasesMin scoreGap
                          scoreGapNoncan scoreGapGCAG scoreGapATAC scoreDelOpen scoreDelBase scoreInsOpen
                          scoreInsBase scoreStitchSJshift alignSJoverhangMin alignSJDBoverhangMin
                          alignSplicedMateMapLmin outSAMmultNmax alignSJstitchMismatchNmax chimSegmentMin)) {

        # Some of these parameters can take 2 values, so we just do the check for all of them
        for (split(" ", $parameters->{$param})) { $self->throw($param . " must be INT") if (!isint($_)); }

    }

    foreach my $param (qw(outFilterMismatchNoverLmax clip3pAdapterMMp outFilterMismatchNoverReadLmax
                          outFilterScoreMinOverLread outFilterMatchNminOverLread
                          alignSplicedMateMapLminOverLmate peOverlapMMp)) {

        # Some of these parameters can take 2 values, so we just do the check for all of them
        for (split(" ", $parameters->{$param})) { $self->throw($param . " must be comprised between 0 and 1") if (!inrange($_, [0, 1])); }

    }

    $parameters = $self->_checkSjdbParams($parameters);

    return($readFiles, $parameters);

}

sub _checkSjdbParams {

    my $self = shift;
    my $parameters = shift;

    for (split(" ", $parameters->{sjdbFileChrStartEnd})) { $self->throw("sjdbFileChrStartEnd file \"" . $_ . "\" does not exist") if (!-e $_); }
    $self->throw("sjdbGTFfile file \"" . $parameters->{sjdbGTFfile} . "\" does not exist") if (defined $parameters->{sjdbGTFfile} && !-e $parameters->{sjdbGTFfile});
    $self->throw("Invalid value for sjdbInsertSave") if ($parameters->{sjdbInsertSave} !~ m/^(?:Basic|All)$/);

    undef($parameters->{sjdbOverhang}) if (!defined $parameters->{sjdbGTFfile} && !defined $parameters->{sjdbFileChrStartEnd});

    return($parameters);

}

sub _readAlignStats {

    my $self = shift;
    my $outPrefix = shift;

    my $stats = {};

    if (-e $outPrefix . "Log.final.out") {

        my $logIO = Data::IO->new(file => $outPrefix . "Log.final.out");

        while(my $line = $logIO->read()) {

            if ($line =~ m/Uniquely mapped reads \% \|\t([\d\.]+)\%/) { $stats->{unique} = $1; }
            elsif ($line =~ m/\% of reads mapped to multiple loci \|\t([\d\.]+)\%/) { $stats->{multiple} = $1; }
            elsif ($line =~ m/\% of reads mapped to too many loci \|\t([\d\.]+)\%/) { $stats->{tooManyLoci} = $1; }
            elsif ($line =~ m/\% of reads unmapped: too many mismatches \|\t([\d\.]+)\%/) { $stats->{tooManyMismatches} = $1; }
            elsif ($line =~ m/\% of reads unmapped: too short \|\t([\d\.]+)\%/) { $stats->{tooShort} = $1; }
            elsif ($line =~ m/\% of reads unmapped: other \|\t([\d\.]+)\%/) { $stats->{other} = $1; }
            elsif ($line =~ m/\% of chimeric reads \|\t([\d\.]+)\%/) { $stats->{chimeric} = $1; }
            elsif ($line =~ m/Average mapped length \|\t([\d\.]+)/) { $stats->{avgMappedLen} = $1; }
            elsif ($line =~ m/Mismatch rate per base, \% \|\t([\d\.]+)\%/) { $stats->{mismatchRate} = $1; }
            elsif ($line =~ m/Deletion rate per base \|\t([\d\.]+)\%/) { $stats->{delRate} = $1; }
            elsif ($line =~ m/Deletion average length \|\t([\d\.]+)/) { $stats->{avgDelLen} = $1; }
            elsif ($line =~ m/Insertion rate per base \|\t([\d\.]+)\%/) { $stats->{insRate} = $1; }
            elsif ($line =~ m/Insertion average length \|\t([\d\.]+)/) { $stats->{avgInsLen} = $1; }

        }

    }
    else { $self->warn("Unable to read alignment statistics (\"Log.final.out\" is missing)"); }

    $self->{_alignStats} = checkparameters({ unique            => 0,
                                             multiple          => 0,
                                             tooManyLoci       => 0,
                                             tooManyMismatches => 0,
                                             tooShort          => 0,
                                             other             => 0,
                                             chimeric          => 0,
                                             avgMappedLen      => 0,
                                             mismatchRate      => 0,
                                             delRate           => 0,
                                             avgDelLen         => 0,
                                             insRate           => 0,
                                             avgInsLen         => 0 }, $stats);

}

1;
