## [2.9.6] - 2025-02-09
### Added
- Added rf-correlate support for comparing more than just 2 samples. This is a major change. Several novel parameters have been implemented:
	- -g (--img), enables the generation of correlation heatmaps (requires R)
	- -R (--R-path), allows specifying the path to the R executable (if not in PATH)
	- -i (--index), allows providing a single RCI index file for all input RC files
	- bs (--block-size), allows specifying a maximum chunk size to read large (genome-level) RC files, such as those generated using rf-count-genome
- Added read number statistics to rf-mmtools
- Added sample labeling support to rf-map and rf-count

### Changed
- Removed the -s (--skip-overall) and -mc (--median-coverage) parameters of rf-correlate
- The -i (--ignore-sequence) parameter of rf-correlate has been changed to -I
- Improved rf-count pre-sorting by read name for efficient analysis of paired-end experiments
- Fixed a bug in rf-count and rf-count-genome causing certain SAM flags to be ignored
- Fixed two bugs introduced in the last release in rf-count:
	- raw mutations not being reported with -orm
	- certain transcripts would not be updated in the RC file (thanks to @coffeebond for reporting this)
- Fixed a bug in rf-json2rc causing certain overlapping windows to be erroneously discarded in some edge cases
- Improved rf-json2rc matching of corresponding conformations (dramatic speed-up)

### API changes
- Dropped File::Path::mkpath() from all programs, and migrated to Core::Utils::mktree()
- Added restoration of STDOUT and STDERR to Core::Process, before calling onexit() sub
- Added Core::Statistics functions calcPearsonPartials() and pearsonFromPartials() to allow speeding up the calculation of correlations on very large datasets, without having to load in memory the entire set
- Added Core::Statistics function distribution() to get all distribution parameters at once (min, 25th percentile, median, 75th percentile, max)
- Implemented Core::Statistics Wilcoxon test via wilcoxonTest() (and accessory function erf())

## [2.9.5] - 2025-12-12
### Added
- Added -bnf (--bowtie-nofw) parameter to rf-map, to force mapping to the antisense strand only
- Added -wl (--whitelist) parameter to rf-rctools extract, to be used as an alternative to -a (--annotation) to allow extracting only specific transcripts
- Added extensive error logging to rf-fold, to enable tracing issues with failed transcripts
- Added -nr (--minRate) and -xr (--maxRate) parameters to rf-mmtools extract, to allow masking/discarding positions whose mutation frequencies are lower/higher than a user-specified threshold
- Added paired-end read support to rf-count. This is a major change. Several novel parameters have been implemented:
	- -mp (--max-clipped), controls the maximum number of clipped bases on either side of the read to be allowed to be included in coverage calculation when -ic (--include-clipped) is enabled
	- -sbn (--sort-by-read-name), which enables pre-sorting large paired-end BAM files by read name to minimize memory footprint
	- -pam (--paired-end-all-mutations), which enables counting all mutations present in overlapping paired-end reads, whether or not they are supported by both mates
	- -fsr (--force-single-read), which forces the two mates in a pair to be treated as independent single reads
	- -msp (--mm-split-paired-end), which, in case of non-overlapping paired-end reads, controls whether they should be reported as separate reads, or as a single long read spanning from the start of R1 to the end of R2, on the basis of the distance between the end of R1 and the start of R2 

### Changed
- Bumped up minimum requirement for RNAstructure version (v6.5)
- Fixed a small issue in the dump of reads/clusters in rf-duplex
- Changed default values for rf-json2rc -ep (--median-pre-cov) and -ec (--median-cov) to 2000 and 0 respectively
- Changed default value for rf-count -mq (--map-quality) to 0
- Changed default value for rf-motifdiscovery -k (--kmer) to 4

### API changes
- Implemented the _timeoutRecv() method in Net::DB::MySQL to prevent hanging in case the server does not respond within a maximum timeout

