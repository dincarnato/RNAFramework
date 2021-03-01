RF Correlate allows calculating pairwise Pearson correlations of structure probing experiments. It can be invoked either on individual transcripts or on whole XML folders.<br/>
Overall, as well as per-transcript correlations are reported in CSV format.

!!! note "Note"
    When directly comparing two XML files, no check is made on the transcript ID, hence allowing the direct correlation of any two XML files (provided that they are of the same length).
<br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-correlate -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-p__ *or* __--processors__ | int | Number of processors to use (Default: __1__)
__-o__ *or* __--output__ | string | Output CSV file (Default: __rf_correlate.csv__)
__-ow__ *or* __--overwrite__ | | Overwrites output file (if the specified file already exists)
__-m__ *or* __--min-values__ | float | Minimum number of values to calculate correlation (Default: __off__)<br/>__Note:__ if a value between 0 and 1 is provided, this is interpreted as a fraction of the transcript's length 
__-s__ *or* __--skip-overall__ | | Skips overall experiment correlation calculation (faster)
__-S__ *or* __--spearman__ | | Uses Spearman instead of Pearson to calculate correlation
__-i__ *or* __--ingore-sequence__ | | Ignores sequence differences (e.g. SNVs) between the compared transcripts

!!! note "Note"
    When ``--min-values`` specified value is interpreted as a fraction of the transcript's length, only reactive bases (specified by the XML ``reactive`` attribute; for additional details, please refer to the [RF Norm documentation](https://rnaframework.readthedocs.io/en/latest/rf-norm/)) are considered. For example, if a transcript containing 25% of each base has been modified with DMS (than only modifies A/C residues), setting ``--min-values`` to 0.5 will cause RF Correlate to skip the transcript if more than 50% of the A/C residues are NaNs.