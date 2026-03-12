# AlphaFold2 Multimer on Duke DCC — Standard Operating Procedure

> **Last updated:** 2026-03-11
> **Author:** Daichi Shonai (ds504)
> **Lab:** Soderling Lab
> **GitHub:** https://github.com/DaichiShonai/AF2

---

## Overview

This document describes how to run **AlphaFold2 Multimer** predictions on the Duke Compute Cluster (DCC) using Singularity containers. It covers FASTA preparation, SLURM job submission, troubleshooting, and results retrieval.

Based on the Soderling Lab AF2 setup originally from https://github.com/WeiliangTian/AF2, with corrections for current DCC paths (as of March 2026).

---

## 1. Key Paths on DCC

| Resource | Path |
|----------|------|
| Lab alphafold directory | `/hpc/group/soderlinglab/tools/alphafold/` |
| Singularity image | `/opt/apps/community/alphafold2/alphafold2_latest.sif` |
| AlphaFold databases | `/opt/apps/community/alphafold2/alphafold_dbs/` |
| FASTA input directory | `/hpc/group/soderlinglab/tools/alphafold/sequence/DS/` |
| Output directory | `/hpc/group/soderlinglab/tools/alphafold/output/` |

### Path changes from original repo

The original GitHub repo (WeiliangTian/AF2) uses older paths that are **no longer valid**:

| What | Old (BROKEN) | Current (WORKING) |
|------|-------------|-------------------|
| Singularity image | `alphafoldv2.2/alphafold_latest.sif` | `alphafold2_latest.sif` |
| Database root | `/opt/apps/community/alphafold2/databases/` | `/opt/apps/community/alphafold2/alphafold_dbs/` |
| UniRef30 database | `uniclust30/uniclust30_2018_08/uniclust30_2018_08` | `uniref30/UniRef30_2021_03` |
| Lab directory | `/hpc/group/soderlinglab/alphafold/` | `/hpc/group/soderlinglab/tools/alphafold/` |

---

## 2. FASTA File Preparation

### Format for multimer prediction

Each FASTA file should contain two sequences separated by headers. Example for predicting Pk3 binding to PAK1:

```
>PAK1_catalytic_domain
MVQLYTPFEKIGQGASGTVYTAMDVATGQEVAIKQMNLQQQPKKELIINEILVMRENKNPNIVNYLDSYLVGDELWVVMEYLAGGSLTDVVTETCMDEGQIAAVCRECLQALEFLHSNQVIHRDIKSDNILLGMDGSVKLTDFGFCAQITPEQSKRSTMVGTPYWMAPEVVTRKAYGPKVDIWSLGIMAIEMIEGEPPYLNENPLRALYLIATNGTPELQNPEKLSAIFRDFLQCCLEMDVEKRGSAKELLQHQFLVD
>Pk3
IVAQVIYHRLSPELRQEFEEKYKGNKSNAKLFAFARQKDPSLTQESVARVLFRQIVA
```

### Critical: FASTA file location

**FASTA files MUST be placed in a directory that is bind-mounted into the Singularity container.** The output directory is always mounted, so the safest approach is to copy FASTA files there:

```bash
cp /hpc/group/soderlinglab/tools/alphafold/sequence/DS/your_file.fasta \
   /hpc/group/soderlinglab/tools/alphafold/output/
```

Then reference the output path in the SLURM script:
```bash
faFile=/hpc/group/soderlinglab/tools/alphafold/output/your_file.fasta
```

> **Why?** The Singularity container only sees directories that are explicitly mounted with `-B`. The sequence directory is NOT mounted by default. If you point to an unmounted path, AF2 will crash with `FileNotFoundError`.

---

## 3. SLURM Script

### Single job script

See `templates/run_single.sh` for a ready-to-use template.

### Array job script (multiple predictions in parallel)

See `templates/run_array.sh` for running multiple binder predictions as a SLURM array.

### Key SLURM parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Partition | `scavenger-gpu` | Uses idle GPUs from other labs. **Jobs can be preempted** (killed) at any time. |
| GPU | `--gres=gpu:1` | One GPU per job |
| CPUs | `-c 10` | 10 CPU cores |
| Memory | `--mem=200G` | AF2 needs substantial RAM for MSA + model inference |
| Mail | `--mail-type=END` | Email notification when job finishes |

