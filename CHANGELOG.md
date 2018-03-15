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