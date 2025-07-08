#!/bin/sh
#SBATCH --nodes=1
#SBATCH --array=1-12
#SBATCH --ntasks-per-node=4
#SBATCH --time=04:00:00
#SBATCH --mem=32gb
#SBATCH --output=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.out
#SBATCH --error=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.err
#SBATCH --job-name=phix_cleanup_repair
#SBATCH --mail-user=echandrasekara2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=guest,batch

# Load BBMap
module load bbmap

# Input/Output Directories
INPUT_DIR="/work/samodha/sachin/ShotgunM/Test"
BASE_OUT="/work/samodha/sachin/ShotgunM/Test_output"
PHIX_REMOVED_DIR="$BASE_OUT/01_phiXremoval"
REPAIR_DIR="$BASE_OUT/02_phiXremovalrepair"
SAMPLE_LIST="$INPUT_DIR/sample_list.txt"

# Create output directories
mkdir -p "$PHIX_REMOVED_DIR"
mkdir -p "$REPAIR_DIR"
mkdir -p "$BASE_OUT/logs"

# Get sample ID for current SLURM array job
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

# Input files
FW_IN="${INPUT_DIR}/${SAMPLE}_1.fq.gz"
RV_IN="${INPUT_DIR}/${SAMPLE}_2.fq.gz"

# Intermediate output: after PhiX removal
FW_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_1.fq.gz"
RV_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_2.fq.gz"

# Final output: repaired pairs
FW_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_1.fq.gz"
RV_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_2.fq.gz"

# Step 1: Remove PhiX and sequencing artifacts
echo "[$SAMPLE] Starting PhiX/artifact removal..."
bbduk.sh in="$FW_IN" out="$FW_CLEAN" k=31 ref=artifacts,phix ordered cardinality
bbduk.sh in="$RV_IN" out="$RV_CLEAN" k=31 ref=artifacts,phix ordered cardinality
echo "[$SAMPLE] PhiX/artifact removal completed."

# Step 2: Repair paired-end reads
echo "[$SAMPLE] Starting repair..."
repair.sh in1="$FW_CLEAN" in2="$RV_CLEAN" out1="$FW_REPAIRED" out2="$RV_REPAIRED"
echo "[$SAMPLE] Repair completed."

