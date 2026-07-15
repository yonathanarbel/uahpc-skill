# UAHPC Module Catalog

Observed on UAHPC on 2026-07-15. The live tree contained 895 entries across
`/cm/local/modulefiles`, `/cm/shared/modulefiles`, and `/share/apps/modulefiles`.
Modules change; use `../scripts/inventory_uahpc.sh --full` before relying on a
specific name.

## Search Correctly

UAHPC currently runs Environment Modules 5.3.1, not Lmod. Use:

```bash
module -t avail
module avail <name>
module keyword <term>
module whatis <exact-module>
module show <exact-module>
module path <exact-module>
```

`module spider` is not implemented. `module show` is especially useful before
loading old modules because it reveals paths, dependencies, and environment
changes.

## Current Families

The largest prefixes in the live tree were:

| Family | Entries | Typical contents |
| --- | ---: | --- |
| `bio/` | 144 | genomics, alignment, assembly, phylogenetics |
| `physical/` | 71 | chemistry, materials, CFD, molecular dynamics |
| `lib/` | 49 | communication, compression, image, and runtime libraries |
| `tools/` | 44 | build, packaging, compression, and developer utilities |
| `math/` | 31 | MATLAB, R, SAS, and numerical packages |
| `mpi/` | 30 | OpenMPI, MPICH, MVAPICH, Intel MPI |
| `devel/` | 28 | CMake, Autotools, Doxygen, SQLite, build support |
| `compilers/` | 27 | GCC, Intel, and NVIDIA compiler generations |
| `python/` | 25 | legacy Python/Anaconda stacks |
| `lang/` | 17 | current Python, Rust, Perl, Tcl, Cython |

## Recommended Modern Foundations

Prefer exact names and one coherent generation:

- GCC: `compiler/GCC/12.3.0`, `compiler/GCC/14.3.0`
- Python: `lang/Python/3.11.3-GCCcore-12.3.0`,
  `lang/Python/3.13.5-GCCcore-14.3.0`
- OpenMPI: `mpi/OpenMPI/4.1.5-GCC-12.3.0`,
  `mpi/OpenMPI/5.0.8-GCC-14.3.0`
- Intel: `toolchain/intel/2023a`, `compiler/intel-compilers/2023.1.0`,
  `mpi/impi/2021.9.0-intel-compilers-2023.1.0`
- Build tools: `devel/CMake/4.0.3-GCCcore-14.3.0`,
  `tools/Ninja/1.13.0-GCCcore-14.3.0`, `EasyBuild/5.2.0`
- Containers: `apptainer/1.3.4-1`; legacy `singularity/3.7.2`
- Languages: `math/R/4.5.2`, `julia/1.6.2`,
  `lang/Rust/1.70.0-GCCcore-12.3.0`, `java/17.0.11`, `go/1.16.2`

Some modules appear both with and without category prefixes. Prefer the
category-qualified EasyBuild name when it provides the intended dependency
stack. Verify with `module show` rather than assuming similarly named entries
are equivalent.

## Numerical And Data Libraries

The tree includes current or historical builds of:

- OpenBLAS, BLAS, LAPACK, FlexiBLAS, BLIS, FFTW, Intel MKL FFTW
- HDF5, netCDF, SQLite, GDAL, GEOS, PROJ
- PETSc, METIS, ParMETIS, Eigen, GMP, MPFR, Qhull
- UCX, UCC, PMIx, PRRTE, libfabric, hwloc

Keep compiler, MPI, HDF5, and netCDF families aligned. Loading an HDF5 build
compiled against a different MPI/compiler stack can fail at link time or,
worse, at runtime.

## Major Applications

Selected observed application modules:

- Bioinformatics: BLAST, Bowtie, BWA, GATK, SAMtools, FastQC, BUSCO, Augustus,
  FreeBayes, QIIME, Maker, RepeatModeler, OrthoFinder, FSL, AFNI, FreeSurfer.
- Chemistry/materials: Gaussian 03/09/16, ORCA 4/5, VASP 5/6, Q-Chem 5.3,
  DIRAC 25, Amber 18, GROMACS, LAMMPS, OpenFOAM, COMSOL 5.3a, ANSYS 2024 R1.
- Analysis: MATLAB 2019a through 2025b, Mathematica 10/12, SAS 9.3/9.4,
  Stata 13, Spark 3.0.3.
- Visualization: Visit 2.7/3.4 and domain-specific visualization dependencies.

Licensed applications may require group membership, a license allocation, or a
specific execution procedure even when their modulefiles are visible.

## GPU And Machine Learning Gaps

No general current PyTorch, JAX, vLLM, or standalone modern CUDA module was
observed in the 2026-07-15 catalog. `math/Tensorflow` and an old Anaconda
TensorFlow environment exist, but should not be assumed suitable for current
GPU work. NVIDIA compiler modules bundle CUDA 11.0 or 11.6 for their compiler
generation; they are not a universal ML environment.

For current GPU software, prefer a pinned Apptainer image or a scratch-based
virtual environment after checking the compute-node driver. Use `apptainer
exec --nv` only inside a GPU allocation, and run `nvidia-smi` first.

## Reproducibility

Record the exact loaded set and software identity in each run:

```bash
module -t list 2>&1 | sort > "$RUN_DIR/modules.txt"
module save "$RUN_DIR/modules.collection"
python --version > "$RUN_DIR/runtime.txt" 2>&1
git rev-parse HEAD > "$RUN_DIR/git-commit.txt"
```

`module save` collections can be restored with `module restore <file>`, but a
container plus lockfile is more portable when module availability changes.
