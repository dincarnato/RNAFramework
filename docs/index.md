![RNAFramework logo](http://www.rnaframework.com/images/logo_black.png)
<br />  
<br />  

!!! warning "Important"
    __[2020-01-16] RNA Framework v2.6.9 [major release]:__<br/>Please check the [changelog](https://github.com/dincarnato/RNAFramework/blob/master/CHANGELOG.md) for a complete list of the changes
    
## Introduction

The recent advent of Next Generation Sequencing (NGS) techniques, has enabled transcriptome-scale analysis of the RNA epistructurome.
Despite the establishment of several methods for querying RNA secondary structures (CIRS-seq, SHAPE-seq, Structure-seq, DMS-seq, PARS, SHAPE-MaP, DMS-MaPseq), and RNA post-transcriptional modifications (&Psi;, m<sup>1</sup>A, m<sup>6</sup>A, m<sup>5</sup>C, hm<sup>5</sup>C, 2'-OMe) on a transcriptome-wide scale, no tool has been developed to date to enable the rapid analysis and interpretation of this data.

__RNA Framework__ is a modular toolkit developed to deal with RNA structure probing and post-transcriptional modifications mapping high-throughput data.  
Its main features are: 

- Automatic reference transcriptome creation
- Automatic reads preprocessing (adapter clipping and trimming) and mapping
- Scoring and data normalization
- Accurate RNA folding prediction by incorporating structural probing data

For updates, please visit: <http://www.rnaframework.com>  
For support requests, please post your questions to: <https://github.com/dincarnato/RNAFramework/issues>


## Author

Danny Incarnato (dincarnato[at]rnaframework.com)<br/>
Assistant Professor @ University of Groningen<br/>
Department of Molecular Genetics  


## Reference

Incarnato *et al*., (2018) RNA Framework: an all-in-one toolkit for the analysis of RNA structures and post-transcriptional modifications (PMID: [29893890](https://www.ncbi.nlm.nih.gov/pubmed/29893890)).

Incarnato *et al*., (2015) RNA structure framework: automated transcriptome-wide reconstruction of RNA secondary structures from high-throughput structure probing data (PMID: [26487736](https://www.ncbi.nlm.nih.gov/pubmed/26487736)).


## License

This program is free software, and can be redistribute and/or modified under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

Please see <http://www.gnu.org/licenses/> for more information.


## Prerequisites

- Linux/Mac system
- Bowtie v1.2.3 (<http://bowtie-bio.sourceforge.net/index.shtml>), or
  <br/>Bowtie v2.3.5 or greater (<http://bowtie-bio.sourceforge.net/bowtie2/index.shtml>)
- SAMTools v1.2 or greater (<http://www.htslib.org/>)
- BEDTools v2.0 or greater (<https://github.com/arq5x/bedtools2/>)
- Cutadapt v2.1 or greater (<http://cutadapt.readthedocs.io/en/stable/index.html>)
- ViennaRNA Package v2.2.0 or greater (<http://www.tbi.univie.ac.at/RNA/>)
- RNAstructure v5.6 or greater (<http://rna.urmc.rochester.edu/RNAstructure.html>)
- Perl v5.12 (or greater), with ithreads support
- Perl non-CORE modules (<http://search.cpan.org/>):

    1. DBD::mysql    
    3. RNA (installed by the __ViennaRNA__ package)  
    4. XML::LibXML
    5. Config::Simple  


## Installation

Clone the RNA Framework git repository:

```bash
git clone https://github.com/dincarnato/RNAFramework
```
This will create a "RNAFramework" folder.<br />
To add RNA Framework executables to your PATH, simply type:

```bash
export PATH=$PATH:/path/to/RNAFramework
```