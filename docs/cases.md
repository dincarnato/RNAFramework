# Analysis of 2'-O-Methyl data (2OMe-seq)

__1.__ Download and decompress SRA files to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR2414087		# High dNTP (1 mM) sample
$ fastq-dump -A SRR2414088		# Low dNTP (4 nM) sample

# Rename files
$ mv SRR2414087_1.fastq HeLa_1mM_dNTP.fastq
$ mv SRR2414088_1.fastq HeLa_4nM_dNTP.fastq 
```
<br/>
__2.__ Prepare the reference index using ``rf-index``. To download a pre-build *Homo sapiens* ribosomal RNAs reference index, simply type:

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
# Specify FastQ files
$ rf-map -bnr -b5 5 -bi  Hsapiens_rRNA_bt/reference HeLa_1mM_dNTP.fastq HeLa_4nM_dNTP.fastq
```

To use Bowtie v2, simply append the ``-b2`` (or ``--bowtie2``) parameter to the previous command:

```bash
$ rf-map -bnr -b5 5 -bi  Hsapiens_rRNA_bt2/reference HeLa_1mM_dNTP.fastq HeLa_4nM_dNTP.fastq --bowtie2
```
<br/>
__4.__ Count RT-stops in both samples using ``rf-count``:

```bash
$ rf-count -fh -f Hsapiens_rRNA_bt/reference.fa rf_map/*.bam
```
<br/>
__5.__ Calculate per-base score and ratio using ``rf-modcall``:

```bash
$ rf-modcall -u rf_count/HeLa_1mM_dNTP.rc -t rf_count/HeLa_4nM_dNTP.rc -i rf_count/index.rci
```