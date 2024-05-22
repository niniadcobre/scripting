#!/bin/bash

# Parse the network address and mask from the command line
network=$1
mask=$2

# Convert the integer mask to a dotted decimal mask
mask=$((0xffffffff << (32-$mask)))
mask=$(printf "%d.%d.%d.%d\n" $((mask>>24&255)) $((mask>>16&255)) $((mask>>8&255)) $((mask&255)))

# Calculate the network address and broadcast address
IFS=. read -r i1 i2 i3 i4 <<< "$network"
IFS=. read -r m1 m2 m3 m4 <<< "$mask"
network_addr=$((i1&m1)).$((i2&m2)).$((i3&m3)).$((i4&m4))
broadcast_addr=$((i1|(m1^255))).$((i2|(m2^255))).$((i3|(m3^255))).$((i4|(m4^255)))

# Iterate over all IP addresses in the network
IFS=. read -r n1 n2 n3 n4 <<< "$network_addr"
IFS=. read -r b1 b2 b3 b4 <<< "$broadcast_addr"
for ((a=$n1; a<=$b1; a++)); do
  for ((b=$n2; b<=$b2; b++)); do
    for ((c=$n3; c<=$b3; c++)); do
      for ((d=$n4+1; d<$b4; d++)); do
        echo "$a.$b.$c.$d"
      done
    done
  done
done

