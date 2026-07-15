#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-summary}"
if [[ "$MODE" == "--local" ]]; then
  shift
  MODE="${1:-summary}"
fi

on_uahpc() {
  [[ "$(hostname -s 2>/dev/null || true)" == uahpc-* ]]
}

inventory() {
  echo "# UAHPC inventory"
  printf 'generated_at='; date -Is
  printf 'host='; hostname
  printf 'user='; id -un

  echo
  echo "## Environment Modules"
  module --version 2>&1 | head -n 2
  module_file=$(mktemp)
  trap 'rm -f "$module_file"' EXIT
  module -t avail >"$module_file" 2>&1 || true
  module_count=$(awk '
    /^[[:space:]]*$/ {next}
    /^\// && /:$/ {next}
    /^(Where|Key):/ {next}
    /^(MODULE|If |Use )/ {next}
    {count++}
    END {print count+0}
  ' "$module_file")
  echo "available_entries=$module_count"
  echo "search: module avail <name> | module keyword <term> | module show <exact-name>"
  if [[ "$MODE" == "--full" || "$MODE" == "full" ]]; then
    echo
    echo "### Complete module avail"
    cat "$module_file"
  else
    echo "selected modules:"
    grep -Ei '(^|/)(apptainer|singularity|Python|R|matlab|julia|GCC|OpenMPI|intel|CUDA|VASP|LAMMPS|gromacs|samtools|blast|freesurfer)(/|$)' "$module_file" | head -n 120 || true
  fi

  echo
  echo "## Partitions and nodes"
  partition_file=$(mktemp)
  trap 'rm -f "$module_file" "$partition_file"' EXIT
  sinfo -h -o '%P|%a|%l|%D|%c|%m|%G|%f' | sort -u > "$partition_file"
  if [[ "$MODE" == "--full" || "$MODE" == "full" ]]; then
    cat "$partition_file"
  else
    awk -F'|' '$1 ~ /^(main\*?|long|threaded|gpu)$/ {print}' "$partition_file"
    echo "private/owner partitions omitted; use --full to include every visible partition"
  fi

  echo
  echo "## Current user associations"
  sacctmgr -n -P show assoc user="$USER" \
    format=Cluster,Account,Partition,QOS,DefaultQOS 2>/dev/null || true

  echo
  echo "## QOS limits"
  if [[ "$MODE" == "--full" || "$MODE" == "full" ]]; then
    sacctmgr -n -P show qos \
      format=Name,MaxWall,MaxTRESPerUser,MaxJobsPerUser 2>/dev/null || true
  else
    qos_csv=$(sacctmgr -n -P show assoc user="$USER" format=QOS 2>/dev/null \
      | awk -F'|' 'NF {print $1; exit}' | tr -d ' ')
    if [[ -n "$qos_csv" ]]; then
      IFS=',' read -r -a qos_names <<< "$qos_csv"
      for qos_name in "${qos_names[@]}"; do
        sacctmgr -n -P show qos where name="$qos_name" \
          format=Name,MaxWall,MaxTRESPerUser,MaxJobsPerUser 2>/dev/null || true
      done
    fi
  fi

  echo
  echo "## Queue"
  squeue -u "$USER" -o '%.18i %.24j %.10T %.12M %.12l %.30R'

  echo
  echo "## Storage"
  df -hT "/home/$USER" "/bighome/$USER" "/scratch/$USER" 2>/dev/null || true
  if command -v pan_quota >/dev/null 2>&1; then
    pan_quota "/home/$USER" "/bighome/$USER" "/scratch/$USER" 2>/dev/null || true
  fi

  echo
  echo "## Commands"
  for command_name in module sinfo squeue sbatch srun salloc sacct sstat seff \
    scontrol sacctmgr apptainer singularity rsync pan_quota; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf '%-12s %s\n' "$command_name" "$(command -v "$command_name")"
    fi
  done
}

if on_uahpc || [[ "${1:-}" == "--local" ]]; then
  inventory
else
  host="${UAHPC_HOST:-uahpc}"
  if [[ "$MODE" == "--full" || "$MODE" == "full" ]]; then
    ssh -o ConnectTimeout=15 "$host" "bash -lc 'bash -s -- --local --full'" < "$0"
  else
    ssh -o ConnectTimeout=15 "$host" "bash -lc 'bash -s -- --local'" < "$0"
  fi
fi
