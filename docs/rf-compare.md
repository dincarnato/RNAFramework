RF Compare allows comparing RF Fold-inferred secondary structures, with a reference of known secondary structures, reporting for each comparison the PPV (Positive Predictive Value, the fraction of basepairs present in the predicted structure that are also present in the reference structure) and the sensitivity (the fraction of base-pairs present in the reference structure that are also in the predicted structure).<br/>Reference structures must be provided in Vienna format:```>Transcript#1AAAAAAAAAAAAAAAAAAAAUUUUUUUUUUUUUUUUUUUUU.((((((((((((((((((....))))))))))))))))))>Transcript#2CCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGG(((((((((((((((((...)))))))))))))))))>Transcript#3GCUAGCUAGCUAGCUAGCUAGUCAAGACGAGUCGAUGCU(((((((((....))))))))).................
```RF Compare can be invoked both on a single structure, or on an entire folder of RF Fold-predicted structure files. Structures can be provided either in CT or Vienna (dot-bracket) format.<br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-compare -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-r__ *or* __--reference__ | string | Path to a file containing reference structures in Vienna format (dot-bracket)
__-x__ *or* __--relaxed__ | | Uses relaxed criteria (described in Deigan *et al.*, 2009) to calculate PPV and sensitivity
__-kn__ *or* __--keep-noncanonical__ | | Keeps non-canonical basepairs in reference structure
__-kp__ *or* __--keep-pseudoknots__ | | Keeps pseudoknotted basepairs in reference structure
__-kl__ *or* __--keep-lonelypairs__ | | Keeps lonely basepairs (helices of length 1 bp) in reference structure