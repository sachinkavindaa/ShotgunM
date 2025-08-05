#!/bin/bash
#SBATCH --job-name=read_depth_post_phix
#SBATCH --output=read_depth_post_phix.out
#SBATCH --error=read_depth_post_phix.err
#SBATCH --time=24:00:00
#SBATCH --mem=16gb
#SBATCH --ntasks=1
#SBATCH --partition=guest,batch

DATA_DIR="/work/samodha/sachin/ShotgunM/Test_output/01_phiXremoval"

total_reads=0
sample_count=0

echo "Counting paired reads AFTER PhiX removal from: $DATA_DIR"
echo "---------------------------------------------------------"

# Match *_fw_clean.fq and pair with *_rv_clean.fq
for r1 in "$DATA_DIR"/*_fw_clean.fq; do
    r2="${r1/_fw_clean.fq/_rv_clean.fq}"

    if [[ -f "$r1" && -f "$r2" ]]; then
        sample=$(basename "$r1" | sed 's/_fw_clean.fq//')

        lines_r1=$(wc -l < "$r1")
        lines_r2=$(wc -l < "$r2")

        read_pairs=$(((lines_r1 + lines_r2) / 4))

        echo "$sample: $read_pairs reads"

        total_reads=$((total_reads + read_pairs))
        sample_count=$((sample_count + 1))
    else
        echo "Missing pair for sample: $r1 or $r2"
    fi
done

echo "---------------------------------------------------------"

if [[ $sample_count -gt 0 ]]; then
    avg_reads=$((total_reads / sample_count))
else
    avg_reads=0
fi

echo "Total reads after PhiX removal: $total_reads"
echo "Samples processed: $sample_count"
echo "Average reads per sample: $avg_reads"
