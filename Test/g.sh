#!/bin/sh
#SBATCH --nodes=1
#SBATCH --array=1-81 
#SBATCH --ntasks-per-node=8
#SBATCH --time=24:00:00
#SBATCH --mem=96gb
#SBATCH --output=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.out
#SBATCH --error=/work/samodha/sachin/ShotgunM/Test_output/logs/job%A_%a.err
#SBATCH --job-name=full_cleanup_pipeline
#SBATCH --mail-user=echandrasekara2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --partition=guest,batch

# Load necessary modules
module load bbmap
module load sickle
module load biodata

# Directories
INPUT_DIR="/work/samodha/sachin/ShotgunM/ibkset1"
BASE_OUT="/work/samodha/sachin/ShotgunM/Test_output"
PHIX_REMOVED_DIR="$BASE_OUT/01_phiXremoval"
REPAIR_DIR="$BASE_OUT/02_phiXremovalrepair"
TRIM_DIR="$BASE_OUT/03_trim"
HUMAN_REMOVED_DIR="$BASE_OUT/04_humanremoval"
BOVINE_REMOVED_DIR="$BASE_OUT/05_bovineremoval"
SAMPLE_LIST="$INPUT_DIR/sample_list.txt"

# Reference paths
HUMAN_REF_DIR="/work/HCC/BCRF/Genomes/Homo_sapiens/UCSC/hg38/WholeGenomeFasta/genome.fa"
BOVINE_REF_DIR="/work/samodha/sachin/ShotgunM/bovine_index/bosTau9.fa"

# Create output directories
mkdir -p "$PHIX_REMOVED_DIR" "$REPAIR_DIR" "$TRIM_DIR" "$HUMAN_REMOVED_DIR" "$BOVINE_REMOVED_DIR" "$BASE_OUT/logs"

# Get current sample name
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

# Check if SAMPLE is empty
if [[ -z "$SAMPLE" ]]; then
  echo "[ERROR] No sample found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID"
  exit 1
fi

# Raw input files
FW_IN="${INPUT_DIR}/${SAMPLE}_1.fq.gz"
RV_IN="${INPUT_DIR}/${SAMPLE}_2.fq.gz"

########################
# Step 1: Remove PhiX
########################
FW_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_1.fq.gz"
RV_CLEAN="${PHIX_REMOVED_DIR}/phiX_removed_${SAMPLE}_2.fq.gz"

bbduk.sh in="$FW_IN" out="$FW_CLEAN" k=31 ref=artifacts,phix ordered cardinality
bbduk.sh in="$RV_IN" out="$RV_CLEAN" k=31 ref=artifacts,phix ordered cardinality
echo "[$SAMPLE] PhiX removal done."

########################
# Step 2: Repair
########################
FW_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_1.fq"
RV_REPAIRED="${REPAIR_DIR}/${SAMPLE}_repaired_2.fq"

repair.sh in1="$FW_CLEAN" in2="$RV_CLEAN" out1="$FW_REPAIRED" out2="$RV_REPAIRED" overwrite=true
echo "[$SAMPLE] Repair completed."

########################
# Step 3: Quality Trimming
########################
FW_TRIMMED="${TRIM_DIR}/trimmed_${SAMPLE}_1.fq"
RV_TRIMMED="${TRIM_DIR}/trimmed_${SAMPLE}_2.fq"
SINGLETON="${TRIM_DIR}/trimmed_s_${SAMPLE}.fq"

sickle pe -t sanger -f "$FW_REPAIRED" -r "$RV_REPAIRED" -o "$FW_TRIMMED" -p "$RV_TRIMMED" -s "$SINGLETON" -q 30 -l 75
echo "[$SAMPLE] Trimming completed."

########################
# Step 4: Human Host Removal
########################
FW_NONHUMAN="${HUMAN_REMOVED_DIR}/nonhuman_${SAMPLE}_1.fq"
RV_NONHUMAN="${HUMAN_REMOVED_DIR}/nonhuman_${SAMPLE}_2.fq"

# Clean up any existing index
rm -rf /work/samodha/sachin/ShotgunM/human_index/ref/

# Index the reference genome
bbmap.sh ref=/work/samodha/sachin/ShotgunM/human_index/hg38.fa \
         path=/work/samodha/sachin/ShotgunM/human_index \
         -Xmx64g

bbmap.sh in="$FW_TRIMMED" outu="$FW_NONHUMAN" ref="$HUMAN_REF_DIR" \
  minid=0.95 maxindel=3 bwr=0.20 bw=12 quickmatch fast minhits=2 \
  qtrim=rl trimq=10 untrim -Xmx23g

bbmap.sh in="$RV_TRIMMED" outu="$RV_NONHUMAN" ref="$HUMAN_REF_DIR" \
  minid=0.95 maxindel=3 bwr=0.20 bw=12 quickmatch fast minhits=2 \
  qtrim=rl trimq=10 untrim -Xmx23g

echo "[$SAMPLE] Human host removal completed."

########################
# Step 5: Bovine Host Removal
########################
FW_NOBOVINE="${BOVINE_REMOVED_DIR}/nobovine_${SAMPLE}_1.fq"
RV_NOBOVINE="${BOVINE_REMOVED_DIR}/nobovine_${SAMPLE}_2.fq"


# Clean up any existing index
rm -rf /work/samodha/sachin/ShotgunM/human_index/ref/

# Index the reference genome
bbmap.sh ref=/work/samodha/sachin/ShotgunM/bovine_index/bosTau9.fa \
         path=/work/samodha/sachin/ShotgunM/bovine_index \
         -Xmx64g

bbmap.sh in="$FW_NONHUMAN" outu="$FW_NOBOVINE" ref="$BOVINE_REF_DIR" \
  minid=0.95 maxindel=3 bwr=0.20 bw=12 quickmatch fast minhits=2 \
  qtrim=rl trimq=10 untrim -Xmx23g

bbmap.sh in="$RV_NONHUMAN" outu="$RV_NOBOVINE" ref="$BOVINE_REF_DIR" \
  minid=0.95 maxindel=3 bwr=0.20 bw=12 quickmatch fast minhits=2 \
  qtrim=rl trimq=10 untrim -Xmx23g

echo "[$SAMPLE] Bovine host removal completed."
