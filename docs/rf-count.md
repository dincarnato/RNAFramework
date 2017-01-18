The RF Count module is the core component of the framework. It can process any number of SAM/BAM files to calculate per-base RT-stops/mutations and read coverage on each transcript.<br /><br />

# Usage
To list the required parameters, simply type:

```bash
$ rf-count -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-p__ *or* __--processors__ | int | Number of processors (threads) to use (Default: __1__)
__-wt__ *or* __--working-threads__ | int | Number of working threads to use for each instance of SAMTools/Bowtie (Default: __1__).<br/>__Note:__ RT Counter executes 1 instance of SAMTools for each processor specified by ``-p``.  At least ``-p <processors>`` * ``-wt <threads>`` processors are required.
__-t__ *or* __--tmp-dir__ | string | Path to a directory for temporary files creation (Default: __/tmp__)<br/>__Note:__ If the provided directory does not exist, it will be created
__-o__ *or* __--output-dir__ | string | Output directory for writing counts in RC (RNA Count) format (Default: rf_count/)
__-ow__ *or* __--overwrite__ | | Overwrites the output directory if already exists
__-nm__ *or* __--no-mapped-count__ | | Disables counting of total mapped reads<br/>__Note:__ This option __must be avoided__ when processing SAM/BAM files from &Psi;-seq/Pseudo-seq and 2OMe-seq experiments.
__-s__ *or* __--samtools__ | string | Path to ``samtools`` executable (Default: assumes ``samtools`` is in PATH)
__-r__ *or* __--sorted__ | | In case SAM/BAM files are passed, assumes that they are already sorted lexicographically by transcript ID, and numerically by position
__-t5__ *or* __--trim-5prime__ | int[,int] | Comma separated list (no spaces) of values indicating the number of bases trimmed from the 5'-end of reads in the respective sample SAM/BAM files (Default: __0__)<br/>__Note #1:__ Values must be provided in the same order as the input files (e.g. rf-count -t5 0,5 file1.bam file2.bam, will consider 0 bases trimmed from file1 reads, and 5 bases trimmed from file2 reads)<br/>__Note #2:__ If a single value is specified along with multiple SAM/BAM files, it will be used for all files
__-fh__ *or* __--from-header__ | | Instead of providing the number of bases trimmed from 5'-end of reads through the ``-t5`` (or ``--trim-5prime``) parameter, RF Count will try to guess it automatically from the header of the provided SAM/BAM files
__-f__ *or* __--fasta__ | string | Path to a FASTA file containing the reference transcripts<br/>__Note #1:__ Transcripts in this file must match transcripts in SAM/BAM file headers<br/>__Note #2:__ This can be omitted if a Bowtie index is specified by ``-bi`` (or ``--bowtie-index``)
__-po__ *or* __--paired-only__ | | When processing SAM/BAM files from paired-end experiments, only those reads for which both mates are mapped will be considered
__-pp__ *or* __--properly-paired__ | | When processing SAM/BAM files from paired-end experiments, only those reads mapped in a proper pair will be considered
__-i__ *or* __--include-clipped__ | | Include reads that have been soft/hard-clipped at their 5'-end when calculating RT-stops<br/>__Note:__ The default behavior is to exclude soft/hard-clipped reads. When this option is active, the RT-stop position is considered to be the position preceding the clipped bases. This option has no effect when ``-m`` (or ``--count-mutations``) is enabled.
__-m__ *or* __--count-mutations__ | | Enables mutations count instead of RT-stops count (for SHAPE-MaP/DMS-MaPseq)
__-mq__ *or* __--min-quality__ | int | Minimum quality score value to consider a mutation (Phred+33, Default: __20__)
__-nd__ *or* __--no-deletions__ | | Disables counting unambiguously mapped deletions as mutations (requires ``-m``)
__-md__ *or* __--max-deletion-len__ | int | Ignores deletions longer than this number of nucleotides (requires ``-m``, Default: __3__)
__-co__ *or* __--coverage-only__ | | Only calculates per-base coverage (disables RT-stops/mutations count)

<br/>
## Deletions re-alignment in mutational profiling-based methods
Mutational profiling (MaP) methods for RNA structure analysis are based on the ability of certain reverse transcriptase enzymes to read-through the sites of SHAPE/DMS modification under specific reaction conditions. Some of them (e.g. SuperScript II) can introduce deletions when encountering a SHAPE/DMS-modified residue. When performing reads mapping, the aligner often reports a single possible alignment of the deletion, although many equally-scoring alignments are possible.<br/>
To avoid counting of ambiguously aligned deletions, that can introduce noise in the measured structural signal, RF Count performs a *deletion re-alignment step* to detect and discard these ambiguously aligned deletions:

```bash
ATTACGCGGATCTACGAAAGCTTTACGGACGGTAC		# Reference
ATTACGCGGATCTACGA-AGCTTTACGGACGGTAC		# Alignment

