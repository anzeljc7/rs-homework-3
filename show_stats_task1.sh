#!/bin/bash
# Izlušči CPI in čas izvajanja za skalarno in vektorsko implementacijo.
# stats.txt ima DVA razdelka: 1. skalarni, 2. vektorski (ker main() kliče
# m5_dump_stats dvakrat — enkrat po skalarnem, enkrat po vektorskem delu).

printf "%-6s | %-12s | %-12s | %-16s | %-16s\n" \
    "VLEN" "Scalar CPI" "Vector CPI" "Scalar time (s)" "Vector time (s)"
printf '%s\n' "-----------------------------------------------------------------------"

for VLEN in 128 256 512 1024 2048 4096; do
    FILE=results_task1/vlen_${VLEN}/stats.txt

    if [ ! -f "$FILE" ]; then
        printf "%-6s | ni podatkov\n" "$VLEN"
        continue
    fi

    # Awk razdeli datoteko na razdelke ob "Begin Simulation Statistics"
    # in pobere vrednost iskane metrike iz zahtevnega razdelka (n==1 ali n==2)
    CPI_SCALAR=$(awk '/Begin Simulation/{n++} n==1 && /board\.processor\.cores\.core\.cpi /{print $2; exit}' "$FILE")
    CPI_VECTOR=$(awk '/Begin Simulation/{n++} n==2 && /board\.processor\.cores\.core\.cpi /{print $2; exit}' "$FILE")

    TIME_SCALAR=$(awk '/Begin Simulation/{n++} n==1 && /^simSeconds /{print $2; exit}' "$FILE")
    TIME_VECTOR=$(awk '/Begin Simulation/{n++} n==2 && /^simSeconds /{print $2; exit}' "$FILE")

    printf "%-6s | %-12s | %-12s | %-16s | %-16s\n" \
        "$VLEN" "$CPI_SCALAR" "$CPI_VECTOR" "$TIME_SCALAR" "$TIME_VECTOR"
done
