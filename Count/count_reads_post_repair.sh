#!/bin/bash

# Directory containing repaired FASTQ files
REPAIR_DIR="/work/samodha/sachin/ShotgunM/Test_output/02_repair"

# Find all repaired forward read files
FILES=($(ls $REPAIR_DIR/*_fw_fixed.fq 2>/dev/null))

# Initialize counters
total_reads=0
sample_count=0

# Loop through forward files (count only once per pair)
for fw_file in "${FILES[@]}"; do
    if [[ -f "$fw_file" ]]; then
        reads=$(($(wc -l < "$fw_file") / 4))
        total_reads=$((total_reads + reads))
        sample_count=$((sample_count + 1))
    fi
done

# Calculate average reads per sample
if [[ $sample_count -gt 0 ]]; then
    avg_reads=$((total_reads / sample_count))
else
    avg_reads=0
fi

# Print results
echo "Total paired reads after repair: $total_reads"
echo "Samples processed: $sample_count"
echo "Average paired reads per sample: $avg_reads"
