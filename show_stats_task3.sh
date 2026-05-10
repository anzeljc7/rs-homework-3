#!/bin/bash
# Izlušči CPI in L1 cache miss events za vse 4 SpMV kernele.
# stats.txt ima ŠTIRI razdelke v tem vrstnem redu (kot v main()):
#   1. unit_stride
#   2. strided
#   3. gather_sorted
#   4. gather_random

KERNELS=("unit_stride" "strided" "gather_sorted" "gather_random")

for CACHE in 8KiB 64KiB; do
    echo "========================================"
    echo " L1 predpomnilnik: $CACHE"
    echo "========================================"

    printf "%-6s | %-14s | %-10s | %-12s\n" \
        "VLEN" "Kernel" "CPI" "L1 misses"
    printf '%s\n' "-------------------------------------------------------"

    for VLEN in 256 512 1024; do
        FILE=results_task3/cache_${CACHE}/vlen_${VLEN}/stats.txt

        if [ ! -f "$FILE" ]; then
            printf "%-6s | ni podatkov\n" "$VLEN"
            continue
        fi

        # Vsak kernel je v svojem razdelku (n = 1..4)
        for IDX in 1 2 3 4; do
            KERNEL=${KERNELS[$((IDX - 1))]}

            CPI=$(awk "/Begin Simulation/{n++} n==$IDX && /board\.processor\.cores\.core\.cpi /{print \$2; exit}" "$FILE")
            MISS=$(awk "/Begin Simulation/{n++} n==$IDX && /l1dcaches\.overallMisses::total/{print \$2; exit}" "$FILE")

            printf "%-6s | %-14s | %-10s | %-12s\n" \
                "$VLEN" "$KERNEL" "$CPI" "$MISS"
        done

        printf '%s\n' "-------------------------------------------------------"
    done

    echo ""
done
