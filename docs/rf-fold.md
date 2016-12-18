The RF Fold module is designed to allow transcriptome-wide reconstruction of RNA structures, starting from XML files generated using the RF Norm tool.This tool can process a single, or an entire directory of XML files, and produces the inferred secondary structures (either in dot-bracket notation, or CT format) and their graphical representation (either in Postscript, or SVG format).<br/>Folding inference can be performed using 2 different algorithms:<br/><br/>1. __ViennaRNA__<br/>2. __RNAstructure__<br/>
    

# Usage
To list the required parameters, simply type:

```bash
$ rf-fold -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-o__ *or* __--output-dir__ | string | Output directory for writing inferred structures (Default: structurome/)
__-ow__ *or* __--overwrite__ | | Overwrites the output directory if already exists
__-ct__ *or* __--connectivity-table__ | | Writes predicted structures in CT format (Default: __Dot-bracket notation__)
__-m__ *or* __--folding-method__ | int | Folding method (1-2, Default: __1__):<br/>__1.__ ViennaRNA <br/>__2.__ RNAstructure
__-p__ *or* __--processors__ | int | Number of processors (threads) to use (Default: __1__)
__-g__ *or* __--img__ | | Enables generation of structure representations (Default: __Postscript format__)
__-s__ *or* __--svg__ | | Structure representations are generated in SVG format (requires ``-g``)
__-t__ *or* __--temperature__ | float | Temperature in Celsius degrees (Default: __37.0__)
__-sl__ *or* __--slope__ | float | Sets the slope used with structure probing data restraints (Default: __1.8__ [kcal/mol])
__-in__ *or* __--intercept__ | float | Sets the intercept used with structure probing data restraints (Default: __-0.6__ [kcal/mol])
__-md__ *or* __--maximum-distance__ | int | Maximum pairing distance (in nt) between transcript's residues (Default: __0__ [no limit])
__-i__ *or* __--ignore-reactivity__ | | Do not use ``rf-norm`` reactivity data to guide folding (MFE unconstrained prediction)
 | | __Folding method #1 options (ViennaRNA)__
__-v__ *or* __--viennarna__ | string | Path to ViennaRNA ``RNAfold`` executable (Default: assumes ``RNAfold`` is in PATH)
__-nlp__ *or* __--no-lonely-pairs__ | | Disallows lonely base-pairs
__-ngu__ *or* __--no-closing-gu__ | | Disallows G:U wobbles at the end of helices
__-cm__ *or* __--constraint-method__ | int | Method for converting ``rf-norm`` reactivities into pseudo-energies (1-2, Default: __1__):<br/>__1.__ Deigan *et al*., 2009<br/>__2.__ Zarringhalam *et al*., 2012
 | | __Zarringhalam *et al*., 2012 method options__
__-cc__ *or* __--constraint-conversion__ | int | Method for converting ``rf-norm`` reactivities into pairing probabilities (1-5, Default: __1__):<br/>__1.__ Skip normalization step (reactivities are treated as pairing probabilities) <br/>__2.__ Linear mapping according to Zarringhalam *et al*., 2012<br/>__3.__ Use a cutoff to divide nucleotides into paired, and unpaired<br/>__4.__ Linear model for converting reactivities into probabilities of being unpaired<br/>__5.__ Linear model for converting the logarithm of reactivities into probabilities of being unpaired
__-bf__ *or* __--beta-factor__ | float | Sets the magnitude of penalities for deviations from the observed pairing probabilities (Default: __0.5__)
__-f__ *or* __--cutoff__ | float | Cutoff for constraining a position as unpaired (&gt;0, Default: __0.7__; requires ``-cc 3``) 
__-ms__ *or* __--model-slope__ | float | Sets the slope used by the linear model (Default: __0.68__ [Method #4], or __1.6__ [Method #5]; requires ``-cc 4`` or ``-cc 5``)
__-mi__ *or* __--model-intercept__ | float | Sets the intercept used by the linear model (Default: __0.2__ [Method #4], or __-2.29__ [Method #5]; requires ``-cc 4`` or ``-cc 5``)
 | | __Folding method #2 options (RNAstructure)__
__-r__ *or* __--rnastructure__ | string | Path to RNAstructure ``Fold`` executable (Default: assumes ``Fold`` is in PATH)
__-dp__ *or* __--data-path__ | string | Path to RNAstructure data tables (Default: assumes __DATAPATH__ environment variable is already set)

!!! note "Information"
    For additional details relatively to ViennaRNA soft-constraint prediction methods, please refer to the [ViennaRNA documentation](http://www.tbi.univie.ac.at/RNA/documentation.html), or to Lorenz *et al*., 2016 (PMID: [26353838](https://www.ncbi.nlm.nih.gov/pubmed/26353838)).