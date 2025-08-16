#!/bin/bash
#SBATCH --job-name=fastq_stats
#SBATCH --output=fastq_stats.out
#SBATCH --error=fastq_stats.err
#SBATCH --time=05:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=12       # use all CPUs available
#SBATCH --partition=batch,guest

module purge
module load seqkit

# Directory with FASTQ files
cd /work/samodha/sachin/ShotgunM/Test_output_without_repair/03_trim || exit 1

# Output file
OUTFILE="fastq_stats_new.tsv"

# Run seqkit once on all files, tab-delimited, multi-threaded
seqkit stats -Ta -j "$SLURM_CPUS_PER_TASK" *.fq > "$OUTFILE"

echo "[OK] Wrote stats to $OUTFILE"
