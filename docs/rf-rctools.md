The RF RCTools module enables easy visualization/manipulation of RC files. It allows indexing, merging and dumping RC files.<br />
This tool is particularly useful when the same sample is sequenced more than one time to increase its coverage. Now, instead of merging the BAM files and re-calling the `rf-count` on the whole dataset (that is very time-consuming), each sample can be processed independently and simply merged to the RC file from the previous analysis.<br/>
# Usage
To list the required parameters, simply type:

```bash
$ rf-rctools [tool] -h
```
Available tools are: __index__, __view__ and __merge__

Parameter         | Tool | Type | Description
----------------: | :--: | :--: | :------------
__-t__ *or* __--tab__ | __view__ | | Switches to tabular output format
__-o__ *or* __--output__ | __merge__ | string | Output RC filename (Default: __merge.rc__)
__-ow__ *or* __--overwrite__ | __merge__ | | Overwrites output file (if the specified file already exists)
__-i__ *or* __--index_ | __merge__ | string[,string] | A comma separated (no spaces) list of RCI index files for the provided RC files<br/>__Note:__ RCI files must be provided in the same order as RC files. If a single RCI file is specified along with multiple RC files, it will be used for all of them.
__-T__ *or* __--tmp-dir__ | __merge__ | string | Temporary directory (Default: __/tmp__)
<br/>
## RCTools "view" output
By default, the `view` command produces an output structured as follows:<br/>

```
Transcript_1
ATGGGCAGCTATGCA...TGGGCATGCTGGATG
0,0,0,3,1,2,5,9,16,26,10,14,21,899,888,1038,112,96,1135,167,1164,139,161,3520,2522,2075,172,2043,185,205
245496,239926,233144,232804,232485,229422,225754,224062,222318,219039,216337,212885,207928,206206,203534,184536,184118,185854,183831,180871,177687,174523,170546,167506,163845,161977,150523,150637,143787,142784,137815

Transcript_2
GAATTCATGCATGCG...AGCTAGCGGGGATAT
0,0,0,1,0,2,5,30,17,17,15,34,46,32,409,48,509,56,480,499,68,715,677,782,74,1016,988,2035,108,158
512,583,702,783,847,1517,1852,2084,2191,4791,10389,15321,16535,17231,17823,18254,19388,22321,22944,25503,27254,28285,36273,41905,50366,50724,71321,73144,77610,77903

Transcript_n
ATTGCTTCCAATGAA...AATATGGAGACTATG
150,2152,161,3557,3109,137,3077,190,157,3105,3923,3047,3199,158,2931,159,3501,149,3938,159,162,159,177,186,5684,281,4734,3800,6114,4736
504075,499650,493631,489064,480388,478484,477320,468301,462674,457668,438438,428879,418411,411484,404875,404148,403917,402996,409478,408878,398653,394306,390252,370852,360041,361397,359538,359530,359542,363686
```
in which each transcript is reported as a 4-rows entry, with rows ordered as follows:

- Transcript ID
- Transcript sequence
- Number of per-base RT-stops (or mutations)
- Per-base coverage

When the `-t` parameter is specified, the output is instead structured as follows:<br/>

```
Transcript_1
A       0       242
G       0       280
C       0       359
G       3       390
...
A       1038    56642
T       112     65943
T       96      66134
A       1135    74888

Transcript_2
T       185     100294
G       205     100831
G       185     101003
A       1458    101124
...
A       2529    101509
A       2984    101819
G       227     103858
A       2937    105307

Transcript_n
C       0       945
G       13      990
A       3       1064
A       5       1893
...
A       3       2333
G       36      2648
C       25      2993
A       30      14274
```
in which each transcript is reported as a multi-row entry (with the number of rows equal to transcript's length). Each row is made of 3 tab-spaced fields, ordered as follows:

- Base
- Number of RT-stops (or mutations)
- Coverage

Consecutive entries are separated by a newline.