ATTACGCGGATCTACGA|AGCTTTACGGACGGTAC		# Sequence surrounding deletion

# Slide the deletion along sequence		# Extract surrounding sequence
ATTACGCGGATC-ACGAAAGCTTTACGGACGGTAC		ATTACGCGGATC|ACGAAAGCTTTACGGACGGTAC	#1
ATTACGCGGATCT-CGAAAGCTTTACGGACGGTAC		ATTACGCGGATCT|CGAAAGCTTTACGGACGGTAC	#2
ATTACGCGGATCTA-GAAAGCTTTACGGACGGTAC		ATTACGCGGATCTA|GAAAGCTTTACGGACGGTAC	#3
ATTACGCGGATCTAC-AAAGCTTTACGGACGGTAC		ATTACGCGGATCTAC|AAAGCTTTACGGACGGTAC	#4
ATTACGCGGATCTACG-AAGCTTTACGGACGGTAC		ATTACGCGGATCTACG|AAGCTTTACGGACGGTAC	#5
ATTACGCGGATCTACGAA-GCTTTACGGACGGTAC		ATTACGCGGATCTACGAA|GCTTTACGGACGGTAC	#6
ATTACGCGGATCTACGAAA-CTTTACGGACGGTAC		ATTACGCGGATCTACGAAA|CTTTACGGACGGTAC	#7
ATTACGCGGATCTACGAAAG-TTTACGGACGGTAC		ATTACGCGGATCTACGAAAG|TTTACGGACGGTAC	#8

# Compare surrounding sequence from sled deletion to that from the original alignment
ATTACGCGGATCTACGA|AGCTTTACGGACGGTAC		# Original alignment
ATTACGCGGATCTACG|AAGCTTTACGGACGGTAC		# 5
ATTACGCGGATCTACGAA|GCTTTACGGACGGTAC		# 6

# Concatenate surrounding sequences
ATTACGCGGATCTACGAAGCTTTACGGACGGTAC		# Original alignment
ATTACGCGGATCTACGAAGCTTTACGGACGGTAC		# 5
ATTACGCGGATCTACGAAGCTTTACGGACGGTAC		# 6

# Deletion is discarded because it is NOT unambiguously aligned
```
For more information, please refer to Smola *et al*., 2015 (PMID: [26426499](https://www.ncbi.nlm.nih.gov/pubmed/26426499)).
<br/><br/>
## RC (RNA Count) format

RF Count produces a RC (RNA Count) file for each analyzed sample. RC files are proprietary binary files,that store transcript’s sequence, per-base RT-stop/mutation counts, and per-base read coverage. These files can be indexed for fast random access.<br/>Each entry in a RC file is structured as follows:

Field             | Description    |  Type
----------------: | :------------: | :----------
__len\_transcript\_id__ | Length of the transcript ID (plus 1, including NULL) | uint32\_t
__transcript\_id__ | Transcript ID (NULL terminated) | char[len\_transcript\_id]
__len\_seq__ | Length of sequence | uint32\_t
__seq__ | 4-bit encoded sequence: 'ACGTN' -> \[0,4] (High nybble first) | uint8\_t\[(len_seq+1)/2]
__counts__ | Transcript's per base RT-stops (or mutations) | uint32\_t[len\_seq]
__coverage__ | Transcript's per base coverage | uint32\_t[len\_seq]

RC files EOF stores the number of total mapped reads (uint64\_t packed as 2 x uint32\_t), and is structured as follows:

Field             | Description    |  Type
----------------: | :------------: | :----------
__n<sub>1</sub>__ | Total experiment mapped reads &gt;&gt; 32 | uint32\_t
__n<sub>2</sub>__ | Total experiment mapped reads & 0xFFFFFFFF | uint32\_t
__marker__ | EOF marker (\\x5b\\x65\\x66\\x72\\x74\\x63\\x5d) | char[7]

RCI (RC Index) files enable random access to transcript data within RC files.<br/>
The RCI index is structured as follows:

Field             | Description    |  Type
----------------: | :------------: | :----------
__len\_transcript\_id__ | Length of the transcript ID (plus 1, including NULL) | uint32\_t
__transcript\_id__ | Transcript ID (NULL terminated) | char[len\_transcript\_id]
__offset__ | Offset of transcript in the RC file | uint32\_t
