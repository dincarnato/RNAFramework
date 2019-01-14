# 1. PARS

__1.__ Download and decompress SRA files to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR972714		# Nuclease S1 sample
$ fastq-dump -A SRR972715		# RNase V1 sample

# Rename files
$ mv SRR972714.fastq S1.fastq
$ mv SRR972715.fastq V1.fastq 
```
<br/>
__2.__ Prepare the reference index using ``rf-index``. To build the RefSeq gene annotation for *Homo sapiens* (hg38 assembly), simply type:

```bash
$ rf-index -g hg38 -a refGene 
```

This will build a Bowtie v1 reference index. To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-index -g hg38 -a refGene --bowtie2 
```

A folder named "*hg38\_refGene\_bt/*" (or "*hg38\_refGene\_bt2/*" in case Bowtie v2 is used) will be created in the current working directory.<br/><br/>

__3.__ Map reads to reference using ``rf-map`` (__Note:__ according to the GEO dataset's page, the last 51 nt of reads should be trimmed):

```bash
# Reads will be trimmed by 51 nt from their 3'-end, an mapped to transcripts
# sense strand only, allowing a maximum of 20 equally scoring alignments

$ rf-map -bnr -b3 51 -bm 20 -bi hg38_refGene_bt/hg38_refGene S1.fastq V1.fastq
```

To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-map -bnr -b3 51 -bi hg38_refGene_bt2/hg38_refGene S1.fastq V1.fastq --bowtie2
```
<br/>
__4.__ Count RT-stops in both samples using ``rf-count``:

```bash
$ rf-count -r -nm -f hg38_refGene_bt/hg38_refGene.fa rf_map/*.bam
```
<br/>
__5.__ Normalize data using ``rf-norm``:

```bash
# Data will be normalized by default using Ding et al., 2014 
# scoring method, and 2-8% normalization

$ rf-norm -u rf_count/V1.rc -t rf_count/S1.rc -i rf_count/index.rci
```
<br/>
__6.__ Perform transcriptome-wide inference of secondary structures usign ``rf-fold``:

```bash
# Inference will be performed by default according to Deigan et al., 2009,
# using the ViennaRNA algorithm

$ rf-fold -g S1_vs_V1_norm/
```
A folder named "*rf_fold/*" will be generated, containing two subdirectories:<br/><br/>
- "*structures/*": inferred structures in dot-bracket notation<br/>
- "*images/*": graphical summaries in SVG format
<br/><br/>
# 2. DMS-MaPseq

__1.__ Download and decompress SRA file to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR3929629		# S. cerevisiae Tagmented rRNA

# Rename file
$ mv SRR3929629.fastq Sc_Tag_rRNA.fastq 
```
<br/>
__2.__ Prepare the reference index using ``rf-index``. To download the pre-built Bowtie v2 *Saccharomyces cerevisiae* ribosomal RNAs reference index, simply type:

```bash
$ rf-index -pb 3 --bowtie2
```
<br/>
__3.__ Map reads to reference using ``rf-map``:

```bash
$ rf-map -ca3 CTGTCTCTTATACACATCT -bs -bi Scerevisiae_rRNA_bt2/reference Sc_Tag_rRNA.fastq --bowtie2
```
<br/>
__4.__ Count mutations using ``rf-count``:

```bash
$ rf-count -r -m -nm -f Scerevisiae_rRNA_bt2/reference.fa rf_map/Sc_Tag_rRNA.bam
```
<br/>
__5.__ Normalize data using ``rf-norm``:

```bash
# Data will be normalized on A/C residues only, using Zubradt et al., 2016 
# scoring method, and 90% Winsorising

$ rf-norm -t rf_count/Sc_Tag_rRNA.rc -i rf_count/index.rci -sm 4 -nm 2 -rb AC
```

A folder named "*Sc_Tag_rRNA_norm/*" will be generated, containing one XML file for each analyzed transcript.<br/><br/>
# 3. SHAPE-MaP

__1.__ Obtain the [HIV-1 genome](https://www.ncbi.nlm.nih.gov/nuccore/M19921.2?report=fasta&log$=seqview&format=text)'s sequence from NCBI (extracting only bases 455-9626, corresponding to the primary transcript) and save it to HIV.fasta. In case you have [__Entrez Direct__](https://www.ncbi.nlm.nih.gov/books/NBK179288/) installed, simply type:

```bash
$ esearch -db nucleotide -query "M19921.2" | efetch -format fasta | perl -e 'while(<>) { chomp; next if (m/^>/); $seq .= $_; } print ">HIV\n" . substr($seq, 454, 9172) . "\n";' > HIV.fasta
```
<br/>
__2.__ Create the reference index:

```bash
$ bowtie2-build HIV.fasta HIV
``` 
<br/>
__3.__ Obtain FastQ files from SRA Database:

```bash
$ fastq-dump -A SRR1301979 --split-files -O Denatured/ 
$ fastq-dump -A SRR1301974 --split-files -O 1M7/
$ fastq-dump -A SRR1301978 --split-files -O Untreated/
``` 
<br/>
__4.__ Rename FastQ files:

```bash
$ mv Denatured/SRR1301979_1.fastq Denatured_R1.fastq
$ mv Denatured/SRR1301979_2.fastq Denatured_R2.fastq 
$ mv 1M7/SRR1301974_1.fastq 1M7_R1.fastq 
$ mv 1M7/SRR1301974_2.fastq 1M7_R2.fastq$ mv Untreated/SRR1301978_1.fastq Untreated_R1.fastq 
$ mv Untreated/SRR1301978_2.fastq Untreated_R2.fastq
``` 
<br/>
__5.__ Map reads to reference using ``rf-map``:

```bash
$ rf-map -p 3 -b2 -cqo -cq5 20 -bs -bl 15 -bN 1 -bD 20 -bR 3 -bdp 100 -bma 2 -bmp 6,2 -bdg 5,1 -bfg 5,1 -bd \
-mp "--maxins 200" -bi HIV Denatured_R1.fastq,Denatured_R2.fastq 1M7_R1.fastq,1M7_R2.fastq \
Untreated_R1.fastq,Untreated_R1.fastq
```
<br/>
__6.__ Count mutations using ``rf-count``:

```bash
$ rf-count -p 3 -nm -r -f HIV.fasta -m -na -md 200 rf_map/Denatured.bam rf_map/1M7.bam rf_map/Untreated.bam
```
<br/>
__7.__ Normalize data using ``rf-norm``:

```bash
# Data will be normalized using Siegfried et al., 2014 
# scoring method, and Box-plot normalization

$ rf-norm -t rf_count/1M7.rc -u rf_count/Untreated.rc -d rf_count/Denatured.rc -i rf_count/index.rci -sm 3 -nm 3 -o HIV_norm/
```

A folder named "*HIV_norm/*" will be generated, containing a single XML file.<br/><br/>
__8.__ Fold HIV-1 genome using ``rf-fold``:

```bash
$ rf-fold -m 2 -g -md 500 -w -pk -km 2 -ko 100 -pw 1600 -po 375 -wt 300 -fw 3000 -fo 300 HIV_norm/
```
<br/><br/>
# 4. m<sup>6</sup>A-seq

__1.__ Download and decompress SRA files to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR456551		# m6A IP sample
$ fastq-dump -A SRR456555		# Input sample

# Rename files
$ mv SRR456551.fastq IP.fastq
$ mv SRR456555.fastq Input.fastq 
```
<br/>
__2.__ Prepare the reference index using ``rf-index``. To build the *Homo sapiens* mRNAs reference index, simply type:

```bash
$ rf-index -g hg19 -a refGene 
```

This will download a Bowtie v1 reference index. To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-index -g hg19 -a refGene --bowtie2 
```

A folder named "*hg19\_refGene\_bt/*" (or "*hg19\_refGene\_bt2/*" in case Bowtie v2 is used) will be created in the current working directory.<br/><br/>
__3.__ Map reads to reference using ``rf-map``:

```bash
$ rf-map -ca3 GATCGGAAGAGCGGTTCAGCAG -bm 20 -bi hg19_refGene_bt/hg19_refGene Input.fastq IP.fastq
```

To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-map -ca3 GATCGGAAGAGCGGTTCAGCAG -bm 20 -bi hg19_refGene_bt/hg19_refGene Input.fastq IP.fastq --bowtie2
```
<br/>
__4.__ Calculate read coverage in both samples using ``rf-count``:

```bash
$ rf-count -nm -r -co -f hg19_refGene_bt/hg19_refGene.fa rf_map/*.bam
```
<br/>
__5.__ Call m<sup>6</sup>A peaks using ``rf-peakcall``:

```bash
$ rf-peakcall -c rf_count/Input.rc -I rf_count/IP.rc -i rf_count/index.rci -e 2.5
```

A BED file named "*IP\_vs\_Input.bed*" will be generated, containing the called peaks.
<br/><br/>
# 5. 2OMe-seq

__1.__ Download and decompress SRA files to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR2414087		# High dNTP (1 mM) sample
$ fastq-dump -A SRR2414088		# Low dNTP (4 nM) sample

# Rename files
$ mv SRR2414087.fastq HeLa_1mM_dNTP.fastq
$ mv SRR2414088.fastq HeLa_4nM_dNTP.fastq 
```
<br/>
__2.__ Prepare the reference index using ``rf-index``. To download the pre-built *Homo sapiens* ribosomal RNAs reference index, simply type:

```bash
$ rf-index -pb 1 
```

This will download a Bowtie v1 reference index. To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-index -pb 1 --bowtie2 
```

A folder named "*Hsapiens\_rRNA_bt/*" (or "*Hsapiens\_rRNA_bt2/*" in case Bowtie v2 is used) will be created in the current working directory.<br/><br/>
__3.__ Map reads to reference using ``rf-map``:

```bash
$ rf-map -b5 5 -bi Hsapiens_rRNA_bt/reference HeLa_1mM_dNTP.fastq HeLa_4nM_dNTP.fastq
```

To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-map -b5 5 -bi Hsapiens_rRNA_bt/reference HeLa_1mM_dNTP.fastq HeLa_4nM_dNTP.fastq --bowtie2
```
<br/>
__4.__ Count RT-stops in both samples using ``rf-count``:

```bash
$ rf-count -r -fh -f Hsapiens_rRNA_bt/reference.fa rf_map/*.bam
```
<br/>
__5.__ Calculate per-base score and ratio using ``rf-modcall``:

```bash
$ rf-modcall -u rf_count/HeLa_1mM_dNTP.rc -t rf_count/HeLa_4nM_dNTP.rc -i rf_count/index.rci
```

A folder named "*HeLa\_4nM\_dNTP\_vs\_HeLa\_1mM\_dNTP/*" will be generated, containing one XML file for each analyzed transcript.
