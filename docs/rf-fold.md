The RF Fold module is designed to allow transcriptome-wide reconstruction of RNA structures, starting from XML files generated using the RF Norm tool.This tool can process a single, or an entire directory of XML files, and produces the inferred secondary structures (either in dot-bracket notation, or CT format) and their graphical representation (either in Postscript, or SVG format).<br/>Folding inference can be performed using 2 different algorithms:<br/><br/>1. __ViennaRNA__<br/>2. __RNAstructure__<br/><br/>
Prediction can be performed either on the whole transcript, or through a windowed approach (see next paragraph).
<br/><br/>
## Windowed folding    
The windowed folding approach is based on the original method described in Siegfried *et al*., 2014 (PMID: [25028896](https://www.ncbi.nlm.nih.gov/pubmed/25028896)), and consists of 3 main steps, outlined below:
<br/><br/>
![RNAFramework pipeline](http://www.rnaframework.com/images/windowed_folding.png)
<br/><br/>
In step I (optional), a window is slid along the RNA, and pseudoknotted structures are detected using the same approach employed by the __ShapeKnots__ algorithm (Hajdin *et al.*, 2013 (PMID: [23503844](https://www.ncbi.nlm.nih.gov/pubmed/23503844))). Our implementation of the ShapeKnots algorithm relies on the __ViennaRNA package__ (instead of __RNAstructure__ as the original implementation did), thus is __much__ faster:
<br/><br/>
![ShapeKnots/RNA Framework comparison](http://www.rnaframework.com/images/shapeknots.png)
<br/><br/>
Nonetheless, both algorithms work in single thread. Alternatively, the multi-thread implementation ``ShapeKnots-smp`` shipped with the latest __RNAstructure__ version can be used.<br/> 
If constraints from structure probing experiments are provided, these are incorporated in the form of soft-constraints. Predicted pseudoknotted base-pairs are retained if they apper in >50% of analyzed windows. In case constraints are provided, pseudoknots are retained only if the average reactivity of bases on both sides of the helices is below a certain reactivity cutoff.<br/>
In step II, a window is slid along the RNA, and partition function is calculated. If provided, soft-constraints are applied. If step I has been performed, pseudoknotted bases are hard-constrained to be single-stranded. Predicted base-pair probabilities are averaged across all windows in which they have appeared, and base-pairs with >99% probability are retained, and hard-constrained to be paired in step III.<br/>
In step III, a window is slid along the RNA, and MFE folding is performed, including (where present) soft-constraints from probing data, and hard-constraints from stages I and II. Predicted base-pairs are retained if they appear in >50% of analyzed windows.

!!! note "Note"
    At all stages, increased sampling is performed at the 5'/3'-ends to avoid end biases

At this stage, if step I has been peformed, pseudoknotted base-pairs are added back to the structure, and the free energy is computed. Along with the predicted structure, the windowed method also produces a WIGGLE track file containing per-base Shannon entropies.<br/>Regions with higher Shannon entropies are likely to form alternative structures, while those with low Shannon entropies correspond to regions with well-defined RNA structures, or persistent single-strandedness (Siegfried *et al*., 2014).<br/>
Shannon entropy is calculated as: <br/>

<math display="block" xmlns="http://www.w3.org/1998/Math/MathML"><msub><mi>H</mi><mi>i</mi></msub><mo>=</mo><mo>-</mo> <munderover><mo>&sum;</mo><mrow><mi>j</mi><mo>=</mo><mn>1</mn></mrow><mi>J</mi></munderover><msub><mi>p</mi><mi>i,j&#xA0;</mi></msub><msub><mi>log</mi><mn>10&#xA0;</mn></msub><msub><mi>p</mi><mi>i,j</mi></msub></math><br/>
where *p<sub>i,j</sub>* is the probability of base *i* of being base-paired to base *j*, over all its potential J pairing partners.<br/>
Since version 2.5, RF Fold generates vector graphical reports (SVG format) for each structure, reporting the per-base reactivity, the MEA structure, the per-base Shannon entropy, and the base-pairing probabilities:<br/><br/>
![Graphical report](http://www.rnaframework.com/images/graphical_report.png)
<br/><br/>

!!! note "Note"
    The calculation of Shannon entropy and base-pairing probabilities requires partition function to be computed. Since this is a *very slow* step, partition function folding is performed only in windowed mode, or if parameters ``-dp`` (or ``--dotplot``) or ``-sh`` (or ``--shannon``) are explicitly specified.

# Usage
To list the required parameters, simply type:

```bash
$ rf-fold -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-o__ *or* __--output-dir__ | string | Output directory for writing inferred structures (Default: rf_fold/)
__-ow__ *or* __--overwrite__ | | Overwrites the output directory if already exists
__-ct__ *or* __--connectivity-table__ | | Writes predicted structures in CT format (Default: __Dot-bracket notation__)
__-m__ *or* __--folding-method__ | int | Folding method (1-2, Default: __1__):<br/>__1.__ ViennaRNA <br/>__2.__ RNAstructure
__-p__ *or* __--processors__ | int | Number of processors (threads) to use (Default: __1__)
__-g__ *or* __--img__ | | Enables the generation of graphical reports
__-t__ *or* __--temperature__ | float | Temperature in Celsius degrees (Default: __37.0__)
__-sl__ *or* __--slope__ | float | Sets the slope used with structure probing data restraints (Default: __1.8__ [kcal/mol])
__-in__ *or* __--intercept__ | float | Sets the intercept used with structure probing data restraints (Default: __-0.6__ [kcal/mol])
__-md__ *or* __--maximum-distance__ | int | Maximum pairing distance (in nt) between transcript's residues (Default: __0__ [no limit])
__-nlp__ *or* __--no-lonelypairs__ | | Disallows lonely base-pairs (1 bp helices) inside predicted structures
__-i__ *or* __--ignore-reactivity__ | | Ignores XML reactivity data when performing folding (MFE unconstrained prediction)
__-hc__ *or* __--hard-constraint__ | | Besides performing soft-constraint folding, allows specifying a reactivity cutoff (specified by ``-f``) for hard-constraining a base to be single-stranded
__-f__ *or* __--cutoff__ | float | Reactivity cutoff for constraining a position as unpaired (&gt;0, Default: __0.7__) 
__-w__ *or* __--windowed__ | | Enables windowed folding
__-pt__ *or* __--partition__ | string | Path to RNAstructure ``partition`` executable (Default: assumes ``partition`` is in PATH)<br/>__Note:__ by default, ``partition-smp`` will be used (if available)
__-pp__ *or* __--probabilityplot__ | string | Path to RNAstructure ``ProbabilityPlot`` executable (Default: assumes ``ProbabilityPlot`` is in PATH)
__-fw__ *or* __--fold-window__ | int | Window size (in nt) for performing MFE folding (>=50, Default: __600__)
__-fo__ *or* __--fold-offset__ | int | Offset (in nt) for MFE folding window sliding (Default: __200__)
__-pw__ *or* __--partition-window__ | int | Window size (in nt) for performing partition function (>=50, Default: __600__)
__-po__ *or* __--partition-offset__ | int | Offset (in nt) for partition function window sliding (Default: __200__)
__-wt__ *or* __--window-trim__ | int | Number of bases to trim from both ends of the partition windows to avoid end biases (Default: __100__)
__-dp__ *or* __--dotplot__ | | Enables generation of dot-plots of base-pairing probabilities
__-sh__ *or* __--shannon-entropy__ | | Enables generation of a WIGGLE track file with per-base Shannon entropies
__-pk__ *or* __--pseudoknots__ | | Enables detection of pseudoknots (computationally intensive)
__-ksl__ *or* __--pseudoknot-slope__ | float | Sets slope used for pseudoknots prediction (Default: same as ``-sl <slope>``)
__-kin__ *or* __--pseudoknot-intercept__ | float | Sets intercept used for pseudoknots prediction (Default: same as ``-in <intercept>``)
__-kp1__ *or* __--pseudoknot-penality1__ | float | Pseudoknot penality P1 (Default: __0.35__)
__-kp2__ *or* __--pseudoknot-penality2__ | float | Pseudoknot penality P2 (Default: __0.65__)
__-kt__ *or* __--pseudoknot-tollerance__ | float | Maximum tollerated deviation of suboptimal structures energy from MFE (>0-1, Default: __0.25__ [25%])
__-kh__ *or* __--pseudoknot-helices__ | int | Number of candidate pseudoknotted helices to evaluate (>0, Default: __100__)
__-kw__ *or* __--pseudoknot-window__ | int | Window size (in nt) for performing pseudoknots detection (>=50, Default: __600__)
__-ko__ *or* __--pseudoknot-offset__ | int | Offset (in nt) for pseudoknots detection window sliding (Default: __200__)
__-kc__ *or* __--pseudoknot-cutoff__ | float | Reactivity cutoff for retaining a pseudoknotted helix (0-1, Default: __0.5__)
__-km__ *or* __--pseudoknot-method__ | int | Algorithm for pseudoknots prediction (1-2, Default: __1__):<br/>__1.__ RNA Framework <br/>__2.__ ShapeKnots<br/>__Note:__ the chosen folding method (specified by ``-m``) affects the algorithm used by RNA Framework (pseudoknot detection method #1) to define the initial MFE structure
 | | __RNA Framework pseudoknots detection algorithm options__
__-vrs__ *or* __--vienna-rnasubopt__ | string | Path to ViennaRNA  ``RNAsubopt`` executable (Default: assumes ``RNAsubopt`` is in PATH)
__-ks__ *or* __--pseudoknot-suboptimal__ | int | Number of suboptimal structures to evaluate for pseudoknots prediction (>0, Default: __1000__)
__-nz__ *or* __--no-zuker__ | | Disables the inclusion of Zuker suboptimal structures (reduces the sampled folding space)
__-zs__ *or* __--zuker-suboptimal__ | | Number of Zuker suboptimal structures to include (>0, Default: __1000__)
 | | __ShapeKnots pseudoknots detection algorithm options__
__-sk__ *or* __--shapeknots__ | string | Path to ``ShapeKnots`` executable (Default: assumes ``ShapeKnots`` is in PATH)<br/>__Note:__ by default, ``ShapeKnots-smp`` will be used (if available)
 | | __Folding method #1 options (ViennaRNA)__
__-vrf__ *or* __--vienna-rnafold__ | string | Path to ViennaRNA ``RNAfold`` executable (Default: assumes ``RNAfold`` is in PATH)
__-ngu__ *or* __--no-closing-gu__ | | Disallows G:U wobbles at the end of helices
__-cm__ *or* __--constraint-method__ | int | Method for converting provided reactivities into pseudo-energies (1-2, Default: __1__):<br/>__1.__ Deigan *et al*., 2009<br/>__2.__ Zarringhalam *et al*., 2012
 | | __Zarringhalam *et al*., 2012 method options__
__-cc__ *or* __--constraint-conversion__ | int | Method for converting ``rf-norm`` reactivities into pairing probabilities (1-5, Default: __1__):<br/>__1.__ Skip normalization step (reactivities are treated as pairing probabilities) <br/>__2.__ Linear mapping according to Zarringhalam *et al*., 2012<br/>__3.__ Use a cutoff to divide nucleotides into paired, and unpaired<br/>__4.__ Linear model for converting reactivities into probabilities of being unpaired<br/>__5.__ Linear model for converting the logarithm of reactivities into probabilities of being unpaired
__-bf__ *or* __--beta-factor__ | float | Sets the magnitude of penalities for deviations from the observed pairing probabilities (Default: __0.5__)
__-ms__ *or* __--model-slope__ | float | Sets the slope used by the linear model (Default: __0.68__ [Method #4], or __1.6__ [Method #5]; requires ``-cc 4`` or ``-cc 5``)
__-mi__ *or* __--model-intercept__ | float | Sets the intercept used by the linear model (Default: __0.2__ [Method #4], or __-2.29__ [Method #5]; requires ``-cc 4`` or ``-cc 5``)
 | | __Folding method #2 options (RNAstructure)__
__-rs__ *or* __--rnastructure__ | string | Path to RNAstructure ``Fold`` executable (Default: assumes ``Fold`` is in PATH)<br/>__Note:__ by default, ``Fold-smp`` will be used (if available)
__-d__ *or* __--data-path__ | string | Path to RNAstructure data tables (Default: assumes __DATAPATH__ environment variable is already set)

!!! note "Information"
    For additional details relatively to ViennaRNA soft-constraint prediction methods, please refer to the [ViennaRNA documentation](http://www.tbi.univie.ac.at/RNA/documentation.html), or to Lorenz *et al*., 2016 (PMID: [26353838](https://www.ncbi.nlm.nih.gov/pubmed/26353838)).

!!! note "Information"
    For additional details relatively to ShapeKnots pseudoknots detection parameters, please refer to Hajdin *et al.*, 2013 (PMID: [23503844](https://www.ncbi.nlm.nih.gov/pubmed/23503844)).
<br/> 
## Output dot-plot files
When option ``-dp`` is provided, RF Fold produces a dot-plot file for each transcript being analyzed, with the following structure:<br/>

```
1549                                   # RNA's length
i       j       -log10(Probability)	   # Header 
8       254     0.459355416499312
9       253     0.446335563943221
10      252     0.456738523239413
11      251     0.454733421725068
12      250     0.46965667808714
13      249     0.47837140333524
21      35      0.268192200569539
22      34      0.0183400615262171
23      33      0.0166665677814708
24      32      0.0128927546134575
25      31      0.0148601207296645
26      30      0.0252017532628297

-- cut --

1497    1510    0.0147874890078331
1498    1509    0.0102803152157546
1499    1508    0.0137510190884233
1500    1507    0.0402352346970943
```
where *i* and *j* are the positions (1-based) of the bases involved in a given base-pair, followed by the -log<sub>10</sub> of their base-pairing probability.<br/>These files can be easily viewed using the __Integrative Genomics Viewer (IGV)__ (for additional details, please refer to the official <a href="http://software.broadinstitute.org/software/igv/">Broad Institute's IGV page</a>).