#!/bin/bash

for rejectfile ; do
    grep ^--- $rejectfile |
    cut -c4- |
    while read file ; do
        grep -v ^+ $rejectfile |
        cut -c2- |
        diff -u - $file
    done
done
