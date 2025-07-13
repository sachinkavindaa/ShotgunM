#!/bin/bash
for file in ibk*_1.fq.gz; do
    newname=$(echo "$file" | sed -E 's/^ibk([0-9]+)/ibk_\1/')
    mv "$file" "$newname"
done

for file in ibk*_2.fq.gz; do
    newname=$(echo "$file" | sed -E 's/^ibk([0-9]+)/ibk_\1/')
    mv "$file" "$newname"
done
