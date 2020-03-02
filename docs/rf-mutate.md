RF Mutate allows designing mutations aimed at disrupting target structure motifs. Not only this tool can also design compensatory mutations aimed at restoring the wild-type structure, but also it allows designing mutations within ORFs, without altering the underlying amino acid sequence.<br/>
RF Mutate requires one or more structure files (either in dot-bracket or CT format) and a motif file, containing the list of the structure motifs to mutagenize. Optionally, an ORF file can be provided, indicating whether (and where) an ORF is present within the analyzed transcripts; in this way, if a target motif overlaps an ORF, RF Mutate can introduce mutations in such a way that the encoded protein remains unchanged. In case no ORF file is provided, RF Mutate can automatically identify the longest ORF (if needed).<br/>
Mutagenesis results are reported in XML format, one file per motif.
<br/><br/>

# Usage
To list the required parameters, simply type:

```bash
$ rf-mutate -h
```

Parameter         | Type | Description
----------------: | :--: |:------------
__-p__ *or* __--processors__ | int | Number of processors to use (Default: __1__)
__-o__ *or* __--output-dir__ | string | Output directory (Default: __rf_mutate/__)
__-ow__ *or* __--overwrite__ | string | Overwrites output directory if already exists
__-mf__ *or* __--motif-file__ | string | Path to a file containing the list of motifs to mutate (mandatory)
__-of__ *or* __--orf-file__ | string | Path to a file containing transcript ORFs (optional)
__-lo__ *or* __--longest-orf__ | | Automatically finds the longest ORF
__-mo__ *or* __--min-orf-length__ | int | Minimum length (in aa) to select the longest ORF (requires ``-lo``, Default: __50__)
__-als__ *or* __--alt-start__ | | Longest ORF is allowed to start with alternative start codons (requires ``-lo``)
__-ans__ *or* __--any-start__ | | Longest ORF is allowed to start with any codon (requires ``-lo``)
__-gc__ *or* __--genetic-code__ | int | Genetic code table for the reference organism (1-33, Default: __1__) __-ec__ *or* __--exclude-codons__ | string | A comma (or semicolon) separated list of rare codons to be avoided 
__-md__ *or* __--min-distance__ | float | Minimum (fractional) base-pair distance between wild-type and mutant (0-1, Default: __0.5__)
__-t__ *or* __--tollerance__ | float | Maximum (fractional) base-pair distance between wild-type and rescue (0-1, Default: __0.2__)
__-mi__ *or* __--max-iterations__ | int | Maximum number of iterations (>0, Default: __1000__)
__-me__ *or* __--max-evaluate__ | int | Maximum number of mutants to evaluate (>0, Default: __1000__)
__-mr__ *or* __--max-results__ | int | Maximum number of mutants to report per motif (Default: __all__)
__-nm__ *or* __--n-mutations__ | int | Number of bases (or codons) to simultaneously mutate (>0, Default: __1__)
__-nr__ *or* __--no-rescue__  | | Disables design of rescue mutations
__-ne__ *or* __--no-ensemble-prob__ | | Disables evaluation of mutant/rescue Boltzmann ensemble
__-vrf__ *or* __--vienna-rnafold__ | string | Path to ViennaRNA RNAfold executable (Default: assumes RNAfold is in PATH)

<br/>
## Motif file
The motif file allows providing a list of target structure motifs to mutagenize.<br/>
It is composed of one or more lines, each one reporting the transcript ID and a comma (or semicolon) separated list of either motif start coordinates (0-based), or motifs in dot-bracket notation:<br/>

