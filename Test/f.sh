#!/bin/sh
#SBATCH --nodes=1
#SBATCH --array=1-12
#SBATCH --ntasks-per-node=4
#SBATCH --time=10:00:00
#SBATCH --mem=64gb
#SBATCH --output=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.out
#SBATCH --error=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.err
#SBATCH --job-name=full_cleanup_pipeline
#SBATCH --mail-user=echandrasekara2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=guest,batch

# Load necessary modules
module load bbmap
module load sickle

# Directories
INPUT_DIR="/work/samodha/sachin/ShotgunM/Test"
BASE_OUT="/work/samodha/sachin/ShotgunM/Test_output"
PHIX_REMOVED_DIR="$BASE_OUT/01_phiXremoval"
REPAIR_DIR="$BASE_OUT/02_phiXremovalrepair"
TRIM_DIR="$BASE_OUT/03_trim"
HUMAN_REMOVED_DIR="$BASE_OUT/04_humanremoval"
BOVINE_REMOVED_DIR="$BASE_OUT/05_bovineremoval"
SAMPLE_LIST="$INPUT_DIR/sample_list.txt"

# Reference files (must be FASTA files, not directories)
HUMAN_REF="/work/samodha/sachin/human_index/hg38.fa"
BOVINE_REF="/work/samodha/sachin/bovine_index/bosTau9.fa"

# Verify references exist
if [ ! -f "$HUMAN_REF" ]; then
    echo "ERROR: Human reference file $HUMAN_REF not found!"
    exit 1
fi
if [ ! -f "$BOVINE_REF" ]; then
    echo "ERROR: Bovine reference file $BOVINE_REF not found!"
    exit 1
fi

# Create output directories
mkdir -p "$PHIX_REMOVED_DIR" "$REPAIR_DIR" "$TRIM_DIR" \
         "$HUMAN_REMOVED_DIR" "$BOVINE_REMOVED_DIR" "$BASE_OUT/logs"

# Get current sample name
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

########################
# Step 1: Remove PhiX
########################
FW_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_1.fq.gz"
RV_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_2.fq.gz"

bbduk.sh in="$INPUT_DIR/${SAMPLE}_1.fq.gz" out="$FW_CLEAN" \
         in2="$INPUT_DIR/${SAMPLE}_2.fq.gz" out2="$RV_CLEAN" \
         k=31 ref=artifacts,phix ordered cardinality
echo "[$SAMPLE] PhiX removal done."

########################
# Step 2: Repair
########################
FW_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_1.fq"
RV_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_2.fq"

repair.sh in1="$FW_CLEAN" in2="$RV_CLEAN" \
          out1="$FW_REPAIRED" out2="$RV_REPAIRED"
echo "[$SAMPLE] Repair completed."

########################
# Step 3: Quality Trimming
########################
FW_TRIMMED="${TRIM_DIR}/trimmed_${SAMPLE}_1.fq"
RV_TRIMMED="${TRIM_DIR}/trimmed_${SAMPLE}_2.fq"
SINGLETON="${TRIM_DIR}/trimmed_s_${SAMPLE}.fq"

sickle pe -t sanger -f "$FW_REPAIRED" -r "$RV_REPAIRED" \
          -o "$FW_TRIMMED" -p "$RV_TRIMMED" -s "$SINGLETON" \
          -q 30 -l 75
echo "[$SAMPLE] Trimming completed."

########################
# Step 4: Human Host Removal
########################
# First index the reference if needed
if [ ! -f "${HUMAN_REF}.fai" ]; then
    bbmap.sh ref="$HUMAN_REF"
fi

bbmap.sh in="$FW_TRIMMED" in2="$RV_TRIMMED" \
         outu="$HUMAN_REMOVED_DIR/nonhuman_${SAMPLE}#.fq" \
         ref="$HUMAN_REF" \
         minid=0.95 maxindel=3 bwr=0.20 bw=12 \
         quickmatch fast minhits=2 \
         qtrim=rl trimq=10 untrim -Xmx23g
echo "[$SAMPLE] Human host removal completed."

########################
# Step 5: Bovine Host Removal
########################
# First index the reference if needed
if [ ! -f "${BOVINE_REF}.fai" ]; then
    bbmap.sh ref="$BOVINE_REF"
fi

bbmap.sh in="$HUMAN_REMOVED_DIR/nonhuman_${SAMPLE}_1.fq" \
         in2="$HUMAN_REMOVED_DIR/nonhuman_${SAMPLE}_2.fq" \
         outu="$BOVINE_REMOVED_DIR/nobovine_${SAMPLE}#.fq" \
         ref="$BOVINE_REF" \
         minid=0.95 maxindel=3 bwr=0.20 bw=12 \
         quickmatch fast minhits=2 \
         qtrim=rl trimq=10 untrim -Xmx23g
echo "[$SAMPLE] Bovine host removal completed."


#test