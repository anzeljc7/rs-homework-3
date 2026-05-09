#!/bin/sh
#SBATCH --job-name=gem5_task2
#SBATCH --output=gem5_task2_%j.log
#SBATCH --cpus-per-task=2
#SBATCH --ntasks=1
#SBATCH --time=04:00:00
#SBATCH --reservation=fri

GEM5_WORKSPACE=/d/hpc/projects/FRI/GEM5/gem5_workspace
GEM5_ROOT=$GEM5_WORKSPACE/gem5
GEM5_BIN=$GEM5_ROOT/build/RISCV_ALL_RUBY/gem5.opt
SIF=$GEM5_WORKSPACE/gem5_rv.sif

BINARY=./workload/heat_stencil/heat_stencil.bin

# Prevajanje RISC-V binarke — -C poda pot do Makefile ker cd ne vpliva na srun
srun apptainer exec $SIF make -C workload/heat_stencil
if [ $? -ne 0 ]; then
    echo "Napaka pri prevajanju! Ustavljam."
    exit 1
fi

# Zunanja zanka: dve velikosti L1 predpomnilnika (zahtevi naloge)
for CACHE in 8KiB 64KiB; do

    # Notranja zanka: vse zahtevane VLEN vrednosti
    for VLEN in 128 256 512 1024 2048 4096; do
        OUTDIR=results_task2/cache_${CACHE}/vlen_${VLEN}
        echo "=== VLEN=$VLEN bitov, L1=$CACHE ==="

        srun apptainer exec $SIF $GEM5_BIN \
            --outdir=$OUTDIR \
            cpu_benchmark.py $VLEN $CACHE $BINARY
    done

done

echo "Vse simulacije za nalogo 2 zaključene."
