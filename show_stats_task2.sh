#!/bin/bash
# Izlušči CPI in L1 cache miss events za skalarno in vektorsko implementacijo.
# stats.txt ima DVA razdelka: 1. skalarni, 2. vektorski.
# Ponovi za obe velikosti predpomnilnika (8KiB in 64KiB).

for CACHE in 8KiB 64KiB; do
    echo "========================================"
    echo " L1 predpomnilnik: $CACHE"
    echo "========================================"

    printf "%-6s | %-10s | %-10s | %-14s | %-14s\n" \
        "VLEN" "Scal. CPI" "Vec. CPI" "Scal. misses" "Vec. misses"
    printf '%s\n' "---------------------------------------------------------------"

    for VLEN in 128 256 512 1024 2048 4096; do
        FILE=results_task2/cache_${CACHE}/vlen_${VLEN}/stats.txt

        if [ ! -f "$FILE" ]; then
            printf "%-6s | ni podatkov\n" "$VLEN"
            continue
        fi

        # CPI iz 1. razdelka (skalarni) in 2. razdelka (vektorski)
        CPI_S=$(awk '/Begin Simulation/{n++} n==1 && /system\.cpu\.cpi /{print $2; exit}' "$FILE")
        CPI_V=$(awk '/Begin Simulation/{n++} n==2 && /system\.cpu\.cpi /{print $2; exit}' "$FILE")

        # L1 podatkovni cache missi iz 1. in 2. razdelka
        MISS_S=$(awk '/Begin Simulation/{n++} n==1 && /l1dcaches\.overallMisses::total/{print $2; exit}' "$FILE")
        MISS_V=$(awk '/Begin Simulation/{n++} n==2 && /l1dcaches\.overallMisses::total/{print $2; exit}' "$FILE")

        printf "%-6s | %-10s | %-10s | %-14s | %-14s\n" \
            "$VLEN" "$CPI_S" "$CPI_V" "$MISS_S" "$MISS_V"
    done

    echo ""
done
