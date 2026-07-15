---
name: uahpc
description: Connect to and work safely on the University of Alabama High Performance Computing cluster (UAHPC), including SSH and VPN diagnosis, PanFS storage and quota checks, Environment Modules discovery, Slurm partitions/QOS/account access, CPU and GPU jobs, Apptainer containers, data transfer, job monitoring, and recovery. Use for uahpc.ua.edu, UAHPC login or compute nodes, /home/$USER, /bighome/$USER, /scratch/$USER, module avail, sbatch, srun, salloc, sinfo, squeue, sacct, seff, GPU allocation, or HPC troubleshooting.
---

# UAHPC

## Operating Rules

- Treat the login node as a control plane. Use it for editing, transfers, module
  discovery, queue inspection, and job submission; run heavy work through Slurm.
- Discover the user's actual associations and current cluster state before
  choosing a partition, QOS, GPU type, memory request, or wall time.
- Never record passwords, Duo codes, API tokens, private keys, or secret values.
  Enter interactive credentials only in the user's terminal.
- Never disable SSH host-key checking to get around a connection problem.
- Inspect before deleting. Do not remove datasets, environments, source trees,
  or results unless the user explicitly approves the exact scope.
- Assume scratch is non-durable and unsnapshotted. Confirm the current purge
  policy and preserve irreplaceable inputs and outputs elsewhere.

## Connect

Prefer a local SSH alias. Replace placeholders locally; do not commit the
resulting private configuration to this skill.

```sshconfig
Host uahpc
    HostName uahpc.ua.edu
    User <mybama-username>
    IdentityFile ~/.ssh/uahpc_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

```bash
ssh uahpc
ssh -o BatchMode=yes -o ConnectTimeout=15 uahpc 'hostname; id -un'
```

UAHPC may require the UA network or VPN. If SSH times out, establish network
reachability before debugging keys:

```bash
nc -vz uahpc.ua.edu 22
ssh -vv uahpc
```

If a password or Duo prompt is expected, omit `BatchMode=yes` and let the user
complete it interactively. Use a bastion only when the user is authorized and
has an independently working account on that host.

## Inventory First

Run the bundled read-only inventory before substantial work:

```bash
scripts/inventory_uahpc.sh
scripts/inventory_uahpc.sh --full   # includes the complete live module list
```

Set `UAHPC_HOST` when the SSH alias has another name. The script also works when
run directly on a UAHPC node.

Manually inspect live state when a focused answer is enough:

```bash
sinfo -o '%P|%a|%l|%D|%c|%m|%G|%N'
squeue -u "$USER"
sacctmgr show assoc user="$USER" format=Cluster,Account,Partition,QOS,DefaultQOS
sacctmgr show qos format=Name,MaxWall,MaxTRESPerUser,MaxJobsPerUser
```

Visible partitions are not necessarily authorized for the current account.
Read [references/slurm-resources.md](references/slurm-resources.md) before
making unusual GPU, high-memory, multi-node, or long-duration requests.

## Resource Snapshot

Live Slurm data on 2026-07-15 showed these resources in the generally visible
public partitions:

- `main`: 61 heterogeneous CPU nodes, from 16 to 192 logical CPUs per node and
  roughly 91 GiB to 2.0 TiB of Slurm-reported memory.
- `long`: eight 24-CPU nodes with roughly 91 GiB each.
- `threaded`: four 40-CPU nodes with roughly 1.97 TiB each.
- `gpu`: nine NVIDIA GPU nodes containing **20 GPUs total**: eight H100 80 GB,
  seven A100 80 GB, two L4, one T4, and two V100 GPUs.
- Several CPU nodes in `main` also overlap named high-memory, ultrahigh-memory,
  or owner partitions. Requesting sufficient memory through an authorized
  public partition can sometimes reach them without private QOS access.
- Two AMD MI210 GPUs were visible only through a private partition in this
  snapshot; do not assume access or CUDA compatibility.

Availability and node state are volatile. At the snapshot time, one H100 node
was drained and the L4 node was down even though both remained configured.
Read [references/hardware-resources.md](references/hardware-resources.md) for
the node-level GPU table, CPU tiers, memory units, and request examples. Always
refresh with `scripts/inventory_uahpc.sh` before capacity planning.

## Storage

Use the paths belonging to the remote account:

- `/home/$USER`: small, durable home for configuration and lightweight source.
- `/bighome/$USER`: durable research/project data, subject to account quota.
- `/scratch/$USER`: active datasets, environments, caches, models, checkpoints,
  job logs, and temporary results. Treat it as disposable.

Check quota and usage before large writes:

```bash
pan_quota "/home/$USER" "/bighome/$USER" "/scratch/$USER"
du -h --max-depth=1 "/scratch/$USER" 2>/dev/null | sort -h | tail -n 30
```

Keep package and model caches off `/home`:

```bash
export TMPDIR="/scratch/$USER/tmp"
export XDG_CACHE_HOME="/scratch/$USER/.cache"
export PIP_CACHE_DIR="$XDG_CACHE_HOME/pip"
export HF_HOME="$XDG_CACHE_HOME/huggingface"
mkdir -p "$TMPDIR" "$PIP_CACHE_DIR" "$HF_HOME"
```

## Modules And Software

UAHPC uses Environment Modules rather than Lmod. `module spider` is not
available. Use:

```bash
module -t avail
module avail python
module keyword python
module whatis lang/Python/3.13.5-GCCcore-14.3.0
module show lang/Python/3.13.5-GCCcore-14.3.0
module list
module purge
module load <exact-module-name>
```

Prefer a coherent recent toolchain and avoid mixing unrelated compiler/MPI
families. Read [references/module-catalog.md](references/module-catalog.md) for
the dated live catalog and important availability gaps.

For a Python project, create its environment in scratch after loading the chosen
interpreter:

```bash
module purge
module load lang/Python/3.13.5-GCCcore-14.3.0
python -m venv "/scratch/$USER/envs/my-project"
source "/scratch/$USER/envs/my-project/bin/activate"
python -m pip install --upgrade pip
```

For reproducible GPU or complex software, prefer an Apptainer image with pinned
dependencies. Put images and caches in scratch:

```bash
module load apptainer/1.3.4-1
export APPTAINER_CACHEDIR="/scratch/$USER/.cache/apptainer"
export APPTAINER_TMPDIR="/scratch/$USER/tmp/apptainer"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
```

## Run Jobs

Prefer `sbatch` for unattended work. A minimal serial CPU job:

```bash
#!/bin/bash
#SBATCH --job-name=my-job
#SBATCH --partition=main
#SBATCH --qos=main
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/scratch/%u/logs/%x-%j.out

