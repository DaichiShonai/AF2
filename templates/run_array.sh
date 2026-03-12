#!/bin/bash
# =============================================================================
# AF2 Multimer — Array Job Template
# Duke DCC / Soderling Lab
# Last verified: 2026-03-11
#
# Runs multiple complexes in parallel as a SLURM array job.
#
# USAGE:
#   1. Edit the NAMES array and --array range below
#   2. Make sure ALL FASTA files are in the output directory
#   3. Submit: sbatch run_array.sh
#
# EXAMPLE:
#   To predict binder1, binder2, binder3 vs a target:
#     NAMES=(binder1_vs_target binder2_vs_target binder3_vs_target)
#     #SBATCH --array=0-2
# =============================================================================

#SBATCH --job-name=af2_array
#SBATCH --out=/hpc/group/soderlinglab/tools/alphafold/output/%j.out
#SBATCH --error=/hpc/group/soderlinglab/tools/alphafold/output/%j.err
#SBATCH -p scavenger-gpu --gres=gpu:1
#SBATCH -c 10
#SBATCH --mem=200G
#SBATCH --mail-type=END

# ---- USER CONFIG (edit these) ------------------------------------------------
#SBATCH --mail-user=ds504@duke.edu

# Array range: 0 to (number of complexes - 1)
#SBATCH --array=0-3

# List of FASTA file basenames (without .fasta extension)
# These files must exist in the output directory as {NAME}.fasta
NAMES=(pk3_vs_pak1 pk4_vs_pak1 pk5_vs_pak1 pk6_vs_pak1)

NUM_PRED=5
# ------------------------------------------------------------------------------

# Pick the FASTA for this array task
NAME=${NAMES[$SLURM_ARRAY_TASK_ID]}

# Singularity environment
export SINGULARITY_TMPDIR=/hpc/home/ds504
export SINGULARITY_CACHEDIR=/hpc/home/ds504

# Paths (verified 2026-03-11)
outputPath=/hpc/group/soderlinglab/tools/alphafold/output
faFile=${outputPath}/${NAME}.fasta
ALPHAFOLD_DATA_PATH=/opt/apps/community/alphafold2/alphafold_dbs/

# Verify FASTA exists
if [ ! -f "$faFile" ]; then
    echo "ERROR: FASTA file not found: $faFile"
    echo "Copy your FASTA files to the output directory first:"
    echo "  cp /path/to/${NAME}.fasta $outputPath/"
    exit 1
fi

echo "Array task $SLURM_ARRAY_TASK_ID: $NAME"
echo "FASTA: $faFile"
echo "Time: $(date)"

singularity run --nv --env TF_FORCE_UNIFIED_MEMORY=1,XLA_PYTHON_CLIENT_MEM_FRACTION=0.5,OPENMM_CPU_THREADS=8 -B $ALPHAFOLD_DATA_PATH:/data -B .:/etc -B $outputPath --pwd /app/alphafold /opt/apps/community/alphafold2/alphafold2_latest.sif --num_multimer_predictions_per_model=$NUM_PRED --fasta_paths=$faFile --data_dir=/data --use_gpu_relax=True --model_preset=multimer --db_preset=full_dbs --max_template_date=2022-06-01 --uniref90_database_path=/data/uniref90/uniref90.fasta --mgnify_database_path=/data/mgnify/mgy_clusters.fa --uniref30_database_path=/data/uniref30/UniRef30_2021_03 --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --template_mmcif_dir=/data/pdb_mmcif/mmcif_files --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat --pdb_seqres_database_path=/data/pdb_seqres/pdb_seqres.txt --uniprot_database_path=/data/uniprot/uniprot.fasta --output_dir=$outputPath

echo "Finished task $SLURM_ARRAY_TASK_ID ($NAME): $(date)"
