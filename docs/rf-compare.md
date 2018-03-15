RF Compare allows comparing RF Fold-inferred secondary structures, with a reference of known secondary structures, reporting for each comparison the PPV (Positive Predictive Value, the fraction of basepairs present in the predicted structure that are also present in the reference structure) and the sensitivity (the fraction of base-pairs present in the reference structure that are also in the predicted structure).<br/>Reference structures can be provided either in Vienna format (dot-bracket notation), or in CT format:```
# Vienna format
>Transcript#1AAAAAAAAAAAAAAAAAAAAUUUUUUUUUUUUUUUUUUUUU.((((((((((((((((((....))))))))))))))))))>Transcript#2CCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGG(((((((((((((((((...)))))))))))))))))>Transcript#3GCUAGCUAGCUAGCUAGCUAGUCAAGACGAGUCGAUGCU(((((((((....))))))))).................
```The name of the sequence in the reference structure file __must__ match the compared file's name (e.g. "Transcript#1" expects a file named "Transcript#1.ct" or "Transcript#1.db").<br/>RF Compare can be invoked both on a single structure, or on an entire folder of RF Fold-predicted structure files. Structures can be provided either in CT or Vienna (dot-bracket) format.<br/>
Since version 2.5, RF Compare generates vector graphical reports (SVG format) for each structure, reporting the reference structure and the compared structure, with base-pairs colored according to their presence in both structures:<br/><br/>
![RF Compare plot](http://www.rnaframework.com/images/rf-compare_img.png)
<br/><br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-compare -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-r__ *or* __--reference__ | string | Path to a file containing reference structures in Vienna format (dot-bracket)
__-g__ *or* __--img__ | | Enables generation of graphical comparison images
__-o__ *or* __--output-dir__ | string | Images output directory (Default: __rf_compare/__, requires ``-g``)
__-ow__ *or* __--overwrite__ | | Overwrites output directory (if the specified path already exists)
__-x__ *or* __--relaxed__ | | Uses relaxed criteria (described in Deigan *et al.*, 2009) to calculate PPV and sensitivity
__-kn__ *or* __--keep-noncanonical__ | | Keeps non-canonical basepairs in reference structure
__-kp__ *or* __--keep-pseudoknots__ | | Keeps pseudoknotted basepairs in reference structure
__-kl__ *or* __--keep-lonelypairs__ | | Keeps lonely basepairs (helices of length 1 bp) in reference structure

!!! note "Note"
    When parameter ``--relaxed`` is specified, a basepair i-j is considered as present in the reference structure if any of the following pairs exist: i/j; i-1/j; i+1/j; i/j-1; i/j+1. For additional details, please refer to Deigan *et al*., 2009 (PMID: [19109441](https://www.ncbi.nlm.nih.gov/pubmed/19109441))