#!/bin/bash
#SBATCH --job-name=fastq_stats
#SBATCH --output=fastq_stats.out
#SBATCH --error=fastq_stats.err
#SBATCH --time=05:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --partition=batch,guest

module load seqkit

# Go to directory with FASTQ files
cd /work/samodha/sachin/ShotgunM/Test_output_without_repair/01_phiXremoval

# Output file
OUTFILE="fastq_stats.tsv"

# Add header
echo -e "file\tformat\ttype\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len" > "$OUTFILE"

# Loop through fastq files
for fq in *.fq; do
    if [[ -f "$fq" ]]; then
        seqkit stats "$fq" | tail -n +2 >> "$OUTFILE"
    fi
done
