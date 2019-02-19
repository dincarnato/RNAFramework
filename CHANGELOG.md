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