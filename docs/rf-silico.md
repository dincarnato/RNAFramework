RF Silico calculates partition function folding for a given set of RNAs, using either ViennaRNA, RNAstructure, or their combination. The probability of each base of being unpaired is then reported in the form of a XML file.<br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-silico -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-f__ *or* __--fasta__ | string | Path to a multi-FASTA file containing transcript sequences
__-o__ *or* __--output-dir__ | string | Output directory for writing probability data in XML format (Default: __rf_silico/__)
__-ow__ *or* __--overwrite__ | | Overwrites the output directory if already exists
__-p__ *or* __--processors__ | int | Number of processors (threads) to use (Default: __1__)
__-t__ *or* __--tmp-dir__ | string | Path to a directory for temporary files creation (Default: __/tmp__)<br/>__Note:__ If the provided directory does not exist, it will be created
__-m__ *or* __--method__ | int | Partition function calculation method (1-3, Default: __1__):<br/>__1.__ ViennaRNA <br/>__2.__ RNAstructure <br/>__3.__ Combined<br/>__Note:__ method #3 calculates base-pair probabilities using both ViennaRNA and RNAstructure, and produces a XML file containing the per-base average of the two algorithms
__-e__ *or* __--temperature__ | float | Temperature in Celsius degrees (Default: __37.0__)
__-md__ *or* __--maximum-distance__ | int | Maximum pairing distance (in nt) between transcript's residues (Default: __0__ [no limit])
__-v__ *or* __--viennarna__ | string | Path to ViennaRNA ``RNAfold`` executable (Default: assumes ``RNAfold`` is in PATH)
__-pr__ *or* __--partition__ | string | Path to RNAstructure ``partition`` executable (Default: assumes ``partition`` is in PATH)
__-pp__ *or* __--probability-plot__ | string | Path to RNAstructure ``ProbabilityPlot`` executable (Default: assumes ``ProbabilityPlot`` is in PATH)
__-dp__ *or* __--data-path__ | string | Path to RNAstructure data tables (Default: assumes __DATAPATH__ environment variable is already set)
__-w__ *or* __--window-size__ | int | Window's size (in nt) for base-pair probability calculation (&ge;3, Default: __full transcript__)
__-wo__ *or* __--window-offset__ | int | Offset for window sliding (&ge;1, Default: __none__)
__-kb__ *or* __--keep-bases__ | string | Bases to report in the XML file (Default: __N__ [ACGT])<br/>__Note:__ This parameter accepts any IUPAC code, or their combinations (e.g. ``-kb M``, or ``-kb AC``). Any other base will be reported as NaN
__-d__ *or* __--decimals__ | int | Number of decimals for reporting base probabilities (1-10, Default: __3__)

!!! note "Note"
    When using methods #2 or #3, if possible, RF Silico uses RNAstructure ``partition-smp`` instead of ``partition`` to speed-up execution