#!/bin/bash
# =============================================================================
# AF2 Multimer — Single Job Template
# Duke DCC / Soderling Lab
# Last verified: 2026-03-11
#
# USAGE:
#   1. Edit the variables in the "USER CONFIG" section below
#   2. Make sure your FASTA file is in the output directory (see SOP)
#   3. Submit: sbatch run_single.sh
# =============================================================================

#SBATCH --job-name=af2_multimer
#SBATCH --out=/hpc/group/soderlinglab/tools/alphafold/output/%j.out
#SBATCH --error=/hpc/group/soderlinglab/tools/alphafold/output/%j.err
#SBATCH -p scavenger-gpu --gres=gpu:1
#SBATCH -c 10
#SBATCH --mem=200G
#SBATCH --mail-type=END

# ---- USER CONFIG (edit these) ------------------------------------------------
#SBATCH --mail-user=ds504@duke.edu

# Name of your FASTA file (must be in the output directory!)
FASTA_NAME="your_complex.fasta"

# Number of predictions per model (5 models x N predictions = total structures)
NUM_PRED=5
# ------------------------------------------------------------------------------

# Singularity environment
export SINGULARITY_TMPDIR=/hpc/home/ds504
export SINGULARITY_CACHEDIR=/hpc/home/ds504

# Paths (verified 2026-03-11)
outputPath=/hpc/group/soderlinglab/tools/alphafold/output
faFile=${outputPath}/${FASTA_NAME}
ALPHAFOLD_DATA_PATH=/opt/apps/community/alphafold2/alphafold_dbs/

# Verify FASTA exists before running
if [ ! -f "$faFile" ]; then
    echo "ERROR: FASTA file not found: $faFile"
    echo "Make sure to copy your FASTA to the output directory first:"
    echo "  cp /path/to/your.fasta $outputPath/"
    exit 1
fi

echo "Starting AF2 Multimer prediction"
echo "FASTA: $faFile"
echo "Output: $outputPath"
echo "Time: $(date)"

singularity run --nv --env TF_FORCE_UNIFIED_MEMORY=1,XLA_PYTHON_CLIENT_MEM_FRACTION=0.5,OPENMM_CPU_THREADS=8 -B $ALPHAFOLD_DATA_PATH:/data -B .:/etc -B $outputPath --pwd /app/alphafold /opt/apps/community/alphafold2/alphafold2_latest.sif --num_multimer_predictions_per_model=$NUM_PRED --fasta_paths=$faFile --data_dir=/data --use_gpu_relax=True --model_preset=multimer --db_preset=full_dbs --max_template_date=2022-06-01 --uniref90_database_path=/data/uniref90/uniref90.fasta --mgnify_database_path=/data/mgnify/mgy_clusters.fa --uniref30_database_path=/data/uniref30/UniRef30_2021_03 --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --template_mmcif_dir=/data/pdb_mmcif/mmcif_files --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat --pdb_seqres_database_path=/data/pdb_seqres/pdb_seqres.txt --uniprot_database_path=/data/uniprot/uniprot.fasta --output_dir=$outputPath

echo "Finished: $(date)"
