#!/bin/bash
# =============================================================================
# Check AF2 Results
# Duke DCC / Soderling Lab
#
# Quickly check the status and scores of completed AF2 predictions.
#
# USAGE:
#   bash check_results.sh                    # Check all results
#   bash check_results.sh pk3_vs_pak1        # Check specific complex
#   bash check_results.sh --job 44078032     # Check specific job status
# =============================================================================

OUTPUT_DIR=/hpc/group/soderlinglab/tools/alphafold/output

# If --job flag, show job status
if [ "$1" = "--job" ] && [ -n "$2" ]; then
    echo "=== Job $2 Status ==="
    sacct -j "$2" --format=JobID,State,ExitCode,Elapsed --array
    echo ""
    echo "=== Error logs ==="
    for f in ${OUTPUT_DIR}/${2}*.err; do
        if [ -f "$f" ]; then
            echo "--- $(basename $f) ---"
            tail -5 "$f"
        fi
    done
    exit 0
fi

# If specific complex name given
if [ -n "$1" ]; then
    NAMES=("$1")
else
    # Auto-detect all result directories
    NAMES=()
    for d in ${OUTPUT_DIR}/*/; do
        dirname=$(basename "$d")
        if [ -f "${d}/ranking_debug.json" ]; then
            NAMES+=("$dirname")
        fi
    done
fi

echo "=== AF2 Multimer Results Summary ==="
echo ""

for name in "${NAMES[@]}"; do
    dir="${OUTPUT_DIR}/${name}"
    if [ ! -d "$dir" ]; then
        echo "[$name] Directory not found"
        continue
    fi

    ranking="${dir}/ranking_debug.json"
    if [ ! -f "$ranking" ]; then
        echo "[$name] Incomplete — no ranking_debug.json"
        # Check if MSAs exist
        if [ -d "${dir}/msas" ]; then
            echo "  MSAs exist — model inference may have failed or is still running"
        fi
        continue
    fi

    # Extract best score using python
    best_score=$(python3 -c "
import json
with open('${ranking}') as f:
    data = json.load(f)
order = data['order']
scores = data['iptm+ptm']
best = order[0]
print(f'{scores[best]:.3f} ({best})')
" 2>/dev/null)

    num_models=$(ls "${dir}"/ranked_*.pdb 2>/dev/null | wc -l)
    has_relaxed=$(ls "${dir}"/relaxed_*.pdb 2>/dev/null | wc -l)

    echo "[$name]"
    echo "  Best ipTM+pTM: $best_score"
    echo "  Models: $num_models ranked PDBs, $has_relaxed relaxed"
    echo ""
done