### Key Singularity flags

```bash
singularity run --nv \
  --env TF_FORCE_UNIFIED_MEMORY=1,XLA_PYTHON_CLIENT_MEM_FRACTION=0.5,OPENMM_CPU_THREADS=8 \
  -B $ALPHAFOLD_DATA_PATH:/data \
  -B .:/etc \
  -B $outputPath \
  --pwd /app/alphafold \
  /opt/apps/community/alphafold2/alphafold2_latest.sif \
  ...
```

- `--nv`: Enable NVIDIA GPU passthrough
- `-B $ALPHAFOLD_DATA_PATH:/data`: Mount databases at `/data` inside container
- `-B .:/etc`: Mount current directory
- `-B $outputPath`: Mount output directory (and FASTA files if placed here)
- `--pwd /app/alphafold`: Set working directory inside container

### Key AlphaFold flags

| Flag | Value | Notes |
|------|-------|-------|
| `--model_preset` | `multimer` | Required for protein-protein complexes |
| `--db_preset` | `full_dbs` | Full database search (slower but better) |
| `--num_multimer_predictions_per_model` | `5` | 5 predictions × 5 models = 25 total structures |
| `--use_gpu_relax` | `True` | **Must be explicitly set.** Do NOT omit or set to `None`. |
| `--max_template_date` | `2022-06-01` | Template cutoff date |

### Flags that do NOT work

| Flag | Error | Fix |
|------|-------|-----|
| `--run_relax` | `Unknown command line flag` | Remove entirely. Relax is controlled by `--use_gpu_relax`. |
| `--use_gpu_relax=None` | `Flag must have a value other than None` | Set to `True` or `False` explicitly. |

---

## 4. Job Submission

### Submit a single job
```bash
sbatch run_single.sh
```

### Submit an array job
```bash
sbatch run_array.sh
```

### Monitor jobs
```bash
# Check running jobs
squeue -u $(whoami)

# Check job history and status
sacct -j <JOB_ID> --format=JobID,State,ExitCode,Elapsed --array

# Check error logs
cat /hpc/group/soderlinglab/tools/alphafold/output/<JOB_ID>.err
```

### Typical runtimes

| Step | Duration | Notes |
|------|----------|-------|
| MSA (Jackhmmer uniref90) | ~15-20 min | CPU-bound |
| MSA (Jackhmmer mgnify) | ~15 min | CPU-bound |
| MSA (HHblits BFD+UniRef30) | ~5-30 min | CPU-bound |
| Template search | ~1 min | |
| Model inference (25 models) | ~2-3 hours | GPU-bound |
| Relaxation | ~30-60 min | GPU-bound |
| **Total per complex** | **~4-5 hours** | On scavenger-gpu |

---

## 5. Troubleshooting

### Problem: `FileNotFoundError` for FASTA file

**Cause:** FASTA file is in a directory not mounted inside Singularity container.

**Fix:** Copy FASTA to the output directory (which is always mounted):
```bash
cp /path/to/your.fasta /hpc/group/soderlinglab/tools/alphafold/output/
```

### Problem: `Unknown command line flag 'run_relax'`

**Cause:** The `--run_relax` flag does not exist in this version of AF2.

**Fix:** Remove `--run_relax` from the script. Use `--use_gpu_relax=True` instead.

### Problem: `Flag --use_gpu_relax must have a value other than None`

**Cause:** Omitting `--use_gpu_relax` or setting it to `None`.

**Fix:** Explicitly add `--use_gpu_relax=True` (or `False` to skip relaxation).

### Problem: `HHblits failed` (stderr empty, runs for 0.028 seconds)

**Cause:** Job was preempted by scavenger-gpu partition while HHblits was starting.

**Fix:** Resubmit the job. This is a scavenger partition issue, not a script bug.
```bash
sbatch run_single.sh  # or resubmit just the failed array index
```

### Problem: Job disappears from `squeue` unexpectedly

