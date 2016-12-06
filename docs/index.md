![RNAFramework logo](http://www.rnaframework.com/images/logo_black.png)
<br />  
<br />  

## Introduction

The recent advent of Next Generation Sequencing techniques, has enabled transcriptome-scale analysis of the RNA epistructurome.
Despite the establishment of several methods for querying RNA secondary structures (CIRS-seq, SHAPE-seq, Structure-seq, DMS-seq, PARS, SHAPE-MaP, DMS-MaPseq), and RNA post-transcriptional modifications (&Psi;, m<sup>1</sup>A, m<sup>6</sup>A, m<sup>5</sup>C, hm<sup>5</sup>C, 2'-OMe) on a genome-wide scale, no tool has been developed to date to enable the rapid analysis and interpretation of these data.

The RNA Framework is a modular toolkit developed to deal with RNA structure probing and post-transcriptional modifications mapping high-throughput data.  
Its main features are: 

- Automatic reference transcriptome creation
- Automatic reads preprocessing (adapter clipping and trimming) and mapping
- Scoring and data normalization
- Accurate RNA folding prediction by incorporating structural probing data

For updates, please visit: <http://www.rnaframework.com>  
For support requests, please post your questions to: <https://groups.google.com/forum/#!forum/rnaframework>


## Author

Danny Incarnato (dincarnato[at]rnaframework.com)  
Epigenetics Unit @ HuGeF [Human Genetics Foundation]  


## Citation

Incarnato *et al*., (2015) RNA structure framework: automated transcriptome-wide reconstruction of RNA secondary structures from high-throughput structure probing data ([PMID: 26487736](https://www.ncbi.nlm.nih.gov/pubmed/26487736)).


## License

This program is free software, and can be redistribute and/or modified under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

Please see <http://www.gnu.org/licenses/> for more informations.


## Prerequisites

- Linux/Mac system
- Bowtie v1.0.0 (<http://bowtie-bio.sourceforge.net/index.shtml>)
- SAMTools v1.2 or greater (<http://www.htslib.org/>)
- BEDTools v2.0 or greater (<https://github.com/arq5x/bedtools2/>)
- Cutadapt v1.10 or greater (<http://cutadapt.readthedocs.io/en/stable/index.html>)
- ViennaRNA Package v2.2.0 or greater (<http://www.tbi.univie.ac.at/RNA/>)
- RNAstructure v5.6 or greater (<http://rna.urmc.rochester.edu/RNAstructure.html>)
- Perl v5.12 (or greater), with ithreads support
- Perl non-CORE modules (<http://search.cpan.org/>):

    1. DBD::MySQL  
    2. LWP::UserAgent  
    3. RNA (part of the ViennaRNA package)  
    4. XML::LibXML  


## Installation

Clone RSF git repository:

```bash
git clone https://github.com/dincarnato/RNAFramework
```
This will create the RNAFramework folder.<br />
To add RNA Framework executables to your PATH, simply type:

```bash
export PATH=$PATH:/path/to/RNAFramework
```

!!! tip 'Tip'
	This is a tip
