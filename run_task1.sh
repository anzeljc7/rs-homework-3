#!/bin/sh
#SBATCH --job-name=gem5_task1
#SBATCH --output=gem5_task1_%j.log
#SBATCH --cpus-per-task=2
#SBATCH --ntasks=1
#SBATCH --time=02:00:00
#SBATCH --reservation=fri

GEM5_WORKSPACE=/d/hpc/projects/FRI/GEM5/gem5_workspace
GEM5_ROOT=$GEM5_WORKSPACE/gem5
GEM5_BIN=$GEM5_ROOT/build/RISCV_ALL_RUBY/gem5.opt
SIF=$GEM5_WORKSPACE/gem5_rv.sif

BINARY=./workload/scaled_dot_product/scaled_dot_product.bin
CACHE=8KiB

# Prevajanje RISC-V binarke znotraj apptainer okolja
cd workload/scaled_dot_product
srun apptainer exec $SIF make
cd ../..

# Zanka čez vse zahtevane VLEN vrednosti (naloga zahteva 128–4096)
for VLEN in 128 256 512 1024 2048 4096; do
    OUTDIR=results_task1/vlen_${VLEN}
    echo "=== VLEN=$VLEN bitov, L1=$CACHE ==="

    srun apptainer exec $SIF $GEM5_BIN \
        --outdir=$OUTDIR \
        cpu_benchmark.py $VLEN $CACHE $BINARY
done

echo "Vse simulacije za nalogo 1 zaključene."
