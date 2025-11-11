#!/bin/bash -l
#SBATCH --job-name=normalize_cpm
#SBATCH --partition=guest,batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=24:00:00
#SBATCH --output=normalize_cpm.%J.out
#SBATCH --error=normalize_cpm.%J.err
#SBATCH --mail-user=echandrasekara2@unl.edu
#SBATCH --mail-type=END,FAIL

set -euo pipefail

# --------- CONFIGURE THESE IF NEEDED ---------
WORKDIR="/work/samodha/sachin/ShotgunM/Test_output_without_repair/map_to_ORFs/idxstats"
IN="${WORKDIR}/ORF_counts.filtered.tsv"
OUT="${WORKDIR}/ORF_counts.filtered.cpm.tsv"
CHUNKSIZE=100000     # lines per chunks
# ---------------------------------------------

module purge
module load python/3.10

echo "[$(date)] Normalizing to CPM"
echo "IN=$IN"
echo "OUT=$OUT"
echo "CHUNKSIZE=$CHUNKSIZE"

# Basic checks
[[ -s "$IN" ]] || { echo "ERROR: input file not found or empty: $IN"; exit 1; }
# Idempotent skip: uncomment to skip if output already exists
# [[ -s "$OUT" ]] && { echo "Output exists ($OUT) — skipping."; exit 0; }

python - "$IN" "$OUT" "$CHUNKSIZE" << 'PY'
import sys
import math
import pandas as pd

if len(sys.argv) != 4:
    sys.stderr.write("Usage: python - IN OUT CHUNKSIZE\n")
    sys.exit(2)

IN, OUT, CHUNK_STR = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    CHUNKSIZE = int(CHUNK_STR)
except ValueError:
    sys.stderr.write(f"Invalid CHUNKSIZE: {CHUNK_STR}\n")
    sys.exit(2)

print(f"[PASS 1] Computing library sizes from {IN} ...", flush=True)
libs = None
i = 0
for i, chunk in enumerate(pd.read_csv(IN, sep="\t", chunksize=CHUNKSIZE, low_memory=False), 1):
    if libs is None:
        # Expect columns: ORF_ID, LEN, sample1, sample2, ...
        samples = chunk.columns[2:]
        libs = pd.Series(0.0, index=samples, dtype="float64")
    # sum numeric sample columns in this chunk
    libs = libs.add(chunk[samples].sum(numeric_only=True), fill_value=0.0)
    if i % 10 == 0:
        print(f"  processed ~{i*CHUNKSIZE:,} rows ...", flush=True)

if libs is None:
    sys.stderr.write("ERROR: No rows read from input; is the file empty?\n")
    sys.exit(1)

# Avoid division by zero
libs.replace({0: math.nan}, inplace=True)
print("[PASS 1] Done. First few library sizes:")
print(libs.head())

print(f"[PASS 2] Writing CPM-normalized table to {OUT} ...", flush=True)
# Write header with correct columns
hdr = pd.read_csv(IN, sep="\t", nrows=0)
samples = hdr.columns[2:]

first = True
for i, chunk in enumerate(pd.read_csv(IN, sep="\t", chunksize=CHUNKSIZE, low_memory=False), 1):
    out = chunk.iloc[:, :2].copy()  # keep ORF_ID, LEN
    # CPM = counts / libsize * 1e6
    out[samples] = (chunk[samples].astype("float64")).div(libs, axis=1) * 1_000_000.0
    out.to_csv(OUT, sep="\t", index=False, header=first, mode=("w" if first else "a"))
    first = False
    if i % 10 == 0:
        print(f"  wrote ~{i*CHUNKSIZE:,} rows ...", flush=True)

print("[PASS 2] Done.")
PY

echo "[$(date)] Finished."

