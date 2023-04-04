#!/bin/bash

read -p "Enter the block size (e.g., 1M, 1G): " block_size
read -p "Enter the amount of blocks: " block_count
read -p "Enter the number of runs: " runs

# Convert lowercase 'k, m, g, t, p' to uppercase 'K, M, G, T, P'
block_size=$(echo "$block_size" | tr 'kmgtp' 'KMGTP')


echo "Running dd benchmark..."

echo "Starting dd-write..."
temp_file=$(mktemp)
for i in $(seq 1 $runs); do
    speed=$(dd if=/dev/zero of=testfile bs=$block_size count=$block_count oflag=dsync 2>&1 | awk '/copied/ {print $(NF-1),$NF}')
    if echo "$speed" | grep -q "GB"; then
        speed=$(echo "$speed" | awk '{printf("%.0f MB/s", $1 * 1024)}')
    fi
    echo "Run $i speed: $speed" | tee -a "$temp_file"
done

awk '{if($5 == "PB/s") s += $4 * 1024 * 1024 * 1024; else if($5 == "TB/s") s += $4 * 1024 * 1024; else if($5 == "GB/s") s += $4 * 1024; else if($5 == "kB/s") s += $4 / 1024; else s += $4} END {printf("Average speed: %.2f MB/s\n", s/NR)}' "$temp_file"
rm "$temp_file"
echo "Finished dd-write."

 sleep 1s

echo "Starting dd-read..."
temp_file=$(mktemp)
for i in $(seq 1 $runs); do
    speed=$(dd if=testfile of=/dev/null bs=$block_size count=$block_count iflag=fullblock 2>&1 | awk '/copied/ {print $(NF-1),$NF}')
    if echo "$speed" | grep -q "GB"; then
        speed=$(echo "$speed" | awk '{printf("%.0f MB/s", $1 * 1024)}')
    fi
    echo "Run $i speed: $speed" | tee -a "$temp_file"
done

awk '{if($5 == "PB/s") s += $4 * 1024 * 1024 * 1024; else if($5 == "TB/s") s += $4 * 1024 * 1024; else if($5 == "GB/s") s += $4 * 1024; else if($5 == "kB/s") s += $4 / 1024; else s += $4} END {printf("Average speed: %.2f MB/s\n", s/NR)}' "$temp_file"
rm "$temp_file"
echo "Finished dd-read."
rm testfile 
echo "Benchmark finished."