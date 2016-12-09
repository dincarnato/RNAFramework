RF Compare allows comparing inferred secondary structures from RSF Fold, with a reference of knownsecondary structures, reporting for each comparison the PPV (Positive Predictive Value, the fraction of basepairspresent in the predicted structure that are also present in the reference structure) and the sensitivity(the fraction of base-pairs present in the reference structure that are also in the predicted structure).<br/>Reference structures must be provided in Vienna format:```>Transcript_1AAAAAAAAAAAAAAAAAAAAUUUUUUUUUUUUUUUUUUUUU.((((((((((((((((((....))))))))))))))))))>Transcript_2CCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGG(((((((((((((((((...)))))))))))))))))-- cut -->Transcript_nGCUAGCUAGCUAGCUAGCUAGUCAAGACGAGUCGAUGCU(((((((((....))))))))).................
```RF Compare can be invoked both on a single structure, or on an entire folder of RF Fold-predicted structure files. Structures can be provided either in CT or Vienna (dot-bracket) format.<br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-compare -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-r__ *or* __--reference__ | string | Path to a file containing reference structures in Vienna format (dot-bracket)