## [2.9.4] - 2025-10-13
### Added
- Added generation of statistics plots to rf-count and rf-count-genome via the -g (or --img) parameter
- Added a novel normalization method for MaP experiments (Mitchell Normalization, PMID: [37334863](https://pubmed.ncbi.nlm.nih.gov/37334863/)) tor rf-norm (-nm 4)
- Added generation of secondary structure plots with overlaid reactivities via RNAplot (requires ViennaRNA package v2.7.0)

### Changed
- Bumped up minimum requirement for ViennaRNA version (v2.5.0)
- Fixed a minor bug causing user-provided constraints to be ignored when -dp was specified without -w
- Fixed a minor bug causing rf-compare to crash with single transcripts
- Fixed a minor bug in rf-json2rc causing output RC files to lack EOF marker
- Fixed a minor bug in rf-correlate causing the program to throw an exception in case a transcript without any of the bases specified by the -kb parameter was encountered (e.g., -kb A and a transcript containing no As)
- Fixed several issues in rf-duplex, among which one caused by a bug in STAR (reported to Alex Dobin, awaiting fix, for now reads with the issue are silently discarded), and improved multithreading support

### API changes
- Fixed a bug in Graphics::Chart causing the color palette to be inverted by default
- Fixed a bug in Graphics::Chart causing plotted elements to continue past the Y range (when a yRange was specified)
- Fixed a bug in Graphics::Chart::Arcs causing an off-by-1 in the placing of the arcs
- Added handling of IUPAC characters in DNA sequences to Data::IO::Sequence through the parameter "maskIUPAC", which enables masking of IUPAC characters as Ns
- Changed the call to R in Interface::Math::R, which resulted in a dramatic decrease in runtimes
- Added method plot() to Interface::ViennaRNA to generate secondary structure plots with RNAplot and modify them to overlay reactivities

## [2.9.3] - 2025-06-19
### Added
- Added progress bar to rf-combine, rf-compare, rf-correlate
- Added the -hm (--heatmap) parameter, along with a number of accessory parameters (-lhm, -ghm and -ho), to rf-duplex to enable the generation of contact maps from RNA proximity ligation experiments
- Added the -no (--no-overall) parameter to rf-eval to disable the calculation of overall statistics
- Added the "split" command to rf-mmtools to generate a separate MM file for each transcript, startig from a multi-transcript MM file
- Added the "correlate" command to rf-mmtools to calculate the per-transcript correlation of co-mutation patterns between two experiments
- Added the "alignIds" command to rf-mmtools to generate sets of MM files containing exactly the same transcripts in the same order (needed by the upcoming version of DRACO (v1.3), which will introduce handling of replicates)
- Added the -dp (--discardPositions) parameter to the "extract" command of rf-mmtools, to allow removing specific mutated positions from reads
- Added the -tm (--truncateMotif) parameter to rf-structextract, to enable reporting chunks of structured elements to fit the size specified by -xm (--maxMotifLen), by truncating their lower stem (normally these elements would be discarded)
- Added to rf-json2rc support for the upcoming version of DRACO (v1.3), which will introduce handling of replicate experiments 
- Added the -d (--decimals) parameter to rf-jackknife to control the number of decimals in reported FMI/mFMI values
- Added the -rn (--run-norm) parameter to rf-normfactor to enable automatically invoking rf-norm to run normalization using the identified normalization factors

### Changed
- Modified rf-compare to exploit multithreading for a faster import of the reference transcripts
- Modified the behaviour of the -oc (--only-common) parameter of rf-fold to take a numeric argument. Now, XML files common to at least this number of replicates will be analyzed, as compared to the previous version, which only allowed the analysis of XML files common to all replicates
- Fixed the order of filters in rf-structextract, causing certain elements not to be reported

### API changes
- Added the mergeDataStructs() function to Core::Utils, to enable the customized merging of complex data structures
- Added the invertPalette parameter to Graphics::Chart objects
- Added the readCount() method to RF::Data::IO::MM to retrieve the number of reads mapping to a certain transcript
- Fixed a minor bug in Data::XML::Tree
- Fixed a minor bug in the fixdotbracket() function of RNA::Utils, causing an empty string to be returned when the portion of the dot-bracket to be fixed only contained brackets but no dots

## [2.9.2] - 2025-02-25
### Added
- Added the -dp (or --discardPositions) parameter to rf-mmtools to enable filtering out certain transcript positions before performing analysis with DRACO

### Changed
- Fixed a bug in Interface::Math::R causing the accumulation of zombies, or, in some cases, the process to get stuck
- Fixed reaping in Core::Process::Queue so that now also the final processes are reaped as soon as they finish
- Fixed a bug in Garaphics::Chart::Area causing R to return an error with area plots containing mostly NaN values
- Fixed a bug in Graphics::Chart causing values exceeding the visualization range not to be displayed
- Fixed a bug in rf-mmtools causing the -mpr (or --minMutPerRead) parameter causing a value of 0 to be ignored
- Fixed a bug in rf-fold occurring in remote occasions
- Fixed a bug in rf-mutate causing the program to continue with unbalanced structures as input, instead of throwing an exception
- Fixed a bug in rf-count-genome triggered in very edge cases with reads spanning multiple splice junctions (thanks to Lambert Moyon for reporting)

### API changes
- Core::Process now uses Storable's lock_store and lock_retrieve to prevent multiple processes from writing to the same file

## [2.9.1] - 2024-12-10
### Added
- Implemented R integration with RNA Framework. rf-compare, rf-eval, rf-fold, rf-jackknife, rf-norm, rf-duplex and rf-peakcall now include the parameters -g (--img), to enable the generation of plots using R and ggplot2, and -R (--R-path) to specify the path to the R executable (if not in PATH). The path to the R executable can also be set via the environment variable RF_RPATH
- Added the -ca (--corr-all) and -cm (--corr-by-majority) parameters to rf-json2rc to handle merging of windows in cases not all reconstructed conformations correlate above the threshold
- Added the -of (--orf-file) to rf-peakcall to enable specifying transcript-level coordinates of CDSs for meta-gene plot generation, instead of automatically identifying the longest ORF

### Changed
- Fixed a bug in rf-mmtools "extract" causing the original reads to be rewritten to the output MM file, rather than the filtered ones
- Fixed an out-of-memory issue in rf-fold when predicting pseudoknots
- Removed the -pmr (--plot-median-react) and -pms (--plot-median-shannon) parameters from rf-fold. The median reactivity and Shannon entropy plots are now included by default in the output plot generated by -g
- Due to the integration with R and the possibility to generate plots, rf-eval now generates an output folder rather than just reporting a text file
- rf-json2rc can now process DRACO's JSON files without asking for the RC files as well (unless -mc (--min-conf) is set to 1, or -sr (--surround-to-rc) is enabled)

### API changes
- Added the RF::Utils module for functions shared across multiple RNA Framework's tools
- Added the Interface::Math::R class to interact with R
- Added the Graphics::Image and Graphics::Chart classes to generate plots using R and ggplot2
- Added the RF_RPATH environment variable to specify the path to the R executable to be used by RNA Framework's tools

## [2.9.0] - 2024-10-24
### Added
- Added multithread support to rf-count-genome. Added the -P parameter to visualize progress per file
- Added rf-mmtools module for manipulation of MM files
- Added handling of replicates as well as multiple experiments using different chemical probes in rf-fold
- Added handling of replicates in rf-jackknife
- Added -rco (--ref-chr-only) parameter to rf-index to only retrieve reference chromosomes and omitting chromosome fixes and randoms
- Added the -s (--blockSize) parameter to rf-rctools merge to specify the size of the chromosome/transcript chunk to load in memory, to enable efficient merging of large genome-level RC files generated with rf-count-genome

### Changed
- Removed -cm (--constraint-method) from rf-fold and dropped support for Zarringhalam soft constraints. Only Deigan's method is now available
- Modified behaviour of the -i (--index) parameter in rf-norm. The parameter will now only accept a single index file, to be used for all RC files (untreated, treated, denatured). If the RC files have different structures, and a distinct RCI index is needed for each of them, the program will now automatically look for an RCI file named after each individual RC file within the same folder (e.g., for Sample.rc the program will look for Sample.rc.rci)

### API changes
- Added Core::Utils functions spaceLeft(), bytesToHuman() and humanToBytes(), isBinary(), rmEndSpaces()
- Improved handling of process queues in Core::Process::Queue and solved situations in which the program would hang and only use 1 process even if more processors were still available
- Dropped dependency on Config::Simple module. Now RF::Config parses the configuration file itself
- Added the copyIndexFromObject() method to RF::Data::IO::RC
- Improved MMI index structure
- Introduced environment variables RF_NOCHECKUPDATES and RF_VERBOSITY
- Implemented pure-Perl XML handling via the Data::IO::XML and Data::XML::Tree modules, and dropped the requirement for libXML
- Implemented connection to SQL databases via the Net::DB::SQL module, and dropped the requirement for the Perl DBI non-core module
- Added the status() method to Term::Progress to update the status message of an existing progress bar

## [2.8.9] - 2024-09-10
### Added
- Added multithread support to rf-count to speed up the analysis by processing multiple transcripts in parallel. Added the -P parameter to visualize progress per file, and the -ncl (--no-cov-low-qual) to prevent low coverage bases from being counted towards total coverage in -m mode
- Added the -bs (--block-size) parameter to rf-count-genome to define the maximum size of the genome segment to be kept in memory
- Added support to rf-rctools "view" to visualize specific regions of large chromosomes/transcripts (e.g., rf-rctools view chr1:1000-2000)
- Added multithread support to rf-wiggle
- Added the -mc (--min-cov) and -z (--report-zeroes) parameters to rf-wiggle to define, respectively, the minimum coverage of bases to be reported in the WIG files (when processing RC files) and whether bases with a value of 0 should be reported as well

### Changed
- Removed -r (--sorted), -fh (--from-header), -t (--tmp-dir) parameters from rf-count
- Fixed a minor issue in rf-eval causing an exception to be thrown with single structure files
- Fixed a minor issue in rf-fold causing no exception to be thrown in case one of the programs was not found in PATH

### API changes
- Replaced in all modules the "shift if (@_)" assignment with "shift"
- Replaced writing to STDOUT and STDERR in Core::Process with append to enable multiple processes in a process queue to write to the same files without overwriting them
- Added the killById(), shuffleQueue(), listQueue(), deleteQueue() and queueSize() methods to Core::Process::Queue
- Added the lock() and unlock() methods to Data::IO to lock filehandles when multiple processes write to the same file
- Added the "appendable" parameter to RF::Data::IO::MM to prevent an MM file from being closed (by adding the EOF marker) and allowing multiple partial MM files to be easily concatenated
- Added the "showETA" and "updateRate" parameters, and the appendText() method to Term::Progress
- Added the Term::Progress::Multiple module to handle multiple progress bars

## [2.8.8] - 2024-05-20
### Added
- Added handling of the "rc:" prefix to rf-count mask files to reverse complement sequences to mask
- Added support to rf-compare to use entire directories of structure files as reference
- Added multi-threading support to rf-compare
- rf-compare will now report the Fowlkes-Mallows index (FMI, geometric mean of PPV and sensitivity) and the modified FMI (Lan et al., 2022; PMID:35236847) for each comparison
- Parameter -mr (--max-react) of rf-correlate has now been renamed to -cr (--cap-react), to specify a maximum value reactivities must be capped to, while -mr is now used to specify a reactivity threshold above which reactivity values should be excluded from correlation calculation
- Added paramter -ec (--median-coverage) to rf-correlate, to calculate correlation only on transcripts exeeding a certain median coverage
- Added parameter -wl (--whitelist) to rf-normfactor, to allow providing a list of transcript IDs to be used for calculating normalization factors
- Added parameter -ec (--median-coverage) to rf-normfactor, to allow specifying a minimum median coverage for transcripts to be used when calculating normalization factors
- Added paramter -ls (--library-strandedness) to rf-count-genome, to allow specifying the library type for all experiments simultaneously
- rf-jackknife can now use both FMI (geometric mean of PPV and sensitivity) and mFMI (modified FMI, Lan *et al.*, 2022). Parameter -m now allows switching from FMI to mFMI, while the old parameter -m (--median) has now been renamed to -e. 

### Changed
- Fixed rf-count and rf-count-genome to handle X and = CIGAR operations
- Fixed a minor bug in rf-rctools merge, causing the mapped read count to be stored in the merged RC file (thanks to @light0112 for spotting the issue)
- Fixed a minor bug in rf-normfactor, which caused --max-mutation-rate to be ignored
- Fixed a bug preventing custom normalization factors to be passed to rf-norm via -nf when using normalization method #2 (90% Winsorizing)
- Changed rf-count and rf-count-genome to only report primary alignments in the mapped read count of RC files
- Rewritten rf-normfactor and rf-rctools merge (thanks to @coffeebond for reporting the slow speed issue) engine for increased performances

### API Changes
- Fixed a minor bug in RNA::Utils::_commonpairs() causing the same base-pair to be matched multiple times when relaxed evaluation was used
- Changed Core::Utils check for updates to use "git status"
- Added RNA::Utils::fmi() and RNA::Utils::mfmi() to calculate the Fowlkes-Mallows index (FMI, geometric mean of PPV and sensitivity) and the modified FMI (Lan et al., 2022; PMID:35236847)

## [2.8.7] - 2024-02-22
### Added
- Added the -dc and -do parameters to rf-duplex to enable dumping of parsed chimaeras to file
- Added the -ki parameter to rf-json2rc to retain in the output RC files also terminal reactivities that were excluded from the correlation calculation
- Added the -tf parameter to rf-mutate to allow defining a target structure the mutant RNA should fold into
- Added the rf-eval module to allow evaluating the agreement between reactivity data and a secondary structure model
- Added the rf-normfactor to calculate transcriptome-wide (and experiment-wide) normalization factors, to be passed to rf-norm via the -nf parameter

### Changed
- Fixed rf-fold to ensure that bases with Shannon entropy = 0 are also reported in the output WIG file
- Changed default value for maximum mutation rate (-mm) in rf-norm from 0.2 to 1
- WIG files generated by rf-wiggle will now have a different extension depending on the file content (.coverage.wig, .counts.wig, or .ratio.wig)

### API Changes
- In case the child process temporary file cannot be retrieved, now the Core::Process::exitcode() will return an array with 2 values: -1 and the error message

## [2.8.6] - 2023-11-15
### Added
- Added the -cf (--cap-mut-freqs) parameter to rf-json2rc to cap mutation frequencies to a certain value when calculating correlations between reactivity profiles

### Changed
- Fixed a small bug in rf-json2rc causing warnings not to be printed to screen
- Fixed a bug in rf-json2rc causing certain overlapping windows not to be merged
- Changed call to bowtie in rf-map to use the -x parameter to pass the genome index, rather than positional parameter
- Fixed a bug in the handling of end position in BED-formatted annotations by rf-rctools export

### API Changes
- Added the Data::Sequence::Structure::ensembleDiversity() method 

## [2.8.5] - 2023-09-25
### Changed
- Fixed two bugs in rf-count -om mode, one causing IUPAC codes to be misinterpreted, and one leading to wrong base substitution calling in the presence of indels
- Fixed a bug in RNA::Utils::_helixinheritance() causing cyclic references in helix parenthood
- Fixed a bug in rf-structextract causing the "ignore Shannon - ignore SHAPE" filters to fail
- Fixed a bug in rf-structextract causing lonely pairs to be discarded

### API Changes
- Introduced the NRC (Normalized Read Count) file format (former DB file format from SHAPEwarp) 

## [2.8.4] - 2023-08-16
### Added
- Added a check to rf-count to handle cases in which the MD tag is missing from a BAM file in mutation count mode
- Added the --fast parameter to rf-count to enable faster processing of experiments covering a large set of transcripts with relatively low coverage (feature request by Rhiju Das for the EteRNA project)
- Added the --ignore-NaNs parameter to rf-combine to allow combining probing experiments with different sets of reactive bases (e.g., DMS and CMCT)
- Added a tweak to allow Mac users to use rf-fold even when XML::LibXML is not installed
- Added the --norm-factor parameter to rf-norm to allow providing a normalization factor to be used for all transcripts (default behaviour is to calculate the normalization factor on each transcript separately)
- Added the --ignore-lower-than-untreated parameter to rf-norm to allow excluding from normalization those bases having raw reactivity in the treated sample lower than in the untreated control

### Changed
- Fixed a minor bug in rf-fold pseudoknot prediction resulting in an extra window, of the length of the transcript, being evaluated, which led to significantly longer computation times
- Fixed a bug in rf-fold causing pseudoknot prediction to fail when using RNAstructure
- Fixed a minor bug in rf-fold preventing Fold-smp, ShapeKnots-smp and partition-smp from being automatically picked
- Fixed Core::Process:Queue onParentExit call

### API Changes
- Fixed Core::Process to avoid clashes between process with identical IDs (huge thanks to Rhiju Das for reporting the issue!!)

## [2.8.3] - 2023-03-28
### Added
- Added the --plot-median-react and --plot-median-shannon options to rf-fold to plot smoothed median reactivity and Shannon entropy
- Added binomialTest() to Core::Statistics
- Added the --out-raw-counts option to rf-count (feature request by Rhiju Das) to report raw mutation counts per base, broken down by type

### Changed
- Lonely base-pairs are now ignored when defining the constraints in windowed folding mode in rf-fold (including them sometimes caused ViennaRNA RNAfold to fail backtrack)
- Fixed a bug in Interface::ViennaRNA preventing the structure from being correctly parsed
- Fixed a bug in rf-combine leading to reporting a wrong length of the sequence in the new XML file
- Fixed a bug in rf-json2rc causing the program to crash when attempting to merge windows with different numbers of conformations
- Fixed a bug in rf-json2rc causing certain windows not to be merged
- Fixed a bug in RF::Data::IO::RC::readBytewise() caused by the wrong assumption that enon coordinates were aways provided sorted
- Fixed a bug in rf-structextract causing the low SHAPE - low Shannon filter to be ignored
- Fixed a bug in rf-rctools merge when multiple RCI files are provided (thanks to Asperatus22 for reporting)

### API Changes
- Altered RNA::Utils::ppv() and RNA::Utils::sensitivity() to return 0 instead of undef when no base-pairs are common between reference and provided structure
- Data::Sequence::Structure::bpprobability() now returns 0 and does not raise any warning if the requested base-pair does not exist
- Added the rmNaN, rmOutliers and cap parameters to Core::Statistics::pearson() and Core::Statistics::spearman() to automatically remove NaNs or outliers (values below the 5th percentile and above the 95th percentile) and to cap values to a maximum, when calculating correlations

## [2.8.2] - 2022-09-01
### Changed
- Fixed a bug in rf-json2rc introduced in the last version, causing the last base of a transcript to be omitted
- Fixed the count of covered chromosomes in the rf-count-genome output
- Fixed strandedness of paired-end reads in rf-count-genome
- Fixed handling of RT-stops falling before the current memory block
- Fixed a bug in rf-fold introduced in the last version, causing pseudoknots of lenght 1 bp to be discarded
- Fixed a bug in rf-fold during the evaluation of pseudoknotted helices when overlapping with lonely pairs in the MFE structure
- Fixed a naming issue in rf-fold temporary pseudoknot constraint files
- Fixed parsing of Bowtie logs by rf-map, which would have caused rf-map to erroneously report 0% mapped reads with newer versions of Bowtie due to a change in the output log format
- Fixed rf-structextract to avoid redundancies in the output motifs

### API Changes
- Added the updateBytewise() method to RF::Data::IO::RC 
- Updated the Core::Mathematics::isreal() function to use Scalar::Util::looks_like_number() for improved performances

## [2.8.0] - 2022-05-31
### Added
- Added the rf-structextract module to automatically extract relevant RNA structure elements from larger transcripts (e.g. low reactivity - low Shannon regions, structures with free energy lower than expected by chance, etc.)
- Added the rf-count-genome module to process genome-level SAM/BAM alignments

### Changed
- Fixed a bug in rf-correlate when getting the positions of the bases being covered, for ratio calculation
- Added the "-c" (or "--constraints") parameter to rf-fold to allow providing base-pair constraints
- Changed rf-fold logic to perform pseudoknot prediction as the last step, after having built the secondary structure model
- Fixed the "--vienna-rnafold" parameter of rf-mutate to take an argument
- Fixed a bug in rf-peakcall causing the program to crash with 0 read count in the IP sample
- ADDED the "extract" command to rf-rctools to allow extracting transcripts, provided a BED or GTF annotation
- Changed the rf-wiggle module to process RC files in blocks, hence avoiding to keep in memory the full RC entry (useful for genome-level RC files)

### API Changes
- Added a third argument to the Core::Statistics::pearson() function, to allow removing NaN values, outliers, or capping values to a maximum prior to calculating the correlation
- Added the Core::Utils::isGzipped() function to evaluate whether a file is gzipped
- Fixed the read() method of the Data::IO class to automatically skip empty lines
- Fixed a bug in the \_findFormat() method of the Data::IO::Sequence class causing the whole file to be loaded in memory to guess the file format, rather than just a few lines
- Renamed the \_validate() method of the Interface::Generic class to \_makeTmpDir()
- Added the Interface::Aligner::STAR class, in preparation for the next release of RNAFramework
- Added the id() and revcomp() methods to the RF::Data::RC class
- Changed the compression/decompression of the sequence in the RF::Data::IO::RC and RF::Data::IO::MM modules for increased speed
- Added the readBytewis() and writeBytewise() methods to the RF::Data::IO::RC class to allow reading/writing count/coverage data at specific positions of a given transcript/chromosome (useful for the processing of genome-level RC files)

## [2.7.2] - 2021-07-22
### Added
- Added function "extract" to rf-rctools to extract a set of regions specified in a BED file, from an input RC file
- Added the rf-duplex module to enable the analysis of direct RNA-RNA interaction mapping experiments (COMRADES, SPLASH, PARIS, etc.)
- Added the "--only-mut" parameter to rf-count, to allow counting only specific mutation events

### Changed
- Fixed rf-count to use Core::Process::Queue instead of threads, which resulted in a significant speedup of parallel BAM processing

### API Changes
- The Core::Process and Core::Process::Queue modules now use Storable instead of pipes for IPC, to allow children to return even complex data structures
- Added several new methods to Data::IO for enabling control over the filehandle (seek, tell, eof, goToEof), as well as the forceReopenFh method to allow a Data::IO object that has been cloned in a thread (or child process) to be fully independent

## [2.7.1] - 2021-04-03
### Added
- Added parameter "-mcp" (or "--meta-coding-plot") to rf-peakcall to generate protein-coding-only meta-gene plots, by aligning the TSS, start codon, stop codon, and TES
- Added the rf-motifdiscovery module to perform motif discovery from RIP peaks
- Added the rf-json2rc module to post-process DRACO JSON output files into RC format
- Added support for direct comparison of RC files in rf-correlate
- Every RNA Framework module will now notify the user if a new version is available

### Changed
- Fixed a bug in the way rf-norm and rf-wiggle handled reactive bases from IUPAC codes

### API Changes
- The Graphics::Object::Ruler can now take user-defined labels
- Fixed the nt2iupac function of Data::Sequence::Utils

## [2.7.0] - 2021-02-27
### Added
- Added parameter "-l" (or "--log-transform") to rf-combine (reactivity profiles will be averaged after having been log-transformed)
- Added rf-wiggle support for XML files generated by rf-modcall
- Added the rf-mutate tool to design structure mutants/rescues
- Added rf-count parameters "-ld" (or "--left-deletion") and "-rd" (or "--right-deletion") to re-align deletions of multiple consecutive nucleotides and "-la" (or "--left-align") to re-align ambiguously aligned deletion to their left-most position
- Added rf-count parameter "-mv" (or "--max-coverage") to downsample reads to a target coverage on transcript
- Added rf-count parameter "-pn" or ("--primary-only") to only process primary alignments
- Added rf-count parameter "-mm" or ("--mutation-map") to generate MM files for downstream processing with DRACO (Deconvolution of RNA Alternative COnformations)
- Added rf-combine and rf-correlate parameter "-S" (or "--spearman) to use Spearman rather than Pearson to evaluate correlation
- Added rf-correlate "-i" parameter (or "--ignore-sequence") to ignore sequence differences (e.g. due to SNVs) between compared transcripts
- Added support for direct comparison of XML files with different file names to rf-correlate
- Added rf-peackcall "-l" (or "--whitelist") parameter to restrict the analysis to certain transcripts only

### Changed
- Fixed rf-count to handle sequence IDs containing slashes ("/"), causing errors at later stages
- Coordinates in mask files (for rf-count) need now to be specified as 0-based
- Fixed a bug in rf-count causing non-ambiguously mapped deletions to be discarded under certain conditions
- Made right realignment of ambiguously aligned deletion the default in rf-count and removed the "-ra" (or "--right-align") parameter of rf-count
- The "-ds" (or "--discard-shorter") parameter of rf-count can now be set to "MEDIAN" to automatically use the median read length
- Changed the default 3' adapter sequence for the "-ca3" (or "--cutadapt-3adapter") of rf-map to the sequence of the NEBNext Small RNA 3' adapter
- Fixed a bug in rf-norm causing regions with insufficient coverage to be erroneously reported as 0 reactivities

## [2.6.9] - 2020-01-18
### Added
- Added possibility to only combine reactivity profiles exceeding a given correlation cutoff in rf-combine. Parameters "-c" (or "--min-correlation) and "-m" (or "--min-values") respectively control the correlation threshold and the minimum number/fraction of covered bases to calculate correlation
- Added the rf-correlate tool to calculate pairwise correlations between structure probing experiments
- Added parameter "-la" (or "--list-annotations") to rf-index to list available UCSC data tables containing gene annotations
- Added parameters "-H" (or "--host") and "-P" (or "--port") to rf-index to allow specifying and alternative UCSC server hostname and port
- Added parameters "-ctn" (or "--cutadapt-trim-N") and "-cmn" (or "--cutadapt-max-N") to rf-map to respectively allow trimming Ns from read ends and discarding reads containing more than a specified number of Ns
- Added parameter "-ds" (or "--discard-shorter") to rf-count to discard reads shorter than a given length (excluding clipped bases)
- Added the possibility to specify one or more transcripts to visualize with rf-rctools "view"
- Added a check to rf-norm to allow a maximum window size of 30,000 nt when dynamic windowing is enabled
- Added the "-g" (or "--img") and "-mp" (or "--meta-plot") parameters to rf-peakcall to respectively allow generating normalized gene coverage plots or meta-gene plots of coverage/peaks distribution
- Added the "-r" (or "--refine"), "-x" (or "--relaxed") and "-s" (or "--summit") parameters to rf-peakcall to allow refining peak boundaries and to allow generating a BED file with the coordinates of peak summits

### Changed
- Fixed rf-combine to report combined score and ratio when combining rf-modcall XML files
- Changed rf-count to ignore N-only deletions when calculating edit distance
- Removed the "-nm" (or "--no-mapped-count") parameter of rf-count (now total read count is automatically computed as the sum of reads covering each transcript in the dataset)
- Changed the "-l" (or "--list") parameter of rf-index to "-lp" (or "--list-prebuilt")
- Fixed a bug in rf-map causing mapping to fail with filenames containing dots in paired-end experiments
- Cutadapt v2.1 or greater is now required (multithread support)

### API changes
- Added the mround() function to Core::Mathematics to allow rounding to the nearest multiple
- Added support for an extra "structure" tag in RNA Framework's XML files, allowing storing dot-bracket structures inside XML reactivity files

## [2.6.8] - 2019-02-20
### Added
- Added flag "--max-mutation-rate" to rf-norm to allow excluding bases with mutation rate > than a user-defined threshold (for MaP experiments)

### API changes
- Changed rf-norm algorithm to exclude non-covered bases and bases with too high mutation rates from normalization

## [2.6.7] - 2018-11-27
### Added
- Added flag "-i" to rf-compare to allow comparison between structures with different sequences (useful in case of SNVs)
- Added flags "-ksl" and "-kin" to allow using a different set of folding parameters for pseudoknots prediction
- Added RF Norm support for dynamic windows

### Changed
- Fixed a bug in rf-fold causing the software to not report pseudoknots even if present (in certain windows the pseudoknot was predicted as a regular helix, causing its rejection due to the requirement of being present in at least 50% of the analyzed windows)

### API changes
- Replaced the File::Path rmtree() function with a thread-safe version (introduced in the Core::Utils library)
- Added a third parameter to the pearson() and spearman() functions from Core::Statistics to allow handling of arrays containing NaNs (when TRUE, only non-NaN elements from both arrays are kept)
- Modified the pearson() and spearman() functions from Core::Statistics to only return the correlation coefficient when called in scalar context
- Added the split parameter to the helices() method from Data::Sequence::Structure (when TRUE, allows splitting helices with single-nucleotide bulges)
- Fixed a bug causing the RF::Data::IO::XML module to fail reading XML files when a newline was missing between values and tags
- Fixed a bug in the rmpseudoknots() function of RNA::Utils causing any scoring subroutine passed to the function to be overriden by the Core::Mathematics::sum() function

## [2.6.6] - 2018-10-19
### Added
- Added mask file support to rf-count

### Changed
- Fixed a bug in rf-fold causing the software to get stuck when generating graphical reports for transcripts with only 0/NaN reactivity values (thanks to Uciel Pablo Chorostecki for reporting the bug)

## [2.6.5] - 2018-08-09
### Added
- Added rf-rctools utility for RC files manipulation

### API changes
- API modified to use HTTP::Tiny (CORE) instead of LWP::UserAgent

## [2.6.1] - 2018-06-12
### Added
- Added mutated reads statistics to rf-count output

### Changed
- Fixed a bug in rf-fold causing folding to fail with pseudoknotted structures under windowed folding mode
- Fixed a bug in rf-fold causing the software to crash when the first/last windows are < 50 nt

### API changes
- Added haszero() function to Core::Mathematics
- Added forceyrange parameter to Graphics::Object::Yaxis objects to force y-scale over the maximum/minimum Y values in the dataset
- Modified RF::Data::RC module to handle reference sequences with degerated bases

## [2.6] - 2018-05-17
### Added
- Introduced rf-map support for quality-based trimming of reads
- Introduced new rf-count parameters to enable quality filtering of reads/mappings
- Introduced rf-count support for insertions
- Introduced rf-count support for the re-alignment of ambiguously aligned deletions in SHAPE-MaP experiments
- Added sampling of Zuker suboptimal structures to rf-fold pseudoknots detection algorithm

### API changes
- Added the $VERSION variable to the Core::Utils package

## [2.5.5] - 2018-04-25
### Changed
- Added rf-map support for gzipped FastQ files (function request issued by Omar Wagih)

## [2.5.4] - 2018-03-15
### Changed
- Modified all modules to avoid use of Thread::Queue (in some cases we encountered a deadlock, especially with rf-fold, that should be solved now)
- Fixed 90% Wisorizing to esclude values below the 5<sup>th</sup> percentile as outliers
- Now rf-compare can generate comparison plots of structures in SVG format (reference vs. predicted)

### API changes
- Now control over errors verbosity is granted through any of the following environment variables: "verbose", "verbosity", "VERBOSE", or "VERBOSITY"
- We have now avoided use of XML::LibXML for RNA Framework's XML file input handling (thread unsafe)

## [2.5.3] - 2018-02-04
### Changed
- Modified rf-fold to avoid partition function from being computed when not performing windowed folding (or when explicitly required by -dp or -sh)

### API changes
- Modified the rmpseudoknots() function to take an array of array refs of 3 elements [i, j, score], and a code ref to use to compute overall score of the helix

## [2.5.2] - 2018-01-29
### Added
- Rewritten rf-fold engine to make it faster (and to make code maintenance easier)
- Fixed an issue in rf-fold causing a crash when no reactivity data was available for a given pseudoknotted helix
- Fixed a bug in rf-fold causing the software to report unfolded structures for RNAs with length < than the allowed minimum window length (50 nt) in windowed folding mode
- Fixed a severe bug in rf-fold in windowed mode causing the program to crash due to the presence of incompatible base-pairs with probability >= 0.99
- Introduced in rf-fold the generation of SVG graphical summaries (reactivity data, Shannon entropy, base-pairing probabilities and MEA structure)

### API changes
- Data::IO::XML has been replaced by a Data::XML class for XML construction, that is then passed to a generic Data::IO object for writing
- Introduced Graphics libraries for SVG graphics generation (currently supports bar plots, paths, and RNA arc plots)

## [2.5.1] - 2018-01-07
### Added
- Introduced CHANGELOG
- Added back support for Siegfried *et al*., 2014 normalzation method (now the method allows also the analysis of experiments lacking a denatured sample)

## [2.5.0] - 2018-01-05
### Added
- Introduced support for pseudoknots
- Introduced rf-jackknife for slope/intercept grid search
- Changed RC format (from now on backward compatibility is supported, but RC files created before this release are no longer supported)
- rf-peakcall now supports the analysis of experiments lacking control/input sample

### Removed
- Temporarily removed Siegfried *et al*., 2014 normalzation method support