set -euo pipefail
module purge
module load lang/Python/3.13.5-GCCcore-14.3.0
python my_program.py
```

```bash
mkdir -p "/scratch/$USER/logs"
sbatch job.sbatch
```

For interactive diagnosis, request resources first and run work inside the
allocation:

```bash
salloc -p main --qos=debug -t 00:10:00 -c 2 --mem=4G
srun --pty bash -l
```

After receiving a GPU, always verify the allocation before starting a model:

```bash
hostname
echo "$CUDA_VISIBLE_DEVICES"
nvidia-smi
```

Use the templates and selection rules in
[references/slurm-resources.md](references/slurm-resources.md) for GPU, MPI,
arrays, high-memory jobs, checkpointing, and authorization probes.

## Monitor And Recover

```bash
squeue -u "$USER" -o '%.18i %.24j %.10T %.12M %.12l %.30R'
scontrol show job <job-id>
sstat -j <job-id>.batch --format=JobID,AveCPU,AveRSS,MaxRSS
sacct -j <job-id> --format=JobID,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,ExitCode
seff <job-id>
scancel <job-id>
```

Interpret common pending reasons before resubmitting:

- `Resources`: matching nodes are busy; wait or reduce a genuinely excessive
  request.
- `Priority`: the job is valid but behind higher-priority work.
- `QOSMax*` or `AssocMax*`: the account or user has reached a scheduler limit.
- `QOSNotAllowed` or submission rejection: inspect the user's associations and
  choose an authorized partition/QOS pair.

Do not repeatedly clone pending jobs. Preserve logs and checkpoint long jobs so
wall-time, preemption, node failure, or VPN loss does not discard completed work.
Submitted Slurm jobs continue when the user's laptop disconnects.

## Transfer Data

Transfer to scratch by default, with resumable flags:

```bash
rsync -az --partial --info=progress2 local-data/ \
  uahpc:/scratch/<mybama-username>/project/input/
rsync -az --partial --info=progress2 \
  uahpc:/scratch/<mybama-username>/project/results/ local-results/
```

Use `scp` for small one-off files. Do not run sustained compression, hashing, or
bulk transformation on the login node; submit that work to a CPU node.

For large transfers, UA also documents `hpcdtn01.ua.edu` as its data-transfer
node. Confirm that the user can access it, then use a separate SSH alias and the
same resumable `rsync` pattern.

## Official Resources

- [Get Started, accounts, VPN, and support](https://hpc.ua.edu/current-services/get-started/)
- [Live-facing UAHPC technical specifications](https://hpc.ua.edu/current-services/technical-specifications/uahpc/)
- [Research computing and module basics](https://hpc.ua.edu/current-services/get-started/research-computing-basics/)
- [Software catalog](https://hpc.ua.edu/current-services/software-catalog/)

When the website and live scheduler disagree, report the discrepancy and use
live `sinfo`, `scontrol`, and association/QOS output for the immediate request.
Contact `hpc@ua.edu` for account, authorization, software-installation, or
cluster-policy questions that cannot be resolved from live discovery.
