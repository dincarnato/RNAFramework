Tool              | Description
----------------: | :------------
__rf-index__      | Automatically queries UCSC genome database and builds the transcriptome Bowtie reference index for the RF Count module
__rf-count__      | Performs reads pre-processing and mapping (where needed), and calculates per-base RT-stops/mutations and coverage
__rf-norm__       | Performs whole-transcriptome normalization of structure probing data
__rf-fold__       | Produces secondary structures for the analyzed transcripts using structure probing data to guide folding
__rf-compare__    | Compares secondary structures inferred by ``rf-fold`` with a set of reference structures, and computes PPV and sensitivity
__rf-jackknife__     | Iteratively optimize slope and intercept parameters to maximize PPV and sensitivity using a set of reference structures
__rf-modcall__    | Performs analysis of &Psi;-seq/Pseudo-seq and 2OMe-seq data
__rf-peakcall__   | Performs peak calling of RNA immunoprecipitation (IP) experiments
__rf-combine__    | Combines results of multiple experiments into a single profile
__rf-wiggle__    | Produces WIGGLE track files from RC or XML input files

<br/>
![RNAFramework pipeline](http://www.rnaframework.com/images/overview.png)