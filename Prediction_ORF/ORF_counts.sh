#!/bin/bash -l
#SBATCH --job-name=build_orf_table
#SBATCH --partition=guest,batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --output=build_orf_table.%J.out
#SBATCH --error=build_orf_table.%J.err
#SBATCH --mail-user=echandrasekara2@unl.edu
#SBATCH --mail-type=END,FAIL

set -euo pipefail
shopt -s nullglob

# ========= CONFIGURE THESE IF NEEDED ============
# Directory containing *_coasm_ORFs.idxstats.txt file:
IDXDIR="/work/samodha/sachin/ShotgunM/Test_output_without_repair/map_to_ORFs/idxstats"
# Output file:
OUT="${IDXDIR}/ORF_counts.tsv"
# ============================================

module purge   # no special modules needed (uses awk, sort, paste from coreutils)
export LC_ALL=C  # faster and consistent sorting

echo "[`date`] Starting ORF count table build"
cd "$IDXDIR"

# Find sample idxstats files
mapfile -t FILES < <(ls *_coasm_ORFs.idxstats.txt 2>/dev/null | sort -V)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: No *_coasm_ORFs.idxstats.txt files found in $IDXDIR"
  exit 1
fi

# Derive sample names (strip suffix)
: > samples.txt
for f in "${FILES[@]}"; do
  bn="${f%_coasm_ORFs.idxstats.txt}"
  echo "$bn" >> samples.txt
done

# Build header
HEADER="ORF_ID\tLEN"
HEADER="$HEADER\t$(paste -sd $'\t' samples.txt)"
printf "%b\n" "$HEADER" > "$OUT"

# Make per-sample tmp tables: columns -> ORF_ID, LEN, MAPPED
# Note: idxstats lines are: <ref>\t<len>\t<mapped>\t<unmapped>
tmp_list=()
for s in $(cat samples.txt); do
  in="${s}_coasm_ORFs.idxstats.txt"
  out="${s}.tmp"
  awk '$1!="*"{print $1"\t"$2"\t"$3}' "$in" | sort -k1,1 > "$out"
  tmp_list+=("$out")
done

# Optional sanity check: ensure all tmp files have the same number of lines
nref=$(wc -l < "${tmp_list[0]}")
for t in "${tmp_list[@]}"; do
  nl=$(wc -l < "$t")
  if [[ "$nl" -ne "$nref" ]]; then
    echo "ERROR: ORF row count differs across tmp files (e.g., ${tmp_list[0]}:$nref vs $t:$nl)."
    echo "       Ensure all idxstats were generated against the SAME ORF reference."
    exit 1
  fi
done

# Paste all tmp files side-by-side and keep only one LEN column + all MAPPED columns.
# Since each tmp has columns [ORF_ID, LEN, MAPPED], the pasted stream looks like:
# ORF_ID1 LEN1 MAP1 | ORF_ID2 LEN2 MAP2 | ...  We keep ORF_ID from 1st, LEN from 1st, and each MAP col.
paste "${tmp_list[@]}" \
| awk 'BEGIN{OFS="\t"}{
    id=$1; len=$2;
    printf "%s\t%s", id, len;
    for(i=3;i<=NF;i+=3){ printf "\t%s", $i }  # every 3rd col is a mapped count
    printf "\n"
  }' >> "$OUT"

# Clean
rm -f "${tmp_list[@]}"

echo "[`date`] Done. Wrote: $OUT"
echo "[`date`] Samples: $(wc -l < samples.txt)"
echo "[`date`] ORFs: $(( $(wc -l < "$OUT") - 1 ))"

###