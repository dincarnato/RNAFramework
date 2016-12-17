The RF Map module can process any number of FastQ files, both from single-read or paired-end experiments. Reads are first pre-processed (trimmed and clipped), and mapped to the reference transcriptome.<br/>The resulting SAM/BAM files can be then passed to the RF Count module.<br /><br />

# Usage
To list the required parameters, simply type:

```bash
$ rf-map -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-b2__ *or* __--bowtie2__ | | Uses Bowtie v2 for reads mapping (Default: __Bowtie v1__)
__-p__ *or* __--processors__ | int | Number of processors (threads) to use (Default: __1__)
__-wt__ *or* __--working-threads__ | int | Number of working threads to use for each instance of SAMTools/Bowtie (Default: __1__).<br/>__Note:__ RT Counter executes 1 instance of SAMTools/Bowtie for each processor specified by ``-p``.  At least ``-p <processors>`` * ``-wt <threads>`` processors are required.
__-t__ *or* __--tmp-dir__ | string | Path to a directory for temporary files creation (Default: __/tmp__)<br/>__Note:__ If the provided directory does not exist, it will be created
__-o__ *or* __--output-dir__ | string | Output directory for writing mapped reads in SAM/BAM format (Default: rf_map/)
__-ow__ *or* __--overwrite__ | | Overwrites the output directory if already exists
__-nb__ *or* __--no-bam__ | | Disables conversion of SAM files to BAM format
__-b__ *or* __--bowtie__ | string | Path to ``bowtie`` v1/v2 executable (Default: assumes ``bowtie``/``bowtie2`` is in PATH)
__-c__ *or* __--cutadapt__ | string | Path to ``cutadapt`` executable (Default: assumes ``cutadapt`` is in PATH)
__-s__ *or* __--samtools__ | string | Path to ``samtools`` executable (Default: assumes ``samtools`` is in PATH)
 | | __Cutadapt options__
__-ca5__ *or* __--cutadapt-5adapter__ | string | Sequence of 5' adapter to clip (Default: __CAAGTCTCAAGATGTCAGGCTGCTAG__, Illumina Small RNA 5’ Adapter)<br/>__Note:__ Sequence of 5' adapter will be automatically reverse-complemented
__-ca3__ *or* __--cutadapt-3adapter__ | string | Sequence of 3' adapter to clip (Default: __TGGAATTCTCGGGTGCCAAGG__, Illumina Small RNA 3’ Adapter)
__-cl__ *or* __--cutadapt-len__ | int | Minimum length to keep reads after clipping (&ge;10, Default: __25__)
__-cm__ *or* __--cutadapt-min-align__ | int | Minimum alignment in nt to adapter’s sequence (&gt;0, Default: __1__)
__-cp__ *or* __--clipped__ | | Assumes that reads have been already clipped
 | | __Mapping options__
__-mp__ *or* __--mapping-params__ | string | Manually specify additional aligner parameters (e.g. ``-mp "-n 2 -l 15"``)<br/>__Note:__ for a complete list of aligner's parameters, please check the aligner's documentation
__-mo__ *or* __--manual-only__ | | Only uses manually specified aligner's parameters.<br/>Any other parameter, except ``-bi`` (or ``--bowtie-index``), will be ignored
__-bk__ *or* __--bowtie-k__ | int | Reports up to this number of mapping positions for reads (Default: __disabled__)
__-ba__ *or* __--bowtie-all__ | | Reports all mapping positions for reads (Default: __disabled__)
__-bnr__ *or* __--bowtie-norc__ | | Maps only to transcript's sense strand (Default: __both strands__)
__-b5__ *or* __--bowtie-trim5__ | int | Number of bases to trim from 5'-end of reads (&ge;0, Default: __0__)
__-b3__ *or* __--bowtie-trim3__ | int | Number of bases to trim from 3'-end of reads (&ge;0, Default: __0__)
__-bi__ *or* __--bowtie-index__ | string | Path to transcriptome reference index (see ``rf-index``)
 | | __Bowtie v1 options__
__-bl__ *or* __--bowtie-seedlen__ | int | Seed length (&ge;5, Default: __28__)
__-bn__ *or* __--bowtie-n__ | int | Use Bowtie mapper in -n mode (0-3, Default: __2__)<br/>__Note:__ in -n mode, Bowtie admits no more than ``-bn`` mismatches __in the seed__
__-bv__ *or* __--bowtie-v__ | int | Use Bowtie mapper in -v mode (0-3, Default: __disabled__)<br/>__Note:__ in -v mode, Bowtie admits no more than ``-bv`` mismatches __in the entire read__ (Phred quality ignored)
__-bm__ *or* __--bowtie-max__ | int | Discard read if more than this number of alignments exist (Default: __1__)
__-bc__ *or* __--bowtie-chunkmbs__ | int | Maximum MB of RAM for best-first search frames (Default: __128__)
 | | __Bowtie v2 options__
__-bl__ *or* __--bowtie-seedlen__ | int | Seed length (3 &le; *l* &le; 32, Default: __22__)
__-bN__ *or* __--bowtie-N__ | int | Bowtie seed mismatches (0-1, Default: __0__)
__-bD__ *or* __--bowtie-D__ | int | Maximum number of seed extension attempts (&ge;0, Default: __15__)
__-bR__ *or* __--bowtie-R__ | int | Maximum number of re-seeding attempts for reads with repetitive seeds (&ge;0, Default: __2__)
__-bmp__ *or* __--bowtie-mp__ | int[,int] | Maximum and minimum mismatch penalities (&ge;0, Default: 6,2)
__-bdp__ *or* __--bowtie-dpad__ | int | Number of extra reference bases included on sides of the DP table (&ge;0, Default: 15)
__-bdg__ *or* __--bowtie-rdg__ | int[,int] | Read's gap open and extend penalities (&ge;0, Default: 5,3)
__-bfg__ *or* __--bowtie-rfg__ | int[,int] | Reference's gap open and extend penalities (&ge;0, Default: 5,3)
__-bs__ *or* __--bowtie-softclip__ | | Enables local alignment mode (Default: __entire read must align__)
__-bma__ *or* __--bowtie-ma__ | int | Match bonus in local alignment mode (Default: __2__)

!!! note "Important"
    When using __Bowtie v2__ with paired-end reads, Bowtie's ``--no-mixed`` parameter is automatically added to discard those reads for which only one of the two mates can be mapped. Please check [Bowtie v2 documentation](http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml) for additional information.
    
!!! note "Important"
    When using __Bowtie v2__ with paired-end reads, if 5'-end bases have been trimmed (``--bowtie-trim5``), Bowtie's ``--dovetail`` parameter is automatically added to allow reads to end before mate's start coordinate. Please check [Bowtie v2 documentation](http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml) for additional information.