# Analysis of 2'-O-Methyl data (2OMe-seq)

__1.__ Download and decompress SRA files to FastQ format using the [__NCBI SRA Toolkit__](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software):

```bash
# Download/decompress reads
$ fastq-dump -A SRR2414087		# High dNTP sample
$ fastq-dump -A SRR2414088		# Low dNTP sample

# Rename files
$ mv SRR2414087_1.fastq HeLa_1mM_dNTP.fastq
$ mv SRR2414088_1.fastq HeLa_4nM_dNTP.fastq 
```