#!/bin/bash
# =============================================================================
# Quick Setup & Submit Helper
# Duke DCC / Soderling Lab
#
# This script automates the common workflow:
#   1. Copy FASTA files to the output directory (required for Singularity access)
#   2. Copy the SLURM script to the sequence directory
#   3. Submit the job
#
# USAGE:
#   bash setup_and_submit.sh
#
# Before running, edit the FASTA_FILES array below.
# =============================================================================

# ---- USER CONFIG -------------------------------------------------------------
# List your FASTA files (full path)
FASTA_FILES=(
    /hpc/group/soderlinglab/tools/alphafold/sequence/DS/pk3_vs_pak1.fasta
    /hpc/group/soderlinglab/tools/alphafold/sequence/DS/pk4_vs_pak1.fasta
    /hpc/group/soderlinglab/tools/alphafold/sequence/DS/pk5_vs_pak1.fasta
    /hpc/group/soderlinglab/tools/alphafold/sequence/DS/pk6_vs_pak1.fasta
)

# Which script to use: "single" or "array"
MODE="array"
# ------------------------------------------------------------------------------

OUTPUT_DIR=/hpc/group/soderlinglab/tools/alphafold/output
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== AF2 Setup & Submit ==="
echo ""

# Step 1: Copy FASTA files to output directory
echo "Step 1: Copying FASTA files to output directory..."
for f in "${FASTA_FILES[@]}"; do
    if [ -f "$f" ]; then
        cp "$f" "$OUTPUT_DIR/"
        echo "  Copied: $(basename $f)"
    else
        echo "  WARNING: Not found: $f"
    fi
done
echo ""

# Step 2: Submit job
if [ "$MODE" = "array" ]; then
    echo "Step 2: Submitting array job..."
    sbatch "${SCRIPT_DIR}/run_array.sh"
else
    echo "Step 2: Submitting single job..."
    sbatch "${SCRIPT_DIR}/run_single.sh"
fi

echo ""
echo "Done! Monitor with: squeue -u \$(whoami)"
