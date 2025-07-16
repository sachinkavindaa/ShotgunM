#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=6
#SBATCH --mem=64gb
#SBATCH --partition=guest,batch
#SBATCH --time=12:00:00
#SBATCH --job-name=run_QC_pipeline
#SBATCH --error=run_QC_pipeline.%J.stderr
#SBATCH --output=run_QC_pipeline.%J.stdout
#SBATCH --mail-user=echandrasekara2@unl.edu
#SBATCH --mail-type=ALL

# Load modules
module load sickle/1.33
module load bbmap/39.06
module load bowtie/2.5
module load fastqc/0.12
module load megahit/1.2
module load quast/5.0
module load samtools/1.20
module load prodigal/2.60
module load picard/2.22
module load biodata

# Create output directories
mkdir -p MEGAHIT_assemblies
mkdir -p PRODIGAL_OUTPUTS
mkdir -p idxstat_files

# Set working directory
cd /work/samodha/sachin/ShotgunM/Test || { echo "Data folder not found"; exit 1; }

# Loop through all _1.fq files to pair with _2.fq
for f1 in *_1.fq; do
    sample=$(basename "$f1" _1.fq)
    f2="${sample}_2.fq"

    echo "Processing sample: $sample"

    # Step 1: Adapter removal
    bbduk.sh in="$f1" in2="$f2" out="${sample}_fwd_clean.fq" out2="${sample}_rev_clean.fq" \
        ref=/work/samodha/sachin/ShotgunM/adapters.fa ktrim=r k=23 mink=11 hdist=1 tpe tbo

    # Step 2: PhiX removal
    bbduk.sh in="${sample}_fwd_clean.fq" out="${sample}_fwd_clean_nophi.fq" \
        ref=artifacts,phix k=31 ordered cardinality

    bbduk.sh in="${sample}_rev_clean.fq" out="${sample}_rev_clean_nophi.fq" \
        ref=artifacts,phix k=31 ordered cardinality

    # Step 3: Repair pairs
    repair.sh in1="${sample}_fwd_clean_nophi.fq" in2="${sample}_rev_clean_nophi.fq" \
        out1="${sample}_repaired_1.fq" out2="${sample}_repaired_2.fq" outsingle="${sample}_singletons.fq"

    # Step 4: Quality trimming
    sickle pe -f "${sample}_repaired_1.fq" -r "${sample}_repaired_2.fq" \
        -t sanger -o "${sample}_trimmed_1.fq" -p "${sample}_trimmed_2.fq" \
        -s "${sample}_trimmed_single.fq" -q 30 -l 50

    # Step 5: Host removal with bowtie2
    mkdir -p bowtie2_host_cont_remv_output

    bowtie2 -x /work/HCC/BCRF/Genomes/Homo_sapiens/UCSC/hg38/WholeGenomeFasta/genome.fa \
        -p 6 --very-sensitive \
        -1 "${sample}_trimmed_1.fq" -2 "${sample}_trimmed_2.fq" \
        --un-conc bowtie2_host_cont_remv_output/"${sample}_nonhuman.fastq"

    bowtie2 -x /work/HCC/BCRF/Genomes/Homo_sapiens/UCSC/hg38/WholeGenomeFasta/genome.fa \
        -p 6 --very-sensitive \
        -U "${sample}_trimmed_single.fq" \
        --un bowtie2_host_cont_remv_output/"${sample}_nonhuman_single.fastq"

    # Step 6: FastQC
    fastqc bowtie2_host_cont_remv_output/"${sample}_nonhuman.1.fastq"
    fastqc bowtie2_host_cont_remv_output/"${sample}_nonhuman.2.fastq"
    fastqc bowtie2_host_cont_remv_output/"${sample}_nonhuman_single.fastq"

    # Step 7: Move to assembly folder
    cp bowtie2_host_cont_remv_output/"${sample}_nonhuman."*".fastq" /work/samodha/sachin/ShotgunM/MEGAHIT_assemblies/

    echo "Finished processing sample: $sample"
    echo "-----------------------------"
done