**Cause:** Likely preempted. `scavenger-gpu` uses idle GPUs from other labs — when those labs need their GPUs back, your job gets killed.

**Check:**
```bash
sacct -j <JOB_ID> --format=JobID,State,ExitCode,Elapsed
```
If State shows `PREEMPTED`, resubmit.

### Problem: SLURM script has broken backslash continuations

**Cause:** Copy-pasting multi-line scripts through terminal can break `\` line continuations.

**Fix:** Either put the entire `singularity run` command on one line, or write the script using python:
```bash
python3 -c "
script = '''#!/bin/bash
...your script content...
'''
with open('run_job.sh', 'w') as f:
    f.write(script)
"
```

### Problem: `SINGULARITY_TMPDIR` warning

**Message:** `Environment variable SINGULARITY_TMPDIR is set, but APPTAINER_TMPDIR is preferred`

**Fix:** This is just a warning, not an error. The job will run fine. You can optionally change to:
```bash
export APPTAINER_TMPDIR=/hpc/home/ds504
export APPTAINER_CACHEDIR=/hpc/home/ds504
```

---

## 6. Output Files

After a successful run, the output directory (e.g., `output/pk3_vs_pak1/`) contains:

| File | Description |
|------|-------------|
| `ranked_0.pdb` through `ranked_24.pdb` | All 25 models ranked by ipTM+pTM score (rank 0 = best) |
| `relaxed_model_X_multimer_v3_pred_Y.pdb` | Best model after AMBER relaxation |
| `unrelaxed_model_X_multimer_v3_pred_Y.pdb` | Models before relaxation |
| `confidence_model_X_multimer_v3_pred_Y.json` | Per-residue confidence (pLDDT) scores |
| `ranking_debug.json` | ipTM+pTM scores for all models and ranking order |
| `msas/` | Multiple sequence alignment intermediate files |
| `result_model_X_multimer_v3_pred_Y.pkl` | Full prediction output (large, for detailed analysis) |

### Key metrics

- **ipTM+pTM** (from `ranking_debug.json`): Combined interface and overall structure confidence
  - \> 0.8: High confidence in the predicted complex
  - 0.6–0.8: Moderate confidence
  - < 0.6: Low confidence, interface likely unreliable
- **pLDDT** (from confidence JSONs or B-factor column in PDB): Per-residue confidence
  - \> 90: Very high
  - 70–90: Confident
  - 50–70: Low
  - < 50: Very low / disordered

### Retrieving results to local machine

From your local terminal (NOT on DCC):
```bash
# Create local directory
mkdir -p ~/Desktop/AF2_results

# Download best models and ranking info
for name in pk3_vs_pak1 pk4_vs_pak1 pk5_vs_pak1 pk6_vs_pak1; do
  scp ds504@dcc-login.oit.duke.edu:/hpc/group/soderlinglab/tools/alphafold/output/$name/ranked_0.pdb \
      ~/Desktop/AF2_results/${name}_ranked_0.pdb
  scp ds504@dcc-login.oit.duke.edu:/hpc/group/soderlinglab/tools/alphafold/output/$name/ranking_debug.json \
      ~/Desktop/AF2_results/${name}_ranking_debug.json
done
```

---

## 7. About the scavenger-gpu Partition

- `scavenger-gpu` provides access to **idle GPUs from other labs** at no cost
- Your job may be **preempted (killed) at any time** when the GPU owner needs it
- This is normal and expected — just resubmit
- Typical preemption rate: ~10-20% of jobs
- Alternative: If you have a GPU allocation, use `-p gpu-common` (no preemption, but costs SU)

---

## 8. Quick Start Checklist

1. SSH into DCC: `ssh ds504@dcc-login.oit.duke.edu`
2. Prepare FASTA file with both sequences (target + binder)
3. Copy FASTA to output directory: `cp your.fasta /hpc/group/soderlinglab/tools/alphafold/output/`
4. Copy template script and edit FASTA filename
5. Submit: `sbatch your_script.sh`
6. Monitor: `squeue -u ds504`
7. Check results: `cat output/your_complex/ranking_debug.json`
8. Download `ranked_0.pdb` to local machine via `scp`
