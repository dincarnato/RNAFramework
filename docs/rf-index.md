# rf-index

The RF Index tool is designed to automatically generate a Bowtie reference index, that will be used by the RT Count module for reads mapping.<br />This tool requires an internet connection, since it relies on querying the UCSC Genome database to obtain transcripts annotation and reference genome’s sequence.<br /><br />
To list the required parameters, simply type:

```
$ rf-index -h
```

Parameter         | Description
----------------: | :------------
__-o__ *or* __--output-dir__ | Bowtie index output directory (Default: &lt;assembly&gt;\_&lt;annotation&gt;, e.g. “mm9_refFlat/”)
__-ow__ *or* __--overwrite__ | Overwrites the output directory if already exists
__-g__ *or* __--genome-assembly__ | Genome assembly for the species of interest (Default: mm9).<br /> For a complete list of UCSC available assemblies, please refer to the UCSC website (<https://genome.ucsc.edu/FAQ/FAQreleases.html>)


## Author

Danny Incarnato (dincarnato[at]rnaframework.com)  
Epigenetics Unit @ HuGeF [Human Genetics Foundation]  


## Citation

Incarnato *et al*., (2015) RNA structure framework: automated transcriptome-wide reconstruction of RNA secondary structures from high-throughput structure probing data.


## License

This program is free software, and can be redistribute and/or modified under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

Please see http://www.gnu.org/licenses/ for more informations.


## Prerequisites

- Linux/Mac system
- Bowtie v1.0.0 (http://bowtie-bio.sourceforge.net/index.shtml)
- SAMTools v1.2 or greater (http://www.htslib.org/)
- BEDTools v2.0 or greater (https://github.com/arq5x/bedtools2/)
- Cutadapt v1.10 or greater (http://cutadapt.readthedocs.io/en/stable/index.html)
- ViennaRNA Package v2.2.0 or greater (http://www.tbi.univie.ac.at/RNA/)
- RNAstructure v5.6 or greater (http://rna.urmc.rochester.edu/RNAstructure.html)
- Perl v5.12 (or greater), with ithreads support
- Perl non-CORE modules (http://search.cpan.org/):

    1. DBD::MySQL  
    2. LWP::UserAgent  
    3. RNA (part of the ViennaRNA package)  
    4. XML::LibXML  


## Installation

Clone RSF git repository:
```bash
git clone https://github.com/dincarnato/RNAFramework
```
This will create the RNAFramework folder.
To add RNA Framework executables to your PATH, simply type:
```bash
export PATH=$PATH:/path/to/RNAFramework
```

## Usage

Please refer to the RNA Framework manual.  
To obtain parameters list, simply call the required program with the "-h" (or "--help") parameter.