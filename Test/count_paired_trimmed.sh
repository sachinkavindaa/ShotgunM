#!/bin/bash
#SBATCH --job-name=read_depth_trimmed
#SBATCH --output=read_depth_trimmed.out
#SBATCH --error=read_depth_trimmed.err
#SBATCH --time=24:00:00
#SBATCH --mem=64gb
#SBATCH --ntasks=1
#SBATCH --partition=guest,batch

TRIM_DIR="/work/samodha/sachin/ShotgunM/Test_output/03_trim"

total_reads=0
sample_count=0

echo "Counting paired reads AFTER trimming (Step 3) from: $TRIM_DIR"
echo "---------------------------------------------------------------"

for r1 in "$TRIM_DIR"/trimmed_*_1.fq; do
    # Build corresponding R2 filename
    r2="${r1/_1.fq/_2.fq}"

    if [[ -f "$r1" && -f "$r2" ]]; then
        # Extract sample name (removes directory + suffix)
        sample=$(basename "$r1" | sed 's/trimmed_//' | sed 's/_1.fq//')

        # Count lines and convert to read pairs
        lines_r1=$(wc -l < "$r1")
        lines_r2=$(wc -l < "$r2")
        read_pairs=$(((lines_r1 + lines_r2) / 4))

        echo "$sample: $read_pairs reads"

        total_reads=$((total_reads + read_pairs))
        sample_count=$((sample_count + 1))
    else
        echo "Missing trimmed pair for sample: $sample"
    fi
done

echo "---------------------------------------------------------------"

# Average
if [[ $sample_count -gt 0 ]]; then
    avg_reads=$((total_reads / sample_count))
else
    avg_reads=0
fi

echo "Total paired trimmed reads: $total_reads"
echo "Samples processed: $sample_count"
echo "Average reads per sample: $avg_reads"