```
Transcript_1;25,67
Transcript_2,((((((....))))));44
Transcript_3;0,99;(((...(((...)))...))),189
```
Motif start positions __must__ correspond to the first base-paired residue in a helix. In the following example, valid start positions are marked in green:
<br/><br/>
![Helix start](http://www.rnaframework.com/images/helixstart.png)
<br/><br/>

!!! note "Note"
    The name of the transcripts in the motif file __must__ match the input file names (e.g. "Transcript#1" expects a file named "Transcript#1.ct", "Transcript#1.db", or "Transcript#1.fasta")
    
!!! important "Important"
    If a dot-bracket structure is provided and it occurs more than once in the target transcript, __only the first occurrence__ will be considered

<br/>  
## ORF file
The ORF file allows specifying whether an ORF is present at a given position of the transcript.<br/>
It is composed of one or more lines, each one reporting the transcript ID and either the coordinates of the ORF (0-based, inclusive), or the amino acid sequence of the encoded protein (either full or partial):<br/>

```
Transcript_1;48-254
Transcript_2,122
Transcript_3;MYGAAAHKKLDAGASS
```
!!! note "Note"
    Currently, a single ORF per transcript is supported. RF Mutate cannot deal with multiple/overlapping ORFs.

When a single value is provided (e.g. Transcript_2 in the above example), this will be treated as the start coordinate and the end coordinate will be automatically identified.<br/>
When providing an amino acid sequence, either the full sequence or just a portion of it can be provided. The sequence will then be automatically extended to the closest in-frame STOP codon (both upstream and downstream). This way, RF Mutate will be able to identify the underlying ORF, hence allowing target motif disruption without altering the encoded protein.<br/>
Looking at the following example:<br/>

```
0        9        19       29       39       49       59       69 
|--------|--------|--------|--------|--------|--------|--------|-----
 M  G  I  Y  Q  I  L  A  I  Y  S  T  V  A  S  S  L  V  L  L  V  S  *
ATGGGGATCTATCAGATTCTGGCGATCTACTCAACTGTCGCCAGTTCACTGGTGCTTTTGGTCTCCTAA
..(((((((((((((...((((((((..........))))))))....)))))).....)))))))...
```
If the target motif starts at position 19, it will be sufficient to indicate in the ORF file the "IYSTV" portion (for example) of the amino acid sequence, to make RF Mutate identify the full underlying ORF.<br/><br/>
    
## Ouput XML files
For each motif being mutagenized, RF Mutate will generate an XML file, with the following structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<motif energy="-24.30" frame="0-65" id="seg4" position="2-65">
        <result n="0">
                <mutant codons="6,7" ddG="8.00" distance="46" energy="-16.30" probability="0.00">
                        <sequence>CUGGGGAUCUAUCAGAUUCUCGCCAUCUACUCAACUGUCGCCAGUUCACUGGUGCUUUUGGUCUCC</sequence>
                        <structure>..((((((((...))))))))((((.............((((((....))))))....))))....</structure>
                </mutant>
                <rescue codons="13,14" ddG="6.80" distance="6" energy="-17.50" probability="0.86">
                        <sequence>CUGGGGAUCUAUCAGAUUCUCGCCAUCUACUCAACUGUCGCGAGCUCACUGGUGCUUUUGGUCUCC</sequence>
                        <structure>..(((((((((((((...(((((................)))))....)))))).....)))))))</structure>
                </rescue>
        </result>
</motif>
```

The __motif__ tag’s attributes provide information on the wild-type motif:<br/>

Attribute     | Optional | Description
-------------: | :------------: | :----------
__energy__ | no | Free energy (in kcal/mol) of the wild-type motif
__frame__ | yes | In case the motif falls within an ORF, the *frame* attribute contains the start-end coordinates of the codons within which the motif is enclosed
__id__ | no | Transcript ID
__position__ | no | The coordinates of the first and last base within which the motif is enclosed

Six attributes are instead possible within the __mutate/rescue__ tags:<br/>

Attribute     | Optional | Description
-------------: | :------------: | :----------
__bases__ | yes | For motifs falling within non-coding regions, reports a comma-separated list of the bases (0-based) that have been mutated
__codons__ | yes | For motifs falling within ORFs, reports a comma-separated list of the codons (0-based) that have been mutated
__ddG__ | no | Absolute difference (in kcal/mol) between the free energy of the mutant/rescue structure and that of the wild-type structure
__distance__ | no | Base-pair distance between the mutant/rescue structure and the wild-type structure
__energy__ | no | Free energy (in kcal/mol) of the mutant/rescue structure
__probability__ | no | This corresponds to the average probability of the wild-type base-pairs to still be present within the mutant/rescue Boltzman ensemble. __Note:__ if parameter ``-ne`` (or ``--no-ensemble-prob``) has been specified, this attribute will be set to NaN
