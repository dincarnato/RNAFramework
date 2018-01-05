The RF JackKnife takes one or more XML reactivity files, and a set of reference RNA structures in dotbracket notation, and iteratively calls ``rf-fold`` by tuning the slope and intercept folding parameters. This is useful to calibrate the folding parameters for a specific probing reagent or experiment type.<br/>
It produces 3 CSV tables respectively containing the positive predictive value (PPV), sensitivity, and the geometric mean of the 2 values for each slope/intercept pair.<br/><br/>
![PPV Sensitivity table](http://www.rnaframework.com/images/PPV_Sensitivity_table.png)

# Usage
To list the required parameters, simply type:

```bash
$ rf-jackknife -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-r__ *or* __--reference__ | string | A file containing reference structures in Vienna format (dotbracket notation)
__-p__ *or* __--processors__ | int | Number of processors to use (Default: __1__)
__-o__ *or* __--output-dir__ | string | Output directory (Default: __rf_jackknife/__)
__-t__ *or* __--tmp-dir__ | string | Temporary directory (Default: __<output>/tmp__)
__-ow__ *or* __--overwrite__ | | Overwrites output directory (if the specified path already exists)
__-sl__ *or* __--slope__ | float,float | Range of slope values to test (Default: __0,5__)
__-in__ *or* __--intercept__ | float,float | Range of intercept values to test (Default: __-3,0__)
__-ss__ *or* __--slope-step__ | float | Step for testing slope values (Default: __0.2__)
__-is__ *or* __--intercept-step__ | float | Step for testing intercept values (Default: __0.2__)
__-x__ *or* __--relaxed__ | | Uses relaxed criteria (described in Deigan *et al.*, 2009) to calculate PPV and sensitivity
__-kn__ *or* __--keep-noncanonical__ | | Keeps non-canonical basepairs in reference structure
__-kp__ *or* __--keep-pseudoknots__ | | Keeps pseudoknotted basepairs in reference structure
__-kl__ *or* __--keep-lonelypairs__ | | Keeps lonely basepairs (helices of length 1 bp) in reference structure
__-m__ *or* __--median__ | | Reports the median PPV/sensitivity value between all reference structures<br/>__Note:__ by default, the geometric mean of PPV/sensitivity values is reported
__-am__ *or* __--arithmetic-mean__ | | Reports the arithmetic mean of PPV/sensitivity values between all reference structures<br/>__Note:__ by default, the geometric mean of PPV/sensitivity values is reported
__-rf__ *or* __--rf-fold__ | string | Path to ``rf-fold`` executable (Default: assumes ``rf-fold`` is in PATH)
__-rp__ *or* __--rf-fold-params__ | string | Manually specify additional RF Fold parameters (e.g. -rp "-md 500 -m 2")
<br/>
## Output CSV files
RF PeakCall produces 3 CSV files, one for PPV, one for sensitivity, and one with the geometric mean of the 2 values, with intercept values on the x-axis, and slope values on the y-axis