# UAHPC Slurm Resources

Observed on 2026-07-15. Scheduler state and user authorization are dynamic;
always inspect live output and the current user's associations.

## Discovery

```bash
sinfo -o '%P|%a|%l|%D|%c|%m|%G|%f|%N'
scontrol show partition
scontrol show node <node>
sacctmgr show assoc user="$USER" format=Cluster,Account,Partition,QOS,DefaultQOS
sacctmgr show qos format=Name,MaxWall,MaxTRESPerUser,MaxJobsPerUser
```

Public-looking partitions observed were `main`, `long`, `threaded`, and `gpu`.
Many owner/project partitions are also visible. Visibility does not establish
permission: usable QOS values are determined by the user's association.

The observed GPU partition included NVIDIA V100, T4, L4, A100 80 GB, and H100
80 GB nodes. An AMD MI210 node appeared under a private partition and requires a
ROCm-compatible stack. Node state and ownership can change without notice.

## Partition And QOS Selection

- Use `main` for ordinary CPU work and a QOS authorized for the required wall
  time.
- `long` and `threaded` have separate limits and may require explicit QOS.
- Use `gpu` plus an authorized GPU QOS for NVIDIA allocations.
- Do not infer authorization from `sinfo`, and do not trust `sbatch --test-only`
  as the only proof. A tiny real probe gives stronger evidence.
- Request only justified CPU, memory, GPU, and wall time. Oversized requests can
  wait much longer because Slurm must find a node satisfying every constraint.

Safe authorization probe:

```bash
job=$(sbatch --parsable -p main --qos=debug -t 00:01:00 -c 1 --mem=256M \
  --wrap='hostname; date')
squeue -j "$job"
sacct -j "$job" --format=JobID,State,Elapsed,ExitCode
```

If the probe is rejected, inspect associations rather than cycling through
private QOS names.

## GPU Batch Template

Choose an observed type that the account can use. Omitting the type improves
scheduler flexibility when the software supports every NVIDIA generation.

```bash
#!/bin/bash
#SBATCH --job-name=gpu-work
#SBATCH --partition=gpu
#SBATCH --qos=gpu
#SBATCH --gres=gpu:a100-80:1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=/scratch/%u/logs/%x-%j.out

set -euo pipefail
module purge
module load apptainer/1.3.4-1

echo "node=$(hostname) cuda_visible=${CUDA_VISIBLE_DEVICES:-unset}"
nvidia-smi
apptainer exec --nv /scratch/$USER/images/workload.sif python /scratch/$USER/project/run.py
```

Do not request multiple GPUs unless the application is configured for data,
tensor, pipeline, or MPI parallelism. Extra visible GPUs do not automatically
accelerate a single-device process.

## MPI Template

```bash
#!/bin/bash
#SBATCH --job-name=mpi-work
#SBATCH --partition=main
#SBATCH --qos=main
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --mem=0
#SBATCH --time=01:00:00
#SBATCH --output=/scratch/%u/logs/%x-%j.out

set -euo pipefail
module purge
module load compiler/GCC/14.3.0 mpi/OpenMPI/5.0.8-GCC-14.3.0
srun ./my_mpi_program
```

Use a single coherent compiler/MPI family. Verify application scaling on one
node before paying the queue and communication cost of multiple nodes.

## Arrays And Concurrency

```bash
#SBATCH --array=0-999%20

input=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" inputs.txt)
./process-one "$input"
```

The `%20` cap limits simultaneous tasks. Make each task restartable and write to
an isolated output path. Do not let multiple tasks append unsafely to one SQLite
database or output file.

## High Memory

Inspect node memory through `sinfo`/`scontrol`; some large-memory nodes overlap
ordinary partitions while dedicated high-memory partition names may be private.
Requesting `--mem` can select an eligible large node without naming an
unauthorized private partition, but only if such nodes are present in an
authorized partition.

Use `--mem=<total>` for total job memory or `--mem-per-cpu=<amount>` for a
per-CPU contract. Do not specify both. After a representative run, compare
`MaxRSS` with the request and tune it.

## Checkpoint And Resume

- Write outputs atomically: create a temporary file, validate it, then rename.
- Persist a work ledger keyed by stable input identity.
- Skip already completed units after restart.
- Flush checkpoints before the wall-time limit. `$SLURM_JOB_END_TIME` may help
  estimate remaining time when provided.
- Use `--signal=B:USR1@300` and trap the signal when the application supports
  graceful checkpointing five minutes before termination.
- Keep irreplaceable checkpoints out of scratch or mirror them periodically.

## Diagnose Efficiency

```bash
sacct -j <job-id> --format=JobID,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,ExitCode
seff <job-id>
```

- Low CPU efficiency can indicate serial code with excess CPUs, I/O waits, or
  thread settings that do not match `--cpus-per-task`.
- Very low memory use indicates an oversized request; out-of-memory failures
  require either more memory or a lower-concurrency/data-streaming design.
- GPU utilization should be measured inside the allocation with `nvidia-smi`
  or application telemetry; an allocated GPU can still be mostly idle.
