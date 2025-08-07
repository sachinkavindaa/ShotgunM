#!/bin/bash

# Directory containing trimmed FASTQ files
TRIM_DIR="/work/samodha/sachin/ShotgunM/Test_output/03_trim"

# Find all trimmed forward reads (paired)
FW_FILES=($(ls "$TRIM_DIR"/*_fw_trimmed.fq 2>/dev/null))
# Find all singleton reads
SINGLETON_FILES=($(ls "$TRIM_DIR"/*_trimmed_single.fq 2>/dev/null))

# Initialize counters
paired_total=0
singleton_total=0
paired_sample_count=0
singleton_sample_count=0

# Loop through forward trimmed files to count paired reads
for fw_file in "${FW_FILES[@]}"; do
    if [[ -f "$fw_file" ]]; then
        reads=$(($(wc -l < "$fw_file") / 4))
        paired_total=$((paired_total + reads))
        paired_sample_count=$((paired_sample_count + 1))
    fi
done

# Loop through singleton files
for single_file in "${SINGLETON_FILES[@]}"; do
    if [[ -f "$single_file" ]]; then
        reads=$(($(wc -l < "$single_file") / 4))
        singleton_total=$((singleton_total + reads))
        singleton_sample_count=$((singleton_sample_count + 1))
    fi
done

# Total combined reads
total_trimmed_reads=$((paired_total + singleton_total))

# Average calculations
if [[ $paired_sample_count -gt 0 ]]; then
    avg_paired=$((paired_total / paired_sample_count))
else
    avg_paired=0
fi

if [[ $singleton_sample_count -gt 0 ]]; then
    avg_singleton=$((singleton_total / singleton_sample_count))
else
    avg_singleton=0
fi

# Print results
echo "Total paired reads after trimming   : $paired_total"
echo "Samples with paired reads           : $paired_sample_count"
echo "Average paired reads per sample     : $avg_paired"
echo "Total singleton reads after trimming: $singleton_total"
echo "Samples with singleton reads        : $singleton_sample_count"
echo "Average singleton reads per sample  : $avg_singleton"
echo "Total reads after trimming (combined): $total_trimmed_reads"
