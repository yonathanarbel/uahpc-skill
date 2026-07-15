# UAHPC Hardware Resources

Live Slurm snapshot: 2026-07-15. This records configured resources, not a
guarantee that every node is currently healthy, idle, or authorized for every
user. Refresh with `../scripts/inventory_uahpc.sh`.

## GPU Fleet

The public `gpu` partition advertised nine NVIDIA nodes and 20 GPUs:

| Node | GPUs | Host CPUs | Slurm memory | Notes |
| --- | --- | ---: | ---: | --- |
| `uahpc-gpu001` | 2 x V100 | 24 | 288,000 MB | Intel Xeon Silver 4116 |
| `uahpc-gpu002` | 1 x T4 | 64 | 515,478 MB | AMD EPYC 7H12 |
| `uahpc-gpu003` | 1 x A100 80 GB | 128 | 1,031,543 MB | AMD EPYC 7713 |
| `uahpc-gpu004` | 1 x A100 80 GB | 128 | 1,031,543 MB | AMD EPYC 7713 |
| `uahpc-gpu005` | 1 x A100 80 GB | 128 | 1,031,543 MB | AMD EPYC 7713 |
| `uahpc-gpu006` | 4 x A100 80 GB | 64 | 257,240 MB | Intel Xeon Gold 6338 |
| `uahpc-gpu007` | 2 x L4 | 64 | 1,031,549 MB | AMD EPYC 7543 |
| `uahpc-gpu008` | 4 x H100 80 GB | 64 | 1,031,583 MB | Intel Xeon Platinum 8462Y+ |
| `uahpc-gpu010` | 4 x H100 80 GB | 128 | 2,063,762 MB | Intel Xeon Platinum 8592+ |

Aggregate configured GPUs:

| Type | Count | Typed Slurm request |
| --- | ---: | --- |
| H100 80 GB | 8 | `--gres=gpu:h100-80:1` |
| A100 80 GB | 7 | `--gres=gpu:a100-80:1` |
| L4 | 2 | `--gres=gpu:l4:1` |
| T4 | 1 | `--gres=gpu:t4:1` |
| V100 | 2 | `--gres=gpu:v100:1` |

An untyped `--gres=gpu:1` lets Slurm choose any compatible NVIDIA GPU and can
start sooner. Use a typed request only when memory, compute capability, or
validated software behavior requires it.

At snapshot time, `uahpc-gpu008` was drained and `uahpc-gpu007` was down, while
`uahpc-gpu010` and the A100 nodes were active. Treat state as ephemeral:

```bash
sinfo -N -p gpu -o '%N|%T|%c|%m|%G|%f'
```

`uahpc-gpu009` advertised two AMD MI210 GPUs under a private partition rather
than the public `gpu` partition. They require ROCm-aware software and authorized
partition/QOS access; `apptainer exec --nv` and CUDA containers do not target
MI210 hardware.

## CPU And Memory Fleet

The visible public CPU partitions reported:

| Partition | Nodes | CPUs per node | Approximate memory per node | Wall limit shown by partition |
| --- | ---: | ---: | ---: | ---: |
| `main` | 61 | 16-192 | 91 GiB-2.0 TiB | 7 days* |
| `long` | 8 | 24 | 91 GiB | 7 days* |
| `threaded` | 4 | 40 | 1.97 TiB | 3 days* |

`*` The effective limit is the stricter combination of partition, QOS,
association, and account limits. For example, a `main` partition may advertise
seven days while the user's `main` QOS permits less.

Notable CPU classes visible through `main` included:

- AMD EPYC 9654: 192 logical CPUs and about 1.5 TiB.
- AMD EPYC 7713/7742: 128 logical CPUs and about 1.0-2.0 TiB.
- AMD EPYC 7713P: 64 logical CPUs and about 251 GiB.
- Intel Xeon nodes from 16 to 88 logical CPUs and about 91 GiB-1.0 TiB.
- Some dedicated high-memory nodes overlap `main`; dedicated partition names
  can require private QOS even when the same node is reachable from `main`.

Slurm reports memory in MB. Use live node records for a specific request:

```bash
sinfo -N -p main -o '%N|%T|%c|%m|%f'
scontrol show node <node-name>
```

## Request Patterns

Ordinary CPU work:

```bash
sbatch -p main --qos=main -c 8 --mem=32G -t 04:00:00 job.sbatch
```

Large-memory work through an authorized public partition:

```bash
sbatch -p main --qos=<authorized-long-enough-qos> \
  -c 32 --mem=900G -t 1-00:00:00 job.sbatch
```

Single typed GPU:

```bash
sbatch -p gpu --qos=gpu --gres=gpu:h100-80:1 \
  -c 16 --mem=96G -t 04:00:00 gpu-job.sbatch
```

Four GPUs must land on one of the two configured four-GPU H100 nodes or the
four-GPU A100 node. Request four only for software with verified multi-GPU
parallelism:

```bash
sbatch -p gpu --qos=gpu --gres=gpu:a100-80:4 \
  -c 32 --mem=200G -t 04:00:00 multi-gpu.sbatch
```

Before submitting any large request, compare it with current node state and the
user's allowed QOS/TRES ceilings:

```bash
sacctmgr show assoc user="$USER" format=Cluster,Account,Partition,QOS,DefaultQOS
sacctmgr show qos format=Name,MaxWall,MaxTRESPerUser,MaxJobsPerUser
```
