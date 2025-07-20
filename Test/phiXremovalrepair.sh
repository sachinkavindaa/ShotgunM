#!/bin/bash
#SBATCH --job-name=read_depth_repair
#SBATCH --output=read_depth_repair.out
#SBATCH --error=read_depth_repair.err
#SBATCH --time=24:00:00
#SBATCH --mem=64gb
#SBATCH --ntasks=1
#SBATCH --partition=guest,batch

# Path to repaired FASTQ files
DATA_DIR="/work/samodha/sachin/ShotgunM/Test_output/02_phiXremovalrepair"

# Initialize totals
total_reads=0
sample_count=0

echo "Counting paired reads AFTER repair step from: $DATA_DIR"
echo "--------------------------------------------------------"

# Loop over all *_repaired_1.fq files and find matching _2.fq
for r1 in "$DATA_DIR"/*_repaired_1.fq; do
    r2="${r1/_repaired_1.fq/_repaired_2.fq}"

    if [[ -f "$r1" && -f "$r2" ]]; then
        # Extract sample ID
        sample=$(basename "$r1" | sed 's/_repaired_1.fq//')

        # Count lines
        lines_r1=$(wc -l < "$r1")
        lines_r2=$(wc -l < "$r2")

        # Convert to read pairs (4 lines = 1 read)
        read_pairs=$(((lines_r1 + lines_r2) / 4))

        echo "$sample: $read_pairs reads"

        total_reads=$((total_reads + read_pairs))
        sample_count=$((sample_count + 1))
    else
        echo "Missing pair for sample: $r1"
    fi
done

echo "--------------------------------------------------------"

# Calculate average
if [[ $sample_count -gt 0 ]]; then
    avg_reads=$((total_reads / sample_count))
else
    avg_reads=0
fi

echo "Total reads after repair: $total_reads"
echo "Samples processed: $sample_count"
echo "Average reads per sample: $avg_reads"
